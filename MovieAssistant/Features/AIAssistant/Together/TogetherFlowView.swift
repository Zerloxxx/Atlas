import SwiftUI

struct TogetherFlowView: View {
    @StateObject private var viewModel: TogetherViewModel

    init(initialProfile: UserPreferenceProfile? = nil) {
        _viewModel = StateObject(wrappedValue: TogetherViewModel(initial: initialProfile))
    }

    var body: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 0) {
                    if let count = viewModel.participantCount {
                        participantBadge(number: viewModel.currentParticipantNumber, total: count)
                    }
                    ChoiceQuestionView(
                        question: question.title,
                        options: question.options,
                        allowsMultipleSelection: question.allowsMultipleSelection,
                        initialSelection: question.initialSelection,
                        onContinue: { viewModel.answer($0) }
                    )
                }
                .id(question.title)
            } else {
                RecommendationResultsView(profile: viewModel.buildProfile())
            }
        }
        .navigationTitle("Смотрим вместе")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: viewModel.currentParticipantIndex)
        .animation(.easeInOut, value: viewModel.isAskingMood)
        .animation(.easeInOut, value: viewModel.participantCount)
    }

    /// Явно показывает, чей сейчас черёд отвечать — иначе на экране, где
    /// вопросы у всех участников выглядят одинаково, легко потерять, за кого
    /// прямо сейчас отвечаешь.
    private func participantBadge(number: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Отвечает человек \(number) из \(total)")
                .font(AppTheme.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(AppTheme.Colors.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.accent.opacity(0.15))
        .clipShape(Capsule())
        .padding(.top, AppTheme.Layout.padding)
        .padding(.horizontal, AppTheme.Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
