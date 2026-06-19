import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query private var transactions: [Transaction]
    @Query(filter: #Predicate<RecurringExpense> { $0.isActive }) private var recurringExpenses: [RecurringExpense]

    private var snapshot: InsightSnapshot {
        InsightEngine.snapshot(transactions: transactions, recurringExpenses: recurringExpenses)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This month vs fixed costs")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Variable")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                            AmountLabel(snapshot.variableTotal, style: .title3)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Recurring")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                            AmountLabel(snapshot.recurringTotal, style: .title3)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Category breakdown")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)

                    if snapshot.categoryBreakdown.isEmpty {
                        Text("No spending data yet.")
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach(snapshot.categoryBreakdown) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                AmountLabel(item.total, style: .body)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Period totals")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    LabeledContent("This week") {
                        AmountLabel(snapshot.weekTotal, style: .body)
                    }
                    LabeledContent("This month") {
                        AmountLabel(snapshot.monthTotal, style: .body)
                    }
                    LabeledContent("Year to date") {
                        AmountLabel(snapshot.yearToDateTotal, style: .body)
                    }
                }
            }
            .padding(AppTheme.contentPadding)
        }
        .background(AppTheme.background)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .modelContainer(PreviewSampleData.container)
}
