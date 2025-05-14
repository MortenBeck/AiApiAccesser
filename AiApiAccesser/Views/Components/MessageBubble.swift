import SwiftUI
import Combine

struct MessageBubble: View {
    let message: Message
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            if message.role == .assistant {
                assistantBubble
            } else {
                Spacer(minLength: 60)
                userBubble
            }
        }
        .padding(.vertical, 4)
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Document attachments if any
            if let attachments = message.attachedDocuments, !attachments.isEmpty {
                HStack {
                    ForEach(attachments) { attachment in
                        Text(attachment.name)
                            .font(.caption)
                            .padding(6)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(6)
                    }
                }
                .padding(.bottom, 4)
            }
            
            Text(message.content.highlightedMarkdown())
                .padding(12)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                .foregroundColor(.white)
        }
        .padding(.leading, 60)
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                // Assistant icon
                modelIcon
                    .font(.system(size: 20))
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 8)
                
                // Message content
                Text(message.content.highlightedMarkdown())
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                    .cornerRadius(16, corners: [.topRight, .bottomRight, .bottomLeft])
                    .foregroundColor(Color(NSColor.textColor))
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private var modelIcon: some View {
        // This should ideally come from the conversation's model type
        // For now we'll just use a default icon
        Image(systemName: "brain")
            .foregroundColor(.purple)
    }
}