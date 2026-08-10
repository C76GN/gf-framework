# JSON、CSV 与 ConfigFile 导入

## 解析入口

`GFConfigTableImporter` 提供轻量 JSON、CSV、Godot ConfigFile 文本和二维文本行解析、`validate_json_table()`、`validate_json_record()`、`validate_csv_table()`、`validate_config_file_table()` 和 `export_csv_table()` 入口，适合编辑器导入按钮、CI 检查或项目自定义导表流水线在写入缓存前做统一报告。

`validate_json_record()` 面向 manifest、单条工具配置或内容包元数据这类 Dictionary 根节点。它复用 `GFConfigTableSchema` 的字段声明，但不会把 JSON 根节点当成表格行集合；根节点不是 JSON object 时会返回带 `expected_value` 和 `supported_formats` 的失败报告。

这些直接入口接收已经驻留内存的 `String` / rows，不执行字节、行、列、单元格总数或嵌套深度预算。不要把未预检的网络、模组或其他不受信输入直接交给它们。制作期文件入口可先使用 Config Pipeline Reader 的 `max_source_file_bytes`（默认 64 MiB）限制读取；该文件预算仍不等于解析工作量预算，CSV / JSON / ConfigFile 的直接容量合同尚未确定。XLSX 另有 archive、entry、解压总量、行、列和单元格保护。

## 表格预处理

CSV 解析会去掉 UTF-8 BOM，默认拒绝重复表头，并在引号字段未闭合时返回带行列位置的 `unclosed_quote` 问题，而不是把后续整段文本静默吞进一个单元格。

`parse_rows_table()` 可把已经解析好的二维文本行转换为记录数组，CSV 入口也会复用这条路径。`comment_prefixes` 会同时作用于注释行和注释列，或用 `comment_row_prefixes` / `comment_column_prefixes` 分开配置；被过滤的列不会进入表头、记录和字段定位。需要按发布符号裁剪数据时，可以启用 `enable_condition_directives` 并传入 `condition_symbols`，当前只支持简单的 `#if SYMBOL ...` / `#endif` 块，所有符号都命中时才保留块内数据行。裸 `#if` 会以 `empty_condition_symbols` 在指令物理行 fail-closed，不提供隐式“无条件分组”语义。

```gdscript
var parsed := GFConfigTableImporter.parse_csv_table(text, {
	"comment_prefixes": PackedStringArray(["#", "Comment"]),
	"condition_symbols": PackedStringArray(["DLC_A"]),
})
```

## ConfigFile 映射

ConfigFile 解析会把每个 section 映射为一条记录，默认把 section 名写入 `entry_name` 字段。需要让 section 名参与 schema 的 ID 校验时，可以用 `section_field` 改成项目 schema 的 `id_field`。

```gdscript
var parsed := GFConfigTableImporter.parse_config_file_table(text, {
	"section_field": &"id",
	"source": "res://configs/items.cfg",
})
```

导出会按 schema 列顺序或显式 `columns` 输出，并对包含分隔符、换行或引号的单元格做 CSV 转义。

## 报告边界

传入 `{ "source": "res://..." }` 后，CSV 校验报告会尽量附带行列位置，ConfigFile 校验报告会保留来源路径和记录索引，JSON 解析失败会附带解析行号。字段类型、集合、范围、资源路径和文本 key 等规则会尽量写入 `value`、`expected_value`、`actual_value`、`supported_values` 或 `supported_formats`，方便编辑器工具直接渲染可操作诊断；当集合白名单过大时，会改用 `supported_values_count`、`supported_values_sample`、`supported_values_preview_hash` 和 `supported_values_truncated`。其中 preview hash 只描述经过报告预算限制的编码预览，不代表完整白名单的内容指纹。

它仍是轻量解析器，只取 `delimiter` 的第一个字符，空表头会跳过，条件表达式不解析布尔运算，ConfigFile 不反推源码行号，也不把“文本已能放入内存”视为已通过行数/单元格工作量验收；复杂 Excel、多 sheet、编码探测或不受信输入仍建议交给有明确容量边界的项目导表流水线。

校验报告固定包含 `ok`、`row_count`、`error_count`、`warning_count` 和 `issues`。

项目工具可以直接把 `issues` 渲染成表格或控制台输出；项目自定义导入工具或校验规则若需要创建同形状报告，可以复用 `GFConfigValidationReport`。`add_issue()` 会在 issue 创建时把 positional `row_key` 与受支持的 context 字段统一规范化为 JSON-safe 值；Object、非有限浮点数和 Godot 结构类型会变成带类型信息的稳定 marker，而不是保留活对象或等到 `JSON.stringify()` 时退化。
