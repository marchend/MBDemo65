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

## Tech Stack

| Item | Value |
|---|---|
| Platform | iOS 17+, Xcode 16+ |
| Language | Swift 5.10 |
| UI | SwiftUI |
| Architecture | MVVM + Coordinator |
| Auth | Okta OIDC (deferred) |
| Networking | URLSession + async/await (deferred) |

See `CLAUDE.md` / `AGENT.md` for the full architecture guide and planned feature roadmap.
