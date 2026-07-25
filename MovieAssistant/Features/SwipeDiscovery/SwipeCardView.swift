import SwiftUI

/// Тизер-карточка для свайпа — сверху трейлер/кадры (если есть) или просто
/// постер, снизу отдельным блоком описание: жанр, актёры, настроение, рейтинг,
/// но БЕЗ синопсиса и сюжетных деталей — задача карточки заинтриговать,
/// а не пересказать фильм.
struct SwipeCardView: View {
    let movie: Movie

    private var hasMedia: Bool {
        !MovieStillsLoader.images(for: movie.id).isEmpty || TrailerLoader.url(for: movie.id) != nil
    }

    var body: some View {
        // GeometryReader — так же, как было исходно с постером: карточка
        // получает ЖЁСТКИЙ размер от родителя (cardStack), а не "сколько
        // сама насчитает". Без него VStack то ужимался до размера постера
        // (чёрные поля), то наоборот становился жаднее соседних кнопок снизу
        // и выталкивал их за экран — обе крайности от неявного размера.
        GeometryReader { proxy in
            VStack(spacing: 0) {
                mediaArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                descriptionArea
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        }
    }

    @ViewBuilder
    private var mediaArea: some View {
        if hasMedia {
            MovieStillsCarouselView(movieId: movie.id, showsHeading: false, fixedHeight: nil)
        } else {
            PosterImageView(movieId: movie.id)
        }
    }

    private var descriptionArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(movie.title)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer(minLength: 4)
                Label(String(format: "%.1f", movie.rating), systemImage: "star.fill")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.warning)
            }
            Text("\(String(movie.year)) · \(movie.genresLabel)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            if let castLine {
                Text(castLine)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            if !movie.hook.isEmpty {
                // lineLimit — щедрый потолок; minimumScaleFactor подстраховывает:
                // если строк всё равно не хватает, текст чуть уменьшится,
                // но никогда не обрежется многоточием.
                Text(movie.hook)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.9))
                    .lineLimit(5)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 4)
            } else if let teaser {
                // Запасной вариант, если для фильма почему-то нет hook —
                // хотя бы настроение/темы вместо пустого места.
                Text(teaser)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.9))
                    .padding(.top, 4)
            }
        }
        .padding(AppTheme.Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Режиссёр и пара актёров — сильный сигнал для интереса, но не сюжет.
    private var castLine: String? {
        let actors = movie.actors.prefix(2).joined(separator: ", ")
        guard !actors.isEmpty else { return nil }
        return "\(movie.director) · в ролях: \(actors)"
    }

    /// Настроение и темы — сколько есть, но никогда сюжет и синопсис,
    /// специально ради интриги (чтобы решение было "по вайбу", а не по пересказу).
    private var teaser: String? {
        let hints = (movie.atmosphere + movie.themes).prefix(4)
        guard !hints.isEmpty else { return nil }
        return hints.joined(separator: " · ")
    }
}
