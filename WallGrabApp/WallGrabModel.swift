import AppKit
import Combine
import Foundation

@MainActor
final class WallGrabModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum DownloadState: Equatable {
        case idle
        case downloading
        case downloaded(URL)
        case failed(String)
    }

    @Published private(set) var assets: [AerialAsset] = []
    @Published var selectedAssetIDs: Set<AerialAsset.ID> = []
    @Published var searchText = ""
    @Published var macOSVersion = "26.0"
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var resourcesURL: URL?
    @Published private(set) var destinationFolder: URL
    @Published private(set) var downloadStates: [AerialAsset.ID: DownloadState] = [:]

    private let service = AerialCatalogService()
    private let destinationKey = "wallgrab.destinationPath"

    init() {
        if let savedPath = UserDefaults.standard.string(forKey: destinationKey) {
            destinationFolder = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            destinationFolder = Self.defaultDestinationFolder
        }

        ensureDestinationFolder()
    }

    var filteredAssets: [AerialAsset] {
        guard !searchText.isEmpty else {
            return assets
        }

        let query = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return assets.filter { asset in
            [asset.displayName, asset.shotID, asset.videoURL.lastPathComponent]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(query)
        }
    }

    var selectedAssets: [AerialAsset] {
        assets.filter { selectedAssetIDs.contains($0.id) }
    }

    var selectedCount: Int {
        selectedAssets.count
    }

    var primarySelectedAsset: AerialAsset? {
        selectedAssets.first ?? filteredAssets.first ?? assets.first
    }

    func loadIfNeeded() async {
        guard assets.isEmpty else {
            return
        }

        await reload()
    }

    func reload() async {
        loadState = .loading

        do {
            let catalog = try await service.fetchCatalog(for: macOSVersion)
            assets = catalog.assets
            resourcesURL = catalog.resourcesURL
            lastUpdated = .now
            loadState = .loaded
            selectedAssetIDs.formIntersection(Set(assets.map(\.id)))
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationFolder
        panel.prompt = "Choose Folder"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        destinationFolder = url
        UserDefaults.standard.set(url.path, forKey: destinationKey)
        ensureDestinationFolder()
    }

    func setDestinationFolder(_ url: URL) {
        destinationFolder = url
        UserDefaults.standard.set(url.path, forKey: destinationKey)
        ensureDestinationFolder()
    }

    func revealDownloadsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([destinationFolder])
    }

    func downloadSelectedAssets() async {
        let targets = selectedAssets.isEmpty ? [primarySelectedAsset].compactMap { $0 } : selectedAssets
        guard !targets.isEmpty else {
            return
        }

        for asset in targets {
            downloadStates[asset.id] = .downloading
        }

        for asset in targets {
            do {
                let destination = try await download(asset: asset)
                downloadStates[asset.id] = .downloaded(destination)
            } catch {
                downloadStates[asset.id] = .failed(error.localizedDescription)
            }
        }
    }

    private func ensureDestinationFolder() {
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
    }

    private func download(asset: AerialAsset) async throws -> URL {
        ensureDestinationFolder()

        let (temporaryURL, response) = try await URLSession.shared.download(from: asset.videoURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let destination = destinationFolder.appendingPathComponent(asset.filename, isDirectory: false)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static var defaultDestinationFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/backgrounds/aerials", isDirectory: true)
    }
}
