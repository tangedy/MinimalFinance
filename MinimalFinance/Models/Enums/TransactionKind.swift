import Foundation

enum TransactionKind: String, Codable, CaseIterable {
    case expense
    case income
    case transfer

    var label: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }
}
