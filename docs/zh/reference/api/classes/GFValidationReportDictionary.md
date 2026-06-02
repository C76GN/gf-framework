# GFValidationReportDictionary

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用校验报告字典辅助。 提供字典报告的追加、归一化、统计和严重级别提升工具，便于字典式报告 接入 `GFValidationIssue` / `GFValidationReport` 使用的标准字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`issue_to_dict`](#member-gfvalidationreportdictionary-methods-issue_to_dict) | `static func issue_to_dict(issue: Variant, include_empty_fields: bool = false) -> Dictionary:` |
| 方法 | [`report_from_dict`](#member-gfvalidationreportdictionary-methods-report_from_dict) | `static func report_from_dict(data: Dictionary) -> RefCounted:` |
| 方法 | [`append_issue`](#member-gfvalidationreportdictionary-methods-append_issue) | `static func append_issue( report: Dictionary, severity: Variant, kind: StringName, message: String, fields: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`append_source_issue`](#member-gfvalidationreportdictionary-methods-append_source_issue) | `static func append_source_issue( report: Dictionary, severity: Variant, kind: StringName, message: String, source_span: Variant, fields: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`finalize_report`](#member-gfvalidationreportdictionary-methods-finalize_report) | `static func finalize_report( report: Dictionary, subject: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_summary`](#member-gfvalidationreportdictionary-methods-make_summary) | `static func make_summary(subject: String, error_count: int, warning_count: int) -> String:` |
| 方法 | [`get_next_action`](#member-gfvalidationreportdictionary-methods-get_next_action) | `static func get_next_action( report: Dictionary, action_map: Dictionary = {}, fallback_action: String = "Review the first reported issue.", no_action: String = "No action required.", options: Dictionary = {} ) -> String:` |
| 方法 | [`has_error_issues`](#member-gfvalidationreportdictionary-methods-has_error_issues) | `static func has_error_issues(report: Dictionary, options: Dictionary = {}) -> bool:` |
| 方法 | [`make_issue_fingerprint`](#member-gfvalidationreportdictionary-methods-make_issue_fingerprint) | `static func make_issue_fingerprint(issue: Variant, fields: PackedStringArray = PackedStringArray()) -> String:` |
| 方法 | [`filter_issues`](#member-gfvalidationreportdictionary-methods-filter_issues) | `static func filter_issues(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`promote_warnings`](#member-gfvalidationreportdictionary-methods-promote_warnings) | `static func promote_warnings(report: Dictionary, kinds: PackedStringArray = PackedStringArray()) -> Dictionary:` |

## 方法

<a id="member-gfvalidationreportdictionary-methods-issue_to_dict"></a>

### `issue_to_dict`

- API：`public`

```gdscript
static func issue_to_dict(issue: Variant, include_empty_fields: bool = false) -> Dictionary:
```

将任意问题转换为字典。

参数：

| 名称 | 说明 |
|---|---|
| `issue` | GFValidationIssue 或问题字典。 |
| `include_empty_fields` | 为 true 时包含空的可选字段。 |

返回：问题字典。

结构：

- `issue`: Variant accepting GFValidationIssue or Dictionary issue payload.
- `return`: Dictionary serialized issue payload.

<a id="member-gfvalidationreportdictionary-methods-report_from_dict"></a>

### `report_from_dict`

- API：`public`

```gdscript
static func report_from_dict(data: Dictionary) -> RefCounted:
```

将报告字典转换为 GFValidationReport。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

返回：新报告。

结构：

- `data`: Dictionary report payload.

<a id="member-gfvalidationreportdictionary-methods-append_issue"></a>

### `append_issue`

- API：`public`

```gdscript
static func append_issue( report: Dictionary, severity: Variant, kind: StringName, message: String, fields: Dictionary = {} ) -> Dictionary:
```

向字典报告追加问题。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 目标报告字典。 |
| `severity` | 严重级别，可传入 Severity、int 或字符串。 |
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `fields` | 附加字段，例如 key、path、row_key、metadata。 |

返回：追加的问题字典。

结构：

- `report`: Dictionary report payload mutated in place.
- `severity`: Variant accepting GFValidationIssue.Severity, int, String, or StringName.
- `fields`: Dictionary additional issue fields.
- `return`: Dictionary appended issue payload.

<a id="member-gfvalidationreportdictionary-methods-append_source_issue"></a>

### `append_source_issue`

- API：`public`

```gdscript
static func append_source_issue( report: Dictionary, severity: Variant, kind: StringName, message: String, source_span: Variant, fields: Dictionary = {} ) -> Dictionary:
```

向字典报告追加带源码定位的问题。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 目标报告字典。 |
| `severity` | 严重级别，可传入 Severity、int 或字符串。 |
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `source_span` | GFSourceSpan 或兼容字典。 |
| `fields` | 附加字段，例如 key、path、row_key、metadata。 |

返回：追加的问题字典。

结构：

- `report`: Dictionary report payload mutated in place.
- `severity`: Variant accepting GFValidationIssue.Severity, int, String, or StringName.
- `source_span`: Variant accepting GFSourceSpan or Dictionary span payload.
- `fields`: Dictionary additional issue fields.
- `return`: Dictionary appended issue payload.

<a id="member-gfvalidationreportdictionary-methods-finalize_report"></a>

### `finalize_report`

- API：`public`

```gdscript
static func finalize_report( report: Dictionary, subject: String = "", options: Dictionary = {} ) -> Dictionary:
```

重新计算字典报告的统计字段。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 目标报告字典。 |
| `subject` | 摘要主题；为空时使用 report.subject 或 Validation report。 |
| `options` | 可选控制，支持 next_actions、fallback_action、no_action、include_info_count、warnings_as_errors、promote_warning_kinds。 |

返回：同一个报告字典。

结构：

- `report`: Dictionary report payload mutated in place.
- `options`: Dictionary controlling report finalization.
- `return`: Dictionary finalized report payload.

<a id="member-gfvalidationreportdictionary-methods-make_summary"></a>

### `make_summary`

- API：`public`

```gdscript
static func make_summary(subject: String, error_count: int, warning_count: int) -> String:
```

生成摘要文本。

参数：

| 名称 | 说明 |
|---|---|
| `subject` | 摘要主题。 |
| `error_count` | 错误数量。 |
| `warning_count` | 警告数量。 |

返回：摘要文本。

<a id="member-gfvalidationreportdictionary-methods-get_next_action"></a>

### `get_next_action`

- API：`public`

```gdscript
static func get_next_action( report: Dictionary, action_map: Dictionary = {}, fallback_action: String = "Review the first reported issue.", no_action: String = "No action required.", options: Dictionary = {} ) -> String:
```

获取报告下一步建议。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `action_map` | 按问题类别映射的建议文本。 |
| `fallback_action` | 存在问题但未命中映射时返回的建议。 |
| `no_action` | 没有问题时返回的建议。 |
| `options` | 严重级别计算选项。 |

返回：建议文本。

结构：

- `report`: Dictionary report payload.
- `action_map`: Dictionary keyed by issue kind with action text values.
- `options`: Dictionary severity evaluation options.

<a id="member-gfvalidationreportdictionary-methods-has_error_issues"></a>

### `has_error_issues`

- API：`public`

```gdscript
static func has_error_issues(report: Dictionary, options: Dictionary = {}) -> bool:
```

检查报告是否包含错误。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `options` | 严重级别计算选项。 |

返回：存在错误时返回 true。

结构：

- `report`: Dictionary report payload.
- `options`: Dictionary severity evaluation options.

<a id="member-gfvalidationreportdictionary-methods-make_issue_fingerprint"></a>

### `make_issue_fingerprint`

- API：`public`

```gdscript
static func make_issue_fingerprint(issue: Variant, fields: PackedStringArray = PackedStringArray()) -> String:
```

生成稳定的问题指纹，用于项目工具的忽略项、基线和 CI 差异比较。

参数：

| 名称 | 说明 |
|---|---|
| `issue` | GFValidationIssue 或兼容问题字典。 |
| `fields` | 参与指纹计算的字段；为空时使用 severity、kind、path、source_path、key 和 message。 |

返回：问题指纹；输入无效时返回空字符串。

结构：

- `issue`: Variant accepting GFValidationIssue or Dictionary issue payload.

<a id="member-gfvalidationreportdictionary-methods-filter_issues"></a>

### `filter_issues`

- API：`public`

```gdscript
static func filter_issues(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

返回应用忽略项和基线后的报告副本。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 输入报告字典，不会被修改。 |
| `options` | 可选过滤设置，支持 ignored_kinds、ignored_paths、ignored_path_patterns、ignored_keys、ignored_fingerprints、baseline_fingerprints、baseline_issues、fingerprint_fields、include_filter_summary。 |

返回：过滤并重新 finalize 的报告副本。

结构：

- `report`: Dictionary report payload.
- `options`: Dictionary issue filtering options.
- `return`: Dictionary finalized report payload.

<a id="member-gfvalidationreportdictionary-methods-promote_warnings"></a>

### `promote_warnings`

- API：`public`

```gdscript
static func promote_warnings(report: Dictionary, kinds: PackedStringArray = PackedStringArray()) -> Dictionary:
```

将报告中的警告提升为错误。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `kinds` | 为空时提升全部警告；否则只提升匹配类别。 |

返回：同一个报告字典。

结构：

- `report`: Dictionary report payload mutated in place.
- `return`: Dictionary report payload mutated in place.
