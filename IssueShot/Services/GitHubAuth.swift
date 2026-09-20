import Foundation

/// GitHub OAuth Device Flow。ネイティブアプリなので client secret を持たず、
/// ユーザーにコードを表示してブラウザで承認してもらう。
/// https://docs.github.com/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow
struct GitHubDeviceFlow: Sendable {
    struct DeviceCode: Decodable, Sendable {
        let deviceCode: String
        let userCode: String
        let verificationUri: URL
        let expiresIn: Int
        let interval: Int
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let error: String?
        let errorDescription: String?
    }

    enum FlowError: LocalizedError {
        case expired
        case denied
        case server(String)

        var errorDescription: String? {
            switch self {
            case .expired: String(localized: "コードの有効期限が切れました。もう一度やり直してください。")
            case .denied: String(localized: "GitHub 側で承認が拒否されました。")
            case .server(let message): message
            }
        }
    }

    let clientID: String
    let scope = "repo"
    let session: URLSession

    init(clientID: String, session: URLSession = .shared) {
        self.clientID = clientID
        self.session = session
    }

    func requestDeviceCode() async throws -> DeviceCode {
        try await post(
            URL(string: "https://github.com/login/device/code")!,
            form: ["client_id": clientID, "scope": scope]
        )
    }

    /// 承認されるまでポーリング。Task のキャンセルで中断できる。
    func waitForToken(_ code: DeviceCode) async throws -> String {
        let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))
        var interval = max(code.interval, 5)

        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            let response: TokenResponse = try await post(
                URL(string: "https://github.com/login/oauth/access_token")!,
                form: [
                    "client_id": clientID,
                    "device_code": code.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                ]
            )
            if let token = response.accessToken { return token }
            switch response.error {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case "expired_token": throw FlowError.expired
            case "access_denied": throw FlowError.denied
            default: throw FlowError.server(response.errorDescription ?? response.error ?? String(localized: "不明なエラー"))
            }
        }
        throw FlowError.expired
    }

    private func post<T: Decodable>(_ url: URL, form: [String: String]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data(components.percentEncodedQuery!.utf8)

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else {
            throw FlowError.server("GitHub \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }
        return try GitHubClient.decoder.decode(T.self, from: data)
    }
}

/// 開発者向けの近道: ログイン済みの gh CLI からトークンを借りる
enum GHCLITokenImporter {
    static let candidatePaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh",
    ]

    static var installedPath: String? {
        #if APP_STORE
        // App Sandbox では外部コマンドを実行できない（審査でも不可）。ボタンごと出さない。
        return nil
        #else
        return candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
        #endif
    }

    static func importToken() async throws -> String {
        guard let path = installedPath else {
            throw GitHubDeviceFlow.FlowError.server(String(localized: "gh CLI が見つかりません（brew install gh）"))
        }
        let output = try await ProcessRunner.run(path, arguments: ["auth", "token"])
        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw GitHubDeviceFlow.FlowError.server(String(localized: "gh auth token が空でした。`gh auth login` を実行してください。"))
        }
        return token
    }
}

/// 子プロセスを async で実行する小さなヘルパー（screencapture / gh 用）
enum ProcessRunner {
    struct Failure: LocalizedError {
        let status: Int32
        let stderr: String
        var errorDescription: String? { String(localized: "コマンドが終了コード \(status) で失敗: \(stderr)") }
    }

    static func run(_ executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.terminationHandler = { finished in
                let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if finished.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(throwing: Failure(status: finished.terminationStatus, stderr: err))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
