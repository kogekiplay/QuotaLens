import SwiftUI

struct ProviderIconView: View {
    var provider: ProviderKind
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let assetName = provider.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: provider.symbolName)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(provider.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(provider.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                            .stroke(provider.tint.opacity(0.28), lineWidth: 1)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
        .accessibilityHidden(true)
    }
}
