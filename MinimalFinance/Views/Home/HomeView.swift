import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<RecurringExpense> { $0.isActive }) private var recurringExpenses: [RecurringExpense]

    @Binding var showAddTransaction: Bool
    @Binding var showImportCSV: Bool
    @State private var transactionToEdit: Transaction?
    @State private var pullOffset: CGFloat = 0
    @State private var pullHandler = PullDownAddGestureHandler()
    @State private var recurrenceSuggestions: [RecurrenceSuggestion] = []
    @State private var showRecurrenceSuggestions = false
    @State private var selectedMonth: Date = .now

    private let pullThreshold = AppTheme.pullRevealHeight
    private let scrollCoordinateSpace = "homeScroll"

    private static let monthMenuFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private var pullOvershoot: CGFloat {
        max(0, pullOffset - pullThreshold)
    }

    private var snapshot: InsightSnapshot {
        InsightEngine.snapshot(transactions: transactions, recurringExpenses: recurringExpenses, now: selectedMonth)
    }

    private var monthLabelTitle: String {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
            ? "Net this month"
            : "Net in \(Self.monthMenuFormatter.string(from: selectedMonth))"
    }

    private var availableMonths: [Date] {
        let calendar = Calendar.current
        var months = Set(transactions.map { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date })
        months.insert(calendar.dateInterval(of: .month, for: .now)?.start ?? .now)
        return months.sorted(by: >)
    }

    private func monthMenuLabel(_ month: Date) -> String {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
            ? "This month"
            : Self.monthMenuFormatter.string(from: month)
    }

    private var noTransactionsMessage: String {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
            ? "No transactions this month."
            : "No transactions in \(Self.monthMenuFormatter.string(from: selectedMonth))."
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
                            isEnabled: !showAddTransaction && !showImportCSV && transactionToEdit == nil,
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
                            Picker(selection: $selectedMonth) {
                                ForEach(availableMonths, id: \.self) { month in
                                    Text(monthMenuLabel(month)).tag(month)
                                }
                            } label: {
                                Text(monthLabelTitle)
                            }
                            .pickerStyle(.menu)
                            .font(.subheadline)
                            .tint(AppTheme.secondaryText)
                            AmountLabel(snapshot.monthNet)
                        }

                        Spacer()

                        Menu {
                            Button("Add transaction") {
                                showAddTransaction = true
                            }
                            Button("Import CSV") {
                                showImportCSV = true
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

                    HomeChartCarousel(
                        monthlyShape: monthlyShape,
                        comparisonSlices: comparisonSlices,
                        categoryItems: categoryItems,
                        balancePoints: balancePoints
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transactions")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)

                        if currentMonthTransactions.isEmpty {
                            Text(noTransactionsMessage)
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
        .sheet(isPresented: $showImportCSV) {
            NavigationStack {
                ImportCSVView { suggestions in
                    recurrenceSuggestions = suggestions
                    showRecurrenceSuggestions = !suggestions.isEmpty
                }
            }
        }
        .sheet(isPresented: $showRecurrenceSuggestions) {
            RecurrenceSuggestionSheet(suggestions: recurrenceSuggestions)
        }
        .onAppear {
            SeedDataService.seedIfNeeded(modelContext: modelContext)
        }
    }

    private var monthlyShape: MonthlyFinancialShape {
        InsightEngine.monthlyFinancialShape(
            transactions: transactions,
            recurringExpenses: recurringExpenses,
            for: selectedMonth
        )
    }

    private var comparisonSlices: [MonthComparisonSlice] {
        InsightEngine.monthComparison(
            transactions: transactions,
            recurringExpenses: recurringExpenses,
            now: selectedMonth
        )
    }

    private var categoryItems: [CategoryChartItem] {
        guard let monthStart = Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start else {
            return []
        }
        return InsightEngine.categoryBreakdown(transactions: transactions, monthStart: monthStart)
    }

    private var balancePoints: [BalanceTrendPoint] {
        InsightEngine.balanceTrend(transactions: transactions, now: selectedMonth)
    }

    private var currentMonthTransactions: [Transaction] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: selectedMonth) else {
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

#Preview {
    HomeView(showAddTransaction: .constant(false), showImportCSV: .constant(false))
        .modelContainer(PreviewSampleData.container)
}
