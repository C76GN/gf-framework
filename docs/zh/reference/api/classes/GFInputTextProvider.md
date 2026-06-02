# GFInputTextProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_text_provider.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

输入文本格式化扩展点。 项目可继承此资源，为特定设备、平台、本地化或图标字体提供自定义文本。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`priority`](#member-gfinputtextprovider-properties-priority) | `var priority: int = 0` |
| 方法 | [`get_priority`](#member-gfinputtextprovider-methods-get_priority) | `func get_priority() -> int:` |
| 方法 | [`supports_event`](#member-gfinputtextprovider-methods-supports_event) | `func supports_event(_input_event: InputEvent, _options: Dictionary = {}) -> bool:` |
| 方法 | [`get_event_text`](#member-gfinputtextprovider-methods-get_event_text) | `func get_event_text(_input_event: InputEvent, _options: Dictionary = {}) -> String:` |

## 属性

<a id="member-gfinputtextprovider-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

优先级。数值越大越先尝试。

## 方法

<a id="member-gfinputtextprovider-methods-get_priority"></a>

### `get_priority`

- API：`public`

```gdscript
func get_priority() -> int:
```

获取优先级。

返回：优先级。

<a id="member-gfinputtextprovider-methods-supports_event"></a>

### `supports_event`

- API：`public`

```gdscript
func supports_event(_input_event: InputEvent, _options: Dictionary = {}) -> bool:
```

判断是否支持指定输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `_input_event` | 输入事件。 |
| `_options` | 调用选项。 |

返回：支持返回 true。

结构：

- `_options`: Dictionary，由 GFInputFormatter 传入，包含 provider 特定格式化字段。

<a id="member-gfinputtextprovider-methods-get_event_text"></a>

### `get_event_text`

- API：`public`

```gdscript
func get_event_text(_input_event: InputEvent, _options: Dictionary = {}) -> String:
```

获取输入事件文本。

参数：

| 名称 | 说明 |
|---|---|
| `_input_event` | 输入事件。 |
| `_options` | 调用选项。 |

返回：文本；返回空字符串会回退到后续 provider 或默认格式化。

结构：

- `_options`: Dictionary，由 GFInputFormatter 传入，包含 provider 特定格式化字段。
