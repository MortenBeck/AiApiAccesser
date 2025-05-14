import Foundation
import PDFKit
import Combine

class TextExtractor {
    func extractTextFromPDF(url: URL) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            guard let pdfDocument = PDFDocument(url: url) else {
                promise(.failure(NSError(domain: "TextExtractor", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF document"])))
                return
            }
            
            var extractedText = ""
            for pageIndex in 0..<pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: pageIndex) else { continue }
                
                if let pageText = page.string {
                    extractedText += pageText
                    
                    // Add a newline between pages if not already present
                    if !pageText.hasSuffix("\n") && pageIndex < pdfDocument.pageCount - 1 {
                        extractedText += "\n"
                    }
                }
            }
            
            promise(.success(extractedText))
        }.eraseToAnyPublisher()
    }
    
    func extractTextFromFile(url: URL) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            do {
                let data = try Data(contentsOf: url)
                
                // Try to decode as UTF-8
                if let text = String(data: data, encoding: .utf8) {
                    promise(.success(text))
                    return
                }
                
                // If UTF-8 fails, try other common encodings
                let encodings: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .utf16, .utf16LittleEndian, .utf16BigEndian]
                
                for encoding in encodings {
                    if let text = String(data: data, encoding: encoding) {
                        promise(.success(text))
                        return
                    }
                }
                
                promise(.failure(NSError(domain: "TextExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode file with known encodings"])))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}