import Foundation
import OpenAI

public final class GPTPizzaDetector {
    public static let shared = GPTPizzaDetector()

    private let api: OpenAI
    private let decoder = JSONDecoder()

    private init() {
        api = OpenAI(apiToken: "sk-proj-TWzQtMdWue6F05L6F8a1T3BlbkFJ8bQuAI6u4uEy4MHJawCg")
    }

    public func detectPizza(image: Data) async throws -> Bool {
        let response = try await api.chats(query: ChatQuery(
            messages: [
                .system(.init(content: """
                You are a pizza detecting AI. Your job is to receive images from the user and determine \
                if they are images of pizza. If they are pictures of pizza, call set_verdict with "is_pizza" \
                set to the boolean value true. Otherwise, call it with false.
                """)),
                .user(.init(content: .vision([.chatCompletionContentPartImageParam(.init(imageUrl: .init(
                    url: "data:image/jpeg;base64,\(image.base64EncodedString())",
                    detail: .low
                )))]))),
            ],
            model: .gpt4_turbo,
            toolChoice: .function("set_verdict"),
            tools: [.init(function: .init(
                name: "set_verdict",
                description: nil,
                parameters: .init(
                    type: .object,
                    properties: [
                        "is_pizza": .init(type: .boolean),
                    ],
                    required: [
                        "is_pizza"
                    ]
                )
            ))]
        ))
        let arguments = response.choices.lazy
            .compactMap(\.message.toolCalls?.first?.function.arguments)
            .first
        guard let arguments else {
            throw PizzaDetectorError.badGPTOutput
        }
        let verdict = try decoder.decode(Verdict.self, from: Data(arguments.utf8))
        return verdict.isPizza
    }
}

private struct Verdict: Decodable {
    let isPizza: Bool

    private enum CodingKeys: String, CodingKey {
        case isPizza = "is_pizza"
    }
}

public enum PizzaDetectorError: Error {
    case badGPTOutput
}
