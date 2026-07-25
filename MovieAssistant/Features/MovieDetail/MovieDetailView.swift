import SwiftUI

/// Локальный файл трейлера в бандле (Resources/Trailers/trailer_<id>.mp4) —
/// встроенный YouTube-плеер уперся в анти-бот защиту самого YouTube (не
/// обходится ни правильным iframe, ни User-Agent, ни на реальном устройстве),
/// поэтому вместо стриминга используем реальный файл, как и с постерами/кадрами.
/// Видео теперь показывается первой страницей в MovieStillsCarouselView, а не
/// отдельным окном.
enum TrailerLoader {
    static func url(for movieId: Int) -> URL? {
        Bundle.main.url(forResource: "trailer_\(movieId)", withExtension: "mp4")
    }
}

struct MovieDetailView: View {
    let movie: Movie

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var tasteProfile = TasteProfileStore.shared
    @State private var placeholderMessage: String?
    @State private var showPostWatchSurvey = false
    @State private var scrollOffsetY: CGFloat = 0

    /// 0 — заголовка в шапке не видно (вверху экрана), 1 — виден полностью
    /// (постер укатился вверх). Плавный переход между порогами.
    private var titleRevealProgress: Double {
        let fadeStart: CGFloat = 190
        let fadeEnd: CGFloat = 300
        let progress = (scrollOffsetY - fadeStart) / (fadeEnd - fadeStart)
        return Double(min(max(progress, 0), 1))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage

                detailContent
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollOffsetY = newValue
        }
        // Шапка — своя строка со сплошным фоном над картинкой, не поверх нее.
        .safeAreaInset(edge: .top, spacing: 0) {
            headerBar
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert(
            "Демо-версия",
            isPresented: Binding(
                get: { placeholderMessage != nil },
                set: { if !$0 { placeholderMessage = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(placeholderMessage ?? "")
        }
        .sheet(isPresented: $showPostWatchSurvey) {
            PostWatchSurveyView(movie: movie)
        }
    }

    private var headerBar: some View {
        ZStack {
            Text(movie.title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 56)
                .opacity(titleRevealProgress)

            HStack {
                circleButton(icon: "chevron.left") { dismiss() }
                Spacer()
                ShareLink(item: movie.title) {
                    circleIcon("square.and.arrow.up")
                }
            }
        }
        .padding(.horizontal, AppTheme.Layout.padding)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.background)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
            // showsPoster: false — постер уже показан выше отдельным hero-баннером,
            // повторять его первой страницей карусели незачем.
            MovieStillsCarouselView(movieId: movie.id, showsPoster: false)
            titleBlock
            ctaRow
            iconRow

            section(title: "О фильме") {
                Text(movie.synopsis)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.9))
            }

            section(title: "Режиссёр") {
                Text(movie.director)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.9))
            }

            section(title: "В ролях") {
                tagCloud(movie.actors)
            }

            if !movie.themes.isEmpty {
                section(title: "Темы") {
                    tagCloud(movie.themes)
                }
            }

            if !movie.atmosphere.isEmpty {
                section(title: "Атмосфера") {
                    tagCloud(movie.atmosphere)
                }
            }
        }
        .padding(AppTheme.Layout.padding)
    }

    private var heroImage: some View {
        PosterImageView(movieId: movie.id)
            .frame(height: 440)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, AppTheme.Colors.background],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(movie.title.uppercased())
                .font(.system(size: 26, weight: .black))
                .tracking(-0.5)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            HStack(spacing: 10) {
                Text(String(format: "%.1f", movie.rating))
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.ratingColor(for: movie.rating))
                Text(String(movie.year))
                Text(movie.genresLabel)
                    .lineLimit(1)
                Text(movie.durationLabel)
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)

            Text("\(movie.ageRating) · Режиссёр: \(movie.director)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var ctaRow: some View {
        HStack(spacing: 12) {
            Button {
                showPostWatchSurvey = true
            } label: {
                Label("Смотреть фильм", systemImage: "play.fill")
            }
            .buttonStyle(.primaryGradient)

            // С подписью, а не голая иконка: иначе непонятно, что это вход
            // в AI-подбор похожего именно на этот фильм.
            NavigationLink {
                MovieBasedSurveyView(referenceMovie: movie)
            } label: {
                Label("Похожее", systemImage: "sparkles")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(AppTheme.Colors.accentGradient)
                    .clipShape(Capsule())
            }
        }
    }

    private var iconRow: some View {
        HStack {
            Button {
                showPostWatchSurvey = true
            } label: {
                iconActionLabel(
                    icon: tasteProfile.hasRated(movie.id) ? "star.fill" : "star",
                    label: tasteProfile.hasRated(movie.id) ? "Оценено" : "Оценить",
                    tinted: tasteProfile.hasRated(movie.id)
                )
            }
            Spacer()
            Button {
                watchlist.toggle(movie.id)
            } label: {
                iconActionLabel(
                    icon: watchlist.isSaved(movie.id) ? "bookmark.fill" : "bookmark",
                    label: "Буду смотреть",
                    tinted: watchlist.isSaved(movie.id)
                )
            }
            Spacer()
            ShareLink(item: movie.title) {
                iconActionLabel(icon: "arrowshape.turn.up.right", label: "Поделиться")
            }
            Spacer()
            Button {
                placeholderMessage = "Дополнительные действия доступны в реальном сервисе."
            } label: {
                iconActionLabel(icon: "ellipsis", label: "Ещё")
            }
        }
    }

    private func iconActionLabel(icon: String, label: String, tinted: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(tinted ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circleIcon(icon)
        }
    }

    private func circleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .frame(width: 36, height: 36)
            .background(AppTheme.Colors.surfaceElevated)
            .clipShape(Circle())
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            content()
        }
    }

    private func tagCloud(_ items: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surfaceElevated)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: Movie(
                id: 1, title: "Интерстеллар", year: 2014, genres: ["Фантастика", "Драма"],
                director: "Кристофер Нолан", actors: ["Matthew McConaughey", "Anne Hathaway"],
                synopsis: "Группа исследователей отправляется через червоточину в поисках нового дома для человечества.",
                hook: "", themes: ["Космос", "Время"], atmosphere: ["Напряжённая", "Философская"], plotFeatures: [],
                durationMinutes: 169, ageRating: "12+", endingType: "философская", rating: 8.6
            )
        )
    }
}
