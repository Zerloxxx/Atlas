import SwiftUI

/// Общий экран результатов для всех сценариев — принимает уже собранный
/// профиль предпочтений, откуда бы он ни пришёл.
struct RecommendationResultsView: View {
    let profile: UserPreferenceProfile

    @StateObject private var viewModel = RecommendationViewModel()

    /// Режим "выбрать несколько" для рандомайзера — тап по карточке тогда
    /// не открывает "Смотреть"/детали, а отмечает выбор.
    @State private var isSelecting = false
    @State private var selectedForRandom: Set<Int> = []
    /// Показ рандомайзера завязан на этот optional, а не на isPresented+отдельный
    /// state — так кандидаты гарантированно приходят вместе с показом, без гонки.
    @State private var randomPickerRequest: RandomPickerRequest?
    /// Фильм, выбранный рулеткой — по "Готово" рулетка закрывается и сразу
    /// открывается его детальная страница.
    @State private var pendingRandomWinner: Movie?

    private var isShowingRandomWinner: Binding<Bool> {
        Binding(
            get: { pendingRandomWinner != nil },
            set: { if !$0 { pendingRandomWinner = nil } }
        )
    }

    var body: some View {
        ScrollView {
            content
                .padding(AppTheme.Layout.padding)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Подборка для вас")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .loaded(let results) = viewModel.state, results.count >= 2 {
                    // "Выбрать" без объекта было непонятно ("выбрать что?") —
                    // называем прямо, что это вход в рандомайзер.
                    Button(isSelecting ? "Готово" : "Рандом") {
                        isSelecting.toggle()
                        if !isSelecting { selectedForRandom.removeAll() }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isSelecting && selectedForRandom.count >= 2 {
                randomButton
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedForRandom.count)
        .navigationDestination(isPresented: isShowingRandomWinner) {
            if let pendingRandomWinner {
                MovieDetailView(movie: pendingRandomWinner)
            }
        }
        .fullScreenCover(item: $randomPickerRequest) { request in
            RandomPickerView(candidates: request.candidates, scores: request.scores) { movie in
                randomPickerRequest = nil
                pendingRandomWinner = movie
            }
        }
        .task {
            await viewModel.load(profile: profile)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingView
        case .loaded(let results):
            VStack(spacing: AppTheme.Layout.spacing * 1.5) {
                if isSelecting {
                    selectionHint
                }

                ForEach(results) { result in
                    resultCard(result)
                }

                loadMoreButton

                if let loadMoreError = viewModel.loadMoreError {
                    Text(loadMoreError)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Место под плавающую кнопку рандомайзера, чтобы не перекрывала последнюю карточку.
                if isSelecting && selectedForRandom.count >= 2 {
                    Color.clear.frame(height: 60)
                }
            }
        case .failed(let message, let canRetry):
            errorView(message: message, canRetry: canRetry)
        }
    }

    @ViewBuilder
    private func resultCard(_ result: RecommendationResult) -> some View {
        ZStack(alignment: .topLeading) {
            MovieCardView(
                movie: result.movie,
                explanation: result.explanation,
                matchScore: result.matchScore,
                style: .full,
                onDismiss: isSelecting ? nil : { viewModel.dismiss(result.movie) }
            )

            if isSelecting {
                // Прозрачный перехватчик тапа поверх всей карточки — в режиме выбора
                // тап отмечает фильм, а не открывает "Смотреть"/детали под ним.
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleSelection(result.movie.id) }
                selectionBadge(isSelected: selectedForRandom.contains(result.movie.id))
                    .padding(10)
            }
        }
        .opacity(!isSelecting || selectedForRandom.isEmpty || selectedForRandom.contains(result.movie.id) ? 1 : 0.55)
    }

    private func selectionBadge(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(isSelected ? AppTheme.Colors.accent : .white)
            .background(Circle().fill(.black.opacity(0.45)).padding(-1))
    }

    private var selectionHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "shuffle")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.Colors.accent)
            Text("Отметьте 2+ фильма — я крутну рулетку и выберу один за вас (шанс выше у большего % совпадения).")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(AppTheme.Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
    }

    private func toggleSelection(_ movieId: Int) {
        if selectedForRandom.contains(movieId) {
            selectedForRandom.remove(movieId)
        } else {
            selectedForRandom.insert(movieId)
        }
    }

    /// Взвешено по matchScore — тут, в отличие от Мэтчей, есть реальное число
    /// совпадения, так что равный шанс всем был бы игнорированием этих данных.
    private var randomButton: some View {
        Button {
            guard case .loaded(let results) = viewModel.state else { return }
            let selectedResults = results.filter { selectedForRandom.contains($0.movie.id) }
            let scores = Dictionary(uniqueKeysWithValues: selectedResults.map { ($0.movie.id, $0.matchScore) })
            randomPickerRequest = RandomPickerRequest(candidates: selectedResults.map(\.movie), scores: scores)
        } label: {
            Label("Выбери за меня (\(selectedForRandom.count))", systemImage: "shuffle")
        }
        .buttonStyle(.primaryGradient)
        .padding(.horizontal, AppTheme.Layout.padding)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var loadMoreButton: some View {
        Button {
            Task { await viewModel.loadMore() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.isLoadingMore ? "Ищём ещё…" : "Не то — показать ещё")
            }
        }
        .buttonStyle(.primaryGradient)
        .disabled(viewModel.isLoadingMore)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppTheme.Colors.accent)
            Text("ИИ подбирает фильмы под ваши ответы…")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    /// Для отказа "не по теме" кнопки повтора нет: тот же запрос даст тот же
    /// ответ и будет стоить ещё одного обращения к ИИ.
    private func errorView(message: String, canRetry: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: canRetry ? "exclamationmark.triangle" : "film")
                .font(.system(size: 32))
                .foregroundStyle(canRetry ? AppTheme.Colors.warning : AppTheme.Colors.accent)
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            if canRetry {
                Button("Подобрать заново") {
                    Task { await viewModel.retry() }
                }
                .buttonStyle(.primaryGradient)
                .frame(maxWidth: 220)
            } else {
                Text("Вернитесь назад и опишите, что хотите посмотреть.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
