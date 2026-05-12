import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import SwiftData

struct LoginView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @State private var loginInput = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @AppStorage("loggedInUserId") private var loggedInUserId: String?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo or Title
                    VStack(spacing: 8) {
                        Image(systemName: "dollarsign.arrow.circlepath")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(Color.blue)
                        
                        Text("Money Split")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                    }
                    .padding(.bottom, 20)
                    
                    // Fields
                    VStack(spacing: 16) {
                        TextField("Email or Phone Number", text: $loginInput)
                            .keyboardType(.default)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Buttons
                    VStack(spacing: 16) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            hideKeyboard()
                            login()
                        }) {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        HStack {
                            VStack { Divider() }
                            Text("OR").font(.subheadline).foregroundColor(.gray)
                            VStack { Divider() }
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            handleGoogleSignIn()
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                Text("Sign In with Google")
                                    .font(.headline)
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                        .frame(height: 40)
                    
                    NavigationLink(destination: SignupView()) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.gray)
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private func isValidEmailOrPhone(_ input: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        
        // Basic phone number validation (digits, dashes, plus, spaces allowed)
        let phoneRegEx = "^[0-9+ -]{7,15}$"
        let phonePred = NSPredicate(format: "SELF MATCHES %@", phoneRegEx)
        
        return emailPred.evaluate(with: input) || phonePred.evaluate(with: input)
    }

    private func login() {
        // Admin bypass
        if loginInput == "admin" && password == "test" {
            let adminEmail = "admin@example.com"
            let adminDescriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.email == adminEmail })
            if let adminUser = try? modelContext.fetch(adminDescriptor).first {
                loginWithUser(adminUser)
            } else {
                let newAdmin = AppUser(firstName: "Admin", lastName: "User", email: adminEmail, phoneNumber: "1234567890", password: "test")
                modelContext.insert(newAdmin)
                try? modelContext.save()
                loginWithUser(newAdmin)
            }
            return
        }
        
        guard isValidEmailOrPhone(loginInput) else {
            hapticFeedback(.error)
            withAnimation { errorMessage = "Please enter a valid email or phone number." }
            return
        }
        
        errorMessage = nil
        
        let searchInput = loginInput
        let searchPassword = password
        
        // Fetch users matching the password to avoid complex || Predicate crashes in SwiftData
        let descriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.password == searchPassword })
        
        do {
            let users = try modelContext.fetch(descriptor)
            if let user = users.first(where: { $0.email == searchInput || $0.phoneNumber == searchInput }) {
                loginWithUser(user)
            } else {
                hapticFeedback(.error)
                withAnimation { errorMessage = "Incorrect email/phone or password." }
            }
        } catch {
            hapticFeedback(.error)
            withAnimation { errorMessage = "An error occurred while logging in." }
        }
    }
    
    private func loginWithUser(_ user: AppUser) {
        hapticFeedback(.success)
        loggedInUserId = user.id.uuidString
        withAnimation {
            appState.currentUser = user
            appState.isAuthenticated = true
        }
    }
    
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Error signing in: \(error.localizedDescription)")
                return
            }
            
            guard let user = signInResult?.user else { return }
            
            let emailAddress = user.profile?.email ?? ""
            let givenName = user.profile?.givenName ?? "Google"
            let familyName = user.profile?.familyName ?? "User"
            let profilePicUrl = user.profile?.imageURL(withDimension: 200)
            
            // Check if user already exists
            let descriptor = FetchDescriptor<AppUser>(predicate: #Predicate { $0.email == emailAddress })
            if let existingUser = try? modelContext.fetch(descriptor).first {
                // Update profile image if it was missing or new one available
                if existingUser.profileImageData == nil, let url = profilePicUrl {
                    downloadImage(from: url) { data in
                        existingUser.profileImageData = data
                        try? modelContext.save()
                    }
                }
                loginWithUser(existingUser)
            } else {
                let newUser = AppUser(firstName: givenName, lastName: familyName, email: emailAddress, phoneNumber: "")
                modelContext.insert(newUser)
                
                if let url = profilePicUrl {
                    downloadImage(from: url) { data in
                        newUser.profileImageData = data
                        try? modelContext.save()
                    }
                } else {
                    try? modelContext.save()
                }
                
                loginWithUser(newUser)
            }
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                completion(data)
            }
        }.resume()
    }
    
    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
