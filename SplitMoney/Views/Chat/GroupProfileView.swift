import SwiftUI
import SwiftData
import PhotosUI

struct GroupProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let group: SplitGroup

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedCurrency: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingPhotoPicker = false
    @State private var pendingImageData: Data? = nil
    @State private var showingManageMembers = false
    @State private var showingFullGroupImage = false
    @State private var pendingCropImage: UIImage? = nil
    @State private var showingCropper = false

    let currencies = [
        "🇮🇳 ₹ INR", "🇺🇸 $ USD", "🇬🇧 £ GBP",
        "🇦🇺 A$ AUD", "🇯🇵 ¥ JPY", "🇪🇺 € EUR", "🇨🇳 ¥ CNY"
    ]

    // The image to display — pending change takes priority
    var displayImageData: Data? { pendingImageData ?? group.imageData }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Group avatar ─────────────────────────────
                    VStack(spacing: 10) {
                        Button {
                            if isEditing { 
                                showingPhotoPicker = true 
                            } else if displayImageData != nil {
                                showingFullGroupImage = true
                            }
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = displayImageData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue.opacity(0.25), lineWidth: 2))
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.1)]),
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 110, height: 110)
                                        Text(String(group.name.prefix(1)).uppercased())
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                }

                                // Camera badge — only visible in edit mode
                                if isEditing {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 4, y: 4)
                                }
                            }
                        }
                        .photosPicker(isPresented: $showingPhotoPicker,
                                      selection: $selectedPhotoItem,
                                      matching: .images)
                        .onChange(of: selectedPhotoItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    await MainActor.run { 
                                        pendingCropImage = img
                                        showingCropper = true
                                    }
                                }
                            }
                        }

                        if isEditing {
                            Button("Change Photo") { showingPhotoPicker = true }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 12)

                    // ── Group Name ───────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Group Name", systemImage: "person.3.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        if isEditing {
                            HStack {
                                TextField("Group Name", text: $editedName)
                                    .font(.system(size: 17))
                                    .onChange(of: editedName) { _, new in
                                        if new.count > 25 { editedName = String(new.prefix(25)) }
                                    }
                                Spacer()
                                Text("\(editedName.count)/25")
                                    .font(.caption2)
                                    .foregroundColor(editedName.count >= 25 ? .red : .secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                        } else {
                            HStack {
                                Text(group.name)
                                    .font(.system(size: 17, weight: .medium))
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)

                    // ── Currency ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Currency", systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        if isEditing {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(currencies, id: \.self) { currency in
                                        let isSelected = editedCurrency == currency
                                        Button {
                                            withAnimation(.spring(response: 0.25)) {
                                                editedCurrency = currency
                                            }
                                        } label: {
                                            Text(currency)
                                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? .white : .primary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 9)
                                                .background(
                                                    isSelected
                                                        ? AnyView(LinearGradient(
                                                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                                                        : AnyView(Color(.systemGray6))
                                                )
                                                .clipShape(Capsule())
                                                .shadow(color: isSelected ? Color.blue.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                            }
                        } else {
                            HStack {
                                Text(group.currency)
                                    .font(.system(size: 17, weight: .medium))
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }

                    // ── Members ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Members", systemImage: "person.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            Button {
                                showingManageMembers = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("Edit")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(Array(group.members.enumerated()), id: \.element.id) { idx, member in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        Text(String(member.fullName.prefix(1)).uppercased())
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.fullName)
                                            .font(.system(size: 15, weight: .medium))
                                        if !member.phoneNumber.isEmpty {
                                            Text(member.phoneNumber)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if idx < group.members.count - 1 {
                                    Divider().padding(.leading, 66)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Group" : "Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            // Discard changes
                            pendingImageData = nil
                            editedName = group.name
                            editedCurrency = group.currency
                            isEditing = false
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            editedName = group.name
                            editedCurrency = group.currency
                            isEditing = true
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(isEditing && editedName.isEmpty ? .gray : .blue)
                    .disabled(isEditing && editedName.isEmpty)
                }
            }
            .onAppear {
                editedName = group.name
                editedCurrency = group.currency
            }
            .sheet(isPresented: $showingManageMembers) {
                ManageMembersView(group: group)
            }
            .sheet(isPresented: $showingFullGroupImage) {
                if let data = displayImageData, let img = UIImage(data: data) {
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
                        pendingImageData = cropped.jpegData(compressionQuality: 0.75)
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }

    private func saveChanges() {
        group.name = String(editedName.prefix(25))
        group.currency = editedCurrency
        if let newData = pendingImageData {
            group.imageData = newData
        }
        try? modelContext.save()
        pendingImageData = nil
        isEditing = false
    }
}
