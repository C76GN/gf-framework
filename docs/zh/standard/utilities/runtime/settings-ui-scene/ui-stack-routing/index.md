# UI 栈、路由、视口与文本辅助总览

这一组工具覆盖 UI 面板栈、通用 Modal 结果协议、路由、分屏视口、表格数据视图、文本尺寸适配、富文本格式化和通用节点树操作。GF 提供结构和生命周期工具，不规定项目视觉、动画、输入规则或页面业务协议。

## 阅读入口

- [UI 面板栈与 Modal 协议](ui-stack-modal/index.md)：`GFUIUtility`、面板层级、异步加载、dismiss 策略、焦点辅助和 `GFModalResult`。
- [UI 路由与导航历史](ui-router.md)：`GFUIRouterUtility`、`GFUIRoute`、路由参数、相邻页面预加载计划和返回行为。
- [视口、文本与节点树工具](viewport-text-node-tools/index.md)：`GFViewportUtility`、`GFTableDataView`、`GFTextFitter`、`GFTextAutoFit`、`GFRichTextFormatter` 和 `GFNodeTreeOps`。

## 使用边界

这些工具只处理通用 UI 结构、几何转换、表格数据视图、文本适配和节点树操作。页面状态、转场动画、遮罩、输入绑定、返回值协议、权限和业务导航仍由项目 UI、Model 或 System 决定。
