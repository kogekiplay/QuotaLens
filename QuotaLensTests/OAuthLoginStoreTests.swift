import XCTest
@testable import QuotaLens

@MainActor
final class OAuthLoginStoreTests: XCTestCase {
    func testStartNativeOAuthMarksCompletedAndShowsAccountLabel() async {
        let service = FakeNativeOAuthService(
            result: NativeOAuthTokenBundle(
                provider: .codex,
                accessToken: "access-token",
                accountLabel: "coder@example.com"
            )
        )
        let store = OAuthLoginStore()

        await store.startNativeOAuth(
            provider: .codex,
            service: service,
            authenticator: FakeNativeAuthenticator(),
            tokenStore: FakeNativeTokenStore()
        )

        XCTAssertEqual(service.providers, [.codex])
        XCTAssertEqual(store.activeProvider, .codex)
        XCTAssertEqual(store.accountLabel, "coder@example.com")
        XCTAssertEqual(store.message, "Codex 登录完成：coder@example.com")
        XCTAssertTrue(store.isCompleted)
        XCTAssertFalse(store.isBusy)
    }

    func testStartNativeOAuthReportsFailureWithoutManualCallbackState() async {
        let service = FakeNativeOAuthService(error: NativeOAuthError.missingAuthorizationCode)
        let store = OAuthLoginStore()

        await store.startNativeOAuth(
            provider: .anthropic,
            service: service,
            authenticator: FakeNativeAuthenticator(),
            tokenStore: FakeNativeTokenStore()
        )

        XCTAssertEqual(store.activeProvider, .anthropic)
        XCTAssertFalse(store.isCompleted)
        XCTAssertFalse(store.isBusy)
        XCTAssertTrue(store.message.contains("无法完成 Claude 登录"))
    }
}

private final class FakeNativeOAuthService: NativeOAuthServicing {
    var result: NativeOAuthTokenBundle?
    var error: Error?
    private(set) var providers: [NativeOAuthProvider] = []

    init(result: NativeOAuthTokenBundle? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func authorize(
        provider: NativeOAuthProvider,
        authenticator: NativeOAuthAuthenticating,
        tokenStore: NativeOAuthTokenStoring
    ) async throws -> NativeOAuthTokenBundle {
        providers.append(provider)
        if let error {
            throw error
        }
        return result ?? NativeOAuthTokenBundle(provider: provider, accessToken: "token", accountLabel: provider.title)
    }
}

private final class FakeNativeAuthenticator: NativeOAuthAuthenticating {
    func callbackURL(
        for authorizationURL: URL,
        provider: NativeOAuthProvider,
        session: NativeOAuthSession
    ) async throws -> URL {
        URL(string: "\(provider.redirectURI)?code=code&state=\(session.state)")!
    }
}

private final class FakeNativeTokenStore: NativeOAuthTokenStoring {
    private var bundles: [NativeOAuthTokenBundle] = []

    func save(_ bundle: NativeOAuthTokenBundle) throws {
        bundles.append(bundle)
    }

    func loadAll() throws -> [NativeOAuthTokenBundle] {
        bundles
    }

    func load(provider: NativeOAuthProvider) throws -> [NativeOAuthTokenBundle] {
        bundles.filter { $0.provider == provider }
    }
}
