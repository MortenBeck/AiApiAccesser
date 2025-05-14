import Foundation
import Combine
import SwiftUI

class DeepSeekService: LLMService {
    var type: LLMType = .deepSeek
    var settings: LLMSettings
    private let keychainManager: KeychainManager
    
    init(settings: LLMSettings? = nil, keychainManager: KeychainManager = KeychainManager()) {
        self.settings = settings ?? LLMSettings.defaultSettings(for: .deepSeek)
        self.keychainManager = keychainManager
    }
    
    func sendMessage(messages: [Message], documents: [Document]?) -> AnyPublisher<String, Error> {
        guard let apiKey = keychainManager.getApiKey(for: .deepSeek) else {
            return Fail(error: LLMServiceError.noApiKeyFound).eraseToAnyPublisher()
        }
        
        let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestMessages: [[String: Any]] = []
        
        // Add system message
        let systemPrompt = "You are a helpful assistant." + (settings.extraSystemPrompt.isEmpty ? "" : "\n\n\(settings.extraSystemPrompt)")
        requestMessages.append(["role": "system", "content": systemPrompt])
        
        // Process documents if present
        if let documents = documents, !documents.isEmpty {
            let documentContent = documents.compactMap { doc -> String? in
                guard let content = doc.content else { return nil }
                return "Document: \(doc.filename)\n\(content)"
            }.joined(separator: "\n\n")
            
            if !documentContent.isEmpty {
                requestMessages.append(["role": "user", "content": "Here are documents for context:\n\n\(documentContent)"])
                requestMessages.append(["role": "assistant", "content": "I've reviewed the documents you provided."])
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
            "temperature": settings.temperature,
            "max_tokens": settings.maxTokens
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> String in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw LLMServiceError.responseParsingError(NSError(domain: "DeepSeek", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"]))
                }
                
                if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                    throw LLMServiceError.apiError(message)
                }
                
                guard let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    throw LLMServiceError.responseParsingError(NSError(domain: "DeepSeek", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract message content"]))
                }
                
                return content
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
        let url = URL(string: "https://api.deepseek.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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