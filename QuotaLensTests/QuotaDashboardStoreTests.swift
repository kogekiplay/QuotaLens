import XCTest
@testable import QuotaLens

@MainActor
final class QuotaDashboardStoreTests: XCTestCase {
    func testRefreshLoadsNativeAccountsOnly() async {
        let native = FakeQuotaAccountService(accounts: [Self.account(id: "native")])
        let store = QuotaDashboardStore(makeNativeService: { native })

        await store.refresh()

        XCTAssertEqual(native.loadCount, 1)
        XCTAssertEqual(store.accounts.map(\.id), ["native"])
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(store.refreshDate)
    }

    func testRefreshWithoutNativeAccountsFinishesEmptyWithoutError() async {
        let native = FakeQuotaAccountService(accounts: [])
        let store = QuotaDashboardStore(makeNativeService: { native })

        await store.refresh()

        XCTAssertEqual(native.loadCount, 1)
        XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(store.refreshDate)
    }

    private static func account(id: String) -> AccountQuota {
        AccountQuota(
            id: id,
            provider: .codex,
            name: "Codex",
            accountLabel: "\(id)@example.com",
            planName: "Pro",
            subtitle: "测试",
            valueLabel: "90%",
            valueCaption: "剩余",
            windows: [
                QuotaWindow(title: "5 小时限额", remainingFraction: 0.9, kind: .fiveHour)
            ]
        )
    }
}

private final class FakeQuotaAccountService: QuotaAccountLoading {
    var accounts: [AccountQuota]
    var loadCount = 0

    init(accounts: [AccountQuota]) {
        self.accounts = accounts
    }

    func loadAccounts() async throws -> [AccountQuota] {
        loadCount += 1
        return accounts
    }
}
