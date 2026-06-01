import SafariServices
import SwiftUI

/// A thin `UIViewControllerRepresentable` wrapper around
/// `SFSafariViewController` for presenting in-app web pages (e.g.
/// "Need help?" support link) without leaving the app.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showHelp) {
///     SafariSheetView(url: URL(string: "https://acmebank.com/help")!)
/// }
/// ```
struct SafariSheetView: UIViewControllerRepresentable {

    /// The URL to load in the Safari view controller.
    let url: URL

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController,
                                context: Context) {
        // No dynamic updates required — SFSafariViewController is
        // instantiated once per presentation.
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    SafariSheetView(url: URL(string: "https://www.apple.com")!)
}
#endif
