import SwiftUI

// Model information structure
struct ModelOption {
    let modelId: String
    let displayName: String
    let description: String
    let maxContext: Int
    let defaultMaxTokens: Int
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    
    @State private var settings: [LLMType: LLMSettings] = [:]
    @State private var defaultModel: LLMType = .claude
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title)
                    .padding()
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
            
            TabView {
                generalSettingsView
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                
                ForEach(LLMType.allCases) { model in
                    modelSettingsView(for: model)
                        .tabItem {
                            Label(model.rawValue, systemImage: modelIcon(for: model))
                        }
                }
            }
            .padding()
        }
        .frame(width: 700, height: 500)
        .onAppear {
            // Deep copy settings from app state
            for type in LLMType.allCases {
                settings[type] = appState.llmSettings[type]
            }
            
            // Load default model
            defaultModel = .claude // This should be stored in app state in a real implementation
        }
    }
    
    private var generalSettingsView: some View {
        Form {
            Section(header: Text("Application Settings")) {
                Toggle("Auto-save conversations", isOn: .constant(true))
                    .disabled(true) // Always enabled for now
                
                HStack {
                    Text("Default LLM")
                    Spacer()
                    ModelSelector(selectedModel: $defaultModel)
                }
                
                HStack {
                    Text("UI Theme")
                    Spacer()
                    Text("Dark Mode")
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Performance")) {
                Toggle("Cache responses locally", isOn: .constant(true))
                    .disabled(true)
                
                Toggle("Enable document processing in background", isOn: .constant(true))
                    .disabled(true)
            }
        }
    }
    
    private func modelSettingsView(for model: LLMType) -> some View {
        let settings = Binding<LLMSettings>(
            get: { self.settings[model] ?? LLMSettings.defaultSettings(for: model) },
            set: { self.settings[model] = $0 }
        )
        
        return Form {
            Section(header: Text("Model Selection")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Model", selection: Binding(
                        get: { settings.wrappedValue.modelName },
                        set: { settings.wrappedValue.modelName = $0 }
                    )) {
                        ForEach(modelOptions(for: model), id: \.modelId) { option in
                            Text(option.displayName).tag(option.modelId)
                        }
                    }
                    
                    if let selectedModelInfo = getModelInfo(model: model, modelId: settings.wrappedValue.modelName) {
                        Text(selectedModelInfo.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Max Context Size: \(selectedModelInfo.maxContext) tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Response Settings")) {
                VStack(alignment: .leading) {
                    Text("Temperature: \(settings.wrappedValue.temperature, specifier: "%.2f")")
                    Slider(value: Binding(
                        get: { settings.wrappedValue.temperature },
                        set: { settings.wrappedValue.temperature = $0 }
                    ), in: 0...1, step: 0.05)
                    
                    Text("Lower values produce more deterministic outputs, higher values more creative")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("Max Tokens: \(settings.wrappedValue.maxTokens)")
                    Slider(value: Binding(
                        get: { Double(settings.wrappedValue.maxTokens) },
                        set: { settings.wrappedValue.maxTokens = Int($0) }
                    ), in: 100...8000, step: 100)
                    
                    Text("Maximum length of generated responses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("System Prompt")) {
                TextEditor(text: Binding(
                    get: { settings.wrappedValue.extraSystemPrompt },
                    set: { settings.wrappedValue.extraSystemPrompt = $0 }
                ))
                .frame(height: 100)
                .font(.system(.body, design: .monospaced))
                
                Text("Additional instructions provided to the model for all conversations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Document Processing")) {
                VStack(alignment: .leading) {
                    Text("Chunk Size: \(settings.wrappedValue.documentChunkSize)")
                    Slider(value: Binding(
                        get: { Double(settings.wrappedValue.documentChunkSize) },
                        set: { settings.wrappedValue.documentChunkSize = Int($0) }
                    ), in: 500...8000, step: 500)
                    
                    Text("Size of text chunks when processing large documents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("Chunk Overlap: \(settings.wrappedValue.documentOverlap)")
                    Slider(value: Binding(
                        get: { Double(settings.wrappedValue.documentOverlap) },
                        set: { settings.wrappedValue.documentOverlap = Int($0) }
                    ), in: 0...500, step: 10)
                    
                    Text("Overlap between adjacent chunks to maintain context")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Usage Limitations")) {
                Toggle("Enable Rate Limiting", isOn: Binding(
                    get: { settings.wrappedValue.enableRateLimit },
                    set: { settings.wrappedValue.enableRateLimit = $0 }
                ))
                
                if settings.wrappedValue.enableRateLimit {
                    Stepper(
                        "Max Requests per Minute: \(settings.wrappedValue.maxRequestsPerMinute)",
                        value: Binding(
                            get: { Double(settings.wrappedValue.maxRequestsPerMinute) },
                            set: { settings.wrappedValue.maxRequestsPerMinute = Int($0) }
                        ),
                        in: 1...20
                    )
                    
                    Text("Limits the rate of API calls to avoid rate limit errors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Enable Token Budget", isOn: Binding(
                    get: { settings.wrappedValue.enableTokenBudget },
                    set: { settings.wrappedValue.enableTokenBudget = $0 }
                ))
                
                if settings.wrappedValue.enableTokenBudget {
                    VStack(alignment: .leading) {
                        Text("Daily Token Budget: \(settings.wrappedValue.dailyTokenBudget)")
                        Slider(value: Binding(
                            get: { Double(settings.wrappedValue.dailyTokenBudget) },
                            set: { settings.wrappedValue.dailyTokenBudget = Int($0) }
                        ), in: 10000...1000000, step: 10000)
                        
                        Text("Maximum tokens to use per day to control costs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button("Reset to Default") {
                self.settings[model] = LLMSettings.defaultSettings(for: model)
            }
            .padding(.top)
        }
    }
    
    private func modelOptions(for type: LLMType) -> [ModelOption] {
        switch type {
        case .chatGPT:
            return [
                ModelOption(
                    modelId: "gpt-4o",
                    displayName: "GPT-4o",
                    description: "Latest OpenAI model with optimal performance for a variety of tasks",
                    maxContext: 128000,
                    defaultMaxTokens: 4000
                ),
                ModelOption(
                    modelId: "gpt-4",
                    displayName: "GPT-4",
                    description: "Previous generation flagship model with strong reasoning",
                    maxContext: 8192,
                    defaultMaxTokens: 2000
                ),
                ModelOption(
                    modelId: "gpt-3.5-turbo",
                    displayName: "GPT-3.5 Turbo",
                    description: "Faster, more cost-effective model for simpler tasks",
                    maxContext: 16385,
                    defaultMaxTokens: 1000
                )
            ]
        case .claude:
            return [
                ModelOption(
                    modelId: "claude-3-7-sonnet-20250219",
                    displayName: "Claude 3.7 Sonnet",
                    description: "Latest high-performance Anthropic model with extended reasoning",
                    maxContext: 200000,
                    defaultMaxTokens: 4000
                ),
                ModelOption(
                    modelId: "claude-3-opus",
                    displayName: "Claude 3 Opus",
                    description: "Highest capability Claude model with excellent reasoning",
                    maxContext: 200000,
                    defaultMaxTokens: 4000
                ),
                ModelOption(
                    modelId: "claude-3-sonnet",
                    displayName: "Claude 3 Sonnet",
                    description: "Balanced performance model",
                    maxContext: 200000,
                    defaultMaxTokens: 4000
                ),
                ModelOption(
                    modelId: "claude-3-haiku",
                    displayName: "Claude 3 Haiku",
                    description: "Fastest Claude model for simpler tasks",
                    maxContext: 200000,
                    defaultMaxTokens: 2000
                )
            ]
        case .deepSeek:
            return [
                ModelOption(
                    modelId: "deepseek-coder",
                    displayName: "DeepSeek Coder",
                    description: "Specialized for code generation and understanding",
                    maxContext: 32768,
                    defaultMaxTokens: 4000
                ),
                ModelOption(
                    modelId: "deepseek-chat",
                    displayName: "DeepSeek Chat",
                    description: "General purpose chat model",
                    maxContext: 32768,
                    defaultMaxTokens: 4000
                )
            ]
        }
    }
    
    // Helper to get model info
    private func getModelInfo(model: LLMType, modelId: String) -> ModelOption? {
        return modelOptions(for: model).first { $0.modelId == modelId }
    }
    
    private func modelIcon(for model: LLMType) -> String {
        switch model {
        case .chatGPT:
            return "bubble.left.and.text.bubble.right"
        case .claude:
            return "brain"
        case .deepSeek:
            return "magnifyingglass"
        }
    }
    
    private func saveSettings() {
        // Update app state settings
        for (type, modelSettings) in settings {
            appState.llmSettings[type] = modelSettings
        }
        
        // Save to persistence
        appState.saveSettings()
        
        // For future implementation: save default model to AppState
        // appState.defaultModel = defaultModel
    }
}
