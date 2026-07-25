import Foundation

@MainActor
final class QuickPickViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case genre, importantAspects, mood, duration, excludedGenres, done
    }

    struct Question {
        let title: String
        let options: [QuestionOption]
        let allowsMultipleSelection: Bool
        /// Заголовки вариантов, которые нужно сразу показать выбранными —
        /// приходит из прошлого ответа, если проходим опрос повторно "с изменением".
        var initialSelection: [String] = []
    }

    private static let allGenres = ["Боевик", "Комедия", "Фантастика", "Триллер", "Ужасы", "Драма"]
    private static let noExclusionOption = "Без ограничений"

    @Published private(set) var step: Step = .genre

    private(set) var genre: String = ""
    private(set) var importantAspects: [String] = []
    private(set) var mood: String = ""
    private(set) var duration: String = ""
    private(set) var excludedGenres: [String] = []

    /// Прошлый профиль, если открыли экран через "Изменить ответы" из истории —
    /// каждый вопрос подставляет из него свой initialSelection.
    private let seed: UserPreferenceProfile?

    init(initial: UserPreferenceProfile? = nil) {
        self.seed = initial
    }

    var isComplete: Bool { step == .done }

    var currentQuestion: Question? {
        switch step {
        case .genre:
            return Question(
                title: "Какой жанр хочется посмотреть?",
                options: Self.allGenres.map(QuestionOption.init),
                allowsMultipleSelection: false,
                initialSelection: seed?.genres ?? []
            )
        case .importantAspects:
            return Question(
                title: "Что для вас важнее?",
                options: ["Сюжет", "Атмосфера", "Актеры", "Экшен", "Юмор", "Визуальная часть", "Неожиданная концовка"].map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seed?.importantAspects ?? []
            )
        case .mood:
            return Question(
                title: "Какое настроение фильма хочется?",
                options: ["Легкое", "Напряженное", "Темное", "Вдохновляющее", "Эмоциональное"].map(QuestionOption.init),
                allowsMultipleSelection: false,
                initialSelection: seed?.mood ?? []
            )
        case .duration:
            return Question(
                title: "Какая длительность предпочтительнее?",
                options: ["До 90 минут", "До 2 часов", "Любая"].map(QuestionOption.init),
                allowsMultipleSelection: false,
                initialSelection: seed?.durationPreference.map { [$0] } ?? []
            )
        case .excludedGenres:
            let candidates = Self.allGenres.filter { $0 != genre }
            let seedExcluded = seed?.excludedGenres ?? []
            return Question(
                title: "Чего точно не хочется?",
                options: ([Self.noExclusionOption] + candidates).map(QuestionOption.init),
                allowsMultipleSelection: true,
                initialSelection: seedExcluded.isEmpty ? [Self.noExclusionOption] : seedExcluded
            )
        case .done:
            return nil
        }
    }

    func answer(_ selected: [QuestionOption]) {
        let titles = selected.map(\.title)
        switch step {
        case .genre: genre = titles.first ?? ""
        case .importantAspects: importantAspects = titles
        case .mood: mood = titles.first ?? ""
        case .duration: duration = titles.first ?? ""
        case .excludedGenres: excludedGenres = titles.filter { $0 != Self.noExclusionOption }
        case .done: break
        }
        step = Step(rawValue: step.rawValue + 1) ?? .done
    }

    func buildProfile() -> UserPreferenceProfile {
        var profile = UserPreferenceProfile(source: .quickPick)
        profile.genres = genre.isEmpty ? [] : [genre]
        profile.importantAspects = importantAspects
        profile.mood = mood.isEmpty ? [] : [mood]
        profile.durationPreference = duration.isEmpty ? nil : duration
        profile.excludedGenres = excludedGenres
        return profile
    }
}
