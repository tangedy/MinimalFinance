import Foundation

enum CategoryRuleType: String, Codable, CaseIterable {
    case merchantExact
    case keyword
    case builtin
}
