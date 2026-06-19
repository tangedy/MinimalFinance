import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<RecurringExpense> { $0.isActive }) private var recurringExpenses: [RecurringExpense]

    @Binding var showAddTransaction: Bool
    @State private var transactionToEdit: Transaction?
    @State private var pullOffset: CGFloat = 0
    @State private var pullHandler = PullDownAddGestureHandler()

    private let pullThreshold = AppTheme.pullRevealHeight
    private let scrollCoordinateSpace = "homeScroll"

    private var pullOvershoot: CGFloat {
        max(0, pullOffset - pullThreshold)
    }

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
                            isEnabled: !showAddTransaction && transactionToEdit == nil,
                            pullOffset: &pullOffset
                        )
                    }
            }
            .frame(height: 0)

            VStack(spacing: 0) {
                PullDownAddReveal(pullOffset: pullOffset, threshold: pullThreshold)

                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This month")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            AmountLabel(snapshot.monthTotal)
                        }

                        Spacer()

                        Menu {
                            Button("Add transaction") {
                                showAddTransaction = true
                            }
                            NavigationLink("Import CSV") {
                                ImportCSVView()
                            }
                            NavigationLink("Recurring") {
                                RecurringExpensesView()
                            }
                            NavigationLink("Categories") {
                                CategoriesView()
                            }
                            NavigationLink("Insights") {
                                InsightsView()
                            }
                            NavigationLink("Settings") {
                                SettingsView()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.title3)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: 36, height: 36)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending over time")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)

                        ChartPlaceholder()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transactions")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)

                        if currentMonthTransactions.isEmpty {
                            Text("No transactions this month.")
                                .font(.body)
                                .foregroundStyle(AppTheme.secondaryText)
                        } else {
                            List {
                                ForEach(currentMonthTransactions) { transaction in
                                    Button {
                                        transactionToEdit = transaction
                                    } label: {
                                        TransactionRow(transaction: transaction)
                                    }
                                    .buttonStyle(.plain)
                                    .plainListRow()
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteTransaction(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(true)
                            .background(AppTheme.background)
                            .frame(height: currentMonthTransactionsListHeight)
                        }
                    }
                }
                .padding(AppTheme.contentPadding)
            }
            .offset(y: -pullOvershoot)
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
        .sheet(item: $transactionToEdit) { transaction in
            AddTransactionView(transactionToEdit: transaction)
        }
        .onAppear {
            SeedDataService.seedIfNeeded(modelContext: modelContext)
        }
    }

    private var currentMonthTransactions: [Transaction] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: .now) else {
            return transactions
        }
        return transactions.filter { monthInterval.contains($0.date) }
    }

    private var currentMonthTransactionsListHeight: CGFloat {
        CGFloat(currentMonthTransactions.count) * 56
    }

    private func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
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
