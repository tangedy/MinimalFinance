import Foundation
import SwiftData

@Model
final class ImportBatch {
    var importedAt: Date
    var fileName: String
    var rowCount: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.importBatch)
    var transactions: [Transaction]?

    init(importedAt: Date = .now, fileName: String, rowCount: Int) {
        self.importedAt = importedAt
        self.fileName = fileName
        self.rowCount = rowCount
    }
}
