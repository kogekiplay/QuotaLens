# QuotaLens iOS 应用设计文档

## 目标

QuotaLens 是一个本地优先的 AI 订阅额度追踪工具，用于集中查看 Codex、Claude、API 中转站、Cursor 等服务的剩余额度、重置时间、消耗速度和提醒规则。第一版目标是把 OpenDesign 原型还原成原生 iOS App，并实现 App 独立发起的 OAuth、额度刷新、Keychain 凭据存储和 iCloud 私有同步边界。

## 原型来源

以 `/Users/kogeki/Library/CloudStorage/OneDrive-个人/dev/open-design/QuotaLens/screens/*.html` 和 `critique.json` 为最终设计来源。`today-light.png` 与若干红框截图属于中间检查稿，只用于视觉气质参考，不作为最终信息架构依据。

最终原型包含：

- 今日：总额度、3 个紧凑指标、5 小时/本周/全部切换、环形额度、账号额度列表。
- 服务详情：账号头部、套餐与重置状态、额度条、提醒开关、快捷操作 Sheet。
- 洞察：7 天/30 天/账单周期切换、趋势图、预测与建议卡片。
- 设置：账户、隐私、数据同步、提醒、外观、导出、关于。
- 提醒：低打扰规则、安静时段、限额/重置/异常/续费开关。
- 全局添加账号 Sheet：官方账号 OAuth、API 中转站本地表单。

## Liquid Glass 还原规则

网页原型的 `.liquid` 使用 `backdrop-filter`、透明背景、描边和阴影模拟玻璃。iOS 版不复刻这套 CSS，而使用 iOS 26 SwiftUI Liquid Glass：

- 底部 Tab、浮动添加按钮、浮动刷新按钮、搜索框、添加账号 Sheet、快捷操作 Sheet 使用 `GlassEffectContainer` 与 `.glassEffect(...)`。
- 可点击玻璃元素使用 `.interactive()` 或 `.buttonStyle(.glass/.glassProminent)`。
- 多个玻璃元素同屏出现时用 `GlassEffectContainer` 管理形变与渲染；底栏使用 `glassEffectID` 与 `glassEffectUnion` 让选中态、主胶囊和左右浮动动作按官方 Liquid Glass 方式协同。
- 可见的指标卡、趋势卡、账号卡、设置组、provider 选择格和状态 chip 统一使用 `liquidGlassCard` 或 `glassPanel`，不再使用网页式 `backdrop-filter`、`.thinMaterial`、手写透明背景和描边来假装玻璃。
- 大面积中文数字信息保留系统色前景与足够留白，不叠加额外自绘阴影，优先让系统 Liquid Glass 自身处理透光与交互反馈。
- 项目最低目标为 iOS 26.0，因此第一版直接使用真 Liquid Glass API。

## 信息架构

主导航保留 3 个 Tab：

- 今日：工作台首页，面向“现在能不能继续跑任务”的判断。
- 洞察：消耗速度、风险预测和性价比建议。
- 设置：账号、隐私、同步、提醒与导出。

“添加账号或订阅”是全局浮动操作，不作为 Tab；“刷新额度”是今日页右侧浮动操作，不放在顶部导航。详情页通过卡片进入，使用 `NavigationStack` 返回。

## 数据模型

核心模型分三层：

- `AccountQuota`：账号档案，包含 provider、邮箱/标签、套餐、额度窗口、余额、模型数量和刷新状态。
- `QuotaWindow`：单条额度窗口，包含标题、剩余比例、重置时间、颜色语义和是否为 Pro 20x/Spark 附加额度。
- `DashboardSummary`：由账号列表聚合得到的整体剩余额度、总可用时长、即将重置数量、每日消耗估算。

UI 只读取模型，不直接解析 OAuth token 或网络响应。真实数据由服务层把本地 OAuth token 获取到的官方响应归一化成这些模型。

## OAuth 与凭据设计

- 官方账号采用 PKCE + state 防 CSRF。
- iOS 原生登录使用 `ASWebAuthenticationSession` 打开授权页并接收回调。
- App 直接请求各 provider 的授权地址和 token endpoint，不通过外部代理或 relay。
- Codex 额度使用本机 Keychain 中保存的 access token 直接请求官方 usage endpoint。
- 凭据落 Keychain；非敏感快照、提醒规则和 UI 偏好落本地持久层，后续通过 iCloud 私有数据库同步。
- API 中转站只保存用户填写的 base URL、密钥、模型列表和余额描述，默认不上传。

## 错误与状态

OAuth 状态：

- idle：未开始。
- waiting：已打开授权页，等待系统网页登录回调。
- success：授权完成，凭据可用。
- error：授权失败、state 不匹配、超时、token exchange 失败。

额度刷新状态：

- idle：使用缓存。
- loading：正在刷新。
- success：刷新成功并更新时间。
- error：保留上次成功数据，展示错误徽标。

## 测试策略

第一阶段覆盖无需真网络的核心逻辑：

- `QuotaModelsTests`：总剩余额度、即将重置数量、空数据默认值。
- `NativeOAuthServiceTests`：provider 授权 URL、PKCE、token exchange 请求体。
- `NativeCodexQuotaServiceTests`：本地 token 直连 Codex 额度接口并映射账号卡模型。
- 构建验证：`xcodebuild test` 和 iOS Simulator 编译。

UI 交互在后续接入真实 OAuth 前使用样例数据验证布局和导航，不把真实 token 写入测试。

## 后续迭代

1. 加 Face ID 解锁本机 Keychain 凭据。
2. 接入 Claude/Gemini/xAI 等 provider 的额度解析器。
3. 加 iCloud 私有数据库同步。
4. 加 Shortcuts 导出与提醒推送。
