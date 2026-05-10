import SwiftUI
import SwiftData
import Contacts

struct DeviceContact: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let phoneNumber: String
    
    var fullName: String {
        return [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [SplitGroup]
    
    @State private var searchText = ""
    @State private var showingCreateGroup = false
    @State private var showingLogoutConfirmation = false
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
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hello,")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(appState.currentUser?.firstName ?? "Friend")
                                    .font(.system(size: 28, weight: .bold))
                            }
                            Spacer()
                            
                            Button(action: {
                                 hapticFeedback(.light)
                                 showingLogoutConfirmation = true
                             }) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            .alert("Log Out", isPresented: $showingLogoutConfirmation) {
                                Button("Cancel", role: .cancel) { }
                                Button("Log Out", role: .destructive) {
                                    withAnimation {
                                        appState.isAuthenticated = false
                                        loggedInUserId = nil
                                    }
                                }
                            } message: {
                                Text("Are you sure you want to log out? You'll need to sign in again to access your groups.")
                            }
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
                            Button(action: {
                                hapticFeedback(.light)
                                showingCreateGroup = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("New Group")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                            }
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
                }
                .overlay(alignment: .bottom) {
                    // Floating Search Bar at the bottom - ONLY on Home
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search groups...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($isSearchFocused)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
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
                            Button("Cancel") {
                                withAnimation {
                                    searchText = ""
                                    isSearchFocused = false
                                }
                            }
                            .foregroundColor(.blue)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
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
                            group.name = newGroupName
                            try? modelContext.save()
                        }
                    }
                } message: {
                    Text("Enter a new name for '\(groupToRename?.name ?? "this group")'")
                }
                .alert("Log Out", isPresented: $showingLogoutConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Log Out", role: .destructive) {
                        withAnimation {
                            appState.isAuthenticated = false
                            loggedInUserId = nil
                        }
                    }
                } message: {
                    Text("Are you sure you want to log out? You'll need to sign in again to access your groups.")
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

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) var appState
    
    @State private var groupName = ""
    @State private var selectedCurrency = "🇮🇳 ₹ INR"
    @State private var selectedContacts: Set<UUID> = []
    @State private var deviceContacts: [DeviceContact] = []
    @State private var hasFetchedContacts = false
    
    let currencies = [
        "🇮🇳 ₹ INR", "🇺🇸 $ USD", "🇬🇧 £ GBP", "🇦🇺 A$ AUD", "🇯🇵 ¥ JPY", "🇪🇺 € EUR", "🇨🇳 ¥ CNY"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if hasFetchedContacts {
                    Section(header: Text("Select Members")) {
                        ForEach(deviceContacts) { contact in
                            HStack {
                                Text(contact.fullName)
                                Spacer()
                                if selectedContacts.contains(contact.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedContacts.contains(contact.id) {
                                    selectedContacts.remove(contact.id)
                                } else {
                                    selectedContacts.insert(contact.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty)
                }
            }
            .onAppear {
                if !hasFetchedContacts {
                    fetchContacts()
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private func fetchContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                
                var contacts: [DeviceContact] = []
                do {
                    try store.enumerateContacts(with: request) { contact, stop in
                        let firstName = contact.givenName
                        let lastName = contact.familyName
                        let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
                        
                        if !firstName.isEmpty || !lastName.isEmpty {
                            let deviceContact = DeviceContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber)
                            contacts.append(deviceContact)
                        }
                    }
                    DispatchQueue.main.async {
                        self.deviceContacts = contacts
                        self.hasFetchedContacts = true
                    }
                } catch {
                    print("Error fetching contacts: \(error)")
                }
            } else {
                print("Access denied")
            }
        }
    }
    
    private func createGroup() {
        var members: [AppUser] = []
        if let current = appState.currentUser {
            members.append(current)
        }
        
        let selectedDeviceContacts = deviceContacts.filter { selectedContacts.contains($0.id) }
        for deviceContact in selectedDeviceContacts {
            let newUser = AppUser(firstName: deviceContact.firstName, lastName: deviceContact.lastName, email: "", phoneNumber: deviceContact.phoneNumber, password: "")
            modelContext.insert(newUser)
            members.append(newUser)
        }
        
        let newGroup = SplitGroup(name: groupName, currency: selectedCurrency, members: members)
        modelContext.insert(newGroup)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}

struct GroupRowView: View {
    let group: SplitGroup
    let editMode: EditMode
    let onRename: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                
                Text(String(group.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                Text("\(group.members.count) members")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
