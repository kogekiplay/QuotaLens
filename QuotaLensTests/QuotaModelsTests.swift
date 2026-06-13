import XCTest
@testable import QuotaLens

final class QuotaModelsTests: XCTestCase {
    func testDashboardSummaryAveragesRemainingAcrossAccounts() {
        let accounts = [
            AccountQuota.fixture(name: "Codex", remaining: 0.95),
            AccountQuota.fixture(name: "Claude", remaining: 0.36),
            AccountQuota.fixture(name: "API", remaining: 0.68)
        ]

        let summary = DashboardSummary(accounts: accounts)

        XCTAssertEqual(summary.remainingFraction, 0.663, accuracy: 0.001)
        XCTAssertEqual(summary.remainingPercentLabel, "66%")
    }

    func testDashboardSummaryCountsWindowsResettingWithinOneDay() {
        let now = Date(timeIntervalSince1970: 1_000)
        let soon = now.addingTimeInterval(60 * 60 * 6)
        let later = now.addingTimeInterval(60 * 60 * 48)
        let accounts = [
            AccountQuota.fixture(name: "Codex", windows: [
                QuotaWindow(title: "5 小时限额", remainingFraction: 0.95, resetAt: soon, kind: .fiveHour),
                QuotaWindow(title: "周限额", remainingFraction: 0.55, resetAt: later, kind: .weekly)
            ]),
            AccountQuota.fixture(name: "Claude", windows: [
                QuotaWindow(title: "周限额", remainingFraction: 0.36, resetAt: later, kind: .weekly)
            ])
        ]

        let summary = DashboardSummary(accounts: accounts, now: now)

        XCTAssertEqual(summary.resettingSoonCount, 1)
    }

    func testDashboardSummaryUsesFiveHourPercentMetricsWithoutInventingHours() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: 12, minute: 30))!
        let fiveHourReset = now.addingTimeInterval(60 * 60)
        let weeklyReset = now.addingTimeInterval(60 * 60 * 24 * 5)
        let accounts = [
            AccountQuota.fixture(name: "Codex", windows: [
                QuotaWindow(title: "5 小时限额", remainingFraction: 0.92, resetAt: fiveHourReset, kind: .fiveHour),
                QuotaWindow(title: "周限额", remainingFraction: 0.54, resetAt: weeklyReset, kind: .weekly),
                QuotaWindow(title: "GPT 5.3 Codex Spark 5 小时限额", remainingFraction: 1, resetAt: fiveHourReset, kind: .sparkFiveHour)
            ])
        ]

        let summary = DashboardSummary(accounts: accounts, now: now)

        XCTAssertEqual(summary.fiveHourRemainingFraction, 0.92, accuracy: 0.001)
        XCTAssertEqual(summary.fiveHourRemainingPercentLabel, "92%")
        XCTAssertEqual(summary.fiveHourUsedPercentLabel, "8%")
        XCTAssertEqual(summary.weeklyRemainingFraction, 0.54, accuracy: 0.001)
        XCTAssertEqual(summary.weeklyRemainingPercentLabel, "54%")
        XCTAssertEqual(summary.fiveHourEarliestResetLabel, "13:30")
        XCTAssertEqual(summary.resettingSoonCountLabel, "2")
    }

    func testDashboardSummaryUsesEarliestFiveHourResetAcrossMultipleAccounts() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: 12, minute: 30))!
        let firstReset = now.addingTimeInterval(60 * 45)
        let secondReset = now.addingTimeInterval(60 * 60 * 3)
        let weeklyReset = now.addingTimeInterval(60 * 60 * 24)
        let accounts = [
            AccountQuota.fixture(name: "Codex", windows: [
                QuotaWindow(title: "5 小时限额", remainingFraction: 0.92, resetAt: secondReset, kind: .fiveHour),
                QuotaWindow(title: "周限额", remainingFraction: 0.54, resetAt: weeklyReset, kind: .weekly)
            ]),
            AccountQuota.fixture(name: "Work Codex", windows: [
                QuotaWindow(title: "5 小时限额", remainingFraction: 0.72, resetAt: firstReset, kind: .fiveHour)
            ])
        ]

        let summary = DashboardSummary(accounts: accounts, now: now)

        XCTAssertEqual(summary.fiveHourRemainingFraction, 0.82, accuracy: 0.001)
        XCTAssertEqual(summary.fiveHourEarliestResetLabel, "13:15")
    }

    func testDashboardSummaryUsesEmptyDefaults() {
        let summary = DashboardSummary(accounts: [])

        XCTAssertEqual(summary.remainingFraction, 0)
        XCTAssertEqual(summary.remainingPercentLabel, "0%")
        XCTAssertEqual(summary.fiveHourRemainingFraction, 0)
        XCTAssertEqual(summary.fiveHourRemainingPercentLabel, "0%")
        XCTAssertEqual(summary.fiveHourUsedPercentLabel, "0%")
        XCTAssertEqual(summary.fiveHourEarliestResetLabel, "—")
        XCTAssertEqual(summary.resettingSoonCount, 0)
    }

    func testInsightSummaryHasNoTrendSamplesWithoutAccounts() {
        let summary = InsightSummary(accounts: [])

        XCTAssertTrue(summary.trendSamples.isEmpty)
    }

    func testInsightSummaryBuildsTrendSamplesFromRealQuotaWindows() {
        let accounts = [
            AccountQuota.fixture(name: "Codex", windows: [
                QuotaWindow(title: "5 小时限额", remainingFraction: 0.80, kind: .fiveHour),
                QuotaWindow(title: "周限额", remainingFraction: 0.40, kind: .weekly)
            ]),
            AccountQuota.fixture(name: "Claude", windows: [
                QuotaWindow(title: "周限额", remainingFraction: 0.90, kind: .weekly)
            ])
        ]

        let summary = InsightSummary(accounts: accounts)

        XCTAssertEqual(summary.trendSamples.count, 3)
        XCTAssertEqual(summary.trendSamples[0].usedFraction, 0.20, accuracy: 0.001)
        XCTAssertEqual(summary.trendSamples[1].usedFraction, 0.60, accuracy: 0.001)
        XCTAssertEqual(summary.trendSamples[2].usedFraction, 0.10, accuracy: 0.001)
        XCTAssertEqual(summary.trendSamples[0].label, "额度窗口")
        XCTAssertEqual(summary.trendSamples[0].detailLabel, "5 小时限额")
    }
}
