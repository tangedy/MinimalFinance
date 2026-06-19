import SwiftUI

struct AppRouter: View {
    @State private var showAddTransaction = false

    var body: some View {
        NavigationStack {
            HomeView(showAddTransaction: $showAddTransaction)
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
