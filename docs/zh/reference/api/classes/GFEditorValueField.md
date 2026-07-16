# GFEditorValueField

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_value_field.gd`
- 模块：`Kernel`
- 继承：`HBoxContainer`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器通用 Variant 值输入控件。 根据 Godot 属性信息创建基础输入控件，适合 Inspector、Dock 或批量资源表格复用。 支持调用方注册自定义控件工厂；自定义控件只需遵循 get_value、set_value、set_editable 和 value_changed 信号约定即可接入。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`value_changed`](#member-gfeditorvaluefield-signals-value_changed) | `signal value_changed(value: Variant)` |
| 信号 | [`debounced_value_changed`](#member-gfeditorvaluefield-signals-debounced_value_changed) | `signal debounced_value_changed(value: Variant)` |
| 信号 | [`value_parse_failed`](#member-gfeditorvaluefield-signals-value_parse_failed) | `signal value_parse_failed(text: String, error_message: String)` |
| 属性 | [`label_text`](#member-gfeditorvaluefield-properties-label_text) | `var label_text: String = ""` |
| 属性 | [`show_label`](#member-gfeditorvaluefield-properties-show_label) | `var show_label: bool = false` |
| 属性 | [`debounce_seconds`](#member-gfeditorvaluefield-properties-debounce_seconds) | `var debounce_seconds: float = 0.0` |
| 方法 | [`configure`](#member-gfeditorvaluefield-methods-configure) | `func configure(property_info: Dictionary, value: Variant = null) -> void:` |
| 方法 | [`set_value`](#member-gfeditorvaluefield-methods-set_value) | `func set_value(value: Variant) -> void:` |
| 方法 | [`get_value`](#member-gfeditorvaluefield-methods-get_value) | `func get_value() -> Variant:` |
| 方法 | [`set_editable`](#member-gfeditorvaluefield-methods-set_editable) | `func set_editable(editable: bool) -> void:` |
| 方法 | [`get_property_info`](#member-gfeditorvaluefield-methods-get_property_info) | `func get_property_info() -> Dictionary:` |
| 方法 | [`set_label`](#member-gfeditorvaluefield-methods-set_label) | `func set_label(text: String, label_visible: bool = true) -> void:` |
| 方法 | [`set_debounce_seconds`](#member-gfeditorvaluefield-methods-set_debounce_seconds) | `func set_debounce_seconds(seconds: float) -> void:` |
| 方法 | [`register_editor_factory`](#member-gfeditorvaluefield-methods-register_editor_factory) | `func register_editor_factory(value_type: Variant.Type, factory: Callable) -> bool:` |
| 方法 | [`unregister_editor_factory`](#member-gfeditorvaluefield-methods-unregister_editor_factory) | `func unregister_editor_factory(value_type: Variant.Type) -> bool:` |
| 方法 | [`clear_editor_factories`](#member-gfeditorvaluefield-methods-clear_editor_factories) | `func clear_editor_factories() -> void:` |
| 方法 | [`get_registered_editor_types`](#member-gfeditorvaluefield-methods-get_registered_editor_types) | `func get_registered_editor_types() -> PackedInt32Array:` |

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

<a id="member-gfeditorvaluefield-signals-debounced_value_changed"></a>

### `debounced_value_changed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal debounced_value_changed(value: Variant)
```

控件值变化防抖后发出。debounce_seconds 小于等于 0 时与 value_changed 同步发出。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 防抖后的值。 |

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

## 属性

<a id="member-gfeditorvaluefield-properties-label_text"></a>

### `label_text`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var label_text: String = ""
```

标签文本。show_label 为 true 时会显示在输入控件左侧。

<a id="member-gfeditorvaluefield-properties-show_label"></a>

### `show_label`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var show_label: bool = false
```

是否显示标签。

<a id="member-gfeditorvaluefield-properties-debounce_seconds"></a>

### `debounce_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var debounce_seconds: float = 0.0
```

防抖秒数。小于等于 0 时立即发出 debounced_value_changed。

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

<a id="member-gfeditorvaluefield-methods-set_label"></a>

### `set_label`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_label(text: String, label_visible: bool = true) -> void:
```

设置左侧标签。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 标签文本。 |
| `label_visible` | 是否显示标签。 |

<a id="member-gfeditorvaluefield-methods-set_debounce_seconds"></a>

### `set_debounce_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_debounce_seconds(seconds: float) -> void:
```

设置防抖时间。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 防抖秒数；小于等于 0 时禁用等待。 |

<a id="member-gfeditorvaluefield-methods-register_editor_factory"></a>

### `register_editor_factory`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_editor_factory(value_type: Variant.Type, factory: Callable) -> bool:
```

注册指定 Variant 类型的自定义编辑控件工厂。 工厂建议签名为 func(property_info: Dictionary, value: Variant) -> Control。 返回控件若实现 get_value、set_value、set_editable 或 value_changed，GFEditorValueField 会按约定调用。

参数：

| 名称 | 说明 |
|---|---|
| `value_type` | Godot Variant.Type。 |
| `factory` | 控件工厂回调。 |

返回：注册成功返回 true。

<a id="member-gfeditorvaluefield-methods-unregister_editor_factory"></a>

### `unregister_editor_factory`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_editor_factory(value_type: Variant.Type) -> bool:
```

注销指定 Variant 类型的自定义编辑控件工厂。

参数：

| 名称 | 说明 |
|---|---|
| `value_type` | Godot Variant.Type。 |

返回：原先存在并删除时返回 true。

<a id="member-gfeditorvaluefield-methods-clear_editor_factories"></a>

### `clear_editor_factories`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_editor_factories() -> void:
```

清空自定义编辑控件工厂。

<a id="member-gfeditorvaluefield-methods-get_registered_editor_types"></a>

### `get_registered_editor_types`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_registered_editor_types() -> PackedInt32Array:
```

获取已注册工厂的 Variant 类型。

返回：Variant.Type 数值列表。
