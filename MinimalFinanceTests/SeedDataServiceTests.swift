import SwiftData
import XCTest
@testable import MinimalFinance

final class SeedDataServiceTests: XCTestCase {
    @MainActor
    func testSeedAddsMissingBuiltInsAndRemovesObsoleteBuiltInRules() throws {
        let schema = Schema([
            Transaction.self,
            Category.self,
            RecurringExpense.self,
            ImportBatch.self,
            CategoryRule.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let food = Category(name: "Food", isBuiltIn: true, sortOrder: 0)
        let other = Category(name: "Other", isBuiltIn: true, sortOrder: 1)
        context.insert(food)
        context.insert(other)
        context.insert(CategoryRule(ruleType: .builtin, pattern: "FANDUEL", category: other))
        try context.save()

        SeedDataService.seedIfNeeded(modelContext: context)

        let categories = try context.fetch(FetchDescriptor<Category>())
        let expectedNames = [
            "Rent", "Tuition", "Food", "Transport", "Subscriptions", "Transfer", "Clothes", "Other"
        ]
        XCTAssertEqual(Set(categories.map(\.name)), Set(expectedNames))

        for (index, name) in expectedNames.enumerated() {
            XCTAssertEqual(categories.first(where: { $0.name == name })?.sortOrder, index)
        }

        let rules = try context.fetch(FetchDescriptor<CategoryRule>())
        XCTAssertFalse(rules.contains { $0.ruleType == .builtin && $0.pattern == "FANDUEL" })
    }
}