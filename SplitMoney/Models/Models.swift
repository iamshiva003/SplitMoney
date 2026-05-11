import Foundation
import SwiftData

@Model
class AppUser {
    var id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var password: String // Added for authentication
    var profileImageData: Data? // User's profile photo
    
    @Relationship(inverse: \SplitGroup.members)
    var groups: [SplitGroup]? = []

    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    init(id: UUID = UUID(), firstName: String, lastName: String, email: String, phoneNumber: String, password: String = "", profileImageData: Data? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.password = password
        self.profileImageData = profileImageData
    }
}

@Model
class SplitGroup {
    var id: UUID
    var name: String
    var currency: String = "🇮🇳 ₹ INR"
    var imageData: Data? // Group photo
    @Relationship(deleteRule: .nullify) var members: [AppUser]
    @Relationship(deleteRule: .cascade) var expenses: [Expense]
    
    var currencySymbol: String {
        let components = currency.components(separatedBy: " ")
        return components.count >= 2 ? components[1] : "$"
    }
    
    init(id: UUID = UUID(), name: String, currency: String = "🇮🇳 ₹ INR", imageData: Data? = nil, members: [AppUser] = [], expenses: [Expense] = []) {
        self.id = id
        self.name = name
        self.currency = currency
        self.imageData = imageData
        self.members = members
        self.expenses = expenses
    }
}

enum SplitType: String, Codable {
    case equal
    case custom
}

@Model
class Expense {
    var id: UUID
    var title: String
    var amount: Double
    var date: Date
    var splitType: SplitType
    @Relationship(deleteRule: .cascade) var splitDetails: [SplitDetail]
    var paidBy: AppUser?
    
    init(id: UUID = UUID(), title: String, amount: Double, date: Date = Date(), splitType: SplitType = .equal, splitDetails: [SplitDetail] = [], paidBy: AppUser? = nil) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.splitType = splitType
        self.splitDetails = splitDetails
        self.paidBy = paidBy
    }
}

@Model
class SplitDetail {
    var id: UUID
    var user: AppUser?
    var amount: Double
    
    init(id: UUID = UUID(), user: AppUser? = nil, amount: Double) {
        self.id = id
        self.user = user
        self.amount = amount
    }
}

// A lightweight, non-model struct used for safely passing data between views
// without triggering SwiftData relationship loops or SwiftUI state equality issues.
struct PendingSplitDetail: Identifiable, Equatable, Hashable {
    var id = UUID()
    var userId: UUID
    var userName: String
    var amount: Double
}

struct SplitSummaryData: Hashable {
    let title: String
    let amount: Double
    let details: [PendingSplitDetail]
    let payerId: UUID
    let splitType: SplitType
}

struct DeviceContact: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let phoneNumber: String
    
    var fullName: String {
        return [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
