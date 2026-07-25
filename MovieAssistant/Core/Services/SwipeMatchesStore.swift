import Foundation

/// Один лайк из свайп-подбора: сам фильм и категория, в которой его лайкнули.
/// Категория нужна, чтобы на вкладке «Мэтчи» фильм лежал на той же полке, где
/// пользователь его нашёл (у большинства фильмов несколько жанров, и полка
/// «по первому жанру» уводила бы фильм не туда, где его искали).
struct SwipeLike: Codable, Equatable {
    let movieId: Int
    /// nil — лайкнут в режиме «Случайное», полка определяется по основному жанру.
    let category: String?
}

/// Один дизлайк из свайп-подбора — та же форма, что и лайк, чтобы можно было
/// показать «корзину» отклонённого и вернуть конкретный фильм обратно в колоду.
struct SwipeDislike: Codable, Equatable {
    let movieId: Int
    let category: String?
}

/// Один законченный проход колоды свайпа — что лайкнули и что отклонили за раз.
struct SwipeSessionEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let category: String?
    let likedMovieIds: [Int]
    let dislikedMovieIds: [Int]
}

/// Фильмы, лайкнутые в свайп-подборе ("Мэтчи") — переживает перезапуск (UserDefaults).
/// Отдельно от WatchlistStore: лайк в свайпе значит "заинтересовал по обложке",
/// а не "точно буду смотреть" — но, как и вкус из опроса, тоже подмешивается
/// в промпт ИИ как дополнительный контекст.
@MainActor
final class SwipeMatchesStore: ObservableObject {
    static let shared = SwipeMatchesStore()

    /// В промпт уходит только хвост истории — чтобы запрос не рос бесконечно.
    /// Сам список лайков при этом не обрезаем: он показывается на вкладке «Мэтчи».
    private let maxLikesInPrompt = 15
    private let likesKey = "swipeMatches.likes.v2"
    private let legacyLikedIdsKey = "swipeMatches.likedMovieIds"
    private let dislikesKey = "swipeMatches.dislikes.v2"
    private let legacyDislikedIdsKey = "swipeMatches.dislikedMovieIds"

    @Published private(set) var likes: [SwipeLike]
    /// Свайпнутые "мимо" — хранится той же формой, что и лайк (id + категория),
    /// чтобы была видна "корзина" отклонённого и можно было вернуть фильм в колоду.
    /// В промпт ИИ намеренно не идёт: один пропуск — слабый сигнал, не повод
    /// сужать будущие рекомендации.
    @Published private(set) var dislikes: [SwipeDislike]

    private init() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: likesKey),
           let decoded = try? JSONDecoder().decode([SwipeLike].self, from: data) {
            likes = decoded
        } else {
            // Миграция со старого формата (просто список id, без категории).
            let legacy = defaults.array(forKey: legacyLikedIdsKey) as? [Int] ?? []
            likes = legacy.map { SwipeLike(movieId: $0, category: nil) }
        }

        if let data = defaults.data(forKey: dislikesKey),
           let decoded = try? JSONDecoder().decode([SwipeDislike].self, from: data) {
            dislikes = decoded
        } else {
            // Миграция со старого формата (плоский Set<Int>, без категории).
            let legacy = defaults.array(forKey: legacyDislikedIdsKey) as? [Int] ?? []
            dislikes = legacy.map { SwipeDislike(movieId: $0, category: nil) }
        }
    }

    var likedMovieIds: [Int] {
        likes.map(\.movieId)
    }

    var dislikedMovieIds: Set<Int> {
        Set(dislikes.map(\.movieId))
    }

    func isLiked(_ movieId: Int) -> Bool {
        likes.contains { $0.movieId == movieId }
    }

    func add(_ movieId: Int, category: String?) {
        guard !isLiked(movieId) else { return }
        likes.append(SwipeLike(movieId: movieId, category: category))
        saveLikes()
    }

    /// Убирает лайк — нужно для отмены последнего свайпа.
    func removeLike(_ movieId: Int) {
        guard likes.contains(where: { $0.movieId == movieId }) else { return }
        likes.removeAll { $0.movieId == movieId }
        saveLikes()
    }

    func dislike(_ movieId: Int, category: String?) {
        guard !dislikedMovieIds.contains(movieId) else { return }
        dislikes.append(SwipeDislike(movieId: movieId, category: category))
        saveDislikes()
    }

    /// Возвращает фильм из "корзины" отклонённого обратно в колоду — по кнопке
    /// в корзине или при отмене последнего свайпа.
    func removeDislike(_ movieId: Int) {
        guard dislikes.contains(where: { $0.movieId == movieId }) else { return }
        dislikes.removeAll { $0.movieId == movieId }
        saveDislikes()
    }

    /// Явный сброс отклонённых по кнопке — когда пользователь хочет пересмотреть
    /// всё заново, не дожидаясь автоподмешивания.
    func resetDislikes() {
        guard !dislikes.isEmpty else { return }
        dislikes = []
        saveDislikes()
    }

    /// Короткая сводка для промпта — только названия последних лайков.
    func summaryForPrompt(catalog: MovieCatalogProviding) -> String? {
        guard !likes.isEmpty else { return nil }
        let titles = likes.suffix(maxLikesInPrompt).compactMap { catalog.movie(withId: $0.movieId)?.title }
        guard !titles.isEmpty else { return nil }
        return titles.joined(separator: ", ")
    }

    private func saveLikes() {
        guard let data = try? JSONEncoder().encode(likes) else { return }
        UserDefaults.standard.set(data, forKey: likesKey)
    }

    private func saveDislikes() {
        guard let data = try? JSONEncoder().encode(dislikes) else { return }
        UserDefaults.standard.set(data, forKey: dislikesKey)
    }
}

/// История законченных проходов колоды свайпа — переживает перезапуск.
/// Отдельно от RecommendationHistoryStore: тут нет ответа ИИ, только сам факт
/// прохода (что лайкнули/отклонили), поэтому и единственное осмысленное
/// действие — свайпнуть эту категорию ещё раз, а не "изменить ответы".
@MainActor
final class SwipeSessionHistoryStore: ObservableObject {
    static let shared = SwipeSessionHistoryStore()

    private let maxEntries = 30
    private let defaultsKey = "swipeSessions.history.v1"

    @Published private(set) var entries: [SwipeSessionEntry] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([SwipeSessionEntry].self, from: data) {
            entries = decoded
        }
    }

    /// Пустой проход (ничего не лайкнули и не отклонили) не логируем — обычно
    /// это открыли колоду и сразу вышли, вспоминать нечего.
    func addEntry(category: String?, likedMovieIds: [Int], dislikedMovieIds: [Int]) {
        guard !likedMovieIds.isEmpty || !dislikedMovieIds.isEmpty else { return }
        let entry = SwipeSessionEntry(
            id: UUID(),
            date: Date(),
            category: category,
            likedMovieIds: likedMovieIds,
            dislikedMovieIds: dislikedMovieIds
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
