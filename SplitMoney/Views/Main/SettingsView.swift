import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Query private var groups: [SplitGroup]
    
    // Preferences storage
    @AppStorage("defaultCurrency") private var defaultCurrency = "🇮🇳 ₹ INR"
    @AppStorage("defaultSplitMethod") private var defaultSplitMethod = "Equal"
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("expenseReminders") private var expenseReminders = true
    
    // Appearance & Haptics
    @AppStorage("appTheme") private var appTheme = "System"
    @AppStorage("enableHaptics") private var enableHaptics = true
    
    // Security
    @AppStorage("enableBiometrics") private var enableBiometrics = false
    
    // UI Feedback states
    @State private var showingExportAlert = false
    @State private var showingCacheAlert = false
    @State private var showingHelpAlert = false
    @State private var showingLegalAlert: String? = nil
    @State private var cacheSize = "24.5 MB"
    @State private var exportFileURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportProgressText = ""
    @State private var exportProgressValue: Double = 0.0
    
    let currencies = [
        "🇮🇳 ₹ INR", "🇺🇸 $ USD", "🇬🇧 £ GBP",
        "🇦🇺 A$ AUD", "🇯🇵 ¥ JPY", "🇪🇺 € EUR", "🇨🇳 ¥ CNY"
    ]
    
    let splitMethods = ["Equal", "Exact Amounts", "Percentage", "Shares"]
    let themes = ["System", "Light", "Dark"]
    
    var body: some View {
        NavigationStack {
            List {
                // ── PREFERENCES ──────────────────────────────────────
                Section {
                    Picker(selection: $defaultCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    } label: {
                        settingLabel(icon: "coloncurrencysign.circle", color: .green, title: "Default Currency")
                    }
                    
                    Picker(selection: $defaultSplitMethod) {
                        ForEach(splitMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    } label: {
                        settingLabel(icon: "arrow.triangle.branch", color: .blue, title: "Default Split Method")
                    }
                } header: {
                    Text("Preferences")
                }
                
                // ── NOTIFICATIONS ────────────────────────────────────
                Section {
                    Toggle(isOn: Binding(
                        get: { enableNotifications },
                        set: { newVal in
                            enableNotifications = newVal
                            if newVal { NotificationService.shared.requestPermission() }
                        }
                    )) {
                        settingLabel(icon: "bell", color: .red, title: "Push Notifications")
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: Binding(
                        get: { expenseReminders },
                        set: { newVal in
                            expenseReminders = newVal
                            if newVal { NotificationService.shared.requestPermission() }
                        }
                    )) {
                        settingLabel(icon: "clock", color: .orange, title: "Pending Expense Reminders")
                    }
                    .tint(.blue)
                    
                    Button {
                        HapticManager.playImpact(.light)
                        NotificationService.shared.testImmediateReminder(totalOwed: 500)
                    } label: {
                        HStack {
                            Text("Test Reminder Banner (Immediate)")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Notifications")
                }
                
                // ── APPEARANCE & HAPTICS ─────────────────────────────
                Section {
                    Picker(selection: Binding(
                        get: { appTheme },
                        set: { newTheme in
                            appTheme = newTheme
                            updateAppTheme(newTheme)
                        }
                    )) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    } label: {
                        settingLabel(icon: "paintbrush", color: .purple, title: "App Theme")
                    }
                    
                    Toggle(isOn: $enableHaptics) {
                        settingLabel(icon: "hand.tap", color: .indigo, title: "Haptic Feedback")
                    }
                    .tint(.blue)
                } header: {
                    Text("Appearance")
                }
                
                // ── SECURITY ─────────────────────────────────────────
                Section {
                    Toggle(isOn: $enableBiometrics) {
                        settingLabel(icon: "faceid", color: .teal, title: "Biometric Authentication")
                    }
                    .tint(.blue)
                } header: {
                    Text("Security")
                }
                
                // ── DATA & STORAGE ───────────────────────────────────
                Section {
                    Button {
                        guard !isExporting else { return }
                        isExporting = true
                        exportComplete = false
                        exportProgressValue = 0.0
                        exportProgressText = "Starting accounting export..."
                        
                        Task {
                            if let url = await AccountingExportService.exportCSV(modelContext: modelContext, onProgress: { text, val in
                                exportProgressText = text
                                withAnimation(.easeOut(duration: 0.15)) { exportProgressValue = val }
                            }) {
                                exportFileURL = url
                                withAnimation {
                                    exportComplete = true
                                    exportProgressText = "Export Completed Successfully!"
                                }
                            } else {
                                isExporting = false
                            }
                        }
                    } label: {
                        HStack {
                            settingLabel(icon: "square.and.arrow.up", color: .blue, title: "Export All Data (CSV)")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingCacheAlert = true
                    } label: {
                        HStack {
                            settingLabel(icon: "trash", color: .red, title: "Clear Image Cache")
                            Spacer()
                            Text(cacheSize)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Data & Storage")
                }
                
                // ── SUPPORT & ABOUT ──────────────────────────────────
                Section {
                    Button {
                        showingHelpAlert = true
                    } label: {
                        HStack {
                            settingLabel(icon: "questionmark.circle", color: .blue, title: "Help & FAQ")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingLegalAlert = "Privacy Policy"
                    } label: {
                        HStack {
                            settingLabel(icon: "doc.text", color: .gray, title: "Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingLegalAlert = "Terms of Service"
                    } label: {
                        HStack {
                            settingLabel(icon: "doc.text", color: .gray, title: "Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("About")
                } footer: {
                    VStack(alignment: .center, spacing: 6) {
                        Spacer().frame(height: 16)
                        Text("SplitMoney Premium v1.2.0")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Made with ❤️ for effortless expense splitting")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Clear Cache", isPresented: $showingCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clearCache() }
            } message: {
                Text("Are you sure you want to clear cached avatars and receipt images? This will free up \(cacheSize).")
            }
            .alert("Help & FAQ", isPresented: $showingHelpAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Need help? Reach out to support at help@splitmoney.app or visit our online knowledge base.")
            }
            .alert(item: Binding(
                get: { showingLegalAlert.map { LegalInfo(title: $0) } },
                set: { showingLegalAlert = $0?.title }
            )) { legal in
                Alert(title: Text(legal.title), message: Text("The SplitMoney \(legal.title) terms are enforced to protect your personal data and privacy. All transaction records are encrypted."), dismissButton: .default(Text("OK")))
            }
            .overlay {
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 22) {
                            if exportComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 54))
                                    .foregroundColor(.green)
                                    .transition(.scale)
                            } else {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.blue)
                            }
                            
                            Text(exportProgressText)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            if !exportComplete {
                                ProgressView(value: exportProgressValue, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .tint(.blue)
                                    .frame(width: 220)
                            } else {
                                HStack(spacing: 16) {
                                    Button {
                                        withAnimation { isExporting = false }
                                    } label: {
                                        Text("Close")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .frame(width: 100, height: 44)
                                            .background(Color(.secondarySystemBackground))
                                            .cornerRadius(12)
                                    }
                                    
                                    Button {
                                        showingShareSheet = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Share")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(width: 120, height: 44)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(32)
                        .background(Color(.systemBackground))
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 10)
                        .frame(maxWidth: 320)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
        }
    }
    
    // Custom Row Icon Helper
    @ViewBuilder
    private func settingLabel(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(color)
                .frame(width: 26, alignment: .center)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
        }
    }
    
    // MARK: - Functionality Helpers
    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        withAnimation { cacheSize = "0.0 MB" }
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

private struct LegalInfo: Identifiable {
    var id: String { title }
    let title: String
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
