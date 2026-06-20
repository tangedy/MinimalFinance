import SwiftUI
import SwiftData

struct RecurrenceSuggestionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let suggestions: [RecurrenceSuggestion]
    @State private var selectedIDs: Set<UUID>

    init(suggestions: [RecurrenceSuggestion]) {
        self.suggestions = suggestions
        _selectedIDs = State(initialValue: Set(suggestions.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("We noticed possible recurring charges. Select the ones you want to track.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .plainListRow()
                }

                Section("Suggestions") {
                    ForEach(suggestions) { suggestion in
                        Button {
                            toggleSelection(suggestion.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.label)
                                        .font(.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text("\(suggestion.cadence.displayName) · \(suggestion.category?.name ?? "Uncategorized")")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(suggestion.amount, format: .currency(code: currencyCode))
                                        .font(.body)
                                    Image(systemName: selectedIDs.contains(suggestion.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(suggestion.id) ? Color.accentColor : AppTheme.secondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .plainListRow()
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Recurring charges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add selected") { confirmSelected() }
                        .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func confirmSelected() {
        for suggestion in suggestions where selectedIDs.contains(suggestion.id) {
            let recurring = RecurringExpense(
                amount: suggestion.amount,
                cadence: suggestion.cadence,
                category: suggestion.category,
                label: suggestion.label
            )
            modelContext.insert(recurring)
        }
        try? modelContext.save()
        dismiss()
    }
}

private extension RecurrenceCadence {
    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }
}
