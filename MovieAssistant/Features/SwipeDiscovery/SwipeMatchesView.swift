import SwiftUI
import UIKit

/// Вкладка "Мэтчи" — выбор категории для свайпа и лайкнутые фильмы,
/// сгруппированные по жанру (в духе полок на главном экране).
struct SwipeMatchesView: View {
    @ObservedObject private var store = SwipeMatchesStore.shared
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared

    /// Тот же набор жанров и подписи полок, что и на главном — для единого стиля.
    private let shelfGenres: [(genre: String, shelfTitle: String)] = [
        ("Боевик", "Боевики"),
        ("Фантастика", "Фантастика"),
        ("Драма", "Драмы"),
        ("Комедия", "Комедии"),
        ("Триллер", "Триллеры"),
        ("Ужасы", "Ужасы")
    ]

    /// Режим "выбрать несколько" для рандомайзера — включается кнопкой в шапке,
    /// тап по лайкнутому фильму тогда не открывает деталь, а отмечает выбор.
    @State private var isSelecting = false
    @State private var selectedForRandom: Set<Int> = []
    /// Показ рандомайзера завязан на этот optional (а не на отдельный Bool-флаг):
    /// .fullScreenCover(item:) строит экран прямо из значения, без гонки между
    /// "выставили данные" и "выставили флаг показа" — с isPresented+отдельным
    /// state кандидаты иногда приходили пустыми на первый кадр.
    @State private var randomPickerRequest: RandomPickerRequest?
    /// Фильм, выбранный рулеткой — по "Готово" рулетка закрывается и сразу
    /// открывается его детальная страница.
    @State private var pendingRandomWinner: Movie?

