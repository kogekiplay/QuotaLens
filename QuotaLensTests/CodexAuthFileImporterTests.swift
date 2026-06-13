import XCTest
@testable import QuotaLens

final class CodexAuthFileImporterTests: XCTestCase {
    func testParsesCodexAuthJSONIntoNativeTokenBundle() throws {
        let data = """
        {
          "access_token": "access-token",
          "refresh_token": "refresh-token",
          "id_token": "id-token",
          "type": "bearer",
          "account_id": "acct_123",
          "email": "coder@example.com",
          "expired": false,
          "disabled": false,
          "last_refresh": "2026-06-13T12:34:56Z"
        }
        """.data(using: .utf8)!

        let bundle = try CodexAuthFileImporter().tokenBundle(
            from: data,
            importedAt: Date(timeIntervalSince1970: 42)
        )

        XCTAssertEqual(bundle.provider, .codex)
        XCTAssertEqual(bundle.accessToken, "access-token")
        XCTAssertEqual(bundle.refreshToken, "refresh-token")
        XCTAssertEqual(bundle.idToken, "id-token")
        XCTAssertEqual(bundle.tokenType, "bearer")
        XCTAssertEqual(bundle.accountID, "acct_123")
        XCTAssertEqual(bundle.accountLabel, "coder@example.com")
        XCTAssertEqual(bundle.createdAt, ISO8601DateFormatter().date(from: "2026-06-13T12:34:56Z"))
    }

    func testRejectsCodexAuthJSONWithoutAccessToken() {
        let data = """
        {
          "refresh_token": "refresh-token",
          "email": "coder@example.com",
          "expired": false,
          "disabled": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try CodexAuthFileImporter().tokenBundle(from: data)) { error in
            XCTAssertEqual(error.localizedDescription, "认证文件缺少 access_token")
        }
    }

    func testRejectsInvalidJSONWithReadableError() {
        let data = Data("not-json".utf8)

        XCTAssertThrowsError(try CodexAuthFileImporter().tokenBundle(from: data)) { error in
            XCTAssertEqual(error.localizedDescription, "认证文件不是有效的 JSON")
        }
    }

    func testRejectsDisabledCodexAuthJSON() {
        let data = """
        {
          "access_token": "access-token",
          "email": "coder@example.com",
          "expired": false,
          "disabled": true
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try CodexAuthFileImporter().tokenBundle(from: data)) { error in
            XCTAssertEqual(error.localizedDescription, "这个 Codex 认证文件已被禁用")
        }
    }

    func testRejectsExpiredCodexAuthJSONBecauseQuotaRefreshRequiresUsableAccessToken() {
        let data = """
        {
          "access_token": "access-token",
          "refresh_token": "refresh-token",
          "email": "coder@example.com",
          "expired": true,
          "disabled": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try CodexAuthFileImporter().tokenBundle(from: data)) { error in
            XCTAssertEqual(error.localizedDescription, "这个 Codex 认证文件已过期，请重新导出或登录")
        }
    }
}
