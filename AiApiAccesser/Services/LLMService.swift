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