import SwiftUI

struct InsightsView: View {
    var accounts: [AccountQuota]
    var isLoading = false
    var errorMessage: String?
    @State private var range = 0

    private var summary: InsightSummary {
        InsightSummary(accounts: accounts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Picker("范围", selection: $range) {
                    Text("7 天").tag(0)
                    Text("30 天").tag(1)
                    Text("账单周期").tag(2)
                }
                .pickerStyle(.segmented)
                .glassPanel(radius: QLTheme.controlRadius, tint: QLTheme.accent.opacity(0.08), interactive: true)

                sectionHeader("AI 用量趋势", trailing: "跨服务")
                trendCard
                insights
            }
            .padding(18)
            .padding(.bottom, QLTheme.scrollBottomPadding)
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用量洞察")
                .font(.caption.weight(.bold))
                .foregroundStyle(QLTheme.brandPrimary)
                .textCase(.uppercase)
            Text("洞察")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text(accounts.isEmpty ? "同步真实账号后，这里会根据可见额度生成风险和重置提醒。" : "根据当前已同步账号生成额度健康度和重置提醒。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var trendCard: some View {
        VStack(spacing: 14) {
            if summary.trendSamples.isEmpty {
                EmptyTrendChart()
            } else {
                QuotaUsageTrendChart(samples: summary.trendSamples)
            }
            HStack(spacing: 10) {
                MiniMetric(value: summary.remainingPercentLabel, title: "平均剩余额度")
                MiniMetric(value: summary.accountCountLabel, title: "已同步账号")
            }
            MiniMetric(value: summary.resettingSoonLabel, title: "24 小时内重置窗口")
        }
        .padding(16)
        .liquidGlassCard(radius: 28)
    }

    private var insights: some View {
        VStack(spacing: 11) {
            if isLoading {
                InsightCard(title: "正在同步", copy: "正在使用本地 token 同步账号和额度。")
            } else if let errorMessage, !errorMessage.isEmpty {
                InsightCard(title: "暂时无法生成洞察", copy: errorMessage, soft: true)
            } else {
                ForEach(summary.cards) { card in
                    InsightCard(title: card.title, copy: card.copy, soft: card.isSoft)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct InsightSummary {
    var accounts: [AccountQuota]
    var now: Date

    init(accounts: [AccountQuota], now: Date = Date()) {
        self.accounts = accounts
        self.now = now
    }

    var remainingPercentLabel: String {
        DashboardSummary(accounts: accounts, now: now).remainingPercentLabel
    }

    var accountCountLabel: String {
        "\(accounts.count)"
    }

    var resettingSoonLabel: String {
        "\(DashboardSummary(accounts: accounts, now: now).resettingSoonCount)"
    }

    var trendSamples: [QuotaTrendSample] {
        accounts.flatMap(\.windows).map { window in
            QuotaTrendSample(
                usedFraction: (1 - window.remainingFraction).clamped(to: 0...1),
                label: trendLabel(for: window),
                detailLabel: window.title
            )
        }
    }

    var cards: [InsightSummaryCard] {
        guard !accounts.isEmpty else {
            return [
                InsightSummaryCard(
                    title: "暂无真实用量洞察",
                    copy: "完成官方账号登录并同步额度后，这里会按真实额度生成提醒。",
                    isSoft: true
                )
            ]
        }

        let sorted = accounts.sorted { $0.remainingFraction < $1.remainingFraction }
        let lowest = sorted[0]
        var result = [
            InsightSummaryCard(
                title: "\(lowest.name) 当前剩余 \(lowest.remainingPercentLabel)",
                copy: lowest.remainingFraction < 0.35 ? "这个账号的剩余额度偏低，建议优先关注它的重置时间。" : "当前最低剩余额度仍在可用区间，继续保持常规刷新即可。",
                isSoft: lowest.remainingFraction >= 0.35
            ),
            InsightSummaryCard(
                title: "已同步 \(accounts.count) 个账号",
                copy: "所有洞察都基于本机 OAuth token 获取到的官方额度接口结果。",
                isSoft: true
            )
        ]

        let resettingSoon = DashboardSummary(accounts: accounts, now: now).resettingSoonCount
        if resettingSoon > 0 {
            result.append(
                InsightSummaryCard(
                    title: "\(resettingSoon) 个额度窗口将在 24 小时内重置",
                    copy: "适合把临近重置的账号留给高消耗任务，减少提前耗尽的风险。",
                    isSoft: false
                )
            )
        }

        return result
    }

    private func trendLabel(for window: QuotaWindow) -> String {
        guard let resetAt = window.resetAt else {
            return "额度窗口"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = Calendar.current
        formatter.dateFormat = Calendar.current.isDate(resetAt, inSameDayAs: now) ? "HH:mm" : "MM/dd"
        return formatter.string(from: resetAt)
    }
}

struct InsightSummaryCard: Identifiable, Equatable {
    var id: String { title + copy }
    var title: String
    var copy: String
    var isSoft: Bool
}

struct QuotaTrendSample: Equatable {
    var usedFraction: Double
    var label: String
    var detailLabel: String
}

private extension AccountQuota {
    var remainingPercentLabel: String {
        "\(Int((remainingFraction * 100).rounded()))%"
    }
}

private struct QuotaUsageTrendChart: View {
    var samples: [QuotaTrendSample]

    private var normalizedSamples: [Double] {
        samples.map { $0.usedFraction.clamped(to: 0...1) }
    }

    private var trendDateLabels: [String] {
        guard let first = samples.first?.label,
              let last = samples.last?.label else {
            return []
        }
        return first == last ? [first] : [first, last]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("真实额度窗口")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let rect = CGRect(origin: .zero, size: proxy.size)
                ZStack {
                    TrendGridLines()
                        .stroke(.secondary.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                    if normalizedSamples.count > 1 {
                        QuotaTrendAreaShape(samples: normalizedSamples)
                            .fill(QLTheme.brandPrimary.opacity(0.08))
                        QuotaTrendLineShape(samples: normalizedSamples)
                            .stroke(QLTheme.brandPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(Array(normalizedSamples.enumerated()), id: \.offset) { index, sample in
                        Circle()
                            .fill(QLTheme.brandPrimary)
                            .frame(width: 8, height: 8)
                            .position(TrendPath.point(for: index, sample: sample, count: normalizedSamples.count, in: rect))
                    }

                    VStack {
                        HStack {
                            if let first = normalizedSamples.first {
                                TrendEndpointLabel(value: percentLabel(for: first), title: samples.first?.detailLabel ?? "")
                            }
                            Spacer()
                            if let last = normalizedSamples.last, normalizedSamples.count > 1 {
                                TrendEndpointLabel(value: percentLabel(for: last), title: samples.last?.detailLabel ?? "")
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                }
            }
            .frame(height: 150)

            HStack {
                ForEach(Array(trendDateLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : .trailing)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("真实用量趋势图")
    }

    private func percentLabel(for fraction: Double) -> String {
        "\(Int((fraction.clamped(to: 0...1) * 100).rounded()))%"
    }
}

private struct EmptyTrendChart: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2.weight(.semibold))
            Text("暂无趋势图")
                .font(.headline.weight(.semibold))
            Text("同步真实账号后，会根据官方额度窗口生成图表。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background {
            RoundedRectangle(cornerRadius: QLTheme.controlRadius, style: .continuous)
                .fill(.secondary.opacity(0.07))
        }
        .accessibilityLabel("暂无真实用量趋势")
    }
}

private struct TrendGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<4 {
            let progress = CGFloat(index) / 3
            let y = rect.minY + rect.height * progress
            path.move(to: CGPoint(x: rect.minX + TrendPath.horizontalInset, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - TrendPath.horizontalInset, y: y))
        }
        return path
    }
}

private struct TrendEndpointLabel: View {
    var value: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassPanel(radius: 14, tint: QLTheme.brandPrimary.opacity(0.10))
    }
}

private struct QuotaTrendLineShape: Shape {
    var samples: [Double]

    func path(in rect: CGRect) -> Path {
        TrendPath.line(samples: samples, in: rect)
    }
}

private struct QuotaTrendAreaShape: Shape {
    var samples: [Double]

    func path(in rect: CGRect) -> Path {
        var path = TrendPath.line(samples: samples, in: rect)
        guard samples.count > 1 else {
            return Path()
        }

        path.addLine(to: CGPoint(x: rect.maxX - TrendPath.horizontalInset, y: rect.maxY - TrendPath.verticalInset))
        path.addLine(to: CGPoint(x: rect.minX + TrendPath.horizontalInset, y: rect.maxY - TrendPath.verticalInset))
        path.closeSubpath()
        return path
    }
}

private enum TrendPath {
    static let horizontalInset: CGFloat = 8
    static let verticalInset: CGFloat = 14

    static func line(samples: [Double], in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else {
            return path
        }

        let first = point(for: 0, sample: samples[0], count: samples.count, in: rect)
        path.move(to: first)

        guard samples.count > 1 else {
            return path
        }

        for index in samples.indices.dropFirst() {
            path.addLine(to: point(for: index, sample: samples[index], count: samples.count, in: rect))
        }

        return path
    }

    static func point(for index: Int, sample: Double, count: Int, in rect: CGRect) -> CGPoint {
        let clampedSample = sample.clamped(to: 0...1)
        let availableWidth = max(0, rect.width - horizontalInset * 2)
        let availableHeight = max(0, rect.height - verticalInset * 2)
        let xProgress = count <= 1 ? 0.5 : CGFloat(index) / CGFloat(count - 1)
        let x = rect.minX + horizontalInset + availableWidth * xProgress
        let y = rect.maxY - verticalInset - availableHeight * CGFloat(clampedSample)
        return CGPoint(x: x, y: y)
    }
}

private struct MiniMetric: View {
    var value: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value).font(.title3.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlassCard(radius: QLTheme.controlRadius)
    }
}

private struct InsightCard: View {
    var title: String
    var copy: String
    var soft = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline.weight(.bold))
            Text(copy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlassCard(radius: QLTheme.controlRadius, tint: soft ? QLTheme.brandPrimary.opacity(0.08) : nil)
    }
}
