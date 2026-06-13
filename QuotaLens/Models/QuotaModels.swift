import Foundation
import SwiftUI

enum ProviderKind: String, CaseIterable, Identifiable, Codable {
    case codex
    case claude
    case apiRelay
    case cursor
    case chatGPT
    case gemini
    case perplexity
    case poe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .apiRelay: "API 中转站"
        case .cursor: "Cursor"
        case .chatGPT: "ChatGPT"
        case .gemini: "Gemini"
        case .perplexity: "Perplexity"
        case .poe: "Poe"
        }
    }

    var initials: String {
        switch self {
        case .codex: "CX"
        case .claude: "CL"
        case .apiRelay: "API"
        case .cursor: "CU"
        case .chatGPT: "GPT"
        case .gemini: "GE"
        case .perplexity: "PX"
        case .poe: "PO"
        }
    }

    var assetName: String? {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .chatGPT: "ChatGPT"
        case .gemini: "Gemini"
        case .cursor: "Cursor"
        case .perplexity: "Perplexity"
        case .poe: "Poe"
        case .apiRelay: nil
        }
    }

    var symbolName: String {
        switch self {
        case .codex: "terminal.fill"
        case .claude: "sparkles"
        case .apiRelay: "curlybraces"
        case .cursor: "cursorarrow.rays"
        case .chatGPT: "bubble.left.and.bubble.right.fill"
        case .gemini: "diamond.fill"
        case .perplexity: "magnifyingglass"
        case .poe: "p.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .codex: QLTheme.brandPrimary
        case .claude: .orange
        case .apiRelay: QLTheme.brandPrimary
        case .cursor: .indigo
        case .chatGPT: .green
        case .gemini: .purple
        case .perplexity: .cyan
        case .poe: .pink
        }
    }

    var nativeOAuthProvider: NativeOAuthProvider? {
        switch self {
        case .codex:
            return .codex
        case .claude:
            return .anthropic
        case .gemini:
            return .geminiCLI
        case .apiRelay, .cursor, .chatGPT, .perplexity, .poe:
            return nil
        }
    }
}

enum QuotaWindowKind: String, Codable {
    case fiveHour
    case weekly
    case sparkFiveHour
    case sparkWeekly
    case balance
    case monthly
}

struct QuotaWindow: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var remainingFraction: Double
    var resetAt: Date?
    var kind: QuotaWindowKind

    init(
        id: String = UUID().uuidString,
        title: String,
        remainingFraction: Double,
        resetAt: Date? = nil,
        kind: QuotaWindowKind
    ) {
        self.id = id
        self.title = title
        self.remainingFraction = remainingFraction.clamped(to: 0...1)
        self.resetAt = resetAt
        self.kind = kind
    }

    var percentLabel: String {
        "\(Int((remainingFraction * 100).rounded()))%"
    }

    var progressTint: Color {
        switch remainingFraction {
        case 0.67...1:
            return QLTheme.brandPrimary
        case 0.37..<0.67:
            return QLTheme.warn
        default:
            return .red
        }
    }
}

struct AccountQuota: Identifiable, Hashable, Codable {
    var id: String
    var provider: ProviderKind
    var name: String
    var accountLabel: String
    var planName: String
    var subtitle: String
    var valueLabel: String
    var valueCaption: String
    var windows: [QuotaWindow]

    init(
        id: String = UUID().uuidString,
        provider: ProviderKind,
        name: String,
        accountLabel: String,
        planName: String,
        subtitle: String,
        valueLabel: String,
        valueCaption: String,
        windows: [QuotaWindow]
    ) {
        self.id = id
        self.provider = provider
        self.name = name
        self.accountLabel = accountLabel
        self.planName = planName
        self.subtitle = subtitle
        self.valueLabel = valueLabel
        self.valueCaption = valueCaption
        self.windows = windows
    }

    var remainingFraction: Double {
        guard !windows.isEmpty else { return 0 }
        return windows.map(\.remainingFraction).reduce(0, +) / Double(windows.count)
    }

    var primaryWindow: QuotaWindow? {
        windows.first
    }
}

struct DashboardSummary {
    var accounts: [AccountQuota]
    var now: Date

    init(accounts: [AccountQuota], now: Date = Date()) {
        self.accounts = accounts
        self.now = now
    }

    var remainingFraction: Double {
        guard !accounts.isEmpty else { return 0 }
        return accounts.map(\.remainingFraction).reduce(0, +) / Double(accounts.count)
    }

    var remainingPercentLabel: String {
        percentLabel(for: remainingFraction)
    }

    var fiveHourRemainingFraction: Double {
        averageRemainingFraction(for: [.fiveHour]) ?? remainingFraction
    }

    var fiveHourRemainingPercentLabel: String {
        percentLabel(for: fiveHourRemainingFraction)
    }

    var fiveHourUsedPercentLabel: String {
        guard !accounts.isEmpty else { return "0%" }
        return percentLabel(for: 1 - fiveHourRemainingFraction)
    }

    var weeklyRemainingFraction: Double {
        averageRemainingFraction(for: [.weekly]) ?? remainingFraction
    }

    var weeklyRemainingPercentLabel: String {
        percentLabel(for: weeklyRemainingFraction)
    }

    var fiveHourEarliestResetLabel: String {
        nextResetLabel(for: [.fiveHour])
    }

    var resettingSoonCount: Int {
        let limit = now.addingTimeInterval(24 * 60 * 60)
        return accounts.flatMap(\.windows).filter { window in
            guard let resetAt = window.resetAt else { return false }
            return resetAt >= now && resetAt <= limit
        }.count
    }

    var resettingSoonCountLabel: String {
        "\(resettingSoonCount)"
    }

    private var allWindows: [QuotaWindow] {
        accounts.flatMap(\.windows)
    }

    private func averageRemainingFraction(for kinds: Set<QuotaWindowKind>) -> Double? {
        let matchingWindows = allWindows.filter { kinds.contains($0.kind) }
        guard !matchingWindows.isEmpty else { return nil }
        return matchingWindows.map(\.remainingFraction).reduce(0, +) / Double(matchingWindows.count)
    }

    private func percentLabel(for fraction: Double) -> String {
        "\(Int((fraction.clamped(to: 0...1) * 100).rounded()))%"
    }

    private func nextResetLabel(for kinds: Set<QuotaWindowKind>) -> String {
        let matchingResets = allWindows
            .filter { kinds.contains($0.kind) }
            .compactMap(\.resetAt)
            .filter { $0 >= now }
            .sorted()

        guard let nextReset = matchingResets.first else { return "—" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = Calendar.current
        formatter.dateFormat = Calendar.current.isDate(nextReset, inSameDayAs: now) ? "HH:mm" : "MM/dd HH:mm"

        return formatter.string(from: nextReset)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
