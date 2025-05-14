import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var activeConversationId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Debug info to show state
            Text("Active ID: \(activeConversationId?.uuidString ?? "nil") | Count: \(appState.conversations.count)")
                .font(.caption)
                .padding(4)
                .background(Color.black)
                .foregroundColor(.white)
            
            // Tab bar
            TabBar(activeConversationId: $activeConversationId)
                .environmentObject(appState)
            
            // Main content area
            if let conversationId = activeConversationId,
               let conversation = appState.conversations.first(where: { $0.id == conversationId }) {
                ChatView(conversation: conversation)
                    .id(conversationId) // Force new view when changing conversations
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
                        appState.showAPIManagement = true
                    }) {
                        Image(systemName: "key.fill")
                            .help("API Management")
                    }
                    
                    Button(action: {
                        appState.showUsageMonitor = true
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .help("Usage Monitor")
                    }
                    
                    Button(action: {
                        appState.showSettings = true
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
            if activeConversationId == nil && !appState.conversations.isEmpty {
                activeConversationId = appState.conversations[0].id
                print("Setting initial active ID to: \(String(describing: activeConversationId))")
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
                        let id = appState.createNewConversation(modelType: model)
                        print("New conversation ID: \(id)")
                        activeConversationId = id
                        print("Active ID updated to: \(String(describing: activeConversationId))")
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
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func modelIcon(for model: LLMType) -> some View {
        switch model {
        case .chatGPT:
            return Image(systemName: "bubble.left.and.text.bubble.right")
        case .claude:
            return Image(systemName: "brain")
        case .deepSeek:
            return Image(systemName: "magnifyingglass")
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
