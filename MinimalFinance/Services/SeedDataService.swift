import Foundation
import SwiftData

enum SeedDataService {
    private static let builtInCategories = [
        "Rent",
        "Tuition",
        "Food",
        "Transport",
        "Subscriptions",
        "Transfer",
        "Clothes",
        "Other"
    ]

    private static let builtInRules: [(pattern: String, category: String)] = [
        ("SPOTIFY", "Subscriptions"),
        ("OBSIDIAN", "Subscriptions"),
        ("APPLE.COM/BILL", "Subscriptions"),
        ("NETFLIX", "Subscriptions"),
        ("DISNEY", "Subscriptions"),
        ("AMAZON PRIME", "Subscriptions"),
        ("STEAMGAMES", "Subscriptions"),
        ("STEAM", "Subscriptions"),
        ("HBO", "Subscriptions"),
        ("YOUTUBE", "Subscriptions"),
        ("ADOBE", "Subscriptions"),
        ("TIM HORTONS", "Food"),
        ("STARBUCKS", "Food"),
        ("RESTAURANT", "Food"),
        ("RAMEN", "Food"),
        ("GROCERY", "Food"),
        ("FOOD", "Food"),
        ("EUREST", "Food"),
        ("WILD WING", "Food"),
        ("MOOSE", "Food"),
        ("LUCKY MOOSE", "Food"),
        ("AJISEN", "Food"),
        ("WING", "Food"),
        ("PIZZA", "Food"),
        ("CAFE", "Food"),
        ("COFFEE", "Food"),
        ("UBER", "Transport"),
        ("LYFT", "Transport"),
        ("TRANSIT", "Transport"),
        ("PRESTO", "Transport"),
        ("GO TRANSIT", "Transport"),
        ("TTC", "Transport"),
        ("RENT", "Rent"),
        ("TUITION", "Tuition")
    ]

    static func seedIfNeeded(modelContext: ModelContext) {
        seedCategoriesIfNeeded(modelContext: modelContext)
        syncBuiltInRules(modelContext: modelContext)
        assignOtherToUncategorizedExpenses(modelContext: modelContext)
    }

    private static func seedCategoriesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map { $0.name.lowercased() })
        var didChange = false

        for (index, name) in builtInCategories.enumerated() where !existingNames.contains(name.lowercased()) {
            let category = Category(name: name, isBuiltIn: true, sortOrder: index)
            modelContext.insert(category)
            didChange = true
        }

        for category in existing where category.isBuiltIn {
            guard let index = builtInCategories.firstIndex(where: {
                $0.caseInsensitiveCompare(category.name) == .orderedSame
            }), category.sortOrder != index else {
                continue
            }
            category.sortOrder = index
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
    }

    static func syncBuiltInRules(modelContext: ModelContext) {
        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })
        let existing = (try? modelContext.fetch(FetchDescriptor<CategoryRule>())) ?? []
        let canonicalPatterns = Set(builtInRules.map { $0.pattern.uppercased() })
        let existingPatterns = Set(existing.filter { $0.ruleType == .builtin }.map(\.pattern))

        var didChange = false
        for rule in existing where rule.ruleType == .builtin && !canonicalPatterns.contains(rule.pattern) {
            modelContext.delete(rule)
            didChange = true
        }

        for (pattern, categoryName) in builtInRules {
            guard let category = byName[categoryName], !existingPatterns.contains(pattern.uppercased()) else { continue }
            let rule = CategoryRule(
                ruleType: .builtin,
                pattern: pattern,
                category: category,
                priority: 100
            )
            modelContext.insert(rule)
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
    }

    static func otherCategory(modelContext: ModelContext) -> Category? {
        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        return categories.first { $0.name == "Other" }
    }

    static func assignOtherToUncategorizedExpenses(modelContext: ModelContext) {
        guard let other = otherCategory(modelContext: modelContext) else { return }

        let descriptor = FetchDescriptor<Transaction>()
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        var didUpdate = false

        for transaction in transactions where transaction.kind == .expense && transaction.category == nil {
            transaction.category = other
            didUpdate = true
        }

        if didUpdate {
            try? modelContext.save()
        }
    }
}
