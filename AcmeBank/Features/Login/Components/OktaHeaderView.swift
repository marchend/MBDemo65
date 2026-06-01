import SwiftUI

/// A decorative header strip shown at the top of `LoginView`.
///
/// Displays a lock icon, the `acmebank.okta.com` URL text on the
/// leading side, and an Okta-branded badge on the trailing side —
/// mimicking the address-bar branding pattern used in Okta-hosted
/// sign-in pages.
struct OktaHeaderView: View {

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                // Lock icon + URL label
                Label {
                    Text("acmebank.okta.com")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                        .accessibilityIdentifier("OktaHeaderView.url")
                } icon: {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                // Okta logo badge (SF Symbol placeholder + text)
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.caption)
                        .foregroundStyle(Color.oktaBrand)
                    Text("Okta")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.oktaBrand)
                }
                .accessibilityLabel("Okta identity provider")
                .accessibilityIdentifier("OktaHeaderView.oktaBadge")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("OktaHeaderView")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    OktaHeaderView()
}
#endif
