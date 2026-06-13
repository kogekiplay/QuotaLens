import SwiftUI
import UniformTypeIdentifiers

struct AccountSheetView: View {
    static let preferredPresentationHeight: CGFloat = 610

    @Environment(\.dismiss) private var dismiss
    private let isFloatingPanel: Bool
    private let onClose: (() -> Void)?
    private let onLoginCompleted: (() -> Void)?
    @State private var query = ""
    @State private var selectedProvider: ProviderKind = .codex
    @State private var apiName = "API 中转站"
    @State private var apiBase = ""
    @State private var apiKey = ""
    @State private var models = ""
    @State private var quota = ""
    @State private var oauthStore = OAuthLoginStore()
    @State private var oauthService = NativeOAuthService()
    @State private var oauthAuthenticator = SystemOAuthSessionAuthenticator()
    @State private var oauthTokenStore = NativeOAuthTokenStore()
    @State private var isImportingCodexAuthFile = false

    private let providers: [ProviderKind] = [.codex, .claude, .chatGPT, .gemini, .cursor, .perplexity, .poe, .apiRelay]

    init(
        isFloatingPanel: Bool = false,
        onClose: (() -> Void)? = nil,
        onLoginCompleted: (() -> Void)? = nil
    ) {
        self.isFloatingPanel = isFloatingPanel
        self.onClose = onClose
        self.onLoginCompleted = onLoginCompleted
    }

