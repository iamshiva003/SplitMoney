import SwiftUI
import SwiftData
import Contacts
import PhotosUI

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) var appState

    @State private var groupName = ""
    @State private var selectedCurrency = "🇮🇳 ₹ INR"
    @State private var selectedContacts: Set<UUID> = []
    @State private var deviceContacts: [DeviceContact] = []
    @State private var hasFetchedContacts = false
    @State private var searchText = ""
    @FocusState private var isGroupNameFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var groupImageData: Data? = nil
    @State private var showingPhotoPicker = false

    let currencies = [
        "🇮🇳 ₹ INR", "🇺🇸 $ USD", "🇬🇧 £ GBP",
        "🇦🇺 A$ AUD", "🇯🇵 ¥ JPY", "🇪🇺 € EUR", "🇨🇳 ¥ CNY"
    ]

    var selectedDeviceContacts: [DeviceContact] {
        deviceContacts.filter { selectedContacts.contains($0.id) }
    }

    var filteredContacts: [DeviceContact] {
        let unselected = deviceContacts.filter { !selectedContacts.contains($0.id) }
        if searchText.isEmpty { return unselected }
        return unselected.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Group Photo picker ──────────────────────────
                    HStack {
                        Spacer()
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            ZStack {
                                if let data = groupImageData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(.blue)
                                                Text("Add Photo")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.blue)
                                            }
                                        )
                                }
                                if groupImageData != nil {
                                    ZStack {
                                        Circle().fill(Color.blue).frame(width: 26, height: 26)
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 30, y: 30)
                                }
                            }
                        }
                        .photosPicker(isPresented: $showingPhotoPicker,
                                      selection: $selectedPhotoItem,
                                      matching: .images)
                        .onChange(of: selectedPhotoItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    groupImageData = data
                                    selectedPhotoItem = nil   // reset so picker always starts fresh
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    // ── Group Name card ──────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Group Name", systemImage: "person.3.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack {
                            TextField("e.g. Trip to Goa", text: $groupName)
                                .font(.system(size: 17))
                                .focused($isGroupNameFocused)
                                .onChange(of: groupName) { _, new in
                                    if new.count > 25 { groupName = String(new.prefix(25)) }
                                }
                            Spacer()
                            Text("\(groupName.count)/25")
                                .font(.caption2)
                                .foregroundColor(groupName.count >= 25 ? .red : .secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // ── Currency picker ──────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Currency", systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(currencies, id: \.self) { currency in
                                    let isSelected = selectedCurrency == currency
                                    Button {
                                        withAnimation(.spring(response: 0.25)) {
                                            selectedCurrency = currency
                                        }
                                    } label: {
                                        Text(currency)
                                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(
                                                isSelected
                                                    ? AnyView(LinearGradient(
                                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                                                    : AnyView(Color(.systemGray6))
                                            )
                                            .clipShape(Capsule())
                                            .shadow(color: isSelected ? Color.blue.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }
                    }

                    // ── Selected member chips ────────────────────
                    if !selectedDeviceContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("\(selectedDeviceContacts.count) Selected", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(selectedDeviceContacts) { contact in
                                        Button {
                                            withAnimation(.spring(response: 0.25)) {
                                                _ = selectedContacts.remove(contact.id)
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

                    // ── Contacts list ────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label(searchText.isEmpty ? "Add Members" : "Search Results",
                              systemImage: "person.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        // Search bar
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
                            if filteredContacts.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "person.slash")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color(.systemGray3))
                                        Text("No contacts found")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 24)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { idx, contact in
                                        ContactRow(
                                            contact: contact,
                                            isSelected: selectedContacts.contains(contact.id)
                                        ) {
                                            withAnimation(.spring(response: 0.25)) {
                                                if selectedContacts.contains(contact.id) {
                                                    _ = selectedContacts.remove(contact.id)
                                                } else {
                                                    _ = selectedContacts.insert(contact.id)
                                                }
                                            }
                                        }
                                        if idx < filteredContacts.count - 1 {
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
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createGroup) {
                        Text("Create")
                            .fontWeight(.semibold)
                            .foregroundColor(groupName.isEmpty ? .gray : .blue)
                    }
                    .disabled(groupName.isEmpty)
                }
            }
            .onAppear {
                if !hasFetchedContacts { fetchContacts() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isGroupNameFocused = true
                }
            }
            .onTapGesture { hideKeyboard() }
        }
    }

    // MARK: - Data
    private func fetchContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey,
                        CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var contacts: [DeviceContact] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                let fn = contact.givenName
                let ln = contact.familyName
                if !fn.isEmpty || !ln.isEmpty {
                    contacts.append(DeviceContact(
                        firstName: fn, lastName: ln,
                        phoneNumber: contact.phoneNumbers.first?.value.stringValue ?? ""))
                }
            }
            DispatchQueue.main.async {
                self.deviceContacts = contacts
                self.hasFetchedContacts = true
            }
        }
    }

    private func createGroup() {
        var members: [AppUser] = []
        if let current = appState.currentUser { members.append(current) }
        
        for contact in deviceContacts.filter({ selectedContacts.contains($0.id) }) {
            let phone = contact.phoneNumber
            let fname = contact.firstName
            let lname = contact.lastName
            
            // Check if user already exists by phone number
            let descriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.phoneNumber == phone })
            if let existing = try? modelContext.fetch(descriptor).first {
                if !members.contains(where: { $0.id == existing.id }) {
                    members.append(existing)
                }
            } else {
                let u = AppUser(firstName: fname, lastName: lname,
                                email: "", phoneNumber: phone, password: "")
                modelContext.insert(u)
                members.append(u)
            }
        }
        
        let group = SplitGroup(name: groupName, currency: selectedCurrency,
                               imageData: groupImageData, members: members)
        modelContext.insert(group)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Contact row
struct ContactRow: View {
    let contact: DeviceContact
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(String(contact.fullName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    if !contact.phoneNumber.isEmpty {
                        Text(contact.phoneNumber)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
