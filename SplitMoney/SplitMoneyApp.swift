import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct SplitMoneyApp: App {
    @State private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppUser.self,
            SplitGroup.self,
            Expense.self,
            SplitDetail.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    if url.scheme == "splitmoney" {
                        // Handle internal deep links
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                        let amount = components?.queryItems?.first(where: { $0.name == "amount" })?.value
                        let note = components?.queryItems?.first(where: { $0.name == "note" })?.value
                        let text = components?.queryItems?.first(where: { $0.name == "text" })?.value
                        
                        if let text = text {
                            if text == "SCAN_SCREENSHOT" {
                                // Check clipboard for image
                                if let image = UIPasteboard.general.image {
                                    appState.parseSharedImage(image)
                                }
                            } else {
                                appState.parseSharedText(text)
                            }
                        } else if let amount = amount {
                            appState.pendingSharedAmount = amount
                            appState.pendingSharedNote = note
                            appState.showIncomingShareFlow = true
                        }
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
