# Schema 声明

导表结构可以用 `GFConfigTableColumn` 和 `GFConfigTableSchema` 独立声明，再注册到 Provider 上做导入期或运行时校验。

它们描述字段类型、必填、空值、默认值、额外字段策略与校验规则，不规定项目业务字段。

```gdscript
var id_column := GFConfigTableColumn.new()
id_column.field_name = &"id"
id_column.value_type = GFConfigTableColumn.ValueType.INT
id_column.required = true
id_column.allow_null = false

var name_column := GFConfigTableColumn.new()
name_column.field_name = &"name"
name_column.value_type = GFConfigTableColumn.ValueType.STRING
name_column.required = true

var schema := GFConfigTableSchema.new()
schema.table_name = &"items"
schema.columns = [id_column, name_column]
schema.allow_extra_fields = false
schema.coerce_values = true
schema.fail_on_coerce_error = true
schema.require_unique_id = true

register_schema(schema)
var report := validate_table(&"items", get_table(&"items"))
```

字段校验、记录校验、表校验、JSON/CSV 导入报告见 [导入校验与规则](../validation-importer/index.md)。

## Schema 副本语义

`register_schema()` 会保存 schema 副本。`get_schema()` 也返回副本，整值规则与 `element_validation_rules` 都随列复制；调用方修改返回值不会污染 Provider 内部校验规则。

这能避免编辑器工具、CI 校验或项目调试代码在读取 schema 后意外改动运行时 Provider 的正式规则。
