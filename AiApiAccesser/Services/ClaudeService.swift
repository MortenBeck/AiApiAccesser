import Foundation
import Combine
import SwiftUI

class ClaudeService: LLMService {
    var type: LLMType = .claude
    var settings: LLMSettings
    private let keychainManager: KeychainManager
    
    init(settings: LLMSettings? = nil, keychainManager: KeychainManager = KeychainManager()) {
        self.settings = settings ?? LLMSettings.defaultSettings(for: .claude)
        self.keychainManager = keychainManager
    }
    
    func sendMessage(messages: [Message], documents: [Document]?) -> AnyPublisher<String, Error> {
        guard let apiKey = keychainManager.getApiKey(for: .claude) else {
            return Fail(error: LLMServiceError.noApiKeyFound).eraseToAnyPublisher()
        }
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.addValue("anthropic-version-2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestMessages: [[String: Any]] = []
        var systemPrompt = "You are Claude, a helpful AI assistant." + (settings.extraSystemPrompt.isEmpty ? "" : "\n\n\(settings.extraSystemPrompt)")
        
        // Process documents if present
        if let documents = documents, !documents.isEmpty {
            let documentContent = documents.compactMap { doc -> String? in
                guard let content = doc.content else { return nil }
                return "Document: \(doc.filename)\n\(content)"
            }.joined(separator: "\n\n")
            
            if !documentContent.isEmpty {
                systemPrompt += "\n\nThe user has provided the following documents for context:\n\n\(documentContent)"
            }
        }
        
        // Add conversation messages
        for message in messages {
            requestMessages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        let payload: [String: Any] = [
            "model": settings.modelName,
            "messages": requestMessages,
            "system": systemPrompt,
            "temperature": settings.temperature,
            "max_tokens": settings.maxTokens
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> String in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw LLMServiceError.responseParsingError(NSError(domain: "Claude", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"]))
                }
                
                if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                    throw LLMServiceError.apiError(message)
                }
                
                guard let content = json["content"] as? [[String: Any]],
                      let firstContent = content.first,
                      let text = firstContent["text"] as? String else {
                    throw LLMServiceError.responseParsingError(NSError(domain: "Claude", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract message content"]))
                }
                
                return text
            }
            .mapError { error -> Error in
                if let llmError = error as? LLMServiceError {
                    return llmError
                }
                return LLMServiceError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func validateApiKey(_ apiKey: String) -> AnyPublisher<Bool, Error> {
        let url = URL(string: "https://api.anthropic.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.addValue("anthropic-version-2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { data, response -> Bool in
                if let httpResponse = response as? HTTPURLResponse {
                    return httpResponse.statusCode == 200
                }
                return false
            }
            .mapError { error -> Error in
                return LLMServiceError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
}