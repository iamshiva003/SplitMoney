import SwiftUI
import SwiftData

struct IncomingShareView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [SplitGroup]
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedGroup: SplitGroup?
    @State private var navigationPath = NavigationPath()
    
    var userGroups: [SplitGroup] {
        guard let currentUser = appState.currentUser else { return [] }
        return groups.filter { group in
            group.members.contains { $0.id == currentUser.id }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("Shared Transaction")
                        .font(.system(size: 24, weight: .bold))
                    
                    if let amount = appState.pendingSharedAmount {
                        Text("₹\(amount)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    
                    if let note = appState.pendingSharedNote {
                        Text(note)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 30)
                
                Divider()
                
                Text("Select a group to split with")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                
                List(userGroups) { group in
                    Button(action: {
                        selectedGroup = group
                        navigationPath.append(group)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .font(.system(size: 17, weight: .semibold))
                                Text("\(group.members.count) members")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Split Shared")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        appState.showIncomingShareFlow = false
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: SplitGroup.self) { group in
                SplitMoneyView(
                    group: group,
                    initialAmount: appState.pendingSharedAmount,
                    initialNote: appState.pendingSharedNote
                )
            }
        }
    }
}
