import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try url.bookmarkData()
var stale = false
let resolved = try URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], bookmarkDataIsStale: &stale)
guard resolved.standardizedFileURL == url.standardizedFileURL, !stale else {
    fatalError("Finder background bookmark did not resolve to the packaged image")
}
FileHandle.standardOutput.write(data)
