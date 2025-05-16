import SwiftUI
import Combine
import SVGIcons

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
            return SVGIcons.openAILogo()
                .frame(width: 20, height: 20)
        case .claude:
            return SVGIcons.claudeLogo()
                .frame(width: 20, height: 20)
        case .deepSeek:
            return SVGIcons.deepSeekLogo()
                .frame(width: 20, height: 20)
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
