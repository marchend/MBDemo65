# AcmeBank — Agent Guide

## Project Overview
AcmeBank is an iOS banking app (iOS 17+, Swift 5.10, SwiftUI) that lets customers view accounts and transactions, initiate transfers, pay bills, and manage cards — secured via Okta OIDC authentication. The app currently shows the LoginView on launch (auth integration deferred to follow-up stories).

## Tech Stack
| Item | Value |
|---|---|
| Platform | iOS 17+, Xcode 16+ |
| Language | Swift 5.10 |
| UI Framework | SwiftUI |
| Architecture | MVVM + Coordinator (`NavigationStack`) |
| Auth | Okta OIDC via `okta-mobile-swift` `OktaDirectAuth` (in progress) |
| Networking | `URLSession` + async/await (deferred) |
| DI | Constructor injection; no service locator |
| Project file | XcodeGen `project.yml` — **never hand-edit `.pbxproj`** |
| Unit tests | XCTest (`AcmeBankTests/`) |
| UI tests | XCUITest (`AcmeBankUITests/`) |
| Bundle ID | `com.acmebank.mobile` |

## How to Run Locally
```bash
./setup.sh          # installs xcodegen, generates .xcodeproj, opens Xcode
# OR manually:
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```
Build and run the `AcmeBank` scheme on an iOS 17+ simulator.

## How to Run Tests
```bash
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Key Directory Structure
```
AcmeBank/                   ← SwiftUI source root (XcodeGen glob: sources: [AcmeBank])
  App/                      ← @main entry point + root views (implemented)
  Configuration/            ← OktaConfig.swift + InjectOktaConfig.sh Run Script (implemented)
  Core/Auth/                ← AuthService, KeychainStore, UserSession (deferred)
  Core/Networking/          ← APIClient, APIRouter, APIError, RequestInterceptor (deferred)
  Core/Notifications/       ← AppNotification, NotificationPublisher (deferred)
  Core/Extensions/          ← Decimal+Currency, Date+Greeting, String+Initials (deferred)
  Domain/Models/            ← Account, Transaction, Customer, TransferRequest (deferred)
  Domain/Repositories/      ← Protocol-only repository interfaces (deferred)
  Data/Remote/              ← APIRepository implementations (deferred)
  Data/Mock/                ← MockRepository implementations (deferred)
  Features/Login/           ← LoginView + LoginViewModel (implemented); LoginCoordinator (deferred)
  Features/Home/            ← HomeCoordinator, HomeView, HomeViewModel (deferred)
  Features/Accounts/        ← (deferred)
  Features/Transfer/        ← (deferred)
  Features/Cards/           ← (deferred)
  DesignSystem/             ← Colors.swift, Typography.swift (deferred)
  Resources/                ← Assets.xcassets, PrivacyInfo.xcprivacy (implemented)
  Info.plist                ← OKTA_* env vars injected here at build time (see README)
