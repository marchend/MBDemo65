import SwiftUI

/// The Login screen.
///
/// Presents the full AcmeBank sign-in form: Okta-branded address-bar
/// header, hexagonal logo, username / password fields, keep-me-signed-in
/// checkbox, error banner, sign-in button, open-account link, and a
/// "Secured by Okta" footer.
///
/// All state is owned by an injected `LoginViewModel`; this view
/// contains zero business logic.
struct LoginView: View {

    // MARK: - Dependencies

    /// Injected by the caller (e.g. `ContentView`). Use `@ObservedObject`
    /// so the caller retains ownership and SwiftUI re-renders this view
    /// whenever published properties change.
    @ObservedObject var viewModel: LoginViewModel

    // MARK: - Local sheet state

    @State private var showHelpSheet = false
    @State private var showOpenAccountSheet = false

    // MARK: - Help URL

    private let helpURL = URL(string: "https://acmebank.okta.com/help")!

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Address-bar branding strip ──────────────────────
                    OktaHeaderView()

                    // ── Scrollable form content ─────────────────────────
                    VStack(spacing: 20) {

                        // Logo + title + subtitle
                        logoSection

                        // Username field
                        usernameField

                        // Password field (with eye toggle)
                        passwordField

                        // Checkbox + "Need help?" row
                        rememberMeRow

                        // Error banner (hidden when nil)
                        if let errorMessage = viewModel.errorMessage,
                           !errorMessage.isEmpty {
                            ErrorBannerView(message: errorMessage)
                        }

                        // Sign-in button
                        signInButton

                        // "Don't have an account? Open one" row
                        openAccountRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 24)

                    Spacer(minLength: 0)

                    // ── Footer ──────────────────────────────────────────
                    SecuredByOktaFooterView()
                }
                .frame(minHeight: geo.size.height)
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
        // Help sheet
        .sheet(isPresented: $showHelpSheet) {
            SafariSheetView(url: helpURL)
        }
        // Open Account placeholder sheet
        .sheet(isPresented: $showOpenAccountSheet) {
            OpenAccountPlaceholderView()
        }
        .accessibilityIdentifier("LoginView")
    }

    // MARK: - Sub-views

    // Logo, title, subtitle
    private var logoSection: some View {
        VStack(spacing: 12) {
            HexagonLogoView(size: 80)

            Text("AcmeBank")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.acmeNavy)
                .accessibilityIdentifier("LoginView.title")

            Text("Sign in to your account")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .accessibilityIdentifier("LoginView.subtitle")
        }
        .padding(.bottom, 4)
    }

    // Username TextField
    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Username")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(.label))

            TextField("Enter your username", text: $viewModel.username)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )
                .frame(minHeight: 44)
                .disabled(viewModel.isSigningIn)
                .accessibilityIdentifier("LoginView.usernameField")
        }
    }

    // Password SecureField / TextField with eye toggle
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(.label))

            ZStack(alignment: .trailing) {
                Group {
                    if viewModel.isPasswordVisible {
                        TextField("Enter your password", text: $viewModel.password)
                            .accessibilityIdentifier("LoginView.passwordFieldVisible")
                    } else {
                        SecureField("Enter your password", text: $viewModel.password)
                            .accessibilityIdentifier("LoginView.passwordFieldSecure")
                    }
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.leading, 12)
                .padding(.trailing, 48)
                .padding(.vertical, 12)
                .frame(minHeight: 44)

                // Eye toggle button
                Button {
                    viewModel.isPasswordVisible.toggle()
                } label: {
                    Image(systemName: viewModel.isPasswordVisible
                          ? "eye.slash.fill"
                          : "eye.fill")
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(viewModel.isPasswordVisible
                                    ? "Hide password"
                                    : "Show password")
                .accessibilityIdentifier("LoginView.passwordToggle")
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
            .disabled(viewModel.isSigningIn)
        }
    }

    // "Keep me signed in" checkbox + "Need help?" button
    //
    // Implementation note: this is intentionally a plain `Button` rather
    // than a `Toggle` + `CheckboxToggleStyle`. SwiftUI attaches
    // `.accessibilityIdentifier` on a `Toggle` to the outer accessibility
    // element, which exposes as a Switch/Other element — not a Button —
    // so `app.buttons["LoginView.keepMeSignedInToggle"]` in XCUITest
    // would never find it. Rendering the checkbox as a Button directly
    // (and putting the identifier on that Button) makes the element
    // discoverable as `app.buttons[...]`.
    private var rememberMeRow: some View {
        HStack(alignment: .center) {
            Button {
                viewModel.keepMeSignedIn.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.keepMeSignedIn
                          ? "checkmark.square.fill"
                          : "square")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(viewModel.keepMeSignedIn
                                         ? Color.acmeNavy
                                         : Color(.secondaryLabel))

                    Text("Keep me signed in")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Keep me signed in")
            .accessibilityValue(viewModel.keepMeSignedIn ? "On" : "Off")
            .accessibilityIdentifier("LoginView.keepMeSignedInToggle")

            Spacer()

            Button("Need help?") {
                showHelpSheet = true
            }
            .font(.subheadline)
            .foregroundStyle(Color.acmeNavy)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("LoginView.needHelpButton")
        }
    }

    // "Sign in" button.
    //
    // While `viewModel.isSigningIn` is true the button label is replaced
    // with a `ProgressView` and the button is disabled so a second tap
    // can't enqueue a concurrent sign-in. The closure-based callsite
    // (`viewModel.signInTapped()`) is replaced with a direct `Task` that
    // awaits the new async path (`viewModel.signIn(...)`) — this is the
    // MD065-7 wiring change. The legacy closure path on `LoginViewModel`
    // remains in place for the preview / existing tests, but the View
    // no longer routes through it.
    private var signInButton: some View {
        Button {
            let username = viewModel.username
            let password = viewModel.password
            let keepSignedIn = viewModel.keepMeSignedIn
            Task {
                await viewModel.signIn(
                    username: username,
                    password: password,
                    keepSignedIn: keepSignedIn
                )
            }
        } label: {
            Group {
                if viewModel.isSigningIn {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Sign in")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(viewModel.isSignInEnabled
                      ? Color.acmeNavy
                      : Color.acmeNavy.opacity(0.4))
        )
        .disabled(!viewModel.isSignInEnabled || viewModel.isSigningIn)
        .accessibilityIdentifier("LoginView.signInButton")
    }

    // "Don't have an account? Open one" row
    private var openAccountRow: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))

            Button("Open one") {
                showOpenAccountSheet = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.acmeNavy)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("LoginView.openOneButton")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Default") {
    LoginView(viewModel: LoginViewModel())
}

#Preview("With error") {
    let vm = LoginViewModel()
    vm.errorMessage = "Your username or password is incorrect. Please try again."
    return LoginView(viewModel: vm)
}
#endif
