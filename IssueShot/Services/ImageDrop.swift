import AppKit
import UniformTypeIdentifiers

/// ドラッグ＆ドロップで渡された画像を読む。
/// Finder のファイル、ブラウザや写真アプリの画像、macOS のスクリーンショットのサムネイル（ファイルプロミス）、
/// 画像の URL のどれでも受け取れるようにする。
@MainActor
enum ImageDrop {
    static let acceptedTypes: [UTType] = [.fileURL, .image, .url]

    /// 最初に画像として読めたものを返す
    static func loadImage(from providers: [NSItemProvider]) async -> CGImage? {
        for provider in providers {
            for data in await candidates(from: provider) {
                if let image = ImageCodec.load(data) { return image }
            }
        }
        return nil
    }

    private static func candidates(from provider: NSItemProvider) async -> [Data] {
        var results: [Data] = []
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await loadURL(provider, type: .fileURL),
           let data = try? Data(contentsOf: url) {
            results.append(data)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let data = await loadData(provider, type: .image) {
                results.append(data)
            } else if let data = await loadFile(provider, type: .image) {
                results.append(data)
            }
        }
        if results.isEmpty,
           provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await loadURL(provider, type: .url),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            results.append(data)
        }
        return results
    }

    private static func loadData(_ provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// ファイルプロミスは一時ファイルとして渡され、コールバックを抜けると消えるので中で読み切る。
    private static func loadFile(_ provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                continuation.resume(returning: url.flatMap { try? Data(contentsOf: $0) })
            }
        }
    }

    private static func loadURL(_ provider: NSItemProvider, type: UTType) async -> URL? {
        guard let data = await loadData(provider, type: type) else { return nil }
        return URL(dataRepresentation: data, relativeTo: nil)
    }
}
