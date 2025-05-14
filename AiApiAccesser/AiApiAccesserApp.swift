import SwiftUI
import Combine

@main
struct AiApiAccesserApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .darkModeOnly()
                .onAppear {
                    // Load settings on app launch
                    appState.loadSettings()
                    appState.loadConversations()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    let _ = appState.createNewConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                Button("Settings") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Button("API Management") {
                    appState.showAPIManagement = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
