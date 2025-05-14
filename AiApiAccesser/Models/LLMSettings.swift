import Foundation

enum LLMType: String, Codable, CaseIterable, Identifiable {
    case chatGPT = "ChatGPT"
    case claude = "Claude"
    case deepSeek = "DeepSeek"
    
    var id: String { self.rawValue }
}

struct LLMSettings: Codable {
    var modelName: String
    var temperature: Double
    var maxTokens: Int
    var extraSystemPrompt: String
    var documentChunkSize: Int
    var documentOverlap: Int
    
    static func defaultSettings(for type: LLMType) -> LLMSettings {
        switch type {
        case .chatGPT:
            return LLMSettings(
                modelName: "gpt-4o",
                temperature: 0.7,
                maxTokens: 4000,
                extraSystemPrompt: "",
                documentChunkSize: 4000,
                documentOverlap: 200
            )
        case .claude:
            return LLMSettings(
                modelName: "claude-3-7-sonnet-20250219",
                temperature: 0.7,
                maxTokens: 4000,
                extraSystemPrompt: "",
                documentChunkSize: 4000,
                documentOverlap: 200
            )
        case .deepSeek:
            return LLMSettings(
                modelName: "deepseek-coder",
                temperature: 0.7,
                maxTokens: 4000,
                extraSystemPrompt: "",
                documentChunkSize: 4000,
                documentOverlap: 200
            )
        }
    }
}