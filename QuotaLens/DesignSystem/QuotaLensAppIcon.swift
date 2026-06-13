import SwiftUI

struct QuotaLensAppIcon: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [QLTheme.brandPrimary, QLTheme.brandSecondary, QLTheme.brandPrimary.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(.white.opacity(0.82), lineWidth: size * 0.09)
                .padding(size * 0.23)
            Capsule()
                .fill(.white.opacity(0.82))
                .frame(width: size * 0.27, height: size * 0.1)
                .rotationEffect(.degrees(45))
                .offset(x: size * 0.18, y: size * 0.18)
        }
        .frame(width: size, height: size)
        .shadow(color: QLTheme.brandPrimary.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}
