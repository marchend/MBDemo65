# AcmeBank iOS

An iOS banking app (iOS 17+, Swift 5.10, SwiftUI) for Acme Bank customers.

> **Current state:** Bootstrap scaffold — Hello World shell only. Production features land in follow-up stories.

## Quick Start

```bash
./setup.sh
```

The script installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) if missing, generates `AcmeBank.xcodeproj` from `project.yml`, and opens it in Xcode.

**Manual fallback** (for environments that block shell scripts):
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## Run Tests

```bash
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Project File

`AcmeBank.xcodeproj` is **generated** — never commit it. The source of truth is `project.yml`. After pulling changes, run `xcodegen generate` to refresh the project file.

## Okta build configuration

The Okta tenant config is **not committed**. It's injected into the built
`Info.plist` at build time from four environment variables, by the
`AcmeBank/Configuration/InjectOktaConfig.sh` Run Script build phase:

| Env var             | Info.plist key     | Example                                  |
|---------------------|--------------------|------------------------------------------|
| `OKTA_ISSUER`       | `OktaIssuer`       | `https://acme.okta.com/oauth2/default`   |
| `OKTA_CLIENT_ID`    | `OktaClientID`     | `0oa1abcDEF23456789`                     |
| `OKTA_REDIRECT_URI` | `OktaRedirectURI`  | `com.acmebank.mobile:/callback`          |
| `OKTA_SCOPES`       | `OktaScopes`       | `openid profile email offline_access`    |

When **all four** are set on the build machine, real tenant values flow
through to runtime, `OktaConfig.load()` returns `.configured(...)`, and
DirectAuth runs against the real Okta tenant.

When **any** is unset, the Run Script writes a recognisable sentinel
(`__OKTA_NOT_CONFIGURED__`) into the corresponding Info.plist key. The
runtime `OktaConfig` detects the sentinel and returns
`.notConfigured(reason:)`, which the login screen surfaces in its inline
error banner. CI builds with no Okta secrets still compile, launch, and
exercise the UI — they just can't complete a real sign-in.

### ⚠️ Never hand-edit `AcmeBank/Info.plist`

`AcmeBank/Info.plist` **is** source-controlled (XcodeGen no longer
auto-generates it now that we inject keys at build time), but the four
`Okta*` values in it are placeholders — `__OKTA_NOT_CONFIGURED__`
sentinels that the Run Script overwrites with real values when the env
vars are set. **Do not paste real tenant credentials into this file.**

- ❌ Editing `Info.plist` to "just try it quickly" with real Okta values
  risks committing live tenant secrets — `.gitignore` does **not**
  protect this file.
- ✅ Set the four `OKTA_*` env vars (see below) and let the build phase
  inject them. This is the only supported path; the sentinel values
  always win in a clean repo, and CI verifies that.
- ✅ If you need to add a **new** Info.plist key in the future (e.g.
  `NSAppTransportSecurity` for local dev, `CFBundleURLTypes` for the
  Okta redirect-URI scheme, a new privacy-usage string), edit
  `AcmeBank/Info.plist` directly and commit the change — but only for
  keys whose values are **not secrets**. Since
  `GENERATE_INFOPLIST_FILE` is off, XcodeGen will no longer add these
  keys for you.
- 🔒 Before pushing, run `git diff --cached AcmeBank/Info.plist` and
  confirm any `Okta*` keys still read `__OKTA_NOT_CONFIGURED__`. A
  lightweight pre-commit hook covering this is a TODO for the team
  once the workflow is in routine use.

### Three ways to set the env vars

Pick the one that matches how you launch Xcode / `xcodebuild`:

1. **`launchctl setenv` — Xcode launched from Finder / Dock / Spotlight.**
   GUI-launched Xcode does *not* inherit your shell's environment. Set
   the vars on the user session so any GUI-launched process picks them up:
   ```bash
   launchctl setenv OKTA_ISSUER       "https://acme.okta.com/oauth2/default"
   launchctl setenv OKTA_CLIENT_ID    "0oa1abcDEF23456789"
   launchctl setenv OKTA_REDIRECT_URI "com.acmebank.mobile:/callback"
   launchctl setenv OKTA_SCOPES       "openid profile email offline_access"
   ```
   Then quit and relaunch Xcode (`launchctl setenv` only affects
   processes started *after* it runs).

2. **`~/.zshrc` `export` + `xed .` — Xcode launched from a fresh shell.**
   When Xcode is launched as a child of your shell (e.g. via `xed .` in
   the repo root) it inherits the shell environment. Add to `~/.zshrc`:
   ```bash
   export OKTA_ISSUER="https://acme.okta.com/oauth2/default"
   export OKTA_CLIENT_ID="0oa1abcDEF23456789"
   export OKTA_REDIRECT_URI="com.acmebank.mobile:/callback"
   export OKTA_SCOPES="openid profile email offline_access"
   ```
   Open a fresh terminal, `cd` to the repo, run `xed .`.

3. **Per-command export — scripted `xcodebuild` invocations / CI.**
   `xcodebuild`'s `PhaseScriptExecution` subshells do **not** inherit
   arbitrary job-level shell env vars exported in a parent step — only
   env vars explicitly passed on the `xcodebuild` invocation line
   propagate to Run Script phases. Pass them on the command itself:
   ```bash
   OKTA_ISSUER="$OKTA_ISSUER" \
   OKTA_CLIENT_ID="$OKTA_CLIENT_ID" \
   OKTA_REDIRECT_URI="$OKTA_REDIRECT_URI" \
   OKTA_SCOPES="$OKTA_SCOPES" \
   xcodebuild build -scheme AcmeBank …
   ```
   This is the only reliable pattern in CI.

## Tech Stack

| Item | Value |
|---|---|
| Platform | iOS 17+, Xcode 16+ |
| Language | Swift 5.10 |
| UI | SwiftUI |
| Architecture | MVVM + Coordinator |
| Auth | Okta OIDC via `OktaDirectAuth` (in progress) |
| Networking | URLSession + async/await (deferred) |

See `CLAUDE.md` / `AGENT.md` for the full architecture guide and planned feature roadmap.
