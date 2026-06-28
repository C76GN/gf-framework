# 通用资源注册表

`GFResourceRegistry` 用稳定 ID 管理资源路径、类型提示和字段索引。它适合把项目里反复出现的“ID -> 资源路径”描述统一成一个通用资源，而不是让每个系统各自手写字典、字符串 key 或加载分组。

## 定位

注册表只回答三个问题：某个 ID 是否存在、它指向哪个资源、它有哪些可查询字段。它不解释字段含义，也不规定物品、技能、关卡或 UI 的业务规则。需要从目录生成注册表时，使用 `GFResourceRegistryTools` 在编辑器工具、构建脚本或项目 Installer 中扫描路径并写入 `GFResourceRegistry`。

`GFResourceRegistryEntry` 是单条映射，包含 `id`、`path`、`type_hint` 和 `fields`。`fields` 可放单值、`Array` 或 `PackedStringArray`，注册表会用 `GFValueIndex` 建立运行时索引。

## 典型流程

```gdscript
var registry := GFResourceRegistry.new()

registry.set_entry(
	GFResourceRegistryEntry.new().configure(
		&"inventory_panel",
		"res://ui/inventory_panel.tscn",
		"PackedScene",
		{
			&"group": "ui",
			&"tags": ["panel", "inventory"],
		}
	)
)

var ui_ids := registry.query(&"group", "ui")
var panel_scene := registry.load_entry(&"inventory_panel") as PackedScene
```

需要给资源选择器、命令面板或调试工具做文本检索时，可以直接把注册表条目交给 `GFTextSearchScorer`：

```gdscript
var results := registry.search("inventory panel", {
	"limit": 8,
})

for result in results:
	var candidate: Dictionary = result["candidate"]
	print(candidate["id"], candidate["path"])
```

`make_search_candidates()` 会把条目 ID、路径、类型提示和 `fields` 中的通用值整理成候选字典；`search()` 只做文本评分和排序，不加载资源，也不解释字段业务含义。项目如果需要更细的搜索权重，可以传入 `GFTextSearchScorer.rank_candidates()` 支持的 `fields`、`require_all_tokens`、`case_sensitive`、`include_unmatched` 或 `limit` 选项。

资源选择器、调试面板或编辑器列表通常还需要稳定摘要和分页元数据。`make_entry_summary()` 会从条目字段里抽取显示名、说明、预览路径、标签和分类，并保留 ID、路径、basename 与类型提示；它不会加载预览图，也不会要求项目使用固定字段名。需要使用项目自有字段时，把候选字段列表传给对应选项即可。

```gdscript
var summary := registry.make_entry_summary(&"inventory_panel", {
	"title_fields": PackedStringArray(["display_name", "label"]),
	"preview_path_fields": PackedStringArray(["preview_path", "thumbnail"]),
	"tag_fields": PackedStringArray(["tags", "keywords"]),
})

print(summary["title"], summary["preview_path"])
```

`search_page()` 在 `search()` 的基础上返回页码、总数、当前页条目 ID、搜索报告和摘要数组。空查询默认按注册表候选顺序列出条目，适合资源浏览器第一次打开时展示全部内容；如果只需要纯文本命中，可以把 `empty_query_returns_all` 设为 `false`。

```gdscript
var page := registry.search_page("panel", 1, 24, {
	"summary_options": {
		"include_fields": false,
	},
})

for item in page["summaries"]:
	print(item["entry_id"], item["title"])
```

如果工具链需要把资源目录或条目字段组织成菜单、分组面板或构建索引，使用 `group_entry_ids()` 导出“分组 key -> 条目 ID 列表”。它只返回 ID，不加载资源，也不要求 key 唯一：

```gdscript
var by_tag := registry.group_entry_ids(GFResourceRegistry.GROUP_SOURCE_FIELD, {
	"field_id": &"tags",
})

var by_file := registry.group_entry_ids(GFResourceRegistry.GROUP_SOURCE_PATH_BASENAME)
```

`group_entry_ids()` 支持按 ID、完整路径、路径 basename、类型提示或 `fields` 中的字段值分组。字段值可以是单值、`Array` 或 `PackedStringArray`；数组值会让同一个条目进入多个分组。需要只处理部分条目时传入 `entry_ids`，需要保留空 key 时传入 `include_empty` 与 `empty_key`。

需要异步加载时，把 `GFAssetUtility` 显式传入注册表。这样注册表仍然是纯资源描述，缓存、并发合并和句柄所有权继续由 `GFAssetUtility` 负责。

