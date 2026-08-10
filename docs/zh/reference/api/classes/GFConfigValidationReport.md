# GFConfigValidationReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_validation_report.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

配置表校验报告构建工具。 统一创建、合并和补全配置表校验报告，保证 schema、导入器、引用解析和补丁合并使用相同问题结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`CONTEXT_FIELDS`](#member-gfconfigvalidationreport-constants-context_fields) | `const CONTEXT_FIELDS: Array[String] = [ 	"row_key", 	"field", 	"source", 	"line", 	"column", 	"row_index", 	"column_index", 	"rule_id", 	"value", 	"expected_value", 	"actual_value", 	"supported_values", 	"supported_values_count", 	"supported_values_sample", 	"supported_values_preview_hash", 	"supported_values_truncated", 	"supported_formats", 	"supported_content_types", ]` |
| 方法 | [`make_report`](#member-gfconfigvalidationreport-methods-make_report) | `func make_report(table_name: StringName = &"", row_count: int = 0) -> Dictionary:` |
| 方法 | [`make_error_report`](#member-gfconfigvalidationreport-methods-make_error_report) | `func make_error_report( table_name: StringName, kind: String, message: String, context: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_issue`](#member-gfconfigvalidationreport-methods-add_issue) | `func add_issue( report: Dictionary, severity: String, kind: String, table_name: StringName, row_key: Variant, field_name: StringName, message: String, context: Dictionary = {} ) -> void:` |
| 方法 | [`merge_report`](#member-gfconfigvalidationreport-methods-merge_report) | `func merge_report(target: Dictionary, source: Dictionary, include_row_count: bool = false) -> void:` |
| 方法 | [`finalize_report`](#member-gfconfigvalidationreport-methods-finalize_report) | `func finalize_report(report: Dictionary) -> void:` |

## 常量

<a id="member-gfconfigvalidationreport-constants-context_fields"></a>

### `CONTEXT_FIELDS`

- API：`public`

```gdscript
const CONTEXT_FIELDS: Array[String] = [
	"row_key",
	"field",
	"source",
	"line",
	"column",
	"row_index",
	"column_index",
	"rule_id",
	"value",
	"expected_value",
	"actual_value",
	"supported_values",
	"supported_values_count",
	"supported_values_sample",
	"supported_values_preview_hash",
	"supported_values_truncated",
	"supported_formats",
	"supported_content_types",
]
```

从校验上下文复制到单条 issue 的字段名。

## 方法

<a id="member-gfconfigvalidationreport-methods-make_report"></a>

### `make_report`

- API：`public`

```gdscript
func make_report(table_name: StringName = &"", row_count: int = 0) -> Dictionary:
```

创建空校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `row_count` | 记录数量。 |

返回：校验报告字典。

结构：

- `return`: GFConfigValidationReport 兼容 Dictionary，包含 ok、table_name、row_count、error_count、warning_count 和 issues。

<a id="member-gfconfigvalidationreport-methods-make_error_report"></a>

### `make_error_report`

- API：`public`

```gdscript
func make_error_report( table_name: StringName, kind: String, message: String, context: Dictionary = {} ) -> Dictionary:
```

创建单错误校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `kind` | 稳定问题类型。 |
| `message` | 问题描述。 |
| `context` | 可选上下文。 |

返回：校验报告字典。

结构：

- `context`: Dictionary，可包含 row_key、field、source、line、column、row_index、column_index、rule_id、value、expected_value、actual_value、supported_values、supported_formats 和 supported_content_types 字段。
- `return`: GFConfigValidationReport 兼容 Dictionary，包含一条 error issue。

<a id="member-gfconfigvalidationreport-methods-add_issue"></a>

### `add_issue`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func add_issue( report: Dictionary, severity: String, kind: String, table_name: StringName, row_key: Variant, field_name: StringName, message: String, context: Dictionary = {} ) -> void:
```

向报告写入一条问题。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 目标校验报告。 |
| `severity` | severity 字符串，支持 error 或 warning。 |
| `kind` | 稳定问题类型。 |
| `table_name` | 表名。 |
| `row_key` | 行标识。 |
| `field_name` | 字段名。 |
| `message` | 问题描述。 |
| `context` | 可选上下文。 |

结构：

- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前方法修改。
- `row_key`: Variant，经报告 codec 规范化为 JSON-safe 值后复制到 issue 中的行标识。
- `context`: Dictionary，可包含 row_key、field、source、line、column、row_index、column_index、rule_id、value、expected_value、actual_value、supported_values、supported_formats 和 supported_content_types 字段。

<a id="member-gfconfigvalidationreport-methods-merge_report"></a>

### `merge_report`

- API：`public`

```gdscript
func merge_report(target: Dictionary, source: Dictionary, include_row_count: bool = false) -> void:
```

合并一份校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标报告。 |
| `source` | 来源报告。 |
| `include_row_count` | 为 true 时累加 row_count。 |

结构：

- `target`: GFConfigValidationReport 兼容 Dictionary，会被当前方法修改。
- `source`: GFConfigValidationReport 兼容 Dictionary，会复制合并到 target。

<a id="member-gfconfigvalidationreport-methods-finalize_report"></a>

### `finalize_report`

- API：`public`

```gdscript
func finalize_report(report: Dictionary) -> void:
```

根据 error_count 补全 ok 字段。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 校验报告。 |

结构：

- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前方法修改。
