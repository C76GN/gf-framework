# GFValidationDiagnosticAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_diagnostic_adapter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

校验报告到编辑器诊断数据的适配器。 只把 `GFValidationIssue`、`GFValidationReport` 或兼容字典转换成纯 Dictionary 诊断记录，不创建 UI，也不假设具体编辑器控件，便于 Inspector、Dock、CI 和项目工具复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`issue_to_diagnostic`](#member-gfvalidationdiagnosticadapter-methods-issue_to_diagnostic) | `static func issue_to_diagnostic(issue: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`report_to_diagnostics`](#member-gfvalidationdiagnosticadapter-methods-report_to_diagnostics) | `static func report_to_diagnostics(source: Variant, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`group_by_source`](#member-gfvalidationdiagnosticadapter-methods-group_by_source) | `static func group_by_source(diagnostics: Array[Dictionary]) -> Dictionary:` |
| 方法 | [`make_line_records`](#member-gfvalidationdiagnosticadapter-methods-make_line_records) | `static func make_line_records(diagnostics: Array[Dictionary], options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`make_display_text`](#member-gfvalidationdiagnosticadapter-methods-make_display_text) | `static func make_display_text(diagnostic: Dictionary) -> String:` |
| 方法 | [`make_tooltip`](#member-gfvalidationdiagnosticadapter-methods-make_tooltip) | `static func make_tooltip(diagnostic: Dictionary) -> String:` |

## 方法

<a id="member-gfvalidationdiagnosticadapter-methods-issue_to_diagnostic"></a>

### `issue_to_diagnostic`

- API：`public`

```gdscript
static func issue_to_diagnostic(issue: Variant, options: Dictionary = {}) -> Dictionary:
```

将单个问题转换成诊断字典。

参数：

| 名称 | 说明 |
|---|---|
| `issue` | GFValidationIssue 或兼容问题字典。 |
| `options` | 可选参数，支持 use_path_as_source、include_empty_source_span。 |

返回：诊断字典；输入无效时返回空字典。

结构：

- `issue`: Variant accepting GFValidationIssue or Dictionary issue payload.
- `options`: Dictionary diagnostic conversion options.
- `return`: Dictionary editor diagnostic record.

<a id="member-gfvalidationdiagnosticadapter-methods-report_to_diagnostics"></a>

### `report_to_diagnostics`

- API：`public`

```gdscript
static func report_to_diagnostics(source: Variant, options: Dictionary = {}) -> Array[Dictionary]:
```

将报告、报告字典或问题数组转换成诊断数组。

参数：

| 名称 | 说明 |
|---|---|
| `source` | GFValidationReport、报告字典或问题数组。 |
| `options` | 可选参数，支持 source_path、include_positionless、use_path_as_source。 |

返回：诊断数组。

结构：

- `source`: Variant accepting GFValidationReport, Dictionary report payload, or Array issues.
- `options`: Dictionary diagnostic conversion options.
- `return`: Array of Dictionary editor diagnostic records.

<a id="member-gfvalidationdiagnosticadapter-methods-group_by_source"></a>

### `group_by_source`

- API：`public`

```gdscript
static func group_by_source(diagnostics: Array[Dictionary]) -> Dictionary:
```

按源路径分组诊断。

参数：

| 名称 | 说明 |
|---|---|
| `diagnostics` | 诊断数组。 |

返回：source_path -> Array[Dictionary]。

结构：

- `diagnostics`: Array of Dictionary editor diagnostic records.
- `return`: Dictionary keyed by source_path with diagnostic arrays.

<a id="member-gfvalidationdiagnosticadapter-methods-make_line_records"></a>

### `make_line_records`

- API：`public`

```gdscript
static func make_line_records(diagnostics: Array[Dictionary], options: Dictionary = {}) -> Array[Dictionary]:
```

生成适合行号栏、问题列表或资源面板消费的行记录。

参数：

| 名称 | 说明 |
|---|---|
| `diagnostics` | 诊断数组。 |
| `options` | 可选参数，支持 include_positionless。 |

返回：行记录数组。

结构：

- `diagnostics`: Array of Dictionary editor diagnostic records.
- `options`: Dictionary line record conversion options.
- `return`: Array of Dictionary line records.

<a id="member-gfvalidationdiagnosticadapter-methods-make_display_text"></a>

### `make_display_text`

- API：`public`

```gdscript
static func make_display_text(diagnostic: Dictionary) -> String:
```

生成单条诊断的简短显示文本。

参数：

| 名称 | 说明 |
|---|---|
| `diagnostic` | 诊断字典。 |

返回：显示文本。

结构：

- `diagnostic`: Dictionary editor diagnostic record.

<a id="member-gfvalidationdiagnosticadapter-methods-make_tooltip"></a>

### `make_tooltip`

- API：`public`

```gdscript
static func make_tooltip(diagnostic: Dictionary) -> String:
```

生成单条诊断的工具提示文本。

参数：

| 名称 | 说明 |
|---|---|
| `diagnostic` | 诊断字典。 |

返回：工具提示文本。

结构：

- `diagnostic`: Dictionary editor diagnostic record.
