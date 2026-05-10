import Foundation
import SwiftUI
import Observation
import Vision

@Observable
class AppState {
    var isAuthenticated: Bool = false
    var currentUser: AppUser? = nil
    
    // Deep Link / Share Data
    var pendingSharedAmount: String? = nil
    var pendingSharedNote: String? = nil
    var showIncomingShareFlow: Bool = false
    var isProcessingOCR: Bool = false
    
    // Some mock contacts for prototype
    var mockContacts: [AppUser] = [
        AppUser(firstName: "Alice", lastName: "Smith", email: "alice@example.com", phoneNumber: "123-456-7890"),
        AppUser(firstName: "Bob", lastName: "Jones", email: "bob@example.com", phoneNumber: "123-456-7891"),
        AppUser(firstName: "Charlie", lastName: "Brown", email: "charlie@example.com", phoneNumber: "123-456-7892"),
        AppUser(firstName: "Diana", lastName: "Prince", email: "diana@example.com", phoneNumber: "123-456-7893")
    ]
    
    func parseSharedImage(_ image: UIImage) {
        isProcessingOCR = true
        
        guard let cgImage = image.cgImage else {
            isProcessingOCR = false
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                DispatchQueue.main.async { self?.isProcessingOCR = false }
                return
            }
            
            // NEW: Weighted Scoring Strategy
            self?.processScoringOCR(observations)
        }
        
        request.recognitionLevel = .accurate
        do {
            try handler.perform([request])
        } catch {
            isProcessingOCR = false
        }
    }
    
    func processScoringOCR(_ observations: [VNRecognizedTextObservation]) {
        var candidates: [(val: Double, score: Int, observation: VNRecognizedTextObservation)] = []
        
        // 1. First, find important "Anchor" observations (like "Paid to" or "Transaction Successful")
        var anchors: [VNRecognizedTextObservation] = []
        for obs in observations {
            let text = obs.topCandidates(1).first?.string ?? ""
            if text.localizedCaseInsensitiveContains("Paid to") || 
               text.localizedCaseInsensitiveContains("Successful") ||
               text.localizedCaseInsensitiveContains("Total") ||
               text.localizedCaseInsensitiveContains("Sent") {
                anchors.append(obs)
            }
        }
        
        // 2. Identify and Score all numeric candidates
        for obs in observations {
            guard let topCandidate = obs.topCandidates(1).first else { continue }
            let text = topCandidate.string
            
            // IGNORE strings that look like emails, VPAs, or bank fragments (contains @ or multiple dots)
            if text.contains("@") || text.components(separatedBy: ".").count > 2 { continue }
            
            // Clean the text to find potential price numbers
            let clean = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            let numericPart = clean.filter { "0123456789.".contains($0) }
            
            guard let val = Double(numericPart), val > 0 && val < 1000000 else { continue }
            
            // Skip common non-price noise
            if val > 2000 && val < 2030 && !text.contains("₹") { continue } // Likely a year
            if numericPart.count >= 10 { continue } // Likely a transaction ID or phone number
            
            var score = 0
            
            // Bonus 1: Explicit Currency Markers (MASSIVE BOOST for India)
            if text.contains("₹") || text.contains("Rs") || text.localizedCaseInsensitiveContains("INR") {
                score += 5000 
            }
            
            // Bonus 2: Spatial Proximity to Anchors (Paid to, Successful, etc.)
            for anchor in anchors {
                let distY = abs(obs.boundingBox.origin.y - anchor.boundingBox.origin.y)
                if distY < 0.12 { score += 1000 }
            }
            
            // Bonus 3: Visual prominence (Large font = high score)
            score += Int(obs.boundingBox.height * 3000)
            
            // Bonus 4: Decimal precision (Small boost, but don't let it outscore an integer with a ₹ symbol)
            if numericPart.contains(".") { score += 100 }
            
            candidates.append((val, score, obs))
        }
        
        // Pick the winning candidate
        let winner = candidates.sorted { $0.score > $1.score }.first
        
        DispatchQueue.main.async {
            if let best = winner {
                self.pendingSharedAmount = String(format: "%.2f", best.val)
            } else {
                self.pendingSharedAmount = nil
            }
            
            // Extract Note (Merchant Name)
            if let primaryAnchor = anchors.first(where: { $0.topCandidates(1).first?.string.localizedCaseInsensitiveContains("Paid to") ?? false }) {
                // Find the observation closest to "Paid to" that isn't the amount itself
                let merchantObs = observations.filter { obs in
                    let text = obs.topCandidates(1).first?.string ?? ""
                    return obs != primaryAnchor && !text.contains("₹") && !text.localizedCaseInsensitiveContains("Successful") && text.count > 2
                }.min(by: { obs1, obs2 in
                    let dist1 = abs(obs1.boundingBox.origin.y - primaryAnchor.boundingBox.origin.y)
                    let dist2 = abs(obs2.boundingBox.origin.y - primaryAnchor.boundingBox.origin.y)
                    return dist1 < dist2
                })
                
                if let merchant = merchantObs?.topCandidates(1).first?.string {
                    // Clean up merchant name (remove fragments and keep the core name)
                    self.pendingSharedNote = merchant.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if self.pendingSharedNote == nil || self.pendingSharedNote == "Shared Transaction" {
                self.pendingSharedNote = "UPI Transaction"
            }
            
            self.isProcessingOCR = false
        }
    }
    
    func parseSharedText(_ text: String) {
        // Fallback for text-only sharing (like a notification copy-paste)
        let pattern = #"(?:₹|Rs\.?|INR)\s?(\d+(?:,\d{3})*(?:\.\d{1,2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = text as NSString
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            if let firstMatch = results.first {
                let amtString = nsString.substring(with: firstMatch.range(at: 1)).replacingOccurrences(of: ",", with: "")
                self.pendingSharedAmount = amtString
            }
        }
        self.showIncomingShareFlow = (self.pendingSharedAmount != nil)
    }
}
