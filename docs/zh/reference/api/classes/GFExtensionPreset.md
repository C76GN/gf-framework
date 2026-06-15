# GFExtensionPreset

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_preset.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`5.0.0`

GF 扩展启用组合描述。 Preset 只描述一组要写入 `gf/extensions/enabled` 的扩展 ID，不改变 manifest 依赖、 不表示扩展之间存在硬依赖，也不承载下载、安装包或跨扩展编排逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`id`](#member-gfextensionpreset-properties-id) | `var id: StringName = &""` |
| 属性 | [`display_name`](#member-gfextensionpreset-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`description`](#member-gfextensionpreset-properties-description) | `var description: String = ""` |
| 属性 | [`extension_ids`](#member-gfextensionpreset-properties-extension_ids) | `var extension_ids: Array[String] = []` |
| 属性 | [`tags`](#member-gfextensionpreset-properties-tags) | `var tags: Array[String] = []` |
| 属性 | [`source_path`](#member-gfextensionpreset-properties-source_path) | `var source_path: String = ""` |
| 方法 | [`from_dictionary`](#member-gfextensionpreset-methods-from_dictionary) | `static func from_dictionary(data: Dictionary, preset_source_path: String = "") -> GFExtensionPreset:` |
| 方法 | [`from_json_file`](#member-gfextensionpreset-methods-from_json_file) | `static func from_json_file(path: String) -> GFExtensionPreset:` |
| 方法 | [`to_dictionary`](#member-gfextensionpreset-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`is_valid`](#member-gfextensionpreset-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_validation_errors`](#member-gfextensionpreset-methods-get_validation_errors) | `func get_validation_errors() -> Array[String]:` |

## 属性

<a id="member-gfextensionpreset-properties-id"></a>

### `id`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var id: StringName = &""
```

Preset 稳定 ID。

<a id="member-gfextensionpreset-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var display_name: String = ""
```

面向用户显示的 preset 名称。

<a id="member-gfextensionpreset-properties-description"></a>

### `description`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var description: String = ""
```

Preset 说明。

<a id="member-gfextensionpreset-properties-extension_ids"></a>

### `extension_ids`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var extension_ids: Array[String] = []
```

要启用的扩展 ID 列表。

<a id="member-gfextensionpreset-properties-tags"></a>

### `tags`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var tags: Array[String] = []
```

便于编辑器工具筛选的标签。

<a id="member-gfextensionpreset-properties-source_path"></a>

### `source_path`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var source_path: String = ""
```

Preset 来源文件路径。内置或代码注册的 preset 可为空。

## 方法

<a id="member-gfextensionpreset-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_dictionary(data: Dictionary, preset_source_path: String = "") -> GFExtensionPreset:
```

从字典创建扩展 preset。

参数：

| 名称 | 说明 |
|---|---|
| `data` | preset 字典。 |
| `preset_source_path` | preset 来源文件路径。 |

返回：扩展 preset 实例。

结构：

- `data`: Dictionary containing id, display_name, description, extension_ids, and tags.

<a id="member-gfextensionpreset-methods-from_json_file"></a>

### `from_json_file`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_json_file(path: String) -> GFExtensionPreset:
```

从 JSON 文件读取扩展 preset。

参数：

| 名称 | 说明 |
|---|---|
| `path` | preset JSON 文件路径。 |

返回：读取成功时返回 preset；失败时返回 null。

<a id="member-gfextensionpreset-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：preset 字典副本。

结构：

- `return`: Dictionary matching the extension preset JSON shape.

<a id="member-gfextensionpreset-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_valid() -> bool:
```

检查 preset 是否满足基本规范。

返回：满足规范时返回 true。

<a id="member-gfextensionpreset-methods-get_validation_errors"></a>

### `get_validation_errors`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_validation_errors() -> Array[String]:
```

获取 preset 规范错误。

返回：错误消息列表。
