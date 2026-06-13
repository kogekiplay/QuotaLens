import SwiftUI

struct QuotaProgressLine: View {
    var window: QuotaWindow
    var showsReset: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(metaText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: window.remainingFraction)
                .tint(window.progressTint)
        }
    }

    private var metaText: String {
        if showsReset, let resetAt = window.resetAt {
            return "\(window.percentLabel) · \(resetAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))"
        }
        return window.percentLabel
    }
}
