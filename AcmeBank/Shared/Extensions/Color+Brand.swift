import SwiftUI

// MARK: - AcmeBank brand colour palette

extension Color {

    /// AcmeBank primary navy — `#1B2A4A`.
    ///
    /// Used for primary buttons, active checkbox fills, and brand
    /// headings throughout the app.
    static let acmeNavy = Color(hex: 0x1B2A4A)
}

// MARK: - Hex initialiser

private extension Color {
    /// Initialises a `Color` from a 24-bit RGB hex integer.
    ///
    /// - Parameter hex: An integer in the form `0xRRGGBB`.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
