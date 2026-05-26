# Bootstrap Plan — AcmeBank iOS

## In scope (this PR)

### Project name + tech stack decisions
- **App name:** AcmeBank
- **Platform:** iOS 17+, Swift 5.10, SwiftUI
- **Architecture:** MVVM + Coordinator (deferred — only shell wired in bootstrap)
- **Project file:** XcodeGen `project.yml` (never hand-crafted `.pbxproj`)
- **Test framework:** XCTest (unit tests) — XCUITest target declared but empty bootstrap only has unit test
- **Bundle ID:** `com.acmebank.mobile`
- **Min Xcode:** 16.0

### Directory structure (bootstrap only)
```
AcmeBank/                        ← SwiftUI source root
  App/
    AcmeBankApp.swift            ← @main SwiftUI entry point
    ContentView.swift            ← Hello World placeholder view
  Resources/
    Assets.xcassets/
      AppIcon.appiconset/
        Contents.json
      Contents.json
  AcmeBank.entitlements          ← stub keychain entitlements
  PrivacyInfo.xcprivacy          ← stub privacy manifest
AcmeBankTests/
  AcmeBankTests.swift            ← one trivial XCTest (proves test runner works)
project.yml                      ← XcodeGen spec
.gitignore                       ← standard iOS / XcodeGen ignores
setup.sh                         ← one-shot materialisation script
bootstrap_plan.md
CLAUDE.md
AGENT.md
README.md
```

### Files this PR creates
| File | Purpose |
|---|---|
| `project.yml` | XcodeGen project spec — iOS 17+, SwiftUI, two test targets |
| `AcmeBank/App/AcmeBankApp.swift` | `@main` SwiftUI App entry point showing Hello World |
| `AcmeBank/App/ContentView.swift` | Placeholder view displaying "AcmeBank" text |
| `AcmeBank/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | Stub AppIcon to satisfy actool |
| `AcmeBank/Resources/Assets.xcassets/Contents.json` | Asset catalog metadata |
| `AcmeBank/AcmeBank.entitlements` | Stub keychain-access-groups entitlements |
| `AcmeBank/PrivacyInfo.xcprivacy` | Stub privacy manifest (UserDefaults reason CA92.1) |
| `AcmeBankTests/AcmeBankTests.swift` | One XCTest proving the test target compiles + links |
| `.gitignore` | Ignores generated `.xcodeproj`, `DerivedData`, macOS cruft |
| `setup.sh` | Installs XcodeGen, runs `xcodegen generate`, opens Xcode |
| `CLAUDE.md` | Project docs for Anthropic agents |
| `AGENT.md` | Project docs for other model families (identical to CLAUDE.md) |
| `README.md` | Human-readable project README |

### How to run locally
```
./setup.sh                  # installs xcodegen, generates .xcodeproj, opens Xcode
# OR manually:
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```
Then build and run the `AcmeBank` scheme on an iOS 17+ simulator.

### How to run tests
```
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

### Definition of Hello World
The app launches on an iOS simulator and displays a single screen with the text **"AcmeBank"** centred on a white background. One unit test (`test_contentView_initializes`) passes, proving the XCTest target compiles and links against the app module.

---

## Out of scope — deferred to future work

- **Authentication (Okta OIDC via `okta-mobile-swift`)** — future PR
- **MVVM + Coordinator full wiring** (AppCoordinator, RootView, LoginCoordinator, TabBarCoordinator, HomeCoordinator, etc.) — future PR
- **Networking layer** (APIClient, APIRouter, APIError, RequestInterceptor, Bearer token injection) — future PR
- **Domain models** (Account, Transaction, Customer, TransferRequest, AccountType) — future PR
- **Repository protocols** (AccountRepositoryProtocol, TransactionRepositoryProtocol, CustomerRepositoryProtocol, TransferRepositoryProtocol) — future PR
- **Mock data layer** (MockAccountRepository, MockTransactionRepository, MockCustomerRepository) — future PR
- **Remote data layer** (AccountAPIRepository, TransactionAPIRepository, CustomerAPIRepository) — future PR
- **Features / screens** (Login, Home, Accounts, Transfer, Cards, More/Settings) — future PRs per feature story
- **Design system tokens** (Colors.swift with acmeNavy/acmeGreen/etc., Typography.swift with Font scale) — future PR
- **Internal notifications** (AppNotification typed names, NotificationPublisher, NotificationKey) — future PR
- **Core extensions** (Decimal+Currency, Date+Greeting, String+Initials) — future PR
- **Keychain helpers** (KeychainStore read/write helpers) — future PR
- **UserSession value type** — future PR
- **XCUITest flows** (LoginUITests, TransferUITests) — future PRs per critical-flow story
- **SwiftLint config** (`.swiftlint.yml`, `-warnings-as-errors` xcconfig) — future PR
- **CI/CD pipeline** (GitHub Actions `ios-build.yml`, xcconfig injection) — future PR
- **Okta.plist + .plist.example** — future PR (auth story)
- **Localizable.strings** — future PR
- **Info.plist API_BASE_URL key + xcconfig injection** — future PR
