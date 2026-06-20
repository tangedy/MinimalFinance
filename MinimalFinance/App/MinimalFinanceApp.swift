import SwiftUI
import SwiftData

@main
struct MinimalFinanceApp: App {
    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
        .modelContainer(for: [Transaction.self, Category.self, RecurringExpense.self, ImportBatch.self, CategoryRule.self])
    }
}
