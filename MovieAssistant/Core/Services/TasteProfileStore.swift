import Foundation

/// Копилка оценок из опроса "как вам фильм?" — переживает перезапуск (UserDefaults).
/// Используется, чтобы подмешивать краткую сводку вкуса пользователя в промпт ИИ
/// на будущих запросах рекомендаций (замкнутый цикл персонализации).
@MainActor
final class TasteProfileStore: ObservableObject {
    static let shared = TasteProfileStore()

    /// Храним только последние N оценок — сводка не должна бесконтрольно расти
    /// и раздувать промпт (а с ним и стоимость запроса).
    private let maxHistoryCount = 10
    private let defaultsKey = "tasteProfile.ratings"

    @Published private(set) var ratings: [TasteRating] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([TasteRating].self, from: data) {
            ratings = decoded
        }
    }

    func hasRated(_ movieId: Int) -> Bool {
        ratings.contains { $0.movieId == movieId }
    }

    func rating(for movieId: Int) -> TasteRating? {
        ratings.first { $0.movieId == movieId }
    }

    func addRating(movieId: Int, rating: Int, likedTags: [String], watchedFully: Bool?) {
        ratings.removeAll { $0.movieId == movieId }
        ratings.append(TasteRating(movieId: movieId, rating: rating, likedTags: likedTags, watchedFully: watchedFully, date: Date()))
        if ratings.count > maxHistoryCount {
            ratings.removeFirst(ratings.count - maxHistoryCount)
        }
        save()
    }

    var ratedMovieIds: Set<Int> {
        Set(ratings.map(\.movieId))
    }

    /// Короткая сводка для промпта — только это (не весь объект) уходит в запрос к ИИ.
    func summaryForPrompt(catalog: MovieCatalogProviding) -> String? {
        guard !ratings.isEmpty else { return nil }
        let lines = ratings.compactMap { entry -> String? in
            guard let movie = catalog.movie(withId: entry.movieId) else { return nil }
            var line = "\(movie.title) — \(entry.rating)/5"
            if !entry.likedTags.isEmpty {
                line += " (понравилось: \(entry.likedTags.joined(separator: ", ")))"
            }
            return line
        }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "; ")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
