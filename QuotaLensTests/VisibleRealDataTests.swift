import XCTest
@testable import QuotaLens

final class VisibleRealDataTests: XCTestCase {
    func testProductionModelsDoNotCarrySampleQuotaAccounts() throws {
        let source = try source("QuotaLens/Models/QuotaModels.swift")

        XCTAssertFalse(source.contains("SampleQuotaData"))
        XCTAssertFalse(source.contains("fixture("))
        XCTAssertFalse(source.contains("测试账号"))
        XCTAssertFalse(source.contains("@example.com"))
        XCTAssertNil(source.range(of: #"[A-Za-z0-9._%+-]+@(gmail|outlook|qq)\.com"#, options: .regularExpression))
        XCTAssertFalse(source.contains("Pro 20x"))
        XCTAssertFalse(source.contains("Max 5x"))
    }

    func testInsightsViewIsDrivenByDashboardAccountsInsteadOfHardCodedClaims() throws {
        let source = try source("QuotaLens/Features/Insights/InsightsView.swift")

        XCTAssertTrue(source.contains("var accounts: [AccountQuota]"))
        XCTAssertTrue(source.contains("InsightSummary(accounts: accounts"))
        XCTAssertFalse(source.contains("+18%"))
        XCTAssertFalse(source.contains("Claude 本周增速"))
        XCTAssertFalse(source.contains("ChatGPT Plus"))
        XCTAssertFalse(source.contains("按当前速度，Claude 会在重置前 3 天用尽额度。"))
    }

    func testInsightsTrendUsesRealQuotaWindowsInsteadOfHardCodedShape() throws {
        let source = try source("QuotaLens/Features/Insights/InsightsView.swift")

        XCTAssertFalse(source.contains("TrendShape()"))
        XCTAssertFalse(source.contains("private struct TrendShape"))
        XCTAssertTrue(source.contains("summary.trendSamples"))
        XCTAssertTrue(source.contains("accounts.flatMap(\\.windows)"))
    }

    func testTodayEmptyStateShowsConnectableServicePreviewWithoutFakeQuotaData() throws {
        let source = try source("QuotaLens/Features/Dashboard/TodayView.swift")

        XCTAssertTrue(source.contains("ConnectableServicesPreview()"))
        XCTAssertTrue(source.contains("ProviderIconView(provider: provider"))
        XCTAssertTrue(source.contains("[.codex, .claude, .chatGPT, .gemini, .cursor, .perplexity]"))
        XCTAssertFalse(source.contains("Pro 20x"))
        XCTAssertFalse(source.contains("Max 5x"))
        XCTAssertFalse(source.contains("剩余 80%"))
    }

    func testTodayMetricsUseFiveHourPercentagesInsteadOfInventedHourEstimates() throws {
        let source = try source("QuotaLens/Features/Dashboard/TodayView.swift")

        XCTAssertTrue(source.contains("summary.weeklyRemainingPercentLabel"))
        XCTAssertTrue(source.contains("summary.resettingSoonCountLabel"))
        XCTAssertTrue(source.contains("summary.fiveHourEarliestResetLabel"))
        XCTAssertTrue(source.contains("最近重置"))
        XCTAssertTrue(source.contains("本周剩余"))
        XCTAssertTrue(source.contains("重置窗口数"))
        XCTAssertFalse(source.contains("5 小时剩余额度 \\(summary.fiveHourRemainingPercentLabel)"))
        XCTAssertFalse(source.contains("summary.fiveHourUsedPercentLabel"))
        XCTAssertFalse(source.contains("5 小时已用"))
        XCTAssertFalse(source.contains("下次重置"))
        XCTAssertFalse(source.contains("summary.availableHoursLabel"))
        XCTAssertFalse(source.contains("summary.dailyBurnLabel"))
        XCTAssertFalse(source.contains("总可用时长"))
        XCTAssertFalse(source.contains("即将重置"))
        XCTAssertFalse(source.contains("每日消耗"))
    }

    func testTodaySummaryPillCentersTextGroupAndStatusDotOnSameAxis() throws {
        let source = try source("QuotaLens/Features/Dashboard/TodayView.swift")

        XCTAssertTrue(source.contains("enum StatusPillVisualSpec"))
        XCTAssertTrue(source.contains("static let height: CGFloat = 60"))
        XCTAssertTrue(source.contains("static let horizontalPadding: CGFloat = 16"))
        XCTAssertTrue(source.contains("static let contentSpacing: CGFloat = 12"))
        XCTAssertTrue(source.contains("static let indicatorFrameSize: CGFloat = 44"))
        XCTAssertTrue(source.contains("static let opticalCenterYOffset: CGFloat = 1"))
        XCTAssertTrue(source.contains("HStack(alignment: .center, spacing: StatusPillVisualSpec.contentSpacing)"))
        XCTAssertTrue(source.contains(".frame(maxHeight: .infinity, alignment: .center)"))
        XCTAssertTrue(source.contains(".offset(y: StatusPillVisualSpec.opticalCenterYOffset)"))
        XCTAssertTrue(source.contains("width: StatusPillVisualSpec.indicatorFrameSize"))
        XCTAssertTrue(source.contains("height: StatusPillVisualSpec.indicatorFrameSize"))
        XCTAssertTrue(source.contains("alignment: .center"))
        XCTAssertTrue(source.contains(".padding(.leading, StatusPillVisualSpec.horizontalPadding)"))
        XCTAssertTrue(source.contains(".padding(.trailing, 0)"))
        XCTAssertTrue(source.contains(".frame(height: StatusPillVisualSpec.height, alignment: .center)"))
        XCTAssertFalse(source.contains("HStack {\n            VStack(alignment: .leading, spacing: 3)"))
    }

    func testVisualSystemUsesUnifiedBrandPrimaryInsteadOfLooseSystemBlue() throws {
        let theme = try source("QuotaLens/DesignSystem/QLTheme.swift")
        let today = try source("QuotaLens/Features/Dashboard/TodayView.swift")
        let insights = try source("QuotaLens/Features/Insights/InsightsView.swift")
        let settings = try source("QuotaLens/Features/Settings/SettingsView.swift")
        let ring = try source("QuotaLens/DesignSystem/QuotaRingView.swift")
        let appIcon = try source("QuotaLens/DesignSystem/QuotaLensAppIcon.swift")

        XCTAssertTrue(theme.contains("static let brandPrimary"))
        XCTAssertTrue(theme.contains("static let accent = brandPrimary"))
        XCTAssertTrue(theme.contains("static let cardRadius: CGFloat = 28"))
        XCTAssertTrue(theme.contains("static let controlRadius: CGFloat = 22"))
        XCTAssertTrue(today.contains(".foregroundStyle(QLTheme.brandPrimary)"))
        XCTAssertTrue(insights.contains(".foregroundStyle(QLTheme.brandPrimary)"))
        XCTAssertTrue(settings.contains(".foregroundStyle(QLTheme.brandPrimary)"))
        XCTAssertTrue(ring.contains("QLTheme.brandPrimary.opacity"))
        XCTAssertTrue(ring.contains("lineCap: .butt"))
        XCTAssertTrue(appIcon.contains("QLTheme.brandPrimary"))
        XCTAssertFalse(today.contains(".foregroundStyle(.blue)"))
        XCTAssertFalse(insights.contains(".foregroundStyle(.blue)"))
        XCTAssertFalse(settings.contains(".foregroundStyle(.blue)"))
    }

    func testQuotaRingAnimatesScopeChangesWithoutLayoutJump() throws {
        let ring = try source("QuotaLens/DesignSystem/QuotaRingView.swift")
        let today = try source("QuotaLens/Features/Dashboard/TodayView.swift")

        XCTAssertTrue(ring.contains("enum QuotaRingVisualSpec"))
        XCTAssertTrue(ring.contains("static let animationDuration = 0.38"))
        XCTAssertTrue(ring.contains("static let percentTextWidth: CGFloat = 96"))
        XCTAssertTrue(ring.contains("static let scopeChangeAnimation = Animation.easeInOut(duration: animationDuration)"))
        XCTAssertTrue(ring.contains("struct QuotaRingArc: Shape"))
        XCTAssertTrue(ring.contains("var animatableData: AnimatablePair<Double, Double>"))
        XCTAssertTrue(ring.contains("path.addArc("))
        XCTAssertTrue(ring.contains("startAngle: .degrees(-90 + 360 * clampedStart)"))
        XCTAssertTrue(ring.contains("endAngle: .degrees(-90 + 360 * clampedEnd)"))
        XCTAssertTrue(ring.contains("clockwise: false"))
        XCTAssertTrue(ring.contains("QuotaRingArc(startFraction: fraction.clamped(to: 0...1), endFraction: 1)"))
        XCTAssertTrue(ring.contains("QuotaRingArc(startFraction: 0, endFraction: fraction.clamped(to: 0...1))"))
        XCTAssertTrue(ring.contains("contentTransition(.numericText(value: Double(percent)))"))
        XCTAssertTrue(ring.contains(".frame(width: QuotaRingVisualSpec.percentTextWidth, alignment: .center)"))
        XCTAssertTrue(ring.contains(".monospacedDigit()"))
        XCTAssertTrue(ring.contains(".id(caption)"))
        XCTAssertTrue(ring.contains(".transition(.opacity)"))
        XCTAssertTrue(ring.contains(".animation(QuotaRingVisualSpec.scopeChangeAnimation, value: fraction)"))
        XCTAssertTrue(ring.contains(".animation(QuotaRingVisualSpec.scopeChangeAnimation, value: caption)"))
        XCTAssertTrue(today.contains(".animation(QuotaRingVisualSpec.scopeChangeAnimation, value: selectedScope)"))
        XCTAssertFalse(ring.contains(".trim(from: 0, to: fraction.clamped(to: 0...1))"))
    }

    func testInsightsTrendChartShowsRealContextInsteadOfDecorationOnly() throws {
        let source = try source("QuotaLens/Features/Insights/InsightsView.swift")

        XCTAssertTrue(source.contains("TrendGridLines()"))
        XCTAssertTrue(source.contains("TrendEndpointLabel("))
        XCTAssertTrue(source.contains("trendDateLabels"))
        XCTAssertTrue(source.contains("QLTheme.brandPrimary"))
        XCTAssertTrue(source.contains("真实额度窗口"))
        XCTAssertFalse(source.contains(".fill(.blue"))
        XCTAssertFalse(source.contains(".stroke(.blue"))
    }

    func testMainShellPassesDashboardStateIntoInsights() throws {
        let source = try source("QuotaLens/Features/Dashboard/MainShellView.swift")

        XCTAssertTrue(source.contains("InsightsView("))
        XCTAssertTrue(source.contains("accounts: dashboardStore.accounts"))
        XCTAssertTrue(source.contains("isLoading: dashboardStore.isLoading"))
        XCTAssertTrue(source.contains("errorMessage: dashboardStore.errorMessage"))
    }

    func testAccountSheetDoesNotExposeManualOAuthCallbackFields() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertFalse(source.contains("粘贴浏览器回调地址"))
        XCTAssertFalse(source.contains("提交回调"))
        XCTAssertFalse(source.contains("检查状态"))
        XCTAssertFalse(source.contains("oauthStatusControls"))
        XCTAssertTrue(source.contains("startNativeOAuth"))
    }

    func testAccountSheetImportsCodexAuthJSONThroughLocalFilePicker() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertTrue(source.contains("import UniformTypeIdentifiers"))
        XCTAssertTrue(source.contains("导入 Codex 认证文件"))
        XCTAssertTrue(source.contains(".fileImporter("))
        XCTAssertTrue(source.contains("allowedContentTypes: [.json]"))
        XCTAssertTrue(source.contains("startAccessingSecurityScopedResource()"))
        XCTAssertTrue(source.contains("CodexAuthFileImporter()"))
        XCTAssertTrue(source.contains("oauthTokenStore.save(bundle)"))
        XCTAssertTrue(source.contains("oauthStore.completeImportedToken(bundle)"))
        XCTAssertTrue(source.contains("onLoginCompleted?()"))
    }

