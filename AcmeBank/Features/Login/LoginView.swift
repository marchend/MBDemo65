import SwiftUI

/// The login screen.
///
/// Renders the AcmeBank brand logo, username / password fields,
/// an eye-toggle to reveal the password, a "Keep me signed in"
/// checkbox, a "Need help?" link (opens in-app Safari), and the
/// primary Sign In button.
///
/// All business state lives in `LoginViewModel`. Pure UI state
/// (`isPasswordVisible`, `showHelpSheet`) lives here as `@State`
/// properties, per the MVVM rule that ViewModels hold no UI
/// presentation decisions.
struct LoginView: View {

    // MARK: - ViewModel

    @StateObject var viewModel: LoginViewModel

    // MARK: - Pure-UI State

    /// Controls whether the password field masks its input.
    @State private var isPasswordVisible: Bool = false

    /// Controls presentation of the "Need help?" in-app Safari sheet.
    @State private var showHelpSheet: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                logoSection
                    .padding(.top, 56)
                    .padding(.bottom, 40)

                formSection
                    .padding(.horizontal, 24)

                Spacer(minLength: 32)
            }
        }
        .background(Color.acmeBackground.ignoresSafeArea())
        .sheet(isPresented: $showHelpSheet) {
            if let url = URL(string: "https://acmebank.com/help") {
                SafariSheetView(url: url)
            }
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            // Hexagonal brand logo using a clipped navy hexagon shape
            // with the initials "AB" as a fallback until an asset is
            // added to Assets.xcassets.
            ZStack {
                HexagonShape()
                    .fill(Color.acmeNavy)
                    .frame(width: 88, height: 88)

                Text("AB")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("AcmeBank logo")

            Text("AcmeBank")
                .font(.acmeTitle)
                .foregroundStyle(Color.acmeNavy)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 20) {

            // Error banner — visible only when errorMessage is non-nil
            ErrorBannerView(message: viewModel.errorMessage)
                .accessibilityIdentifier("loginError")

            // Username field
            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.acmeCaption)
                    .foregroundStyle(Color.acmeSubtext)

                TextField("Enter your username", text: $viewModel.username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.acmeSurface)
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    )
                    .accessibilityIdentifier("usernameField")
            }

            // Password field with eye-toggle
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.acmeCaption)
                    .foregroundStyle(Color.acmeSubtext)

                HStack(spacing: 0) {
                    Group {
                        if isPasswordVisible {
                            TextField("Enter your password", text: $viewModel.password)
                                .accessibilityIdentifier("passwordField")
                        } else {
                            SecureField("Enter your password", text: $viewModel.password)
                                .accessibilityIdentifier("passwordField")
                        }
                    }
                    .textContentType(.password)
                    .padding(.leading, 14)
                    .padding(.vertical, 12)

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible
                              ? "eye.slash.fill"
                              : "eye.fill")
                            .foregroundStyle(Color.acmeSubtext)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(isPasswordVisible
                                        ? "Hide password"
                                        : "Show password")
                    .accessibilityIdentifier("passwordVisibilityToggle")
                    .padding(.trailing, 4)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.acmeSurface)
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                )
            }

            // Keep me signed in checkbox
            Toggle(isOn: $viewModel.keepMeSignedIn) {
                Text("Keep me signed in")
                    .font(.acmeBody)
                    .foregroundStyle(Color.acmeText)
            }
            .toggleStyle(CheckboxToggleStyle())
            .accessibilityIdentifier("keepMeSignedInToggle")
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sign In button
            Button {
                viewModel.signInTapped()
            } label: {
                Text("Sign In")
                    .font(.acmeHeadline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.isSignInEnabled
                                  ? Color.acmeNavy
                                  : Color.acmeNavy.opacity(0.4))
                    )
            }
            .disabled(!viewModel.isSignInEnabled)
            .accessibilityIdentifier("signInButton")

            // Need help? link
            Button {
                showHelpSheet = true
            } label: {
                Text("Need help?")
                    .font(.acmeCaption)
                    .foregroundStyle(Color.acmeNavy)
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("needHelpButton")
        }
    }
}

// MARK: - Hexagon Shape

/// A regular hexagon (flat-top orientation) used for the brand logo.
private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let point = CGPoint(
                x: centre.x + radius * cos(angle),
                y: centre.y + radius * sin(angle)
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Login — empty") {
    LoginView(viewModel: LoginViewModel())
}

#Preview("Login — filled") {
    let vm = LoginViewModel()
    vm.username = "user@acmebank.com"
    vm.password = "s3cr3t!"
    return LoginView(viewModel: vm)
}

#Preview("Login — error") {
    let vm = LoginViewModel()
    vm.username = "user@acmebank.com"
    vm.password = "wrongpass"
    vm.errorMessage = "Your username or password is incorrect. Please try again."
    return LoginView(viewModel: vm)
}
#endif
