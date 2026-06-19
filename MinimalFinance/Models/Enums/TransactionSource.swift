import Foundation

enum TransactionSource: String, Codable, CaseIterable {
    case manual
    case csv
    case recurring
}
