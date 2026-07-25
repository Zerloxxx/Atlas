import Foundation

/// Точка расширения архитектуры: сейчас единственная реализация — прямой вызов OpenAI.
/// Позже можно добавить, например, BackendProxyRecommendationService — ViewModel'ы,
/// которые зависят только от этого протокола, менять не придётся.
protocol AIRecommendationService {
    /// `excludedIds` — фильмы, которые не нужно предлагать: уже сохранённые в "Буду смотреть"
    /// и/или отклонённые пользователем в рамках текущей подборки ("не то, другое").
    func recommend(for profile: UserPreferenceProfile, excluding excludedIds: Set<Int>) async throws -> [RecommendationResult]
}
