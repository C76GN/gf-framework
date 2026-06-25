# Asset Metadata

Asset Metadata 扩展用于把导入资产、节点或资源片段上的结构化元数据收束为 GF 可查询的记录。它只处理元数据键、复制、读取、收集和报告，不解释字段业务含义。

适合场景包括：从 glTF `extras` 带入作者标记、扫描关卡节点 metadata、在编辑器导入检查中生成统一报告，或让项目工具用同一套记录读取资产标签。

## 阅读入口

- `GFAssetMetadataUtility`：读取、写入、归一化和收集对象 metadata。
- `GFAssetMetadataRecord`：用稳定结构保存来源路径、对象路径、对象类别和 metadata 字典。
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

`read_object_metadata_with_schema()` 只返回补齐默认值后的副本，不会改写对象 metadata；`validate_object_metadata()` 返回标准 `GFValidationReport` 字典。字段含义、错误分级、跨资产引用和迁移策略仍属于项目工具。

## 使用边界

- Asset Metadata 不内置 `spawn_point`、`loot`、`quest`、`door` 等业务字段。
- 项目可以用 `GFDictionarySchema` 定义 metadata schema，并在自己的导入管线、Installer 或工具中消费记录。
- 需要跨资产引用检查、业务级错误分级或版本迁移时，应在项目工具中基于 `GFAssetMetadataRecord` 和通用 schema 报告实现。
- 其他 GF 内置扩展不应直接依赖 Asset Metadata；跨扩展组合应放在项目 Installer 或独立插件中。

## API Reference

完整类、方法和属性清单见 [Asset Metadata API Reference](../../reference/api/extensions-asset-metadata.md)。
