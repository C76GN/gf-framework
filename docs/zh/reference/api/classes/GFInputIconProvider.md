# GFInputIconProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_icon_provider.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

输入图标格式化扩展点。 项目可继承此资源，把输入事件映射为 Texture2D 或 RichTextLabel BBCode。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`priority`](#member-gfinputiconprovider-properties-priority) | `var priority: int = 0` |
| 属性 | [`icon_size`](#member-gfinputiconprovider-properties-icon_size) | `var icon_size: int = 24` |
| 方法 | [`get_priority`](#member-gfinputiconprovider-methods-get_priority) | `func get_priority() -> int:` |
| 方法 | [`supports_event`](#member-gfinputiconprovider-methods-supports_event) | `func supports_event(_input_event: InputEvent, _options: Dictionary = {}) -> bool:` |
| 方法 | [`get_event_icon`](#member-gfinputiconprovider-methods-get_event_icon) | `func get_event_icon(_input_event: InputEvent, _options: Dictionary = {}) -> Texture2D:` |
| 方法 | [`get_event_rich_text`](#member-gfinputiconprovider-methods-get_event_rich_text) | `func get_event_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:` |

## 属性

<a id="member-gfinputiconprovider-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

优先级。数值越大越先尝试。

<a id="member-gfinputiconprovider-properties-icon_size"></a>

### `icon_size`

- API：`public`

```gdscript
var icon_size: int = 24
```

BBCode 图标默认尺寸。小于等于 0 时不写尺寸。

## 方法

<a id="member-gfinputiconprovider-methods-get_priority"></a>

### `get_priority`

- API：`public`

```gdscript
func get_priority() -> int:
```

获取优先级。

返回：优先级。

<a id="member-gfinputiconprovider-methods-supports_event"></a>

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

- `_options`: Dictionary，由 GFInputFormatter 传入，包含 provider 特定图标字段。

<a id="member-gfinputiconprovider-methods-get_event_icon"></a>

### `get_event_icon`

- API：`public`

```gdscript
func get_event_icon(_input_event: InputEvent, _options: Dictionary = {}) -> Texture2D:
```

获取输入事件图标。

参数：

| 名称 | 说明 |
|---|---|
| `_input_event` | 输入事件。 |
| `_options` | 调用选项。 |

返回：图标资源；返回 null 会回退到后续 provider。

结构：

- `_options`: Dictionary，由 GFInputFormatter 传入，包含 provider 特定图标字段。

<a id="member-gfinputiconprovider-methods-get_event_rich_text"></a>

### `get_event_rich_text`

- API：`public`

```gdscript
func get_event_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:
```

获取输入事件 RichTextLabel BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：BBCode；返回空字符串会回退到文本格式化。

结构：

- `options`: Dictionary，可包含 icon_size 和 provider 特定富文本字段。
