import Foundation
import UIKit

enum TryOnError: LocalizedError {
    case invalidImage
    case missingAPIKey
    case apiError(statusCode: Int)
    case invalidResponse
    case renderLimitReached

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .missingAPIKey: return "Try-on API key not configured."
        case .apiError(let code): return "Try-on service error (\(code)). Please try again."
        case .invalidResponse: return "Could not generate the try-on image."
        case .renderLimitReached: return "You've reached your monthly try-on limit."
        }
    }
}

actor TryOnService {
    private var apiKey: String {
        APIKeyManager.shared.pixelcutAPIKey ?? ""
    }

    func renderTryOn(personImage: UIImage, garmentImage: UIImage) async throws -> UIImage {
        guard !apiKey.isEmpty else { throw TryOnError.missingAPIKey }

        guard let personData = personImage.jpegData(compressionQuality: 0.9),
              let garmentData = garmentImage.jpegData(compressionQuality: 0.9) else {
            throw TryOnError.invalidImage
        }

        let boundary = UUID().uuidString
        var body = Data()

        func appendField(name: String, fileName: String, data: Data) {
            let header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\nContent-Type: image/jpeg\r\n\r\n"
            if let headerData = header.data(using: .utf8) {
                body.append(headerData)
            }
            body.append(data)
            if let newline = "\r\n".data(using: .utf8) {
                body.append(newline)
            }
        }

        appendField(name: "person_image", fileName: "person.jpg", data: personData)
        appendField(name: "garment_image", fileName: "garment.jpg", data: garmentData)

        if let closing = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(closing)
        }

        guard let url = URL(string: "https://api.pixelcut.ai/v1/try-on") else {
            throw TryOnError.apiError(statusCode: 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.apiError(statusCode: 0)
        }
        guard httpResponse.statusCode == 200 else {
            throw TryOnError.apiError(statusCode: httpResponse.statusCode)
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
