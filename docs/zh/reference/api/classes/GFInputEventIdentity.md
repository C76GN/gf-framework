# GFInputEventIdentity

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/common/gf_input_event_identity.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

输入事件的稳定语义身份。 将 Godot InputEvent 归一为框架可复用的显示键、冲突键与图标候选键。 它不读取 InputMap，不规定项目 action 命名，也不绑定具体图标资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KIND_NONE`](#member-gfinputeventidentity-constants-kind_none) | `const KIND_NONE: StringName = &""` |
| 常量 | [`KIND_ACTION`](#member-gfinputeventidentity-constants-kind_action) | `const KIND_ACTION: StringName = &"action"` |
| 常量 | [`KIND_KEY`](#member-gfinputeventidentity-constants-kind_key) | `const KIND_KEY: StringName = &"key"` |
| 常量 | [`KIND_MOUSE_BUTTON`](#member-gfinputeventidentity-constants-kind_mouse_button) | `const KIND_MOUSE_BUTTON: StringName = &"mouse_button"` |
| 常量 | [`KIND_JOY_BUTTON`](#member-gfinputeventidentity-constants-kind_joy_button) | `const KIND_JOY_BUTTON: StringName = &"joy_button"` |
| 常量 | [`KIND_JOY_AXIS`](#member-gfinputeventidentity-constants-kind_joy_axis) | `const KIND_JOY_AXIS: StringName = &"joy_axis"` |
| 常量 | [`KIND_TOUCH`](#member-gfinputeventidentity-constants-kind_touch) | `const KIND_TOUCH: StringName = &"touch"` |
| 常量 | [`KIND_SCREEN_DRAG`](#member-gfinputeventidentity-constants-kind_screen_drag) | `const KIND_SCREEN_DRAG: StringName = &"screen_drag"` |
| 常量 | [`KIND_UNKNOWN`](#member-gfinputeventidentity-constants-kind_unknown) | `const KIND_UNKNOWN: StringName = &"unknown"` |
| 属性 | [`kind`](#member-gfinputeventidentity-properties-kind) | `var kind: StringName = KIND_NONE` |
| 属性 | [`primary_key`](#member-gfinputeventidentity-properties-primary_key) | `var primary_key: String = ""` |
| 属性 | [`display_key`](#member-gfinputeventidentity-properties-display_key) | `var display_key: String = ""` |
| 属性 | [`conflict_key`](#member-gfinputeventidentity-properties-conflict_key) | `var conflict_key: String = ""` |
| 属性 | [`icon_key`](#member-gfinputeventidentity-properties-icon_key) | `var icon_key: StringName = &""` |
| 属性 | [`device_id`](#member-gfinputeventidentity-properties-device_id) | `var device_id: int = -1` |
| 属性 | [`axis_sign`](#member-gfinputeventidentity-properties-axis_sign) | `var axis_sign: int = 0` |
| 属性 | [`metadata`](#member-gfinputeventidentity-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`from_event`](#member-gfinputeventidentity-methods-from_event) | `static func from_event(input_event: InputEvent, options: Dictionary = {}) -> GFInputEventIdentity:` |
| 方法 | [`get_icon_candidates`](#member-gfinputeventidentity-methods-get_icon_candidates) | `static func get_icon_candidates(input_event: InputEvent, options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`is_empty`](#member-gfinputeventidentity-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_signature`](#member-gfinputeventidentity-methods-get_signature) | `func get_signature(include_device: bool = false) -> String:` |
| 方法 | [`to_dictionary`](#member-gfinputeventidentity-methods-to_dictionary) | `func to_dictionary(json_compatible: bool = true) -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gfinputeventidentity-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFInputEventIdentity:` |

## 常量

<a id="member-gfinputeventidentity-constants-kind_none"></a>

### `KIND_NONE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_NONE: StringName = &""
```

未识别或空输入事件。

<a id="member-gfinputeventidentity-constants-kind_action"></a>

### `KIND_ACTION`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_ACTION: StringName = &"action"
```

Godot InputEventAction。

<a id="member-gfinputeventidentity-constants-kind_key"></a>

### `KIND_KEY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_KEY: StringName = &"key"
```

键盘按键事件。

<a id="member-gfinputeventidentity-constants-kind_mouse_button"></a>

### `KIND_MOUSE_BUTTON`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_MOUSE_BUTTON: StringName = &"mouse_button"
```

鼠标按钮事件。

<a id="member-gfinputeventidentity-constants-kind_joy_button"></a>

### `KIND_JOY_BUTTON`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_JOY_BUTTON: StringName = &"joy_button"
```

手柄按钮事件。

<a id="member-gfinputeventidentity-constants-kind_joy_axis"></a>

### `KIND_JOY_AXIS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_JOY_AXIS: StringName = &"joy_axis"
```

手柄轴事件。

<a id="member-gfinputeventidentity-constants-kind_touch"></a>

### `KIND_TOUCH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_TOUCH: StringName = &"touch"
```

触屏按下事件。

<a id="member-gfinputeventidentity-constants-kind_screen_drag"></a>

### `KIND_SCREEN_DRAG`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_SCREEN_DRAG: StringName = &"screen_drag"
```

触屏拖动事件。

<a id="member-gfinputeventidentity-constants-kind_unknown"></a>

### `KIND_UNKNOWN`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_UNKNOWN: StringName = &"unknown"
```

未专门建模的其他 InputEvent。

## 属性

<a id="member-gfinputeventidentity-properties-kind"></a>

### `kind`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var kind: StringName = KIND_NONE
```

输入事件类别。

<a id="member-gfinputeventidentity-properties-primary_key"></a>

### `primary_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var primary_key: String = ""
```

主身份键。用于日志、报告和调试展示中的稳定归类。

<a id="member-gfinputeventidentity-properties-display_key"></a>

### `display_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var display_key: String = ""
```

显示键。用于 UI 或文档层决定如何进一步本地化。

<a id="member-gfinputeventidentity-properties-conflict_key"></a>

### `conflict_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var conflict_key: String = ""
```

冲突键。默认不包含设备 ID，设备匹配应使用 get_signature()。

<a id="member-gfinputeventidentity-properties-icon_key"></a>

### `icon_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var icon_key: StringName = &""
```

首选图标键。没有稳定图标语义时为空。

<a id="member-gfinputeventidentity-properties-device_id"></a>

### `device_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var device_id: int = -1
```

输入事件携带的 Godot device ID。

<a id="member-gfinputeventidentity-properties-axis_sign"></a>

### `axis_sign`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var axis_sign: int = 0
```

轴方向。正向为 1，负向为 -1，未知或不适用为 0。

<a id="member-gfinputeventidentity-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

附加元数据。

结构：

- `metadata`: Dictionary，包含事件类型相关的纯数据字段。

## 方法

<a id="member-gfinputeventidentity-methods-from_event"></a>

### `from_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_event(input_event: InputEvent, options: Dictionary = {}) -> GFInputEventIdentity:
```

从输入事件构建稳定身份。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 归一化选项。 |

返回：输入事件身份；空事件返回 kind 为空的身份。

结构：

- `options`: Dictionary，可包含 include_key_modifiers、include_key_modifier_combo、match_touch_index 和 joy_axis_sign。

<a id="member-gfinputeventidentity-methods-get_icon_candidates"></a>

### `get_icon_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_icon_candidates(input_event: InputEvent, options: Dictionary = {}) -> PackedStringArray:
```

获取输入事件可能使用的图标键。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 归一化选项。 |

返回：图标键列表，按优先级排序。

结构：

- `options`: Dictionary，可包含 include_key_modifier_combo、match_touch_index 和 joy_axis_sign。

<a id="member-gfinputeventidentity-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_empty() -> bool:
```

判断身份是否为空。

返回：空身份返回 true。

<a id="member-gfinputeventidentity-methods-get_signature"></a>

### `get_signature`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_signature(include_device: bool = false) -> String:
```

获取冲突签名。

参数：

| 名称 | 说明 |
|---|---|
| `include_device` | 是否把 device_id 纳入签名。 |

返回：稳定冲突签名；空身份返回空字符串。

<a id="member-gfinputeventidentity-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary(json_compatible: bool = true) -> Dictionary:
```

转换为字典。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 是否把 metadata 转换为 JSON 兼容值。 |

返回：身份字典。

结构：

- `return`: Dictionary with kind, primary_key, display_key, conflict_key, icon_key, device_id, axis_sign, and metadata fields.

<a id="member-gfinputeventidentity-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dictionary(data: Dictionary) -> GFInputEventIdentity:
```

从字典恢复输入事件身份。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 身份字典。 |

返回：输入事件身份。

结构：

- `data`: Dictionary produced by to_dictionary(), or a compatible dictionary with the same fields.
