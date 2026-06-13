import CryptoKit
import Foundation
import Security

enum NativeOAuthError: LocalizedError {
    case unsupportedProvider(NativeOAuthProvider)
    case invalidEndpoint
    case invalidCallback(URL)
    case authorizationFailed(String)
    case missingAuthorizationCode
    case stateMismatch(expected: String, actual: String?)
    case tokenExchangeFailed(Int, String)
    case tokenResponseMissingAccessToken

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let provider):
            return "\(provider.title) 暂不支持 App 内原生 OAuth"
        case .invalidEndpoint:
            return "OAuth 地址无效"
        case .invalidCallback:
            return "OAuth 回调地址无效"
        case .authorizationFailed(let message):
            return "OAuth 授权失败：\(message)"
        case .missingAuthorizationCode:
            return "OAuth 回调缺少授权码"
        case .stateMismatch:
            return "OAuth state 校验失败"
        case .tokenExchangeFailed(let statusCode, let body):
            return "OAuth token 交换失败：HTTP \(statusCode) \(body)"
        case .tokenResponseMissingAccessToken:
            return "OAuth token 响应缺少 access_token"
        }
    }
}

struct NativeOAuthSession: Equatable, Sendable {
    var provider: NativeOAuthProvider
    var state: String
    var codeVerifier: String
    var codeChallenge: String
    var nonce: String

    init(
        provider: NativeOAuthProvider,
        state: String,
        codeVerifier: String,
        codeChallenge: String,
        nonce: String
    ) {
        self.provider = provider
        self.state = state
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
        self.nonce = nonce
    }

    static func make(provider: NativeOAuthProvider) throws -> NativeOAuthSession {
        let verifier = try NativePKCE.makeCodeVerifier()
        return NativeOAuthSession(
            provider: provider,
            state: NativePKCE.randomURLSafeString(byteCount: 32),
            codeVerifier: verifier,
            codeChallenge: NativePKCE.codeChallenge(for: verifier),
            nonce: NativePKCE.randomURLSafeString(byteCount: 32)
        )
    }
}

