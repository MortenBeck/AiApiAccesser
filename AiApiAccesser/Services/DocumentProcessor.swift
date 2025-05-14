import Foundation
import PDFKit
import UniformTypeIdentifiers
import Combine
import SwiftUI


class DocumentProcessor {
    private let textExtractor: TextExtractor
    private let documentSplitter: DocumentSplitter
    private let imageProcessor: ImageProcessor
    
    init(textExtractor: TextExtractor = TextExtractor(),
         documentSplitter: DocumentSplitter = DocumentSplitter(),
         imageProcessor: ImageProcessor = ImageProcessor()) {
        self.textExtractor = textExtractor
        self.documentSplitter = documentSplitter
        self.imageProcessor = imageProcessor
    }
    
    func processDocument(at url: URL) -> AnyPublisher<Document, Error> {
        // Get file attributes for size
        let fileSize: Int
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int ?? 0
        } catch {
            logError("Failed to get file size: \(error)")
            fileSize = 0
        }
        
        let documentType = Document.DocumentType.from(url: url)
        let filename = url.lastPathComponent
        
        return extractContent(from: url, type: documentType)
            .flatMap { content -> AnyPublisher<Document, Error> in
                // Create document with full content
                let document = Document(
                    filename: filename,
                    fileURL: url,
                    fileType: documentType,
                    content: content,
                    fileSize: fileSize
                )
                
                // Split document if needed
                return self.splitIfNeeded(document: document, chunkSize: 4000, overlap: 200)
            }
            .eraseToAnyPublisher()
    }
    
    private func extractContent(from url: URL, type: Document.DocumentType) -> AnyPublisher<String, Error> {
        switch type {
        case .pdf:
            return textExtractor.extractTextFromPDF(url: url)
        case .image:
            return imageProcessor.processImage(url: url)
        case .code, .csv, .text:
            return textExtractor.extractTextFromFile(url: url)
        case .unknown:
            // Try to extract as text and if that fails, return empty string
            return textExtractor.extractTextFromFile(url: url)
                .catch { _ in
                    Just("Could not extract content from this file type.")
                        .setFailureType(to: Error.self)
                }
                .eraseToAnyPublisher()
        }
    }
    
    private func splitIfNeeded(document: Document, chunkSize: Int, overlap: Int) -> AnyPublisher<Document, Error> {
        guard let content = document.content, content.count > chunkSize else {
            // Document is small enough, no need to split
            return Just(document)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return documentSplitter.splitDocument(content: content, chunkSize: chunkSize, overlap: overlap)
            .map { chunks -> Document in
                var updatedDocument = document
                updatedDocument.chunks = chunks.enumerated().map { index, chunk in
                    Document.DocumentChunk(content: chunk, index: index)
                }
                return updatedDocument
            }
            .eraseToAnyPublisher()
    }
}
