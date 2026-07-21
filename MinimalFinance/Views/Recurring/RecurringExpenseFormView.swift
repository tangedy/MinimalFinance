import SwiftUI
import SwiftData

struct RecurringExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    private let expenseToEdit: RecurringExpense?

    @FocusState private var focusedField: Field?

    @State private var label = ""
    @State private var amountText = ""
    @State private var cadence: RecurrenceCadence = .monthly
    @State private var selectedCategory: Category?
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now
    @State private var isActive = true

    private enum Field: Hashable {
        case label
        case amount
    }

    init(expenseToEdit: RecurringExpense? = nil) {
        self.expenseToEdit = expenseToEdit
    }

    private var isEditing: Bool {
        expenseToEdit != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $label)
                        .focused($focusedField, equals: .label)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: amountText) { _, newValue in
                            let filtered = Self.filterAmountInput(newValue)
                            if filtered != newValue {
                                amountText = filtered
                            }
                        }
                    Picker("Cadence", selection: $cadence) {
                        ForEach(RecurrenceCadence.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(Optional<Category>.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                }

                Section {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, displayedComponents: .date)
                    }
                }

                if isEditing {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit recurring" : "Add recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExistingExpense)
        }
    }

    private func loadExistingExpense() {
        guard let expenseToEdit else {
            focusedField = .label
            return
        }
        label = expenseToEdit.label
        amountText = NSDecimalNumber(decimal: expenseToEdit.amount).stringValue
        cadence = expenseToEdit.cadence
        selectedCategory = expenseToEdit.category
        startDate = expenseToEdit.startDate
        if let existingEndDate = expenseToEdit.endDate {
            hasEndDate = true
            endDate = existingEndDate
        }
        isActive = expenseToEdit.isActive
    }

    private static func filterAmountInput(_ value: String) -> String {
        var result = ""
        var hasDecimalSeparator = false

        for character in value {
            if character.isNumber {
                result.append(character)
            } else if (character == "." || character == ",") && !hasDecimalSeparator {
                hasDecimalSeparator = true
                result.append(".")
            }
        }

        return result
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) != nil
    }

    private func save() {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) else { return }
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let resolvedEndDate = hasEndDate ? endDate : nil

        if let expenseToEdit {
            expenseToEdit.label = trimmedLabel
            expenseToEdit.amount = amount
            expenseToEdit.cadence = cadence
            expenseToEdit.category = selectedCategory
            expenseToEdit.startDate = startDate
            expenseToEdit.endDate = resolvedEndDate
            expenseToEdit.isActive = isActive
        } else {
            let expense = RecurringExpense(
                amount: amount,
                cadence: cadence,
                startDate: startDate,
                endDate: resolvedEndDate,
                category: selectedCategory,
                isActive: true,
                label: trimmedLabel
            )
            modelContext.insert(expense)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    RecurringExpenseFormView()
        .modelContainer(PreviewSampleData.container)
}
