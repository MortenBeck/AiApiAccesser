import SwiftUI
import Combine

// Global application state
class AppState: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var activeConversationId: UUID?
    @Published var showSettings = false
    @Published var showAPIManagement = false
    @Published var llmSettings: [LLMType: LLMSettings] = [:]
    @Published var isLoading = false
    
    private let persistenceService = PersistenceService()
    private var cancellables = Set<AnyCancellable>()
    
    // LLM services
    private(set) lazy var openAIService = OpenAIService(settings: llmSettings[.chatGPT])
    private(set) lazy var claudeService = ClaudeService(settings: llmSettings[.claude])
    private(set) lazy var deepSeekService = DeepSeekService(settings: llmSettings[.deepSeek])
    
    init() {
        // Initialize with default settings
        LLMType.allCases.forEach { type in
            llmSettings[type] = LLMSettings.defaultSettings(for: type)
        }
    }
    
    func loadSettings() {
        isLoading = true
        
        persistenceService.loadSettings()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to load settings: \(error)")
                }
                self.isLoading = false
            }, receiveValue: { settings in
                self.llmSettings = settings
                
                // Update services with loaded settings
                self.openAIService.settings = settings[.chatGPT] ?? LLMSettings.defaultSettings(for: .chatGPT)
                self.claudeService.settings = settings[.claude] ?? LLMSettings.defaultSettings(for: .claude)
                self.deepSeekService.settings = settings[.deepSeek] ?? LLMSettings.defaultSettings(for: .deepSeek)
            })
            .store(in: &cancellables)
    }
    
    func saveSettings() {
        guard let openAISettings = llmSettings[.chatGPT],
              let claudeSettings = llmSettings[.claude],
              let deepSeekSettings = llmSettings[.deepSeek] else {
            return
        }
        
        persistenceService.saveSettings(openAI: openAISettings, claude: claudeSettings, deepSeek: deepSeekSettings)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to save settings: \(error)")
                }
            }, receiveValue: { _ in
                logInfo("Settings saved successfully")
                
                // Update services with new settings
                self.openAIService.settings = openAISettings
                self.claudeService.settings = claudeSettings
                self.deepSeekService.settings = deepSeekSettings
            })
            .store(in: &cancellables)
    }
    
    func loadConversations() {
        isLoading = true
        
        persistenceService.loadAllConversations()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to load conversations: \(error)")
                }
                self.isLoading = false
            }, receiveValue: { conversations in
                self.conversations = conversations
                
                // Set active conversation to the most recent one if none is active
                if self.activeConversationId == nil && !conversations.isEmpty {
                    self.activeConversationId = conversations[0].id
                }
            })
            .store(in: &cancellables)
    }
    
    func createNewConversation(modelType: LLMType = .claude) {
        let newConversation = Conversation(modelType: modelType)
        conversations.insert(newConversation, at: 0)
        activeConversationId = newConversation.id
        
        // Save the new conversation
        persistenceService.saveConversation(newConversation)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to save new conversation: \(error)")
                }
            }, receiveValue: { _ in
                logInfo("New conversation created successfully")
            })
            .store(in: &cancellables)
    }
    
    func saveConversation(_ conversation: Conversation) {
        persistenceService.saveConversation(conversation)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to save conversation: \(error)")
                }
            }, receiveValue: { _ in
                logInfo("Conversation saved successfully")
                
                // Update the conversation in the list
                if let index = self.conversations.firstIndex(where: { $0.id == conversation.id }) {
                    self.conversations[index] = conversation
                    
                    // Re-sort conversations by last updated date
                    self.conversations.sort { $0.lastUpdatedAt > $1.lastUpdatedAt }
                }
            })
            .store(in: &cancellables)
    }
    
    func deleteConversation(id: UUID) {
        persistenceService.deleteConversation(id: id)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to delete conversation: \(error)")
                }
            }, receiveValue: { _ in
                logInfo("Conversation deleted successfully")
                
                // Remove from list
                self.conversations.removeAll { $0.id == id }
                
                // If this was the active conversation, set a new active one
                if self.activeConversationId == id {
                    self.activeConversationId = self.conversations.first?.id
                }
            })
            .store(in: &cancellables)
    }
    
    func getServiceForType(_ type: LLMType) -> LLMService {
        switch type {
        case .chatGPT:
            return openAIService
        case .claude:
            return claudeService
        case .deepSeek:
            return deepSeekService
        }
    }
}