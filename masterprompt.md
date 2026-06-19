
## Product overview

**Working name:** Minimal Finance
**Product goal:** Give users a frictionless way to log spending, import bank CSVs, and instantly understand spending trends over time.
**Core insight:** People abandon spreadsheet tracking because it takes too much effort, so the app must feel as effortless as the minimalist task app you like.[^4][^5]

## Problem statement

Users want a simple way to see what they spend, where it goes, and how it changes over time, but current solutions are either too manual or too cluttered. Banking apps often do not make trend visibility intuitive, and spreadsheets create too much friction for daily use. The product should reduce tracking effort to near zero while still producing useful insights.[^6][^7][^8]

## Primary users

- People who track money casually but inconsistently.
- People who want an easy view of monthly spending patterns.
- Students or professionals with large fixed costs like rent and tuition.
- Users who export CSVs from their bank and want the data cleaned up quickly.[^9][^7][^6]


## Product principles

- Minimal UI, low visual noise, mostly text-first.
- Fast entry, ideally one gesture or one tap to add a transaction.
- Insights should appear immediately after logging or importing data.
- Fixed recurring costs should be first-class, not hidden in edge-case settings.
- The app should feel calm, not “finance bro” heavy.


## Core features

### 1. Manual transaction entry

Users can add a transaction in a lightweight form with:

- Amount.
- Merchant or description.
- Category.
- Date.
- Optional note.

This should be the fastest possible path for one-off expenses.

### 2. CSV import

Users can upload a bank CSV and map the columns into the app. SwiftUI supports file importing, and CSV handling can be built around the standard comma-separated text type. The import flow should include a preview and a review step before saving.[^1]

### 3. Categories

Transactions can be categorized manually or during import. Categories should help users answer questions like “where did my money go this month?” and “what changed compared with last month?”

### 4. Recurring expenses

Users can define expected recurring items like:

- Rent.
- Tuition.
- Subscriptions.
- Insurance.
- Transit passes.

Recurring items should support a cadence like weekly, monthly, quarterly, or yearly, and optionally a start/end date. These items should appear in the timeline and summaries so users can separate predictable fixed costs from variable spending.

### 5. Spend over time

The home screen should show a simple trend view such as:

- This week.
- This month.
- Last 6 months.
- Year to date.

Swift Charts is a natural fit for this kind of timeline visualization in SwiftUI.[^10][^11][^3]

## Screen list

### 1. Home

This is the main screen and should feel almost empty at first glance. It shows:

- A large summary of current spend.
- A compact chart of spending over time.
- A short list of recent transactions.
- A single obvious add action.


### 2. Add transaction

A minimal input screen or sheet for quick entry. It should be reachable by a pull-down gesture or a single button, matching the low-friction interaction style you like.

### 3. Import CSV

A file picker screen where users choose a CSV file, preview columns, map fields, and confirm import. SwiftUI’s file importer pattern is a good foundation for this.[^1]

### 4. Recurring expenses

A simple list of fixed expenses with options to add, edit, pause, or delete each one. This screen should help users anticipate upcoming commitments.

### 5. Categories

A category management screen for creating and editing labels. Keep it simple, with built-in defaults and optional custom categories.

### 6. Insights

A lightweight analytics screen showing category breakdowns, monthly comparisons, and recurring vs variable spending. Swift Charts can support these visualizations cleanly.[^11][^10]

### 7. Settings

Basic options like currency, data export, backup, and privacy.

## User stories

### Manual logging

- As a user, I want to add a spending entry in a few seconds so I actually keep up with it.
- As a user, I want to choose a category so I can understand where my money goes.
- As a user, I want to see the entry appear immediately in my timeline.


### CSV import

- As a user, I want to import a CSV from my bank so I can backfill my history.
- As a user, I want the app to detect columns automatically so import is low effort.
- As a user, I want to review imported rows before saving so I can catch mistakes.


### Recurring expenses

