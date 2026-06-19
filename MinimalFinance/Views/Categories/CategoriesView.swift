import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showAddCategory = false
    @State private var categoryToEdit: Category?

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    guard !category.isBuiltIn else { return }
                    categoryToEdit = category
                } label: {
                    HStack {
                        Text(category.name)
                        Spacer()
                        if category.isBuiltIn {
                            Text("Built-in")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)
                .plainListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !category.isBuiltIn {
                        Button(role: .destructive) {
                            deleteCategory(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, AppTheme.contentPadding, for: .scrollContent)
        .background(AppTheme.background)
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showAddCategory = true
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            CategoryFormView()
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryFormView(categoryToEdit: category)
        }
    }

    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(PreviewSampleData.container)
}
