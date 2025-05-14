import SwiftUI

struct TabBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var activeConversationId: UUID?
    @State private var hoveredConversationId: UUID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(appState.conversations) { conversation in
                    TabBarItem(
                        title: conversation.title,
                        modelType: conversation.modelType,
                        isActive: activeConversationId == conversation.id,
                        isHovered: hoveredConversationId == conversation.id,
                        onClose: {
                            // If this is the active conversation, set activeConversationId to the next available one
                            if activeConversationId == conversation.id {
                                if let index = appState.conversations.firstIndex(where: { $0.id == conversation.id }) {
                                    if index < appState.conversations.count - 1 {
                                        activeConversationId = appState.conversations[index + 1].id
                                    } else if index > 0 {
                                        activeConversationId = appState.conversations[index - 1].id
                                    } else {
                                        activeConversationId = nil
                                    }
                                }
                            }
                            
                            // Delete the conversation
                            appState.deleteConversation(id: conversation.id)
                        }
                    )
                    .onHover { isHovered in
                        hoveredConversationId = isHovered ? conversation.id : nil
                    }
                    .onTapGesture {
                        activeConversationId = conversation.id
                    }
                    .contextMenu {
                        Button("Close") {
                            // Repeat the same logic as onClose
                            if activeConversationId == conversation.id {
                                if let index = appState.conversations.firstIndex(where: { $0.id == conversation.id }) {
                                    if index < appState.conversations.count - 1 {
                                        activeConversationId = appState.conversations[index + 1].id
                                    } else if index > 0 {
                                        activeConversationId = appState.conversations[index - 1].id
                                    } else {
                                        activeConversationId = nil
                                    }
                                }
                            }
                            
                            appState.deleteConversation(id: conversation.id)
                        }
                        
                        Button("Duplicate") {
                            // Create a new conversation with same model type
                            appState.createNewConversation(modelType: conversation.modelType)
                        }
                    }
                }
                
                // New tab button
                Button(action: {
                    let newConversationId = appState.createNewConversation()
                    activeConversationId = newConversationId
                }) {
                    Image(systemName: "plus")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        }
        .frame(height: 40)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
}

struct TabBarItem: View {
    let title: String
    let modelType: LLMType
    let isActive: Bool
    let isHovered: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Model icon
            modelIcon
                .font(.system(size: 14))
            
            // Title
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
            
            if isActive || isHovered {
                // Close button (only shown when active or hovered)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(NSColor.windowBackgroundColor).opacity(0.6) : Color.clear)
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered && !isActive ? Color(NSColor.windowBackgroundColor).opacity(0.3) : Color.clear)
        )
    }
    
    private var modelIcon: some View {
        switch modelType {
        case .chatGPT:
            return Image(systemName: "bubble.left.and.text.bubble.right")
                .foregroundColor(.green)
        case .claude:
            return Image(systemName: "brain")
                .foregroundColor(.purple)
        case .deepSeek:
            return Image(systemName: "magnifyingglass")
                .foregroundColor(.blue)
        }
    }
}
