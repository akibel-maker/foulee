import Foundation

enum Fmt {
    private static let french = Locale(identifier: "fr_FR")

    /// "5,23" (km)
    static func km(_ meters: Double, decimals: Int = 2) -> String {
        (meters / 1000).formatted(.number.precision(.fractionLength(decimals)).locale(french))
    }

    /// "1:02:15" ou "32:08"
    static func duration(_ t: TimeInterval) -> String {
        let total = max(0, Int(t.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "5'32\"" (par km)
    static func pace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm.isFinite, secondsPerKm > 0, secondsPerKm < 3600 else { return "--'--\"" }
        let total = Int(secondsPerKm.rounded())
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }

    static func meters(_ m: Double) -> String {
        "\(Int(m.rounded())) m"
    }

    static func date(_ d: Date) -> String {
        d.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(french))
    }

    static func shortDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated).locale(french))
    }

    static func month(_ d: Date) -> String {
        d.formatted(.dateTime.month(.wide).year().locale(french)).capitalized
    }

    // MARK: - Versions parlées (coach vocal)

    static func spokenDuration(_ t: TimeInterval) -> String {
        let total = max(0, Int(t.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) heure\(h > 1 ? "s" : "")") }
        if m > 0 { parts.append("\(m) minute\(m > 1 ? "s" : "")") }
        if s > 0 || parts.isEmpty { parts.append("\(s) seconde\(s > 1 ? "s" : "")") }
        return parts.joined(separator: " ")
    }

    static func spokenPace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm.isFinite, secondsPerKm > 0 else { return "inconnue" }
        return spokenDuration(secondsPerKm) + " au kilomètre"
    }
}
