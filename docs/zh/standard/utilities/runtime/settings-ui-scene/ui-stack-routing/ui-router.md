# UI 路由与导航历史

这一页说明如何用 `GFUIRouterUtility` 把 route id 映射到面板场景，并维护轻量路由历史。

## 路由与历史

`panel_opened`、`panel_closed` 和 `navigation_changed` 适合把 UI 栈变化同步给焦点系统、音效、诊断面板或项目自己的路由层。`get_panel_stack()`、`get_stack_count()`、`is_panel_open()` 和 `get_debug_snapshot()` 只返回当前栈状态，不保存业务历史；如果项目只需要 route id 到面板场景的通用映射，可以在其上注册 `GFUIRouterUtility` 和 `GFUIRoute`：

```gdscript
var route := GFUIRoute.new()
route.route_id = &"settings"
route.scene_path = "res://ui/settings_panel.tscn"
route.layer = GFUIUtility.Layer.POPUP

var router := Gf.get_utility(GFUIRouterUtility) as GFUIRouterUtility
router.register_route(route)
router.push_route(&"settings", { "tab": "audio" })
router.back()
```

`GFUIRouterUtility` 只维护路由表、路由参数、面板打开选项和轻量历史；如果面板实现了 `set_route_params(params)` 或 `set_route_metadata(metadata)`，路由工具会在入栈前调用它们。`back()` 只会弹出当前 UI 栈顶正好是路由历史记录中的面板；如果项目直接通过 `GFUIUtility.push_panel()` 在同层压入了普通面板，应先由项目关闭该普通面板，再让路由返回，避免路由历史和实际 UI 栈互相踩踏。复杂页面恢复、返回值、转场动画、权限和业务导航状态仍应由项目自己的 Model/System 或 UI 节点处理。

异步打开 route 时，同一路径、层级和操作上的未完成请求会被视为同一导航边界。相同 route 会复用 pending 结果；不同 route 指向同一目标时会被拒绝为冲突，避免两个逻辑 route 同时等待同一个面板实例并污染历史栈。无 Asset Utility 的同步 fallback 也会进入同一完成回调并移除 route pending 身份，不会让后续导航永久误判为进行中。

每个层级都会创建独立 `CanvasLayer`：`HUD`、`POPUP`、`TOP` 数值越大显示越靠前。`GFUIUtility` 只负责层级根节点、栈顺序、自动隐藏、状态信号、实例加载和少量面板交互策略，不规定 UI 动画、视觉遮罩、输入绑定或面板间通信。
