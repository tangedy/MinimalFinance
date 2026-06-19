import SwiftUI
import SwiftData

struct RecurringExpensesView: View {
    @Query(sort: \RecurringExpense.label) private var recurringExpenses: [RecurringExpense]

    var body: some View {
        List {
            if recurringExpenses.isEmpty {
                ContentUnavailableView(
                    "No recurring expenses",
                    systemImage: "repeat",
                    description: Text("Add rent, tuition, subscriptions, and other fixed costs.")
                )
            } else {
                ForEach(recurringExpenses) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.label)
                            Text(expense.cadence.label)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        AmountLabel(expense.amount, style: .body)
                    }
                }
            }
        }
        .navigationTitle("Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {}
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecurringExpensesView()
    }
    .modelContainer(PreviewSampleData.container)
}
