import SwiftUI
import SwiftData
import Contacts


struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [SplitGroup]
    
    @State private var searchText = ""
    @State private var showingCreateGroup = false
    @State private var showingProfile = false
    @State private var showingSettings = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedGroupIds = Set<UUID>()
    @State private var groupToRename: SplitGroup? = nil
    @State private var newGroupName = ""
    @State private var showingRenameAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var offsetsToDelete: IndexSet? = nil
    @AppStorage("loggedInUserId") private var loggedInUserId: String?
    @FocusState private var isSearchFocused: Bool
    
    var userGroups: [SplitGroup] {
        guard let currentUser = appState.currentUser else { return [] }
        return groups.filter { group in
            group.members.contains { $0.id == currentUser.id }
        }
    }
    
    var filteredGroups: [SplitGroup] {
        if searchText.isEmpty {
            return userGroups
        } else {
            return userGroups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var totalBalance: Double {
        guard let currentUser = appState.currentUser else { return 0 }
        var balance: Double = 0
        
        let userGroups = groups.filter { group in
            group.members.contains { $0.id == currentUser.id }
        }
        
        for group in userGroups {
            for expense in group.expenses {
                let currentUserShare = expense.splitDetails.first(where: { $0.user?.id == currentUser.id })?.amount ?? 0
                
                if let paidBy = expense.paidBy {
                    if paidBy.id == currentUser.id {
                        // User paid: Balance += (Total Amount - Their own share)
                        balance += (expense.amount - currentUserShare)
                    } else {
                        // Someone else paid: Balance -= (User's share)
                        balance -= currentUserShare
                    }
                }
            }
        }
        return balance
    }
    
    var totalToGet: Double {
        guard let currentUser = appState.currentUser else { return 0 }
        var total: Double = 0
        for group in userGroups {
            var groupBal: Double = 0
            for expense in group.expenses {
                let share = expense.splitDetails.first(where: { $0.user?.id == currentUser.id })?.amount ?? 0
                if expense.paidBy?.id == currentUser.id {
                    groupBal += (expense.amount - share)
                } else {
                    groupBal -= share
                }
            }
            if groupBal > 0 { total += groupBal }
        }
        return total
    }

    var totalToOwe: Double {
        guard let currentUser = appState.currentUser else { return 0 }
        var total: Double = 0
        for group in userGroups {
            var groupBal: Double = 0
            for expense in group.expenses {
                let share = expense.splitDetails.first(where: { $0.user?.id == currentUser.id })?.amount ?? 0
                if expense.paidBy?.id == currentUser.id {
                    groupBal += (expense.amount - share)
                } else {
                    groupBal -= share
                }
            }
            if groupBal < 0 { total += abs(groupBal) }
        }
        return total
    }
    
    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning,"
        } else if hour < 17 {
            return "Good afternoon,"
        } else {
            return "Good evening,"
        }
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            // Tappable avatar → Profile
                            Button {
                                hapticFeedback(.light)
                                showingProfile = true
                            } label: {
                                ZStack {
                                    if let data = appState.currentUser?.profileImageData,
                                       let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.blue.opacity(0.25), lineWidth: 1.5))
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            Text(String((appState.currentUser?.firstName.prefix(1) ?? "?")).uppercased())
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            .sheet(isPresented: $showingProfile) {
                                ProfileView()
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(timeBasedGreeting)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(appState.currentUser?.firstName ?? "Friend")
                                    .font(.system(size: 24, weight: .bold))
                            }

                            Spacer()
                            
                            Button {
                                hapticFeedback(.light)
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44, alignment: .trailing)
                            }
                            .sheet(isPresented: $showingSettings) {
                                SettingsView()
                            }
                        }
                        .padding(.horizontal)
                        
                        // Compact Theme-Responsive Dashboard
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("OVERALL BALANCE")
                                        .font(.system(size: 10, weight: .bold))
                                        .kerning(1)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("₹")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(String(format: "%.2f", totalBalance))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                    }
                                }
                                Spacer()
                                
                                // Compact Status Badge
                                let statusText: String = {
                                    if totalBalance > 0 { return "YOU ARE OWED" }
                                    else if totalBalance < 0 { return "YOU OWE" }
                                    else { return "SETTLED" }
                                }()
                                
                                Text(statusText)
                                    .font(.system(size: 9, weight: .heavy))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(totalBalance > 0 ? Color.green.opacity(0.15) : (totalBalance < 0 ? Color.red.opacity(0.15) : Color.gray.opacity(0.15)))
                                    .clipShape(Capsule())
                                    .foregroundColor(totalBalance > 0 ? .green : (totalBalance < 0 ? .red : .gray))
                            }
                            
                            Divider()
                            
                            HStack(spacing: 0) {
                                // You get
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("You get")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text("₹\(String(format: "%.0f", totalToGet))")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // You owe
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("You owe")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text("₹\(String(format: "%.0f", totalToOwe))")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                    
                    // Groups List
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Your Groups")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        
                        if userGroups.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color(.systemGray4))
                                Text("No groups yet")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Create a group to start splitting expenses with friends.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            List {
                                ForEach(filteredGroups) { group in
                                    Group {
                                        NavigationLink(destination: GroupChatView(group: group)) {
                                            GroupRowView(group: group, editMode: editMode, onRename: {
                                                groupToRename = group
                                                newGroupName = group.name
                                                showingRenameAlert = true
                                            })
                                        }
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            modelContext.delete(group)
                                        } label: {
                                            Label("Delete Group", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            hapticFeedback(.light)
                                            groupToRename = group
                                            newGroupName = group.name
                                            showingRenameAlert = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            hapticFeedback(.medium)
                                            modelContext.delete(group)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            .background(Color.clear)
                        }
                    }
                    // ── Bottom bar: search + compact FAB ────────────
                    HStack(spacing: 10) {
                        // Search pill
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search groups...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($isSearchFocused)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(VisualBlurView(style: .systemThinMaterial))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                        )

                        if isSearchFocused || !searchText.isEmpty {
                            // Cancel button replaces FAB during search
                            Button("Cancel") {
                                withAnimation {
                                    searchText = ""
                                    isSearchFocused = false
                                }
                            }
                            .foregroundColor(.blue)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            // Compact circular FAB
                            Button(action: {
                                hapticFeedback(.light)
                                showingCreateGroup = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 46, height: 46)
                                        .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFocused)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: searchText.isEmpty)

                }
                .sheet(isPresented: $showingCreateGroup) {
                    CreateGroupView()
                }
                .alert("Rename Group", isPresented: $showingRenameAlert) {
                    TextField("Group Name", text: $newGroupName)
                    Button("Cancel", role: .cancel) { }
                    Button("Save") {
                        if let group = groupToRename, !newGroupName.isEmpty {
                            hapticFeedback(.success)
                            group.name = String(newGroupName.prefix(25))
                            try? modelContext.save()
                        }
                    }
                } message: {
                    Text("Enter a new name for '\(groupToRename?.name ?? "this group")'")
                }

            }
            .environment(\.editMode, $editMode)
            .onAppear {
                NotificationService.shared.updatePendingExpenseReminders(totalOwed: totalToOwe)
            }
            .onChange(of: totalToOwe) { _, newOwed in
                NotificationService.shared.updatePendingExpenseReminders(totalOwed: newOwed)
            }
        }
    }
    
    private func deleteGroups(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let group = filteredGroups[index]
                modelContext.delete(group)
            }
        }
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        HapticManager.playNotification(type)
    }
    
    private func hapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticManager.playImpact(type)
    }
}


#Preview {
    HomeView()
        .environment(AppState())
}

struct GroupRowView: View {
    @Environment(AppState.self) var appState
    let group: SplitGroup
    let editMode: EditMode
    let onRename: () -> Void
    
    private var groupBalance: Double {
        guard let currentUser = appState.currentUser else { return 0 }
        var balance: Double = 0
        for expense in group.expenses {
            let currentUserShare = expense.splitDetails.first(where: { $0.user?.id == currentUser.id })?.amount ?? 0
            if let paidBy = expense.paidBy {
                if paidBy.id == currentUser.id {
                    balance += (expense.amount - currentUserShare)
                } else {
                    balance -= currentUserShare
                }
            }
        }
        return balance
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let data = group.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue.opacity(0.15), lineWidth: 1))
                } else {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                    Text(String(group.name.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(group.members.count) members")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if abs(groupBalance) > 0.01 {
                    Text(groupBalance > 0 ? "You get" : "You owe")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text("\(group.currencySymbol)\(String(format: "%.0f", abs(groupBalance)))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(groupBalance > 0 ? .green : .red)
                } else {
                    Text("Settled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
