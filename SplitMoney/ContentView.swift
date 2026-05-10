import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) var appState
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage("loggedInUserId") private var loggedInUserId: String?
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                HomeView()
            } else {
                LoginView()
            }
        }
        .sheet(isPresented: Bindable(appState).showIncomingShareFlow) {
            IncomingShareView()
        }
        .onAppear {
            checkLoginState()
        }
    }
    
    private func checkLoginState() {
        guard let userIdString = loggedInUserId, let uuid = UUID(uuidString: userIdString) else { return }
        
        let descriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.id == uuid })
        do {
            let users = try modelContext.fetch(descriptor)
            if let user = users.first {
                appState.currentUser = user
                appState.isAuthenticated = true
            } else {
                // User no longer exists in database, clear login state
                loggedInUserId = nil
            }
        } catch {
            print("Error restoring session: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
