import SwiftUI
import SwiftData
import PhotosUI

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
    
    // Profile photo states
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    
    let countryCodes = [
        "🇺🇸 +1", "🇬🇧 +44", "🇮🇳 +91", "🇦🇺 +61", "🇯🇵 +81", "🇩🇪 +49", "🇫🇷 +33", "🇨🇳 +86"
    ]
    @State private var selectedCountryCode = "🇮🇳 +91"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Header ──────────────────────────────────────────
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
                
                // ── Profile Photo Picker ─────────────────────────────
                PhotosPicker(selection: $selectedPhotoItem,
                             matching: .images,
                             photoLibrary: .shared()) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let img = profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(24)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.25), lineWidth: 2)
                        )
                        .shadow(color: Color.blue.opacity(0.15), radius: 10, x: 0, y: 4)
                        
                        // Camera badge
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 28, height: 28)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: 4)
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run { profileImage = img }
                        }
                    }
                }
                
                VStack(spacing: 2) {
                    Text(profileImage == nil ? "Add Profile Photo" : "Change Photo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // ── Form Fields ──────────────────────────────────────
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        TextField("First Name", text: $firstName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onChange(of: firstName) { _, new in
                                if new.count > 20 { firstName = String(new.prefix(20)) }
                            }
                        
                        TextField("Last Name", text: $lastName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onChange(of: lastName) { _, new in
                                if new.count > 20 { lastName = String(new.prefix(20)) }
                            }
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
                            .onChange(of: phoneNumber) { _, new in
                                let digits = new.filter { $0.isNumber }
                                let clamped = String(digits.prefix(10))
                                if phoneNumber != clamped { phoneNumber = clamped }
                            }
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
                
                // ── Error ────────────────────────────────────────────
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // ── Sign Up Button ───────────────────────────────────
                Button(action: signup) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            hideKeyboard()
        }
        .alert("Account Created", isPresented: $showingSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your account has been created successfully. You will now be taken to the login page to sign in.")
        }
    }
    
    // MARK: - Helpers
    
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
        
        let fullPhoneNumber = phoneNumber.isEmpty
            ? ""
            : "\(selectedCountryCode.components(separatedBy: " ").last ?? "") \(phoneNumber)"
        
        // Compress profile image to JPEG before storing
        let imageData = profileImage?.jpegData(compressionQuality: 0.75)
        
        let newUser = AppUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: fullPhoneNumber,
            password: password,
            profileImageData: imageData
        )
        modelContext.insert(newUser)
        try? modelContext.save()
        
        // Auto-login after signup
        loggedInUserId = newUser.id.uuidString
        withAnimation {
            appState.currentUser = newUser
            appState.isAuthenticated = true
        }
    }
}
