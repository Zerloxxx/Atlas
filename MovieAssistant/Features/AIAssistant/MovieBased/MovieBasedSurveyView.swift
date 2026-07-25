import SwiftUI

struct MovieBasedSurveyView: View {
    let referenceMovie: Movie

    @StateObject private var viewModel: MovieBasedSurveyViewModel

    init(referenceMovie: Movie, initialProfile: UserPreferenceProfile? = nil) {
        self.referenceMovie = referenceMovie
        _viewModel = StateObject(wrappedValue: MovieBasedSurveyViewModel(movie: referenceMovie, initial: initialProfile))
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
        .navigationTitle(referenceMovie.title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: viewModel.step)
    }
}
