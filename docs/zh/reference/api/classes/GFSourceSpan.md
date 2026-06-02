# GFSourceSpan

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_source_span.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用源码或资源文本定位范围。 用于把校验、导入、生成器或编辑器工具中的问题定位到一个稳定的 source_path、line、column 范围。行列约定为 1-based，0 表示未知。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source_path`](#member-gfsourcespan-properties-source_path) | `var source_path: String = ""` |
| 属性 | [`line`](#member-gfsourcespan-properties-line) | `var line: int = 0` |
| 属性 | [`column`](#member-gfsourcespan-properties-column) | `var column: int = 0` |
| 属性 | [`length`](#member-gfsourcespan-properties-length) | `var length: int = 0` |
| 属性 | [`end_line`](#member-gfsourcespan-properties-end_line) | `var end_line: int = 0` |
| 属性 | [`end_column`](#member-gfsourcespan-properties-end_column) | `var end_column: int = 0` |
| 属性 | [`preview`](#member-gfsourcespan-properties-preview) | `var preview: String = ""` |
| 属性 | [`metadata`](#member-gfsourcespan-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfsourcespan-methods-configure) | `func configure( p_source_path: String = "", p_line: int = 0, p_column: int = 0, p_length: int = 0, p_end_line: int = 0, p_end_column: int = 0, p_preview: String = "", p_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`apply_dict`](#member-gfsourcespan-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`to_dict`](#member-gfsourcespan-methods-to_dict) | `func to_dict(include_empty_fields: bool = false, include_legacy_source_alias: bool = false) -> Dictionary:` |
| 方法 | [`duplicate_span`](#member-gfsourcespan-methods-duplicate_span) | `func duplicate_span() -> RefCounted:` |
| 方法 | [`is_empty`](#member-gfsourcespan-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`has_source_path`](#member-gfsourcespan-methods-has_source_path) | `func has_source_path() -> bool:` |
| 方法 | [`has_position`](#member-gfsourcespan-methods-has_position) | `func has_position() -> bool:` |
| 方法 | [`get_effective_end_line`](#member-gfsourcespan-methods-get_effective_end_line) | `func get_effective_end_line() -> int:` |
| 方法 | [`get_effective_end_column`](#member-gfsourcespan-methods-get_effective_end_column) | `func get_effective_end_column() -> int:` |
| 方法 | [`get_location_text`](#member-gfsourcespan-methods-get_location_text) | `func get_location_text() -> String:` |
| 方法 | [`merge_into_dictionary`](#member-gfsourcespan-methods-merge_into_dictionary) | `func merge_into_dictionary( target: Dictionary, include_empty_fields: bool = false, include_legacy_source_alias: bool = false ) -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfsourcespan-methods-from_dict) | `static func from_dict(data: Dictionary) -> RefCounted:` |
| 方法 | [`from_issue`](#member-gfsourcespan-methods-from_issue) | `static func from_issue(issue: Variant) -> RefCounted:` |
| 方法 | [`make`](#member-gfsourcespan-methods-make) | `static func make( p_source_path: String = "", p_line: int = 0, p_column: int = 0, p_length: int = 0 ) -> RefCounted:` |

## 属性

<a id="member-gfsourcespan-properties-source_path"></a>

### `source_path`

- API：`public`

```gdscript
var source_path: String = ""
```

源文件或资源路径。

<a id="member-gfsourcespan-properties-line"></a>

### `line`

- API：`public`

```gdscript
var line: int = 0
```

起始行号，1-based；0 表示未知。

<a id="member-gfsourcespan-properties-column"></a>

### `column`

- API：`public`

```gdscript
var column: int = 0
```

起始列号，1-based；0 表示未知。

<a id="member-gfsourcespan-properties-length"></a>

### `length`

- API：`public`

```gdscript
var length: int = 0
```

同一行内的跨度长度；0 表示未知。

<a id="member-gfsourcespan-properties-end_line"></a>

### `end_line`

- API：`public`

```gdscript
var end_line: int = 0
```

结束行号，1-based；0 表示未知。

<a id="member-gfsourcespan-properties-end_column"></a>

### `end_column`

- API：`public`

```gdscript
var end_column: int = 0
```

结束列号，1-based；0 表示未知。

<a id="member-gfsourcespan-properties-preview"></a>

### `preview`

- API：`public`

```gdscript
var preview: String = ""
```

可选源码预览。

<a id="member-gfsourcespan-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary caller metadata.

## 方法

<a id="member-gfsourcespan-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_source_path: String = "", p_line: int = 0, p_column: int = 0, p_length: int = 0, p_end_line: int = 0, p_end_column: int = 0, p_preview: String = "", p_metadata: Dictionary = {} ) -> RefCounted:
```

配置定位范围。

参数：

| 名称 | 说明 |
|---|---|
| `p_source_path` | 源文件或资源路径。 |
| `p_line` | 起始行号，1-based；0 表示未知。 |
| `p_column` | 起始列号，1-based；0 表示未知。 |
| `p_length` | 同一行内的跨度长度；0 表示未知。 |
| `p_end_line` | 结束行号，1-based；0 表示未知。 |
| `p_end_column` | 结束列号，1-based；0 表示未知。 |
| `p_preview` | 可选源码预览。 |
| `p_metadata` | 调用方附加元数据。 |

返回：当前定位范围。

结构：

- `p_metadata`: Dictionary caller metadata.

<a id="member-gfsourcespan-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。`source` 会作为 `source_path` 的兼容别名读取。 |

结构：

- `data`: Dictionary source span fields.

<a id="member-gfsourcespan-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict(include_empty_fields: bool = false, include_legacy_source_alias: bool = false) -> Dictionary:
```

转换为字典。

参数：

| 名称 | 说明 |
|---|---|
| `include_empty_fields` | 为 true 时包含空字段。 |
| `include_legacy_source_alias` | 为 true 时额外写入 `source` 兼容字段。 |

返回：字典副本。

结构：

- `return`: Dictionary source span fields.

<a id="member-gfsourcespan-methods-duplicate_span"></a>

### `duplicate_span`

- API：`public`

```gdscript
func duplicate_span() -> RefCounted:
```

创建当前定位范围的深拷贝。

返回：新定位范围。

<a id="member-gfsourcespan-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查是否没有任何定位信息。

返回：没有路径且没有位置时返回 true。

<a id="member-gfsourcespan-methods-has_source_path"></a>

### `has_source_path`

- API：`public`

```gdscript
func has_source_path() -> bool:
```

检查是否有源路径。

返回：有源路径时返回 true。

<a id="member-gfsourcespan-methods-has_position"></a>

### `has_position`

- API：`public`

```gdscript
func has_position() -> bool:
```

检查是否有起始行号。

返回：有起始行号时返回 true。

<a id="member-gfsourcespan-methods-get_effective_end_line"></a>

### `get_effective_end_line`

- API：`public`

```gdscript
func get_effective_end_line() -> int:
```

获取有效结束行。

返回：显式 end_line 或起始行。

<a id="member-gfsourcespan-methods-get_effective_end_column"></a>

### `get_effective_end_column`

- API：`public`

```gdscript
func get_effective_end_column() -> int:
```

获取有效结束列。

返回：显式 end_column，或根据 column 与 length 推导出的列号。

<a id="member-gfsourcespan-methods-get_location_text"></a>

### `get_location_text`

- API：`public`

```gdscript
func get_location_text() -> String:
```

生成人类可读定位文本。

返回：例如 `res://table.csv:4:2`。

<a id="member-gfsourcespan-methods-merge_into_dictionary"></a>

### `merge_into_dictionary`

- API：`public`

```gdscript
func merge_into_dictionary( target: Dictionary, include_empty_fields: bool = false, include_legacy_source_alias: bool = false ) -> Dictionary:
```

将定位字段写入目标字典。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标字典。 |
| `include_empty_fields` | 为 true 时包含空字段。 |
| `include_legacy_source_alias` | 为 true 时额外写入 `source` 兼容字段。 |

返回：目标字典。

结构：

- `target`: Dictionary updated in place.
- `return`: Dictionary same instance as target with source span fields.

<a id="member-gfsourcespan-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> RefCounted:
```

从字典创建定位范围。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

返回：新定位范围。

结构：

- `data`: Dictionary source span fields.

<a id="member-gfsourcespan-methods-from_issue"></a>

### `from_issue`

- API：`public`

```gdscript
static func from_issue(issue: Variant) -> RefCounted:
```

从问题对象或问题字典创建定位范围。

参数：

| 名称 | 说明 |
|---|---|
| `issue` | GFValidationIssue 或问题字典。 |

返回：新定位范围。

结构：

- `issue`: Variant GFValidationIssue-like object or Dictionary.

<a id="member-gfsourcespan-methods-make"></a>

### `make`

- API：`public`

```gdscript
static func make( p_source_path: String = "", p_line: int = 0, p_column: int = 0, p_length: int = 0 ) -> RefCounted:
```

创建定位范围。

参数：

| 名称 | 说明 |
|---|---|
| `p_source_path` | 源文件或资源路径。 |
| `p_line` | 起始行号，1-based；0 表示未知。 |
| `p_column` | 起始列号，1-based；0 表示未知。 |
| `p_length` | 同一行内的跨度长度；0 表示未知。 |

返回：新定位范围。
