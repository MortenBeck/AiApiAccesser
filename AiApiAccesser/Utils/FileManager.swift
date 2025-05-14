import Foundation
import Combine

extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    func createDirectoryIfNeeded(at url: URL) throws {
        if !directoryExists(at: url) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getTemporaryDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    func getUniqueTemporaryDirectory() -> URL {
        return getTemporaryDirectory().appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}