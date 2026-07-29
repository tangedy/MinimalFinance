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
- `MinimalFinanceTests/` — XCTest coverage for parsing, insights, recurrence, and categorization
- `MLTrainingData/merchant_categories.csv` — non-sensitive merchant classifier corpus
- `Tools/train_categorization_model.swift` — reproducible macOS Create ML trainer
- `masterprompt.md` — product specification

## On-device merchant categorization

Categorization uses this precedence:

1. User-learned and built-in rules
2. Consistent transaction history
3. The bundled Core ML text classifier
4. The reviewable `Other` fallback

The model predicts eight built-in labels: `Rent`, `Tuition`, `Food`, `Transport`,
`Subscriptions`, `Transfer`, `Clothes`, and `Other`. Custom categories still learn through exact
merchant rules and transaction history; changing the fixed model labels requires retraining and
updating the model contract tests.

An unmatched outgoing payment classified as `Transfer` remains an expense, so money sent to a
friend or colleague is represented in spending totals. When `TransferDetector` finds matching
outgoing and incoming legs for a transfer between the user's own accounts, both transactions are
changed to transaction kind `transfer`, their categories are cleared, and they are excluded from
income and expense totals.

The model runs entirely on device through Core ML and Natural Language. Merchant descriptions are
not sent over the network, logged, or used for automatic on-device training.

### Train and export the model

Create ML requires macOS with the full Xcode toolchain:

```bash
xcrun swift Tools/train_categorization_model.swift \
  MLTrainingData/merchant_categories.csv \
  MinimalFinance/Resources/Models/MerchantCategoryClassifier.mlmodel
```

The trainer validates label and merchant-family split isolation, compares the previous keyword
baseline with Create ML, prints accuracy/macro-F1/confusion matrices, tunes the confidence and
runner-up margin gates for at least 90% accepted-prediction precision, evaluates the selected gate
on the untouched test split, and exports the model. Apply the printed values to
`CategorizationEngine.mlMinimumConfidence` and `CategorizationEngine.mlMinimumMargin`, then run:

```bash
xcodegen generate
xcodebuild -scheme MinimalFinance \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Commit the lightweight `.mlmodel` so Xcode compiles it into the app and CI exercises the bundle
contract. Until the model is present, the app remains functional and safely falls back from rules
and history to `Other`.

## Regenerating the Xcode project

When you change `project.yml`, regenerate the project:

```bash
xcodegen generate
```
