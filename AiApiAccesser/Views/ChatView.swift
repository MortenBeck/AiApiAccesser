import Combine
import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var conversation: Conversation
    @State private var userInput = ""
    @State private var textHeight: CGFloat = 40 // Default minimum height
    @State private var attachedDocuments: [Document] = []
    @State private var isProcessingMessage = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showDocumentPicker = false
    @State private var showModelSelector = false
    
    private let documentProcessor = DocumentProcessor()
    
    init(conversation: Conversation) {
        _conversation = State(initialValue: conversation)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header with toolbar
            chatHeader
            
            // Message list
            ScrollViewReader { scrollView in
                List {
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                }
                .listStyle(PlainListStyle())
                .onChange(of: conversation.messages.count) { oldCount, newCount in
                    // Scroll to bottom when new message added
                    if let lastMessage = conversation.messages.last {
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Input area
            inputArea
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var chatHeader: some View {
        HStack {
            // Model selector
            ModelSelector(selectedModel: Binding(
                get: { conversation.modelType },
                set: { newValue in
                    conversation.modelType = newValue
                    appState.saveConversation(conversation)
                }
            ))
            
            Spacer()
            
            // Document picker
            Button(action: {
                showDocumentPicker = true
            }) {
                Image(systemName: "paperclip")
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut("o", modifiers: [.command])
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf, .text, .plainText, .image, .png, .jpeg, .item],
                allowsMultipleSelection: true
            ) { result in
                handleDocumentSelection(result)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private var inputArea: some View {
        VStack(spacing: 8) {
            // Attached documents
            if !attachedDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachedDocuments) { document in
                            DocumentThumbnail(document: document, onRemove: {
                                attachedDocuments.removeAll { $0.id == document.id }
                            })
                            .frame(width: 200)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 60)
                .padding(.top, 8)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Auto-sizing text editor
                AutoSizingTextEditor(text: $userInput, onHeightChange: { height in
                    textHeight = max(40, min(height, 120)) // Constrain between min 40 and max 120
                })
                .frame(height: textHeight)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                .cornerRadius(12)
                .overlay(
                    // Placeholder text when input is empty
                    Group {
                        if userInput.isEmpty {
                            Text("Type your message here... (Shift+Enter for new line)")
                                .foregroundColor(.gray)
                                .padding(.leading, 12)
                                .padding(.top, 10)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
                .onKeyPress(.return) {
                    if NSEvent.modifierFlags.contains(.shift) {
                        // Add a new line with Shift+Enter
                        userInput += "\n"
                        return .handled
                    } else if !userInput.trimmingCharacters().isEmpty || !attachedDocuments.isEmpty {
                        // Send message with Enter (if we have content)
                        sendMessage()
                        return .handled
                    }
                    return .ignored
                }
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(userInput.trimmingCharacters().isEmpty && attachedDocuments.isEmpty ? .gray : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(userInput.trimmingCharacters().isEmpty && attachedDocuments.isEmpty || isProcessingMessage)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            
            for url in urls {
                // Ensure we have security-scoped access to the file
                guard url.startAccessingSecurityScopedResource() else {
                    // Using DispatchQueue.main.async to modify state
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to access file: \(url.lastPathComponent). Permission denied."
                        self.showError = true
                    }
                    continue
                }
                
                processDocument(at: url)
                
                // Important: Release the security-scoped resource
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        } catch {
            // Using DispatchQueue.main.async to modify state
            DispatchQueue.main.async {
                self.errorMessage = "Failed to select document: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
    
    private func processDocument(at url: URL) {
        documentProcessor.processDocument(at: url)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to process document: \(error)")
                    errorMessage = "Failed to process document: \(error.localizedDescription)"
                    showError = true
                }
            }, receiveValue: { document in
                self.attachedDocuments.append(document)
            })
            .store(in: &cancellables)
    }
    
    private func sendMessage() {
        guard !userInput.trimmingCharacters().isEmpty || !attachedDocuments.isEmpty else { return }
        
        isProcessingMessage = true
        
        // Create user message
        let attachedDocumentReferences = attachedDocuments.map { document in
            Message.AttachedDocument(documentId: document.id, name: document.filename)
        }
        
        let userMessage = Message.userMessage(
            content: userInput,
            attachedDocuments: attachedDocumentReferences
        )
        
        var updatedConversation = conversation
        updatedConversation.addMessage(userMessage)
        
        // Save conversation with user message
        appState.saveConversation(updatedConversation)
        
        // Update local state
        conversation = updatedConversation
        userInput = ""
        textHeight = 40 // Reset text height to minimum
        
        // Get the appropriate LLM service
        let service = appState.getServiceForType(conversation.modelType)
        
        // Send message to LLM with usage tracking
        service.sendMessageWithTracking(messages: conversation.messages, documents: attachedDocuments, appState: appState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isProcessingMessage = false
                
                if case .failure(let error) = completion {
                    logError("Failed to get response: \(error)")
                    
                    // Add error message
                    let errorMessageText = "Sorry, there was an error processing your request: \(error.localizedDescription)"
                    let errorMessage = Message.assistantMessage(content: errorMessageText)
                    
                    var errorConversation = self.conversation
                    errorConversation.addMessage(errorMessage)
                    
                    // Save and update
                    self.appState.saveConversation(errorConversation)
                    self.conversation = errorConversation
                }
                
                // Clear attached documents after sending
                self.attachedDocuments = []
                
            }, receiveValue: { response in
                // Create assistant message with current model type
                let assistantMessage = Message.assistantMessage(
                    content: response,
                    modelType: self.conversation.modelType
                )
                
                var responseConversation = self.conversation
                responseConversation.addMessage(assistantMessage)
                
                // Save conversation with assistant response
                self.appState.saveConversation(responseConversation)
                
                // Update local state
                self.conversation = responseConversation
            })
            .store(in: &cancellables)
    }
}

// Auto-sizing text editor component
struct AutoSizingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onHeightChange: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = true
        
        // Disable scrolling - we want to expand instead
        scrollView.hasVerticalScroller = false
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        // Only update if text changed externally (not from user typing)
        if textView.string != text {
            textView.string = text
        }
        
        // Calculate height based on text content
        calculateHeight(textView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func calculateHeight(_ textView: NSTextView) {
        // Get the text height
        let layoutManager = textView.layoutManager!
        layoutManager.ensureLayout(for: textView.textContainer!)
        
        let height = layoutManager.usedRect(for: textView.textContainer!).height + textView.textContainerInset.height * 2
        onHeightChange(height)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoSizingTextEditor
        
        init(_ parent: AutoSizingTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Update binding
            parent.text = textView.string
            
            // Recalculate height
            parent.calculateHeight(textView)
        }
    }
}
