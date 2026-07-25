import SwiftUI

/// Переиспользуемый экран одного вопроса с вариантами (single/multi-select).
/// Используется во всех опросных сценариях (быстрый подбор, подбор по фильму).
struct ChoiceQuestionView: View {
    let question: String
    let options: [QuestionOption]
    var allowsMultipleSelection: Bool = false
    let onContinue: ([QuestionOption]) -> Void

    @State private var selected: Set<QuestionOption>

    /// `initialSelection` — заголовки уже выбранных вариантов (например, при
    /// повторном прохождении опроса с прошлыми ответами из истории) — сразу
    /// показываются отмеченными, не нужно выбирать заново, если менять не хочется.
    init(
        question: String,
        options: [QuestionOption],
        allowsMultipleSelection: Bool = false,
        initialSelection: [String] = [],
        onContinue: @escaping ([QuestionOption]) -> Void
    ) {
        self.question = question
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onContinue = onContinue
        let preselected = options.filter { initialSelection.contains($0.title) }
        _selected = State(initialValue: Set(preselected))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
                Text(question)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(options) { option in
                        optionRow(option)
                    }
                }
            }
            .padding(AppTheme.Layout.padding)
        }
        // Кнопка закреплена снизу, а не в конце скролла — доступна даже
        // когда вариантов ответа много и они не помещаются на экран.
        .safeAreaInset(edge: .bottom) {
            Button {
                onContinue(Array(selected))
            } label: {
                Text("Далее")
            }
            .buttonStyle(.primaryGradient)
            .disabled(selected.isEmpty)
            .padding(.horizontal, AppTheme.Layout.padding)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(AppTheme.Colors.background)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private func optionRow(_ option: QuestionOption) -> some View {
        let isSelected = selected.contains(option)
        return Button {
            toggle(option)
        } label: {
            HStack {
                Text(option.title)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Layout.padding)
            .background(isSelected ? AppTheme.Colors.accent.opacity(0.15) : AppTheme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall)
                    .stroke(isSelected ? AppTheme.Colors.accent : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ option: QuestionOption) {
        if allowsMultipleSelection {
            if selected.contains(option) {
                selected.remove(option)
            } else {
                selected.insert(option)
            }
        } else {
            selected = [option]
        }
    }
}

#Preview {
    NavigationStack {
        ChoiceQuestionView(
            question: "Какой жанр хочется посмотреть?",
            options: ["Боевик", "Комедия", "Фантастика", "Триллер", "Ужасы", "Драма"].map(QuestionOption.init),
            onContinue: { _ in }
        )
    }
}