    private var isShowingRandomWinner: Binding<Bool> {
        Binding(
            get: { pendingRandomWinner != nil },
            set: { if !$0 { pendingRandomWinner = nil } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 2) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Смахни фильм")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, AppTheme.Layout.padding)

                    categoryPicker
                }

                if isSelecting && !likedShelves.isEmpty {
                    selectionHint
                }

                if likedShelves.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 2) {
                        ForEach(likedShelves, id: \.title) { shelf in
                            shelfSection(title: shelf.title, movies: shelf.movies)
                        }
                    }
                }
            }
            .padding(.top, AppTheme.Layout.spacing)
            // Внизу оставляем место под плавающую кнопку рандомайзера, чтобы
            // последняя полка не пряталась под ней.
            .padding(.bottom, isSelecting && selectedForRandom.count >= 2 ? 84 : AppTheme.Layout.padding)
        }
        // Как и на остальных вкладках: заголовок в safeAreaInset, а не системный
        // navigationTitle — иначе он сворачивается/уезжает при скролле.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, AppTheme.Layout.padding)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(AppTheme.Colors.background)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if isSelecting && selectedForRandom.count >= 2 {
                randomButton
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedForRandom.count)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie)
        }
        .navigationDestination(isPresented: isShowingRandomWinner) {
            if let pendingRandomWinner {
                MovieDetailView(movie: pendingRandomWinner)
            }
        }
        .fullScreenCover(item: $randomPickerRequest) { request in
            RandomPickerView(candidates: request.candidates, scores: request.scores) { movie in
                randomPickerRequest = nil
                pendingRandomWinner = movie
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Мэтчи")
                .font(AppTheme.Typography.largeTitle)
                .tracking(-0.5)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                headerIconButton(systemImage: "clock.arrow.circlepath") {
                    SwipeSessionHistoryView()
                }
                headerIconButton(systemImage: "trash") {
                    SwipeDislikesView()
                }
                Button {
                    isSelecting.toggle()
                    if !isSelecting { selectedForRandom.removeAll() }
                } label: {
                    // Раньше это была голая иконка-галочка без подписи — непонятно,
                    // за что отвечает. Теперь явный текст "Рандом", чтобы сразу было
                    // ясно, что кнопка включает выбор фильмов для рулетки.
                    // Явный HStack вместо Label — Label в этом месте почему-то
                    // растягивался по высоте и терял текст, HStack ведёт себя предсказуемо.
                    HStack(spacing: 5) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isSelecting ? "Готово" : "Рандом")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .fixedSize()
                    .foregroundStyle(isSelecting ? .white : AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isSelecting
                            ? AnyShapeStyle(AppTheme.Colors.accentGradient)
                            : AnyShapeStyle(AppTheme.Colors.surfaceElevated)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func headerIconButton<Destination: View>(systemImage: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.surfaceElevated)
                .clipShape(Circle())
        }
    }

    private var randomButton: some View {
        Button {
            let movies = selectedForRandom.compactMap { catalog.movie(withId: $0) }
            randomPickerRequest = RandomPickerRequest(candidates: movies, scores: nil)
        } label: {
            Label("Выбери за меня (\(selectedForRandom.count))", systemImage: "shuffle")
        }
        .buttonStyle(.primaryGradient)
        .padding(.horizontal, AppTheme.Layout.padding)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var selectionHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "shuffle")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.Colors.accent)
            Text("Не можете выбрать? Отметьте 2+ фильма ниже — я крутну рулетку и выберу один за вас.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(AppTheme.Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
        .padding(.horizontal, AppTheme.Layout.padding)
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryCard(title: "Случайное", icon: "shuffle", genre: nil)
                ForEach(shelfGenres, id: \.genre) { entry in
                    categoryCard(title: entry.shelfTitle, icon: icon(for: entry.genre), genre: entry.genre)
                }
            }
            .padding(.horizontal, AppTheme.Layout.padding)
        }
    }

    private func categoryCard(title: String, icon: String, genre: String?) -> some View {
        NavigationLink {
            SwipeDiscoveryView(genre: genre)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 84, height: 76)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }

    private func icon(for genre: String) -> String {
        switch genre {
        case "Боевик": "bolt.fill"
        case "Фантастика": "sparkles"
        case "Драма": "theatermasks.fill"
        case "Комедия": "face.smiling.fill"
        case "Триллер": "eye.fill"
        case "Ужасы": "moon.stars.fill"
        default: "film.fill"
        }
    }

    // MARK: - Liked, grouped by genre

    /// Каждый лайкнутый фильм лежит ровно на одной полке — на той категории,
    /// в которой его лайкнули. Если лайк был в режиме «Случайное» (категории нет),
    /// полка определяется по основному жанру фильма.
    private func shelfGenre(for like: SwipeLike) -> String? {
        if let category = like.category { return category }
        return catalog.movie(withId: like.movieId)?.genres.first
    }

    private var likedShelves: [(title: String, movies: [Movie])] {
        shelfGenres.compactMap { entry in
            let ids = store.likes.reversed()
                .filter { shelfGenre(for: $0) == entry.genre }
                .map(\.movieId)
            let movies = ids.compactMap { catalog.movie(withId: $0) }
            return movies.isEmpty ? nil : (entry.shelfTitle, movies)
        }
    }

    private func shelfSection(title: String, movies: [Movie]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Layout.padding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: AppTheme.Layout.spacing) {
                    ForEach(movies) { movie in
                        shelfCard(movie)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.padding)
            }
        }
    }

    @ViewBuilder
    private func shelfCard(_ movie: Movie) -> some View {
        if isSelecting {
            Button {
                toggleSelection(movie.id)
            } label: {
                MovieCardView(movie: movie, style: .shelf)
                    .overlay(alignment: .topTrailing) {
                        selectionBadge(isSelected: selectedForRandom.contains(movie.id))
                    }
                    .opacity(selectedForRandom.isEmpty || selectedForRandom.contains(movie.id) ? 1 : 0.55)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: movie) {
                MovieCardView(movie: movie, style: .shelf)
            }
            .buttonStyle(.plain)
        }
    }

    private func selectionBadge(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20))
            .foregroundStyle(isSelected ? AppTheme.Colors.accent : .white)
            .background(Circle().fill(.black.opacity(0.45)).padding(-1))
            .padding(6)
    }

    private func toggleSelection(_ movieId: Int) {
        if selectedForRandom.contains(movieId) {
            selectedForRandom.remove(movieId)
        } else {
            selectedForRandom.insert(movieId)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Пока пусто")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Лайкнутые в свайпе фильмы появятся здесь по категориям")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Layout.padding)
        .padding(.top, 24)
    }
}

// MARK: - История свайп-сессий

/// Список законченных проходов колоды свайпа — что лайкнули и отклонили за раз.
/// В отличие от истории ИИ-подборок тут нет ответа модели, только сам факт
/// прохода, поэтому и единственное действие — свайпнуть эту категорию заново,
/// а не "изменить ответы".
struct SwipeSessionHistoryView: View {
    @ObservedObject private var history = SwipeSessionHistoryStore.shared
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared

