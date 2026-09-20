import Foundation
import Testing
@testable import IssueShot

private final class ShareStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/repos/example/revvy/contents/screenshots/test.jpg")
        let denied = request.value(forHTTPHeaderField: "Authorization") == "Bearer denied"
        let payload = denied ? #"{"message":"Forbidden"}"# : #"{"content":{"path":"screenshots/test.jpg","sha":"test-sha","html_url":"https://github.com/example/revvy/blob/feedback-assets/screenshots/test.jpg"}}"#
        let response = HTTPURLResponse(url: request.url!, statusCode: denied ? 403 : 201, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct ShareUploadTests {
    private func client(token: String) -> GitHubClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ShareStubProtocol.self]
        return GitHubClient(token: token, session: URLSession(configuration: config))
    }

    @Test func imageOnlyUploadReturnsGitHubLinkWithoutCreatingIssue() async throws {
        let upload = try await client(token: "test").uploadScreenshot(repo: "example/revvy", branch: "feedback-assets", path: "screenshots/test.jpg", jpegData: Data([1, 2, 3]))
        #expect(upload.htmlUrl.absoluteString == "https://github.com/example/revvy/blob/feedback-assets/screenshots/test.jpg")
        #expect(upload.branch == "feedback-assets")
    }

    @Test func deniedUploadDoesNotReturnAShareLink() async throws {
        do {
            _ = try await client(token: "denied").uploadScreenshot(repo: "example/revvy", branch: "feedback-assets", path: "screenshots/test.jpg", jpegData: Data([1]))
            Issue.record("Denied upload must fail")
        } catch let error as GitHubAPIError {
            #expect(error.status == 403)
        }
    }
}
