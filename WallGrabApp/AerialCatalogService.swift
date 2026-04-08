import Foundation

struct AerialCatalogService {
    enum ServiceError: LocalizedError {
        case badResponse

        var errorDescription: String? {
            switch self {
            case .badResponse:
                return "Apple returned an unexpected response."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCatalog(for macOSVersion: String) async throws -> AerialCatalog {
        let configURL = URL(string: "https://configuration.apple.com/configurations/internetservices/aerials/resources-config-\(normalizedVersion(macOSVersion)).plist")!
        let (configData, configResponse) = try await session.data(from: configURL)
        try validate(response: configResponse)

        let config = try PropertyListDecoder().decode(ResourcesConfiguration.self, from: configData)
        let (archiveData, archiveResponse) = try await session.data(from: config.resourcesURL)
        try validate(response: archiveResponse)

        let archive = TarArchive(data: archiveData)
        let entriesData = try archive.data(for: "entries.json")
        let entries = try JSONDecoder().decode(AerialEntries.self, from: entriesData)

        return AerialCatalog(macOSVersion: macOSVersion, resourcesURL: config.resourcesURL, entries: entries)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServiceError.badResponse
        }
    }

    private func normalizedVersion(_ version: String) -> String {
        let trimmed = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let bare = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        return bare
            .split(whereSeparator: { !$0.isNumber })
            .joined(separator: "-")
    }
}
