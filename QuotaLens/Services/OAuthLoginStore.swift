import Foundation
import Observation

@MainActor
@Observable
final class OAuthLoginStore {
    var activeProvider: NativeOAuthProvider?
    var message = ""
    var isBusy = false
    var isCompleted = false
    var accountLabel: String?

    func reset() {
        activeProvider = nil
        message = ""
        isBusy = false
        isCompleted = false
        accountLabel = nil
    }

    func startNativeOAuth(
        provider: NativeOAuthProvider,
        service: NativeOAuthServicing = NativeOAuthService(),
        authenticator: NativeOAuthAuthenticating,
        tokenStore: NativeOAuthTokenStoring = NativeOAuthTokenStore()
    ) async {
        isBusy = true
        isCompleted = false
        activeProvider = provider
        accountLabel = nil
        message = "正在打开 \(provider.title) 官方登录..."

        do {
            let bundle = try await service.authorize(
                provider: provider,
                authenticator: authenticator,
                tokenStore: tokenStore
            )
            isCompleted = true
            accountLabel = bundle.accountLabel
            message = "\(provider.title) 登录完成：\(bundle.accountLabel)"
        } catch {
            isCompleted = false
            message = "无法完成 \(provider.title) 登录：\(error.localizedDescription)"
        }

        isBusy = false
    }

    func beginImport(provider: NativeOAuthProvider) {
        isBusy = true
        isCompleted = false
        activeProvider = provider
        accountLabel = nil
        message = "正在导入 \(provider.title) 认证文件..."
    }

    func completeImportedToken(_ bundle: NativeOAuthTokenBundle) {
        isBusy = false
        isCompleted = true
        activeProvider = bundle.provider
        accountLabel = bundle.accountLabel
        message = "\(bundle.provider.title) 认证文件已导入：\(bundle.accountLabel)"
    }

    func failImport(provider: NativeOAuthProvider, error: Error) {
        isBusy = false
        isCompleted = false
        activeProvider = provider
        accountLabel = nil
        message = "无法导入 \(provider.title) 认证文件：\(error.localizedDescription)"
    }
}
