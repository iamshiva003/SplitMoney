import SwiftUI
import SwiftData

struct SettleUpView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    
    let group: SplitGroup
    @State private var showingNudgeAlert = false
    @State private var nudgeMessage = ""
    
    // Balance calculation per member relative to current user
    // Positive: They owe you. Negative: You owe them.
    private var memberBalances: [(user: AppUser, balance: Double)] {
        guard let currentUser = appState.currentUser else { return [] }
        var balances: [UUID: Double] = [:]
        
        // Initialize with all members except self
        for member in group.members where member.id != currentUser.id {
            balances[member.id] = 0
        }
        
        for expense in group.expenses {
            let currentUserShare = expense.splitDetails.first(where: { $0.user?.id == currentUser.id })?.amount ?? 0
            
            if let paidBy = expense.paidBy {
                if paidBy.id == currentUser.id {
                    // Current user paid: Add others' shares to their respective balances (they owe current user)
                    for detail in expense.splitDetails {
                        if let user = detail.user, user.id != currentUser.id {
                            balances[user.id, default: 0] += detail.amount
                        }
                    }
                } else {
                    // Someone else paid: current user owes them their share (subtract from their balance)
                    balances[paidBy.id, default: 0] -= currentUserShare
                }
            }
        }
        
        return group.members
            .filter { $0.id != currentUser.id }
            .map { (user: $0, balance: balances[$0.id] ?? 0) }
            .filter { abs($0.balance) > 0.01 } // Only show members with non-zero balance
            .sorted { abs($0.balance) > abs($1.balance) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if memberBalances.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("You are all settled!")
                                .font(.headline)
                            Text("There are no outstanding balances in this group.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 100)
                    } else {
                        // Summary Card
                        VStack(spacing: 8) {
                            Text("Balance Summary")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let netBalance = memberBalances.reduce(0) { $0 + $1.balance }
                            Text("\(group.currencySymbol)\(String(format: "%.2f", abs(netBalance)))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(netBalance >= 0 ? .green : .red)
                            
                            Text(netBalance >= 0 ? "You are owed in total" : "You owe in total")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Members List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INDIVIDUAL BALANCES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(memberBalances, id: \.user.id) { item in
                                    SettlementRow(user: item.user, balance: item.balance, currencySymbol: group.currencySymbol, onSettle: {
                                        settleBalance(with: item.user, amount: item.balance)
                                    }, onNudge: {
                                        nudgeMessage = "Reminder successfully sent to \(item.user.firstName)!"
                                        showingNudgeAlert = true
                                    })
                                    
                                    if item.user.id != memberBalances.last?.user.id {
                                        Divider().padding(.leading, 70)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reminder Sent 💸", isPresented: $showingNudgeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(nudgeMessage)
            }
        }
    }
    
    private func settleBalance(with otherUser: AppUser, amount: Double) {
        guard let currentUser = appState.currentUser else { return }
        
        let absAmount = abs(amount)
        let isUserPaying = amount < 0
        
        // If amount < 0: Current user owes otherUser -> currentUser pays otherUser
        // If amount > 0: otherUser owes current user -> otherUser pays currentUser
        
        let payer = isUserPaying ? currentUser : otherUser
        let receiver = isUserPaying ? otherUser : currentUser
        
        let settlement = Expense(
            title: isUserPaying ? "Payment to \(receiver.firstName)" : "Payment from \(payer.firstName)",
            amount: absAmount,
            date: Date(),
            splitType: .custom,
            splitDetails: [
                SplitDetail(user: receiver, amount: absAmount)
            ],
            paidBy: payer,
            isSettlement: true,
            isFullSettlement: true,
            relatedExpenseId: nil
        )
        
        group.expenses.append(settlement)
        try? modelContext.save()
        
        hapticFeedback(.success)
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        HapticManager.playNotification(type)
    }
}

struct SettlementRow: View {
    let user: AppUser
    let balance: Double
    let currencySymbol: String
    let onSettle: () -> Void
    var onNudge: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                if let data = user.profileImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(String(user.firstName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.system(size: 16, weight: .semibold))
                Text(balance > 0 ? "owes you" : "you owe")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(currencySymbol)\(String(format: "%.2f", abs(balance)))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(balance > 0 ? .green : .red)
                
                HStack(spacing: 8) {
                    if balance > 0 {
                        Button {
                            HapticManager.playImpact(.light)
                            NotificationService.shared.sendInstantNudge(to: user.firstName, amount: balance, currencySymbol: currencySymbol)
                            onNudge?()
                        } label: {
                            Text("Remind")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    
                    Button(action: onSettle) {
                        Text("Settle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(balance > 0 ? Color.green : Color.red)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