enum NativeOAuthProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case codex
    case anthropic
    case antigravity
    case geminiCLI = "gemini-cli"
    case kimi
    case xai

    var id: String { rawValue }

    static let browserProviders: [NativeOAuthProvider] = [.codex, .anthropic, .geminiCLI, .antigravity, .xai]

    var title: String {
        switch self {
        case .codex: "Codex"
        case .anthropic: "Claude"
        case .antigravity: "Antigravity"
        case .geminiCLI: "Gemini CLI"
        case .kimi: "Kimi"
        case .xai: "xAI"
        }
    }

    var clientID: String {
        switch self {
        case .codex:
            return "app_EMoamEEZ73f0CkXaXp7hrann"
        case .anthropic:
            return "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
        case .geminiCLI:
            return "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com"
        case .antigravity:
            return "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
        case .xai:
            return "b1a00492-073a-47ea-816f-4c329264a828"
        case .kimi:
            return ""
        }
    }

    var clientSecret: String? {
        nil
    }

    var redirectURI: String {
        switch self {
        case .codex:
            return "http://localhost:1455/auth/callback"
        case .anthropic:
            return "http://localhost:54545/callback"
        case .geminiCLI:
            return "http://localhost:8085/oauth2callback"
        case .antigravity:
            return "http://localhost:51121/oauth-callback"
        case .xai:
            return "http://127.0.0.1:56121/callback"
        case .kimi:
            return ""
        }
    }

    var callbackURLScheme: String? {
        guard loopbackRedirectURL == nil else { return nil }
        return URL(string: redirectURI)?.scheme
    }

    var loopbackRedirectURL: URL? {
        guard let url = URL(string: redirectURI),
              url.scheme == "http",
              let host = url.host?.lowercased(),
              host == "localhost" || host == "127.0.0.1" || host == "::1",
              url.port != nil else {
            return nil
        }
        return url
    }

    var scope: String {
        switch self {
        case .codex:
            return "openid email profile offline_access"
        case .anthropic:
            return "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
        case .geminiCLI:
            return [
                "https://www.googleapis.com/auth/cloud-platform",
                "https://www.googleapis.com/auth/userinfo.email",
                "https://www.googleapis.com/auth/userinfo.profile"
            ].joined(separator: " ")
        case .antigravity:
            return [
                "https://www.googleapis.com/auth/cloud-platform",
                "https://www.googleapis.com/auth/userinfo.email",
                "https://www.googleapis.com/auth/userinfo.profile",
                "https://www.googleapis.com/auth/cclog",
                "https://www.googleapis.com/auth/experimentsandconfigs"
            ].joined(separator: " ")
        case .xai:
            return "openid profile email offline_access grok-cli:access api:access"
        case .kimi:
            return ""
        }
    }

    var fixedAuthorizationEndpoint: URL? {
        switch self {
        case .codex:
            return URL(string: "https://auth.openai.com/oauth/authorize")
        case .anthropic:
            return URL(string: "https://claude.ai/oauth/authorize")
        case .geminiCLI, .antigravity:
            return URL(string: "https://accounts.google.com/o/oauth2/v2/auth")
        case .xai:
            return URL(string: "https://auth.x.ai/oauth2/authorize")
        case .kimi:
            return nil
        }
    }

    var defaultTokenEndpoint: URL? {
        switch self {
        case .codex:
            return URL(string: "https://auth.openai.com/oauth/token")
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1/oauth/token")
        case .geminiCLI, .antigravity:
            return URL(string: "https://oauth2.googleapis.com/token")
        case .xai:
            return URL(string: "https://auth.x.ai/oauth2/token")
        case .kimi:
            return nil
        }
    }

    func authorizationURL(
        for session: NativeOAuthSession,
        discoveredAuthorizationEndpoint: URL? = nil
    ) throws -> URL {
        guard self != .kimi else { throw NativeOAuthError.unsupportedProvider(self) }
        let endpoint = discoveredAuthorizationEndpoint ?? fixedAuthorizationEndpoint
        guard let endpoint,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw NativeOAuthError.invalidEndpoint
        }
        components.queryItems = authorizationQueryItems(for: session)
        guard let url = components.url else {
            throw NativeOAuthError.invalidEndpoint
        }
        return url
    }

    func tokenExchangeRequest(
        code: String,
        session: NativeOAuthSession,
        discoveredTokenEndpoint: URL? = nil
    ) throws -> URLRequest {
        guard self != .kimi else { throw NativeOAuthError.unsupportedProvider(self) }
        let endpoint = discoveredTokenEndpoint ?? defaultTokenEndpoint
        guard let endpoint else {
            throw NativeOAuthError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch self {
        case .anthropic:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "code": normalizedCode(code),
                "state": session.state,
                "grant_type": "authorization_code",
                "client_id": clientID,
                "redirect_uri": redirectURI,
                "code_verifier": session.codeVerifier
            ])
        case .codex, .xai:
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = NativeOAuthForm.encode([
                ("grant_type", "authorization_code"),
                ("client_id", clientID),
                ("code", normalizedCode(code)),
                ("redirect_uri", redirectURI),
                ("code_verifier", session.codeVerifier)
            ])
        case .geminiCLI, .antigravity:
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var items: [(String, String)] = [
                ("code", normalizedCode(code)),
                ("client_id", clientID),
                ("redirect_uri", redirectURI),
                ("grant_type", "authorization_code")
            ]
            if let clientSecret {
                items.append(("client_secret", clientSecret))
            }
            request.httpBody = NativeOAuthForm.encode(items)
        case .kimi:
            break
        }

        return request
    }

    func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        let values = NativeOAuthCallbackValues(url: callbackURL)
        if let error = values.value(for: "error"), !error.isEmpty {
            throw NativeOAuthError.authorizationFailed(error)
        }

        guard let code = values.value(for: "code"), !code.isEmpty else {
            throw NativeOAuthError.missingAuthorizationCode
        }

        let split = code.split(separator: "#", maxSplits: 1).map(String.init)
        let normalizedCode = split.first ?? code
        let stateFromCode = split.count > 1 ? split[1] : nil
        let actualState = values.value(for: "state") ?? stateFromCode
        guard actualState == expectedState else {
            throw NativeOAuthError.stateMismatch(expected: expectedState, actual: actualState)
        }

        return normalizedCode
    }

    private func authorizationQueryItems(for session: NativeOAuthSession) -> [URLQueryItem] {
        switch self {
        case .codex:
            return [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "state", value: session.state),
                URLQueryItem(name: "code_challenge", value: session.codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "prompt", value: "login"),
                URLQueryItem(name: "id_token_add_organizations", value: "true"),
                URLQueryItem(name: "codex_cli_simplified_flow", value: "true")
            ]
        case .anthropic:
            return [
                URLQueryItem(name: "code", value: "true"),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "code_challenge", value: session.codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: session.state)
            ]
        case .geminiCLI:
            return googleAuthorizationQueryItems(state: session.state, prompt: "consent")
        case .antigravity:
            return googleAuthorizationQueryItems(state: session.state, prompt: "consent")
        case .xai:
            return [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "code_challenge", value: session.codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: session.state),
                URLQueryItem(name: "nonce", value: session.nonce),
                URLQueryItem(name: "plan", value: "generic"),
                URLQueryItem(name: "referrer", value: "cli-proxy-api")
            ]
        case .kimi:
            return []
        }
    }

    private func googleAuthorizationQueryItems(state: String, prompt: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "prompt", value: prompt),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state)
        ]
    }

    private func normalizedCode(_ code: String) -> String {
        String(code.split(separator: "#", maxSplits: 1).first ?? Substring(code))
    }
}

struct NativeOAuthTokenBundle: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var provider: NativeOAuthProvider
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var tokenType: String?
    var expiresAt: Date?
    var accountID: String?
    var accountLabel: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        provider: NativeOAuthProvider,
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        tokenType: String? = nil,
        expiresAt: Date? = nil,
        accountID: String? = nil,
        accountLabel: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.accountID = accountID
        self.accountLabel = accountLabel
        self.createdAt = createdAt
    }
}

