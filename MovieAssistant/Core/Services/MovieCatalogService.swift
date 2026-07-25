import Foundation

protocol MovieCatalogProviding {
    func allMovies() -> [Movie]
    func movie(withId id: Int) -> Movie?
}

/// Читает локальный movies.json. Позже можно заменить реализацией поверх
/// реального каталога онлайн-кинотеатра — ViewModel'ы работают только
/// через протокол `MovieCatalogProviding` и не заметят разницы.
final class MovieCatalogService: MovieCatalogProviding {
    static let shared = MovieCatalogService()

    private let movies: [Movie]

    private init() {
        movies = Self.loadMovies()
    }

    func allMovies() -> [Movie] {
        movies
    }

    func movie(withId id: Int) -> Movie? {
        movies.first { $0.id == id }
    }

    private static func loadMovies() -> [Movie] {
        guard let url = Bundle.main.url(forResource: "movies", withExtension: "json") else {
            assertionFailure("movies.json не найден в бандле — проверь, что файл добавлен в target")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Movie].self, from: data)
        } catch {
            assertionFailure("Не удалось распарсить movies.json: \(error)")
            return []
        }
    }
}
