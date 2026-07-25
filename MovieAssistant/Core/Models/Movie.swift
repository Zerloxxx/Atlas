import Foundation

struct Movie: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let year: Int
    let genres: [String]
    let director: String
    let actors: [String]
    let synopsis: String
    /// 2-3 предложения "подогрева" для свайп-подбора — сюжетная завязка и интрига,
    /// но без концовки и ключевых поворотов (в отличие от synopsis, который может их касаться).
    let hook: String
    let themes: [String]
    let atmosphere: [String]
    let plotFeatures: [String]
    let durationMinutes: Int
    let ageRating: String
    let endingType: String
    let rating: Double

    var durationLabel: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        return hours > 0 ? "\(hours) ч \(minutes) мин" : "\(minutes) мин"
    }

    var genresLabel: String {
        genres.joined(separator: ", ")
    }

    /// Поиск по названию, жанрам и актёрам — используется на экранах с поиском.
    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(trimmed) { return true }
        if genres.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) { return true }
        if actors.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) { return true }
        return false
    }
}
