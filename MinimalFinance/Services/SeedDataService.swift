import Foundation
import SwiftData

enum SeedDataService {
    private static let builtInCategories = [
        "Rent",
        "Tuition",
        "Food",
        "Transport",
        "Subscriptions",
        "Other"
    ]

    private static let builtInRules: [(pattern: String, category: String)] = [
        ("SPOTIFY", "Subscriptions"),
        ("OBSIDIAN", "Subscriptions"),
        ("APPLE.COM/BILL", "Subscriptions"),
        ("NETFLIX", "Subscriptions"),
        ("DISNEY", "Subscriptions"),
        ("AMAZON PRIME", "Subscriptions"),
        ("TIM HORTONS", "Food"),
        ("STARBUCKS", "Food"),
        ("RESTAURANT", "Food"),
        ("RAMEN", "Food"),
        ("GROCERY", "Food"),
        ("FOOD", "Food"),
        ("EUREST", "Food"),
        ("UBER", "Transport"),
        ("LYFT", "Transport"),
        ("TRANSIT", "Transport"),
        ("PRESTO", "Transport"),
        ("GO TRANSIT", "Transport"),
        ("RENT", "Rent"),
        ("TUITION", "Tuition")
    ]

    static func seedIfNeeded(modelContext: ModelContext) {
        seedCategoriesIfNeeded(modelContext: modelContext)
        seedRulesIfNeeded(modelContext: modelContext)
    }

    private static func seedCategoriesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for (index, name) in builtInCategories.enumerated() {
            let category = Category(name: name, isBuiltIn: true, sortOrder: index)
            modelContext.insert(category)
        }

        try? modelContext.save()
    }

    private static func seedRulesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CategoryRule>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })

        for (pattern, categoryName) in builtInRules {
            guard let category = byName[categoryName] else { continue }
            let rule = CategoryRule(
                ruleType: .builtin,
                pattern: pattern,
                category: category,
                priority: 100
            )
            modelContext.insert(rule)
        }

        try? modelContext.save()
    }
}
