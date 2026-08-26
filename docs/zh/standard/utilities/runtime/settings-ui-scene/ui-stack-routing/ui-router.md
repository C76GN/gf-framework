# UI 路由与导航历史

`GFUIRouterUtility` 把稳定 route id 映射到面板场景、逻辑层和打开选项，并在 `GFUIUtility` 之上维护轻量历史。同步入口返回面板；异步入口返回 `GFUIRouteOperation`，将校验、可选预加载、面板提交和唯一终态统一为可观察契约。相关类型都属于 `gf.standard.ui.navigation`，`GFUIUtility` 与 Router 需要由项目 Installer 显式注册；Router 不会因类存在而自动进入架构。

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
4. `addons/gf/standard` 是否来自同一份完整发布包，相关脚本是否存在且能够解析。

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

每次打开都会在入口冻结 route id、场景路径、逻辑层、默认选项、参数和 metadata。`route_open_requested` 回调或其他项目代码随后修改已注册的 `GFUIRoute`，只影响未来请求，不会改变正在执行的请求身份、完成关联或历史记录。同步与异步 `replace` 都只在新面板确认打开后提交 Router 历史；打开失败时保留旧历史和旧当前路由。

## 类型化异步打开

`push_route_async()` 与 `replace_route_async()` 始终返回 `GFUIRouteOperation`。输入校验失败也会返回已经完成的句柄，不再要求调用方从 warning 文本推断结果：

```gdscript
var operation: GFUIRouteOperation = router.push_route_async(
	&"settings",
	{ "tab": "audio" }
)

if operation.is_completed():
	_handle_route_result(operation.get_result())
else:
	operation.completed.connect(_handle_route_result, CONNECT_ONE_SHOT)


func _handle_route_result(result: GFUIRouteResult) -> void:
	if result.is_successful():
		var panel: Node = result.get_panel()
		return
	push_warning("route=%s status=%s reason=%s" % [
		result.get_route_id(),
		result.get_status(),
		result.get_reason(),
	])
```

句柄只接受一个终态，`get_result()` 返回隔离副本。Router 也会发出 `route_operation_completed(result)`，适合统一遥测；单次调用优先观察句柄，避免按 route id 猜测并发请求。`GFUIRouteResult.to_dict()` 使用 `GFReportValueCodec` 收束调用方 metadata、非有限浮点和运行时对象，可直接进入 JSON 报告边界；`get_metadata()` 则保留原始类型并返回深副本。

Router 在提交前为底层 `GFUIPanelAsyncOperation` 预绑定弱终态回调，并同时校验 Route request ID 与精确 UI 句柄身份；同步 fallback 也不会丢失完成通知。`panel_async_load_finished` 只保留为聚合 telemetry，不承担单次 Route 相关性，因此全局监听器在完成信号中重入并提交同键新请求时，旧请求也不能终结替代请求。

相同 pending 请求只有在规范化 route id、操作、参数、面板选项、回调、预加载策略、预加载计划选项、metadata 以及 owner/scope 实例身份全部一致时才复用同一句柄。不同 Router 请求若占用相同场景路径、逻辑层和操作，会以 `STATUS_ASYNC_CONFLICT` 结束，不会静默覆盖先到请求。若项目绕过 Router，直接在同一 `GFUIUtility` 通道提交了相同 pending 面板请求，Router 也会返回 `ui_async_request_conflict`，避免把未执行路由配置回调的外部面板误记为路由成功。

Router 释放时，尚未提交面板的预加载会回滚并返回 `STATUS_DISPOSED`。面板已经交给当前 `GFUIUtility` 后无法按单个路由请求撤回；此时返回 `STATUS_OUTCOME_UNKNOWN`，明确表示 Router 已失去观察能力，而不是声称面板一定取消或一定打开。调用方不应把 `outcome_unknown` 当作失败后可安全重试的证明。

## 提交前生命周期取消

`async_options` 可以同时提供 `owner: Object` 与 `scope: GFAsyncScope`。两者是 OR 关系：任意一个先结束，尚未提交的路由就以 `STATUS_CANCELLED` 进入唯一终态，回滚 Router 拥有的预加载会话，并忽略迟到的预加载回调。Node owner 必须在调用时已进入场景树，离树会即时取消；普通 Object 只被弱持有，释放后由 Router 的 `tick()` 剪枝。正常注册在 Architecture 中的 Router 会随架构 tick 自动执行该剪枝。

```gdscript
var route_scope: GFAsyncScope = GFAsyncScope.new()
var operation: GFUIRouteOperation = router.push_route_async(
	&"inventory",
	{},
	{},
	Callable(),
	{
		"owner": self,
		"scope": route_scope,
		"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
	}
)

# 页面所属流程终止时，取消尚未提交的路由。
route_scope.cancel("flow_replaced")
```

