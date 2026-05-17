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
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.members) { member in
                        memberAvatar(member: member)
                    }
                }
            }
            
            if group.members.count > 5 {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(.systemGray3))
                    .padding(.leading, 2)
            }
            
            Spacer()
            
            Button(action: {
                showingAddMembers = true
            }) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(
            VStack {
                Spacer()
                Divider()
            }
        )
    }
    
    @ViewBuilder
    private func memberAvatar(member: AppUser) -> some View {
        if let data = member.profileImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(member.firstName.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                )
        }
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
        HStack(spacing: 16) {
            settleButton
            Divider()
                .frame(height: 20)
            scanButton
            Divider()
                .frame(height: 20)
            splitButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            VisualBlurView(style: .systemChromeMaterial)
                .clipShape(Capsule())
        )
        .overlay(
            Capsule()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private var settleButton: some View {
        Button(action: {
            hapticFeedback(.medium)
            showingSettleUp = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.green)
                Text("Settle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private var scanButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 6) {
                if appState.isProcessingOCR {
                    ProgressView()
                        .tint(.primary)
                } else {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.purple)
                }
                Text("Scan")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
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
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Split")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
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
        HapticManager.playNotification(type)
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticManager.playImpact(style)
    }
}

