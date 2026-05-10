import SwiftUI
import SwiftData

struct SummaryView: View {
    let title: String
    let amount: Double
    let splitDetails: [PendingSplitDetail]
    let payerId: UUID
    let group: SplitGroup
    var editingExpense: Expense? = nil
    @Environment(AppState.self) var appState
    let parentDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 12) {
                        Text("Review Split")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("\(group.currencySymbol)\(String(format: "%.2f", amount))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Receipt Card
                    VStack(alignment: .leading, spacing: 20) {
                        // Payer Info
                        HStack(spacing: 12) {
                            let payerDescriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.id == payerId })
                            if let payer = try? modelContext.fetch(payerDescriptor).first {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Paid by")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(payer.firstName)
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            Spacer()
                        }
                        .padding(.bottom, 12)
                        
                        Divider()
                        
                        // Split Breakdown
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Split Breakdown")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            ForEach(splitDetails) { detail in
                                HStack {
                                    Text(detail.userName)
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Text("\(group.currencySymbol)\(String(format: "%.2f", detail.amount))")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Bottom Action Button
            VStack {
                Button(action: {
                    confirmSplit()
                }) {
                    HStack {
                        Text("Confirm and Split")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(
                    VisualBlurView(style: .systemThinMaterial)
                        .mask(LinearGradient(gradient: Gradient(colors: [.clear, .black, .black]), startPoint: .top, endPoint: .bottom))
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func confirmSplit() {
        var finalDetails: [SplitDetail] = []
        
        for detail in splitDetails {
            // Find the actual user model in this context
            let id = detail.userId
            let descriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.id == id })
            if let user = try? modelContext.fetch(descriptor).first {
                finalDetails.append(SplitDetail(user: user, amount: detail.amount))
            }
        }
        
        if let expense = editingExpense {
            // Update existing expense
            expense.title = title
            expense.amount = amount
            expense.splitType = .equal // Logic can be refined
            
            // In SwiftData, cascade delete rule on splitDetails relationship 
            // should handle cleanup if we replace the array
            expense.splitDetails = finalDetails
            
            let payerDescriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.id == payerId })
            expense.paidBy = (try? modelContext.fetch(payerDescriptor).first) ?? appState.currentUser
        } else {
            // Create new expense
            let payerDescriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.id == payerId })
            let actualPayer = try? modelContext.fetch(payerDescriptor).first
            
            let newExpense = Expense(
                title: title,
                amount: amount,
                splitType: .equal,
                splitDetails: finalDetails,
                paidBy: actualPayer ?? appState.currentUser
            )
            
            modelContext.insert(newExpense)
            group.expenses.append(newExpense)
        }
        
        try? modelContext.save()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Return to Chat View
        parentDismiss()
    }
}
