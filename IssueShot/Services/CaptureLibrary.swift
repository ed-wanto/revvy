import AppKit
import Foundation
import Vision

struct SavedCapture: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var note: String
    var text: String
    var annotations: [Annotation]? = nil

    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        let content = note + "\n" + text + "\n" + createdAt.formatted(date: .numeric, time: .shortened)
        return words.allSatisfy { content.localizedStandardContains(String($0)) }
    }
}

/// A sidecar per image makes a failed metadata write recoverable without overwriting the library.
struct CaptureLibrary {
    let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Revvy/Captures", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func imageURL(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".png") }
    private func metadataURL(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".json") }

    func load() throws -> [SavedCapture] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(SavedCapture.self, from: Data(contentsOf: $0)) }
            .filter { FileManager.default.fileExists(atPath: imageURL($0.id).path) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ capture: SavedCapture, png: Data) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: imageURL(capture.id), options: .atomic)
        do { try update(capture) }
        catch { try? FileManager.default.removeItem(at: imageURL(capture.id)); throw error }
    }

    func update(_ capture: SavedCapture) throws {
        try JSONEncoder().encode(capture).write(to: metadataURL(capture.id), options: .atomic)
    }

    func delete(_ capture: SavedCapture) throws {
        // Metadata first: failed image cleanup never leaves an unusable history entry.
        try FileManager.default.removeItem(at: metadataURL(capture.id))
        try FileManager.default.removeItem(at: imageURL(capture.id))
    }
}

enum CaptureTextRecognition {
    static func recognize(png: Data) async throws -> String {
        try await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(data: png).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }
}
