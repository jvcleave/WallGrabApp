import Foundation

struct AerialCatalog: Sendable {
    let macOSVersion: String
    let resourcesURL: URL
    let entries: AerialEntries

    var assets: [AerialAsset] {
        entries.assets.sorted { lhs, rhs in
            if lhs.showInTopLevel != rhs.showInTopLevel {
                return lhs.showInTopLevel && !rhs.showInTopLevel
            }
            if lhs.preferredOrder != rhs.preferredOrder {
                return lhs.preferredOrder < rhs.preferredOrder
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}

struct ResourcesConfiguration: Decodable, Sendable {
    let resourcesURL: URL

    enum CodingKeys: String, CodingKey {
        case resourcesURL = "resources-url"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawURL = try container.decode(String.self, forKey: .resourcesURL)

        guard let resourcesURL = URL(string: rawURL) else {
            throw DecodingError.dataCorruptedError(
                forKey: .resourcesURL,
                in: container,
                debugDescription: "Invalid resources URL: \(rawURL)"
            )
        }

        self.resourcesURL = resourcesURL
    }
}

struct AerialEntries: Decodable, Sendable {
    let version: Int
    let localizationVersion: String?
    let assets: [AerialAsset]
    let initialAssetCount: Int?
    let categories: [AerialCategory]
}

struct AerialAsset: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let accessibilityLabel: String
    let categories: [String]
    let includeInShuffle: Bool
    let localizedNameKey: String
    let pointsOfInterest: [String: String]
    let preferredOrder: Int
    let previewImage: URL
    let shotID: String
    let showInTopLevel: Bool
    let subcategories: [String]
    let videoURL: URL

    enum CodingKeys: String, CodingKey {
        case id
        case accessibilityLabel
        case categories
        case includeInShuffle
        case localizedNameKey
        case pointsOfInterest
        case preferredOrder
        case previewImage
        case shotID
        case showInTopLevel
        case subcategories
        case videoURL = "url-4K-SDR-240FPS"
    }

    var displayName: String {
        let trimmed = accessibilityLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? shotID : trimmed
    }

    var filename: String {
        let ext = videoURL.pathExtension.isEmpty ? "mov" : videoURL.pathExtension
        return "\(sanitizePathComponent(displayName)) - \(shotID).\(ext)"
    }

    private func sanitizePathComponent(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
        let collapsed = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AerialCategory: Decodable, Hashable, Sendable {
    let id: String
    let preferredOrder: Int
    let representativeAssetID: String?
    let localizedNameKey: String
    let subcategories: [AerialSubcategory]
    let localizedDescriptionKey: String?
    let previewImage: URL?
}

struct AerialSubcategory: Decodable, Hashable, Sendable {
    let id: String
    let previewImage: URL?
    let localizedNameKey: String
    let preferredOrder: Int
    let localizedDescriptionKey: String?
    let representativeAssetID: String?
}
