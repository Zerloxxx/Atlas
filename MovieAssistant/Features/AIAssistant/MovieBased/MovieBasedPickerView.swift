import SwiftUI

struct MovieBasedPickerView: View {
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared
    @State private var searchQuery = ""

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing),
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing)
    ]

    private var filteredMovies: [Movie] {
        catalog.allMovies().filter { $0.matches(query: searchQuery) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
                Text("Какой фильм вам понравился?")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.top, 8)

                SearchBarView(text: $searchQuery, placeholder: "Название, жанр, актёр")

                if filteredMovies.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: AppTheme.Layout.spacing * 1.5) {
                        ForEach(filteredMovies) { movie in
                            NavigationLink {
                                MovieBasedSurveyView(referenceMovie: movie)
                            } label: {
                                MovieCardView(movie: movie, style: .grid)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppTheme.Layout.padding)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Подбор по фильму")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Ничего не нашлось")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
