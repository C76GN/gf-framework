# GFScenePreloadEntry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_preload_entry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

场景预加载图谱中的单个节点。 描述一个场景与相邻场景的关系，以及该场景是否应进入固定缓存。 它只表达资源关系，不假设关卡、地图、菜单或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`scene_path`](#member-gfscenepreloadentry-properties-scene_path) | `var scene_path: String = ""` |
| 属性 | [`adjacent_scene_paths`](#member-gfscenepreloadentry-properties-adjacent_scene_paths) | `var adjacent_scene_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`fixed`](#member-gfscenepreloadentry-properties-fixed) | `var fixed: bool = false` |
| 属性 | [`metadata`](#member-gfscenepreloadentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_scene_path`](#member-gfscenepreloadentry-methods-get_scene_path) | `func get_scene_path() -> String:` |
| 方法 | [`get_adjacent_scene_paths`](#member-gfscenepreloadentry-methods-get_adjacent_scene_paths) | `func get_adjacent_scene_paths() -> PackedStringArray:` |
| 方法 | [`describe_entry`](#member-gfscenepreloadentry-methods-describe_entry) | `func describe_entry() -> Dictionary:` |

## 属性

<a id="member-gfscenepreloadentry-properties-scene_path"></a>

### `scene_path`

- API：`public`

```gdscript
var scene_path: String = ""
```

当前场景资源路径。

<a id="member-gfscenepreloadentry-properties-adjacent_scene_paths"></a>

### `adjacent_scene_paths`

- API：`public`

```gdscript
var adjacent_scene_paths: PackedStringArray = PackedStringArray()
```

与当前场景相邻、可能被提前预热的场景资源路径。

<a id="member-gfscenepreloadentry-properties-fixed"></a>

### `fixed`

- API：`public`

```gdscript
var fixed: bool = false
```

是否建议将该场景放入固定缓存。

<a id="member-gfscenepreloadentry-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，会复制到 describe_entry() 结果中。

## 方法

<a id="member-gfscenepreloadentry-methods-get_scene_path"></a>

### `get_scene_path`

- API：`public`

```gdscript
func get_scene_path() -> String:
```

获取规范化后的场景路径。

返回：去除首尾空白后的场景路径。

<a id="member-gfscenepreloadentry-methods-get_adjacent_scene_paths"></a>

### `get_adjacent_scene_paths`

- API：`public`

```gdscript
func get_adjacent_scene_paths() -> PackedStringArray:
```

获取去重后的相邻场景路径。

返回：相邻场景路径列表。

<a id="member-gfscenepreloadentry-methods-describe_entry"></a>

### `describe_entry`

- API：`public`

```gdscript
func describe_entry() -> Dictionary:
```

描述当前条目。

返回：条目描述字典。

结构：

- `return`: Dictionary，包含 scene_path、adjacent_scene_paths、fixed 和 metadata。
