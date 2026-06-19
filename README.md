# MinimalFinance

A minimal personal finance app for tracking spending, importing bank CSVs, and understanding spending trends over time.

## Requirements

- macOS with Xcode 16 or later
- iOS 17+ simulator or device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (one-time install)

## Setup

```bash
brew install xcodegen
xcodegen generate
open MinimalFinance.xcodeproj
```

After opening the project in Xcode, select your development team under **Signing & Capabilities** for the `MinimalFinance` target.

## Build from the command line

```bash
xcodegen generate

# If xcode-select points to Command Line Tools, set DEVELOPER_DIR:
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# With an iOS Simulator runtime installed:
xcodebuild -scheme MinimalFinance -destination 'platform=iOS Simulator,name=iPhone 16' build

# Without a simulator runtime (compile-only):
xcodebuild -project MinimalFinance.xcodeproj -target MinimalFinance \
  -sdk iphonesimulator -arch arm64 CODE_SIGNING_ALLOWED=NO build
```

## Project structure

- `project.yml` — XcodeGen project specification (edit this, then regenerate)
- `MinimalFinance/` — Swift source, resources, and assets
- `masterprompt.md` — product specification

## Regenerating the Xcode project

When you change `project.yml`, regenerate the project:

```bash
xcodegen generate
```
