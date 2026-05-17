import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) var appState

    // ── Editable fields ──────────────────────────────────────
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var email     = ""
    @State private var phoneNumber = ""
    @State private var password  = ""
    @State private var confirmPassword = ""
    @State private var oldPassword = ""

    // ── Photo picker ──────────────────────────────────────────
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var pendingCropImage: UIImage? = nil
    @State private var showingCropper = false

    // ── UI state ──────────────────────────────────────────────
    @State private var isEditing             = false
    @State private var errorMessage: String? = nil
    @State private var showingSuccess        = false
    @State private var showPassword          = false
    @State private var showConfirm           = false
    @State private var showOldPassword       = false
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFullProfileImage = false
    @State private var accountPassword       = ""
    @State private var deleteErrorMessage: String? = nil
    @AppStorage("loggedInUserId") private var loggedInUserId: String?

    let countryCodes = [
        "🇺🇸 +1", "🇬🇧 +44", "🇮🇳 +91", "🇦🇺 +61",
        "🇯🇵 +81", "🇩🇪 +49", "🇫🇷 +33", "🇨🇳 +86"
    ]
    @State private var selectedCountryCode = "🇮🇳 +91"

    // ── Helpers ───────────────────────────────────────────────
    private var user: AppUser? { appState.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 28) {

                // ── Avatar ───────────────────────────────────────
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = profileImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.1))
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(28)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue.opacity(0.25), lineWidth: 2))
                    .shadow(color: Color.blue.opacity(0.15), radius: 10, x: 0, y: 4)
                    .onTapGesture {
                        if profileImage != nil {
                            withAnimation {
                                showingFullProfileImage = true
                            }
                        }
                    }

                    if isEditing {
                        PhotosPicker(selection: $selectedPhotoItem,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .offset(x: 4, y: 4)
                    }
                }
                .padding(.top, 24)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run { 
                                pendingCropImage = img
                                showingCropper = true
                            }
                        }
                    }
                }

                // User full name beneath avatar (read-only display)
                VStack(spacing: 2) {
                    Text(user?.fullName ?? "—")
                        .font(.system(size: 20, weight: .bold))
                    Text(user?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // ── Fields card ──────────────────────────────────
                VStack(spacing: 0) {

                    profileRow(icon: "person.fill", label: "First Name") {
                        if isEditing {
                            TextField("First Name", text: $firstName)
                                .onChange(of: firstName) { _, new in
                                    if new.count > 20 { firstName = String(new.prefix(20)) }
                                }
                        } else {
                            Text(firstName.isEmpty ? "—" : firstName)
                                .foregroundColor(firstName.isEmpty ? .gray : .primary)
                        }
                    }

                    Divider().padding(.leading, 56)

                    profileRow(icon: "person.fill", label: "Last Name") {
                        if isEditing {
                            TextField("Last Name", text: $lastName)
                                .onChange(of: lastName) { _, new in
                                    if new.count > 20 { lastName = String(new.prefix(20)) }
                                }
                        } else {
                            Text(lastName.isEmpty ? "—" : lastName)
                                .foregroundColor(lastName.isEmpty ? .gray : .primary)
                        }
                    }

                    Divider().padding(.leading, 56)

                    profileRow(icon: "envelope.fill", label: "Email") {
                        if isEditing {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(email.isEmpty ? "—" : email)
                                .foregroundColor(email.isEmpty ? .gray : .primary)
                        }
                    }

                    Divider().padding(.leading, 56)

                    // Phone with country picker in edit mode
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "phone.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phone")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if isEditing {
                                HStack(spacing: 6) {
                                    Picker("Code", selection: $selectedCountryCode) {
                                        ForEach(countryCodes, id: \.self) { Text($0).tag($0) }
                                    }
                                    .labelsHidden()
                                    .tint(.blue)

                                    TextField("Phone Number", text: $phoneNumber)
                                        .keyboardType(.phonePad)
                                        .onChange(of: phoneNumber) { _, new in
                                            let digits = new.filter { $0.isNumber }
                                            let clamped = String(digits.prefix(10))
                                            if phoneNumber != clamped { phoneNumber = clamped }
                                        }
                                }
                            } else {
                                Text(phoneNumber.isEmpty ? "—" : phoneNumber)
                                    .foregroundColor(phoneNumber.isEmpty ? .gray : .primary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
                .padding(.horizontal)

                // ── Security Card ─────────────────────────────────
                VStack(spacing: 0) {
                    HStack {
                        Text("Security")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                    
                    if isEditing {
                        // Current Password
                        profileRow(icon: "lock.fill", label: "Current Password") {
                            HStack {
                                if showOldPassword {
                                    TextField("Required to change password", text: $oldPassword)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Required to change password", text: $oldPassword)
                                        .textContentType(.password)
                                }
                                Button {
                                    showOldPassword.toggle()
                                } label: {
                                    Image(systemName: showOldPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Divider().padding(.leading, 56)

                        // New Password
                        profileRow(icon: "lock.fill", label: "New Password") {
                            HStack {
                                if showPassword {
                                    TextField("Leave blank to keep", text: $password)
                                        .textContentType(.newPassword)
                                } else {
                                    SecureField("Leave blank to keep", text: $password)
                                        .textContentType(.newPassword)
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Divider().padding(.leading, 56)

                        // Confirm Password
                        profileRow(icon: "lock.fill", label: "Confirm Password") {
                            HStack {
                                if showConfirm {
                                    TextField("Confirm new password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                } else {
                                    SecureField("Confirm new password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                }
                                Button {
                                    showConfirm.toggle()
                                } label: {
                                    Image(systemName: showConfirm ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                if !confirmPassword.isEmpty {
                                    Image(systemName: password == confirmPassword
                                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(password == confirmPassword ? .green : .red)
                                }
                            }
                        }
                    } else {
                        // Read-only password row
                        profileRow(icon: "lock.fill", label: "Password") {
                            HStack {
                                Text("••••••••")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
                .padding(.horizontal)

                // ── Error ─────────────────────────────────────────
                if let msg = errorMessage {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }


                // ── Log Out button (always visible) ──────────────
                Button(action: { showingLogoutConfirmation = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Log Out")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal)
                
                // ── Delete Account button ────────────────────────
                Button(action: { 
                    accountPassword = ""
                    showingDeleteConfirmation = true 
                }) {
                    Text("Delete Account")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.red.opacity(0.6))
                        .padding(.vertical, 8)
                }
                .padding(.top, 4)
                
                Spacer().frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            loadFromUser()
                            withAnimation { isEditing = false }
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .fontWeight(.bold)
                    } else {
                        Button("Edit") {
                            withAnimation { isEditing = true }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        .onAppear { loadFromUser() }
        .onTapGesture { hideKeyboard() }
        .alert("Profile Updated", isPresented: $showingSuccess) {
            Button("OK") { withAnimation { isEditing = false } }
        } message: {
            Text("Your profile has been saved successfully.")
        }
        .alert("Log Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                withAnimation {
                    loggedInUserId = nil
                    appState.isAuthenticated = false
                }
            }
        } message: {
            Text("Are you sure you want to log out? You'll need to sign in again to access your groups.")
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            SecureField("Enter password", text: $accountPassword)
            Button("Cancel", role: .cancel) { accountPassword = "" }
            Button("Delete", role: .destructive) { deleteUserAccount() }
        } message: {
            Text("This action cannot be undone. Please confirm by entering your password.")
        }
        .sheet(isPresented: $showingFullProfileImage) {
            if let img = profileImage {
                VStack {
                    Spacer()
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .padding(24)
                    Spacer()
                }
                .presentationDragIndicator(.visible)
                .presentationDetents([.fraction(0.65)])
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showingCropper) {
            if let img = pendingCropImage {
                ImageCropperView(image: img) { cropped in
                    profileImage = cropped
                    selectedPhotoItem = nil
                }
            }
        }
        }
    }

    // MARK: - Row builder
    @ViewBuilder
    private func profileRow<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                content()
                    .font(.system(size: 16))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Data helpers
    private func loadFromUser() {
        guard let u = user else { return }
        firstName   = u.firstName
        lastName    = u.lastName
        email       = u.email
        phoneNumber = u.phoneNumber
        password    = ""
        confirmPassword = ""
        oldPassword = ""
        showPassword = false
        showConfirm  = false
        showOldPassword = false
        errorMessage = nil

        // Load saved profile photo
        if let data = u.profileImageData, let img = UIImage(data: data) {
            profileImage = img
        } else {
            profileImage = nil
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pred = NSPredicate(format: "SELF MATCHES %@",
                               "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
        return pred.evaluate(with: email)
    }

    private func saveChanges() {
        guard let u = user else { return }

        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty else {
            withAnimation { errorMessage = "First name, last name and email are required." }
            return
        }

        guard isValidEmail(email) else {
            withAnimation { errorMessage = "Please enter a valid email address." }
            return
        }

        if !password.isEmpty {
            guard oldPassword == u.password else {
                withAnimation { errorMessage = "Current password is incorrect." }
                return
            }
            guard password == confirmPassword else {
                withAnimation { errorMessage = "New passwords do not match." }
                return
            }
        }

        errorMessage = nil

        u.firstName   = firstName
        u.lastName    = lastName
        u.email       = email
        u.phoneNumber = phoneNumber

        if !password.isEmpty {
            u.password = password
        }

        if let img = profileImage {
            u.profileImageData = img.jpegData(compressionQuality: 0.75)
        }

        try? modelContext.save()
        showingSuccess = true
    }

    private func deleteUserAccount() {
        guard let u = user else { return }
        
        if u.password != accountPassword {
            withAnimation { errorMessage = "Incorrect password. Account not deleted." }
            accountPassword = ""
            return
        }
        
        // Password is correct, delete the user
        modelContext.delete(u)
        try? modelContext.save()
        
        // Log out the user
        withAnimation {
            loggedInUserId = nil
            appState.isAuthenticated = false
        }
    }
}
