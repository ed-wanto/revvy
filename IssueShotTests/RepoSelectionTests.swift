import Foundation
import Testing
@testable import IssueShot

struct RepoSelectionTests {
    private func repo(_ fullName: String) -> GHRepo {
        let parts = fullName.split(separator: "/").map(String.init)
        return GHRepo(
            id: fullName.hashValue,
            name: parts[1],
            fullName: fullName,
            owner: GHUser(id: parts[0].hashValue, login: parts[0], avatarUrl: nil, name: nil),
            isPrivate: true,
            defaultBranch: "main",
            pushedAt: nil,
            permissions: GHRepo.Permissions(push: true)
        )
    }

    // API は pushed 順で返す想定。org のリポジトリが先頭でも自分のものを優先する
    private let fetched = [
        "example-org/website",
        "example-org/mobile-app",
        "octocat/revvy",
        "octocat/dotfiles",
    ]

    @Test func defaultRepoPrefersOwnMostRecentlyPushed() {
        let repos = fetched.map(repo)
        let chosen = AppModel.defaultRepo(from: repos, ownerLogin: "octocat")
        #expect(chosen?.fullName == "octocat/revvy")
    }

    @Test func defaultRepoFallsBackToFirstWhenNoneOwned() {
        let repos = fetched.map(repo)
        #expect(AppModel.defaultRepo(from: repos, ownerLogin: "someone-else")?.fullName == "example-org/website")
        #expect(AppModel.defaultRepo(from: repos, ownerLogin: nil)?.fullName == "example-org/website")
    }

    @Test func sortPutsOwnReposFirstKeepingOrder() {
        let sorted = AppModel.sortForDisplay(fetched.map(repo), ownerLogin: "OCTOCAT")
        #expect(sorted.map(\.fullName) == [
            "octocat/revvy",
            "octocat/dotfiles",
            "example-org/website",
            "example-org/mobile-app",
        ])
    }

    @Test func clientIDOverrideWinsOverBundled() {
        #expect(OAuthConfig.resolveClientID(override: "  abc123 ") == "abc123")
        #expect(OAuthConfig.resolveClientID(override: "   ") == OAuthConfig.bundledClientID)
        #expect(OAuthConfig.resolveClientID(override: nil) == OAuthConfig.bundledClientID)
    }
}
