# UI 面板栈与 Modal 协议

本组页面说明 `GFUIUtility` 如何管理默认 HUD、POPUP、TOP 与项目自定义逻辑层，以及项目如何复用 Modal 配置与结果协议。GF 只提供栈结构、可见性策略、加载状态、焦点辅助和通用交互标记；遮罩、动画、输入映射、主题、页面业务协议和返回值处理由项目 UI 实现。

## 阅读入口

- [面板栈与可扩展层级](panel-stack.md)：逻辑层注册、面板入栈、出栈、替换、完整可见性链和通用面板选项。
- [Modal 协议](modal-protocol.md)：`PanelMode.MODAL`、dismiss 策略、`GFModalConfig`、`GFModalAction` 与 `GFModalResult`。
- [生命周期与异步加载](async-lifecycle.md)：关闭释放、外部释放同步、异步请求去重、取消保护和加载信号。

## 使用边界

- `GFUIUtility` 管理面板实例和层级栈，不保存业务页面历史。
- `modal` 只表达独占交互意图，不创建默认遮罩、转场或输入拦截。
- Modal 面板的视觉实现、按钮布局、音效、动画、输入规则和业务上下文由项目层决定。
- 需要 route id 到场景路径的通用映射时，使用 [UI 路由与导航历史](../ui-router.md)。
