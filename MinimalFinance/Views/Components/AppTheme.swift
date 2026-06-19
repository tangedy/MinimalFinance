import SwiftUI

enum AppTheme {
    static let background = Color.white
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let contentPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 32
    static let pullRevealHeight: CGFloat = contentPadding + 20

    static let incomeColor = Color(red: 0.5216, green: 0.7373, blue: 0.5098)
    static let expenseColor = Color(red: 1, green: 0.698, blue: 0.702)
}

enum ChartColors {
    static func forSnapshotBar(id: String, value: Decimal) -> Color {
        switch id {
        case "income":
            return AppTheme.incomeColor
        case "fixed", "variable":
            return AppTheme.expenseColor
        case "savings":
            return value >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor
        default:
            return AppTheme.secondaryText
        }
    }

    static func forMetric(_ metric: String) -> Color {
        switch metric {
        case "Income", "Savings", "Leftover":
            return AppTheme.incomeColor
        case "Expenses":
            return AppTheme.expenseColor
        default:
            return AppTheme.secondaryText
        }
    }
}
