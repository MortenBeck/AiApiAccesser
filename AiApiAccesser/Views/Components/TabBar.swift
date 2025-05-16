import SwiftUI
import AppKit

struct TabBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var activeConversationId: UUID?
    
    var body: some View {
        NativeTabBarWrapper(
            conversations: appState.conversations,
            activeConversationId: $activeConversationId,
            createNewConversation: {
                DispatchQueue.main.async {
                    let id = appState.createNewConversation()
                    activeConversationId = id
                }
            },
            deleteConversation: { id in
                handleTabClose(id: id)
            }
        )
        .frame(height: 40)
    }
    
    private func handleTabClose(id: UUID) {
        if let index = appState.conversations.firstIndex(where: { $0.id == id }) {
            if id == activeConversationId {
                DispatchQueue.main.async {
                    if index < appState.conversations.count - 1 {
                        self.activeConversationId = appState.conversations[index + 1].id
                    } else if index > 0 {
                        self.activeConversationId = appState.conversations[index - 1].id
                    } else {
                        self.activeConversationId = nil
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.appState.deleteConversation(id: id)
        }
    }
}

struct NativeTabBarWrapper: NSViewRepresentable {
    var conversations: [Conversation]
    @Binding var activeConversationId: UUID?
    var createNewConversation: () -> Void
    var deleteConversation: (UUID) -> Void
    
    func makeNSView(context: Context) -> NSStackView {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        stackView.wantsLayer = true
        stackView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
        
        updateNSView(stackView, context: context)
        return stackView
    }
    
    func updateNSView(_ stackView: NSStackView, context: Context) {
        // Clear existing views
        stackView.views.forEach { $0.removeFromSuperview() }
        
        // Add tab for each conversation
        for conversation in conversations {
            let tabButton = NSButton()
            tabButton.title = " " + conversation.title  // Add space after icon
            tabButton.bezelStyle = .recessed
            tabButton.isBordered = true
            tabButton.setButtonType(.momentaryPushIn)
            tabButton.tag = conversations.firstIndex(where: { $0.id == conversation.id }) ?? 0
            
            // Set model icon
            let icon = getModelIcon(for: conversation.modelType)
            if let icon = icon {
                let scaledIcon = NSImage(size: NSSize(width: 14, height: 14))
                scaledIcon.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                icon.draw(in: NSRect(x: 0, y: 0, width: 14, height: 14))
                scaledIcon.unlockFocus()
                
                tabButton.image = scaledIcon
                tabButton.imagePosition = .imageLeft
            }
            
            if conversation.id == activeConversationId {
                tabButton.contentTintColor = NSColor.blue
            }
            
            tabButton.target = context.coordinator
            tabButton.action = #selector(Coordinator.tabSelected(_:))
            tabButton.identifier = NSUserInterfaceItemIdentifier(conversation.id.uuidString)
            
            stackView.addArrangedSubview(tabButton)
            
            // Add close button for tab
            let closeButton = NSButton(title: "✕", target: context.coordinator, action: #selector(Coordinator.closeTab(_:)))
            closeButton.tag = tabButton.tag
            closeButton.bezelStyle = .inline
            closeButton.isBordered = false
            closeButton.contentTintColor = NSColor.red
            closeButton.identifier = NSUserInterfaceItemIdentifier(conversation.id.uuidString)
            
            stackView.addArrangedSubview(closeButton)
        }
        
        // Add new tab button
        let newTabButton = NSButton(title: "+ New", target: context.coordinator, action: #selector(Coordinator.newTab))
        newTabButton.bezelStyle = .recessed
        newTabButton.isBordered = true
        
        stackView.addArrangedSubview(newTabButton)
    }
    
    private func getModelIcon(for modelType: LLMType) -> NSImage? {
        let svgString: String
        
        switch modelType {
        case .chatGPT:
            svgString = SVGIcons.openAISVG
        case .claude:
            svgString = SVGIcons.claudeSVG
        case .deepSeek:
            svgString = SVGIcons.deepSeekSVG
        }
        
        let data = svgString.data(using: .utf8)!
        return NSImage(data: data)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NativeTabBarWrapper
        
        init(_ parent: NativeTabBarWrapper) {
            self.parent = parent
        }
        
        @objc func tabSelected(_ sender: NSButton) {
            guard let idString = sender.identifier?.rawValue,
                  let id = UUID(uuidString: idString) else { return }
            
            self.parent.activeConversationId = id
        }
        
        @objc func closeTab(_ sender: NSButton) {
            guard let idString = sender.identifier?.rawValue,
                  let id = UUID(uuidString: idString) else { return }
            
            self.parent.deleteConversation(id)
        }
        
        @objc func newTab() {
            self.parent.createNewConversation()
        }
    }
}
