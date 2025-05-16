import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var activeConversationId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBar(activeConversationId: $activeConversationId)
                .environmentObject(appState)
                .allowsHitTesting(true)
                .contentShape(Rectangle())
            
            // Main content area
            if let conversationId = activeConversationId,
               let conversation = appState.conversations.first(where: { $0.id == conversationId }) {
                ChatView(conversation: conversation)
                    .id(conversationId) // Force new view when changing conversations
                    .allowsHitTesting(true)
            } else {
                welcomeView
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .darkModeOnly()
        }
        .sheet(isPresented: $appState.showAPIManagement) {
            APIManagementView()
                .darkModeOnly()
        }
        .sheet(isPresented: $appState.showUsageMonitor) {
            UsageMonitorView()
                .darkModeOnly()
                .environmentObject(appState)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 16) {
                    Button(action: {
                        DispatchQueue.main.async {
                            appState.showAPIManagement = true
                        }
                    }) {
                        Image(systemName: "key.fill")
                            .help("API Management")
                    }
                    
                    Button(action: {
                        DispatchQueue.main.async {
                            appState.showUsageMonitor = true
                        }
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .help("Usage Monitor")
                    }
                    
                    Button(action: {
                        DispatchQueue.main.async {
                            appState.showSettings = true
                        }
                    }) {
                        Image(systemName: "gear")
                            .help("Settings")
                    }
                }
            }
        }
        .onAppear {
            print("MainView appeared")
            
            // Initialize activeConversationId with the first conversation if available
            DispatchQueue.main.async {
                if self.activeConversationId == nil && !self.appState.conversations.isEmpty {
                    self.activeConversationId = self.appState.conversations[0].id
                    print("Setting initial active ID to: \(String(describing: self.activeConversationId))")
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Text("Welcome to AiApiAccesser")
                .font(.largeTitle)
            
            Text("Create a new conversation or select an existing one to get started.")
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                ForEach(LLMType.allCases) { model in
                    Button(action: {
                        print("Creating new conversation with model: \(model)")
                        DispatchQueue.main.async {
                            let id = self.appState.createNewConversation(modelType: model)
                            print("New conversation ID: \(id)")
                            self.activeConversationId = id
                            print("Active ID updated to: \(String(describing: self.activeConversationId))")
                        }
                    }) {
                        VStack {
                            modelIcon(for: model)
                                .font(.system(size: 30))
                                .foregroundColor(modelColor(for: model))
                                .padding(.bottom, 4)
                            
                            Text("New \(model.rawValue) Chat")
                        }
                        .frame(width: 150, height: 120)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func modelIcon(for modelType: LLMType) -> some View {
        switch modelType {
        case .chatGPT:
            return AnyView(SVGIcons.openAILogo()
                .frame(width: 30, height: 30))
        case .claude:
            return AnyView(SVGIcons.claudeLogo()
                .frame(width: 30, height: 30))
        case .deepSeek:
            return AnyView(SVGIcons.deepSeekLogo()
                .frame(width: 30, height: 30))
        }
    }
    
    private func modelColor(for model: LLMType) -> Color {
        switch model {
        case .chatGPT:
            return .green
        case .claude:
            return .purple
        case .deepSeek:
            return .blue
        }
    }
}
