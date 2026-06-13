import SwiftUI

enum StatusPillVisualSpec {
    static let height: CGFloat = 60
    static let horizontalPadding: CGFloat = 16
    static let contentSpacing: CGFloat = 12
    static let textSpacing: CGFloat = 2
    static let indicatorSize: CGFloat = 8
    static let indicatorFrameSize: CGFloat = 44
    static let opticalCenterYOffset: CGFloat = 1
}

struct TodayView: View {
    var accounts: [AccountQuota]
    var refreshDate: Date?
    var isLoading = false
    var errorMessage: String?
    var onOpenAccount: (AccountQuota) -> Void = { _ in }
    @State private var selectedScope = 0

    private var summary: DashboardSummary {
        DashboardSummary(accounts: accounts, now: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                summaryPill
                metricGrid
                ringCard
                sectionLabel
                accountList
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, QLTheme.scrollBottomPadding)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日概览")
                .font(.caption.weight(.bold))
                .foregroundStyle(QLTheme.brandPrimary)
                .textCase(.uppercase)
            Text("今日")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text(accounts.isEmpty ? "完成官方账号登录后，真实账号额度会显示在这里。" : "你的 AI 订阅额度会从官方实时同步。")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
    }

    private var summaryPill: some View {
        HStack(alignment: .center, spacing: StatusPillVisualSpec.contentSpacing) {
            VStack(alignment: .leading, spacing: StatusPillVisualSpec.textSpacing) {
                Text(summaryStatusTitle)
                    .font(.title3.weight(.bold))
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: .infinity, alignment: .center)
            .offset(y: StatusPillVisualSpec.opticalCenterYOffset)

            Spacer(minLength: 0)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(
                        width: StatusPillVisualSpec.indicatorFrameSize,
                        height: StatusPillVisualSpec.indicatorFrameSize,
                        alignment: .center
                    )
                    .offset(y: StatusPillVisualSpec.opticalCenterYOffset)
            } else {
                Circle()
                    .fill(summaryStatusColor)
                    .frame(width: StatusPillVisualSpec.indicatorSize, height: StatusPillVisualSpec.indicatorSize)
                    .shadow(color: summaryStatusColor.opacity(0.6), radius: 8)
                    .frame(
                        width: StatusPillVisualSpec.indicatorFrameSize,
                        height: StatusPillVisualSpec.indicatorFrameSize,
                        alignment: .center
                    )
                    .offset(y: StatusPillVisualSpec.opticalCenterYOffset)
            }
        }
        .padding(.leading, StatusPillVisualSpec.horizontalPadding)
        .padding(.trailing, 0)
        .frame(height: StatusPillVisualSpec.height, alignment: .center)
        .glassPanel(radius: 30, tint: summaryStatusColor.opacity(0.08))
    }

    private var summaryStatusTitle: String {
        if isLoading {
            return "正在同步真实额度"
        }
        if errorMessage != nil {
            return "同步需要处理"
        }
        if accounts.isEmpty {
            return "等待连接真实账号"
        }
        return summary.fiveHourRemainingFraction < 0.35 ? "5 小时额度偏低" : "5 小时额度状态良好"
    }

    private var summaryStatusColor: Color {
        if errorMessage != nil {
            return QLTheme.warn
        }
        if accounts.isEmpty {
            return QLTheme.brandSecondary
        }
        return summary.fiveHourRemainingFraction < 0.35 ? QLTheme.warn : QLTheme.brandPrimary
    }

    private var statusText: String {
        if isLoading {
            return "正在同步真实额度..."
        }
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        if refreshDate != nil {
            return accounts.isEmpty ? "已连接，但没有可显示的 Codex 认证文件" : "刚刚刷新 · 额度已同步"
        }
        return "等待首次同步"
    }

    private var metricGrid: some View {
        HStack(spacing: 10) {
            MetricTile(value: summary.fiveHourEarliestResetLabel, title: "最近重置")
            MetricTile(value: summary.weeklyRemainingPercentLabel, title: "本周剩余")
            MetricTile(value: summary.resettingSoonCountLabel, title: "重置窗口数")
        }
    }

    private var ringCard: some View {
        VStack(spacing: 18) {
            Picker("范围", selection: $selectedScope) {
                Text("5 小时").tag(0)
                Text("本周").tag(1)
                Text("全部").tag(2)
            }
            .pickerStyle(.segmented)
            .glassPanel(radius: QLTheme.controlRadius, tint: QLTheme.accent.opacity(0.08), interactive: true)

            QuotaRingView(
                fraction: selectedScopeRemainingFraction,
                caption: ["5 小时剩余", "本周剩余", "全部订阅"][selectedScope]
            )
            .animation(QuotaRingVisualSpec.scopeChangeAnimation, value: selectedScope)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .liquidGlassCard(radius: QLTheme.cardRadius)
    }

    private var selectedScopeRemainingFraction: Double {
        switch selectedScope {
        case 0:
            return summary.fiveHourRemainingFraction
        case 1:
            return summary.weeklyRemainingFraction
        default:
            return summary.remainingFraction
        }
    }

    private var sectionLabel: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("账号额度")
                .font(.title3.weight(.bold))
            Spacer()
        }
        .padding(.top, 10)
    }

    private var accountList: some View {
        VStack(spacing: 10) {
            if accounts.isEmpty {
                emptyAccountState
            } else {
                ForEach(accounts) { account in
                    Button {
                        onOpenAccount(account)
                    } label: {
                        if account.provider == .codex {
                            CodexQuotaCard(account: account)
                        } else {
                            ServiceRow(account: account)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: QLTheme.cardRadius, style: .continuous))
                }
            }
        }
    }

    private var emptyAccountState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("暂无真实额度")
                    .font(.headline.weight(.bold))
                Text("点击左下角添加账号，使用 iOS 系统网页登录官方账号。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ConnectableServicesPreview()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlassCard(radius: QLTheme.cardRadius, tint: QLTheme.accent.opacity(0.04))
    }
}

