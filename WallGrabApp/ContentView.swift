//
//  ContentView.swift
//  WallGrabApp
//
//  Created by jason van cleave on 4/7/26.
//

import AVKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private struct PreviewItem: Identifiable {
        let id: String
        let title: String
        let url: URL
    }

    @StateObject private var model = WallGrabModel()
    @State private var isPickingDestination = false
    @State private var previewItem: PreviewItem?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $model.searchText, placement: .sidebar)
        .task {
            await model.loadIfNeeded()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await model.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    isPickingDestination = true
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
            }
        }
        .frame(minWidth: 1180, minHeight: 760)
        .fileImporter(
            isPresented: $isPickingDestination,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }

            model.setDestinationFolder(url)
        }
        .sheet(item: $previewItem) { item in
            VideoPreviewSheet(title: item.title, url: item.url)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 18) {
            summaryCard

            List(model.filteredAssets, selection: $model.selectedAssetIDs) { asset in
                AssetRowView(asset: asset, downloadState: model.downloadStates[asset.id] ?? .idle)
                    .tag(asset.id)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.11, blue: 0.16), Color(red: 0.03, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let asset = model.primarySelectedAsset {
            AssetDetailView(
                asset: asset,
                selectedCount: model.selectedCount,
                destinationFolder: model.destinationFolder,
                resourcesURL: model.resourcesURL,
                lastUpdated: model.lastUpdated,
                downloadState: model.downloadStates[asset.id] ?? .idle,
                previewVideo: {
                    previewItem = PreviewItem(id: asset.id, title: asset.displayName, url: asset.videoURL)
                },
                download: { Task { await model.downloadSelectedAssets() } },
                revealDownloadsFolder: model.revealDownloadsFolder,
                chooseDestinationFolder: { isPickingDestination = true }
            )
            .background(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.97, blue: 0.99), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else {
            ContentUnavailableView(
                "No Aerial Selected",
                systemImage: "sparkles.tv",
                description: Text("Refresh the catalog or widen the search to load Apple’s current aerial videos.")
            )
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WallGrab")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Apple aerial browser for macOS")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))

            Divider()
                .overlay(.white.opacity(0.15))

            statusRow(label: "Catalog", value: catalogStatusText)
            statusRow(label: "Assets", value: "\(model.filteredAssets.count) shown")
            statusRow(label: "Selected", value: model.selectedCount == 0 ? "None" : "\(model.selectedCount)")
            statusRow(label: "Save To", value: abbreviatedPath(model.destinationFolder.path))
            statusRow(label: "macOS", value: model.macOSVersion)

            Button {
                isPickingDestination = true
            } label: {
                Label("Change Output Folder", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            Text("Command-click rows to queue multiple videos for download.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func statusRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private var catalogStatusText: String {
        switch model.loadState {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading…"
        case .loaded:
            return "Ready"
        case .failed(let message):
            return message
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

private struct AssetRowView: View {
    let asset: AerialAsset
    let downloadState: WallGrabModel.DownloadState

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: asset.previewImage) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.12))
                        Image(systemName: "sparkles.tv")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .frame(width: 92, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(asset.shotID)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

                Text(statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private var statusText: String {
        switch downloadState {
        case .idle:
            return "Ready"
        case .downloading:
            return "Downloading…"
        case .downloaded:
            return "Saved"
        case .failed(let message):
            return message
        }
    }

    private var statusColor: Color {
        switch downloadState {
        case .idle:
            return .white.opacity(0.6)
        case .downloading:
            return .yellow
        case .downloaded:
            return .green
        case .failed:
            return .red.opacity(0.9)
        }
    }
}

private struct AssetDetailView: View {
    let asset: AerialAsset
    let selectedCount: Int
    let destinationFolder: URL
    let resourcesURL: URL?
    let lastUpdated: Date?
    let downloadState: WallGrabModel.DownloadState
    let previewVideo: () -> Void
    let download: () -> Void
    let revealDownloadsFolder: () -> Void
    let chooseDestinationFolder: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero

                HStack(alignment: .top, spacing: 18) {
                    infoCard
                    actionCard
                }
            }
            .padding(28)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: asset.previewImage) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.33, blue: 0.47), Color(red: 0.06, green: 0.12, blue: 0.19)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 340, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(asset.displayName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(asset.shotID)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))

                if selectedCount > 1 {
                    Text("\(selectedCount) videos selected")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(28)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Asset")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            detailRow("Filename", asset.filename)
            detailRow("Shuffle", asset.includeInShuffle ? "Included" : "Excluded")
            detailRow("Top Level", asset.showInTopLevel ? "Yes" : "No")
            detailRow("Destination", destinationFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))

            if let resourcesURL {
                detailRow("Resources", resourcesURL.lastPathComponent)
            }

            if let lastUpdated {
                detailRow("Updated", lastUpdated.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(cardBackground)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Button(action: download) {
                Label(downloadLabel, systemImage: downloadIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: previewVideo) {
                Label("Play Video", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: revealDownloadsFolder) {
                Label("Reveal Download Folder", systemImage: "folder.badge.gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: chooseDestinationFolder) {
                Label("Choose Output Folder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text(downloadStatusText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(downloadStatusColor)
        }
        .frame(width: 280, alignment: .leading)
        .padding(22)
        .background(cardBackground)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .textSelection(.enabled)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.white)
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
    }

    private var downloadLabel: String {
        if selectedCount > 1 {
            return "Download \(selectedCount) Videos"
        }

        switch downloadState {
        case .downloading:
            return "Downloading…"
        case .downloaded:
            return "Download Again"
        default:
            return "Download Video"
        }
    }

    private var downloadIcon: String {
        switch downloadState {
        case .downloaded:
            return "arrow.down.circle.fill"
        default:
            return "arrow.down.circle"
        }
    }

    private var downloadStatusText: String {
        if selectedCount > 1 {
            return "The selected videos will download into the chosen output folder."
        }

        switch downloadState {
        case .idle:
            return "Ready to save into the selected folder."
        case .downloading:
            return "Fetching the 4K SDR 240 FPS video from Apple."
        case .downloaded(let url):
            return "Saved to \(url.lastPathComponent)"
        case .failed(let message):
            return message
        }
    }

    private var downloadStatusColor: Color {
        switch downloadState {
        case .idle:
            return .secondary
        case .downloading:
            return .orange
        case .downloaded:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct VideoPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let url: URL

    @State private var player: AVPlayer

    init(title: String, url: URL) {
        self.title = title
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.escape, modifiers: [])
            }

            VideoPlayer(player: player)
                .frame(minWidth: 920, minHeight: 540)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(url.absoluteString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
        .padding(24)
        .onAppear {
            player.play()
        }
        .onDisappear {
            player.pause()
        }
    }
}

#Preview {
    ContentView()
}
