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
                        isHovered: hoveredConversationId == conversation.id
                    )
                    .onHover { isHovered in
                        hoveredConversationId = isHovered ? conversation.id : nil
                    }
                    .onTapGesture {
                        activeConversationId = conversation.id
                    }
                    .contextMenu {
                        Button("Close") {
                            appState.deleteConversation(id: conversation.id)
                        }
                        
                        Button("Duplicate") {
                            // Create a new conversation with same model type
                            appState.createNewConversation(modelType: conversation.modelType)
                        }
                    }
                }
                
                Button(action: {
                    appState.createNewConversation()
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
                Button(action: {
                    // Will be handled by contextMenu
                }) {
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
