import Foundation
import Combine
import SwiftUI

class PersistenceService {
    private let fileManager = FileManager.default
    private let applicationSupportDirectory: URL
    
    // File paths
    private var conversationsDirectoryURL: URL
    private var documentsDirectoryURL: URL
    private var settingsFileURL: URL
    
    init() {
        // Get the application support directory
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not access application support directory")
        }
        
        self.applicationSupportDirectory = applicationSupportURL.appendingPathComponent("AiApiAccesser")
        self.conversationsDirectoryURL = applicationSupportDirectory.appendingPathComponent("Conversations")
        self.documentsDirectoryURL = applicationSupportDirectory.appendingPathComponent("Documents")
        self.settingsFileURL = applicationSupportDirectory.appendingPathComponent("settings.json")
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        let directories = [applicationSupportDirectory, conversationsDirectoryURL, documentsDirectoryURL]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    logError("Failed to create directory at \(directory.path): \(error)")
                }
            }
        }
    }
    
    // MARK: - Conversations
    
    func saveConversation(_ conversation: Conversation) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let fileURL = self.conversationsDirectoryURL.appendingPathComponent("\(conversation.id.uuidString).json")
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(conversation)
                try data.write(to: fileURL)
                promise(.success(()))
            } catch {
                logError("Failed to save conversation: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func loadConversation(id: UUID) -> AnyPublisher<Conversation, Error> {
        return Future<Conversation, Error> { promise in
            let fileURL = self.conversationsDirectoryURL.appendingPathComponent("\(id.uuidString).json")
            
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                promise(.failure(NSError(domain: "PersistenceService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])))
                return
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let conversation = try decoder.decode(Conversation.self, from: data)
                promise(.success(conversation))
            } catch {
                logError("Failed to load conversation: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func loadAllConversations() -> AnyPublisher<[Conversation], Error> {
        return Future<[Conversation], Error> { promise in
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(at: self.conversationsDirectoryURL, includingPropertiesForKeys: nil)
                let jsonURLs = fileURLs.filter { $0.pathExtension == "json" }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                var conversations: [Conversation] = []
                
                for url in jsonURLs {
                    do {
                        let data = try Data(contentsOf: url)
                        let conversation = try decoder.decode(Conversation.self, from: data)
                        conversations.append(conversation)
                    } catch {
                        logError("Failed to decode conversation at \(url.path): \(error)")
                        // Continue with other conversations even if one fails
                    }
                }
                
                // Sort by last updated date, newest first
                conversations.sort { $0.lastUpdatedAt > $1.lastUpdatedAt }
                
                promise(.success(conversations))
            } catch {
                logError("Failed to load conversations: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteConversation(id: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let fileURL = self.conversationsDirectoryURL.appendingPathComponent("\(id.uuidString).json")
            
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                promise(.success(())) // Already deleted or doesn't exist
                return
            }
            
            do {
                try self.fileManager.removeItem(at: fileURL)
                promise(.success(()))
            } catch {
                logError("Failed to delete conversation: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Documents
    
    func saveDocument(_ document: Document) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let fileURL = self.documentsDirectoryURL.appendingPathComponent("\(document.id.uuidString).json")
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(document)
                try data.write(to: fileURL)
                promise(.success(()))
            } catch {
                logError("Failed to save document: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func loadDocument(id: UUID) -> AnyPublisher<Document, Error> {
        return Future<Document, Error> { promise in
            let fileURL = self.documentsDirectoryURL.appendingPathComponent("\(id.uuidString).json")
            
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                promise(.failure(NSError(domain: "PersistenceService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
                return
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let document = try decoder.decode(Document.self, from: data)
                promise(.success(document))
            } catch {
                logError("Failed to load document: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteDocument(id: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let fileURL = self.documentsDirectoryURL.appendingPathComponent("\(id.uuidString).json")
            
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                promise(.success(())) // Already deleted or doesn't exist
                return
            }
            
            do {
                try self.fileManager.removeItem(at: fileURL)
                promise(.success(()))
            } catch {
                logError("Failed to delete document: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Settings
    
    func saveSettings(openAI: LLMSettings, claude: LLMSettings, deepSeek: LLMSettings) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            do {
                let settings = [
                    LLMType.chatGPT.rawValue: openAI,
                    LLMType.claude.rawValue: claude,
                    LLMType.deepSeek.rawValue: deepSeek
                ]
                
                let encoder = JSONEncoder()
                let data = try encoder.encode(settings)
                try data.write(to: self.settingsFileURL)
                promise(.success(()))
            } catch {
                logError("Failed to save settings: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func loadSettings() -> AnyPublisher<[LLMType: LLMSettings], Error> {
        return Future<[LLMType: LLMSettings], Error> { promise in
            guard self.fileManager.fileExists(atPath: self.settingsFileURL.path) else {
                // Return default settings if file doesn't exist
                let defaults: [LLMType: LLMSettings] = [
                    .chatGPT: LLMSettings.defaultSettings(for: .chatGPT),
                    .claude: LLMSettings.defaultSettings(for: .claude),
                    .deepSeek: LLMSettings.defaultSettings(for: .deepSeek)
                ]
                promise(.success(defaults))
                return
            }
            
            do {
                let data = try Data(contentsOf: self.settingsFileURL)
                let decoder = JSONDecoder()
                let settingsDict = try decoder.decode([String: LLMSettings].self, from: data)
                
                var typedSettings: [LLMType: LLMSettings] = [:]
                
                for (key, value) in settingsDict {
                    if let type = LLMType(rawValue: key) {
                        typedSettings[type] = value
                    }
                }
                
                // Fill in any missing types with defaults
                for type in LLMType.allCases {
                    if typedSettings[type] == nil {
                        typedSettings[type] = LLMSettings.defaultSettings(for: type)
                    }
                }
                
                promise(.success(typedSettings))
            } catch {
                logError("Failed to load settings: \(error)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}