# GFSceneTransitionConfig

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_transition_config.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

场景切换配置资源。 用资源描述一次场景切换所需的目标场景、loading scene、缓存策略、切换参数和扩展参数。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_scene_path`](#member-gfscenetransitionconfig-properties-target_scene_path) | `var target_scene_path: String = ""` |
| 属性 | [`loading_scene_path`](#member-gfscenetransitionconfig-properties-loading_scene_path) | `var loading_scene_path: String = ""` |
| 属性 | [`preload_before_change`](#member-gfscenetransitionconfig-properties-preload_before_change) | `var preload_before_change: bool = false` |
| 属性 | [`preload_as_fixed_cache`](#member-gfscenetransitionconfig-properties-preload_as_fixed_cache) | `var preload_as_fixed_cache: bool = false` |
| 属性 | [`cache_loaded_scene`](#member-gfscenetransitionconfig-properties-cache_loaded_scene) | `var cache_loaded_scene: bool = true` |
| 属性 | [`params`](#member-gfscenetransitionconfig-properties-params) | `var params: Dictionary = {}` |
| 属性 | [`minimum_duration_seconds`](#member-gfscenetransitionconfig-properties-minimum_duration_seconds) | `var minimum_duration_seconds: float = 0.0` |
| 属性 | [`metadata`](#member-gfscenetransitionconfig-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfscenetransitionconfig-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfscenetransitionconfig-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfscenetransitionconfig-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSceneTransitionConfig:` |

## 属性

<a id="member-gfscenetransitionconfig-properties-target_scene_path"></a>

### `target_scene_path`

- API：`public`

```gdscript
var target_scene_path: String = ""
```

目标场景路径。

<a id="member-gfscenetransitionconfig-properties-loading_scene_path"></a>

### `loading_scene_path`

- API：`public`

```gdscript
var loading_scene_path: String = ""
```

可选 loading scene 路径。

<a id="member-gfscenetransitionconfig-properties-preload_before_change"></a>

### `preload_before_change`

- API：`public`

```gdscript
var preload_before_change: bool = false
```

切换前是否先发起预加载。

<a id="member-gfscenetransitionconfig-properties-preload_as_fixed_cache"></a>

### `preload_as_fixed_cache`

- API：`public`

```gdscript
var preload_as_fixed_cache: bool = false
```

preload_before_change 为 true 时，是否把预加载结果写入固定缓存。

<a id="member-gfscenetransitionconfig-properties-cache_loaded_scene"></a>

### `cache_loaded_scene`

- API：`public`

```gdscript
var cache_loaded_scene: bool = true
```

本次切换完成后是否允许写入 GFSceneUtility 缓存。

<a id="member-gfscenetransitionconfig-properties-params"></a>

### `params`

- API：`public`

```gdscript
var params: Dictionary = {}
```

本次切换传递给目标场景或项目流程的参数。

结构：

- `params`: Dictionary[String, Variant]，复制到 GFSceneUtility 的场景切换参数。

<a id="member-gfscenetransitionconfig-properties-minimum_duration_seconds"></a>

### `minimum_duration_seconds`

- API：`public`

```gdscript
var minimum_duration_seconds: float = 0.0
```

loading scene 最短保留秒数；为 0 时不额外等待。

<a id="member-gfscenetransitionconfig-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义参数。

结构：

- `metadata`: Dictionary[String, Variant]，复制到 to_dict() 的项目自定义元数据。

## 方法

<a id="member-gfscenetransitionconfig-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：配置字典。

结构：

- `return`: Dictionary，包含 target_scene_path、loading_scene_path、preload_before_change、preload_as_fixed_cache、cache_loaded_scene、params、minimum_duration_seconds 和 metadata。

<a id="member-gfscenetransitionconfig-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典配置。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 配置字典。 |

结构：

- `data`: Dictionary，由 to_dict() 生成。

<a id="member-gfscenetransitionconfig-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFSceneTransitionConfig:
```

从 Dictionary 创建配置。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 配置字典。 |

返回：新配置。

结构：

- `data`: Dictionary，由 to_dict() 生成。