```gdscript
var assets := Gf.get_utility(GFAssetUtility) as GFAssetUtility

registry.request_entry_async(assets, &"inventory_panel", func(resource: Resource) -> void:
	var scene := resource as PackedScene
	if scene != null:
		add_child(scene.instantiate())
)
```

成组预热时，用 `make_asset_group_entries()` 转成 `GFAssetUtility.preload_group_async()` 接受的请求列表。

```gdscript
assets.preload_group_async(
	&"ui",
	registry.make_asset_group_entries(registry.query(&"group", "ui")),
	func(report: Dictionary) -> void:
		print(report["ok"])
)
```

如果项目资源目录有稳定结构，可以用 `GFResourceRegistryTools` 生成注册表。工具默认会推导路径字段、目录标签和常见资源类型提示；项目仍可通过 `extra_fields`、`fields_by_path` 或 `fields_by_id` 合并自己的字段。

```gdscript
var registry := GFResourceRegistryTools.create_registry_from_scan("res://assets", {
	"id_mode": "relative_path",
	"base_path": "res://assets",
	"path_separator": ".",
	"fields_by_id": {
		"ui.inventory_panel": {
			&"group": "ui",
		},
	},
})
```

扫描阶段只需要收窄“哪些资源路径进入注册表”时，使用 `include_patterns` 和 `exclude_patterns`。模式按 `pattern_base_path` 的相对路径匹配，也会兼容完整资源路径和文件名；支持 `*`、`**` 与 `?`，适合表达项目工具层的通用资源集合，不需要新增单独的运行时分组资源。

```gdscript
var registry := GFResourceRegistryTools.create_registry_from_scan("res://assets", {
	"id_mode": "relative_path",
	"base_path": "res://assets",
	"include_patterns": PackedStringArray(["ui/**/*.tscn", "icons/*.png"]),
	"exclude_patterns": PackedStringArray(["**/draft_*", "temp/**"]),
})
```

已有入口资源时，也可以先按 Godot 的依赖关系展开路径，再生成注册表或预加载分组。`collect_dependency_paths()` 只读取 `ResourceLoader.get_dependencies()`，不改写 remap、不打包 PCK，也不解释依赖的业务含义。

```gdscript
var paths := GFResourceRegistryTools.collect_dependency_paths("res://ui/inventory_panel.tscn", {
	"include_root": true,
	"recursive": true,
	"max_dependency_paths": 256,
})

var registry := GFResourceRegistryTools.create_registry_from_paths(paths, {
	"id_mode": "relative_path",
	"base_path": "res://",
})
```

当工具链需要判断依赖闭包是否可信时，使用 `build_dependency_report()` 获取结构化诊断。报告会保留已纳入路径、资源记录、缺失项、被过滤项、循环和上限命中状态；它不决定导出策略，也不会把依赖归类成项目业务概念。

```gdscript
var report := GFResourceRegistryTools.build_dependency_report("res://ui/inventory_panel.tscn", {
	"include_root": true,
	"recursive": true,
	"max_dependency_paths": 256,
})

if report["ok"] and not report["limit_reached"]:
	var paths := PackedStringArray(report["paths"])
	var registry := GFResourceRegistryTools.create_registry_from_paths(paths, {
		"id_mode": "relative_path",
		"base_path": "res://",
	})
else:
	push_warning(report["summary"])
```

## 注意事项

- 推荐把 `id` 当作项目稳定逻辑 ID，不要直接复用资源路径。
- `path` 可使用 `res://` 或 Godot `uid://`。
- 如果运行时直接修改 `entries` 数组或条目字段，调用 `mark_index_dirty()` 后再查询。
- 字段索引只基于条目 `fields`，不会为了查询而加载实际资源。
- 自动扫描应作为项目工具、编辑器按钮、构建步骤或 Installer 的一部分运行；运行时加载仍交给 `GFAssetUtility`。
- `scan_resource_paths()`、`collect_dependency_paths()` 和 `build_dependency_report()` 的 `excluded_paths` 会按 `GFPathTools` 规范化并去重，命中排除目录自身或其子路径都会被跳过。
- `scan_resource_paths()` 的 `include_patterns` / `exclude_patterns` 只筛选扫描结果，不定义业务分组、导出包或热更策略；这些策略应在项目工具中组合注册表、内容包或安装流程。
- 依赖收集只返回路径闭包，不决定导出、热更新、DLC 或分包策略；这些策略应留在项目构建流程里。
- 依赖报告中的 `excluded` 只表示被调用方过滤，不代表资源错误；`issues` 才是需要工具链显式处理的诊断入口。
