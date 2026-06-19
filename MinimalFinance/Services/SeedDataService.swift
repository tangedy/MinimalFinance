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

    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for (index, name) in builtInCategories.enumerated() {
            let category = Category(name: name, isBuiltIn: true, sortOrder: index)
            modelContext.insert(category)
        }

        try? modelContext.save()
    }
}
