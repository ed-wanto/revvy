import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum SettingsKeys {
    static let clientID = "github.oauthClientID"
    static let issueLabel = "issue.label"
    static let assetsBranch = "issue.assetsBranch"
    static let selectedRepo = "issue.selectedRepo"

    static let rulerUnit = "ruler.unit"
    static let rootFontSize = "ruler.rootFontSize"

    static let defaultLabel = "app-feedback"
    static let defaultAssetsBranch = "feedback-assets"
    static let defaultRootFontSize: Double = 16
}

enum AuthState: Equatable {
    case checking
    case signedOut
    case awaitingDeviceApproval(userCode: String, verificationUri: URL)
    case signedIn(GHUser)
}

struct SubmitResult: Equatable {
    let issue: GHIssue
    let screenshotUploaded: Bool
}

/// 撮影の結果。撮れたか、Esc でやめたか、権限などで撮れなかったか（理由は errorMessage に入る）。
enum CaptureOutcome {
    case captured
    case cancelled
    case failed
}

@MainActor
@Observable
final class AppModel {
    var captures: [SavedCapture] = []
    var captureQuery = ""
    var selectedCaptureID: UUID?
    var shareURL: URL?
    var shareStatus: String?
    var isSharing = false
    var libraryStatus: String?
    private let library = CaptureLibrary()
    private var didBootstrap = false
    /// 撮影できたあとに呼ぶ。画面ルーラーとガイド線を片付けるのに使う。
    @ObservationIgnored var didCapture: (() -> Void)?

    var filteredCaptures: [SavedCapture] { captures.filter { $0.matches(captureQuery) } }

    // MARK: 認証
    var auth: AuthState = .checking
    var authError: String?
    private var client: GitHubClient?
    private var deviceFlowTask: Task<Void, Never>?

    // MARK: リポジトリ
    var repos: [GHRepo] = []
    var isLoadingRepos = false
    var selectedRepo: GHRepo? {
        didSet {
            UserDefaults.standard.set(selectedRepo?.fullName, forKey: SettingsKeys.selectedRepo)
            if selectedRepo != oldValue { Task { await loadRepoMetadata() } }
        }
    }
    var assignees: [GHUser] = []
    var labels: [GHLabel] = []

    // MARK: レポート
    var screenshot: CGImage?
    var annotations: [Annotation] = []
    var tool: AnnotationTool = .select
    var selectedAnnotationID: UUID?
    var showPixelRulers = false
    /// 画像の中心に十字のガイドを出す。書き出しには含めない。
    var showCenterGuides = false
    var isPanningCanvas = false
    /// ズームはツールバーからも操作するのでモデルが持つ。nil は「全体表示」。
    var requestedZoom: CGFloat?
    /// AnnotatorView が実際に描いた倍率を書き戻す。ツールバーの表示に使う。
    var displayedZoom: CGFloat = 1
    private var annotationUndo: [[Annotation]] = []
    private var annotationRedo: [[Annotation]] = []
    /// 連続した矢印キーの微調整をひとつの取り消し単位にまとめるための目印。
    private var lastNudgeAt: Date?
    var canUndoAnnotation: Bool { !annotationUndo.isEmpty }
    var canRedoAnnotation: Bool { !annotationRedo.isEmpty }
    var annotationColor: AnnotationColor = .red
    var title = ""
    var comment = ""
    var selectedAssignees: Set<String> = []
    var selectedLabels: Set<String> = []
    var isCapturing = false
    var isSubmitting = false
    var submitStatus: String?
    var result: SubmitResult?
    var errorMessage: String?

    var user: GHUser? {
        if case .signedIn(let user) = auth { return user }
        return nil
    }

    var selectedCapture: SavedCapture? {
        guard let selectedCaptureID else { return nil }
        return captures.first { $0.id == selectedCaptureID }
    }

    /// ウィンドウのタイトルは「いま編集しているもの」。ロゴはツールバーに置かない。
    var windowTitle: String {
        guard screenshot != nil else { return "Revvy" }
        if let note = selectedCapture?.note.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { return note }
        if let created = selectedCapture?.createdAt { return created.formatted(date: .abbreviated, time: .shortened) }
        return String(localized: "読み込んだ画像")
    }

    var windowSubtitle: String {
        guard user != nil else { return String(localized: "GitHub 未連携") }
        return selectedRepo?.fullName ?? String(localized: "リポジトリ未選択")
    }

