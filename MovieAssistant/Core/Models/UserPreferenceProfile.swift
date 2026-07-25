import Foundation

/// Жанр и настроение одного участника сценария "Смотрим вместе".
struct TogetherParticipant: Codable, Equatable {
    var genres: [String] = []
    var mood: [String] = []
}

/// Нормализованный профиль предпочтений пользователя.
/// Строится любым из сценариев (быстрый подбор, по фильму, чат, вместе)
/// и передаётся в `AIRecommendationService` — сервис рекомендаций не знает,
/// из какого сценария пришёл профиль.
///
/// Codable — профиль целиком сохраняется в истории запросов, чтобы можно было
/// показать все отвеченные критерии и позволить пройти сценарий заново с теми
/// же (или изменёнными) ответами, а не только короткой строкой-описанием.
struct UserPreferenceProfile: Codable {
    enum Source: Codable, Equatable {
        case quickPick
        case movieBased(referenceMovieId: Int)
        case chat
        case together
        /// Сценарий "Мэтчи" — фильмы, которые пользователь лайкнул свайпом.
        case swipeMatch(likedMovieIds: [Int])

        private enum CodingKeys: String, CodingKey {
            case kind, referenceMovieId, likedMovieIds
        }

        private enum Kind: String, Codable {
            case quickPick, movieBased, chat, together, swipeMatch
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Kind.self, forKey: .kind) {
            case .quickPick: self = .quickPick
            case .movieBased:
                self = .movieBased(referenceMovieId: try container.decode(Int.self, forKey: .referenceMovieId))
            case .chat: self = .chat
            case .together: self = .together
            case .swipeMatch:
                self = .swipeMatch(likedMovieIds: try container.decode([Int].self, forKey: .likedMovieIds))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .quickPick:
                try container.encode(Kind.quickPick, forKey: .kind)
            case .movieBased(let referenceMovieId):
                try container.encode(Kind.movieBased, forKey: .kind)
                try container.encode(referenceMovieId, forKey: .referenceMovieId)
            case .chat:
                try container.encode(Kind.chat, forKey: .kind)
            case .together:
                try container.encode(Kind.together, forKey: .kind)
            case .swipeMatch(let likedMovieIds):
                try container.encode(Kind.swipeMatch, forKey: .kind)
                try container.encode(likedMovieIds, forKey: .likedMovieIds)
            }
        }
    }

    let source: Source

    var genres: [String] = []
    var importantAspects: [String] = []
    var mood: [String] = []
    var durationPreference: String?
    /// Жанры, которые пользователь явно не хочет видеть — жёсткое ограничение для ИИ.
    var excludedGenres: [String] = []

    var likedAspects: [String] = []
    var likedActors: [String] = []
    var likedPlotFeatures: [String] = []
    var likedAtmosphere: [String] = []
    var wantsToChange: [String] = []

    var freeTextQuery: String?

    /// Заполняется только для сценария "Смотрим вместе" — жанр и настроение
    /// каждого участника (включая самого пользователя), чтобы ИИ искал
    /// компромисс сразу для всей компании, а не только для двоих.
    var togetherParticipants: [TogetherParticipant] = []

    /// Краткая сводка прошлых оценок пользователя (из опроса после "просмотра") —
    /// заполняется RecommendationViewModel'ом, не самим сценарием.
    var tasteHistorySummary: String?

    /// Краткая сводка фильмов, лайкнутых в свайп-подборе — заполняется
    /// RecommendationViewModel'ом, не самим сценарием.
    var swipeLikesSummary: String?
}
