# JSON、CSV 与 ConfigFile 导入

## 解析入口

`GFConfigTableImporter` 提供轻量 JSON、CSV、Godot ConfigFile 文本和二维文本行解析、`validate_json_table()`、`validate_json_record()`、`validate_csv_table()`、`validate_config_file_table()` 和 `export_csv_table()` 入口，适合编辑器导入按钮、CI 检查或项目自定义导表流水线在写入缓存前做统一报告。

`validate_json_record()` 面向 manifest、单条工具配置或内容包元数据这类 Dictionary 根节点。它复用 `GFConfigTableSchema` 的字段声明，但不会把 JSON 根节点当成表格行集合；根节点不是 JSON object 时会返回带 `expected_value` 和 `supported_formats` 的失败报告。

这些直接入口接收已经驻留内存的 `String` / rows，每次调用默认创建有限的 `GFConfigWorkBudget`。文本在解析前检查输入 UTF-8 字节，数据图在复制前检查深度、循环及累计工作量；CSV 导出另外限制转义后的 UTF-8 输出。输入字符串在调用前已经占用的内存不属于这里的分配保证。制作期文件入口还应使用 Config Pipeline Reader 的文件读取预算；XLSX 保留独立的 archive、entry、解压总量、行、列和单元格保护。

## 工作预算与批次

`work_limits` 可以覆盖下列有限默认值。所有值必须为正整数，未知字段、错误类型、零和负数直接失败；`max_depth` 不能大于 256。

| 字段 | 默认值 | 计量对象 |
| --- | --- | --- |
| `max_input_bytes` | 64 MiB | 累计原始文本 UTF-8 字节；直接 rows 入口按单元格 UTF-8 载荷计量 |
| `max_depth` | 64 | 数据图嵌套深度，根值为 0 |
| `max_work_units` | 1,000,000 | 容器、键、值、Packed 元素访问及入口显式扫描工作；PackedByteArray 每 1024 字节计一个块，向上取整；同一数据再次准入会再次计量 |
| `max_value_bytes` | 256 MiB | 每次准入所访问 String、StringName、NodePath 的 UTF-8 字节与 Packed 数组的保守载荷字节；NodePath 包含路径及属性分隔符 |
| `max_output_bytes` | 64 MiB | CSV 导出累计生成文本的实际 UTF-8 字节；纯解析和数据图合并不消费此额度 |

独立调用互不影响。需要多个导入或合并入口共享累计额度时，显式创建句柄并传入 `work_budget`；它与 `work_limits` 互斥。句柄不能重置，首次失败后继续使用仍然失败，新批次应创建新句柄。入口内部的解析、记录转换和校验沿用同一个句柄，不在子阶段重新获得额度。

```gdscript
var budget := GFConfigWorkBudget.new({ "max_input_bytes": 1024 * 1024 })
var first := GFConfigTableImporter.parse_json_table(first_text, {
	"work_budget": budget,
})
if first["success"]:
	var second := GFConfigTableImporter.parse_json_table(second_text, {
		"work_budget": budget,
	})
	if second["success"]:
		print(budget.get_report())
```

预算失败保留稳定错误分类与 `budget_report`，解析结果同时保留本次调用的 `source`，不截断数据后报告成功，也不返回可用的部分导入或导出结果。`get_report()` 返回副本，包含限额、使用量、首次错误和位置，不能通过修改报告恢复额度。

这些预算限制可计量的数据与协作式执行，不是硬实时超时或进程内存隔离。原生 JSON / ConfigFile 解析不能被外层计时器中断；自定义规则执行时间也由规则实现负责。原生值保持类型语义，Resource 只作为叶引用准入，不递归其属性；其他 Object、Callable、Signal、RID 和容器循环会被拒绝。

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
