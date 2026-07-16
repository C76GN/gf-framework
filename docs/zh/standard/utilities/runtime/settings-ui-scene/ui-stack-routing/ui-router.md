# UI 路由与导航历史

`GFUIRouterUtility` 把稳定 route id 映射到面板场景、逻辑层和打开选项，并在 `GFUIUtility` 之上维护轻量历史。两者都属于 `gf.standard.ui.navigation`，都需要由项目 Installer 显式注册；Router 不会因类存在而自动进入架构。

完整装配示例见 [面板栈与可扩展层级](ui-stack-modal/panel-stack.md)。启动代码必须先检查 `await Gf.init()`，再查询 ready Utility：

```gdscript
if not await Gf.init():
	push_error(Gf.get_architecture().last_initialization_error)
	return

var router := Gf.get_utility(GFUIRouterUtility, true) as GFUIRouterUtility
if router == null:
	push_error("GFUIRouterUtility 未注册；检查 gf/project/installers。")
	return

var routes: Array[GFUIRoute] = [
	preload("res://ui/routes/login.tres"),
	preload("res://ui/routes/home.tres"),
]
router.register_routes(routes)
```

`Invalid call ... in base 'Nil'` 表示 `Gf.get_utility()` 返回了 `null`，不表示 `register_routes()` 被移除。优先检查：

1. `ProjectSettings.get_setting("gf/project/installers", [])` 是否含项目 Installer。
2. `await Gf.init()` 是否返回 `true`；失败时读取 `last_initialization_error`。
3. Installer 是否真的注册了 `GFUIUtility` 和 `GFUIRouterUtility`。
4. 最小 package 安装是否包含 `gf.standard.ui.navigation`。

## 路由与逻辑层

```gdscript
var route := GFUIRoute.new()
route.route_id = &"settings"
route.scene_path = "res://ui/settings_panel.tscn"
route.layer = GFUIUtility.Layer.POPUP

router.register_route(route)
router.push_route(&"settings", { "tab": "audio" })
router.back()
```

自定义 `route.layer` 可以是任意非负逻辑层 ID，但该层必须先通过 `GFUIUtility.register_layer()` 注册；否则 Router 会发出 `route_open_failed(route_id, "missing_ui_layer")`，而不是退化为泛化加载错误。

如果面板实现 `set_route_params(params)` 或 `set_route_metadata(metadata)`，Router 会在入栈前传入副本。`back()` 只弹出当前 UI 栈顶且属于路由历史的面板；项目直接在同层压入普通面板后，应先关闭普通面板。

异步打开时，同一路径、逻辑层和操作上的相同 route 会复用 pending 边界；不同 route 指向同一 pending 目标时返回 `route_async_conflict`。复杂页面恢复、权限、转场动画和业务导航状态仍由项目 Model/System 或 UI 节点负责。
