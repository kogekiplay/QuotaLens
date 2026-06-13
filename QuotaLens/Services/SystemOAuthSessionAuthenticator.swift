import AuthenticationServices
import Foundation
import Network
import UIKit

@MainActor
final class SystemOAuthSessionAuthenticator: NSObject, NativeOAuthAuthenticating {
    private var activeSession: ASWebAuthenticationSession?
    private var activeLoopbackServer: LoopbackOAuthCallbackServer?

    func callbackURL(
        for authorizationURL: URL,
        provider: NativeOAuthProvider,
        session: NativeOAuthSession
    ) async throws -> URL {
        if let redirectURL = provider.loopbackRedirectURL {
            return try await loopbackCallbackURL(
                for: authorizationURL,
                provider: provider,
                redirectURL: redirectURL
            )
        }

        return try await systemCallbackURL(
            for: authorizationURL,
            callbackURLScheme: provider.callbackURLScheme
        )
    }

    private func systemCallbackURL(
        for authorizationURL: URL,
        callbackURLScheme: String?
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let webSession = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? NativeOAuthError.invalidCallback(authorizationURL))
                }
            }
            webSession.presentationContextProvider = self
            webSession.prefersEphemeralWebBrowserSession = false
            activeSession = webSession

            if !webSession.start() {
                activeSession = nil
                continuation.resume(throwing: NativeOAuthError.invalidEndpoint)
            }
        }
    }

    private func loopbackCallbackURL(
        for authorizationURL: URL,
        provider: NativeOAuthProvider,
        redirectURL: URL
    ) async throws -> URL {
        let callbackState = OAuthCallbackContinuationState()
        let server = try LoopbackOAuthCallbackServer(
            redirectURL: redirectURL,
            providerTitle: provider.title,
            onCallback: { callbackURL in
                Task { @MainActor in
                    callbackState.resume(returning: callbackURL)
                }
            },
            onFailure: { error in
                Task { @MainActor in
                    callbackState.resume(throwing: error)
                }
            }
        )

        try await server.start()
        activeLoopbackServer = server
        defer {
            activeSession?.cancel()
            activeSession = nil
            activeLoopbackServer?.stop()
            activeLoopbackServer = nil
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                callbackState.setContinuation(continuation)

                let webSession = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callbackURLScheme: nil
                ) { [weak self] callbackURL, error in
                    self?.activeSession = nil
                    if let callbackURL {
                        callbackState.resume(returning: callbackURL)
                    } else if !callbackState.hasFinished {
                        callbackState.resume(throwing: error ?? NativeOAuthError.invalidCallback(authorizationURL))
                    }
                }
                webSession.presentationContextProvider = self
                webSession.prefersEphemeralWebBrowserSession = false
                activeSession = webSession

                if !webSession.start() {
                    activeSession = nil
                    callbackState.resume(throwing: NativeOAuthError.invalidEndpoint)
                }
            }
        } onCancel: {
            Task { @MainActor in
                callbackState.resume(throwing: NativeOAuthError.invalidCallback(authorizationURL))
                self.activeSession?.cancel()
                self.activeSession = nil
                self.activeLoopbackServer?.stop()
                self.activeLoopbackServer = nil
            }
        }
    }
}

extension SystemOAuthSessionAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        preconditionFailure("ASWebAuthenticationSession requested a presentation anchor without a window scene.")
    }
}

@MainActor
private final class OAuthCallbackContinuationState {
    private var continuation: CheckedContinuation<URL, Error>?
    private(set) var hasFinished = false

    func setContinuation(_ continuation: CheckedContinuation<URL, Error>) {
        self.continuation = continuation
    }

    func resume(returning url: URL) {
        guard !hasFinished else { return }
        hasFinished = true
        continuation?.resume(returning: url)
        continuation = nil
    }

