import SwiftUI

struct SplitMoneyView: View {
    @Environment(\.dismiss) var dismiss
    let group: SplitGroup
    var editingExpense: Expense? = nil
    var initialAmount: String? = nil
    var initialNote: String? = nil
    
    @State private var amountString = ""
    @State private var note = ""
    @State private var isEqualSplit = true
    
    // State to hold custom amounts per user id
    @State private var customAmounts: [UUID: String] = [:]
    
    // Toggle for members participating
    @State private var participatingMembers: Set<UUID> = []
    
    @State private var selectedPayerId: UUID?
    @Environment(AppState.self) var appState
    
    @State private var showingSummary = false
    @State private var navPath = NavigationPath()
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Section
                        VStack(spacing: 8) {
                            Text("How much?")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(group.currencySymbol)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                TextField("0.00", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize()
                                    .focused($isAmountFocused)
                            }
                            
                            TextField("What's this for?", text: $note)
                                .font(.system(size: 18, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.top, 8)
                        }
                        .padding(.top, 20)
                        
                        // Payer Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Paid by")
                                .font(.system(size: 16, weight: .bold))
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(group.members) { member in
                                        PayerCard(member: member, isSelected: selectedPayerId == member.id) {
                                            selectedPayerId = member.id
                                            hapticFeedback(.light)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Split Mode Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Splitting with")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                                Button(action: {
                                    isEqualSplit.toggle()
                                    hapticFeedback(.light)
                                }) {
                                    Text(isEqualSplit ? "Equally" : "Custom")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(group.members) { member in
                                    MemberSplitCard(
                                        member: member,
                                        isParticipating: participatingMembers.contains(member.id),
                                        isEqualSplit: isEqualSplit,
                                        amount: Binding(
                                            get: { customAmounts[member.id] ?? "" },
                                            set: { customAmounts[member.id] = $0 }
                                        ),
                                        onToggle: {
                                            toggleParticipation(for: member.id)
                                            hapticFeedback(.light)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 20)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        Button(action: {
                            hideKeyboard()
                            if validateAmounts() {
                                prepareSummary()
                            }
                        }) {
                            Text(editingExpense == nil ? "Review Split" : "Update Split")
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
                        .disabled(amountString.isEmpty || participatingMembers.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            VisualBlurView(style: .systemThinMaterial)
                                .mask(LinearGradient(gradient: Gradient(colors: [.clear, .black, .black]), startPoint: .top, endPoint: .bottom))
                                .ignoresSafeArea()
                        )
                    }
                }
            }
            .navigationTitle(editingExpense == nil ? "Add Split" : "Edit Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
            .onAppear {
                if let expense = editingExpense {
                    amountString = String(format: "%.2f", expense.amount)
                    note = expense.title
                    isEqualSplit = expense.splitType == .equal
                    
                    var participants = Set<UUID>()
                    var customAmts = [UUID: String]()
                    
                    for detail in expense.splitDetails {
                        if let memberId = detail.user?.id {
                            participants.insert(memberId)
                            customAmts[memberId] = String(format: "%.2f", detail.amount)
                        }
                    }
                    
                    self.participatingMembers = participants
                    self.customAmounts = customAmts
                    self.selectedPayerId = expense.paidBy?.id
                } else {
                    // Use initial values if shared, otherwise defaults
                    if let initialAmount = initialAmount {
                        amountString = initialAmount
                    }
                    if let initialNote = initialNote {
                        note = initialNote
                    }
                    
                    // By default, everyone participates and current user paid
                    participatingMembers = Set(group.members.map { $0.id })
                    selectedPayerId = appState.currentUser?.id
                    
                    // Auto-focus amount field for new splits
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isAmountFocused = true
                    }
                }
            }
            .navigationDestination(for: SplitSummaryData.self) { data in
                SummaryView(
                    title: data.title,
                    amount: data.amount,
                    splitDetails: data.details,
                    payerId: data.payerId,
                    splitType: data.splitType,
                    group: group,
                    editingExpense: editingExpense,
                    parentDismiss: { dismiss() }
                )
            }
        }
    }
    
    private func prepareSummary() {
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".")
        guard let totalAmount = Double(cleanAmount) else { return }
        
        var tempDetails: [PendingSplitDetail] = []
        let participants = group.members.filter { participatingMembers.contains($0.id) }
        
        if isEqualSplit {
            let splitAmount = totalAmount / Double(participants.count)
            for member in participants {
                tempDetails.append(PendingSplitDetail(userId: member.id, userName: member.firstName, amount: splitAmount))
            }
        } else {
            for member in participants {
                let cleanAmt = (customAmounts[member.id] ?? "0").replacingOccurrences(of: ",", with: ".")
                let amt = Double(cleanAmt) ?? 0
                tempDetails.append(PendingSplitDetail(userId: member.id, userName: member.firstName, amount: amt))
            }
        }
        
        let title = note.isEmpty ? "Untitled Expense" : note
        let payerId = selectedPayerId ?? appState.currentUser?.id ?? group.members.first?.id ?? UUID()
        let splitType: SplitType = isEqualSplit ? .equal : .custom
        let summaryData = SplitSummaryData(title: title, amount: totalAmount, details: tempDetails, payerId: payerId, splitType: splitType)
        self.navPath.append(summaryData)
    }
    
    private func validateAmounts() -> Bool {
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".")
        guard let totalAmount = Double(cleanAmount) else { return false }
        
        if !isEqualSplit {
            var sum: Double = 0
            for id in participatingMembers {
                let cleanAmt = (customAmounts[id] ?? "0").replacingOccurrences(of: ",", with: ".")
                sum += Double(cleanAmt) ?? 0
            }
            
            // Allow for tiny rounding differences (0.01)
            if abs(sum - totalAmount) > 0.02 {
                hapticFeedback(.error)
                // In a real app we might show an alert here
                return false
            }
        }
        
        hapticFeedback(.success)
        return true
    }
    
    private func toggleParticipation(for id: UUID) {
        if participatingMembers.contains(id) {
            participatingMembers.remove(id)
        } else {
            participatingMembers.insert(id)
        }
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticManager.playImpact(style)
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        HapticManager.playNotification(type)
    }
}

struct PayerCard: View {
    let member: AppUser
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(member.firstName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isSelected ? .white : .gray)
                    )
                
                Text(member.firstName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .blue : .primary)
            }
            .frame(width: 80, height: 100)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.1) : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct MemberSplitCard: View {
    let member: AppUser
    let isParticipating: Bool
    let isEqualSplit: Bool
    @Binding var amount: String
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggle) {
                HStack(spacing: 16) {
                    Image(systemName: isParticipating ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isParticipating ? .blue : .gray)
                    
                    Text(member.firstName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isParticipating {
                if isEqualSplit {
                    Text("Auto")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    HStack(spacing: 4) {
                        Text("₹")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .opacity(isParticipating ? 1 : 0.6)
    }
}
