import SwiftUI

/// Мини-опрос "как вам фильм?" — показывается вместо плеера (которого в прототипе
/// нет) сразу после тапа "Смотреть". Ответы уходят в TasteProfileStore и потом
/// подмешиваются в промпт ИИ на будущих запросах — эмулируем цикл персонализации,
/// который в реальном сервисе запускался бы после настоящего завершения просмотра.
struct PostWatchSurveyView: View {
    let movie: Movie

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tasteProfile = TasteProfileStore.shared

    @State private var rating: Int
    @State private var likedTags: Set<String>
    @State private var watchedFully: Bool?

    private let tagOptions = ["Сюжет", "Атмосфера", "Актёры", "Экшен", "Визуальная часть", "Концовка"]

    /// Если фильм уже оценивали — показываем прошлый ответ, а не пустую форму:
    /// иначе повторное открытие молча затирало бы предыдущую оценку.
    init(movie: Movie) {
        self.movie = movie
        let previous = TasteProfileStore.shared.rating(for: movie.id)
        _rating = State(initialValue: previous?.rating ?? 0)
        _likedTags = State(initialValue: Set(previous?.likedTags ?? []))
        _watchedFully = State(initialValue: previous?.watchedFully)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
                    header
                    starRatingSection

                    if rating > 0 {
                        tagsSection
                        watchedFullySection
                    }
                }
                .padding(AppTheme.Layout.padding)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                submitButton
                    .padding(.horizontal, AppTheme.Layout.padding)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(AppTheme.Colors.background)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Пропустить") { dismiss() }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Как вам фильм?")
                .font(AppTheme.Typography.largeTitle)
                .tracking(-0.5)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("«\(movie.title)» — в демо плеера нет, поэтому спрашиваем сразу. Ответ поможет ИИ рекомендовать точнее в следующий раз.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var starRatingSection: some View {
        HStack(spacing: 14) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { rating = star }
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 30))
                        .foregroundStyle(star <= rating ? AppTheme.Colors.warning : AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Что понравилось?")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            FlowLayout(spacing: 8) {
                ForEach(tagOptions, id: \.self) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let isSelected = likedTags.contains(tag)
        return Button {
            if isSelected { likedTags.remove(tag) } else { likedTags.insert(tag) }
        } label: {
            Text(tag)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(AppTheme.Colors.surfaceElevated))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var watchedFullySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Досмотрели до конца?")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            HStack(spacing: 12) {
                watchedOption("Да", value: true)
                watchedOption("Нет", value: false)
            }
        }
    }

    private func watchedOption(_ label: String, value: Bool) -> some View {
        let isSelected = watchedFully == value
        return Button {
            watchedFully = value
        } label: {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? AnyShapeStyle(AppTheme.Colors.accentGradient) : AnyShapeStyle(AppTheme.Colors.surfaceElevated))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button {
            tasteProfile.addRating(
                movieId: movie.id,
                rating: rating,
                likedTags: Array(likedTags),
                watchedFully: watchedFully
            )
            dismiss()
        } label: {
            Text("Отправить")
        }
        .buttonStyle(.primaryGradient)
        .disabled(rating == 0)
    }
}

#Preview {
    PostWatchSurveyView(
        movie: Movie(
            id: 1, title: "Интерстеллар", year: 2014, genres: ["Фантастика", "Драма"],
            director: "Кристофер Нолан", actors: ["Мэттью Макконахи"],
            synopsis: "", hook: "", themes: [], atmosphere: [], plotFeatures: [],
            durationMinutes: 169, ageRating: "12+", endingType: "философская", rating: 8.6
        )
    )
}
