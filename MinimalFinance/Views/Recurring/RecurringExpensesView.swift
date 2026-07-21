import SwiftUI
import SwiftData

struct RecurringExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringExpense.label) private var recurringExpenses: [RecurringExpense]

    @State private var showAddExpense = false
    @State private var expenseToEdit: RecurringExpense?

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
                    Button {
                        expenseToEdit = expense
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.label)
                                Text(expense.cadence.label)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            if !expense.isActive {
                                Text("Paused")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            AmountLabel(expense.amount, style: .body)
                                .opacity(expense.isActive ? 1 : 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .plainListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteExpense(expense)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            expense.isActive.toggle()
                            try? modelContext.save()
                        } label: {
                            Label(
                                expense.isActive ? "Pause" : "Resume",
                                systemImage: expense.isActive ? "pause.fill" : "play.fill"
                            )
                        }
                        .tint(expense.isActive ? .orange : .green)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, AppTheme.contentPadding, for: .scrollContent)
        .background(AppTheme.background)
        .navigationTitle("Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showAddExpense = true
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            RecurringExpenseFormView()
        }
        .sheet(item: $expenseToEdit) { expense in
            RecurringExpenseFormView(expenseToEdit: expense)
        }
    }

    private func deleteExpense(_ expense: RecurringExpense) {
        modelContext.delete(expense)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        RecurringExpensesView()
    }
    .modelContainer(PreviewSampleData.container)
}
