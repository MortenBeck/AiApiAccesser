import Foundation
import Combine
import SwiftUI
import SystemConfiguration
import Network

class ClaudeService: LLMService {
   var type: LLMType = .claude
   var settings: LLMSettings
   private let keychainManager: KeychainManager
   
   init(settings: LLMSettings? = nil, keychainManager: KeychainManager = KeychainManager()) {
       self.settings = settings ?? LLMSettings.defaultSettings(for: .claude)
       self.keychainManager = keychainManager
       checkApiEndpointReachability()
   }
   
    func isHostReachable(_ host: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let monitor = NWPathMonitor()
        var isReachable = false
        
        monitor.pathUpdateHandler = { (path: NWPath) in
            isReachable = path.status == .satisfied
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkReachability")
        monitor.start(queue: queue)
        
        // Wait for a result with timeout
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return isReachable
    }
   
   func checkApiEndpointReachability() {
       let url = URL(string: "https://api.anthropic.com/v1/models")!
       var request = URLRequest(url: url)
       request.httpMethod = "HEAD"
       
       let task = URLSession.shared.dataTask(with: request) { _, response, error in
           if let error = error {
               logError("Network error checking Claude API: \(error)")
               return
           }
           
           if let httpResponse = response as? HTTPURLResponse {
               logInfo("Claude API endpoint is reachable, status: \(httpResponse.statusCode)")
           }
       }
       task.resume()
   }
   
   func sendMessage(messages: [Message], documents: [Document]?) -> AnyPublisher<String, Error> {
       guard let apiKey = keychainManager.getApiKey(for: .claude) else {
           return Fail(error: LLMServiceError.noApiKeyFound).eraseToAnyPublisher()
       }
       
       // Check network
       if !isHostReachable("api.anthropic.com") {
           return Fail(error: LLMServiceError.networkError(NSError(domain: "Network", code: -1003,
               userInfo: [NSLocalizedDescriptionKey: "Cannot reach Claude API. Please check your connection."]))).eraseToAnyPublisher()
       }
       
       // Construct request
       let url = URL(string: "https://api.anthropic.com/v1/messages")!
       var request = URLRequest(url: url)
       request.httpMethod = "POST"
       request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
       request.addValue("application/json", forHTTPHeaderField: "Content-Type")
       request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
       
       // Format all messages correctly
       var formattedMessages: [[String: Any]] = []
       
       // Add system content as a separate field
       var systemContent = "You are Claude, a helpful AI assistant."
       if !settings.extraSystemPrompt.isEmpty {
           systemContent += "\n\n" + settings.extraSystemPrompt
       }
       
       // Add documents as context in the system message if present
       if let documents = documents, !documents.isEmpty {
           let documentContent = documents.compactMap { doc -> String? in
               guard let content = doc.content else { return nil }
               return "Document: \(doc.filename)\n\(content)"
           }.joined(separator: "\n\n")
           
           if !documentContent.isEmpty {
               systemContent += "\n\nReview these documents for context:\n\n" + documentContent
           }
       }
       
       // Add all conversation messages
       for message in messages {
           formattedMessages.append([
               "role": message.role.rawValue,
               "content": message.content
           ])
       }
       
       // Create final payload with proper structure
       let payload: [String: Any] = [
           "model": settings.modelName,
           "messages": formattedMessages,
           "system": systemContent,
           "max_tokens": settings.maxTokens,
           "temperature": settings.temperature
       ]
       
       do {
           let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
           request.httpBody = jsonData
           print("Claude API Request: \(String(data: jsonData, encoding: .utf8) ?? "unable to decode")")
       } catch {
           print("Error creating request: \(error)")
           return Fail(error: error).eraseToAnyPublisher()
       }
       
       return URLSession.shared.dataTaskPublisher(for: request)
           .timeout(.seconds(15), scheduler: DispatchQueue.main)  // Add timeout
           .tryMap { data, response -> Data in
               guard let httpResponse = response as? HTTPURLResponse else {
                   throw LLMServiceError.networkError(NSError(domain: "Claude", code: 0,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
               }
               
               print("Response status code: \(httpResponse.statusCode)")
               print("Response headers: \(httpResponse.allHeaderFields)")
               
               let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
               print("Response body: \(responseString)")
               
               if httpResponse.statusCode != 200 {
                   throw LLMServiceError.apiError("Status code: \(httpResponse.statusCode). Response: \(responseString)")
               }
               
               return data
           }
           .decode(type: ClaudeResponse.self, decoder: JSONDecoder())
           .tryMap { response -> String in
               guard let content = response.content.first?.text else {
                   throw LLMServiceError.responseParsingError(NSError(domain: "Claude", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "Missing content"]))
               }
               return content
           }
           .mapError { error -> Error in
               print("Processing error: \(error)")
               return error
           }
           .eraseToAnyPublisher()
   }
   
   func validateApiKey(_ apiKey: String) -> AnyPublisher<Bool, Error> {
       let url = URL(string: "https://api.anthropic.com/v1/models")!
       var request = URLRequest(url: url)
       request.httpMethod = "GET"
       request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
       request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
       
       return URLSession.shared.dataTaskPublisher(for: request)
           .tryMap { data, response -> Bool in
               guard let httpResponse = response as? HTTPURLResponse else {
                   return false
               }
               
               let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
               print("Validation response (\(httpResponse.statusCode)): \(responseString)")
               
               return httpResponse.statusCode == 200
           }
           .mapError { error -> Error in
               print("Validation error: \(error)")
               return error
           }
           .eraseToAnyPublisher()
   }
}

// Response type for decoding
struct ClaudeResponse: Codable {
   struct Content: Codable {
       let text: String
       let type: String
   }
   
   let id: String
   let content: [Content]
   let model: String
   let role: String
   let type: String
}
