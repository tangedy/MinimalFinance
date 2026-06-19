import SwiftUI

struct AppRouter: View {
    @State private var showAddTransaction = false

    var body: some View {
        NavigationStack {
            HomeView(showAddTransaction: $showAddTransaction)
                .navigationTitle("Minimal Finance")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Add transaction") {
                                showAddTransaction = true
                            }
                            NavigationLink("Import CSV") {
                                ImportCSVView()
                            }
                            NavigationLink("Recurring") {
                                RecurringExpensesView()
                            }
                            NavigationLink("Categories") {
                                CategoriesView()
                            }
                            NavigationLink("Insights") {
                                InsightsView()
                            }
                            NavigationLink("Settings") {
                                SettingsView()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
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
