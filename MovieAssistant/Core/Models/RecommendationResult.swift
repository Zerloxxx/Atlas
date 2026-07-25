import Foundation

/// Итоговая рекомендация: фильм строго из локальной базы + объяснение выбора от ИИ.
struct RecommendationResult: Identifiable {
    var id: Int { movie.id }
    let movie: Movie
    let explanation: String
    /// Оценка совпадения с предпочтениями пользователя, 0-100, определяется ИИ.
    let matchScore: Int
}
