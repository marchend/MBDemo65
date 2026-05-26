import SwiftUI

// MARK: - AcmeBank typography scale
//
// Canonical Font constants per bootstrap.md §10.
// All sizes are expressed relative to a base text style so they
// respond correctly to the user's Dynamic Type setting.

extension Font {
    /// Large screen / hero heading — 28 pt bold.
    static let acmeTitle = Font.system(size: 28, weight: .bold)

    /// Section heading / button label — 17 pt semibold.
    static let acmeHeadline = Font.system(size: 17, weight: .semibold)

    /// Standard body copy — 15 pt regular.
    static let acmeBody = Font.system(size: 15, weight: .regular)

    /// Supporting / label text — 13 pt regular.
    static let acmeCaption = Font.system(size: 13, weight: .regular)

    /// Monospaced balance / numeric display — 17 pt semibold.
    static let acmeMonoBalance = Font.system(size: 17, weight: .semibold)
        .monospacedDigit()
}
