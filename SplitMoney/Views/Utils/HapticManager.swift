import SwiftUI
import UIKit

struct HapticManager {
    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "enableHaptics") == nil {
            return true // Default preference is enabled
        }
        return UserDefaults.standard.bool(forKey: "enableHaptics")
    }
    
    static func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
