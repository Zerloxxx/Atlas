import Foundation

/// История прошлых запросов к ИИ и их результатов — переживает перезапуск
/// (UserDefaults). Позволяет вернуться к уже показанной подборке и выбрать
/// фильм из неё, не проходя опрос заново.
@MainActor
final class RecommendationHistoryStore: ObservableObject {
    static let shared = RecommendationHistoryStore()

    private let maxEntries = 20
    private let defaultsKey = "recommendationHistory.entries"

    @Published private(set) var entries: [RecommendationHistoryEntry] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([RecommendationHistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    func addEntry(scenarioLabel: String, queryDescription: String, profile: UserPreferenceProfile, results: [RecommendationResult]) {
        let items = results.map { RecommendationHistoryItem(movieId: $0.movie.id, explanation: $0.explanation, matchScore: $0.matchScore) }
        let entry = RecommendationHistoryEntry(
            id: UUID(),
            date: Date(),
            scenarioLabel: scenarioLabel,
            queryDescription: queryDescription,
            profile: profile,
            items: items
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