    private var filteredProviders: [ProviderKind] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return providers }
        return providers.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) || $0.initials.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        if isFloatingPanel {
            accountSheetContent
        } else {
            ZStack {
                QLTheme.background.ignoresSafeArea()
                ScrollView {
                    accountSheetContent
                }
            }
        }
    }

    private var accountSheetContent: some View {
        GlassEffectContainer(spacing: glassContainerSpacing) {
            VStack(spacing: contentSpacing) {
                header
                search
                providerGrid
                configPanel
            }
            .padding(contentPadding)
            .padding(.bottom, isFloatingPanel ? 6 : 0)
        }
        .fileImporter(
            isPresented: $isImportingCodexAuthFile,
            allowedContentTypes: [.json]
        ) { result in
            handleCodexAuthFileImport(result)
        }
    }

    private var glassContainerSpacing: CGFloat { isFloatingPanel ? 10 : 14 }
    private var contentSpacing: CGFloat { isFloatingPanel ? 10 : 16 }
    private var contentPadding: CGFloat { isFloatingPanel ? 12 : 14 }
    private var searchHeight: CGFloat { isFloatingPanel ? 46 : 50 }
    private var providerGridSpacing: CGFloat { isFloatingPanel ? 7 : 9 }
    private var providerTileSpacing: CGFloat { isFloatingPanel ? 5 : 7 }
    private var providerTileHeight: CGFloat { isFloatingPanel ? 70 : 82 }
    private var providerIconSize: CGFloat { isFloatingPanel ? 36 : 42 }
    private var configPanelSpacing: CGFloat { isFloatingPanel ? 10 : 14 }
    private var configPanelPadding: CGFloat { isFloatingPanel ? 12 : 15 }
    private var officialPanelSpacing: CGFloat { isFloatingPanel ? 8 : 12 }
    private var officialIconSize: CGFloat { isFloatingPanel ? 38 : 48 }
    private var infoCardPadding: CGFloat { isFloatingPanel ? 9 : 12 }
    private var apiFormSpacing: CGFloat { isFloatingPanel ? 8 : 11 }
    private var inputFieldHeight: CGFloat { isFloatingPanel ? 40 : 54 }

    private var header: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 2) {
                Text("添加账号或订阅")
                    .font(.headline.weight(.bold))
                Text("选择要连接的账号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            if !isFloatingPanel {
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索账号或 API 中转站", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 14)
        .frame(height: searchHeight)
        .glassPanel(radius: 25, tint: .white.opacity(0.06), interactive: true)
    }

    private var providerGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: providerGridSpacing), count: 4), spacing: providerGridSpacing) {
            ForEach(filteredProviders) { provider in
                Button {
                    oauthStore.reset()
                    selectedProvider = provider
                } label: {
                    VStack(spacing: providerTileSpacing) {
                        ProviderIconView(provider: provider, size: providerIconSize)
                        Text(provider.displayName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: providerTileHeight)
                    .glassPanel(
                        radius: 22,
                        tint: selectedProvider == provider ? provider.tint.opacity(0.16) : .white.opacity(0.04),
                        interactive: true
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: configPanelSpacing) {
            HStack {
                Text(selectedProvider == .apiRelay ? "手动配置 API" : "登录官方账号")
                    .font(.headline.weight(.bold))
                Spacer()
                Text(selectedProvider == .apiRelay ? "接口地址和密钥" : "安全登录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedProvider == .apiRelay {
                apiForm
            } else {
                officialPanel
            }
        }
        .padding(configPanelPadding)
        .glassPanel(radius: 28, tint: .white.opacity(0.05))
    }

    private var officialPanel: some View {
        VStack(spacing: officialPanelSpacing) {
            HStack(spacing: 12) {
                ProviderIconView(provider: selectedProvider, size: officialIconSize)
                Text("\(selectedProvider.displayName) 官方订阅")
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            if let nativeProvider = selectedProvider.nativeOAuthProvider {
                Button {
                    startNativeOAuth(provider: nativeProvider)
                } label: {
                    if oauthStore.isBusy {
                        ProgressView()
                    } else {
                        Text("使用 \(selectedProvider.displayName) 登录")
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(isFloatingPanel ? .regular : .large)
                .disabled(oauthStore.isBusy)
                if nativeProvider == .codex {
                    Button {
                        isImportingCodexAuthFile = true
                    } label: {
                        Label("导入 Codex 认证文件", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(isFloatingPanel ? .regular : .large)
                    .disabled(oauthStore.isBusy)
                }
                nativeOAuthStatus(provider: nativeProvider)
            } else {
                Text("这个服务暂未接入 App 原生 OAuth。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("本机同步")
                    .font(.caption.weight(.bold))
                Text(isFloatingPanel ? "仅同步账号、订阅与额度重置。" : "仅同步邮箱、订阅状态、可用模型、额度条与重置时间。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isFloatingPanel ? 1 : 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(infoCardPadding)
            .liquidGlassCard(radius: 20)
        }
    }

    private func startNativeOAuth(provider: NativeOAuthProvider) {
        Task {
            await oauthStore.startNativeOAuth(
                provider: provider,
                service: oauthService,
                authenticator: oauthAuthenticator,
                tokenStore: oauthTokenStore
            )
            if oauthStore.isCompleted {
                onLoginCompleted?()
            }
        }
    }

    private func handleCodexAuthFileImport(_ result: Result<URL, Error>) {
        oauthStore.beginImport(provider: .codex)
        do {
            let url = try result.get()
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let bundle = try CodexAuthFileImporter().tokenBundle(from: data)
            try oauthTokenStore.save(bundle)
            oauthStore.completeImportedToken(bundle)
            onLoginCompleted?()
        } catch {
            oauthStore.failImport(provider: .codex, error: error)
        }
    }

    @ViewBuilder
    private func nativeOAuthStatus(provider: NativeOAuthProvider) -> some View {
        if oauthStore.activeProvider == provider || !oauthStore.message.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !oauthStore.message.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: oauthStore.isCompleted ? "checkmark.circle.fill" : "info.circle")
                            .foregroundStyle(oauthStore.isCompleted ? .green : .secondary)
                        Text(oauthStore.message)
                            .font(.caption)
                            .foregroundStyle(oauthStore.isCompleted ? .green : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(infoCardPadding)
            .liquidGlassCard(radius: 20)
        }
    }

    @ViewBuilder
    private var apiForm: some View {
        if isFloatingPanel {
            floatingAPIForm
        } else {
            fullAPIForm
        }
    }

    private var floatingAPIForm: some View {
        VStack(spacing: apiFormSpacing) {
            HStack(spacing: apiFormSpacing) {
                LiquidGlassTextField("账号名称", text: $apiName, minHeight: inputFieldHeight)
                LiquidGlassTextField(
                    "https://api.example.com/v1",
                    text: $apiBase,
                    keyboardType: .URL,
                    autocapitalization: .never,
                    minHeight: inputFieldHeight
                )
            }
            HStack(spacing: apiFormSpacing) {
                LiquidGlassSecureField("sk-...", text: $apiKey, minHeight: inputFieldHeight)
                LiquidGlassTextField("例如：$12.40 / 1,000,000 tokens", text: $quota, minHeight: inputFieldHeight)
            }
            LiquidGlassTextField(
                "例如：gpt-5.3-codex、claude-sonnet-4.5",
                text: $models,
                minHeight: inputFieldHeight
            )
            Button("保存 API 账号") {}
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
        }
    }

    private var fullAPIForm: some View {
        VStack(spacing: apiFormSpacing) {
            LiquidGlassTextField("账号名称", text: $apiName, minHeight: inputFieldHeight)
            LiquidGlassTextField(
                "https://api.example.com/v1",
                text: $apiBase,
                keyboardType: .URL,
                autocapitalization: .never,
                minHeight: inputFieldHeight
            )
            LiquidGlassSecureField("sk-...", text: $apiKey, minHeight: inputFieldHeight)
            LiquidGlassTextField(
                "例如：gpt-5.3-codex、claude-sonnet-4.5",
                text: $models,
                minHeight: inputFieldHeight
            )
            LiquidGlassTextField("例如：$12.40 / 1,000,000 tokens", text: $quota, minHeight: inputFieldHeight)
            Button("保存 API 账号") {}
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
    }
}

private struct LiquidGlassTextField: View {
    private let prompt: String
    @Binding private var text: String
    private let keyboardType: UIKeyboardType
    private let autocapitalization: TextInputAutocapitalization?
    private let axis: Axis
    private let minHeight: CGFloat
    private let lineLimit: ClosedRange<Int>?

    init(
        _ prompt: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization? = nil,
        axis: Axis = .horizontal,
        minHeight: CGFloat = 54,
        lineLimit: ClosedRange<Int>? = nil
    ) {
        self.prompt = prompt
        self._text = text
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.axis = axis
        self.minHeight = minHeight
        self.lineLimit = lineLimit
    }

    var body: some View {
        textField
            .textFieldStyle(.plain)
            .font(.body)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .tint(QLTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, axis == .vertical ? 12 : 0)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .glassPanel(radius: 18, tint: .white.opacity(0.08), interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var textField: some View {
        if let lineLimit {
            TextField(prompt, text: $text, axis: axis)
                .lineLimit(lineLimit)
        } else {
            TextField(prompt, text: $text, axis: axis)
        }
    }
}

private struct LiquidGlassSecureField: View {
    private let prompt: String
    @Binding private var text: String
    private let minHeight: CGFloat

    init(_ prompt: String, text: Binding<String>, minHeight: CGFloat = 54) {
        self.prompt = prompt
        self._text = text
        self.minHeight = minHeight
    }

    var body: some View {
        SecureField(prompt, text: $text)
            .textFieldStyle(.plain)
            .font(.body)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .tint(QLTheme.accent)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .glassPanel(radius: 18, tint: .white.opacity(0.08), interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
