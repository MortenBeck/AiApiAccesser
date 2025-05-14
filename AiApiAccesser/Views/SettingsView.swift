import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    
    @State private var settings: [LLMType: LLMSettings] = [:]
    
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
                    ModelSelector(selectedModel: .constant(.claude)) // This should be a global setting in AppState
                }
            }
        }
    }
    
    private func modelSettingsView(for model: LLMType) -> some View {
        let settings = Binding<LLMSettings>(
            get: { self.settings[model] ?? LLMSettings.defaultSettings(for: model) },
            set: { self.settings[model] = $0 }
        )
        
        return Form {
            Section(header: Text("Model Settings")) {
                Picker("Model", selection: Binding(
                    get: { settings.wrappedValue.modelName },
                    set: { settings.wrappedValue.modelName = $0 }
                )) {
                    ForEach(modelOptions(for: model), id: \.self) { modelName in
                        Text(modelName).tag(modelName)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Temperature: \(settings.wrappedValue.temperature, specifier: "%.2f")")
                    Slider(value: Binding(
                        get: { settings.wrappedValue.temperature },
                        set: { settings.wrappedValue.temperature = $0 }
                    ), in: 0...1)
                }
                
                VStack(alignment: .leading) {
                    Text("Max Tokens: \(settings.wrappedValue.maxTokens)")
                    Slider(value: Binding(
                        get: { Double(settings.wrappedValue.maxTokens) },
                        set: { settings.wrappedValue.maxTokens = Int($0) }
                    ), in: 100...8000, step: 100)
                }
            }
            
            Section(header: Text("System Prompt")) {
                TextEditor(text: Binding(
                    get: { settings.wrappedValue.extraSystemPrompt },
                    set: { settings.wrappedValue.extraSystemPrompt = $0 }
                ))
                .frame(height: 100)
            }
            
            Section(header: Text("Document Processing")) {
                VStack(alignment: .leading) {
                    Text("Chunk Size: \(settings.wrappedValue.documentChunkSize)")
                    Slider(value: Binding(
                        get: { Double(settings.wrappedValue.documentChunkSize) },
                        set: { settings.wrappedValue.documentChunkSize = Int($0) }
                    ), in: 500...8000, step: 500)
                }
                
                VStack(alignment: .leading) {
                    Text("Chunk Overlap: \(settings.wrappedValue.documentOverlap)")
                    Slider(value: Binding(
                        get: { Double(settings.wrappedValue.documentOverlap) },
                        set: { settings.wrappedValue.documentOverlap = Int($0) }
                    ), in: 0...500, step: 10)
                }
            }
            
            Button("Reset to Default") {
                self.settings[model] = LLMSettings.defaultSettings(for: model)
            }
            .padding(.top)
        }
    }
    
    private func modelOptions(for type: LLMType) -> [String] {
        switch type {
        case .chatGPT:
            return ["gpt-4o", "gpt-4", "gpt-3.5-turbo"]
        case .claude:
            return ["claude-3-7-sonnet-20250219", "claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        case .deepSeek:
            return ["deepseek-coder", "deepseek-chat"]
        }
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
    }
}