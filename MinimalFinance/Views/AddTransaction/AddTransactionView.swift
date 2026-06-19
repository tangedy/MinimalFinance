import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @FocusState private var focusedField: Field?

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var selectedCategory: Category?
    @State private var date = Date.now
    @State private var note = ""

    private enum Field: Hashable {
        case amount
        case merchant
        case note
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    formTextField("Amount", text: $amountText, field: .amount, keyboardType: .decimalPad)
                        .onChange(of: amountText) { _, newValue in
                            let filtered = Self.filterAmountInput(newValue)
                            if filtered != newValue {
                                amountText = filtered
                            }
                        }
                    formTextField("Merchant or description", text: $merchant, field: .merchant)
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(Optional<Category>.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    formTextField("Note (optional)", text: $note, field: .note)
                }
            }
            .navigationTitle("Add transaction")
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
        }
    }

    private func formTextField(
        _ placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .focused($focusedField, equals: field)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    focusedField = field
                }
            )
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
        !merchant.trimmingCharacters(in: .whitespaces).isEmpty
            && Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) != nil
    }

    private func save() {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) else { return }

        let transaction = Transaction(
            amount: amount,
            date: date,
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            source: .manual,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(PreviewSampleData.container)
}
