import XCTest
@testable import QuotaLens

final class MainShellViewTests: XCTestCase {
    func testTabBarMapperMatchesAppTabOrder() {
        XCTAssertEqual(TabBarItemMapper.tag(for: .today), 0)
        XCTAssertEqual(TabBarItemMapper.tag(for: .insights), 1)
        XCTAssertEqual(TabBarItemMapper.tag(for: .settings), 2)

        XCTAssertEqual(TabBarItemMapper.tab(for: 0), .today)
        XCTAssertEqual(TabBarItemMapper.tab(for: 1), .insights)
        XCTAssertEqual(TabBarItemMapper.tab(for: 2), .settings)
        XCTAssertNil(TabBarItemMapper.tab(for: -1))
        XCTAssertNil(TabBarItemMapper.tab(for: 3))
    }

    func testMiddleTabsRestoreOriginalIcons() {
        XCTAssertEqual(AppTab.today.symbolName, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(AppTab.insights.symbolName, "chart.line.uptrend.xyaxis")
        XCTAssertEqual(AppTab.settings.symbolName, "gearshape")
    }

    func testMainShellUsesNativeTabBarForMiddleWithSeparateSideActions() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("UIKitGlassDock("))
        XCTAssertTrue(source.contains("let tabBar = view.tabBar"))
        XCTAssertTrue(source.contains("final class DockTabBar: UITabBar"))
        XCTAssertTrue(source.contains("let item = UITabBarItem("))
        XCTAssertTrue(source.contains("title: tab.title"))
        XCTAssertTrue(source.contains("image: UIImage(systemName: tab.symbolName)"))
        XCTAssertTrue(source.contains("selectedImage: UIImage(systemName: tab.symbolName)"))
        XCTAssertTrue(source.contains("tabBar.tintColor = UIColor(QLTheme.accent)"))
        XCTAssertTrue(source.contains("tabBar.unselectedItemTintColor = .black"))
        XCTAssertTrue(source.contains("tabBar.delegate = self"))
        XCTAssertTrue(source.contains("view.onTabSelected = { [coordinator = context.coordinator] index in"))
        XCTAssertTrue(source.contains("UIGlassContainerEffect()"))
        XCTAssertTrue(source.contains("containerEffect.spacing = SegmentedTabVisualSpec.idleGlassMergeSpacing"))
        XCTAssertTrue(source.contains("containerView.contentView.addSubview(tabBar)"))
        XCTAssertTrue(source.contains("containerView.contentView.addSubview(leftGlassView)"))
        XCTAssertTrue(source.contains("containerView.contentView.addSubview(rightGlassView)"))
        XCTAssertFalse(source.contains("middleGlassView"))
        XCTAssertTrue(source.contains("glassView.cornerConfiguration = .capsule()"))
        XCTAssertFalse(source.contains("GlassEffectContainer(spacing: SegmentedTabVisualSpec.glassMergeSpacing)"))
        XCTAssertFalse(source.contains(".glassEffect(QLTheme.glass(interactive: true), in: .capsule)"))
        XCTAssertFalse(source.contains(".glassEffect(QLTheme.glass(interactive: true), in: .circle)"))
        XCTAssertFalse(source.contains("SegmentedTabControl(selectedTab: $selectedTab)"))
        XCTAssertFalse(source.contains("UIKitGlassActionButton"))
        XCTAssertTrue(source.contains("UIGlassEffect(style: .regular)"))
        XCTAssertTrue(source.contains("effect.isInteractive = true"))
        XCTAssertFalse(source.contains(".buttonStyle(.glass)"))
        XCTAssertFalse(source.contains("UISegmentedControl"))
        XCTAssertFalse(source.contains("SegmentedTabContentView"))
        XCTAssertFalse(source.contains("DockSegmentedControl"))
        XCTAssertFalse(source.contains("UIKitTabBarControl"))
        XCTAssertFalse(source.contains("TabView(selection: $selectedTab)"))
        XCTAssertFalse(source.contains("DragGesture(minimumDistance: 0"))
    }

    func testMainShellDoesNotRenderSampleQuotaData() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertFalse(source.contains("SampleQuotaData.accounts"))
        XCTAssertTrue(source.contains("QuotaDashboardStore"))
        XCTAssertTrue(source.contains(".task {"))
        XCTAssertTrue(source.contains("await dashboardStore.refresh()"))
    }

    func testTabSwitchClearsDetailNavigationPath() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("@State private var navigationPath = NavigationPath()"))
        XCTAssertTrue(source.contains("NavigationStack(path: $navigationPath)"))
        XCTAssertTrue(source.contains(".onChange(of: selectedTab)"))
        XCTAssertTrue(source.contains("navigationPath = NavigationPath()"))
    }

    func testMiddleNativeTabBarUsesWiderLowerPillGeometry() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("static let controlHeight: CGFloat = 58"))
        XCTAssertTrue(source.contains("static let segmentedControlMinimumWidth: CGFloat = 222"))
        XCTAssertTrue(source.contains("static let tabBarHorizontalOutset: CGFloat = 18"))
        XCTAssertTrue(source.contains("static let tabBarVerticalOutset: CGFloat = 12"))
        XCTAssertTrue(source.contains("static let tabBarBottomOffset: CGFloat = 22"))
        XCTAssertEqual(SegmentedTabVisualSpec.tabBarBottomOffset, SegmentedTabVisualSpec.tabBarVerticalOutset + 10)
        XCTAssertTrue(source.contains("static var tabBarVisualHeight: CGFloat"))
        XCTAssertTrue(source.contains("static var tabBarItemWidth: CGFloat"))
        XCTAssertTrue(source.contains("static let dockSpacing: CGFloat = 6"))
        XCTAssertTrue(source.contains("static let glassMergeSpacing: CGFloat = 18"))
        XCTAssertTrue(source.contains("static let idleGlassMergeSpacing: CGFloat = 4"))
        XCTAssertTrue(source.contains("static let maximumDockWidth: CGFloat = 350"))
        XCTAssertTrue(source.contains(".frame(height: SegmentedTabVisualSpec.controlHeight)"))
        XCTAssertTrue(source.contains(".frame(minWidth: SegmentedTabVisualSpec.minimumDockWidth, maxWidth: SegmentedTabVisualSpec.maximumDockWidth)"))
        XCTAssertTrue(source.contains(".frame(maxWidth: SegmentedTabVisualSpec.maximumDockWidth, alignment: .center)"))
        XCTAssertTrue(source.contains("final class DockTabBar: UITabBar"))
        XCTAssertTrue(source.contains("tabBar.backgroundColor = .clear"))
        XCTAssertTrue(source.contains("itemWidth = SegmentedTabVisualSpec.tabBarItemWidth"))
        XCTAssertTrue(source.contains("itemSpacing = 0"))
        XCTAssertFalse(source.contains("tabBar.transform = CGAffineTransform(scaleX:"))
        XCTAssertTrue(source.contains("appearance.stackedItemPositioning = .fill"))
        XCTAssertTrue(source.contains("appearance.stackedItemWidth = SegmentedTabVisualSpec.tabBarItemWidth"))
        XCTAssertTrue(source.contains("appearance.stackedItemSpacing = 0"))
        XCTAssertTrue(source.contains("tabBar.leadingAnchor.constraint(equalTo: leftGlassView.trailingAnchor, constant: SegmentedTabVisualSpec.dockSpacing - SegmentedTabVisualSpec.tabBarHorizontalOutset)"))
        XCTAssertTrue(source.contains("tabBar.trailingAnchor.constraint(equalTo: rightGlassView.leadingAnchor, constant: -SegmentedTabVisualSpec.dockSpacing + SegmentedTabVisualSpec.tabBarHorizontalOutset)"))
        XCTAssertTrue(source.contains("tabBar.bottomAnchor.constraint(equalTo: leftGlassView.bottomAnchor, constant: SegmentedTabVisualSpec.tabBarBottomOffset)"))
        XCTAssertTrue(source.contains("tabBar.heightAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.tabBarVisualHeight)"))
        XCTAssertFalse(source.contains("selectedSegmentTintColor ="))
        let expectedMinimumDockWidth: CGFloat = 222 + 58 * 2 + 6 * 2
        XCTAssertLessThanOrEqual(expectedMinimumDockWidth, 350)

        let segmentAspectRatio = (SegmentedTabVisualSpec.segmentedControlMinimumWidth / CGFloat(AppTab.allCases.count))
            / SegmentedTabVisualSpec.controlHeight
        XCTAssertGreaterThan(segmentAspectRatio, 1.2)
        XCTAssertFalse(source.contains("subview.frame.size.height = bounds.height"))
        XCTAssertFalse(source.contains("subview.layer.cornerRadius = bounds.height / 2"))
        XCTAssertFalse(source.contains("tabBarHostHeight"))
        XCTAssertFalse(source.contains("tabBarRenderedHeight"))
    }

    @MainActor
    func testDockTabBarCreatesNativeItemsForEveryAppTab() throws {
        let tabBar = DockTabBar(frame: CGRect(x: 0, y: 0, width: 222, height: 58))

        let items = try XCTUnwrap(tabBar.items)
        XCTAssertEqual(items.count, AppTab.allCases.count)
        for (index, tab) in AppTab.allCases.enumerated() {
            XCTAssertEqual(items[index].title, tab.title)
            XCTAssertEqual(items[index].tag, index)
            XCTAssertNotNil(items[index].image)
            XCTAssertNotNil(items[index].selectedImage)
            XCTAssertEqual(tabBar.index(for: items[index]), index)
        }
        XCTAssertEqual(tabBar.selectedItem?.tag, TabBarItemMapper.tag(for: .today))
        XCTAssertEqual(tabBar.tintColor, UIColor(QLTheme.accent))
        XCTAssertEqual(tabBar.unselectedItemTintColor, .black)
        XCTAssertEqual(
            tabBar.sizeThatFits(CGSize(width: 222, height: 58)).height,
            SegmentedTabVisualSpec.controlHeight + SegmentedTabVisualSpec.tabBarVerticalOutset * 2
        )

        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)
        XCTAssertTrue(source.contains("let item = UITabBarItem("))
        XCTAssertTrue(source.contains("title: tab.title"))
        XCTAssertTrue(source.contains("image: UIImage(systemName: tab.symbolName)"))
        XCTAssertTrue(source.contains("selectedImage: UIImage(systemName: tab.symbolName)"))
        XCTAssertTrue(source.contains("item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)"))
        XCTAssertTrue(source.contains("setItems(tabItems, animated: false)"))
        XCTAssertTrue(source.contains("selectedItem = tabItems.first"))

        guard
            let controlStart = source.range(of: "final class DockTabBar: UITabBar")
        else {
            return XCTFail("DockTabBar source block is unavailable")
        }
        let dockControlSource = source[controlStart.lowerBound..<source.endIndex]
        XCTAssertFalse(dockControlSource.contains("clipsToBounds = true"))
    }

    func testDockGlassMergesWithSideActionsOnlyWhileMiddleSegmentIsPressed() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertLessThan(SegmentedTabVisualSpec.idleGlassMergeSpacing, SegmentedTabVisualSpec.dockSpacing)
        XCTAssertGreaterThan(SegmentedTabVisualSpec.glassMergeSpacing, SegmentedTabVisualSpec.dockSpacing)
        XCTAssertTrue(source.contains("containerEffect.spacing = SegmentedTabVisualSpec.idleGlassMergeSpacing"))
        XCTAssertTrue(source.contains("setGlassMergeActive(false, animated: false)"))
        XCTAssertTrue(source.contains("tabBar.onPressStateChanged = { [weak view] isPressed in"))
        XCTAssertTrue(source.contains("setGlassMergeActive(isPressed, animated: true)"))
        XCTAssertTrue(source.contains("override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)"))
        XCTAssertTrue(source.contains("override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)"))
        XCTAssertTrue(source.contains("setPressState(true)"))
        XCTAssertTrue(source.contains("setPressState(false)"))
    }

    func testDockTabBarTintingStaysNativeForSystemLiquidGlassLens() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("final class DockTabBar: UITabBar"))
        XCTAssertTrue(source.contains("tabBar.tintColor = UIColor(QLTheme.accent)"))
        XCTAssertTrue(source.contains("tabBar.unselectedItemTintColor = .black"))
        XCTAssertTrue(source.contains("let item = UITabBarItem("))
        XCTAssertTrue(source.contains("title: tab.title"))
        XCTAssertTrue(source.contains("image: UIImage(systemName: tab.symbolName)"))
        XCTAssertTrue(source.contains("selectedImage: UIImage(systemName: tab.symbolName)"))
        XCTAssertTrue(source.contains("button.tintColor = .black"))
        XCTAssertFalse(source.contains("SegmentedTabContentView"))
        XCTAssertFalse(source.contains("DockSegmentedControl"))
        XCTAssertFalse(source.contains("SegmentedTabActionFactory"))
        XCTAssertFalse(source.contains("SegmentedTabImageFactory"))
        XCTAssertFalse(source.contains("SegmentedTabImageStyle"))
        XCTAssertFalse(source.contains("withRenderingMode(.alwaysOriginal)"))
        XCTAssertFalse(source.contains("UIGraphicsImageRenderer"))
        XCTAssertFalse(source.contains("withTintColor(drawColor"))
        XCTAssertFalse(source.contains("button.tintColor = .label"))
        XCTAssertFalse(source.contains("case pressedSelected"))
        XCTAssertFalse(source.contains("case pressedUnselected"))
        XCTAssertFalse(source.contains("drawChromaticContent("))
        XCTAssertFalse(source.contains("dispersionColor"))
    }

    func testSideActionsShrinkWithTheSegmentedControlForVisualAlignment() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("static let actionButtonSize: CGFloat = 58"))
        XCTAssertTrue(source.contains("static let actionSymbolPointSize: CGFloat = 20"))
        XCTAssertTrue(source.contains("leftGlassView.widthAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize)"))
        XCTAssertTrue(source.contains("rightGlassView.widthAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize)"))
        XCTAssertTrue(source.contains("leftGlassView.heightAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize)"))
        XCTAssertTrue(source.contains("rightGlassView.heightAnchor.constraint(equalToConstant: SegmentedTabVisualSpec.actionButtonSize)"))
        XCTAssertTrue(source.contains("static let tabBarHorizontalOutset: CGFloat = 18"))
        XCTAssertTrue(source.contains("static let tabBarVerticalOutset: CGFloat = 12"))
        XCTAssertTrue(source.contains("static let tabBarBottomOffset: CGFloat = 22"))
        XCTAssertEqual(SegmentedTabVisualSpec.tabBarBottomOffset, SegmentedTabVisualSpec.tabBarVerticalOutset + 10)
        XCTAssertTrue(source.contains("static var tabBarVisualHeight: CGFloat"))
        XCTAssertTrue(source.contains("static var tabBarItemWidth: CGFloat"))
        XCTAssertTrue(source.contains("pointSize: SegmentedTabVisualSpec.actionSymbolPointSize"))
        XCTAssertFalse(source.contains("static let actionSymbolPointSize: CGFloat = 22"))
        XCTAssertFalse(source.contains("pointSize: 25"))
        XCTAssertFalse(source.contains("static let actionButtonSize: CGFloat = 56"))
        XCTAssertFalse(source.contains("static let actionButtonSize: CGFloat = 64"))
        XCTAssertFalse(source.contains("static let actionButtonSize: CGFloat = 76"))
        XCTAssertFalse(source.contains("static let actionButtonSize: CGFloat = 84"))
    }

    func testScrollableContentBottomPaddingClearsFloatingDock() {
        XCTAssertGreaterThanOrEqual(
            QLTheme.scrollBottomPadding,
            SegmentedTabVisualSpec.actionButtonSize + 56
        )
    }

    func testAccountPanelFloatsAboveDockInsteadOfCoveringItWithSheet() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("AccountPanelOverlay"))
        XCTAssertTrue(source.contains("AccountSheetView(isFloatingPanel: true, onClose: onClose, onLoginCompleted: onLoginCompleted)"))
        XCTAssertTrue(source.contains("static let dockAttachmentGap: CGFloat = 8"))
        XCTAssertTrue(source.contains(".padding(.bottom, AccountPanelVisualSpec.dockAttachmentGap)"))
        XCTAssertFalse(source.contains("static let bottomClearance: CGFloat = SegmentedTabVisualSpec.actionButtonSize + 30"))
        XCTAssertFalse(source.contains(".offset(y: -AccountPanelVisualSpec.bottomClearance)"))
        XCTAssertFalse(source.contains(".sheet(isPresented: $showsAccountSheet)"))
        XCTAssertFalse(source.contains("presentationDetents([.height(AccountSheetView.preferredPresentationHeight)])"))
    }

    func testAccountPanelUsesContentSizedTopAlignedContainer() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity, alignment: .top)"))
        XCTAssertFalse(source.contains("maxHeight: AccountPanelVisualSpec.maximumFloatingHeight"))
        XCTAssertFalse(source.contains("static let maximumFloatingHeight: CGFloat = 560"))
        XCTAssertFalse(source.contains(".frame(height: AccountPanelVisualSpec.floatingHeight)"))
        XCTAssertFalse(source.contains("static let floatingHeight: CGFloat = 560"))
    }

    func testAccountPanelBlocksTouchesFromPassingThroughToDashboardTabs() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("Color.clear\n                    .contentShape(Rectangle())\n                    .onTapGesture { }"))
        XCTAssertTrue(source.contains(".accessibilityHidden(true)"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)"))
        XCTAssertTrue(source.contains(".contentShape(RoundedRectangle(cornerRadius: AccountPanelVisualSpec.cornerRadius, style: .continuous))"))
    }

    func testAddButtonRotatesPlusIntoCloseIconWhenPanelIsPresented() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("isAddButtonRotated: isAccountPanelPresented"))
        XCTAssertTrue(source.contains("isRotated ? .pi / 4 : 0"))
        XCTAssertTrue(source.contains("UIView.animate("))
        XCTAssertTrue(source.contains("usingSpringWithDamping: 0.82"))
        XCTAssertFalse(source.contains("symbol: \"xmark\""))
    }

    func testCompletedLoginClosesAccountPanelReturnsHomeAndRefreshesDashboard() throws {
        let source = try String(contentsOf: mainShellSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("completeAccountLoginFlow()"))
        XCTAssertTrue(source.contains("selectedTab = .today"))
        XCTAssertTrue(source.contains("showsAccountPanel = false"))
        XCTAssertTrue(source.contains("await dashboardStore.refresh()"))
        XCTAssertTrue(source.contains("onLoginCompleted: onLoginCompleted"))
    }

    private func mainShellSourceURL() throws -> URL {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent("QuotaLens/Features/Dashboard/MainShellView.swift")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("MainShellView.swift source file is unavailable at \(sourceURL.path)")
        }

        return sourceURL
    }
}
