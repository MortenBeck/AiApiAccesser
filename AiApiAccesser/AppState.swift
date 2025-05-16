import SwiftUI
import Combine

// Global application state
class AppState: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var activeConversationId: UUID?
    @Published var showSettings = false
    @Published var showAPIManagement = false
    @Published var showUsageMonitor = false
    @Published var llmSettings: [LLMType: LLMSettings] = [:]
    @Published var isLoading = false
    
    // Usage tracking properties
    @Published var tokenUsage: [String: Int] = [:]
    @Published var requestCounts: [String: Int] = [:]
    
    private let persistenceService = PersistenceService()
    private var cancellables = Set<AnyCancellable>()
    
    // LLM services
    private(set) lazy var openAIService = OpenAIService(settings: llmSettings[.chatGPT])
    private(set) lazy var claudeService = ClaudeService(settings: llmSettings[.claude])
    private(set) lazy var deepSeekService = DeepSeekService(settings: llmSettings[.deepSeek])
    
    init() {
        print("AppState init")
        // Initialize with default settings
        LLMType.allCases.forEach { type in
            llmSettings[type] = LLMSettings.defaultSettings(for: type)
        }
        
        // Load usage data
        loadUsageData()
    }
    
    func loadSettings() {
        print("Loading settings")
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
        
        // Load usage data
        loadUsageData()
    }
    
    func loadConversations() {
        print("Loading conversations")
        isLoading = true
        
        persistenceService.loadAllConversations()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to load conversations: \(error)")
                }
                self.isLoading = false
            }, receiveValue: { conversations in
                print("Loaded \(conversations.count) conversations")
                self.conversations = conversations
                
                // Set active conversation to the most recent one if none is active
                if self.activeConversationId == nil && !conversations.isEmpty {
                    self.activeConversationId = conversations[0].id
                    print("Setting active conversation to \(String(describing: self.activeConversationId))")
                }
            })
            .store(in: &cancellables)
    }
    
    func createNewConversation(modelType: LLMType = .claude) -> UUID {
        print("Creating new conversation with model \(modelType)")
        let newConversation = Conversation(modelType: modelType)
        print("New conversation ID: \(newConversation.id)")
        
        conversations.insert(newConversation, at: 0)
        print("Conversations count after insert: \(conversations.count)")
        
        activeConversationId = newConversation.id
        print("Set active conversation ID to: \(String(describing: activeConversationId))")
        
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
        
        return newConversation.id
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
        print("Deleting conversation with ID: \(id)")
        
        persistenceService.deleteConversation(id: id)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to delete conversation: \(error)")
                }
            }, receiveValue: { _ in
                logInfo("Conversation deleted successfully")
                
                // Remove from list
                self.conversations.removeAll { $0.id == id }
                print("Conversations count after delete: \(self.conversations.count)")
                
                // If this was the active conversation, set a new active one
                if self.activeConversationId == id {
                    if !self.conversations.isEmpty {
                        self.activeConversationId = self.conversations.first?.id
                        print("Set new active ID to: \(String(describing: self.activeConversationId))")
                    } else {
                        self.activeConversationId = nil
                        print("Set active ID to nil")
                    }
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
    
    // MARK: - Usage tracking methods
    
    func resetTokenUsage() {
        tokenUsage = [:]
        saveUsageData()
    }
    
    func saveSettings() {
        let openAISettings = llmSettings[.chatGPT] ?? LLMSettings.defaultSettings(for: .chatGPT)
        let claudeSettings = llmSettings[.claude] ?? LLMSettings.defaultSettings(for: .claude)
        let deepSeekSettings = llmSettings[.deepSeek] ?? LLMSettings.defaultSettings(for: .deepSeek)
        
        persistenceService.saveSettings(openAI: openAISettings, claude: claudeSettings, deepSeek: deepSeekSettings)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to save settings: \(error)")
                }
            }, receiveValue: { _ in
                logInfo("Settings saved successfully")
            })
            .store(in: &cancellables)
    }
    
    func resetRequestCounts() {
        requestCounts = [:]
        saveUsageData()
    }
    
    func trackTokenUsage(model: String, count: Int) {
        tokenUsage[model] = (tokenUsage[model] ?? 0) + count
        saveUsageData()
    }
    
    func trackRequest(model: String) {
        requestCounts[model] = (requestCounts[model] ?? 0) + 1
        saveUsageData()
    }
    
    func saveUsageData() {
        UserDefaults.standard.set(tokenUsage, forKey: "tokenUsage")
        UserDefaults.standard.set(requestCounts, forKey: "requestCounts")
    }
    
    func loadUsageData() {
        if let savedTokenUsage = UserDefaults.standard.object(forKey: "tokenUsage") as? [String: Int] {
            tokenUsage = savedTokenUsage
        }
        
        if let savedRequestCounts = UserDefaults.standard.object(forKey: "requestCounts") as? [String: Int] {
            requestCounts = savedRequestCounts
        }
    }
}
