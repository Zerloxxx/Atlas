import Foundation

enum OpenAIClientError: Error, LocalizedError {
    case invalidAPIKey
    case requestFailed(String)
    case emptyResponse
    /// ИИ определил, что запрос не связан с подбором фильма — сообщение уже готово для показа пользователю.
    case offTopic(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Не задан API-ключ OpenAI. Открой Core/Services/Config.swift и вставь свой ключ."
        case .requestFailed(let message):
            return "Запрос к ИИ не удался: \(message)"
        case .emptyResponse:
            return "ИИ вернул пустой или некорректный ответ. Попробуй ещё раз."
        case .offTopic(let message):
            return message
        }
    }
}

/// Низкоуровневый клиент к OpenAI Chat Completions.
/// Не знает о фильмах и промптах — только отправляет system/user сообщения и возвращает текст ответа.
final class OpenAIClient {
    static let shared = OpenAIClient()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func complete(systemPrompt: String, userPrompt: String) async throws -> String {
        guard Config.openAIAPIKey.hasPrefix("sk-") else {
            throw OpenAIClientError.invalidAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        // temperature не передаём: часть моделей (напр. gpt-5.6-terra) принимает
        // только значение по умолчанию и отклоняет запрос при любом другом.
        let body = ChatCompletionRequest(
            model: Config.openAIModel,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            responseFormat: .init(type: "json_object")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.requestFailed("нет ответа от сервера")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw OpenAIClientError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw OpenAIClientError.emptyResponse
        }
        return content
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
