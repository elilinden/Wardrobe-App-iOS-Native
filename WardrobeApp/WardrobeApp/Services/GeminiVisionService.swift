import Foundation
import UIKit

struct GeminiTagResult: Codable {
    let category: String
    let subcategory: String
    let primaryColor: String
    let secondaryColor: String?
    let pattern: String
    let materialEstimate: String
    let formality: String
    let season: [String]

    enum CodingKeys: String, CodingKey {
        case category, subcategory, pattern, formality, season
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case materialEstimate = "material_estimate"
    }
}

struct GeminiBatchResult: Codable {
    let items: [GeminiBatchItem]
}

struct GeminiBatchItem: Codable {
    let boundingBox: BoundingBox
    let category: String
    let primaryColor: String
    let secondaryColor: String?
    let pattern: String
    let materialEstimate: String
    let formality: String

    enum CodingKeys: String, CodingKey {
        case category, pattern, formality
        case boundingBox = "bounding_box"
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case materialEstimate = "material_estimate"
    }
}

struct BoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

actor GeminiVisionService {
    private let apiKey: String

    init() {
        self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            ?? Bundle.main.infoDictionary?["GeminiAPIKey"] as? String
            ?? ""
    }

    func tagSingleItem(image: UIImage) async throws -> GeminiTagResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = """
        Analyze this clothing item photo and return JSON with these fields:
        - category: one of [top, bottom, dress, outerwear, shoes, accessory]
        - subcategory: more specific (e.g. t-shirt, blazer, jeans, sneakers)
        - primary_color: color name
        - secondary_color: color name or null
        - pattern: one of [solid, striped, plaid, floral, graphic, other]
        - material_estimate: one of [denim, knit, cotton, silk, leather, synthetic, unknown]
        - formality: one of [casual, smart_casual, formal, athletic]
        - season: array from [spring, summer, fall, winter, year_round]
        Return only valid JSON. No explanation text.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 500
            ]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw GeminiError.noResponse
        }

        let cleanedJSON = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw GeminiError.malformedJSON
        }

        return try JSONDecoder().decode(GeminiTagResult.self, from: jsonData)
    }

    func detectBatchItems(image: UIImage) async throws -> [GeminiBatchItem] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = """
        Identify each individual clothing item in this image. For each item return: \
        bounding box coordinates (as x, y, width, height in normalized 0-1 values), \
        category (top/bottom/dress/outerwear/shoes/accessory), primary color, \
        secondary color if present, pattern (solid/striped/plaid/floral/graphic/other), \
        material estimate (denim/knit/cotton/silk/leather/synthetic/unknown), \
        formality (casual/smart_casual/formal). Return as JSON object with an "items" array.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 2000
            ]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw GeminiError.noResponse
        }

        let cleanedJSON = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw GeminiError.malformedJSON
        }

        let result = try JSONDecoder().decode(GeminiBatchResult.self, from: jsonData)
        return result.items
    }
}

// MARK: - Gemini API Response Types

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Codable {
    let text: String?
}

enum GeminiError: LocalizedError {
    case invalidImage
    case apiError
    case noResponse
    case malformedJSON

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .apiError: return "Auto-tagging service unavailable."
        case .noResponse: return "No response from tagging service."
        case .malformedJSON: return "Auto-tagging unavailable, please tag manually."
        }
    }
}
