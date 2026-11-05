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

启用 `coerce_values` 时，CSV 导出使用报告型字段转换并共享本次操作的工作预算。结构化字段转换失败会返回 `success=false`、空 `text`、`error_kind=record_conversion_failed`、从零计数的 `row_index` 和保留字段诊断的 `validation_report`，不会把失败记录导出成成功空行，也不会返回此前已构建的部分文本。

需要 Godot 原生资源工作流时，可以把导出结果写入 `GFConfigTableResource`；多张表可以再聚合到 `GFConfigDatabaseResource`，保存为 `.tres/.res` 后用 `GFResourceConfigProvider` 接入运行时查询。通用资源只承载记录、schema、`records_by_id`、`records_by_index`、表集合和 metadata；项目专属 Resource 类、业务字段映射和多端发布策略仍由项目导表工具决定。
