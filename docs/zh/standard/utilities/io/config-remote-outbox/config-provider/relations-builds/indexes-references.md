# 索引与跨表引用

## 索引声明

需要表达唯一键或跨表关系时，可以在 `GFConfigTableSchema.indexes` 中加入 `GFConfigTableIndexDefinition`，在 `references` 中加入 `GFConfigTableReference`。唯一索引会参与单表校验；跨表引用由 `GFConfigReferenceResolver.validate_tables()` 在多表上下文中检查。

## 运行时查询

如果表数据保存为 `GFConfigTableResource`，`schema.indexes` 还可以作为运行时命名索引来源。调用 `rebuild_indexes()` 会把索引缓存写入 `records_by_index`，适合随 `.tres/.res` 一起保存；缓存为空时，`get_index_record()` 和 `get_index_records()` 会按 schema 临时构建查询结果。

## 跨表引用

`resolve_record_references()` 可把一条记录的引用解析为目标记录副本。GF 只理解字段、复合键和报告结构，不解释外键背后的业务含义。

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
