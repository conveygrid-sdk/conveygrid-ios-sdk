import Foundation
import os

/// Centralized logging facility for SammatiNoticeSDK.
/// When debug mode is active (enabled by default in DEBUG builds or via SammatiConfiguration.debugMode / SammatiNotice.enableDebugLogging()),
/// detailed HTTP request/response inspection and SDK lifecycle logs are emitted to both standard output and Apple's Unified Logging system (os.Logger).
public final class SammatiLogger {
    private static let lock = NSLock()
    private static var _isDebugEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    private static let osLog = Logger(subsystem: "com.conveygrid.sammati", category: "SDK")

    public static var isDebugEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isDebugEnabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isDebugEnabled = newValue
        }
    }

    private enum Level {
        case debug, info, warn, error
    }

    private static func emit(level: Level, tag: String, message: String) {
        guard isDebugEnabled || level == .error else { return }

        let formatted = "[SammatiNoticeSDK \(tag)] \(message)"

        // 1. Stdout print + immediate flush
        print(formatted)
        fflush(stdout)

        // 2. Apple Unified Logging (Xcode Console & Console.app)
        switch level {
        case .debug:
            osLog.debug("\(formatted, privacy: .public)")
        case .info:
            osLog.info("\(formatted, privacy: .public)")
        case .warn:
            osLog.warning("\(formatted, privacy: .public)")
        case .error:
            osLog.error("\(formatted, privacy: .public)")
        }
    }

    public static func debug(_ message: @autoclosure () -> String) {
        emit(level: .debug, tag: "🛠️ DEBUG", message: message())
    }

    public static func info(_ message: @autoclosure () -> String) {
        emit(level: .info, tag: "ℹ️ INFO", message: message())
    }

    public static func warn(_ message: @autoclosure () -> String) {
        emit(level: .warn, tag: "⚠️ WARN", message: message())
    }

    public static func error(_ message: @autoclosure () -> String) {
        emit(level: .error, tag: "❌ ERROR", message: message())
    }

    public static func logRequest(url: URL, method: String, headers: [String: String], body: Data?) {
        guard isDebugEnabled else { return }
        var log = """
\n==================== [SammatiNoticeSDK 🌐 HTTP REQUEST] ====================
Method:  \(method)
URL:     \(url.absoluteString)
Headers:
"""
        for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
            let displayValue: String
            if k.lowercased().contains("key") || k.lowercased().contains("auth") {
                displayValue = "\(v.prefix(12))... (length: \(v.count))"
            } else {
                displayValue = v
            }
            log += "\n  - \(k): \(displayValue)"
        }
        if let body, !body.isEmpty {
            log += "\nBody:\n\(prettyJsonString(from: body))"
        } else {
            log += "\nBody: (none)"
        }
        log += "\n========================================================================\n"

        print(log)
        fflush(stdout)
        osLog.info("\(log, privacy: .public)")
    }

    public static func logResponse(url: URL, method: String, statusCode: Int, data: Data, durationMs: Double? = nil) {
        guard isDebugEnabled else { return }
        let durationStr = durationMs.map { String(format: " (%.1f ms)", $0) } ?? ""
        var log = """
\n==================== [SammatiNoticeSDK 📥 HTTP RESPONSE] ====================
URL:         \(method) \(url.absoluteString)
Status:      \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))\(durationStr)
Body:
\(prettyJsonString(from: data))
========================================================================\n
"""

        print(log)
        fflush(stdout)
        osLog.info("\(log, privacy: .public)")
    }

    public static func prettyJsonString(from data: Data) -> String {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return String(data: data, encoding: .utf8) ?? "<binary data: \(data.count) bytes>"
    }
}
