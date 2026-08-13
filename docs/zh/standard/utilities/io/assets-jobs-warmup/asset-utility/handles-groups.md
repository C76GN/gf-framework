# 资源句柄与分组预热

## 资源句柄

当资源会被多个短生命周期对象持有时，可以用 `GFAssetHandle` 表达所有权。句柄会增加路径引用计数并锁定缓存，`release()` 后才允许 LRU 淘汰。创建时解析出的 lease path 与 cache key 会被私有冻结；公开 `path` 只用于展示，之后即使被调用方改写，也不能把释放授权转移到另一缓存身份。句柄也只能由创建它的 `GFAssetUtility` 消费。

如果传入 owner，`release_owner(owner)` 或 Node 退出树时会释放该 owner 的引用。

```gdscript
assets.load_handle_async(
	"res://ui/inventory_panel.tscn",
	func(handle: GFAssetHandle) -> void:
		if handle == null:
			return
		var scene := handle.get_resource() as PackedScene
		add_child(scene.instantiate())
		handle.release(),
	"PackedScene",
	self,
	&"inventory_ui"
)
```

## 分组预热

资源分组适合 UI 包、关卡包或主题包这类“成组预热、成组卸载”的通用流程，不要求项目把业务语义写进工具层。

```gdscript

assets.preload_group_async(
	&"battle_ui",
	[
		{ "path": "res://ui/battle_hud.tscn", "type_hint": "PackedScene" },
		{ "path": "res://ui/skill_icon_atlas.tres", "type_hint": "Resource" },
	],
	func(report: Dictionary) -> void:
		print(report["ok"])
)
```

## 加载约束

分组预热也可以使用加载通道选项：

```gdscript
assets.preload_group_async(
	&"battle_ui",
	battle_ui_paths,
	_on_battle_ui_ready,
	{
		"max_concurrent_loads": 1,
	}
)
```

未显式指定 `lane_id` 时，分组 ID 会作为通道名，因此同一组内部可以串行或限流加载，而不同组仍可独立调度。分组只表达资源集合和加载约束，不表达 UI 包、关卡包或主题包的业务含义。

`unload_group(group_id, true)` 只释放指定分组的 membership 与该组建立的 pin。只有同一路径已经没有句柄引用、任何剩余 pin 和其他分组 membership 时，工具才会立即移除缓存；卸载一个分组不会擦除另一个分组的账本。`pin=false` 的 membership 仍然只表示分组归属，不提供缓存保留能力，因此资源在超过容量时仍可被正常 LRU 淘汰；需要稳定保留时应使用分组 pin、手动 pin 或 `GFAssetHandle`。

## 可保存的预热计划

当预热清单需要放进 `.tres`、编辑器配置或项目级 manifest 时，用 `GFAssetPreloadPlan` 保存计划，再委托 `preload_plan_async()` 执行。计划会保留禁用条目并提供 `validate()` 报告；实际加载仍复用分组预热、缓存 pin 和 lane 限流机制。

```gdscript
var plan := GFAssetPreloadPlan.new()
plan.configure(
	&"battle_ui",
	[
		{ "path": "res://ui/battle_hud.tscn", "type_hint": "PackedScene" },
		{ "path": "res://ui/skill_icon_atlas.tres", "type_hint": "Resource", "enabled": true },
	],
	{
		"plan_id": &"boot.battle_ui",
		"lane_id": &"ui",
		"max_concurrent_loads": 2,
	}
)

assets.preload_plan_async(plan, func(report: Dictionary) -> void:
	if not report["ok"]:
		push_warning("资源预热计划未完全成功。")
)
```

如果项目只是临时传入路径数组，继续使用 `preload_group_async()` 更直接；不要为了使用计划对象而把一次性加载流程资源化。
