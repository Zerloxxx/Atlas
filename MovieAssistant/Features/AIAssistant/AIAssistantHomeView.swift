import SwiftUI

/// Точка входа в Атлас — выбор одного из сценариев подбора фильма.
struct AIAssistantHomeView: View {
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared
    @ObservedObject private var history = RecommendationHistoryStore.shared

    /// Последняя подборка, если она свежая — к ней предлагаем вернуться вместо
    /// повторного прохождения опроса. Дальше недели это уже не "продолжить",
    /// а обычная история, за ней — иконка часов в шапке.
    private var resumableEntry: RecommendationHistoryEntry? {
        guard let last = history.entries.first else { return nil }
        guard Date().timeIntervalSince(last.date) < 7 * 24 * 60 * 60 else { return nil }
        return last
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
                if let resumableEntry {
                    NavigationLink {
                        HistoryDetailView(entry: resumableEntry)
                    } label: {
                        resumeCard(resumableEntry)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    QuickPickFlowView()
                } label: {
                    ScenarioCard(
                        title: "Быстрый подбор",
                        subtitle: "Не знаю, что хочу посмотреть — задайте пару вопросов"
                    ) {
                        quickPickIcon
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MovieBasedPickerView()
                } label: {
                    ScenarioCard(
                        title: "Подбор по понравившемуся фильму",
                        subtitle: "Выберу фильм, который понравился, и найдите похожий"
                    ) {
                        posterCollageIcon
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ChatView()
                } label: {
                    ScenarioCard(
                        title: "AI Chat",
                        subtitle: "Уже знаю, что хочу — просто напишу сообщение"
                    ) {
                        chatBubblesIcon
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TogetherFlowView()
                } label: {
                    ScenarioCard(
                        title: "Смотрим вместе",
                        subtitle: "Учтём вкусы всей компании и найдём компромисс"
                    ) {
                        togetherIcon
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(AppTheme.Layout.padding)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Layout.padding)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(AppTheme.Colors.background)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movie: movie)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Подберём фильм вместе")
                    .font(AppTheme.Typography.largeTitle)
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Выберите, как удобнее начать")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer(minLength: 8)

            NavigationLink {
                HistoryView()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.surfaceElevated)
                    .clipShape(Circle())
            }
            .padding(.top, 4)
        }
    }

    /// Ключевой сценарий из кейса: человек уже подобрал фильмы, отвлёкся и вышел,
    /// так и не начав смотреть. Чтобы вернуться, ему не нужно заново отвечать на
    /// вопросы — подборка сохранена, открываем её как есть.
    private func resumeCard(_ entry: RecommendationHistoryEntry) -> some View {
        HStack(spacing: AppTheme.Layout.spacing) {
            Image(systemName: "arrow.trianglehead.clockwise")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Продолжить выбор")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("\(entry.scenarioLabel) · \(entry.date.ruRelative)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                Text("\(entry.items.count) фильмов уже подобрано — не нужно отвечать заново")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Layout.padding)
        .background(AppTheme.Colors.accent.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                .stroke(AppTheme.Colors.accent.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
    }

    /// Настоящий эмодзи — у Apple он уже цветной/объёмный из коробки,
    /// рисовать самим ничего не нужно.
    private var quickPickIcon: some View {
        Text("🪄")
            .font(.system(size: 40))
            .frame(width: 52, height: 52)
    }

    private var chatBubblesIcon: some View {
        Text("💬")
            .font(.system(size: 42))
            .frame(width: 52, height: 52)
    }

    private var togetherIcon: some View {
        Text("🤝")
            .font(.system(size: 38))
            .frame(width: 52, height: 52)
    }

    /// Коллаж из двух постеров + сердечко — для сценария "по понравившемуся фильму".
    private var posterCollageIcon: some View {
        let movies = catalog.allMovies()
        let left = movies.first(where: { $0.id == 6 }) ?? movies[0]
        let right = movies.first(where: { $0.id == 9 }) ?? movies[min(1, movies.count - 1)]

        return ZStack(alignment: .topTrailing) {
            ZStack {
                PosterImageView(movieId: left.id)
                    .frame(width: 34, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .rotationEffect(.degrees(-8))
                    .offset(x: -9)

                PosterImageView(movieId: right.id)
                    .frame(width: 34, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .rotationEffect(.degrees(8))
                    .offset(x: 9)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: -2, y: 2)
            }
            .frame(width: 52, height: 52)

            Image(systemName: "heart.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(5)
                .background(AppTheme.Colors.accentGradient)
                .clipShape(Circle())
                .offset(x: 4, y: -4)
        }
        .frame(width: 52, height: 52)
    }
}

private struct ScenarioCard<Icon: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacing) {
            icon

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Layout.padding)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
    }
}

#Preview {
    NavigationStack {
        AIAssistantHomeView()
    }
}
