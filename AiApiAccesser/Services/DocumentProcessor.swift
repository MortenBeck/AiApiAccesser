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
        // Log that we're attempting to process a document
        logInfo("Attempting to process document at \(url.absoluteString)")
        
        // Check if the file exists and is readable
        if !FileManager.default.fileExists(atPath: url.path) {
            logError("File does not exist at path: \(url.path)")
            return Fail(error: NSError(domain: "DocumentProcessor", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "File not found"])).eraseToAnyPublisher()
        }
        
        // Check if we can read the file
        if !FileManager.default.isReadableFile(atPath: url.path) {
            logError("File is not readable at path: \(url.path)")
            return Fail(error: NSError(domain: "DocumentProcessor", code: 403,
                                      userInfo: [NSLocalizedDescriptionKey: "File is not readable"])).eraseToAnyPublisher()
        }
        
        // Get file attributes for size
        let fileSize: Int
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int ?? 0
            logInfo("File size: \(fileSize) bytes")
        } catch {
            logError("Failed to get file size: \(error)")
            fileSize = 0
        }
        
        let documentType = Document.DocumentType.from(url: url)
        let filename = url.lastPathComponent
        logInfo("Processing document: \(filename) of type: \(documentType)")
        
        return extractContent(from: url, type: documentType)
            .flatMap { content -> AnyPublisher<Document, Error> in
                logInfo("Content extracted successfully, length: \(content.count) characters")
                
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
            .handleEvents(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    logError("Document processing failed: \(error)")
                } else {
                    logInfo("Document processing completed successfully")
                }
            })
            .eraseToAnyPublisher()
    }
    
    private func extractContent(from url: URL, type: Document.DocumentType) -> AnyPublisher<String, Error> {
        logInfo("Extracting content from \(url.lastPathComponent) of type \(type)")
        
        switch type {
        case .pdf:
            return textExtractor.extractTextFromPDF(url: url)
        case .image:
            return imageProcessor.processImage(url: url)
        case .code, .csv, .text:
            return textExtractor.extractTextFromFile(url: url)
        case .unknown:
            // Try to extract as text and if that fails, return empty string
            logInfo("Unknown file type, attempting to extract as text")
            return textExtractor.extractTextFromFile(url: url)
                .catch { error -> AnyPublisher<String, Error> in
                    logError("Text extraction failed for unknown file type: \(error)")
                    return Just("Could not extract content from this file type.")
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
    }
    
    private func splitIfNeeded(document: Document, chunkSize: Int, overlap: Int) -> AnyPublisher<Document, Error> {
        guard let content = document.content, content.count > chunkSize else {
            // Document is small enough, no need to split
            logInfo("Document is small enough, no need to split")
            return Just(document)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        logInfo("Splitting document into chunks (size: \(chunkSize), overlap: \(overlap))")
        return documentSplitter.splitDocument(content: content, chunkSize: chunkSize, overlap: overlap)
            .map { chunks -> Document in
                logInfo("Document split into \(chunks.count) chunks")
                var updatedDocument = document
                updatedDocument.chunks = chunks.enumerated().map { index, chunk in
                    Document.DocumentChunk(content: chunk, index: index)
                }
                return updatedDocument
            }
            .eraseToAnyPublisher()
    }
}
