import Foundation
import SwiftData

@Model
final class Transaction {
    var amount: Decimal
    var date: Date
    var merchant: String
    var sourceRaw: String
    var note: String?

    var category: Category?
    var importBatch: ImportBatch?

    var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        amount: Decimal,
        date: Date = .now,
        merchant: String,
        category: Category? = nil,
        source: TransactionSource = .manual,
        note: String? = nil,
        importBatch: ImportBatch? = nil
    ) {
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.sourceRaw = source.rawValue
        self.note = note
        self.category = category
        self.importBatch = importBatch
    }
}
