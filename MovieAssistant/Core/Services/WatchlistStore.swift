import Foundation

/// Список "Буду смотреть" — общий на всё приложение, переживает перезапуск
/// (хранится в UserDefaults). Простое хранилище достаточно для MVP,
/// без отдельной базы данных.
@MainActor
final class WatchlistStore: ObservableObject {
    static let shared = WatchlistStore()

    @Published private(set) var savedMovieIds: Set<Int>

    private let defaultsKey = "watchlist.savedMovieIds"

    private init() {
        let stored = UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? []
        savedMovieIds = Set(stored)
    }

    func isSaved(_ movieId: Int) -> Bool {
        savedMovieIds.contains(movieId)
    }

    func toggle(_ movieId: Int) {
        if savedMovieIds.contains(movieId) {
            savedMovieIds.remove(movieId)
        } else {
            savedMovieIds.insert(movieId)
        }
        UserDefaults.standard.set(Array(savedMovieIds), forKey: defaultsKey)
    }
}
