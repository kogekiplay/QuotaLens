import Foundation
@testable import QuotaLens

extension AccountQuota {
    static func fixture(
        name: String,
        provider: ProviderKind = .codex,
        remaining: Double
    ) -> AccountQuota {
        fixture(name: name, provider: provider, windows: [
            QuotaWindow(title: "额度", remainingFraction: remaining, kind: .fiveHour)
        ])
    }

    static func fixture(
        name: String,
        provider: ProviderKind = .codex,
        windows: [QuotaWindow]
    ) -> AccountQuota {
        AccountQuota(
            provider: provider,
            name: name,
            accountLabel: "\(name.lowercased())@example.com",
            planName: "Pro",
            subtitle: "测试账号",
            valueLabel: windows.first?.percentLabel ?? "0%",
            valueCaption: "剩余",
            windows: windows
        )
    }
}
