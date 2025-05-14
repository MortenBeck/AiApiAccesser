import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Combine

struct DocumentThumbnail: View {
    let document: Document
    let onRemove: (() -> Void)?
    
    var body: some View {
        VStack {
            HStack {
                // Document icon
                documentIcon
                    .font(.system(size: 20))
                    .foregroundColor(documentColor)
                
                // Document name
                Text(document.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // Remove button if provided
                if let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // File size
            Text(formattedFileSize)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private var documentIcon: some View {
        switch document.fileType {
        case .pdf:
            return Image(systemName: "doc.text")
        case .image:
            return Image(systemName: "photo")
        case .code:
            return Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .csv:
            return Image(systemName: "tablecells")
        case .text:
            return Image(systemName: "doc.text")
        case .unknown:
            return Image(systemName: "doc")
        }
    }
    
    private var documentColor: Color {
        switch document.fileType {
        case .pdf:
            return .red
        case .image:
            return .blue
        case .code:
            return .green
        case .csv:
            return .orange
        case .text:
            return .gray
        case .unknown:
            return .gray
        }
    }
    
    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(document.fileSize))
    }
}