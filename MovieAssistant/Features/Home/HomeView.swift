import SwiftUI

struct HomeView: View {
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared

    /// Порядок жанров, под которые собираются отдельные полки — соответствует
    /// набору жанров из PROJECT_SPEC.md (сценарий "Быстрый подбор").
    private let shelfGenres: [(genre: String, shelfTitle: String)] = [
        ("Боевик", "Боевики"),
        ("Фантастика", "Фантастика"),
        ("Драма", "Драмы"),
        ("Комедия", "Комедии"),
        ("Триллер", "Триллеры"),
        ("Ужасы", "Ужасы")
    ]

    private let canonicalGenres = ["Боевик", "Комедия", "Фантастика", "Триллер", "Ужасы", "Драма"]
    private let categoryTabs = ["Моё кино", "Новинки", "Топ", "Жанры"]

    @State private var selectedCategory = "Моё кино"
    @State private var selectedGenreFilter = "Боевик"

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing),
        GridItem(.flexible(), spacing: AppTheme.Layout.spacing)
    ]

    private var shelves: [(title: String, movies: [Movie])] {
        let all = catalog.allMovies()
        var result: [(title: String, movies: [Movie])] = [("Фильмы для вас", all)]
        for entry in shelfGenres {
            let filtered = all.filter { $0.genres.contains(entry.genre) }
            if !filtered.isEmpty {
                result.append((entry.shelfTitle, filtered))
            }
        }
        return result
    }

    /// "Гнев человеческий" — первым слайдом промо-баннера, дальше топ по рейтингу.
    private var heroMovies: [Movie] {
        let all = catalog.allMovies()
        let featured = all.filter { $0.id == 3 }
        let rest = all.filter { $0.id != 3 }.sorted { $0.rating > $1.rating }.prefix(4)
        return featured + rest
    }

    var body: some View {
        ScrollView {
            categoryContent
                .padding(.top, AppTheme.Layout.spacing)
                .padding(.bottom, AppTheme.Layout.padding)
        }
        // Шапка получает своё место (safeAreaInset), а не накладывается на контент —
        // так и высота посчитана правильно, и нет "дыры" над ней при скролле.
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
                topBar
                categoryTabBar
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
            .background(AppTheme.Colors.background)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie)
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch selectedCategory {
        case "Моё кино":
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 2) {
                HeroCarouselView(movies: heroMovies)
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 2) {
                    ForEach(shelves, id: \.title) { shelf in
                        shelfSection(title: shelf.title, movies: shelf.movies)
                    }
                }
            }
        case "Новинки":
            movieGrid(catalog.allMovies().sorted { $0.year > $1.year })
        case "Топ":
            movieGrid(catalog.allMovies().sorted { $0.rating > $1.rating })
        case "Жанры":
            genresBrowser
        default:
            EmptyView()
        }
    }

    private var genresBrowser: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(canonicalGenres, id: \.self) { genre in
                        genreChip(genre)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.padding)
            }

            movieGrid(catalog.allMovies().filter { $0.genres.contains(selectedGenreFilter) })
        }
    }

    private func genreChip(_ genre: String) -> some View {
        let isSelected = genre == selectedGenreFilter
        return Button {
            selectedGenreFilter = genre
        } label: {
            Text(genre)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(AppTheme.Colors.surface))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func movieGrid(_ movies: [Movie]) -> some View {
        Group {
            if movies.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "film")
                        .font(.system(size: 30))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("Пока ничего нет в этой категории")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: AppTheme.Layout.spacing * 1.5) {
                    ForEach(movies) { movie in
                        NavigationLink(value: movie) {
                            MovieCardView(movie: movie, style: .grid)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.padding)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("КИНОТЕАТР")
                .font(AppTheme.Typography.brandTitle)
                .tracking(-0.5)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Image(systemName: "bell")
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            NavigationLink {
                ProfileView()
            } label: {
                Circle()
                    .fill(AppTheme.Colors.accent.opacity(0.25))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    )
            }
        }
        .padding(.horizontal, AppTheme.Layout.padding)
        .padding(.top, 8)
    }

    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(categoryTabs, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 6) {
                            Text(category)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(
                                    category == selectedCategory
                                        ? AppTheme.Colors.textPrimary
                                        : AppTheme.Colors.textSecondary
                                )
                            Rectangle()
                                .fill(category == selectedCategory ? AppTheme.Colors.accent : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Layout.padding)
        }
    }

    private func shelfSection(title: String, movies: [Movie]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Text("Все")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            .padding(.horizontal, AppTheme.Layout.padding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: AppTheme.Layout.spacing) {
                    ForEach(movies) { movie in
                        NavigationLink(value: movie) {
                            MovieCardView(movie: movie, style: .shelf)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.padding)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
