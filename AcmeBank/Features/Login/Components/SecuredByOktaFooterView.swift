import SwiftUI

/// A footer strip displayed at the bottom of `LoginView`.
///
/// Shows a centred "Secured by" label alongside an Okta badge to
/// communicate that AcmeBank's authentication is powered by Okta.
struct SecuredByOktaFooterView: View {

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 6) {
                Spacer()

                Text("Secured by")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))

                HStack(spacing: 4) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.caption)
                        .foregroundStyle(Color.oktaBrand)
                    Text("Okta")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.oktaBrand)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SecuredByOktaFooterView")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    SecuredByOktaFooterView()
}
#endif
