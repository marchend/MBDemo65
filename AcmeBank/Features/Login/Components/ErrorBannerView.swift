import SwiftUI

/// A reusable inline error banner.
///
/// Renders a yellow-tinted `HStack` with a warning SF Symbol and the
/// supplied `message`. When `message` is `nil` or empty the banner
/// has zero opacity so it takes no space and participates in no
/// interaction — pass a `Binding<String?>` and update it from the
/// ViewModel's `errorMessage` property.
struct ErrorBannerView: View {

    /// The message to display. Set to `nil` or `""` to hide the banner.
    let message: String?

    var body: some View {
        Group {
            if let message = message, !message.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.acmeErrorIcon)
                        .accessibilityHidden(true)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color.acmeErrorText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.acmeErrorBackground)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(message)
                .accessibilityIdentifier("ErrorBannerView.container")
            }
        }
    }
}

// MARK: - Convenience colour aliases (scoped to the banner)

private extension Color {
    /// Amber warning icon tint.
    static let acmeErrorIcon = Color(red: 0.80, green: 0.53, blue: 0.00)
    /// Dark body text for the error message.
    static let acmeErrorText = Color(red: 0.30, green: 0.15, blue: 0.00)
    /// Light amber background for the banner container.
    static let acmeErrorBackground = Color(red: 1.00, green: 0.95, blue: 0.80)
}

// MARK: - Previews

#if DEBUG
#Preview("With message") {
    ErrorBannerView(message: "Your username or password is incorrect. Please try again.")
        .padding()
}

#Preview("Empty message — hidden") {
    ErrorBannerView(message: nil)
        .padding()
}
#endif
