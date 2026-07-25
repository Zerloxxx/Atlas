import SwiftUI

/// Статичный показ уже полученной подборки из истории — без обращения к ИИ,
/// ровно те карточки, что были показаны в тот раз. Плюс разбивка критериев,
/// по которым она была собрана, и возможность пройти сценарий заново
/// с чистого листа или с уже подставленными прошлыми ответами.
struct HistoryDetailView: View {
    let entry: RecommendationHistoryEntry

    private let catalog: MovieCatalogProviding = MovieCatalogService.shared

    private var results: [RecommendationResult] {
        entry.items.compactMap { item in
            catalog.movie(withId: item.movieId).map { movie in
                RecommendationResult(movie: movie, explanation: item.explanation, matchScore: item.matchScore)
            }
        }
    }

    /// Разбивка ответов, которые пользователь дал при сборе этой подборки —
    /// строится локально по сохранённому профилю, отдельно для каждого сценария.
    private var criteriaRows: [(label: String, value: String)] {
        let profile = entry.profile
        switch profile.source {
        case .quickPick:
            var rows: [(String, String)] = []
            if !profile.genres.isEmpty { rows.append(("Жанр", profile.genres.joined(separator: ", "))) }
            if !profile.importantAspects.isEmpty { rows.append(("Важно", profile.importantAspects.joined(separator: ", "))) }
            if !profile.mood.isEmpty { rows.append(("Настроение", profile.mood.joined(separator: ", "))) }
            if let duration = profile.durationPreference { rows.append(("Длительность", duration)) }
            if !profile.excludedGenres.isEmpty { rows.append(("Не хочу", profile.excludedGenres.joined(separator: ", "))) }
            return rows

        case .movieBased(let referenceMovieId):
            var rows: [(String, String)] = []
            rows.append(("Фильм", catalog.movie(withId: referenceMovieId)?.title ?? "—"))
            if !profile.likedAspects.isEmpty { rows.append(("Понравилось", profile.likedAspects.joined(separator: ", "))) }
            if !profile.likedActors.isEmpty { rows.append(("Актёры", profile.likedActors.joined(separator: ", "))) }
            if !profile.likedPlotFeatures.isEmpty { rows.append(("Сюжет", profile.likedPlotFeatures.joined(separator: ", "))) }
            if !profile.likedAtmosphere.isEmpty { rows.append(("Атмосфера", profile.likedAtmosphere.joined(separator: ", "))) }
            if !profile.wantsToChange.isEmpty { rows.append(("Изменить", profile.wantsToChange.joined(separator: ", "))) }
            return rows

        case .chat:
            return [("Запрос", profile.freeTextQuery ?? "—")]

        case .together:
            var rows: [(String, String)] = []
            for (index, participant) in profile.togetherParticipants.enumerated() {
                if !participant.genres.isEmpty { rows.append(("Человек \(index + 1): жанр", participant.genres.joined(separator: ", "))) }
                if !participant.mood.isEmpty { rows.append(("Человек \(index + 1): настроение", participant.mood.joined(separator: ", "))) }
            }
            return rows

        case .swipeMatch(let likedMovieIds):
            let titles = likedMovieIds.compactMap { catalog.movie(withId: $0)?.title }
            return [("Понравившиеся фильмы", titles.isEmpty ? "—" : titles.joined(separator: ", "))]
        }
    }

    /// "Изменить ответы" не имеет смысла для Мэтчей — там нет анкеты, есть свайпы.
    private var showsEditAction: Bool {
        if case .swipeMatch = entry.profile.source { return false }
        return true
    }

    /// Для сценария "по фильму" повтор возможен только если исходный фильм всё ещё в каталоге.
    private var canRestartScenario: Bool {
        if case .movieBased(let referenceMovieId) = entry.profile.source {
            return catalog.movie(withId: referenceMovieId) != nil
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Layout.spacing * 1.5) {
                if !criteriaRows.isEmpty {
                    criteriaCard
                }

                if canRestartScenario {
                    actionButtons
                }

                ForEach(results) { result in
                    MovieCardView(
                        movie: result.movie,
                        explanation: result.explanation,
                        matchScore: result.matchScore,
                        style: .full
                    )
                }
            }
            .padding(AppTheme.Layout.padding)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(entry.scenarioLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var criteriaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ваши критерии")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(criteriaRows, id: \.label) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text(row.value)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Layout.padding)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            NavigationLink {
                restartDestination
            } label: {
                Text("Пройти ещё раз")
            }
            .buttonStyle(.primaryGradient)

            if showsEditAction {
                NavigationLink {
                    editDestination
                } label: {
                    Text("Изменить ответы")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private var restartDestination: some View {
        switch entry.profile.source {
        case .quickPick:
            QuickPickFlowView()
        case .movieBased(let referenceMovieId):
            if let movie = catalog.movie(withId: referenceMovieId) {
                MovieBasedSurveyView(referenceMovie: movie)
            }
        case .chat:
            ChatView()
        case .together:
            TogetherFlowView()
        case .swipeMatch:
            SwipeDiscoveryView()
        }
    }

    @ViewBuilder
    private var editDestination: some View {
        switch entry.profile.source {
        case .quickPick:
            QuickPickFlowView(initialProfile: entry.profile)
        case .movieBased(let referenceMovieId):
            if let movie = catalog.movie(withId: referenceMovieId) {
                MovieBasedSurveyView(referenceMovie: movie, initialProfile: entry.profile)
            }
        case .chat:
            ChatView(initialText: entry.profile.freeTextQuery ?? "")
        case .together:
            TogetherFlowView(initialProfile: entry.profile)
        case .swipeMatch:
            EmptyView()
        }
    }
}
