import SwiftUI

struct AppRouter: View {
    @State private var showAddTransaction = false
    @State private var showImportCSV = false

    var body: some View {
        NavigationStack {
            HomeView(showAddTransaction: $showAddTransaction, showImportCSV: $showImportCSV)
                .sheet(isPresented: $showAddTransaction) {
                    AddTransactionView()
                }
        }
    }
}

#Preview {
    AppRouter()
        .modelContainer(PreviewSampleData.container)
}
