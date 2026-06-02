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
/// Accessibility identifiers are attached to the individual `Text`
/// views (not to the enclosing `VStack`). Per a prior repo lesson,
/// putting an identifier on a container collapses its child
/// accessibility elements and makes `app.staticTexts["…"]` queries
/// from XCUITest miss the children at runtime.
struct LandingView: View {

    /// The authenticated session. Passed in by the composition root via
    /// SwiftUI navigation state — never read from `UserDefaults`,
    /// `NotificationCenter`, or a singleton.
    let session: UserSession

    var body: some View {
        VStack(spacing: 8) {
            Text("Welcome, \(session.displayName)")
                .font(.title.weight(.bold))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("LandingView.welcomeGreeting")

            Text(session.email)
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
        session: UserSession(
            userId: "preview-sub",
            displayName: "Marc Henderson",
            email: "marc@example.com",
            accessToken: "preview-access-token",
            authTimestamp: Date(),
            deviceName: "Preview Device"
        )
    )
}
#endif
