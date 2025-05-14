import Foundation
import Combine
import Vision
import CoreImage

class ImageProcessor {
    func processImage(url: URL) -> AnyPublisher<String, Error> {
        return recognizeText(in: url)
            .eraseToAnyPublisher()
    }
    
    private func recognizeText(in url: URL) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            guard let image = CIImage(contentsOf: url) else {
                promise(.failure(NSError(domain: "ImageProcessor", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])))
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    promise(.failure(NSError(domain: "ImageProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid observation results"])))
                    return
                }
                
                let recognizedText = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                promise(.success(recognizedText))
            }
            
            request.recognitionLevel = .accurate
            
            do {
                try VNImageRequestHandler(ciImage: image).perform([request])
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}