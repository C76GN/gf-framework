# GFValidationReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_report.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用校验报告数据结构。 用于聚合 `GFValidationIssue`，提供错误/警告统计、健康状态、摘要、下一步建议 和字典序列化。报告不绑定具体配置、存档、节点或编辑器业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`subject`](#member-gfvalidationreport-properties-subject) | `var subject: String = ""` |
| 属性 | [`issues`](#member-gfvalidationreport-properties-issues) | `var issues: Array[RefCounted] = []` |
| 属性 | [`metadata`](#member-gfvalidationreport-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`extra_fields`](#member-gfvalidationreport-properties-extra_fields) | `var extra_fields: Dictionary = {}` |
| 方法 | [`configure`](#member-gfvalidationreport-methods-configure) | `func configure(p_subject: String = "", p_metadata: Dictionary = {}) -> RefCounted:` |
| 方法 | [`clear`](#member-gfvalidationreport-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_issue`](#member-gfvalidationreport-methods-add_issue) | `func add_issue(issue: Variant) -> RefCounted:` |
| 方法 | [`add_info`](#member-gfvalidationreport-methods-add_info) | `func add_info( kind: StringName, message: String, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`add_warning`](#member-gfvalidationreport-methods-add_warning) | `func add_warning( kind: StringName, message: String, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`add_error`](#member-gfvalidationreport-methods-add_error) | `func add_error( kind: StringName, message: String, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`add_source_issue`](#member-gfvalidationreport-methods-add_source_issue) | `func add_source_issue( severity: Variant, kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`add_source_info`](#member-gfvalidationreport-methods-add_source_info) | `func add_source_info( kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`add_source_warning`](#member-gfvalidationreport-methods-add_source_warning) | `func add_source_warning( kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`add_source_error`](#member-gfvalidationreport-methods-add_source_error) | `func add_source_error( kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`merge`](#member-gfvalidationreport-methods-merge) | `func merge(source: Variant, include_metadata: bool = true) -> RefCounted:` |
| 方法 | [`apply_dict`](#member-gfvalidationreport-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`to_dict`](#member-gfvalidationreport-methods-to_dict) | `func to_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`to_json_compatible_dict`](#member-gfvalidationreport-methods-to_json_compatible_dict) | `func to_json_compatible_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_report`](#member-gfvalidationreport-methods-duplicate_report) | `func duplicate_report() -> RefCounted:` |
| 方法 | [`get_error_count`](#member-gfvalidationreport-methods-get_error_count) | `func get_error_count() -> int:` |
| 方法 | [`get_warning_count`](#member-gfvalidationreport-methods-get_warning_count) | `func get_warning_count() -> int:` |
| 方法 | [`get_info_count`](#member-gfvalidationreport-methods-get_info_count) | `func get_info_count() -> int:` |
| 方法 | [`is_ok`](#member-gfvalidationreport-methods-is_ok) | `func is_ok() -> bool:` |
| 方法 | [`is_healthy`](#member-gfvalidationreport-methods-is_healthy) | `func is_healthy() -> bool:` |
| 方法 | [`get_issue_counts_by_kind`](#member-gfvalidationreport-methods-get_issue_counts_by_kind) | `func get_issue_counts_by_kind() -> Dictionary:` |
| 方法 | [`make_summary`](#member-gfvalidationreport-methods-make_summary) | `func make_summary(subject_override: String = "") -> String:` |
| 方法 | [`get_next_action`](#member-gfvalidationreport-methods-get_next_action) | `func get_next_action( action_map: Dictionary = {}, fallback_action: String = "Review the first reported issue.", no_action: String = "No action required." ) -> String:` |
| 方法 | [`promote_warnings_to_errors`](#member-gfvalidationreport-methods-promote_warnings_to_errors) | `func promote_warnings_to_errors(kinds: PackedStringArray = PackedStringArray()) -> RefCounted:` |
| 方法 | [`from_dict`](#member-gfvalidationreport-methods-from_dict) | `static func from_dict(data: Dictionary) -> RefCounted:` |

## 属性

<a id="member-gfvalidationreport-properties-subject"></a>

### `subject`

- API：`public`

```gdscript
var subject: String = ""
```

报告主题，例如资源名、模块名或调用方自定义域。

<a id="member-gfvalidationreport-properties-issues"></a>

### `issues`

- API：`public`

```gdscript
var issues: Array[RefCounted] = []
```

问题列表。

<a id="member-gfvalidationreport-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary of caller-defined report metadata.

<a id="member-gfvalidationreport-properties-extra_fields"></a>

### `extra_fields`

- API：`public`

```gdscript
var extra_fields: Dictionary = {}
```

额外报告字段。用于保留或附加调用方自己的统计数据。

结构：

- `extra_fields`: Dictionary of caller-defined serialized report fields.

## 方法

<a id="member-gfvalidationreport-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(p_subject: String = "", p_metadata: Dictionary = {}) -> RefCounted:
```

配置报告主题和元数据。

参数：

| 名称 | 说明 |
|---|---|
| `p_subject` | 报告主题。 |
| `p_metadata` | 可选元数据。 |

返回：当前报告。

结构：

- `p_metadata`: Dictionary of caller-defined report metadata.

<a id="member-gfvalidationreport-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空问题与额外字段。

<a id="member-gfvalidationreport-methods-add_issue"></a>

### `add_issue`

- API：`public`

```gdscript
func add_issue(issue: Variant) -> RefCounted:
```

添加一个问题。

参数：

| 名称 | 说明 |
|---|---|
| `issue` | GFValidationIssue 或问题字典。 |

返回：添加后的问题；输入无效时返回 null。

结构：

- `issue`: Variant accepting GFValidationIssue or Dictionary issue payload.

<a id="member-gfvalidationreport-methods-add_info"></a>

### `add_info`

- API：`public`

```gdscript
func add_info( kind: StringName, message: String, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加信息问题。

参数：

| 名称 | 说明 |
|---|---|
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-add_warning"></a>

### `add_warning`

- API：`public`

```gdscript
func add_warning( kind: StringName, message: String, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加警告问题。

参数：

| 名称 | 说明 |
|---|---|
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-add_error"></a>

### `add_error`

- API：`public`

```gdscript
func add_error( kind: StringName, message: String, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加错误问题。

参数：

| 名称 | 说明 |
|---|---|
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-add_source_issue"></a>

### `add_source_issue`

- API：`public`

```gdscript
func add_source_issue( severity: Variant, kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加带源码定位的问题。

参数：

| 名称 | 说明 |
|---|---|
| `severity` | 严重级别，可传入 Severity、int 或字符串。 |
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `source_span` | GFSourceSpan 或兼容字典。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `severity`: Variant accepting GFValidationIssue.Severity, int, String, or StringName.
- `source_span`: Variant accepting GFSourceSpan or Dictionary span payload.
- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-add_source_info"></a>

### `add_source_info`

- API：`public`

```gdscript
func add_source_info( kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加带源码定位的信息问题。

参数：

| 名称 | 说明 |
|---|---|
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `source_span` | GFSourceSpan 或兼容字典。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `source_span`: Variant accepting GFSourceSpan or Dictionary span payload.
- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-add_source_warning"></a>

### `add_source_warning`

- API：`public`

```gdscript
func add_source_warning( kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加带源码定位的警告问题。

参数：

| 名称 | 说明 |
|---|---|
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `source_span` | GFSourceSpan 或兼容字典。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `source_span`: Variant accepting GFSourceSpan or Dictionary span payload.
- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-add_source_error"></a>

### `add_source_error`

- API：`public`

```gdscript
func add_source_error( kind: StringName, message: String, source_span: Variant, key: Variant = null, path: String = "", issue_metadata: Dictionary = {} ) -> RefCounted:
```

添加带源码定位的错误问题。

参数：

| 名称 | 说明 |
|---|---|
| `kind` | 问题类别。 |
| `message` | 问题说明。 |
| `source_span` | GFSourceSpan 或兼容字典。 |
| `key` | 可选定位键。 |
| `path` | 可选路径。 |
| `issue_metadata` | 可选元数据。 |

返回：新问题。

结构：

- `source_span`: Variant accepting GFSourceSpan or Dictionary span payload.
- `key`: Variant caller-defined location key.
- `issue_metadata`: Dictionary of caller-defined issue metadata.

<a id="member-gfvalidationreport-methods-merge"></a>

### `merge`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func merge(source: Variant, include_metadata: bool = true) -> RefCounted:
```

合并另一个报告或报告字典。与自身合并，或来源与目标共享同一个 issues Array 时， issues 合并视为幂等空操作；其他 metadata 仍按来源类型的正常规则处理。

参数：

| 名称 | 说明 |
|---|---|
| `source` | GFValidationReport 或包含 issues 的字典。 |
| `include_metadata` | 为 true 时合并源报告 metadata。 |

返回：当前报告。

结构：

- `source`: Variant accepting GFValidationReport or Dictionary report payload.

<a id="member-gfvalidationreport-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用报告字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

结构：

- `data`: Dictionary report payload.

<a id="member-gfvalidationreport-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
```

转换为报告字典。

参数：

| 名称 | 说明 |
|---|---|
| `additional_fields` | 附加到输出中的调用方字段。 |
| `options` | 可选输出控制，支持 include_subject、include_metadata、include_info_count、include_issue_count、include_empty_issue_fields、summary_subject、next_actions、fallback_action、no_action。 |

返回：报告字典。

结构：

- `additional_fields`: Dictionary of caller-defined serialized fields.
- `options`: Dictionary controlling report serialization options.
- `return`: Dictionary serialized report payload.

<a id="member-gfvalidationreport-methods-to_json_compatible_dict"></a>

### `to_json_compatible_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_json_compatible_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
```

转换为 JSON-safe 报告字典。

参数：

| 名称 | 说明 |
|---|---|
| `additional_fields` | 附加到输出中的调用方字段。 |
| `options` | 传给 to_dict() 的输出控制。 |

返回：JSON-safe 报告字典。

结构：

- `additional_fields`: Dictionary of caller-defined serialized fields.
- `options`: Dictionary controlling report serialization options.
- `return`: Dictionary serialized report payload made safe for JSON.stringify().

<a id="member-gfvalidationreport-methods-duplicate_report"></a>

### `duplicate_report`

- API：`public`

```gdscript
func duplicate_report() -> RefCounted:
```

创建当前报告深拷贝。

返回：新报告。

<a id="member-gfvalidationreport-methods-get_error_count"></a>

### `get_error_count`

- API：`public`

```gdscript
func get_error_count() -> int:
```

获取错误数量。

返回：错误数量。

<a id="member-gfvalidationreport-methods-get_warning_count"></a>

### `get_warning_count`

- API：`public`

```gdscript
func get_warning_count() -> int:
```

获取警告数量。

返回：警告数量。

<a id="member-gfvalidationreport-methods-get_info_count"></a>

### `get_info_count`

- API：`public`

```gdscript
func get_info_count() -> int:
```

获取信息数量。

返回：信息数量。

<a id="member-gfvalidationreport-methods-is_ok"></a>

### `is_ok`

- API：`public`

```gdscript
func is_ok() -> bool:
```

检查报告是否没有错误。

返回：没有错误时返回 true。

<a id="member-gfvalidationreport-methods-is_healthy"></a>

### `is_healthy`

- API：`public`

```gdscript
func is_healthy() -> bool:
```

检查报告是否完全健康。

返回：没有错误和警告时返回 true。

<a id="member-gfvalidationreport-methods-get_issue_counts_by_kind"></a>

### `get_issue_counts_by_kind`

- API：`public`

```gdscript
func get_issue_counts_by_kind() -> Dictionary:
```

按问题类别统计数量。

返回：类别计数字典。

结构：

- `return`: Dictionary keyed by issue kind with integer counts.

<a id="member-gfvalidationreport-methods-make_summary"></a>

### `make_summary`

- API：`public`

```gdscript
func make_summary(subject_override: String = "") -> String:
```

生成摘要文本。

参数：

| 名称 | 说明 |
|---|---|
| `subject_override` | 临时覆盖报告主题。 |

返回：摘要文本。

<a id="member-gfvalidationreport-methods-get_next_action"></a>

### `get_next_action`

- API：`public`

```gdscript
func get_next_action( action_map: Dictionary = {}, fallback_action: String = "Review the first reported issue.", no_action: String = "No action required." ) -> String:
```

获取下一步建议。

参数：

| 名称 | 说明 |
|---|---|
| `action_map` | 按问题类别映射的建议文本。 |
| `fallback_action` | 存在问题但没有命中映射时返回的建议。 |
| `no_action` | 没有问题时返回的建议。 |

返回：建议文本。

结构：

- `action_map`: Dictionary keyed by issue kind with action text values.

<a id="member-gfvalidationreport-methods-promote_warnings_to_errors"></a>

### `promote_warnings_to_errors`

- API：`public`

```gdscript
func promote_warnings_to_errors(kinds: PackedStringArray = PackedStringArray()) -> RefCounted:
```

将警告提升为错误。

参数：

| 名称 | 说明 |
|---|---|
| `kinds` | 为空时提升全部警告；否则只提升匹配类别。 |

返回：当前报告。

<a id="member-gfvalidationreport-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> RefCounted:
```

从字典创建报告。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

返回：新报告。

结构：

- `data`: Dictionary report payload.