AcmeBankTests/              ← XCTest unit tests
AcmeBankUITests/            ← XCUITest end-to-end tests
project.yml                 ← XcodeGen spec (source of truth for .xcodeproj)
setup.sh                    ← one-shot materialisation script
```

## Current App Entry Point
`ContentView` (owned by `AcmeBankApp`) renders `LoginView` as the app root. `LoginViewModel.onSignIn` is a no-op stub — real Okta auth is wired in a follow-up story.

## Okta Build Configuration (IMPORTANT)
Okta tenant values (`OKTA_ISSUER`, `OKTA_CLIENT_ID`, `OKTA_REDIRECT_URI`,
`OKTA_SCOPES`) are **never committed**. They're read from the build
machine's environment by `AcmeBank/Configuration/InjectOktaConfig.sh`
(an Xcode Run Script build phase) and written into the built
`Info.plist` via `plutil`. Runtime code reads them via
`Bundle.main.infoDictionary` through `OktaConfig.load()`. When an env
var is unset, the script writes a sentinel string instead of failing
the build; `OktaConfig.load()` detects the sentinel and returns
`.notConfigured(reason:)` so CI without secrets still produces a
runnable app. See README "Okta build configuration" for the three
ways to set the env vars (Finder-launched Xcode, shell-launched Xcode,
scripted `xcodebuild`).

## Planned Architecture

### MVVM + Coordinator (deferred — future PR)
- **View** — SwiftUI `View` struct; zero business logic; renders ViewModel `@Published` state.
- **ViewModel** — `final class: ObservableObject`; holds `@Published` state; calls repositories; never imports SwiftUI view types.
- **Coordinator** — `ObservableObject`; owns `NavigationStack` path; drives push/present declaratively; no imperative `push`/`present` from views.
- **Coordinator hierarchy:** `AppCoordinator` → `LoginCoordinator` / `TabBarCoordinator` → (`HomeCoordinator`, `TransferCoordinator`, `CardsCoordinator`, `MoreCoordinator`).

### Authentication — Okta OIDC (in progress)
- `AuthServiceProtocol`: `signIn()`, `signOut()`, `refreshTokenIfNeeded()`, `isSignedIn`.
- Tokens stored in Keychain via `KeychainStore` (always use `kSecUseDataProtectionKeychain: true` for CI simulator compatibility).
- `UserSession` value type passed through coordinators; never stored in `UserDefaults` or a global singleton.
- Tenant config loaded via `OktaConfig.load()` (see "Okta Build Configuration" above).

### Networking (deferred — future PR)
- `APIClient(baseURL:interceptor:)` wraps `URLSession`; decodes with `.convertFromSnakeCase` + `.iso8601`.
- `APIRouter` enum expresses all endpoints; `RequestInterceptor` injects Bearer token; HTTP 401 posts `AppNotification.sessionExpired`.
- Base URL read from `Info.plist` key `API_BASE_URL` (injected by CI xcconfig).

### Design System (deferred — future PR)
- `DesignSystem/Colors.swift` — `Color.acmeNavy`, `.acmeBackground`, `.acmeSurface`, `.acmeText`, `.acmeSubtext`, `.acmeGreen`, `.acmeBadgeRed`.
- `DesignSystem/Typography.swift` — `Font.acmeTitle`, `.acmeHeadline`, `.acmeBody`, `.acmeCaption`, `.acmeMonoBalance`.

### Keychain Note (IMPORTANT for future agents)
Any Keychain query **must** include `kSecUseDataProtectionKeychain: true`. Without this flag, `SecItem*` calls fail with `errSecMissingEntitlement` (-34018) in CI's `CODE_SIGNING_ALLOWED=NO` simulator runs. The `AcmeBank/AcmeBank.entitlements` file (already committed) handles the signed-device path; the flag handles the simulator path.

## Deferred Work
- Authentication runtime — AuthService wiring DirectAuth, KeychainStore, UserSession — future PR
- MVVM+Coordinator wiring (AppCoordinator, RootView, TabBarCoordinator, all feature coordinators) — future PR
- Networking layer (APIClient, APIRouter, APIError, RequestInterceptor) — future PR
- Domain models (Account, Transaction, Customer, TransferRequest) — future PR
- Repository protocols + Mock/Remote data layer — future PR
- Feature screens (Home, Accounts, Transfer, Cards, More) — future PRs per story
- Design system tokens (Colors, Typography) — future PR
- Internal notifications (AppNotification, NotificationPublisher, NotificationKey) — future PR
- Core extensions (Decimal+Currency, Date+Greeting, String+Initials) — future PR
- SwiftLint config (`.swiftlint.yml`, `-warnings-as-errors` xcconfig) — future PR
- CI/CD pipeline (GitHub Actions `ios-build.yml`, xcconfig injection) — future PR
- Localizable.strings — future PR
- API_BASE_URL xcconfig injection — future PR

## Git Workflow

> **Default PR target branch: `develop`.** Every feature/refactor/docs PR
> opens against `develop`. PRs are only opened against `qa`, `uat`, or
> `main` for explicit promotion PRs.

**Branch model (`develop` → `qa` → `uat` → `main`):**

| Branch  | Role                                 | Receives PRs from              | Promotes to |
|---------|--------------------------------------|--------------------------------|-------------|
| develop | Default integration branch           | feature branches               | qa          |
| qa      | First quality gate                   | develop (promotion PR)         | uat         |
| uat     | Pre-prod acceptance                  | qa (promotion PR)              | main        |
| main    | Production / release tags            | uat (promotion PR)             | tagged only |

All feature PRs MUST target `develop`. Never open a feature PR against
`qa`, `uat`, or `main`. Promotions happen via dedicated promotion PRs.
