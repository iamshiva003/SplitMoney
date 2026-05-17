import SwiftUI

struct ContactRow: View {
    let contact: DeviceContact
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(String(contact.fullName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    if !contact.phoneNumber.isEmpty {
                        Text(contact.phoneNumber)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
