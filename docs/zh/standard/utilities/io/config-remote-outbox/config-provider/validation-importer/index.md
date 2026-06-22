# 导入校验与规则

配置表校验由 schema、字段规则、记录规则、表规则和导入器共同组成。它们输出稳定报告，方便编辑器、CI 和项目工具复用。

## 阅读入口

- [值转换与 Schema 自检](schema-self-check.md)：`coerce_values`、转换失败报告、旧式宽松导入、唯一 ID 检查和 `validate_definition()` 结构自检。
- [校验规则](validation-rules.md)：字段、记录、表规则和自定义规则。
- [JSON 与 CSV 导入](json-csv-import.md)：文本解析、单记录/表格导入校验、CSV 导出和报告结构。
- [Config Pipeline 导表工具包](../../../../../../editor/tools/config-pipeline.md)：可选工具包把 CSV / JSON / XLSX 来源或批量 Profile 构建为 `GFConfigTableResource` / `GFConfigDatabaseResource`，并提供 Profile 路径 Runner 保存 `.tres/.res`。

## 使用边界

这些能力只表达通用导入约束、报告结构和运行时配置资源边界。导表工具包属于制作期能力；具体枚举、资源分类、语言表来源、复杂 Excel、多 sheet、完整 JSON Schema 标准或编码探测仍由项目导表流水线负责。
