# 资源解析器

`GFResourceResolverUtility` 把项目稳定资源键解析为 Godot 资源路径或已加载 `Resource`。它位于 `GFResourceRegistry` 和 `GFAssetUtility` 之间：注册表负责保存 ID、路径和字段索引，资源加载工具负责异步请求、缓存和句柄；解析器负责覆盖链、显式 fallback 和诊断报告。

## 定位

解析器只处理资源定位机制，不解释资源业务含义。它不会扫描目录、下载资源、生成内容包、实例化节点或规定项目资源目录。项目、扩展或内容包可以通过显式 `register_path()`、owner-scoped `register_path_for_owner()` 或 provider 协议贡献资源键。

## 典型流程

```gdscript
var resolver := Gf.get_utility(GFResourceResolverUtility) as GFResourceResolverUtility

resolver.register_path(&"ui.inventory", "res://ui/inventory_panel.tscn", "PackedScene")

var report := resolver.resolve(&"ui.inventory")
if report["ok"]:
	print("resolved path: ", report["path"])
```

需要批量撤销某个系统、内容包或项目模块贡献的资源键时，使用 owner-scoped 注册。`registration_id` 可精确撤销单条记录，`owner_id` 可撤销该 owner 的全部记录；两者都不会影响同 key 的其他 owner 或项目手写注册：

```gdscript
var registration_id := resolver.register_path_for_owner(
	&"ui.inventory",
	&"project.ui_pack",
	"res://ui/skins/default/inventory_panel.tscn",
	"PackedScene",
	10
)

resolver.unregister_registration(registration_id)
resolver.unregister_owner(&"project.ui_pack")
```

可卸载来源需要整体刷新时，使用 `replace_owner_paths()` 提交完整快照。所有条目会先在隔离候选表中验证；任一条目失败时，旧 owner 记录与注册顺序都保持不变，空数组则表示原子清空：

```gdscript
var replacement := resolver.replace_owner_paths(&"project.ui_pack", [
	{
		"resource_key": &"ui.inventory",
		"path": "res://ui/skins/compact/inventory_panel.tscn",
		"type_hint": "PackedScene",
		"priority": 10,
	},
])
if not replacement["ok"]:
	push_error("resource snapshot rejected at index %d" % replacement["failed_index"])
```

运行时加载资源时，继续把实际请求交给 `GFAssetUtility`：

```gdscript
var assets := Gf.get_utility(GFAssetUtility) as GFAssetUtility

resolver.load_async(assets, &"ui.inventory", func(resource: Resource) -> void:
	var scene := resource as PackedScene
	if scene != null:
		add_child(scene.instantiate())
)
```

编辑器工具、构建脚本或已确认很小的资源需要同步读取时，可以调用 `load()`；运行时热路径应优先使用 `load_async()` 或 `make_asset_group_entries()` 后交给 `GFAssetUtility` 预加载。

## Provider 覆盖链

provider 是实现 `resolve_resource(request: Dictionary) -> Variant` 的对象。返回值可以是路径字符串、`Resource`，或包含 `path`、`resource`、`type_hint`、`cache_key`、`resource_identity`、`metadata`、`provider_id` 的 Dictionary。注册时的 `priority` 越高越优先；高优先级候选缺失或类型不匹配时，解析器会继续尝试低优先级候选。

```gdscript
class ProjectResourceProvider:
	extends RefCounted

	func resolve_resource(request: Dictionary) -> Dictionary:
		if request["key"] != &"ui.inventory":
			return { "ok": false, "reason": "not_found" }
		return {
			"path": "res://override/ui/inventory_panel.tscn",
			"type_hint": "PackedScene",
			"metadata": { "source": "project_override" },
		}

resolver.register_provider(ProjectResourceProvider.new(), &"project", 100)
```

## 报告字段

`resolve()` 返回 Dictionary 报告，稳定字段包括：

- `ok`：是否解析成功。
- `key`：请求的资源键。
- `path`：解析到的资源路径；provider 直接返回内存 `Resource` 时可为空。
- `type_hint`：最终传给 `ResourceLoader` 或 `GFAssetUtility` 的类型提示。
- `cache_key`：由 `GFResourceIdentity` 推导的统一缓存键；存在 Godot UID 时优先使用 `uid://`。
- `resource_identity`：资源身份快照，包含 raw path、canonical path、uid path、scheme、extension、cache key 和 metadata。
- `provider_id`：命中的 provider 标识。
- `reason`：失败原因，例如 `missing_resource`、`not_found` 或 `incompatible_resource`。
- `metadata`：provider 或显式注册路径提供的元数据副本。
- `resource`：provider 直接返回的内存资源，可选。

## 注意事项

- 默认会用 `ResourceLoader.exists()` 检查路径是否存在；工具链生成报告或预声明资源时可传 `{ "check_exists": false }`。
- 默认只接受显式注册键或 provider 候选；工具链确实需要直接把 `res://`、`uid://` 或 `user://` 路径作为资源键时，必须传 `{ "allow_direct_path": true }`。
- 解析报告中的 `path` 会尽量返回 canonical `res://` 路径；`uid://` 输入仍会保留在 `cache_key` / `resource_identity.uid_path` 中，方便和 `GFAssetUtility` 缓存对齐。
- 同一资源键可以有多条 owner-scoped 记录，解析时按 `priority` 和注册顺序选择候选。普通 `register_path()` 会先完整验证新候选，再只替换该 key 的 ownerless 项目记录；失败时旧记录与注册顺序不变，也不会删除任何 owner-scoped 贡献。可卸载来源应使用 `register_path_for_owner()`，避免清理时误删其他来源的记录。
- owner 的批量重建应优先使用 `replace_owner_paths()`，不要先 `unregister_owner()` 再逐条注册；后者在中途失败时会暴露部分更新状态。
- `make_asset_group_entries()` 只会导出包含路径的成功解析结果，并携带 `cache_key` 与 `resource_identity`；内存 `Resource` 不能转成 `GFAssetUtility.preload_group_async()` 请求。
- provider 协议只是一种贡献资源定位的机制，不应在 provider 内写入具体玩法规则或跨扩展协作逻辑。
