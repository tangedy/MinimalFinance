import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<RecurringExpense> { $0.isActive }) private var recurringExpenses: [RecurringExpense]

    @Binding var showAddTransaction: Bool
    @State private var pullOffset: CGFloat = 0
    @State private var pullHandler = PullDownAddGestureHandler()

    private let pullThreshold: CGFloat = 72
    private let scrollCoordinateSpace = "homeScroll"

    private var snapshot: InsightSnapshot {
        InsightEngine.snapshot(transactions: transactions, recurringExpenses: recurringExpenses)
    }

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                let minY = geo.frame(in: .named(scrollCoordinateSpace)).minY
                Color.clear
                    .onChange(of: minY) { _, newValue in
                        pullHandler.process(
                            rawOffset: newValue,
                            threshold: pullThreshold,
                            isEnabled: !showAddTransaction,
                            pullOffset: &pullOffset
                        )
                    }
            }
            .frame(height: 0)

            PullDownAddReveal(pullOffset: pullOffset, threshold: pullThreshold)

            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This month")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    AmountLabel(snapshot.monthTotal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Spending over time")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)

                    ChartPlaceholder()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)

                    if transactions.isEmpty {
                        Text("No transactions yet. Pull down to add one.")
                            .font(.body)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(transactions.prefix(5)) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.contentPadding)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .coordinateSpace(name: scrollCoordinateSpace)
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onEnded { _ in
                    guard !showAddTransaction else { return }
                    if pullHandler.consumeTrigger(threshold: pullThreshold) {
                        pullOffset = 0
                        showAddTransaction = true
                    }
                }
        )
        .background(AppTheme.background)
        .onAppear {
            SeedDataService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

private struct ChartPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            .frame(height: 160)
            .overlay {
                Text("Chart")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
    }
}

#Preview {
    HomeView(showAddTransaction: .constant(false))
        .modelContainer(PreviewSampleData.container)
}
