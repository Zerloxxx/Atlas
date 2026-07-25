import Foundation

/// Сценарий "Смотрим вместе" — сначала спрашивает, сколько человек будет
/// смотреть, потом по кругу опрашивает каждого (жанр + настроение) и просит
/// ИИ найти компромисс сразу для всей компании, а не просто усреднить жанр.
@MainActor
final class TogetherViewModel: ObservableObject {
    struct Question {
        let title: String
        let options: [QuestionOption]
        let allowsMultipleSelection: Bool
        var initialSelection: [String] = []
    }

    private static let genres = ["Боевик", "Комедия", "Фантастика", "Триллер", "Ужасы", "Драма"]
    private static let moods = ["Легкое", "Напряженное", "Темное", "Вдохновляющее", "Эмоциональное"]
    private static let countOptions = ["2 человека", "3 человека", "4 человека", "5 человек"]

    /// nil — количество участников ещё не выбрано, первым делом спрашиваем его.
    @Published private(set) var participantCount: Int?
    @Published private(set) var currentParticipantIndex = 0
    @Published private(set) var isAskingMood = false

    private(set) var participants: [TogetherParticipant] = []

    private let seed: UserPreferenceProfile?

    init(initial: UserPreferenceProfile? = nil) {
        self.seed = initial
        // При "Изменить ответы" количество участников уже известно из прошлого
        // профиля — не спрашиваем заново, сразу переходим к самим вопросам.
        if let seededCount = initial?.togetherParticipants.count, seededCount >= 2 {
            participantCount = seededCount
        }
    }

    var isComplete: Bool {
        guard let participantCount else { return false }
        return currentParticipantIndex >= participantCount
    }

    /// Номер участника, который отвечает прямо сейчас — 1-based, для показа на экране.
    var currentParticipantNumber: Int { currentParticipantIndex + 1 }

    var currentQuestion: Question? {
        guard let participantCount else {
            return Question(
                title: "Сколько человек будет смотреть вместе?",
                options: Self.countOptions.map(QuestionOption.init),
                allowsMultipleSelection: false
            )
        }
        guard currentParticipantIndex < participantCount else { return nil }

        let seededParticipant: TogetherParticipant? = {
            guard let seed, currentParticipantIndex < seed.togetherParticipants.count else { return nil }
            return seed.togetherParticipants[currentParticipantIndex]
        }()

        if !isAskingMood {
            return Question(
                title: "Человек \(currentParticipantNumber) из \(participantCount) — какой жанр предпочитает?",
                options: Self.genres.map(QuestionOption.init),
                allowsMultipleSelection: false,
                initialSelection: seededParticipant?.genres ?? []
            )
        } else {
            return Question(
                title: "Человек \(currentParticipantNumber) из \(participantCount) — какое настроение хочет?",
                options: Self.moods.map(QuestionOption.init),
                allowsMultipleSelection: false,
                initialSelection: seededParticipant?.mood ?? []
            )
        }
    }

    func answer(_ selected: [QuestionOption]) {
        let title = selected.first?.title ?? ""

        guard let participantCount else {
            participantCount = Int(title.prefix { $0.isNumber }) ?? 2
            return
        }
        guard currentParticipantIndex < participantCount else { return }

        if participants.count <= currentParticipantIndex {
            participants.append(TogetherParticipant())
        }

        if !isAskingMood {
            participants[currentParticipantIndex].genres = title.isEmpty ? [] : [title]
            isAskingMood = true
        } else {
            participants[currentParticipantIndex].mood = title.isEmpty ? [] : [title]
            isAskingMood = false
            currentParticipantIndex += 1
        }
    }

    func buildProfile() -> UserPreferenceProfile {
        var profile = UserPreferenceProfile(source: .together)
        profile.togetherParticipants = participants
        return profile
    }
}
