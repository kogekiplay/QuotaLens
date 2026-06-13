import SwiftUI

struct AlertsView: View {
    @State private var nearLimit = true
    @State private var resetReminder = true
    @State private var spike = true
    @State private var renewal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("只在真正需要时提醒")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("默认不打扰。接近上限、重置、异常消耗和订阅续费才会推送。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("3 条规则已开启")
                            .font(.headline.weight(.bold))
                        Text("安静时段 23:00 到 08:00")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("低打扰")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassPanel(radius: QLTheme.pillRadius, tint: QLTheme.brandPrimary.opacity(0.12))
                }
                .padding()
                .glassPanel(radius: 30, tint: QLTheme.brandPrimary.opacity(0.08))

                VStack(spacing: 0) {
                    Toggle("接近限额", isOn: $nearLimit)
                        .padding()
                    Toggle("重置提醒", isOn: $resetReminder)
                        .padding()
                    Toggle("异常消耗峰值", isOn: $spike)
                        .padding()
                    Toggle("订阅续费", isOn: $renewal)
                        .padding()
                }
                .liquidGlassCard(radius: QLTheme.controlRadius)

                VStack(alignment: .leading, spacing: 7) {
                    Text("下次提醒")
                        .font(.headline.weight(.bold))
                    Text("Claude Pro 预计 2 天后达到 80%，届时只推送一条可直接关闭的轻量通知。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .liquidGlassCard(radius: QLTheme.controlRadius)
            }
            .padding(18)
        }
        .background(QLTheme.background)
        .navigationTitle("提醒")
        .navigationBarTitleDisplayMode(.inline)
    }
}
