import SwiftUI
import SwiftData
import Contacts

struct ManageMembersView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) var appState
    let group: SplitGroup

    @State private var selectedMemberIds: Set<UUID> = []
    @State private var selectedContactIds: Set<UUID> = []
    @State private var deviceContacts: [DeviceContact] = []
    @State private var hasFetchedContacts = false
    @State private var searchText = ""

    // Contacts picked to add (not already in group)
    var selectedNewContacts: [DeviceContact] {
        deviceContacts.filter { contact in
            selectedContactIds.contains(contact.id) &&
            !group.members.contains(where: { $0.phoneNumber == contact.phoneNumber })
        }
    }

    // Unselected contacts not already in group — filtered by search
    var filteredUnselectedContacts: [DeviceContact] {
        let unselected = deviceContacts.filter { contact in
            !selectedContactIds.contains(contact.id) &&
            !group.members.contains(where: { $0.phoneNumber == contact.phoneNumber })
        }
        if searchText.isEmpty { return unselected }
        return unselected.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Current members card ─────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Current Members", systemImage: "person.3.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                         VStack(spacing: 0) {
                            ForEach(Array(group.members.enumerated()), id: \.element.id) { idx, member in
                                memberRow(member, index: idx)
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .padding(.horizontal)
                    }

                    // ── Selected-to-add chips ────────────────────
                    if !selectedNewContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("\(selectedNewContacts.count) to Add", systemImage: "person.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(selectedNewContacts) { contact in
                                        Button {
                                            withAnimation(.spring(response: 0.25)) {
                                                _ = selectedContactIds.remove(contact.id)
                                            }
                                        } label: {
                                            VStack(spacing: 6) {
                                                ZStack(alignment: .topTrailing) {
                                                    Circle()
                                                        .fill(Color.blue)
                                                        .frame(width: 48, height: 48)
                                                        .overlay(
                                                            Text(String(contact.fullName.prefix(1)).uppercased())
                                                                .font(.system(size: 18, weight: .bold))
                                                                .foregroundColor(.white)
                                                        )
                                                    ZStack {
                                                        Circle().fill(Color.red).frame(width: 18, height: 18)
                                                        Image(systemName: "xmark")
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundColor(.white)
                                                    }
                                                    .offset(x: 3, y: -3)
                                                }
                                                Text(contact.firstName)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                            }
                                            .frame(width: 60)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // ── Add from contacts ────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label(searchText.isEmpty ? "Add From Contacts" : "Search Results",
                              systemImage: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        // Inline search bar
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Search contacts...", text: $searchText)
                                .textInputAutocapitalization(.never)
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        if hasFetchedContacts {
                            if filteredUnselectedContacts.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: searchText.isEmpty ? "person.2.slash" : "person.slash")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color(.systemGray3))
                                        Text(searchText.isEmpty ? "All contacts already added" : "No contacts found")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 24)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(filteredUnselectedContacts.enumerated()), id: \.element.id) { idx, contact in
                                        ContactRow(
                                            contact: contact,
                                            isSelected: selectedContactIds.contains(contact.id)
                                        ) {
                                            withAnimation(.spring(response: 0.25)) {
                                                if selectedContactIds.contains(contact.id) {
                                                    _ = selectedContactIds.remove(contact.id)
                                                } else {
                                                    _ = selectedContactIds.insert(contact.id)
                                                }
                                            }
                                        }
                                        if idx < filteredUnselectedContacts.count - 1 {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                                .padding(.horizontal)
                            }
                        } else {
                            HStack {
                                Spacer()
                                ProgressView().padding(.vertical, 24)
                                Spacer()
                            }
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Manage Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: updateMembers) {
                        Text("Update")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                selectedMemberIds = Set(group.members.map { $0.id })
                fetchContacts()
            }
            .onTapGesture { hideKeyboard() }
        }
    }

    @ViewBuilder
    private func memberRow(_ member: AppUser, index idx: Int) -> some View {
        let isCurrentUser = member.id == appState.currentUser?.id
        let isSelected = selectedMemberIds.contains(member.id)
        Button {
            guard !isCurrentUser else { return }
            withAnimation(.spring(response: 0.25)) {
                if isSelected { _ = selectedMemberIds.remove(member.id) }
                else          { _ = selectedMemberIds.insert(member.id) }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(String(member.fullName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    if isCurrentUser {
                        Text("You").font(.system(size: 12)).foregroundColor(.blue)
                    } else if !member.phoneNumber.isEmpty {
                        Text(member.phoneNumber).font(.system(size: 13)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: (isCurrentUser || isSelected) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isCurrentUser ? Color(.systemGray3) : (isSelected ? .blue : Color(.systemGray3)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if idx < group.members.count - 1 {
            Divider().padding(.leading, 68)
        }
    }

    private func fetchContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey,
                        CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var contacts: [DeviceContact] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                let fn = contact.givenName; let ln = contact.familyName
                if !fn.isEmpty || !ln.isEmpty {
                    contacts.append(DeviceContact(firstName: fn, lastName: ln,
                                                  phoneNumber: contact.phoneNumbers.first?.value.stringValue ?? ""))
                }
            }
            DispatchQueue.main.async {
                self.deviceContacts = contacts
                self.hasFetchedContacts = true
            }
        }
    }

    private func updateMembers() {
        for member in group.members where !selectedMemberIds.contains(member.id) {
            if let idx = group.members.firstIndex(where: { $0.id == member.id }) {
                group.members.remove(at: idx)
            }
        }
        for contact in deviceContacts where selectedContactIds.contains(contact.id) {
            let phone = contact.phoneNumber
            let fname = contact.firstName
            let lname = contact.lastName
            
            // Check if user already exists by phone number
            let descriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.phoneNumber == phone })
            if let existing = try? modelContext.fetch(descriptor).first {
                if !group.members.contains(where: { $0.id == existing.id }) {
                    group.members.append(existing)
                }
            } else {
                let u = AppUser(firstName: fname, lastName: lname,
                                email: "", phoneNumber: phone, password: "")
                modelContext.insert(u)
                group.members.append(u)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
