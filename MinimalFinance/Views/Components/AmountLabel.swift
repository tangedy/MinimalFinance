import SwiftUI

struct AmountLabel: View {
    let amount: Decimal
    let style: Font

    init(_ amount: Decimal, style: Font = .largeTitle) {
        self.amount = amount
        self.style = style
    }

    var body: some View {
        Text(amount, format: .currency(code: UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"))
            .font(style)
            .fontWeight(.light)
            .foregroundStyle(AppTheme.primaryText)
    }
}
