# GFSceneUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

场景与流程切换管理器。 封装原生场景切换，支持带有 `loading scene` 的异步加载、PackedScene 资源预加载缓存、切换参数、场景历史，并可在切换完成后清理不需要跨场景保留的 `System/Model`。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`scene_load_started`](#member-gfsceneutility-signals-scene_load_started) | `signal scene_load_started(path: String)` |
| 信号 | [`scene_load_progress`](#member-gfsceneutility-signals-scene_load_progress) | `signal scene_load_progress(path: String, progress: float)` |
| 信号 | [`scene_load_completed`](#member-gfsceneutility-signals-scene_load_completed) | `signal scene_load_completed(path: String, scene: PackedScene)` |
| 信号 | [`scene_load_failed`](#member-gfsceneutility-signals-scene_load_failed) | `signal scene_load_failed(path: String)` |
| 信号 | [`scene_preload_started`](#member-gfsceneutility-signals-scene_preload_started) | `signal scene_preload_started(path: String)` |
| 信号 | [`scene_preload_progress`](#member-gfsceneutility-signals-scene_preload_progress) | `signal scene_preload_progress(path: String, progress: float)` |
| 信号 | [`scene_preload_completed`](#member-gfsceneutility-signals-scene_preload_completed) | `signal scene_preload_completed(path: String, scene: PackedScene)` |
| 信号 | [`scene_preload_failed`](#member-gfsceneutility-signals-scene_preload_failed) | `signal scene_preload_failed(path: String)` |
| 信号 | [`scene_preload_cancelled`](#member-gfsceneutility-signals-scene_preload_cancelled) | `signal scene_preload_cancelled(path: String)` |
| 信号 | [`scene_switch_started`](#member-gfsceneutility-signals-scene_switch_started) | `signal scene_switch_started(path: String, previous_path: String)` |
| 信号 | [`scene_switch_completed`](#member-gfsceneutility-signals-scene_switch_completed) | `signal scene_switch_completed(path: String, previous_path: String)` |
| 信号 | [`scene_switch_failed`](#member-gfsceneutility-signals-scene_switch_failed) | `signal scene_switch_failed(path: String, previous_path: String, message: String)` |
| 信号 | [`loading_scene_shown`](#member-gfsceneutility-signals-loading_scene_shown) | `signal loading_scene_shown(path: String)` |
| 信号 | [`loading_scene_hidden`](#member-gfsceneutility-signals-loading_scene_hidden) | `signal loading_scene_hidden(path: String)` |
| 信号 | [`scene_cache_added`](#member-gfsceneutility-signals-scene_cache_added) | `signal scene_cache_added(path: String, fixed: bool)` |
| 信号 | [`scene_cache_removed`](#member-gfsceneutility-signals-scene_cache_removed) | `signal scene_cache_removed(path: String, fixed: bool)` |
| 枚举 | [`SceneResourceState`](#member-gfsceneutility-enums-sceneresourcestate) | `enum SceneResourceState` |
| 属性 | [`max_preloaded_scene_resources`](#member-gfsceneutility-properties-max_preloaded_scene_resources) | `var max_preloaded_scene_resources: int:` |
| 属性 | [`cache_loaded_scenes`](#member-gfsceneutility-properties-cache_loaded_scenes) | `var cache_loaded_scenes: bool = true` |
| 属性 | [`scene_preload_map`](#member-gfsceneutility-properties-scene_preload_map) | `var scene_preload_map: GFScenePreloadMap = null` |
| 属性 | [`auto_preload_map_neighbors_on_switch`](#member-gfsceneutility-properties-auto_preload_map_neighbors_on_switch) | `var auto_preload_map_neighbors_on_switch: bool = true` |
| 属性 | [`scene_preload_map_radius`](#member-gfsceneutility-properties-scene_preload_map_radius) | `var scene_preload_map_radius: int = -1:` |
| 属性 | [`loading_screen_fade_in_method`](#member-gfsceneutility-properties-loading_screen_fade_in_method) | `var loading_screen_fade_in_method: StringName = &"fade_in"` |
| 属性 | [`loading_screen_fade_out_method`](#member-gfsceneutility-properties-loading_screen_fade_out_method) | `var loading_screen_fade_out_method: StringName = &"fade_out"` |
| 属性 | [`loading_screen_progress_method`](#member-gfsceneutility-properties-loading_screen_progress_method) | `var loading_screen_progress_method: StringName = &"set_progress"` |
| 属性 | [`loading_screen_progress_fallback_method`](#member-gfsceneutility-properties-loading_screen_progress_fallback_method) | `var loading_screen_progress_fallback_method: StringName = &"update_progress"` |
| 属性 | [`loading_screen_error_method`](#member-gfsceneutility-properties-loading_screen_error_method) | `var loading_screen_error_method: StringName = &"show_error"` |
| 属性 | [`default_transition_minimum_seconds`](#member-gfsceneutility-properties-default_transition_minimum_seconds) | `var default_transition_minimum_seconds: float = 0.0` |
| 属性 | [`max_scene_history`](#member-gfsceneutility-properties-max_scene_history) | `var max_scene_history: int:` |
| 方法 | [`init`](#member-gfsceneutility-methods-init) | `func init() -> void:` |
| 方法 | [`tick`](#member-gfsceneutility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfsceneutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`load_scene_async`](#member-gfsceneutility-methods-load_scene_async) | `func load_scene_async( path: String, loading_scene_path: String = "", params: Dictionary = {}, minimum_duration_seconds: float = -1.0 ) -> Error:` |
| 方法 | [`load_scene_with_transition`](#member-gfsceneutility-methods-load_scene_with_transition) | `func load_scene_with_transition(config: GFSceneTransitionConfig) -> Error:` |
| 方法 | [`preload_scene`](#member-gfsceneutility-methods-preload_scene) | `func preload_scene(path: String, fixed: bool = false) -> Error:` |
| 方法 | [`begin_background_scene_load`](#member-gfsceneutility-methods-begin_background_scene_load) | `func begin_background_scene_load(path: String, params: Dictionary = {}, fixed: bool = false) -> Error:` |
| 方法 | [`activate_background_scene`](#member-gfsceneutility-methods-activate_background_scene) | `func activate_background_scene( path: String, loading_scene_path: String = "", minimum_duration_seconds: float = -1.0 ) -> Error:` |
| 方法 | [`get_background_scene_params`](#member-gfsceneutility-methods-get_background_scene_params) | `func get_background_scene_params(path: String) -> Dictionary:` |
| 方法 | [`preload_scenes`](#member-gfsceneutility-methods-preload_scenes) | `func preload_scenes(paths: PackedStringArray, fixed: bool = false) -> Dictionary:` |
| 方法 | [`configure_scene_preload_map`](#member-gfsceneutility-methods-configure_scene_preload_map) | `func configure_scene_preload_map( preload_map: GFScenePreloadMap, radius: int = -1, auto_preload_on_switch: bool = true ) -> void:` |
| 方法 | [`get_scene_preload_map_plan`](#member-gfsceneutility-methods-get_scene_preload_map_plan) | `func get_scene_preload_map_plan(path: String, radius: int = -1, include_fixed: bool = true) -> Dictionary:` |
| 方法 | [`preload_scene_map_for`](#member-gfsceneutility-methods-preload_scene_map_for) | `func preload_scene_map_for(path: String, radius: int = -1, include_fixed: bool = true) -> Dictionary:` |
| 方法 | [`preload_current_scene_map`](#member-gfsceneutility-methods-preload_current_scene_map) | `func preload_current_scene_map(radius: int = -1, include_fixed: bool = true) -> Dictionary:` |
| 方法 | [`cancel_scene_preload`](#member-gfsceneutility-methods-cancel_scene_preload) | `func cancel_scene_preload(path: String) -> void:` |
| 方法 | [`cancel_all_scene_preloads`](#member-gfsceneutility-methods-cancel_all_scene_preloads) | `func cancel_all_scene_preloads() -> void:` |
| 方法 | [`is_scene_preloading`](#member-gfsceneutility-methods-is_scene_preloading) | `func is_scene_preloading(path: String) -> bool:` |
| 方法 | [`is_scene_preloaded`](#member-gfsceneutility-methods-is_scene_preloaded) | `func is_scene_preloaded(path: String) -> bool:` |
| 方法 | [`get_preloaded_scene`](#member-gfsceneutility-methods-get_preloaded_scene) | `func get_preloaded_scene(path: String) -> PackedScene:` |
| 方法 | [`put_preloaded_scene`](#member-gfsceneutility-methods-put_preloaded_scene) | `func put_preloaded_scene(path: String, scene: PackedScene, fixed: bool = false) -> void:` |
| 方法 | [`remove_preloaded_scene`](#member-gfsceneutility-methods-remove_preloaded_scene) | `func remove_preloaded_scene(path: String) -> void:` |
| 方法 | [`clear_preloaded_scenes`](#member-gfsceneutility-methods-clear_preloaded_scenes) | `func clear_preloaded_scenes(include_fixed: bool = true) -> void:` |
| 方法 | [`move_preloaded_scene_to_fixed`](#member-gfsceneutility-methods-move_preloaded_scene_to_fixed) | `func move_preloaded_scene_to_fixed(path: String) -> bool:` |
| 方法 | [`move_preloaded_scene_to_temporary`](#member-gfsceneutility-methods-move_preloaded_scene_to_temporary) | `func move_preloaded_scene_to_temporary(path: String) -> bool:` |
| 方法 | [`is_preloaded_scene_fixed`](#member-gfsceneutility-methods-is_preloaded_scene_fixed) | `func is_preloaded_scene_fixed(path: String) -> bool:` |
| 方法 | [`get_preloading_scene_paths`](#member-gfsceneutility-methods-get_preloading_scene_paths) | `func get_preloading_scene_paths() -> PackedStringArray:` |
| 方法 | [`get_scene_cache_debug_snapshot`](#member-gfsceneutility-methods-get_scene_cache_debug_snapshot) | `func get_scene_cache_debug_snapshot() -> Dictionary:` |
| 方法 | [`get_scene_resource_state`](#member-gfsceneutility-methods-get_scene_resource_state) | `func get_scene_resource_state(path: String) -> int:` |
| 方法 | [`get_loading_progress`](#member-gfsceneutility-methods-get_loading_progress) | `func get_loading_progress() -> float:` |
| 方法 | [`get_scene_resource_info`](#member-gfsceneutility-methods-get_scene_resource_info) | `func get_scene_resource_info(path: String) -> Dictionary:` |
| 方法 | [`get_current_scene_params`](#member-gfsceneutility-methods-get_current_scene_params) | `func get_current_scene_params() -> Dictionary:` |
| 方法 | [`get_scene_history`](#member-gfsceneutility-methods-get_scene_history) | `func get_scene_history() -> Array[Dictionary]:` |
| 方法 | [`clear_scene_history`](#member-gfsceneutility-methods-clear_scene_history) | `func clear_scene_history() -> void:` |
| 方法 | [`pop_scene_history`](#member-gfsceneutility-methods-pop_scene_history) | `func pop_scene_history() -> Dictionary:` |
| 方法 | [`load_previous_scene`](#member-gfsceneutility-methods-load_previous_scene) | `func load_previous_scene(loading_scene_path: String = "", minimum_duration_seconds: float = -1.0) -> Error:` |
| 方法 | [`mark_transient`](#member-gfsceneutility-methods-mark_transient) | `func mark_transient(script_cls: Script) -> void:` |
| 方法 | [`unmark_transient`](#member-gfsceneutility-methods-unmark_transient) | `func unmark_transient(script_cls: Script) -> void:` |
| 方法 | [`cleanup_transients`](#member-gfsceneutility-methods-cleanup_transients) | `func cleanup_transients() -> void:` |
| 方法 | [`_should_load_active_scene_synchronously`](#member-gfsceneutility-methods-_should_load_active_scene_synchronously) | `func _should_load_active_scene_synchronously() -> bool:` |
| 方法 | [`_load_packed_scene_synchronously`](#member-gfsceneutility-methods-_load_packed_scene_synchronously) | `func _load_packed_scene_synchronously(path: String) -> PackedScene:` |
| 方法 | [`_get_loading_scene_node`](#member-gfsceneutility-methods-_get_loading_scene_node) | `func _get_loading_scene_node() -> Node:` |
| 方法 | [`_do_change_scene`](#member-gfsceneutility-methods-_do_change_scene) | `func _do_change_scene(scene: PackedScene) -> bool:` |
| 方法 | [`_do_change_scene_sync`](#member-gfsceneutility-methods-_do_change_scene_sync) | `func _do_change_scene_sync(path: String) -> Error:` |
| 方法 | [`_get_current_scene_path`](#member-gfsceneutility-methods-_get_current_scene_path) | `func _get_current_scene_path() -> String:` |

## 信号

<a id="member-gfsceneutility-signals-scene_load_started"></a>

### `scene_load_started`

- API：`public`

```gdscript
signal scene_load_started(path: String)
```

当场景异步加载开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |

<a id="member-gfsceneutility-signals-scene_load_progress"></a>

### `scene_load_progress`

- API：`public`

```gdscript
signal scene_load_progress(path: String, progress: float)
```

当场景异步加载进度更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `progress` | 当前进度，范围在 `0.0` 到 `1.0` 之间。 |

<a id="member-gfsceneutility-signals-scene_load_completed"></a>

### `scene_load_completed`

- API：`public`

```gdscript
signal scene_load_completed(path: String, scene: PackedScene)
```

当场景异步加载完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `scene` | 已加载完成的场景资源。 |

<a id="member-gfsceneutility-signals-scene_load_failed"></a>

### `scene_load_failed`

- API：`public`

```gdscript
signal scene_load_failed(path: String)
```

当场景异步加载失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |

<a id="member-gfsceneutility-signals-scene_preload_started"></a>

### `scene_preload_started`

- API：`public`

```gdscript
signal scene_preload_started(path: String)
```

当场景预加载开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |

<a id="member-gfsceneutility-signals-scene_preload_progress"></a>

### `scene_preload_progress`

- API：`public`

```gdscript
signal scene_preload_progress(path: String, progress: float)
```

当场景预加载进度更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `progress` | 当前进度，范围在 `0.0` 到 `1.0` 之间。 |

<a id="member-gfsceneutility-signals-scene_preload_completed"></a>

### `scene_preload_completed`

- API：`public`

```gdscript
signal scene_preload_completed(path: String, scene: PackedScene)
```

当场景预加载完成并进入缓存时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `scene` | 已缓存的场景资源。 |

<a id="member-gfsceneutility-signals-scene_preload_failed"></a>

### `scene_preload_failed`

- API：`public`

```gdscript
signal scene_preload_failed(path: String)
```

当场景预加载失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |

<a id="member-gfsceneutility-signals-scene_preload_cancelled"></a>

### `scene_preload_cancelled`

- API：`public`

```gdscript
signal scene_preload_cancelled(path: String)
```

当场景预加载被取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |

<a id="member-gfsceneutility-signals-scene_switch_started"></a>

### `scene_switch_started`

- API：`public`

```gdscript
signal scene_switch_started(path: String, previous_path: String)
```

当一次场景切换流程开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `previous_path` | 切换前场景路径。 |

<a id="member-gfsceneutility-signals-scene_switch_completed"></a>

### `scene_switch_completed`

- API：`public`

```gdscript
signal scene_switch_completed(path: String, previous_path: String)
```

当一次场景切换流程完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `previous_path` | 切换前场景路径。 |

<a id="member-gfsceneutility-signals-scene_switch_failed"></a>

### `scene_switch_failed`

- API：`public`

```gdscript
signal scene_switch_failed(path: String, previous_path: String, message: String)
```

当一次场景切换流程失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景路径。 |
| `previous_path` | 切换前场景路径。 |
| `message` | 失败说明。 |

<a id="member-gfsceneutility-signals-loading_scene_shown"></a>

### `loading_scene_shown`

- API：`public`

```gdscript
signal loading_scene_shown(path: String)
```

当 loading scene 切入后发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | loading scene 路径。 |

<a id="member-gfsceneutility-signals-loading_scene_hidden"></a>

### `loading_scene_hidden`

- API：`public`

```gdscript
signal loading_scene_hidden(path: String)
```

当 loading scene 准备退出时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | loading scene 路径。 |

<a id="member-gfsceneutility-signals-scene_cache_added"></a>

### `scene_cache_added`

- API：`public`

```gdscript
signal scene_cache_added(path: String, fixed: bool)
```

当场景资源写入预加载缓存后发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |
| `fixed` | 是否写入固定缓存。 |

<a id="member-gfsceneutility-signals-scene_cache_removed"></a>

### `scene_cache_removed`

- API：`public`

```gdscript
signal scene_cache_removed(path: String, fixed: bool)
```

当场景资源从预加载缓存移除后发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |
| `fixed` | 是否来自固定缓存。 |

## 枚举

<a id="member-gfsceneutility-enums-sceneresourcestate"></a>

### `SceneResourceState`

- API：`public`

```gdscript
enum SceneResourceState {
	## 未加载。
	NOT_LOADED,
	## 正在预加载。
	PRELOADING,
	## 已缓存 PackedScene。
	PRELOADED,
	## 当前 load_scene_async() 正在等待该资源。
	ACTIVE_LOADING,
}
```

场景资源在 GFSceneUtility 内部的缓存状态。

## 属性

<a id="member-gfsceneutility-properties-max_preloaded_scene_resources"></a>

### `max_preloaded_scene_resources`

- API：`public`

```gdscript
var max_preloaded_scene_resources: int:
```

最多保留的预加载 PackedScene 数量；设为 `0` 表示禁用预加载缓存。

<a id="member-gfsceneutility-properties-cache_loaded_scenes"></a>

### `cache_loaded_scenes`

- API：`public`

```gdscript
var cache_loaded_scenes: bool = true
```

通过 load_scene_async() 加载完成的目标场景是否写入预加载缓存。

<a id="member-gfsceneutility-properties-scene_preload_map"></a>

### `scene_preload_map`

- API：`public`

```gdscript
var scene_preload_map: GFScenePreloadMap = null
```

可选场景预加载图谱；配置后可按当前场景自动预热相邻场景。

<a id="member-gfsceneutility-properties-auto_preload_map_neighbors_on_switch"></a>

### `auto_preload_map_neighbors_on_switch`

- API：`public`

```gdscript
var auto_preload_map_neighbors_on_switch: bool = true
```

成功切换场景后是否自动按 scene_preload_map 预加载相邻场景。

<a id="member-gfsceneutility-properties-scene_preload_map_radius"></a>

### `scene_preload_map_radius`

- API：`public`

```gdscript
var scene_preload_map_radius: int = -1:
```

自动图谱预加载半径；小于 0 时使用 GFScenePreloadMap.default_radius。

<a id="member-gfsceneutility-properties-loading_screen_fade_in_method"></a>

### `loading_screen_fade_in_method`

- API：`public`

```gdscript
var loading_screen_fade_in_method: StringName = &"fade_in"
```

loading scene 可选淡入方法名；目标节点存在该方法时会被调用。

<a id="member-gfsceneutility-properties-loading_screen_fade_out_method"></a>

### `loading_screen_fade_out_method`

- API：`public`

```gdscript
var loading_screen_fade_out_method: StringName = &"fade_out"
```

loading scene 可选淡出方法名；目标节点存在该方法时会被调用。

<a id="member-gfsceneutility-properties-loading_screen_progress_method"></a>

### `loading_screen_progress_method`

- API：`public`

```gdscript
var loading_screen_progress_method: StringName = &"set_progress"
```

loading scene 可选进度更新方法名；不存在时会回退到 update_progress。

<a id="member-gfsceneutility-properties-loading_screen_progress_fallback_method"></a>

### `loading_screen_progress_fallback_method`

- API：`public`

```gdscript
var loading_screen_progress_fallback_method: StringName = &"update_progress"
```

loading scene 进度更新回退方法名。

<a id="member-gfsceneutility-properties-loading_screen_error_method"></a>

### `loading_screen_error_method`

- API：`public`

```gdscript
var loading_screen_error_method: StringName = &"show_error"
```

loading scene 可选错误显示方法名；目标节点存在该方法时会被调用并传入错误文本。

<a id="member-gfsceneutility-properties-default_transition_minimum_seconds"></a>

### `default_transition_minimum_seconds`

- API：`public`

```gdscript
var default_transition_minimum_seconds: float = 0.0
```

默认 loading scene 最短保留秒数；单次切换可覆盖。

<a id="member-gfsceneutility-properties-max_scene_history"></a>

### `max_scene_history`

- API：`public`

```gdscript
var max_scene_history: int:
```

最多保留的场景历史数量；设为 0 表示不记录历史。

## 方法

<a id="member-gfsceneutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化场景工具的暂停策略。

<a id="member-gfsceneutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |

<a id="member-gfsceneutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

取消待处理场景切换并释放预加载请求、背景参数和缓存。

<a id="member-gfsceneutility-methods-load_scene_async"></a>

### `load_scene_async`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func load_scene_async( path: String, loading_scene_path: String = "", params: Dictionary = {}, minimum_duration_seconds: float = -1.0 ) -> Error:
```

异步切换场景。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景资源路径。 |
| `loading_scene_path` | 可选的过渡场景路径。 |
| `params` | 本次切换参数；完成后可通过 get_current_scene_params() 读取。 |
| `minimum_duration_seconds` | loading scene 最短保留秒数；小于 0 时使用默认值。 |

返回：发起加载的 Godot Error；异步终态继续通过信号报告。

结构：

- `params`: Dictionary[String, Variant]，切换完成后复制到当前场景参数中的场景切换参数。

<a id="member-gfsceneutility-methods-load_scene_with_transition"></a>

### `load_scene_with_transition`

- API：`public`

```gdscript
func load_scene_with_transition(config: GFSceneTransitionConfig) -> Error:
```

按资源配置切换场景。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 场景切换配置。 |

返回：发起切换的 Godot Error。

<a id="member-gfsceneutility-methods-preload_scene"></a>

### `preload_scene`

- API：`public`

```gdscript
func preload_scene(path: String, fixed: bool = false) -> Error:
```

预加载一个场景资源并放入缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景资源路径。 |
| `fixed` | 为 true 时写入固定缓存，不受 LRU 容量淘汰影响。 |

返回：发起请求的 Godot Error。

<a id="member-gfsceneutility-methods-begin_background_scene_load"></a>

### `begin_background_scene_load`

- API：`public`

```gdscript
func begin_background_scene_load(path: String, params: Dictionary = {}, fixed: bool = false) -> Error:
```

后台加载一个场景并记录稍后激活时使用的参数。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景资源路径。 |
| `params` | 激活该场景时传入的参数。 |
| `fixed` | 为 true 时写入固定缓存，不受 LRU 容量淘汰影响。 |

返回：发起请求的 Godot Error。

结构：

- `params`: Dictionary[String, Variant]，后台场景激活时复制并应用的参数。

<a id="member-gfsceneutility-methods-activate_background_scene"></a>

### `activate_background_scene`

- API：`public`

```gdscript
func activate_background_scene( path: String, loading_scene_path: String = "", minimum_duration_seconds: float = -1.0 ) -> Error:
```

激活已经后台加载或正在后台加载的场景。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标场景资源路径。 |
| `loading_scene_path` | 可选的过渡场景路径。 |
| `minimum_duration_seconds` | loading scene 最短保留秒数；小于 0 时使用默认值。 |

返回：发起切换的 Godot Error。

<a id="member-gfsceneutility-methods-get_background_scene_params"></a>

### `get_background_scene_params`

- API：`public`

```gdscript
func get_background_scene_params(path: String) -> Dictionary:
```

获取后台场景记录的参数副本。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：参数副本；没有记录时返回空字典。

结构：

- `return`: Dictionary[String, Variant]，后台场景参数。

<a id="member-gfsceneutility-methods-preload_scenes"></a>

### `preload_scenes`

- API：`public`

```gdscript
func preload_scenes(paths: PackedStringArray, fixed: bool = false) -> Dictionary:
```

批量预加载场景资源。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 场景路径数组。 |
| `fixed` | 为 true 时全部写入固定缓存。 |

返回：path -> Error 的结果字典。

结构：

- `return`: Dictionary[String, Error]，以场景路径为键。

<a id="member-gfsceneutility-methods-configure_scene_preload_map"></a>

### `configure_scene_preload_map`

- API：`public`

```gdscript
func configure_scene_preload_map( preload_map: GFScenePreloadMap, radius: int = -1, auto_preload_on_switch: bool = true ) -> void:
```

配置场景预加载图谱。

参数：

| 名称 | 说明 |
|---|---|
| `preload_map` | 场景预加载图谱资源；传 null 可关闭图谱预加载。 |
| `radius` | 自动预加载半径；小于 0 时使用图谱默认值。 |
| `auto_preload_on_switch` | 成功切换场景后是否自动预加载相邻场景。 |

<a id="member-gfsceneutility-methods-get_scene_preload_map_plan"></a>

### `get_scene_preload_map_plan`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_scene_preload_map_plan(path: String, radius: int = -1, include_fixed: bool = true) -> Dictionary:
```

获取指定场景的图谱预加载计划。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 当前场景资源路径。 |
| `radius` | 搜索半径；小于 0 时使用 scene_preload_map_radius，再小于 0 时使用图谱默认值。 |
| `include_fixed` | 是否包含固定预加载路径。 |

返回：预加载计划字典；未配置图谱时 ok 为 false。

结构：

- `return`: Dictionary，包含 ok、source_path、source_cache_key、radius、include_fixed、fixed_paths、temporary_paths、paths、fixed_cache_keys、temporary_cache_keys、cache_keys、resource_identities 和 errors。

<a id="member-gfsceneutility-methods-preload_scene_map_for"></a>

### `preload_scene_map_for`

- API：`public`

```gdscript
func preload_scene_map_for(path: String, radius: int = -1, include_fixed: bool = true) -> Dictionary:
```

按图谱为指定场景发起预加载。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 当前场景资源路径。 |
| `radius` | 搜索半径；小于 0 时使用 scene_preload_map_radius，再小于 0 时使用图谱默认值。 |
| `include_fixed` | 是否包含固定预加载路径。 |

返回：预加载结果字典。

结构：

- `return`: Dictionary，包含 ok、source_path、radius、include_fixed、requested_count、fixed_requested、temporary_requested、results、errors 和 plan。

<a id="member-gfsceneutility-methods-preload_current_scene_map"></a>

### `preload_current_scene_map`

- API：`public`

```gdscript
func preload_current_scene_map(radius: int = -1, include_fixed: bool = true) -> Dictionary:
```

按图谱为当前场景发起预加载。

参数：

| 名称 | 说明 |
|---|---|
| `radius` | 搜索半径；小于 0 时使用 scene_preload_map_radius，再小于 0 时使用图谱默认值。 |
| `include_fixed` | 是否包含固定预加载路径。 |

返回：预加载结果字典。

结构：

- `return`: Dictionary，包含 ok、source_path、radius、include_fixed、requested_count、fixed_requested、temporary_requested、results、errors 和 plan。

<a id="member-gfsceneutility-methods-cancel_scene_preload"></a>

### `cancel_scene_preload`

- API：`public`

```gdscript
func cancel_scene_preload(path: String) -> void:
```

取消一个仍在进行中的预加载请求。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

<a id="member-gfsceneutility-methods-cancel_all_scene_preloads"></a>

### `cancel_all_scene_preloads`

- API：`public`

```gdscript
func cancel_all_scene_preloads() -> void:
```

取消全部正在进行中的预加载请求。

<a id="member-gfsceneutility-methods-is_scene_preloading"></a>

### `is_scene_preloading`

- API：`public`

```gdscript
func is_scene_preloading(path: String) -> bool:
```

检查场景是否正在预加载。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：正在预加载时返回 true。

<a id="member-gfsceneutility-methods-is_scene_preloaded"></a>

### `is_scene_preloaded`

- API：`public`

```gdscript
func is_scene_preloaded(path: String) -> bool:
```

检查场景是否已经预加载到缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：已缓存时返回 true。

<a id="member-gfsceneutility-methods-get_preloaded_scene"></a>

### `get_preloaded_scene`

- API：`public`

```gdscript
func get_preloaded_scene(path: String) -> PackedScene:
```

获取已预加载的 PackedScene。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：命中缓存时返回 PackedScene，否则返回 null。

<a id="member-gfsceneutility-methods-put_preloaded_scene"></a>

### `put_preloaded_scene`

- API：`public`

```gdscript
func put_preloaded_scene(path: String, scene: PackedScene, fixed: bool = false) -> void:
```

手动写入预加载缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |
| `scene` | PackedScene 实例。 |
| `fixed` | 为 true 时写入固定缓存。 |

<a id="member-gfsceneutility-methods-remove_preloaded_scene"></a>

### `remove_preloaded_scene`

- API：`public`

```gdscript
func remove_preloaded_scene(path: String) -> void:
```

移除一个预加载场景资源。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

<a id="member-gfsceneutility-methods-clear_preloaded_scenes"></a>

### `clear_preloaded_scenes`

- API：`public`

```gdscript
func clear_preloaded_scenes(include_fixed: bool = true) -> void:
```

清空所有预加载场景资源。

参数：

| 名称 | 说明 |
|---|---|
| `include_fixed` | 为 true 时同时清空固定缓存。 |

<a id="member-gfsceneutility-methods-move_preloaded_scene_to_fixed"></a>

### `move_preloaded_scene_to_fixed`

- API：`public`

```gdscript
func move_preloaded_scene_to_fixed(path: String) -> bool:
```

把已缓存场景移动到固定缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：移动成功返回 true。

<a id="member-gfsceneutility-methods-move_preloaded_scene_to_temporary"></a>

### `move_preloaded_scene_to_temporary`

- API：`public`

```gdscript
func move_preloaded_scene_to_temporary(path: String) -> bool:
```

把已缓存场景移动到临时 LRU 缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：移动成功返回 true。

<a id="member-gfsceneutility-methods-is_preloaded_scene_fixed"></a>

### `is_preloaded_scene_fixed`

- API：`public`

```gdscript
func is_preloaded_scene_fixed(path: String) -> bool:
```

检查已缓存场景是否位于固定缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：固定缓存命中时返回 true。

<a id="member-gfsceneutility-methods-get_preloading_scene_paths"></a>

### `get_preloading_scene_paths`

- API：`public`

```gdscript
func get_preloading_scene_paths() -> PackedStringArray:
```

获取正在预加载的场景路径列表。

返回：路径列表。

<a id="member-gfsceneutility-methods-get_scene_cache_debug_snapshot"></a>

### `get_scene_cache_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_scene_cache_debug_snapshot() -> Dictionary:
```

获取场景缓存与加载状态快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 is_loading、target_path、loading_scene_path、current_scene、loading_progress、transition、preload_cache、scene_preload_map、preloading、background 和 threaded_resource_operations。

<a id="member-gfsceneutility-methods-get_scene_resource_state"></a>

### `get_scene_resource_state`

- API：`public`

```gdscript
func get_scene_resource_state(path: String) -> int:
```

获取场景资源状态。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：SceneResourceState 枚举值。

<a id="member-gfsceneutility-methods-get_loading_progress"></a>

### `get_loading_progress`

- API：`public`

```gdscript
func get_loading_progress() -> float:
```

获取当前异步加载进度。

返回：当前加载进度，未加载时为 0。

<a id="member-gfsceneutility-methods-get_scene_resource_info"></a>

### `get_scene_resource_info`

- API：`public`

```gdscript
func get_scene_resource_info(path: String) -> Dictionary:
```

获取单个场景资源的缓存与加载信息。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景路径。 |

返回：场景资源状态字典。

结构：

- `return`: Dictionary，包含 path、state、is_loading、is_preloading、is_preloaded、is_fixed、progress、cached 和 file_size_bytes。

<a id="member-gfsceneutility-methods-get_current_scene_params"></a>

### `get_current_scene_params`

- API：`public`

```gdscript
func get_current_scene_params() -> Dictionary:
```

获取当前场景参数副本。

返回：当前场景参数。

结构：

- `return`: Dictionary[String, Variant]，当前场景参数。

<a id="member-gfsceneutility-methods-get_scene_history"></a>

### `get_scene_history`

- API：`public`

```gdscript
func get_scene_history() -> Array[Dictionary]:
```

获取场景历史副本。

返回：场景历史列表，最新项位于数组末尾。

结构：

- `return`: Array[Dictionary]，元素包含 path、params 和 timestamp_unix。

<a id="member-gfsceneutility-methods-clear_scene_history"></a>

### `clear_scene_history`

- API：`public`

```gdscript
func clear_scene_history() -> void:
```

清空场景历史。

<a id="member-gfsceneutility-methods-pop_scene_history"></a>

### `pop_scene_history`

- API：`public`

```gdscript
func pop_scene_history() -> Dictionary:
```

弹出最近一个场景历史项。

返回：历史项；没有历史时返回空字典。

结构：

- `return`: Dictionary，包含 path、params 和 timestamp_unix；没有记录时为空字典。

<a id="member-gfsceneutility-methods-load_previous_scene"></a>

### `load_previous_scene`

- API：`public`

```gdscript
func load_previous_scene(loading_scene_path: String = "", minimum_duration_seconds: float = -1.0) -> Error:
```

切换到最近一个历史场景。

参数：

| 名称 | 说明 |
|---|---|
| `loading_scene_path` | 可选 loading scene 路径。 |
| `minimum_duration_seconds` | loading scene 最短保留秒数；小于 0 时使用默认值。 |

返回：发起切换的 Godot Error。

<a id="member-gfsceneutility-methods-mark_transient"></a>

### `mark_transient`

- API：`public`

```gdscript
func mark_transient(script_cls: Script) -> void:
```

标记一个脚本类型为瞬态实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 需要在下次切场景时清理的脚本类型。 |

<a id="member-gfsceneutility-methods-unmark_transient"></a>

### `unmark_transient`

- API：`public`

```gdscript
func unmark_transient(script_cls: Script) -> void:
```

取消一个脚本类型的瞬态标记。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要取消标记的脚本类型。 |

<a id="member-gfsceneutility-methods-cleanup_transients"></a>

### `cleanup_transients`

- API：`public`

```gdscript
func cleanup_transients() -> void:
```

立即清理所有瞬态实例。

<a id="member-gfsceneutility-methods-_should_load_active_scene_synchronously"></a>

### `_should_load_active_scene_synchronously`

- API：`protected`

```gdscript
func _should_load_active_scene_synchronously() -> bool:
```

判断当前环境是否应使用同步加载作为活动场景加载降级。

返回：需要同步降级时返回 true。

<a id="member-gfsceneutility-methods-_load_packed_scene_synchronously"></a>

### `_load_packed_scene_synchronously`

- API：`protected`

```gdscript
func _load_packed_scene_synchronously(path: String) -> PackedScene:
```

同步加载 PackedScene 资源。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景资源路径。 |

返回：加载到的 PackedScene；失败时返回 null。

<a id="member-gfsceneutility-methods-_get_loading_scene_node"></a>

### `_get_loading_scene_node`

- API：`protected`

```gdscript
func _get_loading_scene_node() -> Node:
```

获取当前 loading scene 节点。

返回：当前 loading scene 节点；不存在时返回 null。

<a id="member-gfsceneutility-methods-_do_change_scene"></a>

### `_do_change_scene`

- API：`protected`

```gdscript
func _do_change_scene(scene: PackedScene) -> bool:
```

切换到已加载的 PackedScene。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 目标 PackedScene。 |

返回：切换成功返回 true。

<a id="member-gfsceneutility-methods-_do_change_scene_sync"></a>

### `_do_change_scene_sync`

- API：`protected`

```gdscript
func _do_change_scene_sync(path: String) -> Error:
```

同步切换到场景文件路径。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 场景资源路径。 |

返回：Godot 场景切换结果。

<a id="member-gfsceneutility-methods-_get_current_scene_path"></a>

### `_get_current_scene_path`

- API：`protected`

```gdscript
func _get_current_scene_path() -> String:
```

获取当前场景资源路径。

返回：当前场景资源路径；不可用时返回空字符串。
