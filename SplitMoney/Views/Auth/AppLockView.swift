import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Binding var isUnlocked: Bool
    @AppStorage("enableBiometrics") private var enableBiometrics = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "faceid")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.blue)
            
            Text("App Locked")
                .font(.system(size: 28, weight: .bold))
            
            Text("Split Money is locked. Use Face ID or Touch ID to securely access your transactions.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            Button {
                authenticateBiometrics()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Unlock with Biometrics")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.blue)
                .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            
            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            authenticateBiometrics()
        }
    }
    
    private func authenticateBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Split Money") { success, authError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation { isUnlocked = true }
                    } else {
                        errorMessage = authError?.localizedDescription ?? "Authentication failed. Please try again."
                    }
                }
            }
        } else {
            errorMessage = "Biometrics are unavailable on this device."
        }
    }
}
