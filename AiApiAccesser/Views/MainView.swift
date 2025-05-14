import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var activeConversationId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBar(activeConversationId: $activeConversationId)
            
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
        .onAppear {
            activeConversationId = appState.activeConversationId
        }
        .onChange(of: activeConversationId) { oldValue, newValue in
            appState.activeConversationId = newValue
        }
        .onChange(of: appState.activeConversationId) { oldValue, newValue in
            activeConversationId = newValue
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
                        appState.createNewConversation(modelType: model)
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
