import XCTest
@testable import QuotaLens

final class NativeOAuthServiceTests: XCTestCase {
    func testNativeCodexAuthorizationURLMatchesOfficialCodexOAuthParameters() throws {
        let session = NativeOAuthSession(
            provider: .codex,
            state: "state-123",
            codeVerifier: "verifier-123",
            codeChallenge: "challenge-123",
            nonce: "nonce-123"
        )

        let url = try NativeOAuthProvider.codex.authorizationURL(for: session)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "auth.openai.com")
        XCTAssertEqual(components.path, "/oauth/authorize")
        XCTAssertEqual(items["client_id"], "app_EMoamEEZ73f0CkXaXp7hrann")
        XCTAssertEqual(items["redirect_uri"], "http://localhost:1455/auth/callback")
        XCTAssertEqual(items["scope"], "openid email profile offline_access")
        XCTAssertEqual(items["state"], "state-123")
        XCTAssertEqual(items["code_challenge"], "challenge-123")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["prompt"], "login")
        XCTAssertEqual(items["id_token_add_organizations"], "true")
        XCTAssertEqual(items["codex_cli_simplified_flow"], "true")
    }

    func testNativeBrowserOAuthProvidersAreAppInitiatedForSupportedServices() {
        XCTAssertEqual(
            NativeOAuthProvider.browserProviders,
            [.codex, .anthropic, .geminiCLI, .antigravity, .xai]
        )
        XCTAssertNil(NativeOAuthProvider.kimi.fixedAuthorizationEndpoint)
    }

    func testLoopbackOAuthProvidersUseLocalCallbackServerInsteadOfHTTPSchemeInterception() throws {
        for provider in NativeOAuthProvider.browserProviders {
            let redirectURL = try XCTUnwrap(provider.loopbackRedirectURL)

            XCTAssertEqual(redirectURL.scheme, "http")
            XCTAssertNotNil(redirectURL.port)
            XCTAssertNil(provider.callbackURLScheme)
        }
    }

    func testCodexTokenExchangeRequestUsesOpenAITokenEndpointAndPKCEVerifier() throws {
        let session = NativeOAuthSession(
            provider: .codex,
            state: "state-123",
            codeVerifier: "verifier-123",
            codeChallenge: "challenge-123",
            nonce: "nonce-123"
        )

        let request = try NativeOAuthProvider.codex.tokenExchangeRequest(
            code: "code-123",
            session: session,
            discoveredTokenEndpoint: nil
        )

        XCTAssertEqual(request.url?.absoluteString, "https://auth.openai.com/oauth/token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
        let form = formItems(from: body)
        XCTAssertEqual(form["grant_type"], "authorization_code")
        XCTAssertEqual(form["client_id"], "app_EMoamEEZ73f0CkXaXp7hrann")
        XCTAssertEqual(form["code"], "code-123")
        XCTAssertEqual(form["redirect_uri"], "http://localhost:1455/auth/callback")
        XCTAssertEqual(form["code_verifier"], "verifier-123")
    }

    func testGoogleOAuthProvidersDoNotEmbedClientSecretsForPublicSource() throws {
        for provider in [NativeOAuthProvider.geminiCLI, .antigravity] {
            let session = NativeOAuthSession(
                provider: provider,
                state: "state-123",
                codeVerifier: "verifier-123",
                codeChallenge: "challenge-123",
                nonce: "nonce-123"
            )

            let request = try provider.tokenExchangeRequest(
                code: "code-123",
                session: session,
                discoveredTokenEndpoint: nil
            )

            let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
            let form = formItems(from: body)
            XCTAssertNil(provider.clientSecret)
            XCTAssertNil(form["client_secret"])
        }
    }

    private func formItems(from body: String) -> [String: String] {
        var components = URLComponents()
        components.percentEncodedQuery = body
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
}
