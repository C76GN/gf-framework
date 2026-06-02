# GFEditorValueField

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_value_field.gd`
- 模块：`Kernel`
- 继承：`HBoxContainer`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器通用 Variant 值输入控件。 根据 Godot 属性信息创建基础输入控件，适合 Inspector、Dock 或批量资源表格复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`value_changed`](#member-gfeditorvaluefield-signals-value_changed) | `signal value_changed(value: Variant)` |
| 信号 | [`value_parse_failed`](#member-gfeditorvaluefield-signals-value_parse_failed) | `signal value_parse_failed(text: String, error_message: String)` |
| 方法 | [`configure`](#member-gfeditorvaluefield-methods-configure) | `func configure(property_info: Dictionary, value: Variant = null) -> void:` |
| 方法 | [`set_value`](#member-gfeditorvaluefield-methods-set_value) | `func set_value(value: Variant) -> void:` |
| 方法 | [`get_value`](#member-gfeditorvaluefield-methods-get_value) | `func get_value() -> Variant:` |
| 方法 | [`set_editable`](#member-gfeditorvaluefield-methods-set_editable) | `func set_editable(editable: bool) -> void:` |
| 方法 | [`get_property_info`](#member-gfeditorvaluefield-methods-get_property_info) | `func get_property_info() -> Dictionary:` |

## 信号

<a id="member-gfeditorvaluefield-signals-value_changed"></a>

### `value_changed`

- API：`public`

```gdscript
signal value_changed(value: Variant)
```

控件值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新值。 |

结构：

- `value`: Variant editor value read from the active control.

<a id="member-gfeditorvaluefield-signals-value_parse_failed"></a>

### `value_parse_failed`

- API：`public`

```gdscript
signal value_parse_failed(text: String, error_message: String)
```

Array/Dictionary JSON 输入解析失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 用户输入的原始文本。 |
| `error_message` | JSON 解析错误说明。 |

## 方法

<a id="member-gfeditorvaluefield-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(property_info: Dictionary, value: Variant = null) -> void:
```

配置字段输入控件。

参数：

| 名称 | 说明 |
|---|---|
| `property_info` | Godot 属性信息字典，常用键为 name、type、hint、hint_string。 |
| `value` | 初始值。 |

结构：

- `property_info`: Godot property info dictionary.
- `value`: Variant initial editor value.

<a id="member-gfeditorvaluefield-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(value: Variant) -> void:
```

设置当前值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新值。 |

结构：

- `value`: Variant value assigned to the editor.

<a id="member-gfeditorvaluefield-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value() -> Variant:
```

获取当前值。

返回：当前值。

结构：

- `return`: Variant value read from the active editor control.

<a id="member-gfeditorvaluefield-methods-set_editable"></a>

### `set_editable`

- API：`public`

```gdscript
func set_editable(editable: bool) -> void:
```

设置控件是否可编辑。

参数：

| 名称 | 说明 |
|---|---|
| `editable` | 为 true 时允许编辑。 |

<a id="member-gfeditorvaluefield-methods-get_property_info"></a>

### `get_property_info`

- API：`public`

```gdscript
func get_property_info() -> Dictionary:
```

获取当前属性信息。

返回：属性信息字典。

结构：

- `return`: Godot property info dictionary copy.
