# JSON 与 CSV 导入

`GFConfigTableImporter` 提供轻量 JSON/CSV 文本解析、`validate_json_table()`、`validate_json_record()`、`validate_csv_table()` 和 `export_csv_table()` 入口，适合编辑器导入按钮、CI 检查或项目自定义导表流水线在写入缓存前做统一报告。

`validate_json_record()` 面向 manifest、单条工具配置或内容包元数据这类 Dictionary 根节点。它复用 `GFConfigTableSchema` 的字段声明，但不会把 JSON 根节点当成表格行集合；根节点不是 JSON object 时会返回带 `expected_value` 和 `supported_formats` 的失败报告。

CSV 解析会去掉 UTF-8 BOM，默认拒绝重复表头，并在引号字段未闭合时返回带行列位置的 `unclosed_quote` 问题，而不是把后续整段文本静默吞进一个单元格。

导出会按 schema 列顺序或显式 `columns` 输出，并对包含分隔符、换行或引号的单元格做 CSV 转义。

传入 `{ "source": "res://..." }` 后，CSV 校验报告会尽量附带行列位置；JSON 解析失败会附带解析行号。字段类型、集合、范围、资源路径和文本 key 等规则会尽量写入 `value`、`expected_value`、`actual_value`、`supported_values` 或 `supported_formats`，方便编辑器工具直接渲染可操作诊断。

它仍是轻量解析器，只取 `delimiter` 的第一个字符，空表头会跳过，复杂 Excel、多 sheet 或编码探测仍建议交给项目导表流水线。

校验报告固定包含 `ok`、`row_count`、`error_count`、`warning_count` 和 `issues`。

项目工具可以直接把 `issues` 渲染成表格或控制台输出；项目自定义导入工具或校验规则若需要创建同形状报告，可以复用 `GFConfigValidationReport`。
