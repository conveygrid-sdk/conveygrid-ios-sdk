import Foundation
import UIKit
import Security


enum KeychainStore {
    private static let service = "in.sammati.sdk.secure"
    private static let lock = NSLock()
    private static var memoryFallback: [String: Data] = [:]

    @discardableResult
    static func save(data: Data, forKey key: String) -> Bool {
        delete(forKey: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            lock.lock()
            memoryFallback[key] = data
            lock.unlock()
            return true
        }
        return true
    }

    @discardableResult
    static func save(string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data: data, forKey: key)
    }

    static func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        lock.lock()
        defer { lock.unlock() }
        return memoryFallback[key]
    }

    static func loadString(forKey key: String) -> String? {
        guard let data = loadData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        lock.lock()
        memoryFallback.removeValue(forKey: key)
        lock.unlock()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class SessionStore {
    private let key = "sammati_cid"
    private var inMemorySessionId: String?

    var sessionId: String {
        if let inMemorySessionId, !inMemorySessionId.isEmpty {
            return inMemorySessionId
        }
        if let existing = KeychainStore.loadString(forKey: key), !existing.isEmpty {
            inMemorySessionId = existing
            return existing
        }
        // Migrate from UserDefaults if previously stored
        if let legacy = UserDefaults.standard.string(forKey: key), !legacy.isEmpty {
            KeychainStore.save(string: legacy, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            inMemorySessionId = legacy
            return legacy
        }
        let id = UUID().uuidString.lowercased()
        KeychainStore.save(string: id, forKey: key)
        inMemorySessionId = id
        return id
    }
}

enum LanguageStore {
    static let key = "sammati_notice_preferred_language"

    static var current: String {
        UserDefaults.standard.string(forKey: key) ?? "en"
    }

    static func normalize(_ value: String) -> String {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v.isEmpty ? "en" : String(v.prefix(10))
    }

    static func save(_ value: String) {
        UserDefaults.standard.set(normalize(value), forKey: key)
    }
}

enum DateParser {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let d = formatter.date(from: String(value.prefix(10))) { return d }
        let iso = ISO8601DateFormatter()
        return iso.date(from: value)
    }

    static func normalized(_ value: String?) throws -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let d = parse(value) else { throw SammatiSDKError.invalidDateOfBirth }
        return formatter.string(from: d)
    }
}

enum AgeCalculator {
    static func isMinor(_ dob: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        guard let age = calendar.dateComponents([.year], from: dob, to: now).year else { return false }
        return age < 18
    }
}

enum GuardianValidator {
    static func validate(_ guardian: Guardian) throws {
        guard !guardian.guardianName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SammatiSDKError.guardianNameRequired
        }
        guard guardian.relationshipId?.isEmpty == false || guardian.relationshipCode?.isEmpty == false else {
            throw SammatiSDKError.guardianRelationshipRequired
        }
        guard guardian.guardianEmail?.isEmpty == false || guardian.guardianMobile?.isEmpty == false else {
            throw SammatiSDKError.guardianContactRequired
        }
    }
}

struct PendingConsent: Codable {
    let artifactId: String?
    let preferenceToken: String?
    let linkExpiresAt: Date?
}

enum PendingLinkStore {
    private static let key = "sammati_notice_pending_link"

    static func save(result: ConsentResult) {
        let value = PendingConsent(
            artifactId: result.artifactId,
            preferenceToken: result.preferenceToken,
            linkExpiresAt: result.linkExpiresAt
        )
        if let data = try? JSONEncoder().encode(value) {
            KeychainStore.save(data: data, forKey: key)
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func load() -> PendingConsent? {
        if let data = KeychainStore.loadData(forKey: key) {
            return try? JSONDecoder().decode(PendingConsent.self, from: data)
        }
        // Migrate from UserDefaults if previously stored
        if let legacyData = UserDefaults.standard.data(forKey: key) {
            KeychainStore.save(data: legacyData, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            return try? JSONDecoder().decode(PendingConsent.self, from: legacyData)
        }
        return nil
    }

    static func clear() {
        KeychainStore.delete(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }
}

enum GrantedConsentStore {
    private static let lock = NSLock()
    private static let storageKey = "sammati_granted_consents"
    private static var inMemoryCache: Set<String>?

    private static var grantedNotices: Set<String> {
        get {
            if let inMemoryCache {
                return inMemoryCache
            }
            let loaded = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
            inMemoryCache = loaded
            return loaded
        }
        set {
            inMemoryCache = newValue
            UserDefaults.standard.set(Array(newValue), forKey: storageKey)
        }
    }

    private static func candidateKeys(noticeCode: String, identity: ConsentIdentity) -> [String] {
        var keys: [String] = []
        let n = noticeCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let email = identity.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty {
            keys.append("\(n):email:\(email)")
        }
        let mob = (identity.mobile ?? "").filter(\.isNumber)
        if !mob.isEmpty {
            keys.append("\(n):mobile:\(mob)")
            if mob.count > 10 {
                keys.append("\(n):mobile:\(String(mob.suffix(10)))")
            }
        }
        if let ref = identity.referenceId?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
            keys.append("\(n):ref:\(ref.lowercased())")
        }
        if let sub = identity.subjectRef?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty {
            keys.append("\(n):sub:\(sub.lowercased())")
        }
        let sess = identity.sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sess.isEmpty {
            keys.append("\(n):session:\(sess.lowercased())")
        }
        return keys
    }

    static func record(noticeCode: String, identity: ConsentIdentity) {
        lock.lock()
        defer { lock.unlock() }
        var current = grantedNotices
        for key in candidateKeys(noticeCode: noticeCode, identity: identity) {
            current.insert(key)
        }
        grantedNotices = current
    }

    static func isGranted(noticeCode: String, identity: ConsentIdentity) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let current = grantedNotices
        for key in candidateKeys(noticeCode: noticeCode, identity: identity) {
            if current.contains(key) {
                return true
            }
        }
        return false
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        grantedNotices = []
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleBool(forKeys keys: [K]) -> Bool? {
        for key in keys {
            if let val = try? decodeIfPresent(Bool.self, forKey: key) {
                return val
            }
            if let str = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmed == "true" || trimmed == "1" || trimmed == "yes" { return true }
                if trimmed == "false" || trimmed == "0" || trimmed == "no" { return false }
            }
            if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
                return intVal != 0
            }
        }
        return nil
    }
}

extension UIColor {
    public convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        switch hexSanitized.count {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    public static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        } else {
            return light
        }
    }
}

extension NoticeTheme {
    public var uiPrimaryColor: UIColor {
        if let primaryColor, let color = UIColor(hex: primaryColor) {
            return color
        }
        return UIColor(red: 0.0, green: 0.357, blue: 0.929, alpha: 1.0)
    }

    public var uiSecondaryColor: UIColor? {
        if let secondaryColor, let color = UIColor(hex: secondaryColor) {
            return color
        }
        return nil
    }

    public func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let fontFamily, !fontFamily.isEmpty, let customFont = UIFont(name: fontFamily, size: size) {
            return customFont
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    public var logoImage: UIImage? {
        guard let logoURL, !logoURL.isEmpty else { return nil }
        if logoURL.hasPrefix("data:image/") {
            guard let commaIndex = logoURL.firstIndex(of: ",") else { return nil }
            let base64String = String(logoURL[logoURL.index(after: commaIndex)...])
            guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else { return nil }
            return UIImage(data: data)
        }
        return nil
    }
}

