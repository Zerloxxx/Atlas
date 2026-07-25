import Foundation

@MainActor
final class RecommendationViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([RecommendationResult])
        /// `canRetry == false` — повторять запрос бессмысленно (например, ИИ
        /// отказался отвечать не по теме): не предлагаем кнопку и не тратим токены.
        case failed(message: String, canRetry: Bool)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isLoadingMore = false
    /// Ошибка догрузки "показать ещё" — показывается под кнопкой, не затирая
    /// уже показанную подборку.
    @Published private(set) var loadMoreError: String?

    private let service: AIRecommendationService
    private let watchlist: WatchlistStore
    private let tasteProfile: TasteProfileStore
    private let swipeMatches: SwipeMatchesStore
    private let history: RecommendationHistoryStore
    private let catalog: MovieCatalogProviding
    private var profile: UserPreferenceProfile?
    /// Всё, что уже показали или отклонили в рамках текущей подборки — не повторяем.
    private var seenIds: Set<Int> = []
    /// SwiftUI перезапускает `.task` при каждом появлении вью (например, при
    /// возврате на вкладку после переключения) — без этого флага это заново
    /// дёргало бы ИИ и сбрасывало уже показанную подборку.
    private var hasStartedLoading = false
    /// Один запрос — одна запись в истории, сколько бы раз мы ни догружали
    /// и ни повторяли попытку.
    private var hasLoggedHistory = false

    init(
        service: AIRecommendationService = OpenAIRecommendationService(),
        watchlist: WatchlistStore = .shared,
        tasteProfile: TasteProfileStore = .shared,
        swipeMatches: SwipeMatchesStore = .shared,
        history: RecommendationHistoryStore = .shared,
        catalog: MovieCatalogProviding = MovieCatalogService.shared
    ) {
        self.service = service
        self.watchlist = watchlist
        self.tasteProfile = tasteProfile
        self.swipeMatches = swipeMatches
        self.history = history
        self.catalog = catalog
    }

    func load(profile: UserPreferenceProfile) async {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        self.profile = profile
        seenIds = []
        state = .loading
        await fetch(profile: profile, append: false)
    }

    /// Повторная попытка после ошибки — полноценный новый запрос, а не догрузка,
    /// чтобы экран ошибки гарантированно обновился (успехом или новой ошибкой).
    func retry() async {
        guard let profile, !isLoadingMore else { return }
        state = .loading
        loadMoreError = nil
        await fetch(profile: profile, append: false)
    }

    /// Убирает карточку из выдачи и запоминает как отклонённую — "Показать ещё"
    /// больше её не предложит.
    func dismiss(_ movie: Movie) {
        seenIds.insert(movie.id)
        guard case .loaded(var results) = state else { return }
        results.removeAll { $0.movie.id == movie.id }
        state = results.isEmpty
            ? .failed(message: "Все варианты отклонены. Нажмите «Подобрать заново», чтобы получить новые.", canRetry: true)
            : .loaded(results)
    }

    /// Догружает новые рекомендации, не повторяя уже показанные/отклонённые/сохранённые.
    func loadMore() async {
        guard let profile, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        await fetch(profile: profile, append: true)
        isLoadingMore = false
    }

    private func fetch(profile: UserPreferenceProfile, append: Bool) async {
        do {
            var enrichedProfile = profile
            enrichedProfile.tasteHistorySummary = tasteProfile.summaryForPrompt(catalog: catalog)
            enrichedProfile.swipeLikesSummary = swipeMatches.summaryForPrompt(catalog: catalog)

            let excluded = seenIds
                .union(watchlist.savedMovieIds)
                .union(tasteProfile.ratedMovieIds)
                .union(swipeMatches.likedMovieIds)
            let results = try await service.recommend(for: enrichedProfile, excluding: excluded)
            seenIds.formUnion(results.map { $0.movie.id })

            guard !results.isEmpty else {
                if append {
                    loadMoreError = "Больше подходящих фильмов в базе не нашлось."
                } else {
                    state = .failed(
                        message: "ИИ не нашёл подходящих фильмов в базе под эти ответы. Попробуйте изменить критерии.",
                        canRetry: true
                    )
                }
                return
            }

            // Дозаполняем существующий список, только если он ещё жив (.loaded).
            // Если до этого была ошибка (в том числе "всё отклонили") — начинаем заново.
            if append, case .loaded(let existing) = state {
                // Каталог мог не набрать новых вариантов и вернуть уже показанное —
                // одинаковые id в списке ломают отрисовку, поэтому отсеиваем.
                let existingIds = Set(existing.map(\.id))
                let fresh = results.filter { !existingIds.contains($0.id) }
                if fresh.isEmpty {
                    loadMoreError = "Больше подходящих фильмов в базе не нашлось."
                } else {
                    state = .loaded(existing + fresh)
                }
            } else {
                state = .loaded(results)
                logHistoryIfNeeded(profile: profile, results: results)
            }
        } catch {
            let canRetry: Bool
            if case OpenAIClientError.offTopic = error {
                canRetry = false
            } else {
                canRetry = true
            }

            if append {
                loadMoreError = error.localizedDescription
            } else {
                state = .failed(message: error.localizedDescription, canRetry: canRetry)
            }
        }
    }

    private func logHistoryIfNeeded(profile: UserPreferenceProfile, results: [RecommendationResult]) {
        guard !hasLoggedHistory else { return }
        hasLoggedHistory = true
        let (label, description) = RecommendationHistoryEntry.summarize(profile: profile, catalog: catalog)
        history.addEntry(scenarioLabel: label, queryDescription: description, profile: profile, results: results)
    }
}
