# GFRenderWarmupManifest

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_render_warmup_manifest.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用渲染预热清单。 只描述需要提前触碰的渲染相关资源，不绑定具体关卡、材质命名或项目加载流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`manifest_id`](#member-gfrenderwarmupmanifest-properties-manifest_id) | `var manifest_id: StringName = &""` |
| 属性 | [`entries`](#member-gfrenderwarmupmanifest-properties-entries) | `var entries: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfrenderwarmupmanifest-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_resource_path`](#member-gfrenderwarmupmanifest-methods-add_resource_path) | `func add_resource_path( entry_resource_path: String, kind: StringName = &"", type_hint: String = "", entry_metadata: Dictionary = {} ) -> int:` |
| 方法 | [`add_resource`](#member-gfrenderwarmupmanifest-methods-add_resource) | `func add_resource(resource: Resource, kind: StringName = &"", entry_metadata: Dictionary = {}) -> int:` |
| 方法 | [`append_manifest`](#member-gfrenderwarmupmanifest-methods-append_manifest) | `func append_manifest(manifest: GFRenderWarmupManifest) -> int:` |
| 方法 | [`clear`](#member-gfrenderwarmupmanifest-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_entry_count`](#member-gfrenderwarmupmanifest-methods-get_entry_count) | `func get_entry_count() -> int:` |
| 方法 | [`is_empty`](#member-gfrenderwarmupmanifest-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`normalize_entry`](#member-gfrenderwarmupmanifest-methods-normalize_entry) | `static func normalize_entry(entry: Dictionary) -> Dictionary:` |
| 方法 | [`get_entries`](#member-gfrenderwarmupmanifest-methods-get_entries) | `func get_entries() -> Array[Dictionary]:` |
| 方法 | [`describe`](#member-gfrenderwarmupmanifest-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfrenderwarmupmanifest-properties-manifest_id"></a>

### `manifest_id`

- API：`public`

```gdscript
var manifest_id: StringName = &""
```

清单稳定标识，便于诊断和队列统计。

<a id="member-gfrenderwarmupmanifest-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[Dictionary] = []
```

预热条目列表。条目字段为 resource_path、resource、kind、type_hint、metadata。

结构：

- `entries`: Array[Dictionary]，元素包含 resource_path: String、resource: Resource 或 null、kind: StringName、type_hint: String 和 metadata: Dictionary。

<a id="member-gfrenderwarmupmanifest-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，会复制到 describe() 结果中。

## 方法

<a id="member-gfrenderwarmupmanifest-methods-add_resource_path"></a>

### `add_resource_path`

- API：`public`

```gdscript
func add_resource_path( entry_resource_path: String, kind: StringName = &"", type_hint: String = "", entry_metadata: Dictionary = {} ) -> int:
```

添加资源路径条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry_resource_path` | 资源路径。 |
| `kind` | 资源类别提示。 |
| `type_hint` | ResourceLoader 类型提示。 |
| `entry_metadata` | 条目元数据。 |

返回：添加后的条目索引；失败返回 -1。

结构：

- `entry_metadata`: Dictionary[String, Variant]，会复制到 manifest 条目的 metadata。

<a id="member-gfrenderwarmupmanifest-methods-add_resource"></a>

### `add_resource`

- API：`public`

```gdscript
func add_resource(resource: Resource, kind: StringName = &"", entry_metadata: Dictionary = {}) -> int:
```

添加已持有的资源条目。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 资源实例。 |
| `kind` | 资源类别提示。 |
| `entry_metadata` | 条目元数据。 |

返回：添加后的条目索引；失败返回 -1。

结构：

- `entry_metadata`: Dictionary[String, Variant]，会复制到 manifest 条目的 metadata。

<a id="member-gfrenderwarmupmanifest-methods-append_manifest"></a>

### `append_manifest`

- API：`public`

```gdscript
func append_manifest(manifest: GFRenderWarmupManifest) -> int:
```

合并另一个清单的条目。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 来源清单。 |

返回：新增条目数量。

<a id="member-gfrenderwarmupmanifest-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空清单条目。

<a id="member-gfrenderwarmupmanifest-methods-get_entry_count"></a>

### `get_entry_count`

- API：`public`

```gdscript
func get_entry_count() -> int:
```

获取条目数量。

返回：条目数量。

<a id="member-gfrenderwarmupmanifest-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查清单是否为空。

返回：为空返回 true。

<a id="member-gfrenderwarmupmanifest-methods-normalize_entry"></a>

### `normalize_entry`

- API：`public`

```gdscript
static func normalize_entry(entry: Dictionary) -> Dictionary:
```

规范化预热条目字典。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 输入条目。 |

返回：包含 resource_path、resource、kind、type_hint、metadata 的规范化副本。

结构：

- `entry`: Dictionary，包含 resource_path、resource、kind、type_hint 和 metadata 的 manifest 条目。
- `return`: Dictionary，规范化后的 manifest 条目，包含 resource_path、resource、kind、type_hint 和 metadata。

<a id="member-gfrenderwarmupmanifest-methods-get_entries"></a>

### `get_entries`

- API：`public`

```gdscript
func get_entries() -> Array[Dictionary]:
```

获取条目副本。

返回：条目数组副本。

结构：

- `return`: Array[Dictionary]，规范化后的 manifest 条目列表。

<a id="member-gfrenderwarmupmanifest-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

描述清单。

返回：清单描述字典。

结构：

- `return`: Dictionary，包含 manifest_id、entry_count、entries 和 metadata。
