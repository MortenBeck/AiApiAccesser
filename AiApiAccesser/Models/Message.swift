import Foundation

struct Message: Identifiable, Codable {
    var id: UUID
    var content: String
    var role: MessageRole
    var timestamp: Date
    var attachedDocuments: [AttachedDocument]?
    var modelType: LLMType? // Added to track which model generated this message
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    struct AttachedDocument: Identifiable, Codable {
        var id: UUID
        var documentId: UUID
        var name: String
        
        init(documentId: UUID, name: String) {
            self.id = UUID()
            self.documentId = documentId
            self.name = name
        }
    }
    
    init(id: UUID = UUID(), content: String, role: MessageRole, timestamp: Date = Date(), attachedDocuments: [AttachedDocument]? = nil, modelType: LLMType? = nil) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.attachedDocuments = attachedDocuments
        self.modelType = modelType
    }
    
    static func userMessage(content: String, attachedDocuments: [AttachedDocument]? = nil) -> Message {
        Message(content: content, role: .user, attachedDocuments: attachedDocuments)
    }
    
    static func assistantMessage(content: String, modelType: LLMType? = nil) -> Message {
        Message(content: content, role: .assistant, modelType: modelType)
    }
    
    static func systemMessage(content: String) -> Message {
        Message(content: content, role: .system)
    }
}
