import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case today
    case insights
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "今日"
        case .insights: "洞察"
        case .settings: "设置"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "gauge.with.dots.needle.67percent"
        case .insights: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }
}

enum SegmentedTabVisualSpec {
    static let actionButtonSize: CGFloat = 58
    static let actionSymbolPointSize: CGFloat = 20
    static let controlHeight: CGFloat = 58
    static let segmentedControlMinimumWidth: CGFloat = 222
    static let tabBarHorizontalOutset: CGFloat = 18
    static let tabBarVerticalOutset: CGFloat = 12
    static let tabBarBottomOffset: CGFloat = 22
    static let dockSpacing: CGFloat = 6
    static let idleGlassMergeSpacing: CGFloat = 4
    static let glassMergeSpacing: CGFloat = 18
    static let maximumDockWidth: CGFloat = 350

    static var minimumDockWidth: CGFloat {
        segmentedControlMinimumWidth + actionButtonSize * 2 + dockSpacing * 2
    }

    static var tabBarVisualHeight: CGFloat {
        controlHeight + tabBarVerticalOutset * 2
    }

    static var tabBarItemWidth: CGFloat {
        (segmentedControlMinimumWidth + tabBarHorizontalOutset * 2) / CGFloat(AppTab.allCases.count)
    }
}

enum AccountPanelVisualSpec {
    static let cornerRadius: CGFloat = 34
    static let horizontalPadding: CGFloat = 14
    static let dockAttachmentGap: CGFloat = 8
}

enum TabBarItemMapper {
    static func tag(for tab: AppTab) -> Int {
        AppTab.allCases.firstIndex(of: tab) ?? 0
    }

    static func tab(for index: Int) -> AppTab? {
        guard AppTab.allCases.indices.contains(index) else {
            return nil
        }

        return AppTab.allCases[index]
    }
}

struct MainShellView: View {
    @State private var selectedTab: AppTab = .today
    @State private var navigationPath = NavigationPath()
    @State private var showsAccountPanel = false
    @State private var dashboardStore = QuotaDashboardStore()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            tabContent(for: selectedTab)
                .navigationDestination(for: AccountQuota.self) { account in
                    ServiceDetailView(account: account)
                }
        }
        .background(QLTheme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            accountPanelOverlay
        }
        .task {
            await dashboardStore.refresh()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HybridGlassDock(
                selectedTab: $selectedTab,
                isAccountPanelPresented: showsAccountPanel,
                onAdd: { setAccountPanelPresented(!showsAccountPanel) },
                onRefresh: {
                    Task {
                        await dashboardStore.refresh()
                    }
                }
            )
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .onChange(of: selectedTab) { _, _ in
            navigationPath = NavigationPath()
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showsAccountPanel)
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView(
                accounts: dashboardStore.accounts,
                refreshDate: dashboardStore.refreshDate,
                isLoading: dashboardStore.isLoading,
                errorMessage: dashboardStore.errorMessage,
                onOpenAccount: { account in
                    navigationPath.append(account)
                }
            )
        case .insights:
            InsightsView(
                accounts: dashboardStore.accounts,
                isLoading: dashboardStore.isLoading,
                errorMessage: dashboardStore.errorMessage
            )
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private var accountPanelOverlay: some View {
        if showsAccountPanel {
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    .accessibilityHidden(true)

                AccountPanelOverlay {
                    setAccountPanelPresented(false)
                } onLoginCompleted: {
                    completeAccountLoginFlow()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
    }

    private func setAccountPanelPresented(_ isPresented: Bool) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            showsAccountPanel = isPresented
        }
    }

    private func completeAccountLoginFlow() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selectedTab = .today
            showsAccountPanel = false
        }
        Task {
            await dashboardStore.refresh()
        }
    }
}