    func resume(throwing error: Error) {
        guard !hasFinished else { return }
        hasFinished = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private final class LoopbackOAuthCallbackServer: @unchecked Sendable {
    private let redirectURL: URL
    private let providerTitle: String
    private let onCallback: @Sendable (URL) -> Void
    private let onFailure: @Sendable (Error) -> Void
    private let queue = DispatchQueue(label: "com.kogeki.QuotaLens.loopbackOAuthCallback")
    private let listener: NWListener
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var didStart = false
    private var didCaptureCallback = false

    init(
        redirectURL: URL,
        providerTitle: String,
        onCallback: @escaping @Sendable (URL) -> Void,
        onFailure: @escaping @Sendable (Error) -> Void
    ) throws {
        guard let portValue = redirectURL.port,
              let port = NWEndpoint.Port(rawValue: UInt16(portValue)) else {
            throw NativeOAuthError.invalidCallback(redirectURL)
        }

        self.redirectURL = redirectURL
        self.providerTitle = providerTitle
        self.onCallback = onCallback
        self.onFailure = onFailure

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters, on: port)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.startContinuation = continuation
                self.listener.stateUpdateHandler = { [weak self] state in
                    guard let server = self else { return }
                    server.queue.async {
                        server.handle(state)
                    }
                }
                self.listener.newConnectionHandler = { [weak self] connection in
                    guard let server = self else { return }
                    server.queue.async {
                        server.handle(connection)
                    }
                }
                self.listener.start(queue: self.queue)
            }
        }
    }

    func stop() {
        queue.async {
            self.listener.cancel()
            if let continuation = self.startContinuation {
                self.startContinuation = nil
                continuation.resume(throwing: NativeOAuthError.invalidCallback(self.redirectURL))
            }
        }
    }

    private func handle(_ state: NWListener.State) {
        switch state {
        case .ready:
            didStart = true
            startContinuation?.resume()
            startContinuation = nil
        case .failed(let error):
            startContinuation?.resume(throwing: error)
            startContinuation = nil
            onFailure(error)
        case .cancelled:
            if !didStart {
                startContinuation?.resume(throwing: NativeOAuthError.invalidCallback(redirectURL))
                startContinuation = nil
            }
        default:
            break
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                self.onFailure(error)
            }
        }
        connection.start(queue: queue)
        receiveRequest(from: connection)
    }

    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                self.onFailure(error)
                connection.cancel()
                return
            }

            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let callbackURL = self.callbackURL(from: request) else {
                self.sendResponse(
                    statusCode: 400,
                    reason: "Bad Request",
                    body: self.htmlPage(
                        title: "登录回调无效",
                        message: "QuotaLens 没有收到 \(self.providerTitle) 的有效 OAuth 回调。"
                    ),
                    connection: connection
                )
                return
            }

            self.sendResponse(
                statusCode: 200,
                reason: "OK",
                body: self.htmlPage(
                    title: "登录完成",
                    message: "\(self.providerTitle) 已授权，正在返回 QuotaLens。"
                ),
                connection: connection
            )

            if !self.didCaptureCallback {
                self.didCaptureCallback = true
                self.onCallback(callbackURL)
            }
        }
    }

    private func callbackURL(from request: String) -> URL? {
        guard let requestLine = request.components(separatedBy: "\r\n").first else {
            return nil
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2, parts[0] == "GET" else {
            return nil
        }

        let requestTarget = parts[1]
        guard let components = URLComponents(string: requestTarget) else {
            return nil
        }

        let path = components.path.isEmpty ? "/" : components.path
        guard path == redirectURL.path else {
            return nil
        }

        var callbackComponents = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)
        callbackComponents?.path = path
        callbackComponents?.percentEncodedQuery = components.percentEncodedQuery
        return callbackComponents?.url
    }

    private func sendResponse(statusCode: Int, reason: String, body: String, connection: NWConnection) {
        let response = """
        HTTP/1.1 \(statusCode) \(reason)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func htmlPage(title: String, message: String) -> String {
        """
        <!doctype html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title)</title>
        <style>
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; background: #f5f7fb; color: #111827; }
        main { width: min(86vw, 420px); padding: 28px; border-radius: 24px; background: rgba(255, 255, 255, 0.86); box-shadow: 0 24px 80px rgba(15, 23, 42, 0.16); text-align: center; }
        .mark { width: 58px; height: 58px; margin: 0 auto 18px; border-radius: 50%; display: grid; place-items: center; background: #10b981; color: white; font-size: 34px; font-weight: 700; }
        h1 { margin: 0 0 10px; font-size: 24px; }
        p { margin: 0; color: #6b7280; line-height: 1.55; }
        </style>
        </head>
        <body>
        <main>
        <div class="mark">✓</div>
        <h1>\(title)</h1>
        <p>\(message)</p>
        </main>
        </body>
        </html>
        """
    }
}
