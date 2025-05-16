import SwiftUI

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
            
            markdownText(message.content)
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
                // Assistant icon based on model type
                if let modelType = message.modelType {
                    modelIcon(for: modelType)
                        .font(.system(size: 20))
                        .frame(width: 30, height: 30)
                        .padding(.trailing, 8)
                } else {
                    // Fallback generic icon if no model type
                    Image(systemName: "brain")
                        .font(.system(size: 20))
                        .frame(width: 30, height: 30)
                        .foregroundColor(.purple)
                        .padding(.trailing, 8)
                }
                
                // Message content
                markdownText(message.content)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                    .cornerRadius(16, corners: [.topRight, .bottomRight, .bottomLeft])
                    .foregroundColor(Color(NSColor.textColor))
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func markdownText(_ content: String) -> some View {
        let attributedString = try? AttributedString(markdown: content)
        return Text(attributedString ?? AttributedString(content))
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
}
