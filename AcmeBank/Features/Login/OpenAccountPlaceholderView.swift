import SwiftUI

/// A placeholder sheet shown when the user taps "Open one" on the
/// Login screen.
///
/// The full account-opening flow is deferred to a future story. This
/// stub prevents a dead tap target and gives UX acceptance testers a
/// clear signal that the navigation wiring is correct.
struct OpenAccountPlaceholderView: View {

    /// Dismiss the sheet when the "Done" button is tapped.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.acmeNavy)
                    .accessibilityHidden(true)

                Text("Coming soon")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .accessibilityIdentifier("OpenAccountPlaceholderView.title")

                Text("Account opening will be available in a future update.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Open an Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("OpenAccountPlaceholderView.doneButton")
                }
            }
        }
        .accessibilityIdentifier("OpenAccountPlaceholderView")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    OpenAccountPlaceholderView()
}
#endif
