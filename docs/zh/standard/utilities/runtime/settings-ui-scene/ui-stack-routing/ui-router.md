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

`route.layer` 是“这条 Route 属于哪个独立导航栈”，不是全局页面优先级。登录、认证、主页这类互斥页面应放在同一层并调用 `replace_route()`；跨到新层不会自动关闭旧层。真正需要跨层切换时，由项目流程先显式 `clear_layer(old_layer)`。绘制前后关系则读取目标层的 `GFUILayerDefinition.canvas_layer`，与 route 的逻辑层 ID 大小无关。

如果面板实现 `set_route_params(params)` 或 `set_route_metadata(metadata)`，Router 会在入栈前传入副本。`back()` 只弹出当前 UI 栈顶且属于路由历史的面板；项目直接在同层压入普通面板后，应先关闭普通面板。

## 从路由关系构建预加载计划

页面第一次打开时常会出现资源加载抖动。项目可以在 `GFUIRoute.adjacent_route_ids` 中声明“从当前页面通常可能到达哪些页面”，再由 `GFUIRoutePreloadUtility` 做有界可达性遍历。这个关系只是资源规划提示，不是权限、导航守卫或强制跳转规则。

例如，主页可以到设置、背包和任务页；暂停菜单则作为任何阶段都可能打开的固定页面：

```gdscript
var home: GFUIRoute = GFUIRoute.new()
home.route_id = &"home"
home.scene_path = "res://ui/home.tscn"
home.adjacent_route_ids = PackedStringArray([
	"settings",
	"inventory",
	"quests",
])

var settings: GFUIRoute = GFUIRoute.new()
settings.route_id = &"settings"
settings.scene_path = "res://ui/settings.tscn"

var inventory: GFUIRoute = GFUIRoute.new()
inventory.route_id = &"inventory"
inventory.scene_path = "res://ui/inventory.tscn"

var quests: GFUIRoute = GFUIRoute.new()
quests.route_id = &"quests"
quests.scene_path = "res://ui/quests.tscn"

var pause: GFUIRoute = GFUIRoute.new()
pause.route_id = &"pause"
pause.scene_path = "res://ui/pause.tscn"

var routes: Array[GFUIRoute] = [home, settings, inventory, quests, pause]
router.register_routes(routes)
```

路由注册完成后，可以从 Router 当前目录直接构建 `GFAssetPreloadPlan`：

```gdscript
var result: Dictionary = router.build_preload_plan(&"home", {
	"max_depth": 1,
	"max_catalog_routes": 256,
	"max_routes": 12,
	"max_edges": 48,
	"fixed_route_ids": PackedStringArray(["pause"]),
	"group_id": &"ui_home_neighbors",
	"plan_id": &"home_neighbors",
	"pin_cache": true,
	"max_concurrent_loads": 2,
	"check_exists": OS.is_debug_build(),
})

if not GFVariantData.get_option_bool(result, "ok"):
	push_error("无法从指定起始路由构建预加载计划。")
	return

if not GFVariantData.get_option_bool(result, "healthy"):
	push_warning("路由关系包含缺失、重复、无场景或被预算截断的条目。")

var plan_value: Variant = result.get("asset_plan")
if not (plan_value is GFAssetPreloadPlan):
	return
var asset_plan: GFAssetPreloadPlan = plan_value
var assets: GFAssetUtility = Gf.get_utility(GFAssetUtility, true) as GFAssetUtility
if assets == null:
	return

assets.preload_plan_async(asset_plan, func(report: Dictionary) -> void:
	if not GFVariantData.get_option_bool(report, "ok"):
		push_warning("候选页面预加载未完全成功。")
)
```

默认 `max_depth = 1`，只分析直接相邻页面；默认不把起始页面加入计划，因为它通常已经加载。路由 ID 在注册、查询和规划时都会去除首尾空白，纯空白 ID 视为无效；项目仍应直接保存规范化后的稳定 ID，避免配置文件出现肉眼难辨的差异。`fixed_route_ids` 用于加载页、暂停页或通用错误页等与当前可达关系无关但始终要纳入本次候选的页面。固定候选会优先占用 `max_routes`，可达页面进入 `temporary_route_ids`，实际路径最终按资源身份去重。这里的“固定”只表示计划候选，不代表自动常驻或采用不同的缓存生命周期。

`ok` 表示是否成功识别起始路由并构建了稳定结果；`healthy` 还要求没有悬空路由、空场景、缺失资源、重复 route ID 或容量截断。开发构建可以启用 `check_exists` 检查场景路径，发布运行时则可按项目成本策略决定是否检查。`max_catalog_routes` 默认是 `1024`，限制目录构建实际检查的原始路由数；Router 入口也只按注册顺序向 Planner 交付预算内条目和一个截断哨兵，不会预先复制完整目录。`catalog_route_count` 和 `catalog_budget_exhausted` 可用于判断目录是否完整。当起始路由可能位于尚未检查的尾部时，失败原因是 `catalog_budget_exhausted`，且不会把该 ID 放入 `missing_route_ids` 误报为确定缺失。`max_routes` 限制固定、可达和缺失候选的唯一 ID 总数，`max_edges` 限制实际扫描的原始相邻关系数；任一预算耗尽都会让 `truncated = true`，并反映到对应的 `catalog_budget_exhausted`、`route_budget_exhausted` 或 `edge_budget_exhausted`。

Planner 只生成计划，不会自动发起 IO。项目可以在登录结束、切换章节或进入大厅后选择合适时机调用 `preload_plan_async()`；离开对应区域后可用 `GFAssetUtility.unload_group(group_id)` 释放分组 pin。权限变化、动态活动入口、网络条件、内存档位和实际预热时机仍由项目判断。

异步打开时，同一路径、逻辑层和操作上的相同 route 会复用 pending 边界；不同 route 指向同一 pending 目标时返回 `route_async_conflict`。复杂页面恢复、权限、转场动画和业务导航状态仍由项目 Model/System 或 UI 节点负责。
