import SwiftUI

/// Точка входа в Атлас — выбор одного из сценариев подбора фильма.
struct AIAssistantHomeView: View {
    private let catalog: MovieCatalogProviding = MovieCatalogService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
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
