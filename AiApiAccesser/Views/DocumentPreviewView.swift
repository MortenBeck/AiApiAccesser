import SwiftUI
import PDFKit
import QuickLook
import Combine

struct DocumentPreviewView: View {
    let document: Document
    
    var body: some View {
        VStack {
            HStack {
                Text(document.filename)
                    .font(.headline)
                
                Spacer()
                
                Text(formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            
            if document.fileType == .pdf {
                PDFPreview(url: document.fileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if document.fileType == .image {
                ImagePreview(url: document.fileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextPreview(content: document.content ?? "No content available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(document.fileSize))
    }
}

struct PDFPreview: NSViewRepresentable {
    let url: URL?
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let url = url, let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}

struct ImagePreview: View {
    let url: URL?
    
    var body: some View {
        if let url = url, let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Text("Image could not be loaded")
                .foregroundColor(.gray)
        }
    }
}

struct TextPreview: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .padding()
        }
    }
}