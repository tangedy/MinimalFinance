import SwiftUI
import SwiftData

struct ImportPreviewRowView: View {
    let row: ImportPreviewRow
    let currencyCode: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.merchant)
                        .font(.body)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(row.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)

                    if row.kind == .expense {
                        categoryCaption
                    } else {
                        Text("Income")
                            .font(.caption)
                            .foregroundStyle(AppTheme.incomeColor)
                    }
                }

                Spacer(minLength: 12)

                Text(displayAmount, format: .currency(code: currencyCode))
                    .font(.body)
                    .foregroundStyle(row.kind == .income ? AppTheme.incomeColor : AppTheme.primaryText)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(row.kind != .expense)
    }

    @ViewBuilder
    private var categoryCaption: some View {
        if let category = row.effectiveCategory {
            HStack(spacing: 4) {
                Text("Suggested: \(category.name)")
                    .font(.caption)
                    .foregroundStyle(row.needsReview ? .orange : AppTheme.secondaryText)
                if row.overrideCategory != nil {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        } else {
            Text("Needs category")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var displayAmount: Decimal {
        row.kind == .expense ? -row.amount : row.amount
    }
}
