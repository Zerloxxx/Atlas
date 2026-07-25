import Foundation

/// Один сохранённый фильм из прошлой подборки — ровно то, что вернул ИИ,
/// без повторного запроса при просмотре истории.
struct RecommendationHistoryItem: Codable {
    let movieId: Int
    let explanation: String
    let matchScore: Int
}

/// Один прошлый запрос к ИИ и его результат — сценарий, краткое описание того,
/// что спросили, и сами карточки.
struct RecommendationHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let scenarioLabel: String
    let queryDescription: String
    /// Полный профиль запроса — по нему строится разбивка всех отвеченных
    /// критериев в деталях истории и запускаются "Пройти ещё раз"/"Изменить ответы".
    let profile: UserPreferenceProfile
    let items: [RecommendationHistoryItem]

    /// Человекочитаемое описание сценария/запроса — не завязано на ИИ,
    /// формируется локально по профилю, который уже был собран сценарием.
    static func summarize(profile: UserPreferenceProfile, catalog: MovieCatalogProviding) -> (label: String, description: String) {
        switch profile.source {
        case .quickPick:
            var parts: [String] = []
            if !profile.genres.isEmpty { parts.append(profile.genres.joined(separator: ", ")) }
            if !profile.mood.isEmpty { parts.append(profile.mood.joined(separator: ", ")) }
            if !profile.excludedGenres.isEmpty { parts.append("без: \(profile.excludedGenres.joined(separator: ", "))") }
            return ("Быстрый подбор", parts.isEmpty ? "Без уточнений" : parts.joined(separator: " · "))

        case .movieBased(let referenceMovieId):
            let title = catalog.movie(withId: referenceMovieId)?.title ?? "фильму"
            var parts: [String] = []
            if !profile.likedActors.isEmpty { parts.append(profile.likedActors.joined(separator: ", ")) }
            if !profile.likedAspects.isEmpty { parts.append(profile.likedAspects.joined(separator: ", ")) }
            return ("По фильму «\(title)»", parts.isEmpty ? "Похожее" : parts.joined(separator: " · "))

        case .chat:
            return ("AI Chat", profile.freeTextQuery ?? "")

        case .together:
            let parts = profile.togetherParticipants.enumerated().compactMap { index, participant -> String? in
                guard !participant.genres.isEmpty else { return nil }
                return "чел. \(index + 1): \(participant.genres.joined(separator: ", "))"
            }
            let count = profile.togetherParticipants.count
            return ("Смотрим вместе (\(count))", parts.joined(separator: " · "))

        case .swipeMatch(let likedMovieIds):
            let titles = likedMovieIds.compactMap { catalog.movie(withId: $0)?.title }
            return ("Мэтчи", titles.isEmpty ? "Похожее на понравившееся" : "На основе: \(titles.joined(separator: ", "))")
        }
    }
}
