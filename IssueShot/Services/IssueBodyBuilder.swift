import AppKit
import Foundation

/// Issue に載せる実行環境（アプリ・OS・機種・ディスプレイ・撮影日時）
struct ReportEnvironment: Sendable {
    var reporter: String
    var appVersion: String
    var macOSVersion: String
    var hardwareModel: String
    var display: String
    var capturedAt: String

    @MainActor
    static func current(reporter: String) -> ReportEnvironment {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        let display: String
        if let screen = NSScreen.main {
            let frame = screen.frame
            display = "\(Int(frame.width))x\(Int(frame.height)) @\(Int(screen.backingScaleFactor))x"
        } else {
            display = String(localized: "不明")
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"

        return ReportEnvironment(
            reporter: "@\(reporter)",
            appVersion: "Revvy \(version) (\(build))",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hardwareModel: sysctlString("hw.model") ?? String(localized: "不明"),
            display: display,
            capturedAt: formatter.string(from: Date())
        )
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Issue のタイトルと本文を組み立てる
enum IssueBodyBuilder {
    static let maxTitleLength = 60

    static func title(userTitle: String, comment: String) -> String {
        let source = userTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? comment : userTitle
        let singleLine = Masking.mask(source)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !singleLine.isEmpty else { return "[Feedback] \(String(localized: "(本文なし)"))" }
        if singleLine.count > maxTitleLength {
            return "[Feedback] \(singleLine.prefix(maxTitleLength))..."
        }
        return "[Feedback] \(singleLine)"
    }

    static func body(
        comment: String,
        environment: ReportEnvironment,
        screenshot: UploadedScreenshot?,
        screenshotError: String?
    ) -> String {
        let screenshotSection: String
        if let screenshot {
            let branchNote = String(localized: "（`\(screenshot.branch)` ブランチ）")
            screenshotSection = """
            ![screenshot](\(screenshot.rawUrl.absoluteString))

            [\(screenshot.path)](\(screenshot.htmlUrl.absoluteString)) \(branchNote)
            """
        } else if let screenshotError {
            screenshotSection = String(localized: "アップロード失敗: \(codeBlock(screenshotError))")
        } else {
            screenshotSection = String(localized: "なし")
        }

        let agentSection: String
        if let screenshot {
            let location = String(localized: "スクリーンショットは `\(screenshot.branch)` ブランチの `\(screenshot.path)` にある。")
            let instruction = String(localized: "修正に着手する前に画像を読むこと。")
            agentSection = """
            \(location)

            ```bash
            git fetch origin \(screenshot.branch)
            git show origin/\(screenshot.branch):\(screenshot.path) > /tmp/feedback.jpg
            ```

            \(instruction)
            """
        } else {
            agentSection = String(localized: "スクリーンショットは添付されていない。上記の実行環境と本文から画面を再現すること。")
        }

        return """
        ## \(String(localized: "フィードバック"))

        \(codeBlock(Masking.mask(comment.trimmingCharacters(in: .whitespacesAndNewlines))))

        ## \(String(localized: "スクリーンショット"))

        \(screenshotSection)

        ## \(String(localized: "実行環境"))

        | \(String(localized: "項目")) | \(String(localized: "値")) |
        | --- | --- |
        | \(String(localized: "報告者")) | \(tableCell(environment.reporter)) |
        | \(String(localized: "アプリ")) | \(tableCell(environment.appVersion)) |
        | macOS | \(tableCell(environment.macOSVersion)) |
        | Mac | \(tableCell(environment.hardwareModel)) |
        | \(String(localized: "ディスプレイ")) | \(tableCell(environment.display)) |
        | \(String(localized: "撮影時刻")) | \(tableCell(environment.capturedAt)) |

        ## \(String(localized: "AIエージェント向けの手順"))

        \(agentSection)

        ---
        _\(String(localized: "このIssueは Revvy から作成されました。"))_
        """
    }

    /// コードブロックを閉じられないように ``` を潰す
    static func codeBlock(_ text: String) -> String {
        text.replacingOccurrences(of: "```", with: "` ` `")
    }

    static func tableCell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}
