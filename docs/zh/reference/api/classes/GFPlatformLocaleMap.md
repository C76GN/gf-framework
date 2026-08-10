# GFPlatformLocaleMap

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/text/gf_platform_locale_map.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

平台语言键到 Godot locale 的映射表。 该资源用于让 Steam、微信、主机平台或自建启动器等 adapter 把自身语言键转换为 Godot TranslationServer 使用的 locale。GF 不内置任何具体平台表。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`entries`](#member-gfplatformlocalemap-properties-entries) | `var entries: Array[Dictionary] = []` |
| 属性 | [`default_locale`](#member-gfplatformlocalemap-properties-default_locale) | `var default_locale: String = ""` |
| 方法 | [`set_mapping`](#member-gfplatformlocalemap-methods-set_mapping) | `func set_mapping( platform_id: StringName, platform_locale: String, locale: String, fallback_locale: String = "", display_name: String = "" ) -> Dictionary:` |
| 方法 | [`get_mapping`](#member-gfplatformlocalemap-methods-get_mapping) | `func get_mapping(platform_id: StringName, platform_locale: String) -> Dictionary:` |
| 方法 | [`map_locale`](#member-gfplatformlocalemap-methods-map_locale) | `func map_locale(platform_id: StringName, platform_locale: String, fallback_value: String = "") -> String:` |
| 方法 | [`map_fallback_locale`](#member-gfplatformlocalemap-methods-map_fallback_locale) | `func map_fallback_locale(platform_id: StringName, platform_locale: String, fallback_value: String = "") -> String:` |
| 方法 | [`erase_mapping`](#member-gfplatformlocalemap-methods-erase_mapping) | `func erase_mapping(platform_id: StringName, platform_locale: String) -> bool:` |
| 方法 | [`to_dict`](#member-gfplatformlocalemap-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformlocalemap-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_map`](#member-gfplatformlocalemap-methods-duplicate_map) | `func duplicate_map() -> GFPlatformLocaleMap:` |
| 方法 | [`make_entry`](#member-gfplatformlocalemap-methods-make_entry) | `static func make_entry( platform_id: StringName, platform_locale: String, locale: String, fallback_locale: String = "", display_name: String = "" ) -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfplatformlocalemap-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformLocaleMap:` |

## 属性

<a id="member-gfplatformlocalemap-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var entries: Array[Dictionary] = []
```

映射表条目。

结构：

- `entries`: Array[Dictionary]，每项包含 platform_id、platform_locale、locale、fallback_locale 和 display_name。

<a id="member-gfplatformlocalemap-properties-default_locale"></a>

### `default_locale`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var default_locale: String = ""
```

未命中时返回的默认 locale。

## 方法

<a id="member-gfplatformlocalemap-methods-set_mapping"></a>

### `set_mapping`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_mapping( platform_id: StringName, platform_locale: String, locale: String, fallback_locale: String = "", display_name: String = "" ) -> Dictionary:
```

设置或替换映射条目。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |
| `platform_locale` | 平台语言键。 |
| `locale` | Godot locale。 |
| `fallback_locale` | fallback Godot locale。 |
| `display_name` | 展示名。 |

返回：写入后的条目副本。

结构：

- `return`: Dictionary locale mapping entry.

<a id="member-gfplatformlocalemap-methods-get_mapping"></a>

### `get_mapping`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_mapping(platform_id: StringName, platform_locale: String) -> Dictionary:
```

获取映射条目。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |
| `platform_locale` | 平台语言键。 |

返回：映射条目副本；不存在时为空字典。

结构：

- `return`: Dictionary locale mapping entry.

<a id="member-gfplatformlocalemap-methods-map_locale"></a>

### `map_locale`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func map_locale(platform_id: StringName, platform_locale: String, fallback_value: String = "") -> String:
```

映射到 Godot locale。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |
| `platform_locale` | 平台语言键。 |
| `fallback_value` | 未命中时的调用方 fallback。 |

返回：Godot locale。

<a id="member-gfplatformlocalemap-methods-map_fallback_locale"></a>

### `map_fallback_locale`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func map_fallback_locale(platform_id: StringName, platform_locale: String, fallback_value: String = "") -> String:
```

映射到 fallback Godot locale。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |
| `platform_locale` | 平台语言键。 |
| `fallback_value` | 未命中时的调用方 fallback。 |

返回：fallback Godot locale。

<a id="member-gfplatformlocalemap-methods-erase_mapping"></a>

### `erase_mapping`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func erase_mapping(platform_id: StringName, platform_locale: String) -> bool:
```

移除映射条目。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |
| `platform_locale` | 平台语言键。 |

返回：找到并移除时返回 true。

<a id="member-gfplatformlocalemap-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：映射表字典。

结构：

- `return`: Dictionary with entries and default_locale.

<a id="member-gfplatformlocalemap-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用映射表。 条目按输入顺序应用；同一 platform_id 与规范化 platform_locale 重复出现时， 后一条覆盖前一条，与连续调用 `set_mapping()` 的语义一致。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 映射表字典。 |

结构：

- `data`: Dictionary with entries and default_locale.

<a id="member-gfplatformlocalemap-methods-duplicate_map"></a>

### `duplicate_map`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_map() -> GFPlatformLocaleMap:
```

创建映射表深拷贝。

返回：新映射表。

<a id="member-gfplatformlocalemap-methods-make_entry"></a>

### `make_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_entry( platform_id: StringName, platform_locale: String, locale: String, fallback_locale: String = "", display_name: String = "" ) -> Dictionary:
```

创建映射条目。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |
| `platform_locale` | 平台语言键。 |
| `locale` | Godot locale。 |
| `fallback_locale` | fallback Godot locale。 |
| `display_name` | 展示名。 |

返回：映射条目。

结构：

- `return`: Dictionary locale mapping entry.

<a id="member-gfplatformlocalemap-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformLocaleMap:
```

从字典创建映射表。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 映射表字典。 |

返回：新映射表。

结构：

- `data`: Dictionary with entries and default_locale.
