import SwiftUI
import SwiftData
import Contacts
import PhotosUI
import Vision

struct GroupChatView: View {
    let group: SplitGroup
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) var appState
    @State private var showingSplitMoney = false
    @State private var showingAddMembers = false
    @State private var showingGroupProfile = false
    @State private var expenseToEdit: Expense? = nil
    @State private var expenseToDelete: Expense? = nil
    @State private var showingDeleteConfirmation = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var scanErrorMessage: String? = nil
    @State private var showingScanError = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header with Member Avatars and Names
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(group.members) { member in
                            VStack(spacing: 6) {
                                if let data = member.profileImageData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Text(String(member.firstName.prefix(1)).uppercased())
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.blue)
                                        )
                                }
                                
                                Text(member.firstName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground).opacity(0.8))
                .background(VisualBlurView(style: .systemUltraThinMaterial)) // Glassmorphism
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if group.expenses.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(Color(.systemGray4))
                                    Text("No splits yet")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Text("Start a conversation by adding an expense.")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 100)
                                .padding(.horizontal, 40)
                            } else {
                                let sortedExpenses = group.expenses.sorted(by: { $0.date < $1.date })
                                ForEach(sortedExpenses) { expense in
                                    let currentUserId = appState.currentUser?.id
                                    let paidById = expense.paidBy?.id
                                    let isMe = paidById != nil && paidById == currentUserId
                                    
                                    ExpenseMessageBubble(expense: expense, group: group, isCurrentUser: isMe)
                                        .id(expense.id)
                                        .contextMenu {
                                            Button {
                                                hapticFeedback(.success)
                                                expenseToEdit = expense
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive) {
                                                hapticFeedback(.warning)
                                                expenseToDelete = expense
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            
                            // Large spacer at the bottom to ensure content isn't hidden by FAB
                            Spacer()
                                .frame(height: 120)
                                .id("bottom_anchor")
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    .background(Color(.systemGroupedBackground).opacity(0.5))
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: group.expenses.count) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            
            // Modern Floating Action Buttons
            HStack(spacing: 12) {
                // Scan Receipt Button
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 8) {
                        if appState.isProcessingOCR {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text("Scan")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(appState.isProcessingOCR)
                
                // Split Money Button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showingSplitMoney = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Split")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 6)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 30)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await processSelectedImage(image)
                } else {
                    await MainActor.run {
                        scanErrorMessage = "Failed to load image from library."
                        showingScanError = true
                    }
                }
            }
        }
        .alert("Scan Error", isPresented: $showingScanError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(scanErrorMessage ?? "Unknown error")
        }
        .alert("Delete Expense?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { expenseToDelete = nil }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    deleteExpense(expense)
                }
            }
        } message: {
            Text("Are you sure you want to delete this expense? This action cannot be undone.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Tappable group name/avatar in the centre — acts as Group Profile entry
            ToolbarItem(placement: .principal) {
                Button {
                    showingGroupProfile = true
                } label: {
                    HStack(spacing: 8) {
                        if let data = group.imageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 30, height: 30)
                                Text(String(group.name.prefix(1)).uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("\(group.members.count) members")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSplitMoney) {
            SplitMoneyView(
                group: group,
                initialAmount: appState.pendingSharedAmount,
                initialNote: appState.pendingSharedNote
            )
        }
        .sheet(item: $expenseToEdit) { expense in
            SplitMoneyView(group: group, editingExpense: expense)
        }
        .sheet(isPresented: $showingGroupProfile) {
            GroupProfileView(group: group)
        }
        .sheet(isPresented: $showingAddMembers) {
            ManageMembersView(group: group)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
        }
    }
    
    private func processSelectedImage(_ image: UIImage) async {
        await MainActor.run { appState.isProcessingOCR = true }
        
        guard let cgImage = image.cgImage else {
            await MainActor.run { appState.isProcessingOCR = false }
            return
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            guard let observations = request.results else {
                await MainActor.run { appState.isProcessingOCR = false }
                return
            }
            
            await MainActor.run {
                // Use the NEW high-precision scoring logic
                appState.processScoringOCR(observations)
                
                appState.isProcessingOCR = false
                if appState.pendingSharedAmount != nil {
                    appState.showIncomingShareFlow = false
                    showingSplitMoney = true
                } else {
                    scanErrorMessage = "Couldn't find an amount in this image. Try a clearer screenshot of the UPI receipt."
                    showingScanError = true
                }
            }
        } catch {
            print("OCR Error: \(error)")
            await MainActor.run { appState.isProcessingOCR = false }
        }
    }
    
    private func deleteExpense(_ expense: Expense) {
        withAnimation {
            // Remove from group array first to update UI immediately
            if let index = group.expenses.firstIndex(where: { $0.id == expense.id }) {
                group.expenses.remove(at: index)
            }
            // Then delete from context
            modelContext.delete(expense)
            
            // Explicitly save context to persist changes
            try? modelContext.save()
        }
        expenseToDelete = nil
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

struct VisualBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct ExpenseMessageBubble: View {
    let expense: Expense
    let group: SplitGroup
    let isCurrentUser: Bool
    @Environment(AppState.self) var appState
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 40) }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 10) {
                // Header Info
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(isCurrentUser ? .white : .primary)
                        
                        Text(expense.date, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .gray)
                    }
                    
                    Spacer()
                    
                    Text("\(group.currencySymbol)\(String(format: "%.2f", expense.amount))")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(isCurrentUser ? .white : .blue)
                }
                
                // Payer info
                if !isCurrentUser, let payer = expense.paidBy {
                    Text("Paid by \(payer.firstName)")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Divider()
                    .background(isCurrentUser ? Color.white.opacity(0.3) : Color(.separator))
                
                // Split Details
                VStack(spacing: 6) {
                    ForEach(expense.splitDetails.prefix(3)) { detail in
                        HStack {
                            Text(detail.user?.firstName ?? "Unknown")
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(group.currencySymbol)\(String(format: "%.2f", detail.amount))")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    
                    if expense.splitDetails.count > 3 {
                        Text("+ \(expense.splitDetails.count - 3) more")
                            .font(.system(size: 11))
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .primary.opacity(0.8))
            }
            .padding(16)
            .background(
                Group {
                    if isCurrentUser {
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.85)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        Color(.secondarySystemGroupedBackground)
                    }
                }
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            if !isCurrentUser { Spacer(minLength: 40) }
        }
    }
}

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

                    Spacer().frame(height: 16)
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
