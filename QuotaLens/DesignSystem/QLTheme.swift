import SwiftUI

enum QLTheme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let softSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let text = Color.primary
    static let muted = Color.secondary
    static let brandPrimary = Color(red: 0.0, green: 0.62, blue: 0.58)
    static let brandSecondary = Color(red: 0.05, green: 0.46, blue: 0.72)
    static let accent = brandPrimary
    static let mint = brandPrimary
    static let warn = Color(red: 0.88, green: 0.39, blue: 0.12)

    static let cardRadius: CGFloat = 28
    static let controlRadius: CGFloat = 22
    static let pillRadius: CGFloat = 999
    static let scrollBottomPadding: CGFloat = 120

    static func glass(tint: Color? = nil, interactive: Bool = false) -> Glass {
        var effect = Glass.regular
        if let tint {
            effect = effect.tint(tint)
        }
        if interactive {
            effect = effect.interactive()
        }
        return effect
    }
}

struct LiquidGlassCard: ViewModifier {
    var radius: CGFloat = QLTheme.cardRadius
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        content
            .glassEffect(QLTheme.glass(tint: tint, interactive: interactive), in: .rect(cornerRadius: radius))
    }
}

extension View {
    func liquidGlassCard(radius: CGFloat = QLTheme.cardRadius, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(LiquidGlassCard(radius: radius, tint: tint, interactive: interactive))
    }

    func glassPanel(radius: CGFloat = 28, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassPanel(radius: radius, tint: tint, interactive: interactive))
    }
}

private struct GlassPanel: ViewModifier {
    var radius: CGFloat
    var tint: Color?
    var interactive: Bool

    func body(content: Content) -> some View {
        content
            .glassEffect(QLTheme.glass(tint: tint, interactive: interactive), in: .rect(cornerRadius: radius))
    }
}
