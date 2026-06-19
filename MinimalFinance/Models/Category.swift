import Foundation
import SwiftData

@Model
final class Category {
    var name: String
    var isBuiltIn: Bool
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
    var recurringExpenses: [RecurringExpense]?

    init(name: String, isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}