@MainActor
protocol NativeOAuthAuthenticating: AnyObject {
    func callbackURL(
        for authorizationURL: URL,
        provider: NativeOAuthProvider,
        session: NativeOAuthSession
    ) async throws -> URL
}

@MainActor
protocol NativeOAuthTokenStoring {
    func save(_ bundle: NativeOAuthTokenBundle) throws
    func loadAll() throws -> [NativeOAuthTokenBundle]
    func load(provider: NativeOAuthProvider) throws -> [NativeOAuthTokenBundle]
}

@MainActor
protocol NativeOAuthServicing {
    func authorize(
        provider: NativeOAuthProvider,
        authenticator: NativeOAuthAuthenticating,
        tokenStore: NativeOAuthTokenStoring
    ) async throws -> NativeOAuthTokenBundle
}

@MainActor
protocol URLSessionDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionDataLoading {}

@MainActor
final class NativeOAuthService {
    private let session: URLSessionDataLoading
    private let now: () -> Date
    private let decoder = JSONDecoder()

    init(session: URLSessionDataLoading = URLSession.shared, now: @escaping () -> Date = Date.init) {
        self.session = session
        self.now = now
    }

    func authorize(
        provider: NativeOAuthProvider,
        authenticator: NativeOAuthAuthenticating,
        tokenStore: NativeOAuthTokenStoring
    ) async throws -> NativeOAuthTokenBundle {
        let oauthSession = try NativeOAuthSession.make(provider: provider)
        let authorizationURL = try provider.authorizationURL(for: oauthSession)
        let callbackURL = try await authenticator.callbackURL(
            for: authorizationURL,
            provider: provider,
            session: oauthSession
        )
        let code = try provider.authorizationCode(from: callbackURL, expectedState: oauthSession.state)
        let bundle = try await exchangeCode(code, provider: provider, session: oauthSession)
        try tokenStore.save(bundle)
        return bundle
    }

    func exchangeCode(
        _ code: String,
        provider: NativeOAuthProvider,
        session oauthSession: NativeOAuthSession,
        discoveredTokenEndpoint: URL? = nil
    ) async throws -> NativeOAuthTokenBundle {
        let request = try provider.tokenExchangeRequest(
            code: code,
            session: oauthSession,
            discoveredTokenEndpoint: discoveredTokenEndpoint
        )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NativeOAuthError.tokenExchangeFailed(0, "invalid response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NativeOAuthError.tokenExchangeFailed(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8) ?? ""
            )
        }
        let tokenResponse = try decoder.decode(NativeOAuthTokenResponse.self, from: data)
        guard !tokenResponse.accessToken.isEmpty else {
            throw NativeOAuthError.tokenResponseMissingAccessToken
        }
        return tokenResponse.bundle(provider: provider, now: now())
    }
}

extension NativeOAuthService: NativeOAuthServicing {}

private enum NativePKCE {
    static func makeCodeVerifier() throws -> String {
        randomURLSafeString(byteCount: 96)
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

private enum NativeOAuthForm {
    static func encode(_ items: [(String, String)]) -> Data {
        items
            .map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private struct NativeOAuthCallbackValues {
    private var values: [String: String] = [:]

    init(url: URL) {
        append(url.query)
        append(url.fragment)
    }

    func value(for key: String) -> String? {
        values[key]
    }

    private mutating func append(_ raw: String?) {
        guard let raw, !raw.isEmpty else { return }
        var components = URLComponents()
        components.percentEncodedQuery = raw
        for item in components.queryItems ?? [] {
            values[item.name] = item.value ?? ""
        }
    }
}

private struct NativeOAuthTokenResponse: Decodable {
    struct ClaudeAccount: Decodable {
        var emailAddress: String?

        enum CodingKeys: String, CodingKey {
            case emailAddress = "email_address"
        }
    }

    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var tokenType: String?
    var expiresIn: TimeInterval?
    var account: ClaudeAccount?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case account
    }

    func bundle(provider: NativeOAuthProvider, now: Date) -> NativeOAuthTokenBundle {
        let identity = NativeJWTIdentity(idToken: idToken)
        let label = account?.emailAddress ?? identity.email ?? provider.title
        return NativeOAuthTokenBundle(
            provider: provider,
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            tokenType: tokenType,
            expiresAt: expiresIn.map { now.addingTimeInterval($0) },
            accountID: identity.subject,
            accountLabel: label,
            createdAt: now
        )
    }
}

private struct NativeJWTIdentity {
    var email: String?
    var subject: String?

    init(idToken: String?) {
        guard let idToken else { return }
        let segments = idToken.split(separator: ".")
        guard segments.count > 1,
              let payloadData = Data(base64URLEncoded: String(segments[1])),
              let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return
        }
        email = object["email"] as? String
        subject = (object["https://api.openai.com/auth"] as? [String: Any])?["chatgpt_account_id"] as? String
            ?? object["sub"] as? String
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded value: String) {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - normalized.count % 4) % 4
        normalized.append(String(repeating: "=", count: padding))
        self.init(base64Encoded: normalized)
    }
}
