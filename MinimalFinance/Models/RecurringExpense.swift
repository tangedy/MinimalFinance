import Foundation
import SwiftData

@Model
final class RecurringExpense {
    var amount: Decimal
    var cadenceRaw: String
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var label: String

    var category: Category?

    var cadence: RecurrenceCadence {
        get { RecurrenceCadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }

    init(
        amount: Decimal,
        cadence: RecurrenceCadence = .monthly,
        startDate: Date = .now,
        endDate: Date? = nil,
        category: Category? = nil,
        isActive: Bool = true,
        label: String
    ) {
        self.amount = amount
        self.cadenceRaw = cadence.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.isActive = isActive
        self.label = label
    }
}