    var body: some View {
        ScrollView {
            if history.entries.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacing) {
                    Text("Каждая карточка — один проход свайпа. Тапните постер, чтобы открыть фильм, или свайпните категорию заново.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    ForEach(history.entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(AppTheme.Layout.padding)
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("История свайпов")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entryCard(_ entry: SwipeSessionEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.category ?? "Случайное")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Понравилось \(entry.likedMovieIds.count) · Мимо \(entry.dislikedMovieIds.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                Text(entry.date.ruShort)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            if entry.likedMovieIds.isEmpty {
                Text("В этот раз ничего не понравилось")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.likedMovieIds, id: \.self) { id in
                            if let movie = catalog.movie(withId: id) {
                                NavigationLink(value: movie) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        PosterImageView(movieId: id)
                                            .frame(width: 52, height: 74)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        Text(movie.title)
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                            .lineLimit(1)
                                            .frame(width: 52, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            NavigationLink {
                SwipeDiscoveryView(genre: entry.category)
            } label: {
                Label("Свайпнуть эту категорию заново", systemImage: "arrow.clockwise")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Пока пусто")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Здесь появится история ваших свайп-подборок")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Корзина дизлайков

/// "Корзина" отклонённого в свайпе — можно посмотреть, что смахнули "мимо",
/// и вернуть конкретный фильм обратно в колоду одним тапом.
struct SwipeDislikesView: View {
    @ObservedObject private var store = SwipeMatchesStore.shared
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared

    private var items: [(dislike: SwipeDislike, movie: Movie)] {
        store.dislikes.reversed().compactMap { dislike in
            catalog.movie(withId: dislike.movieId).map { (dislike, $0) }
        }
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 16) {
                    ForEach(items, id: \.dislike.movieId) { item in
                        dislikeCard(item.movie)
                    }
                }
                .padding(AppTheme.Layout.padding)
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Отклонённое")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dislikeCard(_ movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                PosterImageView(movieId: movie.id)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))

                Button {
                    store.removeDislike(movie.id)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, AppTheme.Colors.accent)
                        .background(Circle().fill(.black.opacity(0.35)))
                }
                .padding(6)
            }
            Text(movie.title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Пусто")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Фильмы, свайпнутые «мимо», появятся здесь")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Рандомайзер "Выбери за меня"

/// Запрос на показ рандомайзера — .fullScreenCover(item:) строит RandomPickerView
/// прямо из этого значения, поэтому кандидаты не могут "не успеть" примениться
/// к моменту показа, в отличие от isPresented-флага с отдельным state рядом.
struct RandomPickerRequest: Identifiable {
    let id = UUID()
    let candidates: [Movie]
    let scores: [Int: Int]?
}

/// Общий "решает случай" для Мэтчей и обычного отбора — крупный постер "крутится"
/// по кандидатам с растущей задержкой (эффект замедляющегося барабана) и с эффектами
/// (свечение, хаптик, вспышка на финале) останавливается на одном. Без geometry-
/// математики со смещением ленты — это надёжно и не зависит от размеров экрана.
/// При наличии scores (совпадение в % из ИИ-подборки) шанс каждого фильма
/// пропорционален его проценту; без scores (лайки в свайпе, где совпадения
/// как числа не существует) — шанс у всех кандидатов одинаковый.
/// `onFinished` вызывается по кнопке "Готово" с выбранным фильмом — экран,
/// который показал рандомайзер, сам решает, что делать дальше (открыть деталь фильма).
struct RandomPickerView: View {
    let candidates: [Movie]
    let scores: [Int: Int]?
    var onFinished: (Movie) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var isSpinning = true
    @State private var winner: Movie?
    @State private var tick = false
    @State private var ringRotation: Double = 0
    @State private var showSparkles = false
    /// Кандидаты для текущего круга — уменьшается на каждый реролл (выигравший
    /// фильм убирается), в отличие от неизменного candidates.
    @State private var pool: [Movie]

    init(candidates: [Movie], scores: [Int: Int]?, onFinished: @escaping (Movie) -> Void = { _ in }) {
        self.candidates = candidates
        self.scores = scores
        self.onFinished = onFinished
        _pool = State(initialValue: candidates)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(isSpinning ? "Выбираем за вас…" : "Ваш фильм")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.top, 40)

                if isSpinning {
                    posterFrame
                    thumbnailStrip
                } else if let winner {
                    // После остановки — та же карусель (видео + кадры), что и на
                    // странице фильма, вместо статичного постера с кольцом.
                    MovieStillsCarouselView(movieId: winner.id)
                        .padding(.horizontal, AppTheme.Layout.padding)
                    winnerInfo(winner)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        // Кнопка закреплена внизу отдельно от скролла — блок с описанием фильма
        // может не поместиться на маленьких экранах, а кнопка должна быть видна всегда.
        .safeAreaInset(edge: .bottom) {
            Group {
                if isSpinning {
                    Button("Отмена") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                } else {
                    VStack(spacing: 10) {
                        Button("Готово") {
                            if let winner { onFinished(winner) }
                        }
                        .buttonStyle(.primaryGradient)

                        // Не показываем реролл, если этот фильм — последний в пуле:
                        // крутить больше не из чего.
                        if pool.count > 1 {
                            Button {
                                reroll()
                            } label: {
                                Label("Реролл — попробовать другой", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppTheme.Layout.padding)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.background)
        }
        .onAppear(perform: startSpin)
    }

    /// Раньше тут были только название и жанр — по фильму было ничего не понятно.
    /// Добавили рейтинг, длительность и hook (тот же короткий тизер без спойлеров,
    /// что уже используется на карточках свайпа) — теперь видно, о чём фильм.
    private func winnerInfo(_ movie: Movie) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(movie.title)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(String(movie.year)) · \(movie.genresLabel)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 14) {
                    Label(String(format: "%.1f", movie.rating), systemImage: "star.fill")
                    Label(movie.durationLabel, systemImage: "clock")
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

                if let score = scores?[movie.id] {
                    Text("Совпадение \(score)%")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }

            Text(movie.hook)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.85))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Layout.padding)
                .background(AppTheme.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
        }
        .padding(.horizontal, AppTheme.Layout.padding)
    }

    private var posterFrame: some View {
        let movie = pool.indices.contains(currentIndex) ? pool[currentIndex] : pool.first
        return ZStack {
            // Крутящееся кольцо-свечение позади постера, пока идёт выбор — источник
            // "игрового" ощущения без риска сломать надёжную индекс-логику рядом.
            if isSpinning {
                Circle()
                    .stroke(
                        AngularGradient(colors: [AppTheme.Colors.accent, .clear, AppTheme.Colors.accent], center: .center),
                        lineWidth: 6
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(ringRotation))
                    .blur(radius: 2)
            }

            if let movie {
                PosterImageView(movieId: movie.id)
                    .frame(width: 210, height: 315)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                            .stroke(AppTheme.Colors.accent, lineWidth: isSpinning ? 0 : 3)
                    )
                    // Небольшой "удар" на каждой смене кадра плюс общий подскок на финале.
                    .scaleEffect(isSpinning ? (tick ? 1.06 : 1.0) : 1.08)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
            } else {
                Color.clear.frame(width: 210, height: 315)
            }

            if showSparkles {
                sparkleburst
            }
        }
        .animation(.spring(response: 0.35), value: isSpinning)
        .animation(.easeOut(duration: 0.12), value: tick)
    }

    /// Ряд мини-постеров всех кандидатов — подсвеченный текущий индекс визуально
    /// "бежит" по ряду в такт основному постеру, усиливая ощущение колеса/барабана.
    private var thumbnailStrip: some View {
        HStack(spacing: 8) {
            ForEach(Array(pool.enumerated()), id: \.offset) { index, movie in
                PosterImageView(movieId: movie.id)
                    .frame(width: 34, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.Colors.accent, lineWidth: index == currentIndex ? 2 : 0)
                    )
                    .opacity(index == currentIndex ? 1 : 0.4)
                    .scaleEffect(index == currentIndex ? 1.12 : 1)
            }
        }
        .animation(.easeOut(duration: 0.15), value: currentIndex)
    }

    private var sparkleburst: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .offset(y: -90)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
        }
        .scaleEffect(showSparkles ? 1.4 : 0.2)
        .opacity(showSparkles ? 0 : 1)
        .animation(.easeOut(duration: 0.6), value: showSparkles)
    }

    private func startSpin() {
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        guard pool.count >= 2 else {
            winner = pool.first
            isSpinning = false
            return
        }
        let picked = pickWinner()
        let targetIndex = pool.firstIndex { $0.id == picked.id } ?? 0
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()

        // Растущая задержка между сменами постера — визуально это "барабан",
        // который крутится быстро, а потом плавно замедляется и замирает.
        //
        // Индекс на каждом тике считаем "в обратную сторону от финала" (сколько
        // тиков осталось до конца), а не просто по кругу от нуля — тогда
        // последний тик математически гарантированно совпадает с targetIndex,
        // без отдельного жёсткого "прыжка" в конце (раньше цикл шёл сам по себе,
        // а последним кадром сразу подставлялся правильный индекс — это и
        // выглядело как скачок).
        var t = 0.0
        var delay = 0.06
        let steps = 16
        for step in 0..<steps {
            t += delay
            let stepsRemaining = steps - 1 - step
            let idx = ((targetIndex - stepsRemaining) % pool.count + pool.count) % pool.count
            let isLast = step == steps - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                currentIndex = idx
                tick.toggle()
                if isLast {
                    withAnimation(.spring(response: 0.4)) {
                        winner = picked
                        isSpinning = false
                        showSparkles = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    impact.impactOccurred()
                }
            }
            delay *= 1.14
        }
    }

    /// Без scores — равный шанс всем. Со scores — шанс пропорционален проценту
    /// совпадения (минимум 1, чтобы 0% не обнулял шанс совсем).
    private func pickWinner() -> Movie {
        guard let scores else {
            return pool.randomElement() ?? pool[0]
        }
        let weights = pool.map { max(scores[$0.id] ?? 1, 1) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return pool.randomElement() ?? pool[0] }
        var r = Int.random(in: 0..<total)
        for (movie, weight) in zip(pool, weights) {
            if r < weight { return movie }
            r -= weight
        }
        return pool.last ?? pool[0]
    }

    /// Убирает выпавший фильм из пула и крутит заново среди оставшихся.
    /// Если остался ровно один — отдаём его сразу, без анимации: крутить
    /// барабан с одним вариантом бессмысленно, результат и так предопределён.
    private func reroll() {
        guard let winner else { return }
        pool.removeAll { $0.id == winner.id }
        self.winner = nil
        showSparkles = false

        if pool.count <= 1 {
            self.winner = pool.first
            isSpinning = false
        } else {
            currentIndex = 0
            isSpinning = true
            startSpin()
        }
    }
}

/// Предыдущая версия дизайна рандомайзера — по просьбе пользователя сохранена
/// как есть и не используется нигде, только на случай, если понадобится вернуть
/// именно этот вариант. Логика идентична RandomPickerView без свечения/хаптика/
/// вспышки/полоски миниатюр и без перехода в деталь фильма по "Готово".
struct RandomPickerViewClassic: View {
    let candidates: [Movie]
    let scores: [Int: Int]?

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var isSpinning = true
    @State private var winner: Movie?

    var body: some View {
        VStack(spacing: 24) {
            Text(isSpinning ? "Выбираем за вас…" : "Ваш фильм")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.top, 40)

            posterFrame

            if let winner, !isSpinning {
                VStack(spacing: 6) {
                    Text(winner.title)
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(String(winner.year)) · \(winner.genresLabel)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    if let score = scores?[winner.id] {
                        Text("Совпадение \(score)%")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.padding)
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            if isSpinning {
                Button("Отмена") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                Button("Готово") { dismiss() }
                    .buttonStyle(.primaryGradient)
                    .padding(.horizontal, AppTheme.Layout.padding)
            }
        }
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .onAppear(perform: startSpin)
    }

    private var posterFrame: some View {
        let movie = candidates.indices.contains(currentIndex) ? candidates[currentIndex] : candidates.first
        return Group {
            if let movie {
                PosterImageView(movieId: movie.id)
                    .frame(width: 210, height: 315)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                            .stroke(AppTheme.Colors.accent, lineWidth: isSpinning ? 0 : 3)
                    )
                    .scaleEffect(isSpinning ? 1 : 1.05)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
            } else {
                Color.clear.frame(width: 210, height: 315)
            }
        }
        .animation(.spring(response: 0.35), value: isSpinning)
    }

    private func startSpin() {
        guard candidates.count >= 2 else {
            winner = candidates.first
            isSpinning = false
            return
        }
        let picked = pickWinner()
        let targetIndex = candidates.firstIndex { $0.id == picked.id } ?? 0

        var t = 0.0
        var delay = 0.06
        let steps = 16
        for step in 0..<steps {
            t += delay
            let idx = step % candidates.count
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                currentIndex = idx
            }
            delay *= 1.14
        }
        t += delay
        DispatchQueue.main.asyncAfter(deadline: .now() + t) {
            currentIndex = targetIndex
            withAnimation(.spring(response: 0.4)) {
                winner = picked
                isSpinning = false
            }
        }
    }

    private func pickWinner() -> Movie {
        guard let scores else {
            return candidates.randomElement() ?? candidates[0]
        }
        let weights = candidates.map { max(scores[$0.id] ?? 1, 1) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return candidates.randomElement() ?? candidates[0] }
        var r = Int.random(in: 0..<total)
        for (movie, weight) in zip(candidates, weights) {
            if r < weight { return movie }
            r -= weight
        }
        return candidates.last ?? candidates[0]
    }
}

#Preview {
    NavigationStack {
        SwipeMatchesView()
    }
}
