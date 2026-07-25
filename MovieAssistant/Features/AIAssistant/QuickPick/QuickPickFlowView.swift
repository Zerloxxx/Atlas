import SwiftUI

struct QuickPickFlowView: View {
    @StateObject private var viewModel: QuickPickViewModel

    init(initialProfile: UserPreferenceProfile? = nil) {
        _viewModel = StateObject(wrappedValue: QuickPickViewModel(initial: initialProfile))
    }

    var body: some View {
        Group {
            if let question = viewModel.currentQuestion {
                ChoiceQuestionView(
                    question: question.title,
                    options: question.options,
                    allowsMultipleSelection: question.allowsMultipleSelection,
                    initialSelection: question.initialSelection,
                    onContinue: { viewModel.answer($0) }
                )
                .id(question.title)
            } else {
                RecommendationResultsView(profile: viewModel.buildProfile())
            }
        }
        .navigationTitle("Быстрый подбор")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: viewModel.step)
    }
}
