import Foundation

final class OpenAIRecommendationService: AIRecommendationService {
    private let client: OpenAIClient
    private let catalog: MovieCatalogProviding

    init(client: OpenAIClient = .shared, catalog: MovieCatalogProviding = MovieCatalogService.shared) {
        self.client = client
        self.catalog = catalog
    }

    func recommend(for profile: UserPreferenceProfile, excluding excludedIds: Set<Int>) async throws -> [RecommendationResult] {
        var movies = catalog.allMovies()

        // В сценарии "по фильму" исключаем сам референсный фильм — бессмысленно
        // рекомендовать пользователю фильм, который он только что назвал понравившимся.
        if case .movieBased(let referenceMovieId) = profile.source {
            movies.removeAll { $0.id == referenceMovieId }
        }

        // Исключаем уже сохранённое/отклонённое, но не даём каталогу опустеть —
        // если исключения съели всё, лучше показать что-то, чем ничего.
        if !excludedIds.isEmpty {
            let filtered = movies.filter { !excludedIds.contains($0.id) }
            if !filtered.isEmpty {
                movies = filtered
            }
        }

        let systemPrompt = PromptBuilder.systemPrompt()
        let userPrompt = PromptBuilder.userPrompt(profile: profile, catalog: movies)

        let rawContent = try await client.complete(systemPrompt: systemPrompt, userPrompt: userPrompt)

        guard let data = rawContent.data(using: .utf8) else {
            throw OpenAIClientError.emptyResponse
        }

        let parsed = try JSONDecoder().decode(AIResponsePayload.self, from: data)

        // Запрос не про фильмы — ИИ сам это определил, показываем его пояснение
        // через стандартный экран ошибки вместо натянутых "рекомендаций".
        if parsed.offTopic {
            throw OpenAIClientError.offTopic(
                parsed.message.isEmpty
                    ? "Я помогаю только с подбором фильмов — задайте вопрос о том, что хотите посмотреть."
                    : parsed.message
            )
        }

        // Строго резолвим movieId по локальному каталогу — фильм, который модель могла
        // "придумать" или спутать с несуществующим id, просто отбрасывается.
        return parsed.recommendations.compactMap { item in
            catalog.movie(withId: item.movieId).map { movie in
                RecommendationResult(
                    movie: movie,
                    explanation: item.explanation,
                    matchScore: min(max(item.matchScore, 0), 100)
                )
            }
        }
    }

    private struct AIResponsePayload: Decodable {
        struct Item: Decodable {
            let movieId: Int
            let matchScore: Int
            let explanation: String
        }
        let offTopic: Bool
        let message: String
        let recommendations: [Item]
    }
}
