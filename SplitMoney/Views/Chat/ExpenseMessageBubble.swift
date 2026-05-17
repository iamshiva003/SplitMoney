import SwiftUI
import SwiftData

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
        HapticManager.playNotification(type)
    }
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
    
    private var settledExpensesForFullSettlement: [Expense] {
        guard expense.isFullSettlement else { return [] }
        guard let payerId = expense.paidBy?.id, let receiverId = expense.splitDetails.first?.user?.id else { return [] }
        
        let priorFullSettlementDate = group.expenses.filter { e in
            guard e.isFullSettlement, e.id != expense.id, e.date < expense.date else { return false }
            let ePaidById = e.paidBy?.id
            let eReceiverId = e.splitDetails.first?.user?.id
            let matches = (ePaidById == payerId && eReceiverId == receiverId) || (ePaidById == receiverId && eReceiverId == payerId)
            return matches
        }
        .map { $0.date }
        .max() ?? Date.distantPast
        
        return group.expenses.filter { e in
            guard !e.isSettlement, e.date > priorFullSettlementDate, e.date < expense.date else { return false }
            
            let ePaidById = e.paidBy?.id
            let payerOwesReceiver = (ePaidById == receiverId && e.splitDetails.contains { $0.user?.id == payerId })
            let receiverOwesPayer = (ePaidById == payerId && e.splitDetails.contains { $0.user?.id == receiverId })
            
            guard payerOwesReceiver || receiverOwesPayer else { return false }
            
            let participantId = payerOwesReceiver ? payerId : receiverId
            let isAlreadyIndividuallySettled = group.expenses.contains { s in
                s.isSettlement && !s.isFullSettlement && s.relatedExpenseId == e.id && s.paidBy?.id == participantId && s.date < expense.date
            }
            
            return !isAlreadyIndividuallySettled
        }
        .sorted { $0.date > $1.date }
    }
    
    private func shareAmountForSettledExpense(_ exp: Expense, payerId: UUID, receiverId: UUID) -> (amount: Double, isDeduction: Bool) {
        if exp.paidBy?.id == receiverId {
            let share = exp.splitDetails.first(where: { $0.user?.id == payerId })?.amount ?? exp.amount
            return (amount: share, isDeduction: false)
        } else if exp.paidBy?.id == payerId {
            let share = exp.splitDetails.first(where: { $0.user?.id == receiverId })?.amount ?? exp.amount
            return (amount: share, isDeduction: true)
        }
        return (amount: exp.amount, isDeduction: false)
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
    
    private var sortedSplitDetails: [SplitDetail] {
        guard let currentUserId = appState.currentUser?.id else { return expense.splitDetails }
        return expense.splitDetails.sorted { d1, d2 in
            if d1.user?.id == currentUserId { return true }
            if d2.user?.id == currentUserId { return false }
            return (d1.user?.firstName ?? "") < (d2.user?.firstName ?? "")
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
            if isCurrentUser { Spacer(minLength: 80) }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
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
                } else if expense.isFullSettlement {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Full Balance Settled")
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCurrentUser ? Color.white.opacity(0.15) : Color.green.opacity(0.1))
                    .foregroundColor(isCurrentUser ? .white : .green)
                    .cornerRadius(4)
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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .lineLimit(1)
                        
                        Text(expense.date, style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .gray)
                    }
                    
                    Spacer()
                    
                    Text("\(group.currencySymbol)\(String(format: "%.2f", expense.amount))")
                        .font(.system(size: 16, weight: .bold))
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
                        ForEach(sortedSplitDetails.prefix(5)) { detail in
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
                    if expense.isFullSettlement {
                        let settledList = settledExpensesForFullSettlement
                        if !settledList.isEmpty {
                            Divider()
                                .background(isCurrentUser ? Color.white.opacity(0.3) : Color(.separator))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Settled splits:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                                
                                ForEach(settledList.prefix(4)) { exp in
                                    HStack {
                                        Text(exp.title)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                        Spacer()
                                        let shareData = shareAmountForSettledExpense(exp, payerId: expense.paidBy?.id ?? UUID(), receiverId: expense.splitDetails.first?.user?.id ?? UUID())
                                        let prefix = shareData.isDeduction ? "-" : ""
                                        Text("\(prefix)\(group.currencySymbol)\(String(format: "%.2f", shareData.amount))")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(isCurrentUser ? .white : .primary)
                                    }
                                }
                                if settledList.count > 4 {
                                    Text("+ \(settledList.count - 4) more")
                                        .font(.system(size: 10))
                                        .italic()
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .primary.opacity(0.8))
                            .padding(.vertical, 4)
                            
                            Divider()
                                .background(isCurrentUser ? Color.white.opacity(0.3) : Color(.separator))
                        }
                    }
                    
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
            .padding(10)
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
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHighlighted ? highlightColor : (expense.isSettlement ? Color.green.opacity(0.3) : Color.clear), lineWidth: isHighlighted ? 2 : 1)
            )
            .scaleEffect(isHighlighted ? 1.03 : 1.0)
            .shadow(color: isHighlighted ? highlightColor.opacity(0.4) : Color.black.opacity(0.04), radius: isHighlighted ? 10 : 4, x: 0, y: isHighlighted ? 5 : 2)
            
            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}
