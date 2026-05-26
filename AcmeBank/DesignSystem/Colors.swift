import SwiftUI

// MARK: - AcmeBank brand colour palette
//
// Canonical home for all named Color constants, per bootstrap.md §10.
// Use `Color(hex: "#RRGGBB")` — String-based — throughout the design system.

extension Color {

    /// AcmeBank primary navy — `#1B2A4A`.
    ///
    /// Used for primary buttons, active checkbox fills, and brand
    /// headings throughout the app.
    static let acmeNavy = Color(hex: "#1B2A4A")

    /// Page / screen background — `#F2F3F5`.
    static let acmeBackground = Color(hex: "#F2F3F5")

    /// Card / surface background — white.
    static let acmeSurface = Color.white

    /// Primary body text — `#1A1A1A`.
    static let acmeText = Color(hex: "#1A1A1A")

    /// Secondary / subtext — `#6B7280`.
    static let acmeSubtext = Color(hex: "#6B7280")

    /// Success / positive balance — `#16A34A`.
    static let acmeGreen = Color(hex: "#16A34A")

    /// Error / overdrawn badge — `#DC2626`.
    static let acmeBadgeRed = Color(hex: "#DC2626")
}

// MARK: - String hex initialiser (internal — reusable across the design system)

extension Color {
    /// Initialises a `Color` from a CSS-style hex string.
    ///
    /// Accepted formats: `"#RGB"`, `"#RRGGBB"`, `"#AARRGGBB"`.
    /// The leading `#` is optional.
    ///
    /// - Parameter hex: A hex colour string, e.g. `"#1B2A4A"`.
    init(hex: String) {
        var sanitised = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitised.hasPrefix("#") { sanitised.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: sanitised).scanHexInt64(&value)

        let r, g, b, a: Double
        switch sanitised.count {
        case 3:
            // #RGB → #RRGGBB
            r = Double((value >> 8) & 0xF) / 15.0
            g = Double((value >> 4) & 0xF) / 15.0
            b = Double( value       & 0xF) / 15.0
            a = 1.0
        case 6:
            // #RRGGBB
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8)  & 0xFF) / 255.0
            b = Double( value        & 0xFF) / 255.0
            a = 1.0
        case 8:
            // #AARRGGBB
            a = Double((value >> 24) & 0xFF) / 255.0
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8)  & 0xFF) / 255.0
            b = Double( value        & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
