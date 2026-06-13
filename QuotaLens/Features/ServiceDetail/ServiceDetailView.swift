import SwiftUI

struct ServiceDetailView: View {
    var account: AccountQuota
    @Environment(\.dismiss) private var dismiss
    @State private var showsActions = false
    @State private var limitAlertEnabled = true
    @State private var sparkAlertEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                detailHero
                sectionHeader("额度条", trailing: account.planName)
                if account.provider == .codex {
                    CodexQuotaCard(account: account)
                } else {
                    VStack(spacing: 14) {
                        ForEach(account.windows) { window in
                            QuotaProgressLine(window: window)
                        }
                    }
                    .padding(16)
                    .liquidGlassCard()
                }
                sectionHeader("提醒设置", trailing: "2 条已开启")
                alertSettings
            }
            .padding(18)
        }
        .background(QLTheme.background)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("返回")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsActions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(QLTheme.brandPrimary)
                }
                .accessibilityLabel("更多操作")
            }
        }
        .sheet(isPresented: $showsActions) {
            QuickActionsSheet(account: account)
                .presentationDetents([.height(260)])
        }
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ProviderIconView(provider: account.provider, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.title2.weight(.bold))
                    Text(account.accountLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(account.planName)
                    .font(.title3.weight(.bold))
                Text(account.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let primary = account.primaryWindow {
                ProgressView(value: primary.remainingFraction)
                    .tint(primary.progressTint)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("2h18m 后重置")
                        .font(.subheadline.weight(.semibold))
                    Text("5 小时窗口额度仍处于健康状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("5 小时")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassPanel(radius: QLTheme.pillRadius, tint: QLTheme.accent.opacity(0.12))
            }
        }
        .padding(16)
        .liquidGlassCard(radius: 28)
    }

    private var alertSettings: some View {
        VStack(spacing: 0) {
            Toggle("用量达到 80% 时提醒", isOn: $limitAlertEnabled)
                .font(.subheadline.weight(.semibold))
                .padding()
            Divider().padding(.leading)
            Toggle("Spark 额度单独提醒", isOn: $sparkAlertEnabled)
                .font(.subheadline.weight(.semibold))
                .padding()
        }
        .liquidGlassCard(radius: QLTheme.controlRadius)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            Text(trailing)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }
}

private struct QuickActionsSheet: View {
    var account: AccountQuota

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                Capsule()
                    .fill(.secondary.opacity(0.28))
                    .frame(width: 42, height: 5)
                    .padding(.top, 8)
                quickAction("添加账号或订阅", symbol: "plus")
                quickAction("刷新额度", symbol: "arrow.clockwise")
                quickAction("暂停 \(account.name) 提醒", symbol: "pause.fill")
            }
            .padding(18)
            .glassPanel(radius: 34, tint: .white.opacity(0.05))
        }
        .padding(10)
    }

    private func quickAction(_ title: String, symbol: String) -> some View {
        Button {} label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: symbol)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.glass)
    }
}
