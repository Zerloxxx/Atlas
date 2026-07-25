import SwiftUI

/// Вкладка "Поиск" — поиск по каталогу (название, жанр, актёр).
struct SearchView: View {
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared
    @State private var searchQuery = ""

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing),
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing)
    ]

    private var results: [Movie] {
        catalog.allMovies().filter { $0.matches(query: searchQuery) }
    }

    var body: some View {
        ScrollView {
            if results.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: AppTheme.Layout.spacing * 1.5) {
                    ForEach(results) { movie in
                        NavigationLink(value: movie) {
                            MovieCardView(movie: movie, style: .grid)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Layout.padding)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing) {
                Text("Поиск")
                    .font(AppTheme.Typography.largeTitle)
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                SearchBarView(text: $searchQuery, placeholder: "Название, жанр, актёр")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Layout.padding)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(AppTheme.Colors.background)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Ничего не нашлось")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
