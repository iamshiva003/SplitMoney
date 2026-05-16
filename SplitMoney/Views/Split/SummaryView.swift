import SwiftUI
import SwiftData

struct SummaryView: View {
    let title: String
    let amount: Double
    let splitDetails: [PendingSplitDetail]
    let payerId: UUID
    let splitType: SplitType
    let group: SplitGroup
    var editingExpense: Expense? = nil
    @Environment(AppState.self) var appState
    let parentDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    private var actualPayer: AppUser? {
        group.members.first(where: { $0.id == payerId })
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 28) {
                    // Premium Header Section
                    VStack(spacing: 12) {
                        Text("TOTAL AMOUNT")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1.5)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(group.currencySymbol)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                            Text(String(format: "%.2f", amount))
                                .font(.system(size: 54, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 32)
                            .multilineTextAlignment(.center)
                        
                        // Badge
                        HStack(spacing: 6) {
                            Image(systemName: splitType == .equal ? "equal.circle.fill" : "slider.horizontal.3")
                            Text(splitType == .equal ? "Equal Split" : "Custom Split")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 36)
                    
                    // Receipt Card
                    VStack(alignment: .leading, spacing: 0) {
                        // Top Payer Section
                        HStack(spacing: 16) {
                            if let payer = actualPayer {
                                SummaryAvatarView(user: payer)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Paid by")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(payer.fullName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                            Spacer()
                            
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                        .padding(24)
                        
                        // Perforated Divider
                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color(.systemGroupedBackground))
                                .frame(width: 24, height: 24)
                                .offset(x: -12)
                            
                            Line()
                                .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .frame(height: 1)
                            
                            Circle()
                                .fill(Color(.systemGroupedBackground))
                                .frame(width: 24, height: 24)
                                .offset(x: 12)
                        }
                        .padding(.vertical, -12)
                        
                        // Breakdown Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Split Breakdown")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 12) {
                                ForEach(splitDetails) { detail in
                                    let member = group.members.first(where: { $0.id == detail.userId })
                                    let isMe = detail.userId == appState.currentUser?.id
                                    
                                    HStack(spacing: 14) {
                                        if let m = member {
                                            SummaryAvatarView(user: m, size: 36)
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(detail.userName)
                                                .font(.system(size: 16, weight: isMe ? .bold : .medium))
                                                .foregroundColor(isMe ? .blue : .primary)
                                            if isMe {
                                                Text("Your share")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(group.currencySymbol)\(String(format: "%.2f", detail.amount))")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(isMe ? .blue : .primary)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(isMe ? Color.blue.opacity(0.08) : Color.clear)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(24)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 130)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            
            // Floating Confirm Button
            VStack {
                Button(action: {
                    confirmSplit()
                }) {
                    HStack(spacing: 12) {
                        Text(editingExpense == nil ? "Confirm and Split" : "Update Split")
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.3, blue: 0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.blue.opacity(0.35), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(
                    VisualBlurView(style: .systemThinMaterial)
                        .mask(LinearGradient(gradient: Gradient(colors: [.clear, .black, .black]), startPoint: .top, endPoint: .bottom))
                        .ignoresSafeArea()
                )
            }
        }
        .navigationTitle(editingExpense == nil ? "Review Split" : "Review Update")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func confirmSplit() {
        var finalDetails: [SplitDetail] = []
        
        for detail in splitDetails {
            if let user = group.members.first(where: { $0.id == detail.userId }) {
                finalDetails.append(SplitDetail(user: user, amount: detail.amount))
            }
        }
        
        if let expense = editingExpense {
            expense.title = title
            expense.amount = amount
            expense.splitType = splitType
            expense.splitDetails = finalDetails
            expense.paidBy = actualPayer ?? appState.currentUser
        } else {
            let newExpense = Expense(
                title: title,
                amount: amount,
                splitType: splitType,
                splitDetails: finalDetails,
                paidBy: actualPayer ?? appState.currentUser
            )
            
            modelContext.insert(newExpense)
            group.expenses.append(newExpense)
        }
        
        try? modelContext.save()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        parentDismiss()
    }
}

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

struct SummaryAvatarView: View {
    let user: AppUser
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            if let data = user.profileImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.indigo.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: size, height: size)
                
                Text(String(user.firstName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }
}
