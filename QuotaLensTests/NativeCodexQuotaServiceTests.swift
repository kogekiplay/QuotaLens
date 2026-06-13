import XCTest
@testable import QuotaLens

@MainActor
final class NativeCodexQuotaServiceTests: XCTestCase {
    func testLoadAccountsFetchesCodexQuotaWithStoredAccessToken() async throws {
        let tokenStore = FakeNativeTokenStore([
            NativeOAuthTokenBundle(
                provider: .codex,
                accessToken: "codex-access-token",
                accountLabel: "coder@example.com"
            )
        ])
        let loader = FakeDataLoader(
            data: """
            {
              "plan_type": "pro",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 25,
                  "reset_after_seconds": 3600
                },
                "secondary_window": {
                  "used_percent": 50,
                  "reset_after_seconds": 86400
                }
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )
        let service = NativeCodexQuotaService(
            tokenStore: tokenStore,
            session: loader,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        let accounts = try await service.loadAccounts()

        XCTAssertEqual(loader.requests.first?.url?.absoluteString, CodexQuotaEndpoint.usageURL)
        XCTAssertEqual(loader.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer codex-access-token")
        XCTAssertEqual(accounts.count, 1)
        let account = try XCTUnwrap(accounts.first)
        XCTAssertEqual(account.provider, .codex)
        XCTAssertEqual(account.accountLabel, "coder@example.com")
        XCTAssertEqual(account.planName, "Pro 20x")
        XCTAssertEqual(account.windows.map(\.percentLabel), ["75%", "50%"])
        XCTAssertEqual(account.valueLabel, "75%")
    }

    func testLoadAccountsWithoutLocalCodexTokensDoesNotCallNetwork() async throws {
        let loader = FakeDataLoader(data: Data("{}".utf8), statusCode: 200)
        let service = NativeCodexQuotaService(
            tokenStore: FakeNativeTokenStore([]),
            session: loader
        )

        let accounts = try await service.loadAccounts()

        XCTAssertTrue(accounts.isEmpty)
        XCTAssertTrue(loader.requests.isEmpty)
    }

    func testLoadAccountsIncludesCodexSparkAdditionalRateLimitForPro20x() async throws {
        let tokenStore = FakeNativeTokenStore([
            NativeOAuthTokenBundle(
                provider: .codex,
                accessToken: "codex-access-token",
                accountLabel: "pro@example.com"
            )
        ])
        let loader = FakeDataLoader(
            data: """
            {
              "plan_type": "pro",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 6,
                  "reset_after_seconds": 12096
                },
                "secondary_window": {
                  "used_percent": 46,
                  "reset_after_seconds": 428207
                }
              },
              "additional_rate_limits": [
                {
                  "limit_name": "GPT-5.3-Codex-Spark",
                  "metered_feature": "codex_bengalfox",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 20,
                      "reset_after_seconds": 1800
                    },
                    "secondary_window": {
                      "used_percent": 75,
                      "reset_after_seconds": 86400
                    }
                  }
                }
              ]
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )
        let service = NativeCodexQuotaService(
            tokenStore: tokenStore,
            session: loader,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        let accounts = try await service.loadAccounts()
        let account = try XCTUnwrap(accounts.first)

        XCTAssertEqual(account.planName, "Pro 20x")
        XCTAssertEqual(account.windows.map(\.kind), [.fiveHour, .weekly, .sparkFiveHour, .sparkWeekly])
        XCTAssertEqual(account.windows.map(\.title), [
            "5 小时限额",
            "周限额",
            "GPT 5.3 Codex Spark 5 小时限额",
            "GPT 5.3 Codex Spark 周限额"
        ])
        XCTAssertEqual(account.windows.map(\.percentLabel), ["94%", "54%", "80%", "25%"])
    }

    func testLoadAccountsKeepsProLitePlanAsPro5xWhenSparkLimitExists() async throws {
        let tokenStore = FakeNativeTokenStore([
            NativeOAuthTokenBundle(
                provider: .codex,
                accessToken: "codex-access-token",
                accountLabel: "prolite@example.com"
            )
        ])
        let loader = FakeDataLoader(
            data: """
            {
              "plan_type": "prolite",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 10,
                  "reset_after_seconds": 3600
                },
                "secondary_window": {
                  "used_percent": 20,
                  "reset_after_seconds": 86400
                }
              },
              "additional_rate_limits": [
                {
                  "limit_name": "GPT-5.3-Codex-Spark",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 30,
                      "reset_after_seconds": 1800
                    }
                  }
                }
              ]
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )
        let service = NativeCodexQuotaService(
            tokenStore: tokenStore,
            session: loader,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        let accounts = try await service.loadAccounts()
        let account = try XCTUnwrap(accounts.first)

        XCTAssertEqual(account.planName, "Pro 5x")
        XCTAssertEqual(account.windows.map(\.kind), [.fiveHour, .weekly, .sparkFiveHour])
    }

    func testLoadAccountsFallsBackToCodexIDTokenPlanTypeWhenUsageOmitsPlanType() async throws {
        let tokenStore = FakeNativeTokenStore([
            NativeOAuthTokenBundle(
                provider: .codex,
                accessToken: "codex-access-token",
                idToken: makeUnsignedIDToken(planType: "prolite"),
                accountLabel: "id-token@example.com"
            )
        ])
        let loader = FakeDataLoader(
            data: """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": 15,
                  "reset_after_seconds": 3600
                }
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )
        let service = NativeCodexQuotaService(tokenStore: tokenStore, session: loader)

        let accounts = try await service.loadAccounts()
        let account = try XCTUnwrap(accounts.first)

        XCTAssertEqual(account.planName, "Pro 5x")
    }
}

private final class FakeNativeTokenStore: NativeOAuthTokenStoring {
    private let bundles: [NativeOAuthTokenBundle]

    init(_ bundles: [NativeOAuthTokenBundle]) {
        self.bundles = bundles
    }

    func save(_ bundle: NativeOAuthTokenBundle) throws {}

    func loadAll() throws -> [NativeOAuthTokenBundle] {
        bundles
    }

    func load(provider: NativeOAuthProvider) throws -> [NativeOAuthTokenBundle] {
        bundles.filter { $0.provider == provider }
    }
}

private final class FakeDataLoader: URLSessionDataLoading {
    var requests: [URLRequest] = []
    var data: Data
    var statusCode: Int

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private func makeUnsignedIDToken(planType: String) -> String {
    let header = #"{"alg":"none"}"#
    let payload = """
    {
      "email": "id-token@example.com",
      "https://api.openai.com/auth": {
        "chatgpt_account_id": "chatgpt-account-id",
        "chatgpt_plan_type": "\(planType)"
      }
    }
    """
    return [
        Data(header.utf8).base64URLEncodedString(),
        Data(payload.utf8).base64URLEncodedString(),
        ""
    ].joined(separator: ".")
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
