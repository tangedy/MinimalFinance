import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currencyCode") private var currencyCode = "USD"

    @State private var showClearConfirmation = false
    @State private var csvDocument: CSVDocument?
    @State private var backupDocument: JSONBackupDocument?
    @State private var showCSVExporter = false
    @State private var showBackupExporter = false
    @State private var exportError: String?

    private let currencies = ["USD", "CAD", "EUR", "GBP"]

    var body: some View {
        Form {
            Section("General") {
                Picker("Currency", selection: $currencyCode) {
                    ForEach(currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }

            Section("Data") {
                Button("Export data") {
                    csvDocument = CSVDocument(text: DataExportService.transactionsCSV(modelContext: modelContext))
                    showCSVExporter = true
                }
                Button("Backup") {
                    backupDocument = JSONBackupDocument(data: DataExportService.fullBackupJSON(modelContext: modelContext))
                    showBackupExporter = true
                }
                Button("Clear all data", role: .destructive) {
                    showClearConfirmation = true
                }
            }

            Section("Privacy") {
                Text("All data is stored locally on this device.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Clear all data?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear everything", role: .destructive) {
                DataResetService.clearAllData(modelContext: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes all transactions, rules, and recurring expenses. Built-in categories are restored.")
        }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "MinimalFinance-Transactions"
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "MinimalFinance-Backup"
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .onAppear {
            SeedDataService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewSampleData.container)
}
