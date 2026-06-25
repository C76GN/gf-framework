# GFInputFormatter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_formatter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

输入事件与绑定的轻量文本格式化工具。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`input_event_as_text`](#member-gfinputformatter-methods-input_event_as_text) | `static func input_event_as_text(input_event: InputEvent, options: Dictionary = {}) -> String:` |
| 方法 | [`input_event_as_rich_text`](#member-gfinputformatter-methods-input_event_as_rich_text) | `static func input_event_as_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:` |
| 方法 | [`input_event_icon`](#member-gfinputformatter-methods-input_event_icon) | `static func input_event_icon(input_event: InputEvent, options: Dictionary = {}) -> Texture2D:` |
| 方法 | [`action_as_text`](#member-gfinputformatter-methods-action_as_text) | `static func action_as_text(action_name: StringName, options: Dictionary = {}) -> String:` |
| 方法 | [`action_as_rich_text`](#member-gfinputformatter-methods-action_as_rich_text) | `static func action_as_rich_text(action_name: StringName, options: Dictionary = {}) -> String:` |
| 方法 | [`action_icon`](#member-gfinputformatter-methods-action_icon) | `static func action_icon(action_name: StringName, options: Dictionary = {}) -> Texture2D:` |
| 方法 | [`binding_as_text`](#member-gfinputformatter-methods-binding_as_text) | `static func binding_as_text(binding: GFInputBinding, options: Dictionary = {}) -> String:` |
| 方法 | [`binding_as_rich_text`](#member-gfinputformatter-methods-binding_as_rich_text) | `static func binding_as_rich_text(binding: GFInputBinding, options: Dictionary = {}) -> String:` |
| 方法 | [`mapping_as_text`](#member-gfinputformatter-methods-mapping_as_text) | `static func mapping_as_text( mapping: GFInputMapping, context_id: StringName = &"", remap_config: GFInputRemapConfig = null, options: Dictionary = {} ) -> String:` |
| 方法 | [`mapping_as_rich_text`](#member-gfinputformatter-methods-mapping_as_rich_text) | `static func mapping_as_rich_text( mapping: GFInputMapping, context_id: StringName = &"", remap_config: GFInputRemapConfig = null, options: Dictionary = {} ) -> String:` |
| 方法 | [`add_text_provider`](#member-gfinputformatter-methods-add_text_provider) | `static func add_text_provider(provider: GFInputTextProvider) -> void:` |
| 方法 | [`remove_text_provider`](#member-gfinputformatter-methods-remove_text_provider) | `static func remove_text_provider(provider: GFInputTextProvider) -> void:` |
| 方法 | [`clear_text_providers`](#member-gfinputformatter-methods-clear_text_providers) | `static func clear_text_providers() -> void:` |
| 方法 | [`get_text_providers`](#member-gfinputformatter-methods-get_text_providers) | `static func get_text_providers() -> Array[GFInputTextProvider]:` |
| 方法 | [`add_icon_provider`](#member-gfinputformatter-methods-add_icon_provider) | `static func add_icon_provider(provider: GFInputIconProvider) -> void:` |
| 方法 | [`remove_icon_provider`](#member-gfinputformatter-methods-remove_icon_provider) | `static func remove_icon_provider(provider: GFInputIconProvider) -> void:` |
| 方法 | [`clear_icon_providers`](#member-gfinputformatter-methods-clear_icon_providers) | `static func clear_icon_providers() -> void:` |
| 方法 | [`get_icon_providers`](#member-gfinputformatter-methods-get_icon_providers) | `static func get_icon_providers() -> Array[GFInputIconProvider]:` |

## 方法

<a id="member-gfinputformatter-methods-input_event_as_text"></a>

### `input_event_as_text`

- API：`public`

```gdscript
static func input_event_as_text(input_event: InputEvent, options: Dictionary = {}) -> String:
```

将 Godot 输入事件格式化为通用文本。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 可选格式化参数。 |

返回：可显示文本。

结构：

- `options`: Dictionary，可包含 unbound_text 和 provider 特定格式化字段。

<a id="member-gfinputformatter-methods-input_event_as_rich_text"></a>

### `input_event_as_rich_text`

- API：`public`

```gdscript
static func input_event_as_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:
```

将 Godot 输入事件格式化为 RichTextLabel BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 可选格式化参数。 |

返回：BBCode 文本。

结构：

- `options`: Dictionary，可包含 unbound_text、icon_size 和 provider 特定富文本字段。

<a id="member-gfinputformatter-methods-input_event_icon"></a>

### `input_event_icon`

- API：`public`

```gdscript
static func input_event_icon(input_event: InputEvent, options: Dictionary = {}) -> Texture2D:
```

获取输入事件图标。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 可选格式化参数。 |

返回：图标资源。

结构：

- `options`: Dictionary，透传给已注册的图标 provider。

<a id="member-gfinputformatter-methods-action_as_text"></a>

### `action_as_text`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func action_as_text(action_name: StringName, options: Dictionary = {}) -> String:
```

将 InputMap 动作的首选事件格式化为通用文本。

参数：

| 名称 | 说明 |
|---|---|
| `action_name` | InputMap 动作名。 |
| `options` | 可选格式化参数。 |

返回：可显示文本。

结构：

- `options`: Dictionary，可包含 unbound_text、preferred_device_type、preferred_event_index 和 provider 特定格式化字段。

<a id="member-gfinputformatter-methods-action_as_rich_text"></a>

### `action_as_rich_text`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func action_as_rich_text(action_name: StringName, options: Dictionary = {}) -> String:
```

将 InputMap 动作的首选事件格式化为 RichTextLabel BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `action_name` | InputMap 动作名。 |
| `options` | 可选格式化参数。 |

返回：BBCode 文本。

结构：

- `options`: Dictionary，可包含 unbound_text、icon_size、preferred_device_type、preferred_event_index、prefer_action_icon 和 provider 特定富文本字段。

<a id="member-gfinputformatter-methods-action_icon"></a>

### `action_icon`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func action_icon(action_name: StringName, options: Dictionary = {}) -> Texture2D:
```

获取 InputMap 动作的首选图标。

参数：

| 名称 | 说明 |
|---|---|
| `action_name` | InputMap 动作名。 |
| `options` | 可选格式化参数。 |

返回：图标资源。

结构：

- `options`: Dictionary，可包含 preferred_device_type、preferred_event_index、prefer_action_icon 和 provider 特定图标字段。

<a id="member-gfinputformatter-methods-binding_as_text"></a>

### `binding_as_text`

- API：`public`

```gdscript
static func binding_as_text(binding: GFInputBinding, options: Dictionary = {}) -> String:
```

将绑定格式化为通用文本。

参数：

| 名称 | 说明 |
|---|---|
| `binding` | 输入绑定。 |
| `options` | 可选格式化参数。 |

返回：可显示文本。

结构：

- `options`: Dictionary，可包含 unbound_text 和 provider 特定格式化字段。

<a id="member-gfinputformatter-methods-binding_as_rich_text"></a>

### `binding_as_rich_text`

- API：`public`

```gdscript
static func binding_as_rich_text(binding: GFInputBinding, options: Dictionary = {}) -> String:
```

将绑定格式化为 RichTextLabel BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `binding` | 输入绑定。 |
| `options` | 可选格式化参数。 |

返回：BBCode 文本。

结构：

- `options`: Dictionary，可包含 unbound_text、icon_size 和 provider 特定富文本字段。

<a id="member-gfinputformatter-methods-mapping_as_text"></a>

### `mapping_as_text`

- API：`public`

```gdscript
static func mapping_as_text( mapping: GFInputMapping, context_id: StringName = &"", remap_config: GFInputRemapConfig = null, options: Dictionary = {} ) -> String:
```

将映射的当前有效绑定格式化为通用文本。

参数：

| 名称 | 说明 |
|---|---|
| `mapping` | 输入映射。 |
| `context_id` | 上下文标识。 |
| `remap_config` | 可选重映射配置。 |
| `options` | 可选格式化参数。 |

返回：可显示文本。

结构：

- `options`: Dictionary，可包含 unbound_text 和 provider 特定格式化字段。

<a id="member-gfinputformatter-methods-mapping_as_rich_text"></a>

### `mapping_as_rich_text`

- API：`public`

```gdscript
static func mapping_as_rich_text( mapping: GFInputMapping, context_id: StringName = &"", remap_config: GFInputRemapConfig = null, options: Dictionary = {} ) -> String:
```

将映射的当前有效绑定格式化为 RichTextLabel BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `mapping` | 输入映射。 |
| `context_id` | 上下文标识。 |
| `remap_config` | 可选重映射配置。 |
| `options` | 可选格式化参数。 |

返回：BBCode 文本。

结构：

- `options`: Dictionary，可包含 unbound_text、icon_size 和 provider 特定富文本字段。

<a id="member-gfinputformatter-methods-add_text_provider"></a>

### `add_text_provider`

- API：`public`

```gdscript
static func add_text_provider(provider: GFInputTextProvider) -> void:
```

注册文本 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 文本 provider。 |

<a id="member-gfinputformatter-methods-remove_text_provider"></a>

### `remove_text_provider`

- API：`public`

```gdscript
static func remove_text_provider(provider: GFInputTextProvider) -> void:
```

移除文本 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 文本 provider。 |

<a id="member-gfinputformatter-methods-clear_text_providers"></a>

### `clear_text_providers`

- API：`public`

```gdscript
static func clear_text_providers() -> void:
```

清空文本 provider。

<a id="member-gfinputformatter-methods-get_text_providers"></a>

### `get_text_providers`

- API：`public`

```gdscript
static func get_text_providers() -> Array[GFInputTextProvider]:
```

获取已注册文本 provider。

返回：provider 列表副本。

<a id="member-gfinputformatter-methods-add_icon_provider"></a>

### `add_icon_provider`

- API：`public`

```gdscript
static func add_icon_provider(provider: GFInputIconProvider) -> void:
```

注册图标 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 图标 provider。 |

<a id="member-gfinputformatter-methods-remove_icon_provider"></a>

### `remove_icon_provider`

- API：`public`

```gdscript
static func remove_icon_provider(provider: GFInputIconProvider) -> void:
```

移除图标 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 图标 provider。 |

<a id="member-gfinputformatter-methods-clear_icon_providers"></a>

### `clear_icon_providers`

- API：`public`

```gdscript
static func clear_icon_providers() -> void:
```

清空图标 provider。

<a id="member-gfinputformatter-methods-get_icon_providers"></a>

### `get_icon_providers`

- API：`public`

```gdscript
static func get_icon_providers() -> Array[GFInputIconProvider]:
```

获取已注册图标 provider。

返回：provider 列表副本。
