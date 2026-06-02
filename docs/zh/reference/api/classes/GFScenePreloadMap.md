# GFScenePreloadMap

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_preload_map.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用场景预加载关系图。 用资源描述场景间的相邻关系，供 GFSceneUtility 或项目层根据当前场景计算预加载计划。 图谱只关注资源路径和缓存策略，不绑定地图、关卡、菜单或具体业务流。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`default_radius`](#member-gfscenepreloadmap-properties-default_radius) | `var default_radius: int = 1:` |
| 属性 | [`max_scheduled_scenes`](#member-gfscenepreloadmap-properties-max_scheduled_scenes) | `var max_scheduled_scenes: int = 0:` |
| 属性 | [`fixed_scene_paths`](#member-gfscenepreloadmap-properties-fixed_scene_paths) | `var fixed_scene_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`entries`](#member-gfscenepreloadmap-properties-entries) | `var entries: Array[GFScenePreloadEntry] = []` |
| 属性 | [`metadata`](#member-gfscenepreloadmap-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_entry`](#member-gfscenepreloadmap-methods-get_entry) | `func get_entry(scene_path: String) -> GFScenePreloadEntry:` |
| 方法 | [`get_fixed_scene_paths`](#member-gfscenepreloadmap-methods-get_fixed_scene_paths) | `func get_fixed_scene_paths() -> PackedStringArray:` |
| 方法 | [`get_neighbor_scene_paths`](#member-gfscenepreloadmap-methods-get_neighbor_scene_paths) | `func get_neighbor_scene_paths( scene_path: String, radius: int = -1, include_source: bool = false ) -> PackedStringArray:` |
| 方法 | [`get_preload_plan`](#member-gfscenepreloadmap-methods-get_preload_plan) | `func get_preload_plan( scene_path: String, radius: int = -1, include_fixed: bool = true ) -> Dictionary:` |
| 方法 | [`validate_map`](#member-gfscenepreloadmap-methods-validate_map) | `func validate_map(options: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfscenepreloadmap-properties-default_radius"></a>

### `default_radius`

- API：`public`

```gdscript
var default_radius: int = 1:
```

默认相邻搜索半径；0 表示只使用固定预加载路径。

<a id="member-gfscenepreloadmap-properties-max_scheduled_scenes"></a>

### `max_scheduled_scenes`

- API：`public`

```gdscript
var max_scheduled_scenes: int = 0:
```

单次计划最多返回的临时相邻场景数量；0 表示不限制。

<a id="member-gfscenepreloadmap-properties-fixed_scene_paths"></a>

### `fixed_scene_paths`

- API：`public`

```gdscript
var fixed_scene_paths: PackedStringArray = PackedStringArray()
```

始终参与预加载计划的固定场景路径。

<a id="member-gfscenepreloadmap-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFScenePreloadEntry] = []
```

场景关系条目列表。

<a id="member-gfscenepreloadmap-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，会复制到预加载计划报告中。

## 方法

<a id="member-gfscenepreloadmap-methods-get_entry"></a>

### `get_entry`

- API：`public`

```gdscript
func get_entry(scene_path: String) -> GFScenePreloadEntry:
```

获取指定路径对应的条目。

参数：

| 名称 | 说明 |
|---|---|
| `scene_path` | 场景资源路径。 |

返回：对应条目；未找到时返回 null。

<a id="member-gfscenepreloadmap-methods-get_fixed_scene_paths"></a>

### `get_fixed_scene_paths`

- API：`public`

```gdscript
func get_fixed_scene_paths() -> PackedStringArray:
```

获取去重后的固定预加载路径。

返回：固定预加载路径列表。

<a id="member-gfscenepreloadmap-methods-get_neighbor_scene_paths"></a>

### `get_neighbor_scene_paths`

- API：`public`

```gdscript
func get_neighbor_scene_paths( scene_path: String, radius: int = -1, include_source: bool = false ) -> PackedStringArray:
```

获取指定场景周围的相邻场景路径。

参数：

| 名称 | 说明 |
|---|---|
| `scene_path` | 当前场景资源路径。 |
| `radius` | 搜索半径；小于 0 时使用 default_radius。 |
| `include_source` | 是否包含 scene_path 自身。 |

返回：相邻场景路径列表。

<a id="member-gfscenepreloadmap-methods-get_preload_plan"></a>

### `get_preload_plan`

- API：`public`

```gdscript
func get_preload_plan( scene_path: String, radius: int = -1, include_fixed: bool = true ) -> Dictionary:
```

获取指定场景的预加载计划。

参数：

| 名称 | 说明 |
|---|---|
| `scene_path` | 当前场景资源路径。 |
| `radius` | 搜索半径；小于 0 时使用 default_radius。 |
| `include_fixed` | 是否包含固定预加载路径。 |

返回：预加载计划字典。

结构：

- `return`: Dictionary，包含 source_path、radius、include_fixed、fixed_paths、temporary_paths、paths 和 metadata。

<a id="member-gfscenepreloadmap-methods-validate_map"></a>

### `validate_map`

- API：`public`

```gdscript
func validate_map(options: Dictionary = {}) -> Dictionary:
```

校验预加载图谱结构。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 check_exists。 |

返回：校验报告字典。

结构：

- `options`: Dictionary，包含 check_exists: bool。
- `return`: Dictionary，由 GFValidationReport.to_dict() 生成的校验报告。
