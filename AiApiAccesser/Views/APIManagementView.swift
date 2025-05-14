import SwiftUI
import Combine

struct APIManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    
    @State private var openAIApiKey = ""
    @State private var claudeApiKey = ""
    @State private var deepSeekApiKey = ""
    
    @State private var isValidatingOpenAI = false
    @State private var isValidatingClaude = false
    @State private var isValidatingDeepSeek = false
    
    @State private var openAIKeyValid = false
    @State private var claudeKeyValid = false
    @State private var deepSeekKeyValid = false
    
    @State private var cancellables = Set<AnyCancellable>()
    
    private let keychainManager = KeychainManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("API Key Management")
                    .font(.title)
                    .padding()
                
                Spacer()
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    apiKeySection(
                        title: "OpenAI API Key",
                        description: "API key for accessing ChatGPT models",
                        apiKey: $openAIApiKey,
                        isValidating: $isValidatingOpenAI,
                        isValid: $openAIKeyValid,
                        validateAction: validateOpenAIKey,
                        saveAction: saveOpenAIKey
                    )
                    
                    Divider()
                    
                    apiKeySection(
                        title: "Anthropic Claude API Key",
                        description: "API key for accessing Claude models",
                        apiKey: $claudeApiKey,
                        isValidating: $isValidatingClaude,
                        isValid: $claudeKeyValid,
                        validateAction: validateClaudeKey,
                        saveAction: saveClaudeKey
                    )
                    
                    Divider()
                    
                    apiKeySection(
                        title: "DeepSeek API Key",
                        description: "API key for accessing DeepSeek models",
                        apiKey: $deepSeekApiKey,
                        isValidating: $isValidatingDeepSeek,
                        isValid: $deepSeekKeyValid,
                        validateAction: validateDeepSeekKey,
                        saveAction: saveDeepSeekKey
                    )
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadSavedKeys()
        }
    }
    
    private func apiKeySection(
        title: String,
        description: String,
        apiKey: Binding<String>,
        isValidating: Binding<Bool>,
        isValid: Binding<Bool>,
        validateAction: @escaping () -> Void,
        saveAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
            
            SecureField("API Key", text: apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isValidating.wrappedValue)
            
            HStack {
                Button("Validate") {
                    validateAction()
                }
                .disabled(apiKey.wrappedValue.isEmpty || isValidating.wrappedValue)
                
                if isValidating.wrappedValue {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, 5)
                } else if isValid.wrappedValue {
                    Text("Valid")
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button("Save") {
                    saveAction()
                }
                .disabled(apiKey.wrappedValue.isEmpty || isValidating.wrappedValue)
            }
        }
    }
    
    private func loadSavedKeys() {
        // We don't load actual keys, just placeholders if keys exist
        if let _ = keychainManager.getApiKey(for: .chatGPT) {
            openAIApiKey = "••••••••••••••••••••••••••"
            openAIKeyValid = true
        }
        
        if let _ = keychainManager.getApiKey(for: .claude) {
            claudeApiKey = "••••••••••••••••••••••••••"
            claudeKeyValid = true
        }
        
        if let _ = keychainManager.getApiKey(for: .deepSeek) {
            deepSeekApiKey = "••••••••••••••••••••••••••"
            deepSeekKeyValid = true
        }
    }
    
    private func validateOpenAIKey() {
        guard !openAIApiKey.isEmpty else { return }
        
        isValidatingOpenAI = true
        openAIKeyValid = false
        
        // Don't validate if it's the placeholder
        if openAIApiKey == "••••••••••••••••••••••••••" {
            isValidatingOpenAI = false
            openAIKeyValid = true
            return
        }
        
        appState.openAIService.validateApiKey(openAIApiKey)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isValidatingOpenAI = false
                
                if case .failure(let error) = completion {
                    logError("OpenAI API key validation failed: \(error)")
                    openAIKeyValid = false
                }
            }, receiveValue: { isValid in
                openAIKeyValid = isValid
            })
            .store(in: &cancellables)
    }
    
    private func validateClaudeKey() {
        guard !claudeApiKey.isEmpty else { return }
        
        isValidatingClaude = true
        claudeKeyValid = false
        
        // Don't validate if it's the placeholder
        if claudeApiKey == "••••••••••••••••••••••••••" {
            isValidatingClaude = false
            claudeKeyValid = true
            return
        }
        
        appState.claudeService.validateApiKey(claudeApiKey)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isValidatingClaude = false
                
                if case .failure(let error) = completion {
                    logError("Claude API key validation failed: \(error)")
                    claudeKeyValid = false
                }
            }, receiveValue: { isValid in
                claudeKeyValid = isValid
            })
            .store(in: &cancellables)
    }
    
    private func validateDeepSeekKey() {
        guard !deepSeekApiKey.isEmpty else { return }
        
        isValidatingDeepSeek = true
        deepSeekKeyValid = false
        
        // Don't validate if it's the placeholder
        if deepSeekApiKey == "••••••••••••••••••••••••••" {
            isValidatingDeepSeek = false
            deepSeekKeyValid = true
            return
        }
        
        appState.deepSeekService.validateApiKey(deepSeekApiKey)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isValidatingDeepSeek = false
                
                if case .failure(let error) = completion {
                    logError("DeepSeek API key validation failed: \(error)")
                    deepSeekKeyValid = false
                }
            }, receiveValue: { isValid in
                deepSeekKeyValid = isValid
            })
            .store(in: &cancellables)
    }
    
    private func saveOpenAIKey() {
        // Don't save if it's the placeholder
        if openAIApiKey != "••••••••••••••••••••••••••" {
            do {
                try keychainManager.saveApiKey(openAIApiKey, for: .chatGPT)
                logInfo("OpenAI API key saved successfully")
            } catch {
                logError("Failed to save OpenAI API key: \(error)")
            }
        }
    }
    
    private func saveClaudeKey() {
        // Don't save if it's the placeholder
        if claudeApiKey != "••••••••••••••••••••••••••" {
            do {
                try keychainManager.saveApiKey(claudeApiKey, for: .claude)
                logInfo("Claude API key saved successfully")
            } catch {
                logError("Failed to save Claude API key: \(error)")
            }
        }
    }
    
    private func saveDeepSeekKey() {
        // Don't save if it's the placeholder
        if deepSeekApiKey != "••••••••••••••••••••••••••" {
            do {
                try keychainManager.saveApiKey(deepSeekApiKey, for: .deepSeek)
                logInfo("DeepSeek API key saved successfully")
            } catch {
                logError("Failed to save DeepSeek API key: \(error)")
            }
        }
    }
}