- As a user, I want to mark rent as recurring so I can anticipate my monthly baseline.
- As a user, I want tuition to appear as a fixed upcoming expense so I can plan ahead.
- As a user, I want recurring items to appear differently from normal transactions.


### Categories and insights

- As a user, I want to filter by category so I can study one part of my spending.
- As a user, I want to compare this month to last month so I can spot trends.
- As a user, I want to see total variable spending vs fixed spending so I can understand my flexibility.


## Data model

A simple model set could be:

- Transaction.
- Category.
- RecurringExpense.
- ImportBatch.
- InsightSnapshot.

A transaction should store amount, date, merchant, category, source, and note. A recurring expense should store amount, cadence, start date, end date, category, and active state. This is enough to support both basic tracking and forward-looking planning.

## MVP scope

### v1

- Manual transaction entry.
- Category support.
- Recurring expenses.
- CSV import.
- Basic timeline chart.
- Monthly summary.
- Local storage only.


### v2

- Advanced filters.
- Multi-account support.
- Custom rules for imports.
- Notifications for upcoming recurring expenses.
- Export and sync.
- More polished analytics.


### v3

- Cloud sync.
- Collaborative household support.
- Bank connections.
- Forecasting and spending alerts.


## Out of scope for v1

- Full banking integrations.
- Debt tracking.
- Investment tracking.
- Budget envelopes.
- Complex forecasting.
- Shared finances.

Keeping v1 narrow will preserve the minimalist experience and reduce build risk.

## UX direction

The UI should be intentionally plain: white background, generous spacing, small amount of color, and lots of text hierarchy. That “bare text on white” quality is likely part of why MinimaList feels so good — it removes visual friction and puts attention on the action itself. For your app, the design should make the data feel calm and immediate, not decorative.[^5][^12][^4]

## Open questions

- Should recurring expenses auto-generate future entries or just appear as planned items?
- Should categories be editable by the user or mostly fixed?
- Should the app default to local-only privacy-first storage?
- Should CSV import prioritize simplicity or maximum bank format compatibility?


## Success criteria

The app is successful if:

- Users can log an expense in under 5 seconds.
- CSV import feels easy instead of annoying.
- Users can see monthly trends without effort.
- Recurring expenses reduce uncertainty about future spending.
- The app feels simple enough that users want to keep using it.



[^1]: https://github.com/gahntpo/CSVEditor

[^2]: https://developer.apple.com/la/videos/play/wwdc2024/10137/?time=557

[^3]: https://www.youtube.com/watch?v=mnH7YRmuVKw

[^4]: https://apps.apple.com/ca/app/to-do-list-minimalist-task/id993066159

[^5]: https://screensdesign.com/showcase/minimalist-to-do-list-widget

[^6]: https://apps.apple.com/us/app/moneymymoney/id1665422950

[^7]: https://apps.apple.com/mk/app/spendle/id1441881620

[^8]: https://www.reddit.com/r/SaaS/comments/1l1yd78/i_built_a_privacyfocused_budgeting_app_that/

[^9]: https://dev.to/juandes/rowswift-a-simple-csv-analyzer-for-ios-4g4a

[^10]: https://commitstudiogs.medium.com/swiftui-charts-visualize-your-data-beautifully-with-apples-native-api-8015a7f01039

[^11]: https://swiftcrafted.dev/article/swift-charts-complete-guide-data-visualization-swiftui

[^12]: https://apps.apple.com/jo/app/minimalist-to-do-list/id6744609467

[^13]: https://www.kodeco.com/ios/paths/sharing-state-management-swiftui/43760166-data-persistence-in-swiftui/03-persisting-data-with-swiftdata/02

[^14]: https://www.youtube.com/watch?v=zk0gwmfgC4I

[^15]: https://commitstudiogs.medium.com/mastering-swiftdata-apples-new-way-to-persist-your-app-s-data-50aac9265fe2

[^16]: https://www.youtube.com/watch?v=kuzOxNE4eys

