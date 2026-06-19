import SwiftData

enum PreviewSampleData {
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            RecurringExpense.self,
            ImportBatch.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let food = Category(name: "Food", isBuiltIn: true, sortOrder: 0)
        let rent = Category(name: "Rent", isBuiltIn: true, sortOrder: 1)
        context.insert(food)
        context.insert(rent)

        context.insert(Transaction(amount: 12.50, merchant: "Coffee shop", category: food))
        context.insert(Transaction(amount: 45.00, merchant: "Grocery", category: food))
        context.insert(RecurringExpense(amount: 1200, cadence: .monthly, category: rent, label: "Rent"))

        return container
    }()
}
