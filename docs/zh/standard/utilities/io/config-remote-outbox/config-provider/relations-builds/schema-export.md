# Schema 推导与导出

已有样本数据但暂时没有 schema 时，可以用 `GFConfigTableSchema.infer_from_records()` 从 `Array[Dictionary]` 或 `Dictionary` 表推导字段和值类型，再由项目层人工校正必填、默认值、枚举或业务约束。

```gdscript
var inferred_schema := GFConfigTableSchema.infer_from_records(&"items", rows, {
	"required_if_present_in_all_rows": true,
})

var exported := GFConfigTableImporter.export_csv_table(rows, inferred_schema)
if exported["success"]:
	print(exported["text"])
```

Schema 推导只提供初始结构，不应替代项目的数据契约设计。导出工具只处理通用表结构，字段排序、发布管线和业务环境差异由项目层决定。

需要 Godot 原生资源工作流时，可以把导出结果写入 `GFConfigTableResource`；多张表可以再聚合到 `GFConfigDatabaseResource`，保存为 `.tres/.res` 后用 `GFResourceConfigProvider` 接入运行时查询。通用资源只承载记录、schema、`records_by_id`、`records_by_index`、表集合和 metadata；项目专属 Resource 类、业务字段映射和多端发布策略仍由项目导表工具决定。