private struct HybridGlassDock: View {
    @Binding var selectedTab: AppTab
    var isAccountPanelPresented: Bool
    var onAdd: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        UIKitGlassDock(
            selectedTab: $selectedTab,
            isAddButtonRotated: isAccountPanelPresented,
            addAccessibilityLabel: isAccountPanelPresented ? "关闭添加面板" : "添加账号",
            onAdd: onAdd,
            onRefresh: onRefresh
        )
        .frame(height: SegmentedTabVisualSpec.controlHeight)
        .frame(minWidth: SegmentedTabVisualSpec.minimumDockWidth, maxWidth: SegmentedTabVisualSpec.maximumDockWidth)
        .frame(maxWidth: SegmentedTabVisualSpec.maximumDockWidth, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct AccountPanelOverlay: View {
    var onClose: () -> Void
    var onLoginCompleted: () -> Void

    var body: some View {
        AccountSheetView(isFloatingPanel: true, onClose: onClose, onLoginCompleted: onLoginCompleted)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(RoundedRectangle(cornerRadius: AccountPanelVisualSpec.cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: AccountPanelVisualSpec.cornerRadius, style: .continuous))
            .liquidGlassCard(radius: AccountPanelVisualSpec.cornerRadius, tint: .white.opacity(0.05))
            .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 18)
            .padding(.horizontal, AccountPanelVisualSpec.horizontalPadding)
            .padding(.bottom, AccountPanelVisualSpec.dockAttachmentGap)
    }
}

private struct UIKitGlassDock: UIViewRepresentable {
    @Binding var selectedTab: AppTab
    var isAddButtonRotated: Bool
    var addAccessibilityLabel: String
    var onAdd: () -> Void
    var onRefresh: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab, onAdd: onAdd, onRefresh: onRefresh)
    }

    func makeUIView(context: Context) -> GlassDockView {
        let view = GlassDockView()
        view.addButton.addTarget(context.coordinator, action: #selector(Coordinator.addTapped), for: .touchUpInside)
        view.refreshButton.addTarget(context.coordinator, action: #selector(Coordinator.refreshTapped), for: .touchUpInside)
        let tabBar = view.tabBar
        tabBar.onPressStateChanged = { [weak view] isPressed in
            view?.setGlassMergeActive(isPressed, animated: true)
        }
        view.onTabSelected = { [coordinator = context.coordinator] index in
            coordinator.selectTabIndex(index)
        }
        view.configure(
            selectedTab: selectedTab,
            isRotated: isAddButtonRotated,
            addAccessibilityLabel: addAccessibilityLabel,
            animated: false
        )

        return view
    }

    func updateUIView(_ view: GlassDockView, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        context.coordinator.onAdd = onAdd
        context.coordinator.onRefresh = onRefresh
        view.configure(
            selectedTab: selectedTab,
            isRotated: isAddButtonRotated,
            addAccessibilityLabel: addAccessibilityLabel,
            animated: true
        )
    }

    @MainActor
    final class Coordinator: NSObject {
        var selectedTab: Binding<AppTab>
        var onAdd: () -> Void
        var onRefresh: () -> Void

        init(selectedTab: Binding<AppTab>, onAdd: @escaping () -> Void, onRefresh: @escaping () -> Void) {
            self.selectedTab = selectedTab
            self.onAdd = onAdd
            self.onRefresh = onRefresh
        }

        @objc
        func addTapped() {
            onAdd()
        }

        @objc
        func refreshTapped() {
            onRefresh()
        }

        func selectTabIndex(_ index: Int) {
            guard let tab = TabBarItemMapper.tab(for: index) else {
                return
            }
            selectedTab.wrappedValue = tab
        }
    }
}

final class GlassDockView: UIView, UITabBarDelegate {
    private let containerView = UIVisualEffectView()
    private let leftGlassView = UIVisualEffectView()
    private let rightGlassView = UIVisualEffectView()
    let addButton = UIButton(type: .system)
    let refreshButton = UIButton(type: .system)
    let tabBar: DockTabBar = {
        let tabBar = DockTabBar(frame: .zero)
        tabBar.backgroundColor = .clear
        tabBar.tintColor = UIColor(QLTheme.accent)
        tabBar.unselectedItemTintColor = .black
        return tabBar
    }()
    var onTabSelected: ((Int) -> Void)?
    private var currentRotationAngle: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        [leftGlassView, rightGlassView].forEach(configureGlassShape(_:))
    }

    func configure(
        selectedTab: AppTab,
        isRotated: Bool,
        addAccessibilityLabel: String,
        animated: Bool
    ) {
        tabBar.selectTab(selectedTab)

        configureActionButton(addButton, symbolName: "plus", accessibilityLabel: addAccessibilityLabel)
        configureActionButton(refreshButton, symbolName: "arrow.clockwise", accessibilityLabel: "刷新")

        let rotationAngle: CGFloat = isRotated ? .pi / 4 : 0
        guard currentRotationAngle != rotationAngle else { return }
        currentRotationAngle = rotationAngle

        let changes = {
            self.addButton.transform = CGAffineTransform(rotationAngle: rotationAngle)
        }
        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.55,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: changes
            )
        } else {
            changes()
        }
    }

    private func setup() {
        backgroundColor = .clear

        if #available(iOS 26.0, *) {
            let containerEffect = UIGlassContainerEffect()
            containerEffect.spacing = SegmentedTabVisualSpec.idleGlassMergeSpacing
            containerView.effect = containerEffect
            leftGlassView.effect = makeGlassEffect(tintColor: UIColor.systemBackground.withAlphaComponent(0.22))
            rightGlassView.effect = makeGlassEffect(tintColor: UIColor.systemBackground.withAlphaComponent(0.22))
            [leftGlassView, rightGlassView].forEach(configureGlassShape(_:))
        } else {
            leftGlassView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            rightGlassView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }

        [containerView, leftGlassView, rightGlassView, addButton, refreshButton, tabBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        tabBar.delegate = self

        addSubview(containerView)
        containerView.contentView.addSubview(tabBar)
        containerView.contentView.addSubview(leftGlassView)
        containerView.contentView.addSubview(rightGlassView)
        leftGlassView.contentView.addSubview(addButton)
        rightGlassView.contentView.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            leftGlassView.leadingAnchor.constraint(equalTo: containerView.contentView.leadingAnchor),
            leftGlassView.centerYAnchor.constraint(equalTo: containerView.contentView.centerYAnchor),
            leftGlassView.widthAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize),
            leftGlassView.heightAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize),

            rightGlassView.trailingAnchor.constraint(equalTo: containerView.contentView.trailingAnchor),
            rightGlassView.centerYAnchor.constraint(equalTo: containerView.contentView.centerYAnchor),
            rightGlassView.widthAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize),
            rightGlassView.heightAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize),

            addButton.leadingAnchor.constraint(equalTo: leftGlassView.contentView.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: leftGlassView.contentView.trailingAnchor),
            addButton.topAnchor.constraint(equalTo: leftGlassView.contentView.topAnchor),
            addButton.bottomAnchor.constraint(equalTo: leftGlassView.contentView.bottomAnchor),

            tabBar.leadingAnchor.constraint(equalTo: leftGlassView.trailingAnchor, constant: SegmentedTabVisualSpec.dockSpacing - SegmentedTabVisualSpec.tabBarHorizontalOutset),
            tabBar.trailingAnchor.constraint(equalTo: rightGlassView.leadingAnchor, constant: -SegmentedTabVisualSpec.dockSpacing + SegmentedTabVisualSpec.tabBarHorizontalOutset),
            tabBar.bottomAnchor.constraint(equalTo: leftGlassView.bottomAnchor, constant: SegmentedTabVisualSpec.tabBarBottomOffset),
            tabBar.heightAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.tabBarVisualHeight),

            refreshButton.leadingAnchor.constraint(equalTo: rightGlassView.contentView.leadingAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: rightGlassView.contentView.trailingAnchor),
            refreshButton.topAnchor.constraint(equalTo: rightGlassView.contentView.topAnchor),
            refreshButton.bottomAnchor.constraint(equalTo: rightGlassView.contentView.bottomAnchor)
        ])

        setGlassMergeActive(false, animated: false)
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let dockTabBar = tabBar as? DockTabBar, let index = dockTabBar.index(for: item) else {
            return
        }

        onTabSelected?(index)
    }

    private func makeGlassEffect(tintColor: UIColor) -> UIVisualEffect {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            effect.tintColor = tintColor
            return effect
        }
        return UIBlurEffect(style: .systemUltraThinMaterial)
    }

    private func configureGlassShape(_ glassView: UIVisualEffectView) {
        if #available(iOS 26.0, *) {
            glassView.cornerConfiguration = .capsule()
        } else {
            glassView.layer.cornerRadius = min(glassView.bounds.width, glassView.bounds.height) / 2
            glassView.layer.cornerCurve = .continuous
            glassView.clipsToBounds = true
        }
    }

    private func configureActionButton(
        _ button: UIButton,
        symbolName: String,
        accessibilityLabel: String
    ) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: SegmentedTabVisualSpec.actionSymbolPointSize,
            weight: .semibold
        )
        configuration.contentInsets = .zero
        button.configuration = configuration
        button.tintColor = .black
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits = [.button]
    }

    func setGlassMergeActive(_ isActive: Bool, animated: Bool) {
        guard #available(iOS 26.0, *) else {
            return
        }

        let spacing = isActive
            ? SegmentedTabVisualSpec.glassMergeSpacing
            : SegmentedTabVisualSpec.idleGlassMergeSpacing
        let updates = {
            if let containerEffect = self.containerView.effect as? UIGlassContainerEffect {
                containerEffect.spacing = spacing
            } else {
                let containerEffect = UIGlassContainerEffect()
                containerEffect.spacing = spacing
                self.containerView.effect = containerEffect
            }
        }

        if animated {
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: updates
            )
        } else {
            updates()
        }
    }
}


