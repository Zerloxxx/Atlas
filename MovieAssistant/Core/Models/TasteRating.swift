import Foundation

/// Оценка фильма, оставленная пользователем в мини-опросе после "просмотра".
struct TasteRating: Codable {
    let movieId: Int
    let rating: Int
    let likedTags: [String]
    let watchedFully: Bool?
    let date: Date
}
