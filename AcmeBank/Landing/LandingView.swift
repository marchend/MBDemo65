import SwiftUI

/// Post-authentication landing screen.
///
/// Rendered by the composition root (`AcmeBankApp`) the moment
/// `LoginViewModel.signedInSession` flips from `nil` to a populated
/// `UserSession`. The view is intentionally inert — no view model, no
/// repositories, no second network call — because all of the data it
/// renders was already decoded from the ID token claims during sign-in.
/// A future story will replace this with a real Home screen wired
/// through a coordinator; for now this exists to prove the post-auth
/// navigation hop end-to-end.
///
/// Token handling: this view accepts only the two strings it actually
/// renders (`displayName`, `email`), NOT the full `UserSession`. The
/// `accessToken` bearer is held exclusively at the composition root and
/// never travels down through SwiftUI's view tree / `NavigationStack`
/// path values / state-restoration machinery. That keeps the live
/// token's surface area as small as possible — the existing
/// non-`Codable` `UserSession` already blocks on-disk persistence, and
/// this narrowing additionally prevents in-memory diffing/restoration
/// machinery from copying it around. When the coordinator-driven
/// `NavigationStack` ships, only the two display strings will need to
/// be placed into path values, not the bearer token.
///
/// Accessibility identifiers are attached to the individual `Text`
/// views (not to the enclosing `VStack`). Per a prior repo lesson,
/// putting an identifier on a container collapses its child
/// accessibility elements and makes `app.staticTexts["…"]` queries
/// from XCUITest miss the children at runtime.
struct LandingView: View {

    /// The signed-in user's display name (from the ID token's `name`
    /// claim, with fallbacks handled at decode time). Passed in by the
    /// composition root.
    let displayName: String

    /// The signed-in user's email (from the ID token's `email` claim).
    /// Passed in by the composition root.
    let email: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Welcome, \(displayName)")
                .font(.title.weight(.bold))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("LandingView.welcomeGreeting")

            Text(email)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("LandingView.email")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.systemBackground))
    }
}

#if DEBUG
#Preview {
    LandingView(
        displayName: "Marc Henderson",
        email: "marc@example.com"
    )
}
#endif
