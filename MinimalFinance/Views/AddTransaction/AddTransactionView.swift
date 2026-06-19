import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var selectedCategory: Category?
    @State private var date = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Merchant or description", text: $merchant)
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(Optional<Category>.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
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