    func testAccountSheetAPIInputsUseLiquidGlassFields() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertTrue(source.contains("LiquidGlassTextField("))
        XCTAssertTrue(source.contains("LiquidGlassSecureField("))
        XCTAssertTrue(source.contains("glassPanel(radius: 18, tint: .white.opacity(0.08), interactive: true)"))
        XCTAssertTrue(source.contains(".textFieldStyle(.plain)"))
        XCTAssertFalse(source.contains(".textFieldStyle(.roundedBorder)"))
    }

    func testFloatingAccountSheetUsesCompactNonScrollingLayout() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertTrue(source.contains("if isFloatingPanel {\n            accountSheetContent\n        } else {\n            ZStack {"))
        XCTAssertTrue(source.contains("ScrollView {\n                    accountSheetContent\n                }"))
        XCTAssertTrue(source.contains("private var accountSheetContent: some View"))
        XCTAssertTrue(source.contains("private var contentSpacing: CGFloat { isFloatingPanel ? 10 : 16 }"))
        XCTAssertTrue(source.contains("private var providerTileHeight: CGFloat { isFloatingPanel ? 70 : 82 }"))
        XCTAssertTrue(source.contains("private var providerIconSize: CGFloat { isFloatingPanel ? 36 : 42 }"))
        XCTAssertTrue(source.contains("private var configPanelPadding: CGFloat { isFloatingPanel ? 12 : 15 }"))
        XCTAssertFalse(source.contains("ScrollView {\n                GlassEffectContainer(spacing: 14)"))
    }

    func testFloatingAccountSheetHidesHeaderCloseButtonBecauseDockClosesPanel() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertTrue(source.contains("if !isFloatingPanel {\n                Button {\n                    close()"))
        XCTAssertFalse(source.contains(".accessibilityLabel(\"关闭\")"))
    }

    func testFloatingAPIAccountFormUsesCompactTwoColumnLayout() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertTrue(source.contains("if isFloatingPanel {\n            floatingAPIForm\n        } else {\n            fullAPIForm\n        }"))
        XCTAssertTrue(source.contains("private var floatingAPIForm: some View"))
        XCTAssertTrue(source.contains("private var fullAPIForm: some View"))
        XCTAssertTrue(source.contains("HStack(spacing: apiFormSpacing) {\n                LiquidGlassTextField(\"账号名称\", text: $apiName, minHeight: inputFieldHeight)"))
        XCTAssertTrue(source.contains("private var inputFieldHeight: CGFloat { isFloatingPanel ? 40 : 54 }"))
        XCTAssertTrue(source.contains("\"例如：gpt-5.3-codex、claude-sonnet-4.5\",\n                text: $models,\n                minHeight: inputFieldHeight"))
        XCTAssertFalse(source.contains("private var modelFieldHeight"))
        XCTAssertFalse(source.contains("axis: .vertical"))
        XCTAssertFalse(source.contains("lineLimit: 2...3"))
    }

    func testProviderTilesExposeFullRoundedHitShape() throws {
        let source = try source("QuotaLens/Features/Accounts/AccountSheetView.swift")

        XCTAssertTrue(source.contains(".contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))"))
    }

    func testSettingsDoesNotShowLocalAuthExplanationCard() throws {
        let source = try source("QuotaLens/Features/Settings/SettingsView.swift")

        XCTAssertFalse(source.contains("localAuthGroup"))
        XCTAssertFalse(source.contains("本地登录"))
        XCTAssertFalse(source.contains("认证方式"))
        XCTAssertFalse(source.contains("账号登录由 iOS 系统网页登录会话发起"))
        XCTAssertFalse(source.contains("数据来源"))
        XCTAssertFalse(source.contains("额度直接使用本地 token 请求各官方服务"))
    }

    func testServiceDetailToolbarUsesSystemButtonsWithoutNestedCustomGlassChrome() throws {
        let source = try source("QuotaLens/Features/ServiceDetail/ServiceDetailView.swift")
        guard let toolbarStart = source.range(of: "ToolbarItem(placement: .topBarTrailing)"),
              let sheetStart = source.range(of: ".sheet(isPresented:", range: toolbarStart.upperBound..<source.endIndex) else {
            return XCTFail("Toolbar block not found")
        }
        let toolbarSource = String(source[toolbarStart.lowerBound..<sheetStart.lowerBound])

        XCTAssertTrue(source.contains("@Environment(\\.dismiss) private var dismiss"))
        XCTAssertTrue(source.contains(".navigationBarBackButtonHidden(true)"))
        XCTAssertTrue(source.contains("ToolbarItem(placement: .topBarLeading)"))
        XCTAssertTrue(source.contains("Button { dismiss() }"))
        XCTAssertTrue(toolbarSource.contains("Button {"))
        XCTAssertTrue(toolbarSource.contains("showsActions = true"))
        XCTAssertTrue(toolbarSource.contains("Image(systemName: \"ellipsis\")"))
        XCTAssertTrue(source.contains("Image(systemName: \"chevron.left\")"))
        XCTAssertFalse(source.contains("UIKitToolbarGlassButton"))
        XCTAssertFalse(source.contains("ToolbarGlassControl"))
        XCTAssertFalse(source.contains("UIVisualEffectView"))
        XCTAssertFalse(source.contains("UIGlassEffect(style: .regular)"))
        XCTAssertFalse(source.contains("effectView.cornerConfiguration"))
        XCTAssertFalse(toolbarSource.contains(".buttonStyle(.glass)"))
    }

    func testAccountDetailUsesExplicitPathNavigationSoTabSwitchCanPopDetail() throws {
        let shell = try source("QuotaLens/Features/Dashboard/MainShellView.swift")
        let today = try source("QuotaLens/Features/Dashboard/TodayView.swift")

        XCTAssertTrue(shell.contains("NavigationStack(path: $navigationPath)"))
        XCTAssertTrue(shell.contains(".navigationDestination(for: AccountQuota.self)"))
        XCTAssertTrue(shell.contains("ServiceDetailView(account: account)"))
        XCTAssertTrue(shell.contains("onOpenAccount: { account in"))
        XCTAssertTrue(shell.contains("navigationPath.append(account)"))
        XCTAssertTrue(shell.contains("navigationPath = NavigationPath()"))
        XCTAssertTrue(today.contains("var onOpenAccount: (AccountQuota) -> Void = { _ in }"))
        XCTAssertTrue(today.contains("Button {\n                        onOpenAccount(account)"))
        XCTAssertTrue(today.contains(".contentShape(RoundedRectangle(cornerRadius: QLTheme.cardRadius, style: .continuous))"))
        XCTAssertFalse(today.contains("NavigationLink(value: account)"))
        XCTAssertFalse(today.contains("NavigationLink {\n                        ServiceDetailView(account: account)"))
    }

    func testAppLaunchesDirectlyIntoMainShellWithoutOnboarding() throws {
        let source = try source("QuotaLens/App/QuotaLensApp.swift")

        XCTAssertTrue(source.contains("MainShellView()"))
        XCTAssertFalse(source.contains("hasCompletedOnboarding"))
        XCTAssertFalse(source.contains("OnboardingView"))
    }

    func testGeneratedProjectDoesNotKeepOnboardingGroup() throws {
        let project = try source("QuotaLens.xcodeproj/project.pbxproj")

        XCTAssertFalse(project.contains("/* Onboarding */"))
        XCTAssertFalse(project.contains("path = Onboarding;"))
    }

    private func source(_ relativePath: String) throws -> String {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Source file unavailable at \(sourceURL.path)")
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
