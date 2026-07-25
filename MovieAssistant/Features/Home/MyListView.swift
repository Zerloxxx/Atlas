import SwiftUI

/// Вкладка "Моё" — список фильмов, сохранённых через "Буду смотреть".
struct MyListView: View {
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared
    @ObservedObject private var watchlist = WatchlistStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing),
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing)
    ]

    private var savedMovies: [Movie] {
        catalog.allMovies().filter { watchlist.isSaved($0.id) }
    }

    var body: some View {
        ScrollView {
            if savedMovies.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: AppTheme.Layout.spacing * 1.5) {
                    ForEach(savedMovies) { movie in
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
            Text("Буду смотреть")
                .font(AppTheme.Typography.largeTitle)
                .tracking(-0.5)
                .foregroundStyle(AppTheme.Colors.textPrimary)
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
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Пока пусто")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Нажимайте «Буду смотреть» на странице фильма — он появится здесь")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}
