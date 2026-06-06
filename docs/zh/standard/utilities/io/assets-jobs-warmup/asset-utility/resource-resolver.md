# 资源解析器

`GFResourceResolverUtility` 把项目稳定资源键解析为 Godot 资源路径或已加载 `Resource`。它位于 `GFResourceRegistry` 和 `GFAssetUtility` 之间：注册表负责保存 ID、路径和字段索引，资源加载工具负责异步请求、缓存和句柄；解析器负责覆盖链、显式 fallback 和诊断报告。

## 定位

解析器只处理资源定位机制，不解释资源业务含义。它不会扫描目录、下载资源、生成内容包、实例化节点或规定项目资源目录。项目、扩展或未来内容包可以通过显式 `register_path()` 或 provider 协议贡献资源键。

## 典型流程

```gdscript
var resolver := Gf.get_utility(GFResourceResolverUtility) as GFResourceResolverUtility

resolver.register_path(&"ui.inventory", "res://ui/inventory_panel.tscn", "PackedScene")

var report := resolver.resolve(&"ui.inventory")
if report["ok"]:
	print("resolved path: ", report["path"])
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

provider 是实现 `resolve_resource(request: Dictionary) -> Variant` 的对象。返回值可以是路径字符串、`Resource`，或包含 `path`、`resource`、`type_hint`、`metadata`、`provider_id` 的 Dictionary。注册时的 `priority` 越高越优先；高优先级候选缺失或类型不匹配时，解析器会继续尝试低优先级候选。

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
- `provider_id`：命中的 provider 标识。
- `reason`：失败原因，例如 `missing_resource`、`not_found` 或 `incompatible_resource`。
- `metadata`：provider 或显式注册路径提供的元数据副本。
- `resource`：provider 直接返回的内存资源，可选。

## 注意事项

- 默认会用 `ResourceLoader.exists()` 检查路径是否存在；工具链生成报告或预声明资源时可传 `{ "check_exists": false }`。
- 默认只接受显式注册键或 provider 候选；工具链确实需要直接把 `res://`、`uid://` 或 `user://` 路径作为资源键时，必须传 `{ "allow_direct_path": true }`。
- `make_asset_group_entries()` 只会导出包含路径的成功解析结果；内存 `Resource` 不能转成 `GFAssetUtility.preload_group_async()` 请求。
- provider 协议只是一种贡献资源定位的机制，不应在 provider 内写入具体玩法规则或跨扩展协作逻辑。
