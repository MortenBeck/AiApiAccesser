import SwiftUI
import Combine

struct UsageMonitorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Usage Monitoring")
                    .font(.title)
                    .padding()
                
                Spacer()
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Token usage section
                    usageSection(
                        title: "Token Usage",
                        description: "Track the number of tokens used per model"
                    )
                    
                    // Charts for token usage
                    tokenUsageChart
                    
                    Divider()
                    
                    // API call section
                    usageSection(
                        title: "API Calls",
                        description: "Track the number of API calls made per model"
                    )
                    
                    // Charts for API calls
                    apiCallsChart
                    
                    Divider()
                    
                    // Budget status
                    budgetStatusSection
                    
                    Spacer()
                    
                    // Reset buttons
                    HStack {
                        Button("Reset Token Counters") {
                            appState.resetTokenUsage()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        Button("Reset API Call Counters") {
                            appState.resetRequestCounts()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
    }
    
    private func usageSection(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var tokenUsageChart: some View {
        VStack {
            // For each model type, show usage
            ForEach(LLMType.allCases) { type in
                if let settings = appState.llmSettings[type],
                   let modelName = getModelDisplayName(type: type, modelId: settings.modelName) {
                    modelTokenUsageView(
                        modelName: modelName,
                        usage: appState.tokenUsage[settings.modelName] ?? 0,
                        limit: settings.enableTokenBudget ? settings.dailyTokenBudget : nil,
                        color: getModelColor(for: type)
                    )
                }
            }
        }
    }
    
    private var apiCallsChart: some View {
        VStack {
            // For each model type, show API calls
            ForEach(LLMType.allCases) { type in
                if let settings = appState.llmSettings[type],
                   let modelName = getModelDisplayName(type: type, modelId: settings.modelName) {
                    modelAPICallsView(
                        modelName: modelName,
                        count: appState.requestCounts[settings.modelName] ?? 0,
                        limit: settings.enableRateLimit ? settings.maxRequestsPerMinute : nil,
                        color: getModelColor(for: type)
                    )
                }
            }
        }
    }
    
    private var budgetStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Status")
                .font(.headline)
            
            ForEach(LLMType.allCases) { type in
                if let settings = appState.llmSettings[type],
                   let modelName = getModelDisplayName(type: type, modelId: settings.modelName) {
                    
                    if settings.enableTokenBudget {
                        let usage = appState.tokenUsage[settings.modelName] ?? 0
                        let percentage = min(Double(usage) / Double(settings.dailyTokenBudget), 1.0)
                        
                        HStack {
                            Text("\(modelName):")
                                .foregroundColor(getModelColor(for: type))
                            
                            Spacer()
                            
                            Text("\(usage) / \(settings.dailyTokenBudget) tokens")
                                .foregroundColor(percentage > 0.8 ? .red : .primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func modelTokenUsageView(modelName: String, usage: Int, limit: Int?, color: Color) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(modelName)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(usage) tokens")
            }
            
            if let limit = limit {
                let percentage = min(Double(usage) / Double(limit), 1.0)
                
                ProgressView(value: percentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: usageColor(for: percentage)))
                
                HStack {
                    Text("Daily Limit: \(limit) tokens")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .foregroundColor(usageColor(for: percentage))
                }
            } else {
                Text("No limit set")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func modelAPICallsView(modelName: String, count: Int, limit: Int?, color: Color) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(modelName)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(count) calls")
            }
            
            if let limit = limit {
                let percentage = min(Double(count) / Double(limit), 1.0)
                
                ProgressView(value: percentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: usageColor(for: percentage)))
                
                HStack {
                    Text("Rate Limit: \(limit) per minute")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .foregroundColor(usageColor(for: percentage))
                }
            } else {
                Text("No limit set")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func usageColor(for percentage: Double) -> Color {
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func getModelDisplayName(type: LLMType, modelId: String) -> String? {
        // Lookup model display names from model options
        let options = modelOptions(for: type)
        return options.first(where: { $0.modelId == modelId })?.displayName
    }
    
    private func getModelColor(for type: LLMType) -> Color {
        switch type {
        case .chatGPT:
            return .green
        case .claude:
            return .purple
        case .deepSeek:
            return .blue
        }
    }
    
    // Model options - duplicate from SettingsView (in a real app, would be in a shared place)
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
}
