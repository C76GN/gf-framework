# GFTextGenerationContext

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/text/gf_text_generation_context.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

安全的纯数据文本生成上下文。 提供显式数据 scope、严格缺失检查、简单 token 替换、输出缓冲和预算诊断。 token 只解析数据路径，不执行表达式、脚本或宿主对象方法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`strict_variables`](#member-gftextgenerationcontext-properties-strict_variables) | `var strict_variables: bool = false` |
| 属性 | [`max_output_length`](#member-gftextgenerationcontext-properties-max_output_length) | `var max_output_length: int = 0` |
| 属性 | [`indent_text`](#member-gftextgenerationcontext-properties-indent_text) | `var indent_text: String = "\t"` |
| 属性 | [`budget`](#member-gftextgenerationcontext-properties-budget) | `var budget: GFExecutionBudget = null` |
| 属性 | [`metadata`](#member-gftextgenerationcontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`_init`](#member-gftextgenerationcontext-methods-_init) | `func _init(root_values: Dictionary = {}, options: Dictionary = {}) -> void:` |
| 方法 | [`configure`](#member-gftextgenerationcontext-methods-configure) | `func configure(root_values: Dictionary = {}, options: Dictionary = {}) -> GFTextGenerationContext:` |
| 方法 | [`clear`](#member-gftextgenerationcontext-methods-clear) | `func clear() -> void:` |
| 方法 | [`push_scope`](#member-gftextgenerationcontext-methods-push_scope) | `func push_scope(values: Dictionary, label: String = "") -> int:` |
| 方法 | [`pop_scope`](#member-gftextgenerationcontext-methods-pop_scope) | `func pop_scope() -> Dictionary:` |
| 方法 | [`set_value`](#member-gftextgenerationcontext-methods-set_value) | `func set_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`has_value`](#member-gftextgenerationcontext-methods-has_value) | `func has_value(data_path: String) -> bool:` |
| 方法 | [`get_value`](#member-gftextgenerationcontext-methods-get_value) | `func get_value(data_path: String, default_value: Variant = null, source_span: Variant = null) -> Variant:` |
| 方法 | [`replace_tokens`](#member-gftextgenerationcontext-methods-replace_tokens) | `func replace_tokens(text: String, options: Dictionary = {}) -> String:` |
| 方法 | [`append_text`](#member-gftextgenerationcontext-methods-append_text) | `func append_text(text: String, source_span: Variant = null) -> bool:` |
| 方法 | [`append_line`](#member-gftextgenerationcontext-methods-append_line) | `func append_line(text: String = "", source_span: Variant = null) -> bool:` |
| 方法 | [`append_indented_line`](#member-gftextgenerationcontext-methods-append_indented_line) | `func append_indented_line(text: String = "", source_span: Variant = null) -> bool:` |
| 方法 | [`push_indent`](#member-gftextgenerationcontext-methods-push_indent) | `func push_indent() -> int:` |
| 方法 | [`pop_indent`](#member-gftextgenerationcontext-methods-pop_indent) | `func pop_indent() -> int:` |
| 方法 | [`get_text`](#member-gftextgenerationcontext-methods-get_text) | `func get_text() -> String:` |
| 方法 | [`get_report`](#member-gftextgenerationcontext-methods-get_report) | `func get_report() -> GFValidationReport:` |
| 方法 | [`duplicate_report`](#member-gftextgenerationcontext-methods-duplicate_report) | `func duplicate_report() -> GFValidationReport:` |
| 方法 | [`get_debug_snapshot`](#member-gftextgenerationcontext-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gftextgenerationcontext-properties-strict_variables"></a>

### `strict_variables`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var strict_variables: bool = false
```

缺失变量是否记录为错误。

<a id="member-gftextgenerationcontext-properties-max_output_length"></a>

### `max_output_length`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_output_length: int = 0
```

最大输出长度；小于等于 0 表示不限制。

<a id="member-gftextgenerationcontext-properties-indent_text"></a>

### `indent_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var indent_text: String = "\t"
```

每级缩进使用的文本。

<a id="member-gftextgenerationcontext-properties-budget"></a>

### `budget`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var budget: GFExecutionBudget = null
```

可选执行预算。

<a id="member-gftextgenerationcontext-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary，包含调用方定义的上下文。

## 方法

<a id="member-gftextgenerationcontext-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(root_values: Dictionary = {}, options: Dictionary = {}) -> void:
```

创建文本生成上下文。

参数：

| 名称 | 说明 |
|---|---|
| `root_values` | 根数据 scope。 |
| `options` | 可选配置，支持 strict_variables、max_output_length、indent_text、budget、subject 和 metadata。 |

结构：

- `root_values`: Dictionary，根数据。
- `options`: Dictionary，上下文配置。

<a id="member-gftextgenerationcontext-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure(root_values: Dictionary = {}, options: Dictionary = {}) -> GFTextGenerationContext:
```

配置上下文并清空输出。

参数：

| 名称 | 说明 |
|---|---|
| `root_values` | 根数据 scope。 |
| `options` | 可选配置，支持 strict_variables、max_output_length、indent_text、budget、subject 和 metadata。 |

返回：当前上下文。

结构：

- `root_values`: Dictionary，根数据。
- `options`: Dictionary，上下文配置。

<a id="member-gftextgenerationcontext-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空 scope、输出和诊断。

<a id="member-gftextgenerationcontext-methods-push_scope"></a>

### `push_scope`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func push_scope(values: Dictionary, label: String = "") -> int:
```

推入一个数据 scope。

参数：

| 名称 | 说明 |
|---|---|
| `values` | scope 数据。 |
| `label` | scope 标签，仅用于诊断。 |

返回：当前 scope 数量。

结构：

- `values`: Dictionary，scope 数据。

<a id="member-gftextgenerationcontext-methods-pop_scope"></a>

### `pop_scope`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func pop_scope() -> Dictionary:
```

弹出顶层 scope。

返回：被移除的 scope；没有 scope 时返回空字典。

结构：

- `return`: Dictionary，被移除的 scope 数据。

<a id="member-gftextgenerationcontext-methods-set_value"></a>

### `set_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_value(key: StringName, value: Variant) -> void:
```

设置顶层 scope 的值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |
| `value` | 字段值。 |

结构：

- `value`: Variant，调用方数据。

<a id="member-gftextgenerationcontext-methods-has_value"></a>

### `has_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_value(data_path: String) -> bool:
```

检查路径是否可解析。

参数：

| 名称 | 说明 |
|---|---|
| `data_path` | 点号分隔的数据路径。 |

返回：可解析时返回 true。

<a id="member-gftextgenerationcontext-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_value(data_path: String, default_value: Variant = null, source_span: Variant = null) -> Variant:
```

读取路径值。

参数：

| 名称 | 说明 |
|---|---|
| `data_path` | 点号分隔的数据路径。 |
| `default_value` | 缺失时返回的默认值。 |
| `source_span` | 可选源码定位。 |

返回：读取到的值或默认值。

结构：

- `default_value`: Variant，缺失时的默认值。
- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。
- `return`: Variant，读取到的数据。

<a id="member-gftextgenerationcontext-methods-replace_tokens"></a>

### `replace_tokens`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func replace_tokens(text: String, options: Dictionary = {}) -> String:
```

替换文本中的 token。 token 默认使用 `{{name}}` 形式，name 只能是数据路径；不会执行表达式。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 输入文本。 |
| `options` | 可选配置，支持 start_token、end_token、missing_text、max_replacements 和 source_span。 |

返回：替换后的文本。

结构：

- `options`: Dictionary，token 替换配置。

<a id="member-gftextgenerationcontext-methods-append_text"></a>

### `append_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func append_text(text: String, source_span: Variant = null) -> bool:
```

追加文本到输出缓冲。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 要追加的文本。 |
| `source_span` | 可选源码定位。 |

返回：追加成功时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gftextgenerationcontext-methods-append_line"></a>

### `append_line`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func append_line(text: String = "", source_span: Variant = null) -> bool:
```

追加一行文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 行文本。 |
| `source_span` | 可选源码定位。 |

返回：追加成功时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gftextgenerationcontext-methods-append_indented_line"></a>

### `append_indented_line`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func append_indented_line(text: String = "", source_span: Variant = null) -> bool:
```

追加带当前缩进的一行文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 行文本。 |
| `source_span` | 可选源码定位。 |

返回：追加成功时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gftextgenerationcontext-methods-push_indent"></a>

### `push_indent`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func push_indent() -> int:
```

增加缩进级别。

返回：当前缩进级别。

<a id="member-gftextgenerationcontext-methods-pop_indent"></a>

### `pop_indent`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func pop_indent() -> int:
```

减少缩进级别。

返回：当前缩进级别。

<a id="member-gftextgenerationcontext-methods-get_text"></a>

### `get_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_text() -> String:
```

获取当前输出文本。

返回：输出文本。

<a id="member-gftextgenerationcontext-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report() -> GFValidationReport:
```

获取当前报告。

返回：校验报告。

<a id="member-gftextgenerationcontext-methods-duplicate_report"></a>

### `duplicate_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func duplicate_report() -> GFValidationReport:
```

创建报告副本。

返回：校验报告副本。

<a id="member-gftextgenerationcontext-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：上下文状态字典。

结构：

- `return`: Dictionary，包含 scope、输出和诊断状态。
