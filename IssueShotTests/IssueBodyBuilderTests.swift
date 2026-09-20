import Foundation
import Testing
@testable import IssueShot

struct MaskingTests {
    @Test func masksTokensJWTsAndEmails() {
        let input = """
        Authorization: Bearer abc.def.ghi
        token=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123
        jwt=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
        mail=teacher@example.com
        """
        let masked = Masking.mask(input)
        #expect(masked.contains("Authorization: Bearer [MASKED]"))
        #expect(masked.contains("[MASKED_TOKEN]"))
        #expect(masked.contains("[MASKED_JWT]"))
        #expect(masked.contains("[MASKED_EMAIL]"))
        #expect(!masked.contains("ghp_"))
        #expect(!masked.contains("example.com"))
    }

    @Test func leavesOrdinaryTextAlone() {
        let text = "保存ボタンを押すと 500 エラーになる"
        #expect(Masking.mask(text) == text)
    }
}

struct IssueBodyBuilderTests {
    private let environment = ReportEnvironment(
        reporter: "@tester",
        appVersion: "IssueShot 0.1.0 (1)",
        macOSVersion: "Version 26.6.2",
        hardwareModel: "Mac16,6",
        display: "3456x2234 @2x",
        capturedAt: "2026-09-11 16:40 JST"
    )

    @Test func titleFallsBackToCommentAndTruncates() {
        let long = String(repeating: "あ", count: 80)
        let title = IssueBodyBuilder.title(userTitle: "", comment: long)
        #expect(title.hasPrefix("[Feedback] "))
        #expect(title.hasSuffix("..."))
        #expect(title.count == "[Feedback] ".count + 60 + 3)
    }

    @Test func titlePrefersUserTitleAndCollapsesWhitespace() {
        let title = IssueBodyBuilder.title(userTitle: "  保存で\n  落ちる ", comment: "ignored")
        #expect(title == "[Feedback] 保存で 落ちる")
    }

    @Test func bodyWithScreenshotHasAllSections() {
        let shot = UploadedScreenshot(
            path: "screenshots/20260911-164000-abc123.jpg",
            htmlUrl: URL(string: "https://github.com/octocat/example-app/blob/feedback-assets/screenshots/20260911-164000-abc123.jpg")!,
            branch: "feedback-assets"
        )
        let body = IssueBodyBuilder.body(comment: "保存が失敗する", environment: environment, screenshot: shot, screenshotError: nil)
        #expect(body.contains("## \(String(localized: "フィードバック"))"))
        #expect(body.contains("## \(String(localized: "スクリーンショット"))"))
        #expect(body.contains("## \(String(localized: "実行環境"))"))
        #expect(body.contains("## \(String(localized: "AIエージェント向けの手順"))"))
        #expect(body.contains("![screenshot](\(shot.rawUrl.absoluteString))"))
        #expect(body.contains("git show origin/feedback-assets:screenshots/20260911-164000-abc123.jpg"))
        #expect(body.contains("| \(String(localized: "報告者")) | @tester |"))
    }

    @Test func bodyWithoutScreenshotExplainsReproduction() {
        let body = IssueBodyBuilder.body(comment: "x", environment: environment, screenshot: nil, screenshotError: nil)
        #expect(body.contains(String(localized: "スクリーンショットは添付されていない。上記の実行環境と本文から画面を再現すること。")))
    }

    @Test func bodyMasksSecretsAndDefusesCodeFences() {
        let body = IssueBodyBuilder.body(
            comment: "token ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123 ```",
            environment: environment,
            screenshot: nil,
            screenshotError: "```boom```"
        )
        #expect(body.contains("[MASKED_TOKEN]"))
        #expect(!body.contains("```boom```"))
    }

    @Test func rawUrlAppendsRawQuery() {
        let shot = UploadedScreenshot(
            path: "p.jpg",
            htmlUrl: URL(string: "https://github.com/o/r/blob/b/p.jpg")!,
            branch: "b"
        )
        #expect(shot.rawUrl.absoluteString == "https://github.com/o/r/blob/b/p.jpg?raw=true")
    }

    @Test func screenshotPathFollowsNamingConvention() {
        let path = AppModel.screenshotPath(now: Date(timeIntervalSince1970: 0))
        #expect(path.hasPrefix("screenshots/"))
        #expect(path.hasSuffix(".jpg"))
        let regex = try! NSRegularExpression(pattern: #"^screenshots/\d{8}-\d{6}-[0-9a-f]{6}\.jpg$"#)
        #expect(regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil)
    }
}
