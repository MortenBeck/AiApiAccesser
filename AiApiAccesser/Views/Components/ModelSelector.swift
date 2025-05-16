import SwiftUI

struct ModelSelector: View {
    @Binding var selectedModel: LLMType
    
    var body: some View {
        Picker("Model", selection: $selectedModel) {
            ForEach(LLMType.allCases) { model in
                Text(model.rawValue)
                    .tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .frame(width: 150)
    }
}
