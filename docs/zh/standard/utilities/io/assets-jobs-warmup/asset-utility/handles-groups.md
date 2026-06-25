# 资源句柄与分组预热

## 资源句柄

当资源会被多个短生命周期对象持有时，可以用 `GFAssetHandle` 表达所有权。句柄会增加路径引用计数并锁定缓存，`release()` 后才允许 LRU 淘汰。

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
