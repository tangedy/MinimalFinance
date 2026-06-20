import Foundation
import SwiftData

enum CategoryRuleService {
    static func learn(merchant: String, category: Category, modelContext: ModelContext) {
        let pattern = MerchantNormalizer.normalize(merchant)
        guard !pattern.isEmpty else { return }

        let descriptor = FetchDescriptor<CategoryRule>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let userPriority = 200

        if let match = existing.first(where: {
            $0.ruleType == .merchantExact && $0.pattern == pattern
        }) {
            match.category = category
            match.priority = userPriority
        } else {
            let rule = CategoryRule(
                ruleType: .merchantExact,
                pattern: pattern,
                category: category,
                priority: userPriority
            )
            modelContext.insert(rule)
        }

        try? modelContext.save()
    }
}
