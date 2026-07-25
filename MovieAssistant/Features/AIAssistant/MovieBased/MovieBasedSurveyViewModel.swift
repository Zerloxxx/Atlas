import Foundation

/// Динамический опрос по понравившемуся фильму: уточняющие вопросы зависят
/// от того, что пользователь отметил на первом шаге, и используют реальные
/// данные конкретного фильма (актёры/сюжет/атмосфера), а не статичный список.
@MainActor
final class MovieBasedSurveyViewModel: ObservableObject {
    enum Step: Equatable {
        case likedAspects
        case actorsFollowUp
        case plotFollowUp
        case atmosphereFollowUp
        case wantsToChange
        case done
    }

    struct Question {
        let title: String
        let options: [QuestionOption]
        let allowsMultipleSelection: Bool
        var initialSelection: [String] = []
    }

    let movie: Movie

    @Published private(set) var step: Step = .likedAspects
    private var remainingFollowUps: [Step] = []

    private(set) var likedAspects: [String] = []
    private(set) var likedActors: [String] = []
    private(set) var likedPlotFeatures: [String] = []
    private(set) var likedAtmosphere: [String] = []
    private(set) var wantsToChange: [String] = []

    private let seed: UserPreferenceProfile?

    init(movie: Movie, initial: UserPreferenceProfile? = nil) {
        self.movie = movie
        self.seed = initial
    }

    var isComplete: Bool { step == .done }

    var currentQuestion: Question? {
        switch step {
        case .likedAspects:
            return Question(
                title: "Что вам понравилось именно в этом фильме?",
                options: ["Сюжет", "Атмосфера", "Актеры", "Экшен", "Визуальная часть", "Музыка", "Идея", "Режиссура", "Концовка"].map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seed?.likedAspects ?? []
            )
        case .actorsFollowUp:
            return Question(
                title: "Какие актёры особенно понравились?",
                options: movie.actors.map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seed?.likedActors ?? []
            )
        case .plotFollowUp:
            return Question(
                title: "Что особенно зацепило в сюжете?",
                options: movie.plotFeatures.map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seed?.likedPlotFeatures ?? []
            )
        case .atmosphereFollowUp:
            return Question(
                title: "Какая атмосфера понравилась?",
                options: movie.atmosphere.map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seed?.likedAtmosphere ?? []
            )
        case .wantsToChange:
            return Question(
                title: "Что хотелось бы изменить?",
                options: ["Ничего, найдите похожее", "Более лёгкий фильм", "Более динамичный", "Другой жанр", "Более короткий", "Более длинный", "Более неожиданная концовка"].map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seed?.wantsToChange ?? []
            )
        case .done:
            return nil
        }
    }

    func answer(_ selected: [QuestionOption]) {
        let titles = selected.map(\.title)
        switch step {
        case .likedAspects:
            likedAspects = titles
            remainingFollowUps = buildFollowUps(for: titles)
        case .actorsFollowUp:
            likedActors = titles
        case .plotFollowUp:
            likedPlotFeatures = titles
        case .atmosphereFollowUp:
            likedAtmosphere = titles
        case .wantsToChange:
            wantsToChange = titles
        case .done:
            break
        }
        advance()
    }

    private func buildFollowUps(for aspects: [String]) -> [Step] {
        var steps: [Step] = []
        if aspects.contains("Актеры"), !movie.actors.isEmpty { steps.append(.actorsFollowUp) }
        if aspects.contains("Сюжет"), !movie.plotFeatures.isEmpty { steps.append(.plotFollowUp) }
        if aspects.contains("Атмосфера"), !movie.atmosphere.isEmpty { steps.append(.atmosphereFollowUp) }
        return steps
    }

    private func advance() {
        if !remainingFollowUps.isEmpty {
            step = remainingFollowUps.removeFirst()
        } else if step != .wantsToChange {
            step = .wantsToChange
        } else {
            step = .done
        }
    }

    func buildProfile() -> UserPreferenceProfile {
        var profile = UserPreferenceProfile(source: .movieBased(referenceMovieId: movie.id))
        profile.likedAspects = likedAspects
        profile.likedActors = likedActors
        profile.likedPlotFeatures = likedPlotFeatures
        profile.likedAtmosphere = likedAtmosphere
        profile.wantsToChange = wantsToChange
        return profile
    }
}
