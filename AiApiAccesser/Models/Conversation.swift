import Foundation
import SwiftUI
import Combine

struct Conversation: Identifiable, Codable {
    var id: UUID
    var title: String
    var messages: [Message]
    var modelType: LLMType
    var createdAt: Date
    var lastUpdatedAt: Date
    
    init(id: UUID = UUID(), 
         title: String = "New Conversation", 
         messages: [Message] = [], 
         modelType: LLMType = .claude, 
         createdAt: Date = Date(), 
         lastUpdatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.modelType = modelType
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    mutating func addMessage(_ message: Message) {
        messages.append(message)
        lastUpdatedAt = Date()
        
        // Auto-generate title from first user message if title is default
        if title == "New Conversation" && messages.count == 1 && message.role == .user {
            title = generateTitle(from: message.content)
        }
    }
    
    private func generateTitle(from content: String) -> String {
        let words = content.split(separator: " ")
        let maxWords = 5
        let titleWords = words.prefix(maxWords).joined(separator: " ")
        
        if titleWords.count < content.count {
            return "\(titleWords)..."
        } else {
            return titleWords
        }
    }
}