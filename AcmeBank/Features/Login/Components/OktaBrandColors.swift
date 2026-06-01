import SwiftUI

// MARK: - Okta Brand Colours
//
// Defines the single canonical Okta-blue token used by `OktaHeaderView`
// and `SecuredByOktaFooterView`.
//
// TODO: Once `DesignSystem/Colors.swift` lands, replace this with the
//       proper design-system token (e.g. `Color.oktaBrand`) and delete
//       this file.  The two call-sites are OktaHeaderView.swift and
//       SecuredByOktaFooterView.swift.

extension Color {
    /// The Okta brand blue used for the Okta badge in the login screen header
    /// and footer.  Defined here so that the one literal appears in exactly one
    /// place; a future `DesignSystem/Colors.swift` token swap needs only a
    /// single edit.
    static let oktaBrand = Color(red: 0.0, green: 0.58, blue: 0.83)
}
