import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

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
                AmountLabel(transaction.amount, style: .body)
                if let category = transaction.category?.name {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
