import Foundation

/// Shared byte/rate/percent formatting.
enum Format {

    static func bytes(_ value: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(value))
    }

    static func bytesShort(_ value: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(max(value, 0)))
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 1 else { return "0 B/s" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false
        let text = formatter.string(fromByteCount: Int64(bytesPerSecond))
        // ByteCountFormatter can round 1.4 B up to "1 B"; keep the unit honest.
        return text + "/s"
    }

    static func percent(_ ratio: Double, decimals: Int = 0) -> String {
        guard ratio.isFinite else { return "—" }
        return String(format: "%.\(decimals)f", ratio * 100)
    }

    static func temperature(_ celsius: Double, fahrenheit: Bool) -> String {
        let value = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return String(format: "%.0f°", value)
    }

    static func minutes(_ value: Int) -> String {
        let hours = value / 60
        let mins = value % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    static func watts(_ value: Double) -> String {
        String(format: "%.1f W", value)
    }
}
