import Foundation

struct GHUser: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let login: String
    let avatarUrl: URL?
    let name: String?
}

struct GHRepo: Codable, Identifiable, Hashable, Sendable {
    struct Permissions: Codable, Hashable, Sendable {
        let push: Bool
    }

    let id: Int
    let name: String
    let fullName: String
    let owner: GHUser
    let isPrivate: Bool
    let defaultBranch: String
    let pushedAt: Date?
    let permissions: Permissions?

    enum CodingKeys: String, CodingKey {
        case id, name, fullName, owner, defaultBranch, pushedAt, permissions
        case isPrivate = "private"
    }
}

struct GHLabel: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

struct GHIssue: Codable, Hashable, Sendable {
    let number: Int
    let htmlUrl: URL
}

struct GHBranch: Codable, Sendable {
    struct Commit: Codable, Sendable { let sha: String }
    let name: String
    let commit: Commit
}

struct GHRef: Codable, Sendable {
    struct Object: Codable, Sendable { let sha: String }
    let object: Object
}

struct GHContentResponse: Codable, Sendable {
    struct Content: Codable, Sendable {
        let path: String
        let sha: String
        let htmlUrl: URL
    }
    let content: Content
}

/// `feedback-assets` ブランチにコミット済みのスクリーンショット
struct UploadedScreenshot: Hashable, Sendable {
    let path: String
    let htmlUrl: URL
    let branch: String

    /// Issue 本文でインライン表示するための URL（private リポジトリでも閲覧権限があれば描画される）
    var rawUrl: URL {
        var components = URLComponents(url: htmlUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "raw", value: "true")]
        return components.url!
    }
}
