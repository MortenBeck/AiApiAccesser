import SwiftUI
import Combine

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var conversation: Conversation
    @State private var userInput = ""
    @State private var attachedDocuments: [Document] = []
    @State private var isProcessingMessage = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showDocumentPicker = false
    @State private var showModelSelector = false
    
    private let documentProcessor = DocumentProcessor()
    
    init(conversation: Conversation) {
        _conversation = State(initialValue: conversation)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
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
                allowedContentTypes: [.pdf, .text, .plainText, .image, .png, .jpeg],
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
                // Text input
                TextField("Type your message here...", text: $userInput, axis: .vertical)
                    .lineLimit(5)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
                
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
                processDocument(at: url)
            }
        } catch {
            logError("Document selection failed: \(error)")
        }
    }
    
    private func processDocument(at url: URL) {
        documentProcessor.processDocument(at: url)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Failed to process document: \(error)")
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
        
        // Get the appropriate LLM service
        let service = appState.getServiceForType(conversation.modelType)
        
        // Send message to LLM
        service.sendMessage(messages: conversation.messages, documents: attachedDocuments)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isProcessingMessage = false
                
                if case .failure(let error) = completion {
                    logError("Failed to get response: \(error)")
                    
                    // Add error message
                    let errorMessage = Message.assistantMessage(
                        content: "Sorry, there was an error processing your request: \(error.localizedDescription)"
                    )
                    
                    var errorConversation = self.conversation
                    errorConversation.addMessage(errorMessage)
                    
                    // Save and update
                    self.appState.saveConversation(errorConversation)
                    self.conversation = errorConversation
                }
                
                // Clear attached documents after sending
                self.attachedDocuments = []
                
            }, receiveValue: { response in
                // Create assistant message
                let assistantMessage = Message.assistantMessage(content: response)
                
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
