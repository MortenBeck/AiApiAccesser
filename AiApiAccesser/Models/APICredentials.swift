import Foundation
import SwiftUI
import Combine

struct APICredentials: Codable {
    var openAIApiKey: String?
    var claudeApiKey: String?
    var deepSeekApiKey: String?
    
    func getApiKey(for type: LLMType) -> String? {
        switch type {
        case .chatGPT:
            return openAIApiKey
        case .claude:
            return claudeApiKey
        case .deepSeek:
            return deepSeekApiKey
        }
    }
    
    mutating func setApiKey(_ key: String, for type: LLMType) {
        switch type {
        case .chatGPT:
            openAIApiKey = key
        case .claude:
            claudeApiKey = key
        case .deepSeek:
            deepSeekApiKey = key
        }
    }
}