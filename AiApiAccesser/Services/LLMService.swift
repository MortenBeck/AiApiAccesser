import Foundation
import Combine
import SwiftUI

protocol LLMService {
    var type: LLMType { get }
    var settings: LLMSettings { get set }
    
    func sendMessage(messages: [Message], documents: [Document]?) -> AnyPublisher<String, Error>
    func validateApiKey(_ apiKey: String) -> AnyPublisher<Bool, Error>
}

enum LLMServiceError: Error {
    case invalidApiKey
    case apiError(String)
    case networkError(Error)
    case responseParsingError(Error)
    case noApiKeyFound
}

// MARK: - Usage tracking extension
extension LLMService {
    func sendMessageWithTracking(messages: [Message], documents: [Document]?, appState: AppState) -> AnyPublisher<String, Error> {
        // Track API request
        DispatchQueue.main.async {
            appState.trackRequest(model: self.settings.modelName)
        }
        
        return sendMessage(messages: messages, documents: documents)
            .map { response -> String in
                // Estimate token usage (this is a very rough estimation)
                let inputTokens = self.estimateTokens(messages: messages, documents: documents)
                let outputTokens = self.estimateTokens(text: response)
                
                // Track token usage on main thread
                DispatchQueue.main.async {
                    appState.trackTokenUsage(model: self.settings.modelName, count: inputTokens + outputTokens)
                }
                
                return response
            }
            .eraseToAnyPublisher()
    }
    
    // Very rough token estimation - different models tokenize differently
    // For a production app, use model-specific tokenizers
    private func estimateTokens(text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        return max(1, text.count / 4)
    }
    
    private func estimateTokens(messages: [Message], documents: [Document]?) -> Int {
        var totalText = ""
        
        // Add message content
        for message in messages {
            totalText += message.content
        }
        
        // Add document content
        if let docs = documents {
            for doc in docs {
                if let content = doc.content {
                    totalText += content
                }
            }
        }
        
        return estimateTokens(text: totalText)
    }
}
