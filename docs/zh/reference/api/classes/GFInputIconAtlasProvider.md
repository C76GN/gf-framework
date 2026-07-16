# GFInputIconAtlasProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_icon_atlas_provider.gd`
- 模块：`Standard`
- 继承：`GFInputIconProvider`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可配置输入图标图集 Provider。 将 InputEvent 归一化为通用图标键，再通过显式映射或路径模板解析 Texture2D / RichText 图标。 框架不附带图标资源，也不规定项目的美术风格或平台命名。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`root_path`](#member-gfinputiconatlasprovider-properties-root_path) | `var root_path: String = ""` |
| 属性 | [`style`](#member-gfinputiconatlasprovider-properties-style) | `var style: StringName = &"default"` |
| 属性 | [`platform`](#member-gfinputiconatlasprovider-properties-platform) | `var platform: StringName = &""` |
| 属性 | [`fallback_platform`](#member-gfinputiconatlasprovider-properties-fallback_platform) | `var fallback_platform: StringName = &"generic"` |
| 属性 | [`path_pattern`](#member-gfinputiconatlasprovider-properties-path_pattern) | `var path_pattern: String = "{root}/{style}/{platform}/{icon}.png"` |
| 属性 | [`icon_paths`](#member-gfinputiconatlasprovider-properties-icon_paths) | `var icon_paths: Dictionary = {}` |
| 属性 | [`icon_textures`](#member-gfinputiconatlasprovider-properties-icon_textures) | `var icon_textures: Dictionary = {}` |
| 属性 | [`rich_text_separator`](#member-gfinputiconatlasprovider-properties-rich_text_separator) | `var rich_text_separator: String = " "` |
| 属性 | [`split_key_modifiers`](#member-gfinputiconatlasprovider-properties-split_key_modifiers) | `var split_key_modifiers: bool = true` |
| 属性 | [`cache_missing_paths`](#member-gfinputiconatlasprovider-properties-cache_missing_paths) | `var cache_missing_paths: bool = true` |
| 属性 | [`max_cached_textures`](#member-gfinputiconatlasprovider-properties-max_cached_textures) | `var max_cached_textures: int = 128` |
| 属性 | [`max_cached_missing_paths`](#member-gfinputiconatlasprovider-properties-max_cached_missing_paths) | `var max_cached_missing_paths: int = 256` |
| 方法 | [`set_icon_path`](#member-gfinputiconatlasprovider-methods-set_icon_path) | `func set_icon_path(icon_key: StringName, icon_resource_path: String) -> void:` |
| 方法 | [`set_icon_texture`](#member-gfinputiconatlasprovider-methods-set_icon_texture) | `func set_icon_texture(icon_key: StringName, texture: Texture2D) -> void:` |
| 方法 | [`clear_cache`](#member-gfinputiconatlasprovider-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`supports_event`](#member-gfinputiconatlasprovider-methods-supports_event) | `func supports_event(input_event: InputEvent, options: Dictionary = {}) -> bool:` |
| 方法 | [`get_event_icon`](#member-gfinputiconatlasprovider-methods-get_event_icon) | `func get_event_icon(input_event: InputEvent, options: Dictionary = {}) -> Texture2D:` |
| 方法 | [`get_event_rich_text`](#member-gfinputiconatlasprovider-methods-get_event_rich_text) | `func get_event_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:` |
| 方法 | [`get_event_icon_path`](#member-gfinputiconatlasprovider-methods-get_event_icon_path) | `func get_event_icon_path(input_event: InputEvent, options: Dictionary = {}) -> String:` |
| 方法 | [`resolve_event_icon_key`](#member-gfinputiconatlasprovider-methods-resolve_event_icon_key) | `func resolve_event_icon_key(input_event: InputEvent, options: Dictionary = {}) -> StringName:` |
| 方法 | [`get_event_icon_candidates`](#member-gfinputiconatlasprovider-methods-get_event_icon_candidates) | `func get_event_icon_candidates(input_event: InputEvent, options: Dictionary = {}) -> PackedStringArray:` |

## 属性

<a id="member-gfinputiconatlasprovider-properties-root_path"></a>

### `root_path`

- API：`public`

```gdscript
var root_path: String = ""
```

图标根目录。路径模板中的 {root} 会使用该值。

<a id="member-gfinputiconatlasprovider-properties-style"></a>

### `style`

- API：`public`

```gdscript
var style: StringName = &"default"
```

图标风格名。路径模板中的 {style} 会使用该值。

<a id="member-gfinputiconatlasprovider-properties-platform"></a>

### `platform`

- API：`public`

```gdscript
var platform: StringName = &""
```

平台名。为空时使用 options.platform 或 fallback_platform。

<a id="member-gfinputiconatlasprovider-properties-fallback_platform"></a>

### `fallback_platform`

- API：`public`

```gdscript
var fallback_platform: StringName = &"generic"
```

平台回退名。

<a id="member-gfinputiconatlasprovider-properties-path_pattern"></a>

### `path_pattern`

- API：`public`

```gdscript
var path_pattern: String = "{root}/{style}/{platform}/{icon}.png"
```

路径模板。可使用 {root}、{style}、{platform}、{icon}。

<a id="member-gfinputiconatlasprovider-properties-icon_paths"></a>

### `icon_paths`

- API：`public`

```gdscript
var icon_paths: Dictionary = {}
```

显式路径映射，key 为 get_event_icon_candidates() 产生的图标键。

结构：

- `icon_paths`: Dictionary，以 StringName 或 String 图标键为键，值为 String Texture2D 资源路径。

<a id="member-gfinputiconatlasprovider-properties-icon_textures"></a>

### `icon_textures`

- API：`public`

```gdscript
var icon_textures: Dictionary = {}
```

显式纹理映射，key 为 get_event_icon_candidates() 产生的图标键。

结构：

- `icon_textures`: Dictionary，以 StringName 或 String 图标键为键，值为 Texture2D。

<a id="member-gfinputiconatlasprovider-properties-rich_text_separator"></a>

### `rich_text_separator`

- API：`public`

```gdscript
var rich_text_separator: String = " "
```

RichText 输出多个图标时使用的分隔文本。

<a id="member-gfinputiconatlasprovider-properties-split_key_modifiers"></a>

### `split_key_modifiers`

- API：`public`

```gdscript
var split_key_modifiers: bool = true
```

是否为带修饰键的键盘事件输出多个图标。

<a id="member-gfinputiconatlasprovider-properties-cache_missing_paths"></a>

### `cache_missing_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var cache_missing_paths: bool = true
```

是否缓存缺失的图标路径。

<a id="member-gfinputiconatlasprovider-properties-max_cached_textures"></a>

### `max_cached_textures`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_cached_textures: int = 128
```

成功加载纹理缓存容量；小于等于 0 表示不缓存新纹理。

<a id="member-gfinputiconatlasprovider-properties-max_cached_missing_paths"></a>

### `max_cached_missing_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_cached_missing_paths: int = 256
```

缺失路径缓存容量；小于等于 0 表示不缓存缺失路径。

## 方法

<a id="member-gfinputiconatlasprovider-methods-set_icon_path"></a>

### `set_icon_path`

- API：`public`

```gdscript
func set_icon_path(icon_key: StringName, icon_resource_path: String) -> void:
```

设置图标路径映射。

参数：

| 名称 | 说明 |
|---|---|
| `icon_key` | 图标键。 |
| `icon_resource_path` | Texture2D 资源路径。 |

<a id="member-gfinputiconatlasprovider-methods-set_icon_texture"></a>

### `set_icon_texture`

- API：`public`

```gdscript
func set_icon_texture(icon_key: StringName, texture: Texture2D) -> void:
```

设置图标纹理映射。

参数：

| 名称 | 说明 |
|---|---|
| `icon_key` | 图标键。 |
| `texture` | 图标纹理。 |

<a id="member-gfinputiconatlasprovider-methods-clear_cache"></a>

### `clear_cache`

- API：`public`

```gdscript
func clear_cache() -> void:
```

清空已加载的纹理缓存。

<a id="member-gfinputiconatlasprovider-methods-supports_event"></a>

### `supports_event`

- API：`public`

```gdscript
func supports_event(input_event: InputEvent, options: Dictionary = {}) -> bool:
```

判断是否支持指定输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：支持返回 true。

结构：

- `options`: Dictionary，可包含 allow_missing_paths、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。

<a id="member-gfinputiconatlasprovider-methods-get_event_icon"></a>

### `get_event_icon`

- API：`public`

```gdscript
func get_event_icon(input_event: InputEvent, options: Dictionary = {}) -> Texture2D:
```

获取输入事件图标。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：图标纹理；不存在时返回 null。

结构：

- `options`: Dictionary，可包含 allow_missing_paths、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。

<a id="member-gfinputiconatlasprovider-methods-get_event_rich_text"></a>

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

返回：BBCode；无法解析时返回空字符串。

结构：

- `options`: Dictionary，可包含 allow_missing_paths、icon_size、rich_text_separator、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。

<a id="member-gfinputiconatlasprovider-methods-get_event_icon_path"></a>

### `get_event_icon_path`

- API：`public`

```gdscript
func get_event_icon_path(input_event: InputEvent, options: Dictionary = {}) -> String:
```

获取输入事件的首选图标路径。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：图标路径；无法解析时返回空字符串。

结构：

- `options`: Dictionary，可包含 allow_missing_paths、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。

<a id="member-gfinputiconatlasprovider-methods-resolve_event_icon_key"></a>

### `resolve_event_icon_key`

- API：`public`

```gdscript
func resolve_event_icon_key(input_event: InputEvent, options: Dictionary = {}) -> StringName:
```

获取输入事件的首选图标键。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：图标键；无法解析时返回空 StringName。

结构：

- `options`: Dictionary，可包含 split_key_modifiers 和 include_key_modifier_combo。

<a id="member-gfinputiconatlasprovider-methods-get_event_icon_candidates"></a>

### `get_event_icon_candidates`

- API：`public`

```gdscript
func get_event_icon_candidates(input_event: InputEvent, options: Dictionary = {}) -> PackedStringArray:
```

获取输入事件可能使用的图标键列表。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `options` | 调用选项。 |

返回：图标键列表，按优先级排序。

结构：

- `options`: Dictionary，可包含 split_key_modifiers 和 include_key_modifier_combo。
