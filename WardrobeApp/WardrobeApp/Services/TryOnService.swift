import Foundation
import UIKit

actor TryOnService {
    private let apiKey: String

    init() {
        self.apiKey = ProcessInfo.processInfo.environment["PIXELCUT_API_KEY"]
            ?? Bundle.main.infoDictionary?["PixelcutAPIKey"] as? String
            ?? ""
    }

    func renderTryOn(personImage: UIImage, garmentImage: UIImage) async throws -> UIImage {
        guard let personData = personImage.jpegData(compressionQuality: 0.9),
              let garmentData = garmentImage.jpegData(compressionQuality: 0.9) else {
            throw TryOnError.invalidImage
        }

        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"person_image\"; filename=\"person.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(personData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"garment_image\"; filename=\"garment.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(garmentData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let url = URL(string: "https://api.pixelcut.ai/v1/try-on")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TryOnError.apiError
        }

        guard let renderedImage = UIImage(data: data) else {
            throw TryOnError.invalidResponse
        }

        return renderedImage
    }

    func renderOutfit(personImage: UIImage, garmentImages: [UIImage]) async throws -> UIImage {
        var currentImage = personImage
        for garment in garmentImages {
            currentImage = try await renderTryOn(personImage: currentImage, garmentImage: garment)
        }
        return currentImage
    }
}

enum TryOnError: LocalizedError {
    case invalidImage
    case apiError
    case invalidResponse
    case renderLimitReached

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .apiError: return "Try-on service unavailable. Please try again."
        case .invalidResponse: return "Could not generate the try-on image."
        case .renderLimitReached: return "You've reached your monthly try-on limit."
        }
    }
}
