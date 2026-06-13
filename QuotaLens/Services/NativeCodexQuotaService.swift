import Foundation

@MainActor
final class NativeCodexQuotaService {
    enum ServiceError: Error {
        case invalidResponse
        case upstreamFailure(Int)
    }

    private let tokenStore: NativeOAuthTokenStoring
    private let session: URLSessionDataLoading
    private let now: () -> Date
    private let decoder = JSONDecoder()

    init(
        tokenStore: NativeOAuthTokenStoring = NativeOAuthTokenStore(),
        session: URLSessionDataLoading = URLSession.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.tokenStore = tokenStore
        self.session = session
        self.now = now
    }

    func loadAccounts() async throws -> [AccountQuota] {
        let tokens = try tokenStore.load(provider: .codex)
            .filter { !$0.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var accounts: [AccountQuota] = []
        for token in tokens {
            let account = try await loadCodexAccount(token: token)
            accounts.append(account)
        }
        return accounts
    }

    private func loadCodexAccount(token: NativeOAuthTokenBundle) async throws -> AccountQuota {
        let response = try await requestUsage(accessToken: token.accessToken)
        let windows = buildCodexWindows(from: response)
        let valueLabel = windows.first?.percentLabel ?? "0%"
        let accountID = token.accountID ?? token.id

        return AccountQuota(
            id: accountID,
            provider: .codex,
            name: "Codex",
            accountLabel: token.accountLabel,
            planName: planName(from: planType(from: response, token: token)),
            subtitle: "官方 Codex 账号额度",
            valueLabel: valueLabel,
            valueCaption: "剩余",
            windows: windows
        )
    }

    private func requestUsage(accessToken: String) async throws -> [String: JSONValue] {
        guard let url = URL(string: CodexQuotaEndpoint.usageURL) else {
            throw ServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(CodexQuotaEndpoint.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.upstreamFailure(httpResponse.statusCode)
        }
        guard let payload = try decoder.decode(JSONValue.self, from: data).objectValue else {
            throw ServiceError.invalidResponse
        }
        return payload
    }

    private func buildCodexWindows(from payload: [String: JSONValue]) -> [QuotaWindow] {
        let rateLimit = payload.object("rate_limit") ?? payload.object("rateLimit")
        let primaryWindow = rateLimit?.object("primary_window") ?? rateLimit?.object("primaryWindow")
        let secondaryWindow = rateLimit?.object("secondary_window") ?? rateLimit?.object("secondaryWindow")

        let baseWindows = [
            buildWindow(
                id: "codex-five-hour",
                title: "5 小时限额",
                kind: .fiveHour,
                payload: primaryWindow
            ),
            buildWindow(
                id: "codex-weekly",
                title: "周限额",
                kind: .weekly,
                payload: secondaryWindow
            )
        ].compactMap { $0 }

        return baseWindows + buildAdditionalCodexWindows(
            from: payload.array("additional_rate_limits") ?? payload.array("additionalRateLimits")
        )
    }

    private func buildAdditionalCodexWindows(from limits: [JSONValue]?) -> [QuotaWindow] {
        guard let limits else { return [] }

        return limits.flatMap { value -> [QuotaWindow] in
            guard let payload = value.objectValue else { return [] }
            let limitName = payload.string("limit_name") ?? payload.string("limitName") ?? ""
            guard isSparkLimitName(limitName) else { return [] }

            let rateLimit = payload.object("rate_limit") ?? payload.object("rateLimit")
            let primaryWindow = rateLimit?.object("primary_window") ?? rateLimit?.object("primaryWindow")
            let secondaryWindow = rateLimit?.object("secondary_window") ?? rateLimit?.object("secondaryWindow")
            let displayName = displayName(forLimitName: limitName)
            let idPrefix = "codex-\(normalizedLimitID(limitName))"

            return [
                buildWindow(
                    id: "\(idPrefix)-five-hour",
                    title: "\(displayName) 5 小时限额",
                    kind: .sparkFiveHour,
                    payload: primaryWindow
                ),
                buildWindow(
                    id: "\(idPrefix)-weekly",
                    title: "\(displayName) 周限额",
                    kind: .sparkWeekly,
                    payload: secondaryWindow
                )
            ].compactMap { $0 }
        }
    }

    private func buildWindow(
        id: String,
        title: String,
        kind: QuotaWindowKind,
        payload: [String: JSONValue]?
    ) -> QuotaWindow? {
        guard let payload else { return nil }
        let usedPercent = payload.number("used_percent") ?? payload.number("usedPercent") ?? 0
        let remaining = 1 - (usedPercent / 100)
        let resetAfter = payload.number("reset_after_seconds") ?? payload.number("resetAfterSeconds")
        let resetAtSeconds = payload.number("reset_at") ?? payload.number("resetAt")
        let resetAt = resetAfter.map { now().addingTimeInterval($0) }
            ?? resetAtSeconds.map { Date(timeIntervalSince1970: $0) }

        return QuotaWindow(
            id: id,
            title: title,
            remainingFraction: remaining,
            resetAt: resetAt,
            kind: kind
        )
    }

    private func planType(from response: [String: JSONValue], token: NativeOAuthTokenBundle) -> String? {
        response.string("plan_type")
            ?? response.string("planType")
            ?? codexPlanType(fromIDToken: token.idToken)
    }

    private func planName(from raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "官方账号"
        }
        switch raw.lowercased() {
        case "free":
            return "Free"
        case "plus":
            return "Plus"
        case "pro", "pro_20x", "pro-20x", "pro 20x":
            return "Pro 20x"
        case "prolite", "pro_lite", "pro-lite", "pro lite", "pro_5x", "pro-5x", "pro 5x":
            return "Pro 5x"
        case "team":
            return "Team"
        case "enterprise":
            return "Enterprise"
        default:
            return raw.prefix(1).uppercased() + raw.dropFirst()
        }
    }

    private func codexPlanType(fromIDToken idToken: String?) -> String? {
        guard let idToken else { return nil }
        let segments = idToken.split(separator: ".")
        guard segments.count > 1,
              let payloadData = Data(base64URLEncoded: String(segments[1])),
              let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }

        if let planType = object["chatgpt_plan_type"] as? String, !planType.isEmpty {
            return planType
        }
        if let planType = object["chatgptPlanType"] as? String, !planType.isEmpty {
            return planType
        }
        if let authInfo = object["https://api.openai.com/auth"] as? [String: Any] {
            if let planType = authInfo["chatgpt_plan_type"] as? String, !planType.isEmpty {
                return planType
            }
            if let planType = authInfo["chatgptPlanType"] as? String, !planType.isEmpty {
                return planType
            }
        }
        return nil
    }

    private func isSparkLimitName(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return normalized.contains("spark") || normalized.contains("bengalfox")
    }

    private func displayName(forLimitName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "GPT 5.3 Codex Spark"
        }
        return trimmed.replacingOccurrences(of: "-", with: " ")
    }

    private func normalizedLimitID(_ name: String) -> String {
        let parts = name.lowercased().split { !$0.isLetter && !$0.isNumber }
        return parts.isEmpty ? "spark" : parts.joined(separator: "-")
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - normalized.count % 4) % 4
        normalized.append(String(repeating: "=", count: padding))
        self.init(base64Encoded: normalized)
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func object(_ key: String) -> [String: JSONValue]? {
        self[key]?.objectValue
    }

    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func number(_ key: String) -> Double? {
        self[key]?.doubleValue
    }

    func array(_ key: String) -> [JSONValue]? {
        guard case .array(let values) = self[key] else { return nil }
        return values
    }
}
