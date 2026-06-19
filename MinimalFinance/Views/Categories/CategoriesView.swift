import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var body: some View {
        List {
            ForEach(categories) { category in
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
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {}
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(PreviewSampleData.container)
}
