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
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 16) {
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
                            .navigationDestination(isPresented: $showingProfile) {
                                ProfileView()
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hello,")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(appState.currentUser?.firstName ?? "Friend")
                                    .font(.system(size: 24, weight: .bold))
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Summary Card
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Balance")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("₹\(String(format: "%.2f", totalBalance))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .contentTransition(.numericText())
                            }
                            Spacer()
                            Image(systemName: totalBalance >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(24)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [totalBalance >= 0 ? Color.blue : Color.red, totalBalance >= 0 ? Color.blue.opacity(0.7) : Color.red.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(24)
                        .padding(.horizontal)
                        .shadow(color: (totalBalance >= 0 ? Color.blue : Color.red).opacity(0.3), radius: 15, x: 0, y: 10)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    
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
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    private func hapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: type)
        generator.impactOccurred()
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
