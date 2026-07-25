import Foundation

@MainActor
final class SwipeDiscoveryViewModel: ObservableObject {
    @Published private(set) var deck: [Movie] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var sessionLikedIds: [Int] = []
    @Published private(set) var sessionDislikedIds: [Int] = []
    @Published var pendingProfile: UserPreferenceProfile?
    /// true — колоду собрали, вернув в неё ранее отклонённые: в этой категории
    /// новых фильмов уже не осталось, показываем об этом честную подсказку.
    @Published private(set) var isRecycledDeck = false
    /// Последний свайп в этой колоде — для кнопки "отменить". Храним только
    /// один шаг назад: многоуровневый undo для прототипа избыточен.
    @Published private(set) var lastAction: (movie: Movie, liked: Bool)?

    /// nil — колода из всего каталога; иначе только фильмы этого жанра.
    let genre: String?

    private let catalog: MovieCatalogProviding
    private let watchlist: WatchlistStore
    private let tasteProfile: TasteProfileStore
    private let swipeMatches: SwipeMatchesStore
    private let sessionHistory: SwipeSessionHistoryStore

    private let deckSize = 6
    private var hasLoggedSession = false

    init(
        genre: String? = nil,
        catalog: MovieCatalogProviding = MovieCatalogService.shared,
        watchlist: WatchlistStore = .shared,
        tasteProfile: TasteProfileStore = .shared,
        swipeMatches: SwipeMatchesStore = .shared,
        sessionHistory: SwipeSessionHistoryStore = .shared
    ) {
        self.genre = genre
        self.catalog = catalog
        self.watchlist = watchlist
        self.tasteProfile = tasteProfile
        self.swipeMatches = swipeMatches
        self.sessionHistory = sessionHistory
        buildDeck()
    }

    var currentCard: Movie? {
        deck.indices.contains(currentIndex) ? deck[currentIndex] : nil
    }

    var nextCard: Movie? {
        deck.indices.contains(currentIndex + 1) ? deck[currentIndex + 1] : nil
    }

    var isFinished: Bool {
        currentIndex >= deck.count
    }

    var likedMovies: [Movie] {
        sessionLikedIds.compactMap { catalog.movie(withId: $0) }
    }

    var canUndo: Bool {
        lastAction != nil
    }

    /// Новая подборка из того, что пользователь ещё не видел (не в "Буду смотреть",
    /// не оценено и не лайкнуто в свайпе раньше), при заданном жанре — только он.
    ///
    /// Если в узкой категории всё уже просмотрено (например, ужасов в базе всего
    /// четыре), не показываем пустой экран, а возвращаем в колоду ранее отклонённые —
    /// иначе категория "выгорала" бы навсегда.
    func buildDeck() {
        let inCategory = catalog.allMovies().filter { movie in
            genre == nil || movie.genres.contains(genre!)
        }
        // Лайкнутое, сохранённое и оценённое не возвращаем никогда — это осознанный
        // выбор пользователя. Заново предлагаем только то, что он просто пролистал.
        let hardExcluded = watchlist.savedMovieIds
            .union(tasteProfile.ratedMovieIds)
            .union(swipeMatches.likedMovieIds)

        let fresh = inCategory.filter {
            !hardExcluded.contains($0.id) && !swipeMatches.dislikedMovieIds.contains($0.id)
        }
        let recycled = inCategory.filter { !hardExcluded.contains($0.id) }

        let candidates: [Movie]
        if !fresh.isEmpty {
            candidates = fresh
            isRecycledDeck = false
        } else {
            candidates = recycled
            isRecycledDeck = !recycled.isEmpty
        }

        deck = Array(candidates.shuffled().prefix(deckSize))
        currentIndex = 0
        sessionLikedIds = []
        sessionDislikedIds = []
        lastAction = nil
        hasLoggedSession = false
    }

    func like(_ movie: Movie) {
        guard currentCard?.id == movie.id else { return }
        if !sessionLikedIds.contains(movie.id) {
            sessionLikedIds.append(movie.id)
        }
        swipeMatches.add(movie.id, category: genre)
        lastAction = (movie, true)
        currentIndex += 1
        logSessionIfFinished()
    }

    func dislike(_ movie: Movie) {
        guard currentCard?.id == movie.id else { return }
        if !sessionDislikedIds.contains(movie.id) {
            sessionDislikedIds.append(movie.id)
        }
        swipeMatches.dislike(movie.id, category: genre)
        lastAction = (movie, false)
        currentIndex += 1
        logSessionIfFinished()
    }

    /// Возвращает последнюю просвайпанную карточку обратно наверх колоды —
    /// на случай, если палец промахнулся или пользователь передумал.
    func undoLastSwipe() {
        guard let action = lastAction, currentIndex > 0 else { return }
        currentIndex -= 1
        if action.liked {
            sessionLikedIds.removeAll { $0 == action.movie.id }
            swipeMatches.removeLike(action.movie.id)
        } else {
            sessionDislikedIds.removeAll { $0 == action.movie.id }
            swipeMatches.removeDislike(action.movie.id)
        }
        lastAction = nil
    }

    /// Строит профиль на основе лайкнутых в этой сессии фильмов и отправляет
    /// на общий экран рекомендаций — тот же AI-пайплайн, что и у остальных сценариев.
    func requestSimilar() {
        guard !sessionLikedIds.isEmpty else { return }
        pendingProfile = UserPreferenceProfile(source: .swipeMatch(likedMovieIds: sessionLikedIds))
    }

    func restart() {
        buildDeck()
    }

    /// Явный сброс отклонённых по кнопке — когда пользователь хочет пересмотреть
    /// всё заново, не дожидаясь автоподмешивания.
    func resetSkipped() {
        swipeMatches.resetDislikes()
        buildDeck()
    }

    /// Логирует проход колоды в историю ровно один раз, в момент, когда дошли
    /// до конца — так же, как история ИИ-подборок логируется на первый успешный фетч.
    private func logSessionIfFinished() {
        guard isFinished, !hasLoggedSession else { return }
        hasLoggedSession = true
        sessionHistory.addEntry(category: genre, likedMovieIds: sessionLikedIds, dislikedMovieIds: sessionDislikedIds)
    }
}
