import Foundation

/**
 * Manages user accounts, authentication, registration, and expiry on iOS.
 * Default user expiry is 31-12-2027.
 * Admin account is permanent with no expiry and full administrative rights.
 */
final class UserManager {
    static let shared = UserManager()
    private init() {}

    private let prefsKey = "capture_pro_users_data"
    private let testExpiryKey = "test_user_expiry_date"
    static let defaultUserExpiry = "31-12-2027"

    struct UserAccount: Identifiable, Codable {
        var id: String { username }
        let username: String
        let password: String
        var expiryDate: String? // nil means No Expiry (like Admin)
        let isAdmin: Bool
    }

    enum LoginResult {
        case success(username: String, isAdmin: Bool)
        case invalidCredentials
        case expired(username: String)
    }

    enum RegisterResult {
        case success
        case emptyFields
        case userAlreadyExists
    }

    // ── Get all user accounts ──────────────────────────────────────────────────
    func getAllUserAccounts() -> [UserAccount] {
        let defaults = UserDefaults.standard
        let testExpiry = defaults.string(forKey: testExpiryKey) ?? Self.defaultUserExpiry

        var list: [UserAccount] = [
            UserAccount(username: "Admin", password: "Adminziya@2016", expiryDate: nil, isAdmin: true),
            UserAccount(username: "Test User", password: "Test@123", expiryDate: testExpiry, isAdmin: false)
        ]

        if let savedData = defaults.string(forKey: prefsKey), !savedData.isEmpty {
            let entries = savedData.components(separatedBy: ";")
            for entry in entries {
                let parts = entry.components(separatedBy: ":::")
                if parts.count >= 2 {
                    let uname = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let pass = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let exp = parts.count >= 3 && !parts[2].isBlank ? parts[2] : Self.defaultUserExpiry
                    list.append(UserAccount(username: uname, password: pass, expiryDate: exp, isAdmin: false))
                }
            }
        }

        return list
    }

    // ── Registration ─────────────────────────────────────────────────────────
    func registerUser(username: String, password: String, expiryDate: String = defaultUserExpiry) -> RegisterResult {
        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanUser.isEmpty || cleanPass.isEmpty {
            return .emptyFields
        }

        let allUsers = getAllUserAccounts()
        if allUsers.contains(where: { $0.username.caseInsensitiveCompare(cleanUser) == .orderedSame }) {
            return .userAlreadyExists
        }

        let defaults = UserDefaults.standard
        let existing = defaults.string(forKey: prefsKey) ?? ""
        var entries = existing.isEmpty ? [] : existing.components(separatedBy: ";")
        entries.append("\(cleanUser):::\(cleanPass):::\(expiryDate)")

        defaults.set(entries.joined(separator: ";"), forKey: prefsKey)
        return .success
    }

    // ── Update Expiry ─────────────────────────────────────────────────────────
    func updateUserExpiry(username: String, newExpiry: String) -> Bool {
        if username.caseInsensitiveCompare("Admin") == .orderedSame {
            return false // Admin has no expiry
        }

        let defaults = UserDefaults.standard

        if username.caseInsensitiveCompare("Test User") == .orderedSame {
            defaults.set(newExpiry, forKey: testExpiryKey)
            return true
        }

        guard let existing = defaults.string(forKey: prefsKey), !existing.isEmpty else { return false }
        let entries = existing.components(separatedBy: ";")
        let updated = entries.map { entry -> String in
            let parts = entry.components(separatedBy: ":::")
            if !parts.isEmpty && parts[0].caseInsensitiveCompare(username) == .orderedSame {
                let pass = parts.count >= 2 ? parts[1] : ""
                return "\(parts[0]):::\(pass):::\(newExpiry)"
            }
            return entry
        }

        defaults.set(updated.joined(separator: ";"), forKey: prefsKey)
        return true
    }

    // ── Remove User ───────────────────────────────────────────────────────────
    func removeUser(username: String) -> Bool {
        if username.caseInsensitiveCompare("Admin") == .orderedSame {
            return false
        }

        let defaults = UserDefaults.standard
        guard let existing = defaults.string(forKey: prefsKey), !existing.isEmpty else { return false }
        let entries = existing.components(separatedBy: ";")
        let filtered = entries.filter { entry in
            let parts = entry.components(separatedBy: ":::")
            return !(parts.count > 0 && parts[0].caseInsensitiveCompare(username) == .orderedSame)
        }

        defaults.set(filtered.joined(separator: ";"), forKey: prefsKey)
        return true
    }

    // ── Authentication ────────────────────────────────────────────────────────
    func authenticate(username: String, password: String) -> LoginResult {
        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        let users = getAllUserAccounts()
        guard let match = users.first(where: {
            $0.username.caseInsensitiveCompare(cleanUser) == .orderedSame && $0.password == cleanPass
        }) else {
            return .invalidCredentials
        }

        if let exp = match.expiryDate, isExpired(exp) {
            return .expired(username: match.username)
        }

        return .success(username: match.username, isAdmin: match.isAdmin)
    }

    func isExpired(_ expiryDateStr: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let expiryDate = formatter.date(from: expiryDateStr) else { return false }
        return Date() > expiryDate
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
