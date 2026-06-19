import Foundation

struct ExpiryGuard {
    static func isExpired() -> Bool {
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        let calendar = Calendar.current
        guard let expiryDate = calendar.date(from: components) else {
            return true
        }
        
        return Date() > expiryDate
    }
}
