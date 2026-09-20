import Foundation
import Testing
@testable import IssueShot

struct CaptureLibraryTests {
    @Test func persistsNotesOCRAndOriginalAcrossReloadAndDeletes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = CaptureLibrary(directory: directory)
        var capture = SavedCapture(id: UUID(), createdAt: Date(), note: "ログイン画面", text: "")
        let original = Data([1, 2, 3])
        try library.save(capture, png: original)
        capture.text = "Sign in エラー"
        capture.annotations = [Annotation(tool: .arrow, color: .red, points: [.zero, CGPoint(x: 1, y: 1)])]
        try library.update(capture)
        let reloaded = try CaptureLibrary(directory: directory).load()
        #expect(reloaded == [capture])
        #expect(reloaded[0].matches("ログイン ERROR") == false)
        #expect(reloaded[0].matches("ログイン sign") == true)
        #expect(reloaded[0].matches("エラー") == true)
        #expect(try Data(contentsOf: library.imageURL(capture.id)) == original)
        try library.delete(capture)
        #expect(try library.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: library.imageURL(capture.id).path))
    }

    @Test func corruptMetadataIsReportedInsteadOfSilentlyLosingHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("broken.json"))
        #expect(throws: (any Error).self) { try CaptureLibrary(directory: directory).load() }
    }

    @Test func missingLibraryStartsEmpty() throws {
        let library = CaptureLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        #expect(try library.load().isEmpty)
    }
}
