import SwiftUI

/// Большой промо-баннер на главном экране (в духе Кинопоиска) — карусель
/// с постером на весь экран, кратким описанием и CTA поверх изображения.
///
/// Специально не используется `TabView(.page)` — вложенный в вертикальный
/// `ScrollView`, он на реальном устройстве иначе считает ширину страницы,
/// чем в симуляторе, и обрезает контент. Вместо этого — нативный паджинг
/// через `scrollTargetBehavior`, который для этого и предназначен.
struct HeroCarouselView: View {
    let movies: [Movie]

    @State private var currentId: Int?
    @State private var placeholderMessage: String?
    @ObservedObject private var watchlist = WatchlistStore.shared

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(movies) { movie in
                        NavigationLink(value: movie) {
                            slide(for: movie)
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal)
                        .id(movie.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentId)
            .scrollIndicators(.hidden)
            .frame(height: 500)

            pageDots
        }
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
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(movies) { movie in
                Circle()
                    .fill(
                        movie.id == (currentId ?? movies.first?.id)
                            ? AppTheme.Colors.accent
                            : AppTheme.Colors.textSecondary.opacity(0.4)
                    )
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func slide(for movie: Movie) -> some View {
        ZStack(alignment: .bottomLeading) {
            PosterImageView(movieId: movie.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .clear, AppTheme.Colors.background.opacity(0.85), AppTheme.Colors.background],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("КИНОТЕАТР")
                    .font(.system(size: 12, weight: .black))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(movie.title.uppercased())
                    .font(.system(size: 30, weight: .black))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                    Text("Топ-10 · \(movie.genresLabel)")
                        .font(AppTheme.Typography.caption)
                }
                .foregroundStyle(AppTheme.Colors.accent)

                Text(movie.synopsis)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.85))
                    .lineLimit(2)

                HStack(spacing: 12) {
                    // Не Button — тап проваливается на внешний NavigationLink
                    // всего слайда, ведущий на страницу фильма.
                    Label("Смотреть", systemImage: "play.fill")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 22)
                        .background(AppTheme.Colors.accentGradient)
                        .clipShape(Capsule())

                    circleButton(
                        icon: watchlist.isSaved(movie.id) ? "bookmark.fill" : "bookmark",
                        tinted: watchlist.isSaved(movie.id)
                    ) {
                        watchlist.toggle(movie.id)
                    }
                    circleButton(icon: "minus") {
                        placeholderMessage = "Скрытие рекомендаций доступно в реальном сервисе."
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, AppTheme.Layout.padding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func circleButton(icon: String, tinted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(tinted ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(AppTheme.Colors.surfaceElevated))
                .clipShape(Circle())
        }
    }
}
