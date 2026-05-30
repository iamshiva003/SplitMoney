import SwiftUI
import SwiftData

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        return path
    }
}

struct BarcodeView: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<28) { index in
                Rectangle()
                    .fill(Color.primary.opacity(0.8))
                    .frame(width: index % 4 == 0 ? 3 : (index % 3 == 0 ? 1.2 : 2), height: 38)
            }
        }
    }
}

struct BillReceiptView: View {
    let expense: Expense
    let group: SplitGroup
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 20))
                            .foregroundColor(expense.isSettlement ? .green : .blue)
                        Text("SplitMoney")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.black)
                            .tracking(1.0)
                    }
                    Text(expense.isSettlement ? "SETTLEMENT RECEIPT" : "TRANSACTION RECEIPT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(2.0)
                }
                .padding(.top, 10)
                
                Divider()
                
                // Group & Date info
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GROUP NAME")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("DATE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(expense.date, style: .date)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                
                // Expense / Settlement details
                if expense.isSettlement {
                    VStack(spacing: 8) {
                        let receiverName = expense.splitDetails.first?.user?.fullName ?? "Unknown"
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                            .padding(.bottom, 2)
                        
                        Text("SETTLEMENT COMPLETED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .tracking(1.0)
                        
                        Text("\(expense.paidBy?.fullName ?? "Unknown") paid \(receiverName)")
                            .font(.system(size: 14, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                        
                        Text("\(group.currencySymbol)\(String(format: "%.2f", expense.amount))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.06))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 6) {
                        Text(expense.title.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                        
                        Text("\(group.currencySymbol)\(String(format: "%.2f", expense.amount))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(12)
                }
                
                // Payer & Split Method Information
                VStack(spacing: 8) {
                    HStack {
                        Text("PAID BY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(expense.paidBy?.fullName ?? "Unknown")
                            .font(.system(size: 12, weight: .bold))
                    }
                    
                    if !expense.isSettlement {
                        HStack {
                            Text("SPLIT METHOD")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(expense.splitType == .equal ? "Split Equally" : "Custom Split")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
                
                if !expense.isSettlement {
                    DashedLine()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(.secondary.opacity(0.4))
                        .frame(height: 1)
                    
                    // Individual Splits Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INDIVIDUAL SPLITS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                            .padding(.bottom, 2)
                        
                        ForEach(expense.splitDetails) { detail in
                            HStack(spacing: 8) {
                                Text(detail.user?.fullName ?? "Unknown")
                                    .font(.system(size: 12, weight: .medium))
                                
                                Spacer()
                                
                                // Paid/Pending Status Pill
                                let isPayer = detail.user?.id == expense.paidBy?.id
                                let isSettled = checkIsSettled(detail: detail)
                                
                                if isPayer || isSettled {
                                    Text("PAID")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.12))
                                        .cornerRadius(4)
                                } else {
                                    Text("PENDING")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.12))
                                        .cornerRadius(4)
                                }
                                
                                Text("\(group.currencySymbol)\(String(format: "%.2f", detail.amount))")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                        }
                    }
                }
                
                DashedLine()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(.secondary.opacity(0.4))
                    .frame(height: 1)
                
                // Barcode and Footer
                VStack(spacing: 8) {
                    BarcodeView()
                    
                    Text("#SM-\(expense.id.uuidString.prefix(8).uppercased())")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("Scan to settle or view on SplitMoney")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 10)
            }
            .padding(20)
            .background(Color(.systemBackground))
        }
        .frame(width: 330)
        .cornerRadius(16)
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
}
