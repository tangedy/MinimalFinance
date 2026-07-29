import SwiftData

enum PreviewSampleData {
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            RecurringExpense.self,
            ImportBatch.self,
            CategoryRule.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let rent = Category(name: "Rent", isBuiltIn: true, sortOrder: 0)
        let tuition = Category(name: "Tuition", isBuiltIn: true, sortOrder: 1)
        let food = Category(name: "Food", isBuiltIn: true, sortOrder: 2)
        let transport = Category(name: "Transport", isBuiltIn: true, sortOrder: 3)
        let subscriptions = Category(name: "Subscriptions", isBuiltIn: true, sortOrder: 4)
        let transfer = Category(name: "Transfer", isBuiltIn: true, sortOrder: 5)
        let clothes = Category(name: "Clothes", isBuiltIn: true, sortOrder: 6)
        let other = Category(name: "Other", isBuiltIn: true, sortOrder: 7)
        context.insert(rent)
        context.insert(tuition)
        context.insert(food)
        context.insert(transport)
        context.insert(subscriptions)
        context.insert(transfer)
        context.insert(clothes)
        context.insert(other)

        context.insert(CategoryRule(ruleType: .builtin, pattern: "TIM HORTONS", category: food, priority: 100))
        context.insert(CategoryRule(ruleType: .builtin, pattern: "SPOTIFY", category: subscriptions, priority: 100))

        context.insert(Transaction(amount: 12.50, merchant: "Coffee shop", category: food))
        context.insert(Transaction(amount: 45.00, merchant: "Grocery", category: food))
        context.insert(Transaction(amount: 3000, merchant: "Paycheck", kind: .income))
        context.insert(RecurringExpense(amount: 1200, cadence: .monthly, category: rent, label: "Rent"))

        return container
    }()
}