final class DockTabBar: UITabBar, UIGestureRecognizerDelegate {
    var onPressStateChanged: ((Bool) -> Void)?
    private var isPressing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = SegmentedTabVisualSpec.tabBarVisualHeight
        return size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.cornerCurve = .continuous
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        setPressState(true)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        setPressState(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        setPressState(false)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var fittedSize = super.sizeThatFits(size)
        fittedSize.height = SegmentedTabVisualSpec.tabBarVisualHeight
        return fittedSize
    }

    func selectTab(_ tab: AppTab) {
        let selectedIndex = TabBarItemMapper.tag(for: tab)
        guard selectedItem?.tag != selectedIndex else {
            return
        }

        selectedItem = items?.first { $0.tag == selectedIndex }
    }

    func index(for item: UITabBarItem) -> Int? {
        guard AppTab.allCases.indices.contains(item.tag) else {
            return nil
        }
        return item.tag
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func setup() {
        backgroundColor = .clear
        isTranslucent = true
        itemPositioning = .fill
        itemWidth = SegmentedTabVisualSpec.tabBarItemWidth
        itemSpacing = 0
        tintColor = UIColor(QLTheme.accent)
        unselectedItemTintColor = .black
        configureAppearance()

        let tabItems = AppTab.allCases.enumerated().map { index, tab in
            let item = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.symbolName),
                selectedImage: UIImage(systemName: tab.symbolName)
            )
            item.tag = index
            item.imageInsets = UIEdgeInsets(top: -2, left: 0, bottom: 2, right: 0)
            item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
            return item
        }
        setItems(tabItems, animated: false)
        selectedItem = tabItems.first

        let pressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        pressRecognizer.minimumPressDuration = 0
        pressRecognizer.cancelsTouchesInView = false
        pressRecognizer.delegate = self
        addGestureRecognizer(pressRecognizer)
    }

    private func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.stackedItemPositioning = .fill
        appearance.stackedItemWidth = SegmentedTabVisualSpec.tabBarItemWidth
        appearance.stackedItemSpacing = 0
        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance]
            .forEach(configureItemAppearance(_:))
        standardAppearance = appearance
        if #available(iOS 15.0, *) {
            scrollEdgeAppearance = appearance
        }
    }

    private func configureItemAppearance(_ itemAppearance: UITabBarItemAppearance) {
        itemAppearance.normal.iconColor = .black
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        itemAppearance.selected.iconColor = UIColor(QLTheme.accent)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(QLTheme.accent),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
    }

    @objc
    private func handlePress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            setPressState(true)
        default:
            setPressState(false)
        }
    }

    private func setPressState(_ isPressing: Bool) {
        guard self.isPressing != isPressing else {
            return
        }

        self.isPressing = isPressing
        onPressStateChanged?(isPressing)
    }
}
