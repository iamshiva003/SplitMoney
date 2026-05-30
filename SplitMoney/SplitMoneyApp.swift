import SwiftUI
import SwiftData
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        _ = NotificationService.shared
        return true
    }
}

@main
struct SplitMoneyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            #if DEBUG
            // SwiftData Schema mismatch or migration failure occurred.
            // In development/DEBUG mode, we can automatically delete the old SQLite files and recreate the container
            // so the developer doesn't experience a crash-loop after modifying models.
            let url = modelConfiguration.url
            let fileManager = FileManager.default
            
            print("⚠️ SwiftData ModelContainer creation failed: \(error). resetting local store at: \(url.path)")
            
            // Clean up main store file and possible SQLite WAL/SHM sidecar files
            let urlsToDelete = [
                url,
                url.appendingPathExtension("wal"),
                url.appendingPathExtension("shm"),
                url.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                url.deletingPathExtension().appendingPathExtension("sqlite-shm")
            ]
            
            for deleteUrl in urlsToDelete {
                try? fileManager.removeItem(at: deleteUrl)
            }
            
            if let walUrl = URL(string: url.absoluteString + "-wal") {
                try? fileManager.removeItem(at: walUrl)
            }
            if let shmUrl = URL(string: url.absoluteString + "-shm") {
                try? fileManager.removeItem(at: shmUrl)
            }
            
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Fatal Error: Could not recreate ModelContainer after resetting store: \(error)")
            }
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
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
