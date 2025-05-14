import Foundation
import Combine

class DocumentSplitter {
    func splitDocument(content: String, chunkSize: Int, overlap: Int) -> AnyPublisher<[String], Error> {
        return Just(content)
            .tryMap { text -> [String] in
                // Split by paragraphs first
                let paragraphs = text.components(separatedBy: "\n\n")
                var chunks: [String] = []
                var currentChunk = ""
                
                for paragraph in paragraphs {
                    // If adding this paragraph exceeds the chunk size, save current chunk and start a new one
                    if (currentChunk + paragraph).count > chunkSize && !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                        
                        // Start new chunk with overlap from previous chunk if possible
                        if currentChunk.count > overlap {
                            let overlapStartIndex = currentChunk.index(currentChunk.endIndex, offsetBy: -overlap, limitedBy: currentChunk.startIndex) ?? currentChunk.startIndex
                            currentChunk = String(currentChunk[overlapStartIndex...]) + paragraph
                        } else {
                            currentChunk = paragraph
                        }
                    } else {
                        if !currentChunk.isEmpty {
                            currentChunk += "\n\n"
                        }
                        currentChunk += paragraph
                    }
                }
                
                // Add the last chunk if it's not empty
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                return chunks
            }
            .eraseToAnyPublisher()
    }
}