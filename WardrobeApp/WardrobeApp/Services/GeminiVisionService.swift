import Foundation
import UIKit

// MARK: - Response Types

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

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

private struct GeminiPart: Codable {
    let text: String?
}

enum GeminiError: LocalizedError {
    case invalidImage
    case missingAPIKey
    case invalidURL
    case apiError(statusCode: Int)
    case noResponse
    case malformedJSON

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .missingAPIKey: return "Gemini API key not configured."
        case .invalidURL: return "Invalid API configuration."
        case .apiError(let code): return "Auto-tagging service error (\(code))."
        case .noResponse: return "No response from tagging service."
        case .malformedJSON: return "Auto-tagging unavailable, please tag manually."
        }
    }
}

// MARK: - Service

actor GeminiVisionService {
    private var apiKey: String {
        APIKeyManager.shared.geminiAPIKey ?? ""
    }

    func tagSingleItem(image: UIImage) async throws -> GeminiTagResult {
        AppLog.api.info("Gemini: Starting single item tagging")
        guard !apiKey.isEmpty else {
            AppLog.api.error("Gemini: API key missing")
            throw GeminiError.missingAPIKey
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            AppLog.api.error("Gemini: Failed to compress image to JPEG")
            throw GeminiError.invalidImage
        }

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

        let data = try await callGemini(imageData: imageData, prompt: prompt, maxTokens: 500)
        return try JSONDecoder().decode(GeminiTagResult.self, from: data)
    }

    func detectBatchItems(image: UIImage) async throws -> [GeminiBatchItem] {
        AppLog.api.info("Gemini: Starting batch item detection")
        guard !apiKey.isEmpty else {
            AppLog.api.error("Gemini: API key missing")
            throw GeminiError.missingAPIKey
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.invalidImage
        }

        let prompt = """
        Identify each individual clothing item in this image. For each item return: \
        bounding box coordinates (as x, y, width, height in normalized 0-1 values), \
        category (top/bottom/dress/outerwear/shoes/accessory), primary color, \
        secondary color if present, pattern (solid/striped/plaid/floral/graphic/other), \
        material estimate (denim/knit/cotton/silk/leather/synthetic/unknown), \
        formality (casual/smart_casual/formal). Return as JSON object with an "items" array.
        """

        let data = try await callGemini(imageData: imageData, prompt: prompt, maxTokens: 2000)
        let result = try JSONDecoder().decode(GeminiBatchResult.self, from: data)
        return result.items
    }

    // MARK: - Private

    private func callGemini(imageData: Data, prompt: String, maxTokens: Int) async throws -> Data {
        let base64Image = imageData.base64EncodedString()

        let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(encodedKey)") else {
            throw GeminiError.invalidURL
        }

        let requestBody: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                ]
            ]],
            "generationConfig": ["temperature": 0.1, "maxOutputTokens": maxTokens]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        AppLog.api.debug("Gemini: Sending request with \(imageData.count) bytes image data")
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLog.api.error("Gemini: Invalid HTTP response")
            throw GeminiError.apiError(statusCode: 0)
        }

        AppLog.api.info("Gemini: Response status \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            AppLog.api.error("Gemini: API error with status \(httpResponse.statusCode)")
            throw GeminiError.apiError(statusCode: httpResponse.statusCode)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            AppLog.api.error("Gemini: No text in response candidates")
            throw GeminiError.noResponse
        }
        AppLog.api.debug("Gemini: Got response text (\(text.count) chars)")

        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiError.malformedJSON
        }

        return jsonData
    }
}
