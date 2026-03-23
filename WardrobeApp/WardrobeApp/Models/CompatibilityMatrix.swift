import Foundation

struct CompatibilityMatrix: Codable {
    let neverCombine: [[String]]
    let preferCombine: [[String]]

    enum CodingKeys: String, CodingKey {
        case neverCombine = "never_combine"
        case preferCombine = "prefer_combine"
    }

    static let `default` = CompatibilityMatrix(
        neverCombine: [
            ["formal_shoes", "athletic_shorts"],
            ["ballgown", "sneakers"],
            ["swimwear", "blazer"],
            ["athletic_top", "formal_trousers"]
        ],
        preferCombine: [
            ["blazer", "dress_trousers"],
            ["denim_jeans", "casual_top"],
            ["sneakers", "casual_bottom"]
        ]
    )

    static func load() -> CompatibilityMatrix {
        guard let url = Bundle.main.url(forResource: "compatibility_matrix", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let matrix = try? JSONDecoder().decode(CompatibilityMatrix.self, from: data) else {
            return .default
        }
        return matrix
    }
}
