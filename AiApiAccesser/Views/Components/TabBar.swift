import SwiftUI

struct TabBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var activeConversationId: UUID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Existing conversation tabs
                ForEach(appState.conversations) { conversation in
                    ConversationTab(
                        conversation: conversation,
                        isActive: activeConversationId == conversation.id,
                        onSelect: {
                            activeConversationId = conversation.id
                        },
                        onClose: {
                            handleCloseTab(id: conversation.id)
                        }
                    )
                }
                
                // New tab button - simple and direct
                Button(action: {
                    print("Creating new conversation")
                    let id = appState.createNewConversation()
                    print("New conversation ID: \(id)")
                    activeConversationId = id
                    print("Active ID updated to: \(String(describing: activeConversationId))")
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)
        }
        .frame(height: 40)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private func handleCloseTab(id: UUID) {
        print("Closing tab with ID: \(id)")
        
        // Find the index of the conversation to be closed
        if let index = appState.conversations.firstIndex(where: { $0.id == id }) {
            // Determine the next tab to be active
            if id == activeConversationId {
                if index < appState.conversations.count - 1 {
                    // If not the last tab, select the next one
                    activeConversationId = appState.conversations[index + 1].id
                    print("Setting active to next: \(String(describing: activeConversationId))")
                } else if index > 0 {
                    // If the last tab, select the previous one
                    activeConversationId = appState.conversations[index - 1].id
                    print("Setting active to previous: \(String(describing: activeConversationId))")
                } else {
                    // If it's the only tab, set to nil
                    activeConversationId = nil
                    print("Setting active to nil")
                }
            }
        }
        
        // Delete the conversation
        print("Deleting conversation")
        appState.deleteConversation(id: id)
    }
}

struct ConversationTab: View {
    let conversation: Conversation
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Model icon
            modelIcon
                .font(.system(size: 14))
            
            // Title
            Text(conversation.title)
                .lineLimit(1)
                .truncationMode(.tail)
            
            // Always show close button for simplicity
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.blue.opacity(0.3) : Color(NSColor.windowBackgroundColor).opacity(0.3))
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    private var modelIcon: some View {
        switch conversation.modelType {
        case .chatGPT:
            return AnyView(SVGIcons.openAILogo()
                .frame(width: 14, height: 14))
        case .claude:
            return AnyView(SVGIcons.claudeLogo()
                .frame(width: 14, height: 14))
        case .deepSeek:
            return AnyView(SVGIcons.deepSeekLogo()
                .frame(width: 14, height: 14))
        }
    }
}
