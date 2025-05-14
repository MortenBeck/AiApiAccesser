import Foundation
import UniformTypeIdentifiers

struct Document: Identifiable, Codable {
    var id: UUID
    var filename: String
    var fileURL: URL?
    var fileType: DocumentType
    var content: String?
    var chunks: [DocumentChunk]?
    var fileSize: Int
    var createdAt: Date
    
    enum DocumentType: String, Codable {
        case pdf
        case image
        case code
        case csv
        case text
        case unknown
        
        static func from(url: URL) -> DocumentType {
            if let uti = UTType(filenameExtension: url.pathExtension.lowercased()) {
                if uti.conforms(to: .pdf) {
                    return .pdf
                } else if uti.conforms(to: .image) {
                    return .image
                } else if uti.conforms(to: .sourceCode) || ["py", "ipynb", "js", "ts", "swift", "java", "cpp", "c"].contains(url.pathExtension.lowercased()) {
                    return .code
                } else if url.pathExtension.lowercased() == "csv" {
                    return .csv
                } else if uti.conforms(to: .text) {
                    return .text
                }
            }
            return .unknown
        }
    }
    
    struct DocumentChunk: Identifiable, Codable {
        var id: UUID
        var content: String
        var index: Int
        
        init(id: UUID = UUID(), content: String, index: Int) {
            self.id = id
            self.content = content
            self.index = index
        }
    }
    
    init(id: UUID = UUID(), 
         filename: String, 
         fileURL: URL? = nil, 
         fileType: DocumentType, 
         content: String? = nil, 
         chunks: [DocumentChunk]? = nil, 
         fileSize: Int = 0, 
         createdAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.fileType = fileType
        self.content = content
        self.chunks = chunks
        self.fileSize = fileSize
        self.createdAt = createdAt
    }
}