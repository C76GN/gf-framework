# 索引与跨表引用

## 索引声明

需要表达唯一键或跨表关系时，可以在 `GFConfigTableSchema.indexes` 中加入 `GFConfigTableIndexDefinition`，在 `references` 中加入 `GFConfigTableReference`。唯一索引会参与单表校验；跨表引用由 `GFConfigReferenceResolver.validate_tables()` 在多表上下文中检查。

## 运行时查询

如果表数据保存为 `GFConfigTableResource`，`schema.indexes` 还可以作为运行时命名索引来源。调用 `rebuild_indexes()` 会把索引缓存写入 `records_by_index`，适合随 `.tres/.res` 一起保存；缓存为空时，`get_index_record()` 和 `get_index_records()` 会按 schema 临时构建查询结果。

## 跨表引用

`GFConfigTableReference.source_mode` 默认为 `SourceMode.FIELDS`，把来源字段的完整值组成单字段键或复合键。`resolve_record_references()` 只处理这一模式，可把一条记录的引用解析为目标记录副本。GF 只理解字段、键和报告结构，表关系及其业务含义由项目声明。

如果多张表已经聚合到 `GFConfigDatabaseResource`，可以直接调用 `validate_database()`，它会复用 `GFConfigReferenceResolver.validate_tables()` 检查整包 schema、表数据和跨表引用。

```gdscript
var unique_index := GFConfigTableIndexDefinition.new()
unique_index.index_id = &"item_variant"
unique_index.field_names = PackedStringArray(["item_id", "variant"])
unique_index.unique = true
item_schema.indexes.append(unique_index)

var reference := GFConfigTableReference.new()
reference.source_fields = PackedStringArray(["item_id"])
reference.target_table_name = &"items"
reference.target_fields = PackedStringArray(["id"])
owner_schema.references.append(reference)

var report := GFConfigReferenceResolver.validate_tables({
	&"items": item_rows,
	&"owners": owner_rows,
}, [item_schema, owner_schema])

var table := GFConfigTableResource.new()
table.table_name = &"items"
table.schema = item_schema
table.records = item_rows
table.rebuild_indexes()

var key := table.make_index_key(&"item_variant", {
	"item_id": 1001,
	"variant": "normal",
})
var item := table.get_index_record(&"item_variant", key)
```

## 数组元素引用

当一个字段保存多个目标 ID 时，把 `source_mode` 设为 `SourceMode.ARRAY_ELEMENTS`。此模式要求 `source_fields` 恰好包含一个字段；`target_fields` 可以显式指定一个字段，也可以留空以使用目标 schema 的 `id_field`。它逐项校验一维 `Array`，每个元素匹配一个目标键。

下面的内存记录示例检查 `collections.catalog_ids` 中每个值是否存在于 `catalog.id`：

```gdscript
var catalog_rows: Array[Dictionary] = [{"id": 101}, {"id": 102}]
var collection_rows: Array[Dictionary] = [
	{"id": 7, "catalog_ids": [101, 102, 999]},
]
var catalog_schema: GFConfigTableSchema = GFConfigTableSchema.infer_from_records(
	&"catalog", catalog_rows
)
var collection_schema: GFConfigTableSchema = GFConfigTableSchema.infer_from_records(
	&"collections", collection_rows
)

var catalog_reference: GFConfigTableReference = GFConfigTableReference.new()
catalog_reference.source_mode = GFConfigTableReference.SourceMode.ARRAY_ELEMENTS
catalog_reference.source_fields = PackedStringArray(["catalog_ids"])
catalog_reference.target_table_name = &"catalog"
catalog_reference.required = true
catalog_reference.allow_null_values = false
# target_fields 留空，使用 catalog_schema.id_field。
collection_schema.references = [catalog_reference]

var schemas: Array[GFConfigTableSchema] = [catalog_schema, collection_schema]
var reference_report: Dictionary = GFConfigReferenceResolver.validate_tables({
	&"catalog": catalog_rows,
	&"collections": collection_rows,
}, schemas)
```

`999` 没有匹配目标，报告中的 issue 包含以下字段：

```json
{
  "kind": "missing_reference",
  "table_name": "collections",
  "row_key": 7,
  "field": "catalog_ids",
  "element_index": 2,
  "value": 999
}
```

`field` 始终是原字段名，`element_index` 从 `0` 开始；读取报告时无需拆解 `catalog_ids[2]` 这样的拼接字段名。重复值按各自位置检查，例如 `[999, 999]` 会分别报告位置 `0` 和 `1`。

下表以引用声明有效、目标表存在为前提；独立的 schema 校验仍然生效。

| 来源情况 | `required=true` | `required=false` |
| --- | --- | --- |
| 来源字段缺失 | `missing_reference_value` | 允许缺失 |
| 空 `Array` | 通过 | 通过 |
| 合法元素匹配目标键 | 通过 | 通过 |
| 合法元素没有匹配目标键 | `missing_reference`，包含元素位置和值 | 允许未匹配 |
| 来源不是 `Array`，包括整个字段为 `null` | `invalid_reference_value` | `invalid_reference_value` |
| 元素类型非法，或 `null` 元素被禁止 | `invalid_reference_element`，包含元素位置和值 | `invalid_reference_element`，包含元素位置和值 |

元素支持 `bool`、`int`、有限 `float`、`String` 和 `StringName`。引用匹配不转换类型，例如整数 `101`、浮点数 `101.0`、字符串 `"101"` 与 `StringName` 值 `&"101"` 是不同的键。嵌套数组、Dictionary、PackedArray、对象等值不属于元素支持范围；PackedArray 也不能作为来源容器。

`allow_null_values` 默认为 `true`，在数组模式下只控制元素能否为 `null`。这个元素仍作为键参与匹配：当 `required=true` 且目标不存在 `null` 键时，仍报 `missing_reference`；它不会跳过必需引用。设置为 `false` 时，`null` 元素报 `invalid_reference_element`。整个字段为 `null` 在两种设置下都不是合法数组。

`duplicate_reference()`、`describe()` 以及 Resource 保存与加载都会保留 `source_mode`。未显式指定 `reference_id` 时，数组模式生成的标识形如 `catalog_ids[]->catalog`，与字段模式分开。数组模式只提供引用校验，`make_source_key()` 返回空字符串，`resolve_record_references()` 跳过该模式；需要读取目标记录时，由项目使用已有表查询入口组织结果。
