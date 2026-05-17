import Foundation
import SwiftData

@MainActor
struct AccountingExportService {
    static func exportCSV(modelContext: ModelContext, onProgress: @escaping (String, Double) -> Void) async -> URL? {
        onProgress("Fetching active users...", 0.1)
        try? await Task.sleep(nanoseconds: 50_000_000) // Brief yield for UI animation
        
        // Freshly fetch all active users directly from SQLite and map by persistentModelID
        let activeUsers = (try? modelContext.fetch(FetchDescriptor<AppUser>())) ?? []
        var validUsersMap: [PersistentIdentifier: String] = [:]
        for user in activeUsers {
            validUsersMap[user.persistentModelID] = user.firstName
        }
        
        onProgress("Fetching transaction records...", 0.25)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Freshly fetch all active expenses directly from SQLite and map by persistentModelID
        let activeExpenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
        var validExpMap: [PersistentIdentifier: Expense] = [:]
        for exp in activeExpenses {
            validExpMap[exp.persistentModelID] = exp
        }
        
        onProgress("Analyzing expense groups...", 0.4)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Freshly fetch all active groups directly from SQLite
        let activeGroups = (try? modelContext.fetch(FetchDescriptor<SplitGroup>())) ?? []
        
        var csv = "Group Name,Expense Title,Amount,Currency,Paid By,Date\n"
        
        let totalExpenses = activeGroups.reduce(0) { $0 + $1.expenses.count }
        var processedExpenses = 0
        
        for group in activeGroups {
            let groupName = group.name
            let groupCurr = group.currency
            
            for expProxy in group.expenses {
                processedExpenses += 1
                let percentage = 0.4 + (0.55 * Double(processedExpenses) / Double(max(1, totalExpenses)))
                
                if processedExpenses % max(1, totalExpenses / 20) == 0 || processedExpenses == totalExpenses {
                    onProgress("Exporting \(processedExpenses) of \(totalExpenses) transactions...", percentage)
                    try? await Task.sleep(nanoseconds: 10_000_000) // Yield for progress bar rendering
                }
                
                // Safely resolve the expense proxy using persistentModelID
                guard let exp = validExpMap[expProxy.persistentModelID] else { continue }
                
                let dateStr = exp.date.formatted(date: .abbreviated, time: .omitted)
                let title = exp.title
                let amount = exp.amount
                
                var paidByName = "Unknown"
                if let payerProxy = exp.paidBy {
                    if let name = validUsersMap[payerProxy.persistentModelID] {
                        paidByName = name
                    } else {
                        paidByName = "Deleted User"
                    }
                }
                
                csv += "\"\(groupName)\",\"\(title)\",\(amount),\"\(groupCurr)\",\"\(paidByName)\",\"\(dateStr)\"\n"
            }
        }
        
        onProgress("Finalizing CSV accounting file...", 1.0)
        try? await Task.sleep(nanoseconds: 150_000_000)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SplitMoney_Accounting.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
}
