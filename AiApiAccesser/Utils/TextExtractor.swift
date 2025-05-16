import Foundation
import PDFKit
import Combine

class TextExtractor {
    func extractTextFromPDF(url: URL) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            // Log attempt
            logInfo("Attempting to extract text from PDF: \(url.lastPathComponent)")
            
            // Create a bookmark for the URL to maintain access rights
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                // Store bookmark data if needed for longer access
                UserDefaults.standard.set(bookmarkData, forKey: "LastDocumentBookmark")
            } catch {
                logError("Failed to create bookmark for PDF: \(error)")
                // Continue anyway, this is just a backup approach
            }
            
            guard let pdfDocument = PDFDocument(url: url) else {
                let error = NSError(domain: "TextExtractor", code: 0,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF document"])
                logError("Failed to load PDF document: \(url.lastPathComponent)")
                promise(.failure(error))
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
            
            if extractedText.isEmpty {
                logWarning("Extracted empty text from PDF: \(url.lastPathComponent)")
            } else {
                logInfo("Successfully extracted \(extractedText.count) characters from PDF")
            }
            
            promise(.success(extractedText))
        }.eraseToAnyPublisher()
    }
    
    func extractTextFromFile(url: URL) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            logInfo("Attempting to extract text from file: \(url.lastPathComponent)")
            
            // Create a direct file handle first to test access
            do {
                let fileHandle = try FileHandle(forReadingFrom: url)
                defer { fileHandle.closeFile() }
                
                // If we got here, we have read access, now try to read the content
                do {
                    let data = try Data(contentsOf: url)
                    logInfo("Successfully read \(data.count) bytes from file")
                    
                    // Try to decode as UTF-8
                    if let text = String(data: data, encoding: .utf8) {
                        logInfo("Successfully decoded text using UTF-8 encoding")
                        promise(.success(text))
                        return
                    }
                    
                    // If UTF-8 fails, try other common encodings
                    let encodings: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .utf16, .utf16LittleEndian, .utf16BigEndian]
                    
                    for encoding in encodings {
                        if let text = String(data: data, encoding: encoding) {
                            logInfo("Successfully decoded text using \(encoding) encoding")
                            promise(.success(text))
                            return
                        }
                    }
                    
                    logError("Failed to decode file with known encodings: \(url.lastPathComponent)")
                    promise(.failure(NSError(domain: "TextExtractor", code: 1,
                                           userInfo: [NSLocalizedDescriptionKey: "Failed to decode file with known encodings"])))
                } catch {
                    logError("Failed to read file contents: \(error)")
                    promise(.failure(error))
                }
                
            } catch {
                logError("Failed to open file handle: \(error)")
                
                // Try an alternative approach with String initializer
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    logInfo("Successfully read file content using String initializer")
                    promise(.success(text))
                } catch {
                    logError("All attempts to read file failed: \(error)")
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
}
