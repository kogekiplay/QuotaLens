import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                appSummary
                settingsGroup
            }
            .padding(18)
            .padding(.bottom, QLTheme.scrollBottomPadding)
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("偏好设置")
                .font(.caption.weight(.bold))
                .foregroundStyle(QLTheme.brandPrimary)
                .textCase(.uppercase)
            Text("设置")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text("隐私友好，本地优先。账号、同步、提醒与导出集中管理。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var appSummary: some View {
        HStack(spacing: 12) {
            QuotaLensAppIcon(size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("QuotaLens")
                    .font(.headline.weight(.bold))
                Text("AI 订阅额度与用量追踪")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .liquidGlassCard(radius: QLTheme.controlRadius)
    }

    private var settingsGroup: some View {
        VStack(spacing: 0) {
            SettingRow(title: "账户", subtitle: "本机数据与订阅档案", symbol: "person.crop.circle")
            SettingRow(title: "隐私", subtitle: "凭证不上传，连接状态单独授权", symbol: "lock.shield")
            SettingRow(title: "数据同步", subtitle: "iCloud 私有数据库同步", symbol: "icloud")
            NavigationLink {
                AlertsView()
            } label: {
                SettingRow(title: "提醒", subtitle: "限额、重置、异常消耗、续费", symbol: "bell")
            }
            .buttonStyle(.plain)
            SettingRow(title: "外观", subtitle: "自动", symbol: "circle.lefthalf.filled")
            SettingRow(title: "导出用量", subtitle: "CSV、JSON 或 Shortcuts", symbol: "square.and.arrow.up")
            SettingRow(title: "关于 QuotaLens", subtitle: "版本、许可与反馈", symbol: "info.circle")
        }
        .liquidGlassCard(radius: QLTheme.controlRadius)
    }
}

struct SettingRow: View {
    var title: String
    var subtitle: String
    var symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(QLTheme.brandPrimary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        Divider().padding(.leading, 52)
    }
}
