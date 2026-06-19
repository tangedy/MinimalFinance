import SwiftUI
import UniformTypeIdentifiers

struct ImportCSVView: View {
    @State private var showFileImporter = false
    @State private var parsedRows: [ParsedCSVRow] = []
    @State private var columnHeaders: [String] = []
    @State private var selectedFileName = ""
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Import CSV")
                    .font(.title2)
                    .fontWeight(.regular)
                Text("Choose a bank export file to preview and map columns before importing.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
            }

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

                    ForEach(parsedRows.prefix(10)) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.description.isEmpty ? "—" : row.description)
                                .font(.body)
                            HStack {
                                Text(row.date)
                                Spacer()
                                Text(row.amount)
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }

                    if parsedRows.count > 10 {
                        Text("+\(parsedRows.count - 10) more rows")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Button("Confirm import") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                }
            }

            if let importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(AppTheme.contentPadding)
        .background(AppTheme.background)
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
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
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ImportCSVView()
    }
}
