import SwiftUI

/// Тиндер-подобный подбор: свайп вправо — нравится, влево — мимо.
/// В конце колоды — итог с лайкнутыми и кнопкой "предложи похожее" (уходит
/// в общий AI-пайплайн через новый сценарий .swipeMatch).
struct SwipeDiscoveryView: View {
    let genre: String?
    @StateObject private var viewModel: SwipeDiscoveryViewModel
    @State private var dragOffset: CGSize = .zero
    /// Пока карточка улетает, повторные нажатия игнорируем — иначе быстрый
    /// двойной тап пролистывал бы сразу две карточки.
    @State private var isCommitting = false

    private let swipeThreshold: CGFloat = 110

    init(genre: String? = nil) {
        self.genre = genre
        _viewModel = StateObject(wrappedValue: SwipeDiscoveryViewModel(genre: genre))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isFinished {
                summaryView
            } else {
                cardStack
                actionButtons
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(genre.map { "Смахни: \($0)" } ?? "Смахни фильм")
        .navigationBarTitleDisplayMode(.inline)
        // Тап по фильму ведёт в MovieDetailView через navigationDestination(for: Movie.self),
        // объявленный в корне стека (SwipeMatchesView или AIAssistantHomeView) — свой
        // здесь заводить нельзя: два обработчика одного типа в одном NavigationStack
        // путают back-stack (показывает не тот фильм, лишний шаг в "назад").
        .navigationDestination(isPresented: isShowingResults) {
            RecommendationResultsView(profile: viewModel.pendingProfile ?? UserPreferenceProfile(source: .swipeMatch(likedMovieIds: [])))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.undoLastSwipe()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .disabled(!viewModel.canUndo)
            }
        }
    }

    private var isShowingResults: Binding<Bool> {
        Binding(
            get: { viewModel.pendingProfile != nil },
            set: { newValue in if !newValue { viewModel.pendingProfile = nil } }
        )
    }

    // MARK: - Card stack

    private var cardStack: some View {
        ZStack {
            if let nextCard = viewModel.nextCard {
                SwipeCardView(movie: nextCard)
                    .scaleEffect(0.94)
                    .offset(y: 10)
                    .opacity(0.6)
            }
            if let currentCard = viewModel.currentCard {
                SwipeCardView(movie: currentCard)
                    .overlay(alignment: .topLeading) {
                        stamp(text: "НРАВИТСЯ", color: AppTheme.Colors.success, opacity: likeOpacity)
                    }
                    .overlay(alignment: .topTrailing) {
                        stamp(text: "МИМО", color: AppTheme.Colors.accentSecondary, opacity: dislikeOpacity)
                    }
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                    .gesture(dragGesture(for: currentCard))
                    .id(currentCard.id)
            }
        }
        .animation(.interactiveSpring(), value: dragOffset)
        .padding(AppTheme.Layout.padding)
        .frame(maxHeight: .infinity)
    }

    private func dragGesture(for movie: Movie) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isCommitting else { return }
                // Карточка свайпается влево/вправо — вертикальную составляющую
                // сильно гасим, а не убираем совсем, чтобы жест всё равно
                // ощущался живым, но не давал утащить карточку вверх/вниз.
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.15)
            }
            .onEnded { value in
                guard !isCommitting else { return }
                if value.translation.width > swipeThreshold {
                    commit(liked: true, movie: movie)
                } else if value.translation.width < -swipeThreshold {
                    commit(liked: false, movie: movie)
                } else {
                    withAnimation(.spring()) { dragOffset = .zero }
                }
            }
    }

    private func commit(liked: Bool, movie: Movie) {
        guard !isCommitting else { return }
        isCommitting = true
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: liked ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if liked {
                viewModel.like(movie)
            } else {
                viewModel.dislike(movie)
            }
            dragOffset = .zero
            isCommitting = false
        }
    }

    private var likeOpacity: Double {
        dragOffset.width > 0 ? min(Double(dragOffset.width / swipeThreshold), 1) : 0
    }

    private var dislikeOpacity: Double {
        dragOffset.width < 0 ? min(Double(-dragOffset.width / swipeThreshold), 1) : 0
    }

    private func stamp(text: String, color: Color, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 2))
            .rotationEffect(.degrees(-12))
            .opacity(opacity)
            .padding(20)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 40) {
            Button {
                if let movie = viewModel.currentCard {
                    commit(liked: false, movie: movie)
                }
            } label: {
                actionButtonLabel(icon: "xmark", label: "Мимо", color: AppTheme.Colors.accentSecondary)
            }

            Button {
                if let movie = viewModel.currentCard {
                    commit(liked: true, movie: movie)
                }
            } label: {
                actionButtonLabel(icon: "heart.fill", label: "Нравится", color: AppTheme.Colors.success)
            }
        }
        .padding(.bottom, 24)
    }

    /// Раньше кнопки были голыми кружками — без подписи было непонятно,
    /// какая из них "не нравится", а какая "нравится".
    private func actionButtonLabel(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 60, height: 60)
                .background(AppTheme.Colors.surface)
                .clipShape(Circle())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Summary

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: AppTheme.Layout.spacing * 1.5) {
                if viewModel.isRecycledDeck && !viewModel.deck.isEmpty {
                    Text("Новых фильмов в этой категории не осталось — показали те, что вы раньше пролистали.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.likedMovies.isEmpty {
                    emptySummary
                } else {
                    Text("Понравилось")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        ForEach(viewModel.likedMovies) { movie in
                            NavigationLink(value: movie) {
                                VStack(alignment: .leading, spacing: 4) {
                                    PosterImageView(movieId: movie.id)
                                        .frame(height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
                                    Text(movie.title)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        viewModel.requestSimilar()
                    } label: {
                        Label("Предложи что-то похожее", systemImage: "sparkles")
                    }
                    .buttonStyle(.primaryGradient)
                }

                Button("Новая подборка") {
                    viewModel.restart()
                }
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.top, 4)

                if viewModel.deck.isEmpty {
                    Button("Показать пролистанные заново") {
                        viewModel.resetSkipped()
                    }
                    .foregroundStyle(AppTheme.Colors.accent)
                }
            }
            .padding(AppTheme.Layout.padding)
        }
    }

    private var emptySummary: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(viewModel.deck.isEmpty ? emptyDeckMessage : "Ничего не зацепило")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Попробуйте другую подборку")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 60)
    }

    private var emptyDeckMessage: String {
        if let genre {
            return "Новых фильмов в категории «\(genre)» не осталось"
        }
        return "Новых фильмов для подборки не осталось"
    }
}

#Preview {
    NavigationStack {
        SwipeDiscoveryView()
    }
}
