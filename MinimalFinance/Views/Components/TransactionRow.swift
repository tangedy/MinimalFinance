import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    private var signedAmount: Decimal {
        switch transaction.kind {
        case .expense:
            return -transaction.amount
        case .income:
            return transaction.amount
        case .transfer:
            return transaction.amount
        }
    }

    private var subtitle: String? {
        switch transaction.kind {
        case .income:
            return "Income"
        case .transfer:
            return "Transfer"
        case .expense:
            return transaction.category?.name ?? "Other"
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .income:
            return AppTheme.incomeColor
        case .transfer:
            return AppTheme.secondaryText
        case .expense:
            return AppTheme.primaryText
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.body)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(signedAmount, format: .currency(code: UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"))
                    .font(.body)
                    .fontWeight(.light)
                    .foregroundStyle(amountColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
