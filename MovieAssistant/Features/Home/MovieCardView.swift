import SwiftUI

/// Переиспользуемая карточка фильма.
/// `.grid` — компактная карточка для сетки каталога.
/// `.full` — широкая карточка с объяснением для экрана рекомендаций.
struct MovieCardView: View {
    enum Style {
        case grid
        case full
        case shelf
    }

    let movie: Movie
    var explanation: String? = nil
    /// 0-100, показывается бейджем на карточке `.full`, если передан.
    var matchScore: Int? = nil
    var style: Style = .grid
    /// Если передан — на карточке `.full` появляется крестик "не то", отклоняющий рекомендацию.
    var onDismiss: (() -> Void)? = nil

    @State private var showPostWatchSurvey = false
    @ObservedObject private var watchlist = WatchlistStore.shared

    var body: some View {
        switch style {
        case .grid:
            gridBody
        case .full:
            fullBody
        case .shelf:
            shelfBody
        }
    }

    private var gridBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster(height: 180)
            Text(movie.title)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.Colors.warning)
                Text(String(format: "%.1f", movie.rating))
                Text("· \(movie.year)")
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    /// Есть ли кадры/трейлер для листающейся карусели — иначе используем
    /// обычный статичный постер во всю ширину карточки как запасной вариант.
    private var hasMedia: Bool {
        !MovieStillsLoader.images(for: movie.id).isEmpty || TrailerLoader.url(for: movie.id) != nil
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacing) {
            Group {
                if hasMedia {
                    MovieStillsCarouselView(movieId: movie.id, showsHeading: false, fixedHeight: 200)
                } else {
                    poster(height: 200)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("\(String(movie.year)) · \(movie.genresLabel)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label(String(format: "%.1f", movie.rating), systemImage: "star.fill")
                        Label(movie.durationLabel, systemImage: "clock")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer(minLength: 4)
                if let matchScore {
                    matchScoreBadge(matchScore)
                }
            }

            if let explanation {
                Text(explanation)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.85))
                    .padding(AppTheme.Layout.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
            }

            HStack(spacing: 10) {
                Button {
                    showPostWatchSurvey = true
                } label: {
                    Label("Смотреть", systemImage: "play.fill")
                }
                .buttonStyle(.primaryGradient)

                // Сохранить прямо из подборки — иначе понравившуюся рекомендацию
                // некуда деть, кроме как посмотреть прямо сейчас.
                Button {
                    watchlist.toggle(movie.id)
                } label: {
                    Image(systemName: watchlist.isSaved(movie.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(watchlist.isSaved(movie.id) ? .white : AppTheme.Colors.textPrimary)
                        .frame(width: 46, height: 46)
                        .background(
                            watchlist.isSaved(movie.id)
                                ? AnyShapeStyle(AppTheme.Colors.accentGradient)
                                : AnyShapeStyle(AppTheme.Colors.surfaceElevated)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                NavigationLink(value: movie) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.Colors.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.Layout.padding)
        .background(AppTheme.Colors.surface)
        .overlay(alignment: .topTrailing) {
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(7)
                        .background(AppTheme.Colors.surfaceElevated)
                        .clipShape(Circle())
                }
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
        .sheet(isPresented: $showPostWatchSurvey) {
            PostWatchSurveyView(movie: movie)
        }
    }

    /// Компактная карточка для горизонтальных полок каталога (в духе Кинопоиска):
    /// постер во весь размер + бейдж рейтинга поверх, название под постером.
    private var shelfBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster(width: 128, height: 188)
                .overlay(alignment: .topLeading) {
                    ratingBadge.padding(6)
                }
            Text(movie.title)
                .font(AppTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 128, alignment: .leading)
        }
    }

    private var ratingBadge: some View {
        Text(String(format: "%.1f", movie.rating))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppTheme.Colors.ratingColor(for: movie.rating))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func matchScoreBadge(_ score: Int) -> some View {
        Text("\(score)%")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.Colors.accentGradient)
            .clipShape(Capsule())
            .fixedSize()
    }

    private func poster(width: CGFloat? = nil, height: CGFloat) -> some View {
        PosterImageView(movieId: movie.id)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
    }
}

#Preview {
    ScrollView {
        MovieCardView(
            movie: Movie(
                id: 1, title: "Интерстеллар", year: 2014, genres: ["Фантастика", "Драма"],
                director: "Кристофер Нолан", actors: ["Matthew McConaughey"],
                synopsis: "", hook: "", themes: [], atmosphere: [], plotFeatures: [],
                durationMinutes: 169, ageRating: "12+", endingType: "философская", rating: 8.6
            ),
            explanation: "Рекомендуем, потому что вы отметили интерес к теме времени и напряжённую атмосферу.",
            matchScore: 94,
            style: .full,
            onDismiss: {}
        )
        .padding()
    }
    .background(AppTheme.Colors.background)
}
