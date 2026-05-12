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
    @State private var showingSettleUp = false
    @State private var showingAddMembers = false
    @State private var showingGroupProfile = false
    @State private var expenseToEdit: Expense? = nil
    @State private var expenseToDelete: Expense? = nil
    @State private var showingDeleteConfirmation = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var scanErrorMessage: String? = nil
    @State private var showingScanError = false
    @State private var highlightedExpenseId: UUID? = nil
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                membersHeader
                messageThread
            }
            
            actionButtons
        }
        .onChange(of: selectedItem) { _, newItem in
            handlePhotosPickerChange(newItem)
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
            groupToolbarItem
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
        .sheet(isPresented: $showingSettleUp) {
            SettleUpView(group: group)
        }
        .sheet(isPresented: $showingGroupProfile) {
            GroupProfileView(group: group)
        }
        .sheet(isPresented: $showingAddMembers) {
            ManageMembersView(group: group)
        }
    }
    
    private var membersHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Members")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("\(group.members.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(group.members) { member in
                        VStack(spacing: 6) {
                            if let data = member.profileImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 46, height: 46)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue.opacity(0.1), lineWidth: 1))
                            } else {
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Text(String(member.firstName.prefix(1)).uppercased())
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.blue)
                                    )
                            }
                            
                            Text(member.firstName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 14)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            VStack {
                Spacer()
                Divider()
            }
        )
    }
    
    @ViewBuilder
    private var messageThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if group.expenses.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(group.expenses.sorted(by: { $0.date < $1.date })) { expense in
                            ExpenseRow(
                                expense: expense,
                                group: group,
                                currentUserId: appState.currentUser?.id,
                                onEdit: { expenseToEdit = $0 },
                                onDelete: {
                                    expenseToDelete = $0
                                    showingDeleteConfirmation = true
                                },
                                onScrollTo: { id in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                    // Flash the highlight
                                    highlightedExpenseId = id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation(.easeOut(duration: 0.5)) {
                                            if highlightedExpenseId == id {
                                                highlightedExpenseId = nil
                                            }
                                        }
                                    }
                                },
                                onSettle: { exp in
                                    settleSpecificExpense(exp)
                                },
                                onMarkAsSettled: { exp, detail in
                                    markOtherAsSettled(expense: exp, detail: detail)
                                },
                                isHighlighted: highlightedExpenseId == expense.id
                            )
                        }
                    }
                    
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
    
    @ViewBuilder
    private var emptyStateView: some View {
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
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            settleButton
            scanButton
            splitButton
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var settleButton: some View {
        Button(action: {
            hapticFeedback(.medium)
            showingSettleUp = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Settle")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    @ViewBuilder
    private var scanButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 6) {
                if appState.isProcessingOCR {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                }
                Text("Scan")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(appState.isProcessingOCR)
    }
    
    @ViewBuilder
    private var splitButton: some View {
        Button(action: {
            hapticFeedback(.medium)
            showingSplitMoney = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Split")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 6)
        }
    }
    
    private var groupToolbarItem: some ToolbarContent {
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
                    VStack(alignment: .center, spacing: 0) {
                        Text(group.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
    }
    
    private func handlePhotosPickerChange(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await processSelectedImage(image)
            } else if newItem != nil {
                await MainActor.run {
                    scanErrorMessage = "Failed to load image from library."
                    showingScanError = true
                }
            }
        }
    }
}
    
struct ExpenseRow: View {
    let expense: Expense
    let group: SplitGroup
    let currentUserId: UUID?
    let onEdit: (Expense) -> Void
    let onDelete: (Expense) -> Void
    var onScrollTo: ((UUID) -> Void)? = nil
    var onSettle: ((Expense) -> Void)? = nil
    var onMarkAsSettled: ((Expense, SplitDetail) -> Void)? = nil
    var isHighlighted: Bool = false
    
    var isMe: Bool {
        let paidById = expense.paidBy?.id
        return paidById != nil && paidById == currentUserId
    }
    
    var body: some View {
        ExpenseMessageBubble(expense: expense, group: group, isCurrentUser: isMe, onScrollTo: onScrollTo, onSettle: onSettle, onMarkAsSettled: onMarkAsSettled, isHighlighted: isHighlighted)
            .id(expense.id)
            .contextMenu {
                if !expense.isSettlement {
                    Button {
                        hapticFeedback(.success)
                        onEdit(expense)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        hapticFeedback(.success)
                        onSettle?(expense)
                    } label: {
                        Label("Settle this expense", systemImage: "checkmark.circle")
                    }
                }
                
                Button(role: .destructive) {
                    hapticFeedback(.warning)
                    onDelete(expense)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

extension GroupChatView {
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
        }
    }
    
    private func settleSpecificExpense(_ expense: Expense) {
        guard let currentUser = appState.currentUser else { return }
        
        // Find how much the current user owes for THIS expense
        let myShareDetail = expense.splitDetails.first(where: { $0.user?.id == currentUser.id })
        guard let share = myShareDetail?.amount, share > 0 else { return }
        
        // If current user is the one who paid, they can't "settle" it with themselves
        guard expense.paidBy?.id != currentUser.id else { return }
        
        let payer = currentUser
        let receiver = expense.paidBy ?? currentUser
        
        let settlement = Expense(
            title: "Settled: \(expense.title)",
            amount: share,
            date: Date(),
            splitType: .custom,
            splitDetails: [
                SplitDetail(user: receiver, amount: share)
            ],
            paidBy: payer,
            isSettlement: true,
            relatedExpenseId: expense.id
        )
        
        group.expenses.append(settlement)
        try? modelContext.save()
        hapticFeedback(.success)
    }
    
    private func markOtherAsSettled(expense: Expense, detail: SplitDetail) {
        guard let participant = detail.user else { return }
        guard let payer = expense.paidBy else { return }
        
        let settlement = Expense(
            title: "Settled: \(expense.title)",
            amount: detail.amount,
            date: Date(),
            splitType: .custom,
            splitDetails: [
                SplitDetail(user: payer, amount: detail.amount)
            ],
            paidBy: participant,
            isSettlement: true,
            relatedExpenseId: expense.id
        )
        
        group.expenses.append(settlement)
        try? modelContext.save()
        hapticFeedback(.success)
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
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
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
    var onScrollTo: ((UUID) -> Void)? = nil
    var onSettle: ((Expense) -> Void)? = nil
    var onMarkAsSettled: ((Expense, SplitDetail) -> Void)? = nil
    var isHighlighted: Bool = false
    @Environment(AppState.self) var appState
    
    private var relatedExpense: Expense? {
        guard let rid = expense.relatedExpenseId else { return nil }
        return group.expenses.first(where: { $0.id == rid })
    }
    
    private var isAlreadySettledByMe: Bool {
        guard let currentUser = appState.currentUser else { return false }
        return group.expenses.contains { $0.isSettlement && $0.relatedExpenseId == expense.id && $0.paidBy?.id == currentUser.id }
    }
    
    private func checkIsSettled(detail: SplitDetail) -> Bool {
        guard let participantId = detail.user?.id, !expense.isSettlement else { return false }
        let expensePayerId = expense.paidBy?.id
        
        return group.expenses.contains { e in
            // 1. Direct link to this specific expense
            if e.isSettlement && e.relatedExpenseId == expense.id && e.paidBy?.id == participantId {
                return true
            }
            
            // 2. Global "Settle Up" that happened AFTER this expense between these same two people
            if e.isFullSettlement && e.date > expense.date {
                let ePaidById = e.paidBy?.id
                let eReceivedById = e.splitDetails.first?.user?.id
                
                let isPayerInvolved = (ePaidById == participantId || eReceivedById == participantId)
                let isReceiverInvolved = (ePaidById == expensePayerId || eReceivedById == expensePayerId)
                return isPayerInvolved && isReceiverInvolved
            }
            
            return false
        }
    }
    
    private var highlightColor: Color {
        if isCurrentUser {
            return .white
        } else {
            return .blue
        }
    }
    
    @ViewBuilder
    private func splitDetailRow(_ detail: SplitDetail) -> some View {
        HStack(spacing: 8) {
            Text(detail.user?.firstName ?? "Unknown")
                .font(.system(size: 12))
            
            if !expense.isSettlement {
                if checkIsSettled(detail: detail) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                } else if detail.user?.id == appState.currentUser?.id && expense.paidBy?.id != appState.currentUser?.id {
                    Button {
                        onSettle?(expense)
                    } label: {
                        Text("Settle")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                } else if expense.paidBy?.id == appState.currentUser?.id && detail.user?.id != appState.currentUser?.id {
                    Button {
                        onMarkAsSettled?(expense, detail)
                    } label: {
                        Text("Paid?")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            Text("\(group.currencySymbol)\(String(format: "%.2f", detail.amount))")
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                // Reply/Link Header
                if let related = relatedExpense {
                    Button {
                        onScrollTo?(related.id)
                    } label: {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(isCurrentUser ? Color.white.opacity(0.5) : Color.blue)
                                .frame(width: 3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(related.isSettlement ? "Settlement" : related.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                                Text("\(group.currencySymbol)\(String(format: "%.2f", related.amount))")
                                    .font(.system(size: 10))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isCurrentUser ? Color.white.opacity(0.1) : Color.blue.opacity(0.05))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                }

                // Header Info
                HStack(alignment: .center) {
                    if expense.isSettlement {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(isCurrentUser ? .white : .green)
                            .font(.system(size: 14))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(expense.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .lineLimit(1)
                        
                        Text(expense.date, style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .gray)
                    }
                    
                    Spacer()
                    
                    Text("\(group.currencySymbol)\(String(format: "%.2f", expense.amount))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isCurrentUser ? .white : (expense.isSettlement ? .green : .blue))
                }
                
                if !expense.isSettlement {
                    // Payer info
                    if !isCurrentUser, let payer = expense.paidBy {
                        Text("Paid by \(payer.firstName)")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                    
                    Divider()
                        .background(isCurrentUser ? Color.white.opacity(0.3) : Color(.separator))
                    
                    // Split Details
                    VStack(spacing: 6) {
                        ForEach(expense.splitDetails.prefix(5)) { detail in
                            splitDetailRow(detail)
                        }
                        
                        if expense.splitDetails.count > 5 {
                            Text("+ \(expense.splitDetails.count - 5) more")
                                .font(.system(size: 10))
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .primary.opacity(0.8))
                } else {
                    // Settlement specific footer
                    let receiverName = expense.splitDetails.first?.user?.firstName ?? "Unknown"
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("\(expense.paidBy?.firstName ?? "Unknown") paid \(receiverName)")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(12)
            .background(
                Group {
                    if isCurrentUser {
                        LinearGradient(
                            gradient: Gradient(colors: expense.isSettlement ? [Color.green, Color.green.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.85)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color(.secondarySystemGroupedBackground)
                    }
                }
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighlighted ? highlightColor : (expense.isSettlement ? Color.green.opacity(0.3) : Color.clear), lineWidth: isHighlighted ? 2 : 1)
            )
            .scaleEffect(isHighlighted ? 1.03 : 1.0)
            .shadow(color: isHighlighted ? highlightColor.opacity(0.4) : Color.black.opacity(0.04), radius: isHighlighted ? 10 : 4, x: 0, y: isHighlighted ? 5 : 2)
            
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
