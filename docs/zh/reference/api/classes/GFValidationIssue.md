# GFValidationIssue

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_issue.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用校验问题条目。 用于描述配置、资源、节点树、存档载荷或编辑器工具中的单个问题。它只记录 严重级别、问题类别、定位信息和附加字段，不决定项目如何展示或修复问题。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Severity`](#member-gfvalidationissue-enums-severity) | `enum Severity` |
| 属性 | [`severity`](#member-gfvalidationissue-properties-severity) | `var severity: Severity = Severity.ERROR` |
| 属性 | [`kind`](#member-gfvalidationissue-properties-kind) | `var kind: StringName = &""` |
| 属性 | [`key`](#member-gfvalidationissue-properties-key) | `var key: Variant = null` |
| 属性 | [`path`](#member-gfvalidationissue-properties-path) | `var path: String = ""` |
| 属性 | [`source_path`](#member-gfvalidationissue-properties-source_path) | `var source_path: String = ""` |
| 属性 | [`line`](#member-gfvalidationissue-properties-line) | `var line: int = 0` |
| 属性 | [`column`](#member-gfvalidationissue-properties-column) | `var column: int = 0` |
| 属性 | [`length`](#member-gfvalidationissue-properties-length) | `var length: int = 0` |
| 属性 | [`end_line`](#member-gfvalidationissue-properties-end_line) | `var end_line: int = 0` |
| 属性 | [`end_column`](#member-gfvalidationissue-properties-end_column) | `var end_column: int = 0` |
| 属性 | [`preview`](#member-gfvalidationissue-properties-preview) | `var preview: String = ""` |
| 属性 | [`subject`](#member-gfvalidationissue-properties-subject) | `var subject: String = ""` |
| 属性 | [`message`](#member-gfvalidationissue-properties-message) | `var message: String = ""` |
| 属性 | [`metadata`](#member-gfvalidationissue-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`extra_fields`](#member-gfvalidationissue-properties-extra_fields) | `var extra_fields: Dictionary = {}` |
| 方法 | [`_init`](#member-gfvalidationissue-methods-_init) | `func _init( p_severity: Variant = Severity.ERROR, p_kind: StringName = &"", p_message: String = "", p_key: Variant = null, p_path: String = "", p_metadata: Dictionary = {} ) -> void:` |
| 方法 | [`configure`](#member-gfvalidationissue-methods-configure) | `func configure( p_severity: Variant, p_kind: StringName, p_message: String, p_key: Variant = null, p_path: String = "", p_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`apply_dict`](#member-gfvalidationissue-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`to_dict`](#member-gfvalidationissue-methods-to_dict) | `func to_dict(include_empty_fields: bool = false) -> Dictionary:` |
| 方法 | [`duplicate_issue`](#member-gfvalidationissue-methods-duplicate_issue) | `func duplicate_issue() -> RefCounted:` |
| 方法 | [`set_source_span`](#member-gfvalidationissue-methods-set_source_span) | `func set_source_span(source_span: Variant) -> RefCounted:` |
| 方法 | [`get_source_span`](#member-gfvalidationissue-methods-get_source_span) | `func get_source_span() -> RefCounted:` |
| 方法 | [`has_source_position`](#member-gfvalidationissue-methods-has_source_position) | `func has_source_position() -> bool:` |
| 方法 | [`get_location_text`](#member-gfvalidationissue-methods-get_location_text) | `func get_location_text() -> String:` |
| 方法 | [`get_kind_key`](#member-gfvalidationissue-methods-get_kind_key) | `func get_kind_key() -> String:` |
| 方法 | [`is_error`](#member-gfvalidationissue-methods-is_error) | `func is_error() -> bool:` |
| 方法 | [`is_warning`](#member-gfvalidationissue-methods-is_warning) | `func is_warning() -> bool:` |
| 方法 | [`is_info`](#member-gfvalidationissue-methods-is_info) | `func is_info() -> bool:` |
| 方法 | [`normalize_severity`](#member-gfvalidationissue-methods-normalize_severity) | `static func normalize_severity(value: Variant) -> Severity:` |
| 方法 | [`severity_to_string`](#member-gfvalidationissue-methods-severity_to_string) | `static func severity_to_string(value: Variant) -> String:` |
| 方法 | [`from_dict`](#member-gfvalidationissue-methods-from_dict) | `static func from_dict(data: Dictionary) -> RefCounted:` |

## 枚举

<a id="member-gfvalidationissue-enums-severity"></a>

### `Severity`

- API：`public`

```gdscript
enum Severity {
	## 信息提示，不影响健康状态。
	INFO,
	## 警告，报告仍可继续使用，但不再视为完全健康。
	WARNING,
	## 错误，报告不应视为通过。
	ERROR,
}
```

校验问题严重级别。

## 属性

<a id="member-gfvalidationissue-properties-severity"></a>

### `severity`

- API：`public`

```gdscript
var severity: Severity = Severity.ERROR
```

严重级别。

<a id="member-gfvalidationissue-properties-kind"></a>

### `kind`

- API：`public`

```gdscript
var kind: StringName = &""
```

通用问题类别。推荐使用稳定的 snake_case 标识。

<a id="member-gfvalidationissue-properties-key"></a>

### `key`

- API：`public`

```gdscript
var key: Variant = null
```

可选定位键，例如行号、资源 key、节点 key 或调用方自定义标识。

结构：

- `key`: Variant caller-defined location key.

<a id="member-gfvalidationissue-properties-path"></a>

### `path`

- API：`public`

```gdscript
var path: String = ""
```

可选路径，例如资源路径、节点路径或数据路径。

<a id="member-gfvalidationissue-properties-source_path"></a>

### `source_path`

- API：`public`

```gdscript
var source_path: String = ""
```

可选源文件或资源路径。`source` 字典字段会作为兼容别名读取。

<a id="member-gfvalidationissue-properties-line"></a>

### `line`

- API：`public`

```gdscript
var line: int = 0
```

可选源码起始行号，1-based；0 表示未知。

<a id="member-gfvalidationissue-properties-column"></a>

### `column`

- API：`public`

```gdscript
var column: int = 0
```

可选源码起始列号，1-based；0 表示未知。

<a id="member-gfvalidationissue-properties-length"></a>

### `length`

- API：`public`

```gdscript
var length: int = 0
```

可选源码范围长度；0 表示未知。

<a id="member-gfvalidationissue-properties-end_line"></a>

### `end_line`

- API：`public`

```gdscript
var end_line: int = 0
```

可选源码结束行号，1-based；0 表示未知。

<a id="member-gfvalidationissue-properties-end_column"></a>

### `end_column`

- API：`public`

```gdscript
var end_column: int = 0
```

可选源码结束列号，1-based；0 表示未知。

<a id="member-gfvalidationissue-properties-preview"></a>

### `preview`

- API：`public`

```gdscript
var preview: String = ""
```

可选源码预览。

<a id="member-gfvalidationissue-properties-subject"></a>

### `subject`

- API：`public`

```gdscript
var subject: String = ""
```

可选主题，用于标记问题所属对象或报告域。

<a id="member-gfvalidationissue-properties-message"></a>

### `message`

- API：`public`

```gdscript
var message: String = ""
```

面向开发者或工具 UI 的简短说明。

<a id="member-gfvalidationissue-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary caller metadata.

<a id="member-gfvalidationissue-properties-extra_fields"></a>

### `extra_fields`

- API：`public`

```gdscript
var extra_fields: Dictionary = {}
```

额外上下文字段。用于无损保留已有报告中的自定义字段。

结构：

- `extra_fields`: Dictionary caller-defined fields preserved during conversion.

## 方法

<a id="member-gfvalidationissue-methods-_init"></a>

### `_init`

- API：`public`

```gdscript
func _init( p_severity: Variant = Severity.ERROR, p_kind: StringName = &"", p_message: String = "", p_key: Variant = null, p_path: String = "", p_metadata: Dictionary = {} ) -> void:
```

创建校验问题条目。

参数：

| 名称 | 说明 |
|---|---|
| `p_severity` | 严重级别，可传入 Severity、int 或字符串。 |
| `p_kind` | 问题类别。 |
| `p_message` | 问题说明。 |
| `p_key` | 可选定位键。 |
| `p_path` | 可选路径。 |
| `p_metadata` | 可选元数据。 |

结构：

- `p_severity`: Variant Severity, int, or string.
- `p_key`: Variant caller-defined location key.
- `p_metadata`: Dictionary caller metadata.

<a id="member-gfvalidationissue-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_severity: Variant, p_kind: StringName, p_message: String, p_key: Variant = null, p_path: String = "", p_metadata: Dictionary = {} ) -> RefCounted:
```

配置问题条目并返回自身，便于链式构造。

参数：

| 名称 | 说明 |
|---|---|
| `p_severity` | 严重级别，可传入 Severity、int 或字符串。 |
| `p_kind` | 问题类别。 |
| `p_message` | 问题说明。 |
| `p_key` | 可选定位键。 |
| `p_path` | 可选路径。 |
| `p_metadata` | 可选元数据。 |

返回：当前问题条目。

结构：

- `p_severity`: Variant Severity, int, or string.
- `p_key`: Variant caller-defined location key.
- `p_metadata`: Dictionary caller metadata.

<a id="member-gfvalidationissue-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

结构：

- `data`: Dictionary validation issue fields.

<a id="member-gfvalidationissue-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict(include_empty_fields: bool = false) -> Dictionary:
```

转换为字典。

参数：

| 名称 | 说明 |
|---|---|
| `include_empty_fields` | 为 true 时包含空的可选字段。 |

返回：字典副本。

结构：

- `return`: Dictionary validation issue fields.

<a id="member-gfvalidationissue-methods-duplicate_issue"></a>

### `duplicate_issue`

- API：`public`

```gdscript
func duplicate_issue() -> RefCounted:
```

创建当前问题条目的深拷贝。

返回：新问题条目。

<a id="member-gfvalidationissue-methods-set_source_span"></a>

### `set_source_span`

- API：`public`

```gdscript
func set_source_span(source_span: Variant) -> RefCounted:
```

设置源码定位范围。

参数：

| 名称 | 说明 |
|---|---|
| `source_span` | GFSourceSpan 或兼容字典。 |

返回：当前问题条目。

结构：

- `source_span`: Variant GFSourceSpan-like object or Dictionary.

<a id="member-gfvalidationissue-methods-get_source_span"></a>

### `get_source_span`

- API：`public`

```gdscript
func get_source_span() -> RefCounted:
```

获取源码定位范围副本。

返回：GFSourceSpan。

<a id="member-gfvalidationissue-methods-has_source_position"></a>

### `has_source_position`

- API：`public`

```gdscript
func has_source_position() -> bool:
```

检查问题是否有源码行号。

返回：有行号时返回 true。

<a id="member-gfvalidationissue-methods-get_location_text"></a>

### `get_location_text`

- API：`public`

```gdscript
func get_location_text() -> String:
```

获取人类可读定位文本。

返回：例如 `res://table.csv:4:2`。

<a id="member-gfvalidationissue-methods-get_kind_key"></a>

### `get_kind_key`

- API：`public`

```gdscript
func get_kind_key() -> String:
```

获取统计用问题类别。

返回：优先返回 kind，最后返回 unknown。

<a id="member-gfvalidationissue-methods-is_error"></a>

### `is_error`

- API：`public`

```gdscript
func is_error() -> bool:
```

是否为错误。

返回：严重级别为 ERROR 时返回 true。

<a id="member-gfvalidationissue-methods-is_warning"></a>

### `is_warning`

- API：`public`

```gdscript
func is_warning() -> bool:
```

是否为警告。

返回：严重级别为 WARNING 时返回 true。

<a id="member-gfvalidationissue-methods-is_info"></a>

### `is_info`

- API：`public`

```gdscript
func is_info() -> bool:
```

是否为信息。

返回：严重级别为 INFO 时返回 true。

<a id="member-gfvalidationissue-methods-normalize_severity"></a>

### `normalize_severity`

- API：`public`

```gdscript
static func normalize_severity(value: Variant) -> Severity:
```

将任意输入归一为 Severity。

参数：

| 名称 | 说明 |
|---|---|
| `value` | Severity、int 或字符串。 |

返回：归一后的严重级别。

结构：

- `value`: Variant Severity, int, string, or null.

<a id="member-gfvalidationissue-methods-severity_to_string"></a>

### `severity_to_string`

- API：`public`

```gdscript
static func severity_to_string(value: Variant) -> String:
```

将严重级别转换为稳定字符串。

参数：

| 名称 | 说明 |
|---|---|
| `value` | Severity、int 或字符串。 |

返回：info、warning 或 error。

结构：

- `value`: Variant Severity, int, string, or null.

<a id="member-gfvalidationissue-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> RefCounted:
```

从字典创建问题条目。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

返回：新问题条目。

结构：

- `data`: Dictionary validation issue fields.
