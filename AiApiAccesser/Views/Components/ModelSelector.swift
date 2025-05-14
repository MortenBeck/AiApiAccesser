import SwiftUI
import Combine

struct ModelSelector: View {
    @Binding var selectedModel: LLMType
    
    var body: some View {
        Picker("Model", selection: $selectedModel) {
            ForEach(LLMType.allCases) { model in
                HStack {
                    modelIcon(for: model)
                        .foregroundColor(modelColor(for: model))
                    
                    Text(model.rawValue)
                }
                .tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .frame(width: 150)
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