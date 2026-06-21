import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportCSVView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var onImportComplete: ([RecurrenceSuggestion]) -> Void = { _ in }

    @State private var showFileImporter = false
    @State private var previewRows: [ImportPreviewRow] = []
    @State private var columnHeaders: [String] = []
    @State private var detectedFormat = ""
    @State private var selectedFileName = ""
    @State private var importError: String?
    @State private var isImporting = false
    @State private var editingRowID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                Text("Choose a bank export file to preview and import.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)

                Button("Choose CSV file") {
                    showFileImporter = true
                }
                .buttonStyle(.bordered)

                if !selectedFileName.isEmpty {
                    Text("Selected: \(selectedFileName)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if !detectedFormat.isEmpty {
                    Text("Detected format: \(detectedFormat)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if !columnHeaders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected columns")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(columnHeaders.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if previewRows.isEmpty {
                    Text("No rows loaded yet.")
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview (\(previewRows.count) rows)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(categorizationSummary)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        ForEach(previewRows) { row in
                            ImportPreviewRowView(
                                row: row,
                                currencyCode: currencyCode
                            ) {
                                editingRowID = row.id
                            }
                        }
                    }
                }

                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(AppTheme.contentPadding)
            .padding(.bottom, previewRows.isEmpty ? 0 : 80)
        }
        .background(AppTheme.background)
        .navigationTitle("Import CSV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !previewRows.isEmpty {
                Button {
                    confirmImport()
                } label: {
                    Group {
                        if isImporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Confirm import (\(previewRows.count))")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.vertical, 12)
                .background(AppTheme.background)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: Binding(
            get: { editingRowID != nil },
            set: { if !$0 { editingRowID = nil } }
        )) {
            if let rowID = editingRowID {
                CategoryOverrideSheet(
                    categories: categories,
                    selected: previewRows.first(where: { $0.id == rowID })?.effectiveCategory
                ) { category in
                    applyCategoryOverride(rowID: rowID, category: category)
                    editingRowID = nil
                }
            }
        }
        .onAppear {
            SeedDataService.seedIfNeeded(modelContext: modelContext)
        }
    }

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
    }

    private var categorizationSummary: String {
        let autoCount = previewRows.filter(\.isAutoCategorized).count
        let reviewCount = previewRows.filter(\.needsReview).count
        return "Auto-categorized \(autoCount) of \(previewRows.count) · \(reviewCount) need review"
    }

    private func applyCategoryOverride(rowID: UUID, category: Category?) {
        guard let index = previewRows.firstIndex(where: { $0.id == rowID }) else { return }
        previewRows[index].overrideCategory = category
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        importError = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let contents = try CSVImportService.readContents(from: url)
                let parsed = CSVImportService.parse(contents: contents)
                columnHeaders = parsed.mapping.headers
                detectedFormat = parsed.mapping.formatLabel
                selectedFileName = url.lastPathComponent
                previewRows = CSVImportService.categorize(rows: parsed.rows, modelContext: modelContext)

                if previewRows.isEmpty {
                    importError = "No valid transactions found in this file."
                }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func confirmImport() {
        guard !previewRows.isEmpty, !isImporting else { return }

        isImporting = true
        importError = nil

        do {
            _ = try CSVImportService.importRows(
                previewRows,
                fileName: selectedFileName.isEmpty ? "import.csv" : selectedFileName,
                modelContext: modelContext
            )

            let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
            let recurring = (try? modelContext.fetch(FetchDescriptor<RecurringExpense>())) ?? []
            let suggestions = RecurrenceDetector.detect(
                transactions: transactions,
                existingRecurring: recurring
            )

            isImporting = false
            onImportComplete(suggestions)
            dismiss()
        } catch {
            isImporting = false
            importError = "Import failed: \(error.localizedDescription)"
        }
    }
}

private struct CategoryOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let selected: Category?
    let onSelect: (Category?) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        onSelect(category)
                        dismiss()
                    } label: {
                        HStack {
                            Text(category.name)
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            if selected?.persistentModelID == category.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .plainListRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        ImportCSVView()
    }
    .modelContainer(PreviewSampleData.container)
}
