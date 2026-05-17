import UserNotifications
import SwiftUI

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }
    
    func updatePendingExpenseReminders(totalOwed: Double) {
        requestPermission { granted in
            guard granted else { return }
            
            let enableNotifications = UserDefaults.standard.object(forKey: "enableNotifications") == nil ? true : UserDefaults.standard.bool(forKey: "enableNotifications")
            let expenseReminders = UserDefaults.standard.object(forKey: "expenseReminders") == nil ? true : UserDefaults.standard.bool(forKey: "expenseReminders")
            
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            
            guard enableNotifications && expenseReminders else {
                return
            }
            
            // Schedule daily reminder at 4:37 PM (16:37)
            let content = UNMutableNotificationContent()
            content.title = "Pending Expense Reminder ⏰"
            if totalOwed > 0 {
                content.body = "You currently owe ₹\(String(format: "%.0f", totalOwed)) across your SplitMoney groups. Tap to view and settle up!"
            } else {
                content.body = "Keep your SplitMoney groups perfectly balanced! Check your groups to settle up any pending bills."
            }
            content.sound = .default
            content.badge = NSNumber(value: 1)
            
            var dateComponents = DateComponents()
            dateComponents.hour = 16
            dateComponents.minute = 37
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_expense_reminder", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling reminder: \(error.localizedDescription)")
                } else {
                    print("Successfully scheduled daily expense reminder for ₹\(totalOwed) at 16:37")
                }
            }
        }
    }
    
    func testImmediateReminder(totalOwed: Double) {
        requestPermission { granted in
            guard granted else {
                print("Permission not granted for test reminder")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Pending Expense Reminder ⏰"
            if totalOwed > 0 {
                content.body = "You currently owe ₹\(String(format: "%.0f", totalOwed)) across your SplitMoney groups. Tap to view and settle up!"
            } else {
                content.body = "Keep your SplitMoney groups perfectly balanced! Check your groups to settle up any pending bills."
            }
            content.sound = .default
            content.badge = NSNumber(value: 1)
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "test_expense_reminder_\(UUID().uuidString)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling test reminder: \(error.localizedDescription)")
                } else {
                    print("Successfully dispatched test immediate reminder request!")
                }
            }
        }
    }
    
    func sendInstantNudge(to debtorName: String, amount: Double, currencySymbol: String) {
        requestPermission { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Payment Request Sent 💸"
            content.body = "A notification nudge has been sent to \(debtorName) for \(currencySymbol)\(String(format: "%.0f", amount))."
            content.sound = .default
            
            // Schedule 3 seconds from now
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            let request = UNNotificationRequest(identifier: "instant_nudge_\(UUID().uuidString)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling nudge: \(error.localizedDescription)")
                }
            }
        }
    }
}