已取消的 scope 会立即返回 `STATUS_CANCELLED`；已完成的 scope、类型错误的 scope 或不在场景树内的 Node owner 会返回 `STATUS_INVALID_LIFECYCLE`。提交边界是 Router 实际调用 `GFUIUtility` 异步打开入口的时刻；跨过边界后 Router 会解除 owner/scope 监听，后续离树或取消不会关闭已提交的面板，也不会改写其最终打开结果。需要关闭已打开面板时，项目应显式使用 UI 栈 API，不要把取消令牌当作隐式关闭指令。

## 打开前预加载策略

异步入口最后一个 `async_options` 参数支持：

- `preload_policy`：`PRELOAD_NONE`、`PRELOAD_BEST_EFFORT` 或 `PRELOAD_REQUIRED`。
- `preload_plan_options`：传给现有有界 Route Planner 的选项。
- `metadata`：写入句柄终态和预加载会话的调用方上下文。

默认 `PRELOAD_NONE` 保持直接提交面板请求的行为。`PRELOAD_BEST_EFFORT` 会执行可用计划，但规划不健康、缺少 `GFAssetUtility` 或事务失败时仍继续打开；成功结果可通过 `was_preload_attempted()`、`was_preload_successful()`、`get_preload_result()` 和非空 `reason` 识别降级。`PRELOAD_REQUIRED` 只有在计划健康且 `GFAssetLoadSession` 原子提交后才提交面板，否则返回对应 `STATUS_PRELOAD_*` 或 `STATUS_MISSING_ASSET_UTILITY` 终态。

```gdscript
var operation: GFUIRouteOperation = router.replace_route_async(
	&"battle_hud",
	{},
	{},
	Callable(),
	{
		"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
		"preload_plan_options": {
			"max_depth": 0,
			"max_concurrent_loads": 2,
		},
		"metadata": {
			"flow": "enter_battle",
		},
	}
)
```

自动协调始终强制 `include_source = true`；没有指定 `max_depth` 时使用 `0`，只把当前页面作为打开屏障，避免相邻候选的配置错误意外阻断当前页面。显式提高深度后，`PRELOAD_REQUIRED` 会把整个有界计划的健康度纳入门禁，`PRELOAD_BEST_EFFORT` 则把不完整候选记录为降级。

未显式提供 `group_id` 时，每个请求使用独占临时 owner group；面板进入终态后 Router 调用 `unload_group(group_id, false)` 释放所有权，不破坏共享缓存。显式提供 `group_id` 表示该分组由调用方管理，Router 不会代替项目释放。预加载只负责资源就绪，不实现权限、导航守卫、转场动画或业务恢复。

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

`ok` 表示是否成功识别起始路由并构建了稳定结果；`healthy` 还要求没有悬空路由、空场景、缺失资源、错误资源类型、重复 route ID 或容量截断。开发构建可以启用 `check_exists` 检查场景路径；Planner 会同时使用 `PackedScene` 类型提示和 Godot 为该类型认可的资源扩展，现有的脚本、纹理或普通 Resource 不会因为路径存在就被误判为健康页面。`missing_scene_paths` 只报告找不到的路径，`invalid_scene_type_paths` 单独报告路径存在但不能作为 `PackedScene` 使用的配置。发布运行时则可按项目成本策略决定是否检查。`max_catalog_routes` 默认是 `1024`，限制目录构建实际检查的原始路由数；Router 入口也只按注册顺序向 Planner 交付预算内条目和一个截断哨兵，不会预先复制完整目录。`catalog_route_count` 和 `catalog_budget_exhausted` 可用于判断目录是否完整。当起始路由可能位于尚未检查的尾部时，失败原因是 `catalog_budget_exhausted`，且不会把该 ID 放入 `missing_route_ids` 误报为确定缺失。`max_routes` 限制固定、可达和缺失候选的唯一 ID 总数，`max_edges` 限制实际扫描的原始相邻关系数；任一预算耗尽都会让 `truncated = true`，并反映到对应的 `catalog_budget_exhausted`、`route_budget_exhausted` 或 `edge_budget_exhausted`。

单独调用 `build_preload_plan()` 时，Planner 只生成计划，不会自动发起 IO。项目可以在登录结束、切换章节或进入大厅后选择合适时机调用 `preload_plan_async()`；离开对应区域后可用 `GFAssetUtility.unload_group(group_id)` 释放分组 pin。异步路由入口只有在显式选择预加载策略时才协调计划与 IO。权限变化、动态活动入口、网络条件、内存档位和实际预热时机仍由项目判断。

复杂页面恢复、权限、转场动画和业务导航状态仍由项目 Model/System 或 UI 节点负责。
