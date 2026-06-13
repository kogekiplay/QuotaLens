import SwiftUI

enum QuotaRingVisualSpec {
    static let size: CGFloat = 158
    static let lineWidth: CGFloat = 16
    static let percentTextWidth: CGFloat = 96
    static let animationDuration = 0.38
    static let scopeChangeAnimation = Animation.easeInOut(duration: animationDuration)
}

struct QuotaRingArc: Shape {
    var startFraction: Double
    var endFraction: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startFraction, endFraction) }
        set {
            startFraction = newValue.first
            endFraction = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let clampedStart = startFraction.clamped(to: 0...1)
        let clampedEnd = endFraction.clamped(to: 0...1)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90 + 360 * clampedStart),
            endAngle: .degrees(-90 + 360 * clampedEnd),
            clockwise: false
        )
        return path
    }
}

struct QuotaRingView: View {
    var fraction: Double
    var caption: String

    private var percent: Int {
        Int((fraction * 100).rounded())
    }

    var body: some View {
        ZStack {
            QuotaRingArc(startFraction: fraction.clamped(to: 0...1), endFraction: 1)
                .stroke(QLTheme.brandPrimary.opacity(0.16), style: StrokeStyle(lineWidth: QuotaRingVisualSpec.lineWidth, lineCap: .butt))
            QuotaRingArc(startFraction: 0, endFraction: fraction.clamped(to: 0...1))
                .stroke(QLTheme.brandPrimary, style: StrokeStyle(lineWidth: QuotaRingVisualSpec.lineWidth, lineCap: .butt))
            VStack(spacing: 5) {
                Text("\(percent)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(percent)))
                    .frame(width: QuotaRingVisualSpec.percentTextWidth, alignment: .center)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .id(caption)
                    .transition(.opacity)
            }
        }
        .frame(width: QuotaRingVisualSpec.size, height: QuotaRingVisualSpec.size)
        .animation(QuotaRingVisualSpec.scopeChangeAnimation, value: fraction)
        .animation(QuotaRingVisualSpec.scopeChangeAnimation, value: caption)
        .accessibilityElement(children: .combine)
    }
}