private struct MetricTile: View {
    var value: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 92)
        .padding(.horizontal, 12)
        .liquidGlassCard(radius: QLTheme.controlRadius)
    }
}

private struct ConnectableServicesPreview: View {
    private let providers: [ProviderKind] = [.codex, .claude, .chatGPT, .gemini, .cursor, .perplexity]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(providers) { provider in
                HStack(spacing: 10) {
                    ProviderIconView(provider: provider, size: 30)
                        .opacity(0.72)

                    Text(provider.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.62))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Circle()
                        .fill(provider.tint.opacity(0.28))
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .background(provider.tint.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 1)
                }
                .accessibilityLabel(provider.displayName)
            }
        }
        .opacity(0.82)
    }
}

struct CodexQuotaCard: View {
    var account: AccountQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ProviderIconView(provider: account.provider)
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline.weight(.bold))
                    Text(account.accountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                QuotaPlanBadge(title: account.planName)
            }

            Divider()

            VStack(spacing: 14) {
                ForEach(account.windows) { window in
                    QuotaProgressLine(window: window)
                }
            }
        }
        .padding(14)
        .liquidGlassCard(radius: QLTheme.cardRadius)
    }
}

struct ServiceRow: View {
    var account: AccountQuota

    var body: some View {
        HStack(spacing: 12) {
            ProviderIconView(provider: account.provider)
            VStack(alignment: .leading, spacing: 6) {
                Text(account.name)
                    .font(.headline.weight(.semibold))
                Text(account.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let window = account.primaryWindow {
                    ProgressView(value: window.remainingFraction)
                        .tint(window.progressTint)
                }
            }
            Spacer()
            QuotaPlanBadge(title: account.planName)
        }
        .padding(12)
        .liquidGlassCard(radius: QLTheme.controlRadius)
    }
}

private struct QuotaPlanBadge: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(QLTheme.brandPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .glassPanel(radius: QLTheme.pillRadius, tint: QLTheme.brandPrimary.opacity(0.14))
    }
}
