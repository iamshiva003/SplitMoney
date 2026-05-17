import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) var appState
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    
    @AppStorage("loggedInUserId") private var loggedInUserId: String?
    @AppStorage("appTheme") private var appTheme = "System"
    @AppStorage("enableBiometrics") private var enableBiometrics = false
    
    @State private var isUnlocked = false
    
    var isLockActive: Bool {
        enableBiometrics && !isUnlocked
    }
    
    var body: some View {
        Group {
            if isLockActive {
                AppLockView(isUnlocked: $isUnlocked)
            } else {
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
            }
        }
        .onAppear {
            checkLoginState()
            updateAppTheme(appTheme)
            _ = NotificationService.shared
        }
        .onChange(of: appTheme) { _, newTheme in
            updateAppTheme(newTheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && enableBiometrics {
                isUnlocked = false
            }
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
    
    private func updateAppTheme(_ theme: String) {
        let style: UIUserInterfaceStyle
        if theme == "Light" { style = .light }
        else if theme == "Dark" { style = .dark }
        else { style = .unspecified }
        
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
