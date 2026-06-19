import Foundation

enum RecurrenceCadence: String, Codable, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var label: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }
}
