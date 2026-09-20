import Foundation

struct GitHubAPIError: LocalizedError, Sendable {
    let status: Int
    let message: String
    let path: String

    var errorDescription: String? { "GitHub API \(status) (\(path)): \(message)" }
    var isNotFound: Bool { status == 404 }
    var isUnauthorized: Bool { status == 401 }
    var isUnprocessable: Bool { status == 422 }
}

/// api.github.com への薄いラッパー。Octokit などの SDK は使わず URLSession で直接呼ぶ
struct GitHubClient: Sendable {
    static let apiBase = URL(string: "https://api.github.com")!

    let token: String
    let session: URLSession

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    // MARK: - Request primitives

    private struct Empty: Encodable {}

    func request<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await request(method, path, query: query, body: Optional<Empty>.none)
    }

    func request<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: B?) async throws -> T {
        let (data, _) = try await send(method, path, query: query, body: body)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw GitHubAPIError(status: 0, message: String(localized: "レスポンスの解析に失敗: \(error.localizedDescription)"), path: path)
        }
    }

    @discardableResult
    func send<B: Encodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: B?) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(url: Self.apiBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Revvy", forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubAPIError(status: http.statusCode, message: Self.errorMessage(from: data), path: path)
        }
        return (data, http)
    }

    private static func errorMessage(from data: Data) -> String {
        struct Body: Decodable { let message: String? }
        if let body = try? decoder.decode(Body.self, from: data), let message = body.message {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "(no body)"
    }

    // MARK: - User / repos

    func currentUser() async throws -> GHUser {
        try await request("GET", "user")
    }

    /// 自分が push できるリポジトリを pushed 順で最大 500 件
    func listRepositories() async throws -> [GHRepo] {
        var all: [GHRepo] = []
        for page in 1...5 {
            let pageItems: [GHRepo] = try await request("GET", "user/repos", query: [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "sort", value: "pushed"),
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
            ])
            all.append(contentsOf: pageItems)
            if pageItems.count < 100 { break }
        }
        return all
    }

    func listAssignees(repo: String) async throws -> [GHUser] {
        try await request("GET", "repos/\(repo)/assignees", query: [URLQueryItem(name: "per_page", value: "100")])
    }

    func listLabels(repo: String) async throws -> [GHLabel] {
        try await request("GET", "repos/\(repo)/labels", query: [URLQueryItem(name: "per_page", value: "100")])
    }

    // MARK: - Screenshot upload (Contents API)

    private struct CreateRefRequest: Encodable { let ref: String; let sha: String }
    private struct PutContentsRequest: Encodable { let message: String; let content: String; let branch: String }

    /// 画像置き場ブランチがなければデフォルトブランチから切る
    func ensureBranch(repo: String, branch: String, defaultBranch: String) async throws {
        do {
            let _: GHBranch = try await request("GET", "repos/\(repo)/branches/\(branch)")
            return
        } catch let error as GitHubAPIError where error.isNotFound {
            // fall through and create
        }
        let base: GHRef = try await request("GET", "repos/\(repo)/git/ref/heads/\(defaultBranch)")
        do {
            try await send("POST", "repos/\(repo)/git/refs", body: CreateRefRequest(ref: "refs/heads/\(branch)", sha: base.object.sha))
        } catch let error as GitHubAPIError where error.isUnprocessable {
            // 競合で既に作られていた場合は成功扱い
        }
    }

    func uploadScreenshot(repo: String, branch: String, path: String, jpegData: Data) async throws -> UploadedScreenshot {
        let response: GHContentResponse = try await request(
            "PUT",
            "repos/\(repo)/contents/\(path)",
            body: PutContentsRequest(
                message: "chore(feedback): add screenshot \(path)",
                content: jpegData.base64EncodedString(),
                branch: branch
            )
        )
        return UploadedScreenshot(path: response.content.path, htmlUrl: response.content.htmlUrl, branch: branch)
    }

    // MARK: - Labels / issues

    private struct CreateLabelRequest: Encodable { let name: String; let color: String; let description: String }

    /// ラベルがなければ作る。既存（422）や権限不足は無視して Issue 作成を優先する
    func ensureLabel(repo: String, name: String) async {
        _ = try? await send(
            "POST",
            "repos/\(repo)/labels",
            body: CreateLabelRequest(name: name, color: "F9A825", description: String(localized: "アプリ内フィードバックから起票"))
        )
    }

    private struct CreateIssueRequest: Encodable {
        let title: String
        let body: String
        let labels: [String]
        let assignees: [String]
    }

    func createIssue(repo: String, title: String, body: String, labels: [String], assignees: [String]) async throws -> GHIssue {
        try await request(
            "POST",
            "repos/\(repo)/issues",
            body: CreateIssueRequest(title: title, body: body, labels: labels, assignees: assignees)
        )
    }
}
