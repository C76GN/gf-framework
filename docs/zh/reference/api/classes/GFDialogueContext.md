# GFDialogueContext

[API Reference](../index.md) / [Dialogue](../extensions-dialogue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/dialogue/runtime/gf_dialogue_context.gd`
- 模块：`Dialogue`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用对话运行上下文。 上下文保存运行时值，并把条件判断、mutation 和文本解析委托给项目提供的 Callable。框架只负责规范调用与结果包装。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`values`](#member-gfdialoguecontext-properties-values) | `var values: Dictionary = {}` |
| 属性 | [`condition_handler`](#member-gfdialoguecontext-properties-condition_handler) | `var condition_handler: Callable = Callable()` |
| 属性 | [`mutation_handler`](#member-gfdialoguecontext-properties-mutation_handler) | `var mutation_handler: Callable = Callable()` |
| 属性 | [`text_resolver`](#member-gfdialoguecontext-properties-text_resolver) | `var text_resolver: Callable = Callable()` |
| 方法 | [`set_architecture`](#member-gfdialoguecontext-methods-set_architecture) | `func set_architecture(architecture: GFArchitecture) -> GFDialogueContext:` |
| 方法 | [`get_architecture`](#member-gfdialoguecontext-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`set_value`](#member-gfdialoguecontext-methods-set_value) | `func set_value(key: StringName, value: Variant) -> GFDialogueContext:` |
| 方法 | [`get_value`](#member-gfdialoguecontext-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`check_condition`](#member-gfdialoguecontext-methods-check_condition) | `func check_condition(condition_id: StringName, payload: Variant = null, subject: Variant = null) -> Dictionary:` |
| 方法 | [`apply_mutation`](#member-gfdialoguecontext-methods-apply_mutation) | `func apply_mutation(mutation_id: StringName, payload: Variant = null, subject: Variant = null) -> Dictionary:` |
| 方法 | [`resolve_text`](#member-gfdialoguecontext-methods-resolve_text) | `func resolve_text(text: String, subject: Variant = null) -> String:` |
| 方法 | [`serialize_values`](#member-gfdialoguecontext-methods-serialize_values) | `func serialize_values() -> Dictionary:` |
| 方法 | [`deserialize_values`](#member-gfdialoguecontext-methods-deserialize_values) | `func deserialize_values(data: Dictionary) -> void:` |

## 属性

<a id="member-gfdialoguecontext-properties-values"></a>

### `values`

- API：`public`

```gdscript
var values: Dictionary = {}
```

运行时值表。字段含义由项目决定。

结构：

- `values`: 项目自定义运行时值 Dictionary；键通常为 StringName，值由项目决定。

<a id="member-gfdialoguecontext-properties-condition_handler"></a>

### `condition_handler`

- API：`public`

```gdscript
var condition_handler: Callable = Callable()
```

条件处理器，建议签名为 func(condition_id, payload, subject, context) -> Variant。

<a id="member-gfdialoguecontext-properties-mutation_handler"></a>

### `mutation_handler`

- API：`public`

```gdscript
var mutation_handler: Callable = Callable()
```

mutation 处理器，建议签名为 func(mutation_id, payload, subject, context) -> Variant。

<a id="member-gfdialoguecontext-properties-text_resolver"></a>

### `text_resolver`

- API：`public`

```gdscript
var text_resolver: Callable = Callable()
```

文本解析器，建议签名为 func(text, subject, context) -> String。

## 方法

<a id="member-gfdialoguecontext-methods-set_architecture"></a>

### `set_architecture`

- API：`public`

```gdscript
func set_architecture(architecture: GFArchitecture) -> GFDialogueContext:
```

设置架构引用。

参数：

| 名称 | 说明 |
|---|---|
| `architecture` | 架构实例。 |

返回：当前上下文。

<a id="member-gfdialoguecontext-methods-get_architecture"></a>

### `get_architecture`

- API：`public`

```gdscript
func get_architecture() -> GFArchitecture:
```

获取架构引用。

返回：架构实例；不存在时返回 null。

<a id="member-gfdialoguecontext-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant) -> GFDialogueContext:
```

写入上下文值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |
| `value` | 值。 |

返回：当前上下文。

结构：

- `value`: 要写入 values 的任意项目值。

<a id="member-gfdialoguecontext-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取上下文值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |
| `default_value` | 默认值。 |

返回：当前值或默认值。

结构：

- `default_value`: key 缺失时返回的任意默认值。
- `return`: values 中的项目值，或传入的 default_value。

<a id="member-gfdialoguecontext-methods-check_condition"></a>

### `check_condition`

- API：`public`

```gdscript
func check_condition(condition_id: StringName, payload: Variant = null, subject: Variant = null) -> Dictionary:
```

检查条件。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件 ID。 |
| `payload` | 条件载荷。 |
| `subject` | 触发条件的行、响应或项目对象。 |

返回：结构化结果。

结构：

- `payload`: 条件处理器接收的任意项目载荷；框架只透传。
- `subject`: GFDialogueLine、GFDialogueResponse 或项目传入的任意条件主体。
- `return`: 包含 ok、reason 和 value 等字段的 Dictionary；当处理器返回 Dictionary 时会保留调用方字段。

<a id="member-gfdialoguecontext-methods-apply_mutation"></a>

### `apply_mutation`

- API：`public`

```gdscript
func apply_mutation(mutation_id: StringName, payload: Variant = null, subject: Variant = null) -> Dictionary:
```

请求执行 mutation。

参数：

| 名称 | 说明 |
|---|---|
| `mutation_id` | mutation ID。 |
| `payload` | mutation 载荷。 |
| `subject` | 触发 mutation 的行、响应或项目对象。 |

返回：结构化结果。

结构：

- `payload`: mutation 处理器接收的任意项目载荷；框架只透传。
- `subject`: GFDialogueLine、GFDialogueResponse 或项目传入的任意 mutation 主体。
- `return`: 包含 ok、reason 和 value 等字段的 Dictionary；当处理器返回 Dictionary 时会保留调用方字段。

<a id="member-gfdialoguecontext-methods-resolve_text"></a>

### `resolve_text`

- API：`public`

```gdscript
func resolve_text(text: String, subject: Variant = null) -> String:
```

解析文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 原始文本或文本键。 |
| `subject` | 文本所属行、响应或项目对象。 |

返回：解析后的文本。

结构：

- `subject`: GFDialogueLine、GFDialogueResponse 或项目传入的任意文本主体。

<a id="member-gfdialoguecontext-methods-serialize_values"></a>

### `serialize_values`

- API：`public`

```gdscript
func serialize_values() -> Dictionary:
```

序列化运行值。

返回：值表副本。

结构：

- `return`: values 的深拷贝 Dictionary。

<a id="member-gfdialoguecontext-methods-deserialize_values"></a>

### `deserialize_values`

- API：`public`

```gdscript
func deserialize_values(data: Dictionary) -> void:
```

恢复运行值。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 值表。 |

结构：

- `data`: serialize_values() 返回的运行时值 Dictionary。
