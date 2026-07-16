# Asset Metadata

Asset Metadata 扩展用于把导入资产、节点或资源片段上的结构化元数据收束为 GF 可查询的记录。它只处理元数据键、复制、读取、收集和报告，不解释字段业务含义。

适合场景包括：从 glTF `extras` 带入作者标记、扫描关卡节点 metadata、在编辑器导入检查中生成统一报告，或让项目工具用同一套记录读取资产标签。

## 阅读入口

- `GFAssetMetadataUtility`：读取、写入、归一化和收集对象 metadata。
- `GFAssetMetadataRecord`：用稳定结构保存来源路径、对象路径、对象类别和 metadata 字典。
- `GFAssetAttributionTools`：归一化资产授权/署名字段，检查资源路径归因覆盖，并生成稳定通知文本。
- `GFAssetMetadataGltfDocumentExtension`：在 glTF 导入时把节点 `extras` 复制为 GF metadata。

## 典型流程

导入 glTF 后，节点上的 `extras` 会被写入默认键 `gf_asset_metadata`。项目可以在需要时收集场景树：

```gdscript
var utility := Gf.get_utility(GFAssetMetadataUtility) as GFAssetMetadataUtility
var records := utility.collect_node_tree(imported_root, {
	"source_path": "res://levels/forest.glb",
})

for record: GFAssetMetadataRecord in records:
	var metadata := record.metadata
	# 项目层在这里解释 metadata 字段。
```

需要对 metadata 做通用结构约束时，复用 `GFDictionarySchema` / `GFSchemaField`，不要另建一套模板系统：

```gdscript
var schema := GFDictionarySchema.new()
schema.schema_id = &"asset_metadata"
schema.coerce_values = true
schema.add_field(GFSchemaField.new().configure(&"kind", GFSchemaField.ValueType.STRING, {
	"required": true,
	"allow_null": false,
	"default_value": "asset",
}))

var normalized := utility.read_object_metadata_with_schema(imported_root, schema)
var report := utility.validate_object_metadata(imported_root, schema)
```

`read_object_metadata_with_schema()` 只返回补齐默认值后的副本，不会改写对象 metadata；`validate_object_metadata()` 会校验原始 metadata，因此缺失必填字段不会被 schema 默认值掩盖。字段含义、错误分级、跨资产引用和迁移策略仍属于项目工具。

写入空 metadata 默认表示清除旧 metadata marker，避免扫描器把 stale 空字典误判成有效数据。项目确实需要表达“已扫描但没有可记录字段”时，在 `write_object_metadata()` options 中传入 `"mark_scanned_empty": true`，并用 `get_object_metadata_state()` 区分 `absent`、`empty` 和 `valid`。

收集大型节点树时可传 `"max_nodes"` 限制扫描节点数量；`build_node_tree_report()` 会返回 `visited_node_count`、`max_nodes` 和 `truncated`，便于导入工具或 CI 在预算内停止，而不是递归扫完整个场景。

## 资产归因报告

项目需要整理第三方资产授权、作者、来源或 Credits 信息时，可以把归因数据放在普通 metadata 字段中，然后用 `GFAssetAttributionTools` 做统一归一和覆盖检查：

```gdscript
var record := GFAssetMetadataRecord.new().configure("res://assets/ui/icons.png", NodePath("."), &"asset", {
	"attribution": {
		"license_id": "CC0-1.0",
		"title": "UI Icons",
		"creator": "Example Studio",
		"source_url": "https://example.test/icons",
	},
})

var report := GFAssetAttributionTools.build_attribution_report([record], PackedStringArray([
	"res://assets/ui/icons.png",
]))
var notice_text := GFAssetAttributionTools.format_notice_text(report)
```

归因条目支持 `path` / `resource_path` / `source_path`、`license_id` / `license`、`title` / `name`、`creator` / `author`、`source_url` / `source` 等常见别名。`metadata.attribution` 这种嵌套形态会继承同级 metadata 中的 `source_path`、`subject_path` 和 `subject_kind`。传入资源路径时，工具会检查每个资源是否命中精确条目或父目录条目，输出 `GFValidationReport` 兼容字典，适合接入导入检查、CI 或项目 Credits 生成流程。默认报告会把条目和覆盖路径转换为 JSON-safe 值，便于直接进入日志、CI artifact 或诊断面板。

`GFAssetAttributionTools` 只处理结构化字段、路径覆盖和通知文本摘要；它不内置许可证正文、不联网拉取数据，也不替项目判断某个授权是否可用于商业发布。项目仍应在自己的发布流程中维护许可证正文、审查规则和法务确认。

## 使用边界

- Asset Metadata 不内置 `spawn_point`、`loot`、`quest`、`door` 等业务字段。
- 资产归因工具只提供通用字段约定和覆盖报告，不替项目维护授权模板、许可证全文或发布合规策略。
- 项目可以用 `GFDictionarySchema` 定义 metadata schema，并在自己的导入管线、Installer 或工具中消费记录。
- 需要跨资产引用检查、业务级错误分级或版本迁移时，应在项目工具中基于 `GFAssetMetadataRecord` 和通用 schema 报告实现。
- 其他 GF 内置扩展不应直接依赖 Asset Metadata；跨扩展组合应放在项目 Installer 或独立插件中。

## API Reference

完整类、方法和属性清单见 [Asset Metadata API Reference](../../reference/api/extensions-asset-metadata.md)。
