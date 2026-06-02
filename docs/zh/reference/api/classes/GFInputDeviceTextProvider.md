# GFInputDeviceTextProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_device_text_provider.gd`
- 模块：`Standard`
- 继承：`GFInputTextProvider`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用手柄输入文本 provider。 以抽象方位和轴名称描述 Joypad 输入，项目可通过字典覆盖为任意设备、平台或本地化文本。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`button_labels`](#member-gfinputdevicetextprovider-properties-button_labels) | `var button_labels: Dictionary = _DEFAULT_BUTTON_LABELS` |
| 属性 | [`axis_labels`](#member-gfinputdevicetextprovider-properties-axis_labels) | `var axis_labels: Dictionary = _DEFAULT_AXIS_LABELS` |
| 属性 | [`axis_positive_suffix`](#member-gfinputdevicetextprovider-properties-axis_positive_suffix) | `var axis_positive_suffix: String = "+"` |
| 属性 | [`axis_negative_suffix`](#member-gfinputdevicetextprovider-properties-axis_negative_suffix) | `var axis_negative_suffix: String = "-"` |
| 属性 | [`axis_direction_deadzone`](#member-gfinputdevicetextprovider-properties-axis_direction_deadzone) | `var axis_direction_deadzone: float = 0.1` |
| 方法 | [`create_standard`](#member-gfinputdevicetextprovider-methods-create_standard) | `static func create_standard(provider_priority: int = 0) -> GFInputDeviceTextProvider:` |
| 方法 | [`format_joypad_event`](#member-gfinputdevicetextprovider-methods-format_joypad_event) | `static func format_joypad_event(input_event: InputEvent, options: Dictionary = {}) -> String:` |
| 方法 | [`supports_event`](#member-gfinputdevicetextprovider-methods-supports_event) | `func supports_event(input_event: InputEvent, _options: Dictionary = {}) -> bool:` |
| 方法 | [`get_event_text`](#member-gfinputdevicetextprovider-methods-get_event_text) | `func get_event_text(input_event: InputEvent, options: Dictionary = {}) -> String:` |

## 属性

<a id="member-gfinputdevicetextprovider-properties-button_labels"></a>

### `button_labels`

- API：`public`

```gdscript
var button_labels: Dictionary = _DEFAULT_BUTTON_LABELS
```

Joypad 按钮标签表，Key 为 JoyButton int。

结构：

- `button_labels`: Dictionary，以 JoyButton int 或枚举值为键，值为 String 显示标签。

<a id="member-gfinputdevicetextprovider-properties-axis_labels"></a>

### `axis_labels`

- API：`public`

```gdscript
var axis_labels: Dictionary = _DEFAULT_AXIS_LABELS
```

Joypad 轴标签表，Key 为 JoyAxis int。

结构：

- `axis_labels`: Dictionary，以 JoyAxis int 或枚举值为键，值为 String 显示标签。

<a id="member-gfinputdevicetextprovider-properties-axis_positive_suffix"></a>

### `axis_positive_suffix`

- API：`public`

```gdscript
var axis_positive_suffix: String = "+"
```

正向轴后缀。

<a id="member-gfinputdevicetextprovider-properties-axis_negative_suffix"></a>

### `axis_negative_suffix`

- API：`public`

```gdscript
var axis_negative_suffix: String = "-"
```

负向轴后缀。

<a id="member-gfinputdevicetextprovider-properties-axis_direction_deadzone"></a>

### `axis_direction_deadzone`

- API：`public`

```gdscript
var axis_direction_deadzone: float = 0.1
```

轴方向判断死区。

## 方法

<a id="member-gfinputdevicetextprovider-methods-create_standard"></a>

### `create_standard`

- API：`public`

```gdscript
static func create_standard(provider_priority: int = 0) -> GFInputDeviceTextProvider:
```

创建标准手柄文本 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider_priority` | provider 优先级。 |

返回：文本 provider。

<a id="member-gfinputdevicetextprovider-methods-format_joypad_event"></a>

### `format_joypad_event`

- API：`public`

```gdscript
static func format_joypad_event(input_event: InputEvent, options: Dictionary = {}) -> String:
```

使用标准标签格式化 Joypad 输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 可选格式化参数。 |

返回：文本；非 Joypad 事件返回空字符串。

结构：

- `options`: Dictionary，可包含 joypad_button_labels、joypad_axis_labels、joypad_axis_deadzone、joypad_axis_positive_suffix 和 joypad_axis_negative_suffix。

<a id="member-gfinputdevicetextprovider-methods-supports_event"></a>

### `supports_event`

- API：`public`

```gdscript
func supports_event(input_event: InputEvent, _options: Dictionary = {}) -> bool:
```

判断是否支持指定输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `_options` | 调用选项。 |

返回：支持返回 true。

结构：

- `_options`: Dictionary，为 provider 接口兼容性接收的选项。

<a id="member-gfinputdevicetextprovider-methods-get_event_text"></a>

### `get_event_text`

- API：`public`

```gdscript
func get_event_text(input_event: InputEvent, options: Dictionary = {}) -> String:
```

获取输入事件文本。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：文本；不支持时返回空字符串。

结构：

- `options`: Dictionary，可包含 joypad_button_labels、joypad_axis_labels、joypad_axis_deadzone、joypad_axis_positive_suffix 和 joypad_axis_negative_suffix。
