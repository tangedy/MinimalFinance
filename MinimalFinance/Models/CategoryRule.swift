import Foundation
import SwiftData

@Model
final class CategoryRule {
    var ruleTypeRaw: String
    var pattern: String
    var priority: Int
    var createdAt: Date

    var category: Category?

    var ruleType: CategoryRuleType {
        get { CategoryRuleType(rawValue: ruleTypeRaw) ?? .keyword }
        set { ruleTypeRaw = newValue.rawValue }
    }

    init(
        ruleType: CategoryRuleType,
        pattern: String,
        category: Category?,
        priority: Int = 100,
        createdAt: Date = .now
    ) {
        self.ruleTypeRaw = ruleType.rawValue
        self.pattern = pattern.uppercased()
        self.priority = priority
        self.createdAt = createdAt
        self.category = category
    }
}
