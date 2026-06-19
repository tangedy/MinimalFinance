import SwiftUI

struct SettingsView: View {
    @AppStorage("currencyCode") private var currencyCode = "USD"

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
                Button("Export data") {}
                Button("Backup") {}
            }

            Section("Privacy") {
                Text("All data is stored locally on this device.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
