import SwiftUI
import SwiftData

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var showingSuccessAlert = false
    @AppStorage("loggedInUserId") private var loggedInUserId: String?
    
    let countryCodes = [
        "🇺🇸 +1", "🇬🇧 +44", "🇮🇳 +91", "🇦🇺 +61", "🇯🇵 +81", "🇩🇪 +49", "🇫🇷 +33", "🇨🇳 +86"
    ]
    @State private var selectedCountryCode = "🇮🇳 +91"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Join Money Split to manage your shared expenses easily.")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        TextField("First Name", text: $firstName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        TextField("Last Name", text: $lastName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    HStack {
                        Picker("Code", selection: $selectedCountryCode) {
                            ForEach(countryCodes, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .tint(.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    HStack {
                        SecureField("Verify Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                        
                        if !confirmPassword.isEmpty {
                            Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(password == confirmPassword ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    signup()
                }) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            hideKeyboard()
        }
        .alert("Account Created", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your account has been created successfully. You will now be taken to the login page to sign in.")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func signup() {
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            withAnimation { errorMessage = "Please fill in all required fields." }
            return
        }
        
        guard password == confirmPassword else {
            withAnimation { errorMessage = "Passwords do not match." }
            return
        }
        
        guard isValidEmail(email) else {
            withAnimation { errorMessage = "Please enter a valid email address." }
            return
        }
        
        errorMessage = nil
        
        let fullPhoneNumber = phoneNumber.isEmpty ? "" : "\(selectedCountryCode.components(separatedBy: " ").last ?? "") \(phoneNumber)"
        
        let newUser = AppUser(firstName: firstName, lastName: lastName, email: email, phoneNumber: fullPhoneNumber, password: password)
        modelContext.insert(newUser)
        
        // Show success alert, which will then dismiss the view
        showingSuccessAlert = true
    }
}