    var zoomLabel: String {
        guard screenshot != nil else { return "—" }
        return requestedZoom == nil ? String(localized: "全体") : "\(Int((displayedZoom * 100).rounded()))%"
    }

    func zoomIn() { requestedZoom = min(CanvasViewport.maxScale, displayedZoom * 1.25) }
    func zoomOut() { requestedZoom = max(CanvasViewport.minScale, displayedZoom / 1.25) }
    func zoomToFit() { requestedZoom = nil }

    var canSubmit: Bool {
        user != nil && selectedRepo != nil && !isSubmitting && !isSharing
            && (!comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || screenshot != nil)
    }

    private var defaults: UserDefaults { .standard }
    var issueLabel: String { defaults.string(forKey: SettingsKeys.issueLabel).nonEmpty ?? SettingsKeys.defaultLabel }
    var assetsBranch: String { defaults.string(forKey: SettingsKeys.assetsBranch).nonEmpty ?? SettingsKeys.defaultAssetsBranch }
    var clientID: String { OAuthConfig.resolveClientID(override: defaults.string(forKey: SettingsKeys.clientID)) }

    // MARK: - 起動

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        do { captures = try library.load() }
        catch { errorMessage = String(localized: "履歴を読み込めませんでした: \(error.localizedDescription)") }
        guard let token = KeychainStore.gitHubToken.read() else {
            auth = .signedOut
            return
        }
        await signIn(token: token, persist: false)
    }

    // MARK: - 認証

    func signIn(token: String, persist: Bool = true) async {
        authError = nil
        auth = .checking
        let candidate = GitHubClient(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            let user = try await candidate.currentUser()
            if persist { try KeychainStore.gitHubToken.write(candidate.token) }
            client = candidate
            auth = .signedIn(user)
            await loadRepos()
        } catch let error as GitHubAPIError where error.isUnauthorized {
            KeychainStore.gitHubToken.delete()
            auth = .signedOut
            authError = String(localized: "トークンが無効です。もう一度連携してください。")
        } catch {
            auth = .signedOut
            authError = error.localizedDescription
        }
    }

    func startDeviceFlow() {
        let id = clientID
        guard !id.isEmpty else {
            authError = String(localized: "設定で OAuth App の Client ID を入力してください。")
            return
        }
        authError = nil
        deviceFlowTask?.cancel()
        deviceFlowTask = Task {
            let flow = GitHubDeviceFlow(clientID: id)
            do {
                let code = try await flow.requestDeviceCode()
                auth = .awaitingDeviceApproval(userCode: code.userCode, verificationUri: code.verificationUri)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code.userCode, forType: .string)
                NSWorkspace.shared.open(code.verificationUri)
                let token = try await flow.waitForToken(code)
                await signIn(token: token)
            } catch is CancellationError {
                auth = .signedOut
            } catch {
                auth = .signedOut
                authError = error.localizedDescription
            }
        }
    }

    func cancelDeviceFlow() {
        deviceFlowTask?.cancel()
        deviceFlowTask = nil
        auth = .signedOut
    }

    func importTokenFromGHCLI() async {
        authError = nil
        do {
            let token = try await GHCLITokenImporter.importToken()
            await signIn(token: token)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        shareURL = nil
        shareStatus = nil
        deviceFlowTask?.cancel()
        KeychainStore.gitHubToken.delete()
        client = nil
        repos = []
        selectedRepo = nil
        auth = .signedOut
    }

    // MARK: - リポジトリ

    func loadRepos() async {
        guard let client else { return }
        isLoadingRepos = true
        defer { isLoadingRepos = false }
        do {
            let fetched = try await client.listRepositories()
            repos = Self.sortForDisplay(fetched.filter { $0.permissions?.push ?? true }, ownerLogin: user?.login)
            let remembered = defaults.string(forKey: SettingsKeys.selectedRepo)
            if let remembered, let match = repos.first(where: { $0.fullName == remembered }) {
                selectedRepo = match
            } else if selectedRepo == nil {
                selectedRepo = Self.defaultRepo(from: repos, ownerLogin: user?.login)
            }
        } catch {
            errorMessage = String(localized: "リポジトリ一覧の取得に失敗: \(error.localizedDescription)")
        }
    }

    private func loadRepoMetadata() async {
        guard let client, let repo = selectedRepo else {
            assignees = []
            labels = []
            return
        }
        selectedAssignees = []
        selectedLabels = []
        async let fetchedAssignees = client.listAssignees(repo: repo.fullName)
        async let fetchedLabels = client.listLabels(repo: repo.fullName)
        assignees = (try? await fetchedAssignees) ?? []
        labels = (try? await fetchedLabels) ?? []
    }

    // MARK: - スクリーンショット

    /// Esc でのキャンセルと、権限エラーなどで撮れなかった場合を分けて返す。
    @discardableResult
    func capture(_ mode: CaptureMode) async -> CaptureOutcome {
        guard !isCapturing else { return .cancelled }
        isCapturing = true
        errorMessage = nil
        defer { isCapturing = false }
        do {
            guard let image = try await ScreenCaptureService.capture(mode) else { return .cancelled }
            setScreenshot(image)
            didCapture?()
            return .captured
        } catch ScreenCaptureError.permissionDenied {
            errorMessage = ScreenCaptureError.permissionDenied.errorDescription
            NSWorkspace.shared.open(ScreenCaptureError.settingsURL)
        } catch {
            errorMessage = String(localized: "撮影に失敗: \(error.localizedDescription)")
        }
        return .failed
    }

    func pasteScreenshot() {
        if let image = ImageCodec.fromPasteboard() {
            setScreenshot(image)
        } else {
            errorMessage = String(localized: "クリップボードに画像がありません。")
        }
    }

    /// Finder・ブラウザ・写真アプリなどからドロップされた画像を取り込む
    @discardableResult
    func importDroppedImage(_ providers: [NSItemProvider]) async -> Bool {
        guard let image = await ImageDrop.loadImage(from: providers) else {
            errorMessage = String(localized: "ドロップされたものを画像として読み込めませんでした。")
            return false
        }
        setScreenshot(image)
        return true
    }

    func loadScreenshot(from url: URL) {
        if let image = ImageCodec.load(url) {
            setScreenshot(image)
        } else {
            errorMessage = String(localized: "画像として読み込めませんでした: \(url.lastPathComponent)")
        }
    }

    func setScreenshot(_ image: CGImage) {
        resetAnnotationHistory()
        screenshot = image
        annotations = []
        result = nil
        shareURL = nil
        shareStatus = nil
        selectedCaptureID = nil
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            errorMessage = String(localized: "履歴用の画像を変換できませんでした。")
            return
        }
        let capture = SavedCapture(id: UUID(), createdAt: Date(), note: "", text: "")
        do {
            try library.save(capture, png: png)
            captures.insert(capture, at: 0)
            selectedCaptureID = capture.id
            Task {
                do {
                    let text = try await CaptureTextRecognition.recognize(png: png)
                    guard let index = captures.firstIndex(where: { $0.id == capture.id }) else { return }
                    var updated = captures[index]
                    updated.text = text
                    try library.update(updated)
                    captures[index] = updated
                } catch { libraryStatus = String(localized: "画像は保存済みですが、文字認識に失敗しました。") }
            }
        } catch { errorMessage = String(localized: "履歴に保存できませんでした: \(error.localizedDescription)") }
    }

    func openCapture(_ capture: SavedCapture) {
        resetAnnotationHistory()
        guard let image = ImageCodec.load(library.imageURL(capture.id)) else {
            errorMessage = String(localized: "履歴の画像を読み込めませんでした。")
            return
        }
        screenshot = image
        selectedCaptureID = capture.id
        annotations = capture.annotations ?? []
        shareURL = nil
        shareStatus = nil
    }

    func updateNote(_ note: String, for id: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return }
        var updated = captures[index]
        updated.note = note
        do { try library.update(updated); captures[index] = updated }
        catch { errorMessage = String(localized: "メモの保存に失敗しました: \(error.localizedDescription)") }
    }

    func deleteCapture(_ capture: SavedCapture) {
        do {
            try library.delete(capture)
            captures.removeAll { $0.id == capture.id }
            if selectedCaptureID == capture.id { clearScreenshot() }
        } catch { errorMessage = String(localized: "履歴の削除に失敗しました: \(error.localizedDescription)") }
    }

    func persistAnnotations() {
        guard let id = selectedCaptureID, let index = captures.firstIndex(where: { $0.id == id }) else { return }
        var updated = captures[index]
        updated.annotations = annotations
        do { try library.update(updated); captures[index] = updated }
        catch { errorMessage = String(localized: "編集の保存に失敗しました: \(error.localizedDescription)") }
    }

    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadScreenshot(from: url)
    }

    func copyImage() {
        guard let screenshot else { return }
        let rendered = AnnotationRenderer.render(annotations, onto: screenshot)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([NSImage(cgImage: rendered, size: .zero)])
    }

    func exportImage() {
        guard let screenshot else { return }
        let rendered = AnnotationRenderer.render(annotations, onto: screenshot)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Revvy-\(Date().formatted(.iso8601).replacingOccurrences(of: ":", with: "-" )).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let data = NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url, options: .atomic)
        } catch { errorMessage = String(localized: "画像の保存に失敗しました: \(error.localizedDescription)") }
    }

    func shareScreenshot() async {
        guard !isSharing, !isSubmitting, let client, let repo = selectedRepo, let screenshot else { return }
        let captureID = selectedCaptureID
        let sharedAnnotations = annotations
        let branch = assetsBranch
        let rendered = AnnotationRenderer.render(annotations, onto: screenshot)
        guard let jpeg = ImageCodec.jpegData(rendered) else { errorMessage = String(localized: "画像を変換できませんでした。"); return }
        isSharing = true
        shareURL = nil
        shareStatus = String(localized: "アップロード中…")
        defer { isSharing = false }
        do {
            try await client.ensureBranch(repo: repo.fullName, branch: branch, defaultBranch: repo.defaultBranch)
            let uploaded = try await client.uploadScreenshot(repo: repo.fullName, branch: branch, path: Self.screenshotPath(), jpegData: jpeg)
            guard selectedCaptureID == captureID, self.screenshot === screenshot, annotations == sharedAnnotations, selectedRepo == repo, assetsBranch == branch, self.client?.token == client.token else { shareStatus = nil; return }
            shareURL = uploaded.htmlUrl
            shareStatus = String(localized: "リンクをコピーしました")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(uploaded.htmlUrl.absoluteString, forType: .string)
        } catch {
            shareStatus = nil
            errorMessage = String(localized: "共有に失敗しました: \(error.localizedDescription)")
        }
    }

    func showWindow() {
        NSApp.activate()
        // タイトルはキャプチャ名に変わるので、WindowGroup の識別子で探す。
        let window = NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }
            ?? NSApp.windows.first { $0.canBecomeMain && $0.isVisible }
        window?.makeKeyAndOrderFront(nil)
    }

    func clearScreenshot() {
        resetAnnotationHistory()
        selectedCaptureID = nil
        shareURL = nil
        shareStatus = nil
        screenshot = nil
        annotations = []
    }

    func commitAnnotations(_ updated: [Annotation]) {
        guard updated != annotations else { return }
        lastNudgeAt = nil
        annotationUndo.append(annotations)
        if annotationUndo.count > 100 { annotationUndo.removeFirst() }
        annotationRedo = []
        annotations = updated
    }

    /// 矢印キーで選択中の注釈を元画像 1px 単位で動かす。⇧ で 10px。
    func nudgeSelectedAnnotation(dx: CGFloat, dy: CGFloat, fast: Bool, now: Date = Date()) {
        guard let selectedAnnotationID, let image = screenshot,
              let target = annotations.first(where: { $0.id == selectedAnnotationID }) else { return }
        let step: CGFloat = fast ? 10 : 1
        let moved = AnnotationGeometry.moved(target, by: CGSize(
            width: dx * step / CGFloat(image.width),
            height: dy * step / CGFloat(image.height)
        ))
        let updated = annotations.map { $0.id == selectedAnnotationID ? moved : $0 }
        guard updated != annotations else { return }
        // 押しっぱなしで取り消し履歴が埋まらないよう、直前も微調整なら履歴を足さない。
        if let lastNudgeAt, now.timeIntervalSince(lastNudgeAt) < 1.2, !annotationUndo.isEmpty {
            annotations = updated
            annotationRedo = []
        } else {
            commitAnnotations(updated)
        }
        self.lastNudgeAt = now
    }

    /// 選択中の注釈を寸法そのままで複製し、少しずらして重ならないようにする。
    func duplicateSelectedAnnotation() {
        guard let selectedAnnotationID, let image = screenshot,
              let target = annotations.first(where: { $0.id == selectedAnnotationID }) else { return }
        let shifted = AnnotationGeometry.moved(target, by: CGSize(
            width: 12 / CGFloat(image.width),
            height: 12 / CGFloat(image.height)
        ))
        let copy = Annotation(tool: shifted.tool, color: shifted.color, points: shifted.points,
                              text: shifted.text, fontSize: shifted.fontSize)
        commitAnnotations(annotations + [copy])
        self.selectedAnnotationID = copy.id
    }

    func deleteSelectedAnnotation() {
        guard let selectedAnnotationID else { return }
        commitAnnotations(annotations.filter { $0.id != selectedAnnotationID })
        self.selectedAnnotationID = nil
    }

    func undoAnnotation() {
        guard let previous = annotationUndo.popLast() else { return }
        annotationRedo.append(annotations)
        annotations = previous
        selectedAnnotationID = nil
    }

    func redoAnnotation() {
        guard let next = annotationRedo.popLast() else { return }
        annotationUndo.append(annotations)
        annotations = next
        selectedAnnotationID = nil
    }

    private func resetAnnotationHistory() {
        isPanningCanvas = false
        requestedZoom = nil
        lastNudgeAt = nil
        annotationUndo = []
        annotationRedo = []
        selectedAnnotationID = nil
    }

    // MARK: - 送信

    func submit() async {
        guard let client, let repo = selectedRepo, let user, canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        result = nil
        defer {
            isSubmitting = false
            submitStatus = nil
        }

        var uploaded: UploadedScreenshot?
        var uploadError: String?

        if let screenshot {
            submitStatus = String(localized: "スクリーンショットをアップロード中…")
            let rendered = AnnotationRenderer.render(annotations, onto: screenshot)
            if let jpeg = ImageCodec.jpegData(rendered) {
                do {
                    try await client.ensureBranch(repo: repo.fullName, branch: assetsBranch, defaultBranch: repo.defaultBranch)
                    uploaded = try await client.uploadScreenshot(
                        repo: repo.fullName,
                        branch: assetsBranch,
                        path: Self.screenshotPath(),
                        jpegData: jpeg
                    )
                } catch {
                    uploadError = error.localizedDescription
                }
            } else {
                uploadError = String(localized: "JPEG への変換に失敗")
            }
        }

        submitStatus = String(localized: "Issue を作成中…")
        let label = issueLabel
        await client.ensureLabel(repo: repo.fullName, name: label)

        let environment = ReportEnvironment.current(reporter: user.login)
        let body = IssueBodyBuilder.body(
            comment: comment,
            environment: environment,
            screenshot: uploaded,
            screenshotError: uploadError
        )
        do {
            let issue = try await client.createIssue(
                repo: repo.fullName,
                title: IssueBodyBuilder.title(userTitle: title, comment: comment),
                body: body,
                labels: Array(Set([label]).union(selectedLabels)).sorted(),
                assignees: Array(selectedAssignees).sorted()
            )
            result = SubmitResult(issue: issue, screenshotUploaded: uploaded != nil)
            if let uploadError { errorMessage = String(localized: "Issue は作成しましたが画像のアップロードに失敗しました: \(uploadError)") }
        } catch {
            errorMessage = String(localized: "Issue の作成に失敗: \(error.localizedDescription)")
        }
    }

    func resetReport() {
        clearScreenshot()
        screenshot = nil
        annotations = []
        title = ""
        comment = ""
        selectedAssignees = []
        selectedLabels = []
        result = nil
        errorMessage = nil
    }

    /// 自分がオーナーのリポジトリを先頭に、それぞれ pushed 順（API の並び）を保つ
    nonisolated static func sortForDisplay(_ repos: [GHRepo], ownerLogin: String?) -> [GHRepo] {
        guard let ownerLogin else { return repos }
        let own = repos.filter { $0.owner.login.caseInsensitiveCompare(ownerLogin) == .orderedSame }
        let others = repos.filter { $0.owner.login.caseInsensitiveCompare(ownerLogin) != .orderedSame }
        return own + others
    }

    /// 初期選択は「自分がオーナー」のリポジトリのうち最近 push したもの。なければ先頭
    nonisolated static func defaultRepo(from repos: [GHRepo], ownerLogin: String?) -> GHRepo? {
        if let ownerLogin,
           let own = repos.first(where: { $0.owner.login.caseInsensitiveCompare(ownerLogin) == .orderedSame }) {
            return own
        }
        return repos.first
    }

    /// screenshots/<YYYYMMDD-HHMMSS>-<6 hex>.jpg
    nonisolated static func screenshotPath(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = String(format: "%06x", Int.random(in: 0..<0xFFFFFF))
        return "screenshots/\(formatter.string(from: now))-\(suffix).jpg"
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
