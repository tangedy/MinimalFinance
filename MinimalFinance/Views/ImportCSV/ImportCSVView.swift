import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportCSVView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFileImporter = false
    @State private var parsedRows: [ParsedCSVRow] = []
    @State private var columnHeaders: [String] = []
    @State private var selectedFileName = ""
    @State private var importError: String?
    @State private var isImporting = false

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

                if parsedRows.isEmpty {
                    Text("No rows loaded yet.")
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview (\(parsedRows.count) rows)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)

                        ForEach(parsedRows) { row in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.merchant)
                                        .font(.body)
                                    Text(row.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer(minLength: 12)
                                Text(displayAmount(for: row), format: .currency(code: currencyCode))
                                    .font(.body)
                                    .foregroundStyle(row.kind == .income ? AppTheme.incomeColor : AppTheme.primaryText)
                            }
                            .padding(.vertical, 6)
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
            .padding(.bottom, parsedRows.isEmpty ? 0 : 80)
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
            if !parsedRows.isEmpty {
                Button {
                    confirmImport()
                } label: {
                    Group {
                        if isImporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Confirm import (\(parsedRows.count))")
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
    }

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
    }

    private func displayAmount(for row: ParsedCSVRow) -> Decimal {
        row.kind == .expense ? -row.amount : row.amount
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
                parsedRows = parsed.rows
                selectedFileName = url.lastPathComponent

                if parsed.rows.isEmpty {
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
        guard !parsedRows.isEmpty, !isImporting else { return }

        isImporting = true
        importError = nil

        do {
            _ = try CSVImportService.importRows(
                parsedRows,
                fileName: selectedFileName.isEmpty ? "import.csv" : selectedFileName,
                modelContext: modelContext
            )
            isImporting = false
            dismiss()
        } catch {
            isImporting = false
            importError = "Import failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        ImportCSVView()
    }
    .modelContainer(PreviewSampleData.container)
}
