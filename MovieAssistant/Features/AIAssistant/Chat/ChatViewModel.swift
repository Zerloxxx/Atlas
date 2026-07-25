import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(
            role: .assistant,
            text: "Привет! Напишите, что хотите посмотреть — например: «Хочу боевик с Джейсоном Стэйтемом» или «Фильм похожий на Форсаж, но без гонок»."
        )
    ]
    @Published var inputText: String
    @Published var pendingProfile: UserPreferenceProfile?

    init(initialText: String = "") {
        self.inputText = initialText
    }

    /// Готовые подсказки настроения — подставляются тапом в пустое поле ввода,
    /// чтобы не заставлять человека придумывать формулировку с нуля.
    let moodSuggestions: [String] = [
        "Хочу поплакать",
        "Ничего не думать",
        "Что-то короткое",
        "Напряжённый триллер",
        "Уютный вечер",
        "Что-то новое для меня"
    ]

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        inputText = ""

        var profile = UserPreferenceProfile(source: .chat)
        profile.freeTextQuery = trimmed
        pendingProfile = profile
    }
}
