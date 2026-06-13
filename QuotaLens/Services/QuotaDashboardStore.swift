import Foundation
import Observation

@MainActor
protocol QuotaAccountLoading {
    func loadAccounts() async throws -> [AccountQuota]
}

extension NativeCodexQuotaService: QuotaAccountLoading {}

@MainActor
@Observable
final class QuotaDashboardStore {
    var accounts: [AccountQuota] = []
    var refreshDate: Date?
    var isLoading = false
    var errorMessage: String?

    private let makeNativeService: () -> QuotaAccountLoading?

    init(
        makeNativeService: @escaping () -> QuotaAccountLoading? = { NativeCodexQuotaService() }
    ) {
        self.makeNativeService = makeNativeService
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            accounts = try await makeNativeService()?.loadAccounts() ?? []
            refreshDate = Date()
        } catch {
            accounts = []
            errorMessage = Self.message(for: error)
            refreshDate = nil
        }
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? NativeCodexQuotaService.ServiceError {
            switch serviceError {
            case .invalidResponse:
                return "Codex 额度响应无效"
            case .upstreamFailure(let statusCode):
                return "Codex 额度接口请求失败：HTTP \(statusCode)"
            }
        }
        if let storeError = error as? NativeOAuthTokenStore.StoreError {
            switch storeError {
            case .encodingFailed, .decodingFailed, .keychain, .fileStorage:
                return storeError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
