# GFRenderWarmupUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_render_warmup_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用渲染资源预热工具。 通过清单或节点树收集 Mesh、Material、Texture 等渲染资源，并按帧预算提前加载和触碰 RID。 它不决定项目何时预热、预热哪些场景或如何展示加载进度。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`warmup_queued`](#member-gfrenderwarmuputility-signals-warmup_queued) | `signal warmup_queued(queue_id: int, manifest_id: StringName, entry_count: int)` |
| 信号 | [`warmup_entry_processed`](#member-gfrenderwarmuputility-signals-warmup_entry_processed) | `signal warmup_entry_processed(queue_id: int, entry_index: int, result: Dictionary)` |
| 信号 | [`warmup_completed`](#member-gfrenderwarmuputility-signals-warmup_completed) | `signal warmup_completed(queue_id: int, summary: Dictionary)` |
| 枚举 | [`TouchMode`](#member-gfrenderwarmuputility-enums-touchmode) | `enum TouchMode` |
| 属性 | [`default_entries_per_tick`](#member-gfrenderwarmuputility-properties-default_entries_per_tick) | `var default_entries_per_tick: int = 4` |
| 属性 | [`default_max_seconds`](#member-gfrenderwarmuputility-properties-default_max_seconds) | `var default_max_seconds: float = 0.0` |
| 属性 | [`default_touch_mode`](#member-gfrenderwarmuputility-properties-default_touch_mode) | `var default_touch_mode: TouchMode = TouchMode.RID_ONLY` |
| 属性 | [`keep_resources_cached`](#member-gfrenderwarmuputility-properties-keep_resources_cached) | `var keep_resources_cached: bool = true` |
| 属性 | [`instantiate_packed_scenes`](#member-gfrenderwarmuputility-properties-instantiate_packed_scenes) | `var instantiate_packed_scenes: bool = false` |
| 方法 | [`tick`](#member-gfrenderwarmuputility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfrenderwarmuputility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`queue_manifest`](#member-gfrenderwarmuputility-methods-queue_manifest) | `func queue_manifest(manifest: GFRenderWarmupManifest, options: Dictionary = {}) -> int:` |
| 方法 | [`warmup_manifest_now`](#member-gfrenderwarmuputility-methods-warmup_manifest_now) | `func warmup_manifest_now(manifest: GFRenderWarmupManifest, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`process_queue`](#member-gfrenderwarmuputility-methods-process_queue) | `func process_queue(max_entries: int = 1) -> int:` |
| 方法 | [`build_manifest_from_tree`](#member-gfrenderwarmuputility-methods-build_manifest_from_tree) | `func build_manifest_from_tree(root: Node, options: Dictionary = {}) -> GFRenderWarmupManifest:` |
| 方法 | [`build_manifest_from_scene`](#member-gfrenderwarmuputility-methods-build_manifest_from_scene) | `func build_manifest_from_scene(scene: PackedScene, options: Dictionary = {}) -> GFRenderWarmupManifest:` |
| 方法 | [`build_manifest_from_scene_path`](#member-gfrenderwarmuputility-methods-build_manifest_from_scene_path) | `func build_manifest_from_scene_path(scene_path: String, options: Dictionary = {}) -> GFRenderWarmupManifest:` |
| 方法 | [`clear_queue`](#member-gfrenderwarmuputility-methods-clear_queue) | `func clear_queue() -> void:` |
| 方法 | [`release_cached_resources`](#member-gfrenderwarmuputility-methods-release_cached_resources) | `func release_cached_resources() -> void:` |
| 方法 | [`release_temporary_render_nodes`](#member-gfrenderwarmuputility-methods-release_temporary_render_nodes) | `func release_temporary_render_nodes() -> void:` |
| 方法 | [`get_cached_resource_count`](#member-gfrenderwarmuputility-methods-get_cached_resource_count) | `func get_cached_resource_count() -> int:` |
| 方法 | [`get_queue_size`](#member-gfrenderwarmuputility-methods-get_queue_size) | `func get_queue_size() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfrenderwarmuputility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfrenderwarmuputility-signals-warmup_queued"></a>

### `warmup_queued`

- API：`public`

```gdscript
signal warmup_queued(queue_id: int, manifest_id: StringName, entry_count: int)
```

清单加入预热队列时发出。

参数：

| 名称 | 说明 |
|---|---|
| `queue_id` | 预热队列标识。 |
| `manifest_id` | 清单标识。 |
| `entry_count` | 清单条目数量。 |

<a id="member-gfrenderwarmuputility-signals-warmup_entry_processed"></a>

### `warmup_entry_processed`

- API：`public`

```gdscript
signal warmup_entry_processed(queue_id: int, entry_index: int, result: Dictionary)
```

单个条目预热完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `queue_id` | 预热队列标识。 |
| `entry_index` | 清单条目索引。 |
| `result` | 单个条目的预热结果。 |

结构：

- `result`: Dictionary，包含 ok、resource_path、kind、resource_class、touched_count、error、metadata 和 entry_index。

<a id="member-gfrenderwarmuputility-signals-warmup_completed"></a>

### `warmup_completed`

- API：`public`

```gdscript
signal warmup_completed(queue_id: int, summary: Dictionary)
```

单个清单预热完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `queue_id` | 预热队列标识。 |
| `summary` | 清单预热摘要。 |

结构：

- `summary`: Dictionary，包含 queue_id、manifest_id、total_count、processed_count、failed_count、ok、elapsed_seconds、stopped_by_budget、completed_at_unix 和 results。

## 枚举

<a id="member-gfrenderwarmuputility-enums-touchmode"></a>

### `TouchMode`

- API：`public`

```gdscript
enum TouchMode {
	## 只加载资源并触碰 RID。
	RID_ONLY,
	## 使用离屏临时渲染节点让材质或 Mesh 参与一次渲染。
	TEMPORARY_RENDER_NODES,
}
```

预热触碰模式。

## 属性

<a id="member-gfrenderwarmuputility-properties-default_entries_per_tick"></a>

### `default_entries_per_tick`

- API：`public`

```gdscript
var default_entries_per_tick: int = 4
```

每次 tick 默认处理的最大条目数。

<a id="member-gfrenderwarmuputility-properties-default_max_seconds"></a>

### `default_max_seconds`

- API：`public`

```gdscript
var default_max_seconds: float = 0.0
```

默认预热时间预算，单位秒。小于等于 0 表示不限制。

<a id="member-gfrenderwarmuputility-properties-default_touch_mode"></a>

### `default_touch_mode`

- API：`public`

```gdscript
var default_touch_mode: TouchMode = TouchMode.RID_ONLY
```

默认触碰模式。

<a id="member-gfrenderwarmuputility-properties-keep_resources_cached"></a>

### `keep_resources_cached`

- API：`public`

```gdscript
var keep_resources_cached: bool = true
```

是否保留已加载资源引用，避免预热后立刻被释放。

<a id="member-gfrenderwarmuputility-properties-instantiate_packed_scenes"></a>

### `instantiate_packed_scenes`

- API：`public`

```gdscript
var instantiate_packed_scenes: bool = false
```

从 PackedScene 条目预热时是否实例化场景并扫描其渲染资源。默认关闭以避免触发项目脚本副作用。

## 方法

<a id="member-gfrenderwarmuputility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float) -> void:
```

推进预热队列。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量。 |

<a id="member-gfrenderwarmuputility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

清空预热队列、缓存资源和临时渲染节点。

<a id="member-gfrenderwarmuputility-methods-queue_manifest"></a>

### `queue_manifest`

- API：`public`

```gdscript
func queue_manifest(manifest: GFRenderWarmupManifest, options: Dictionary = {}) -> int:
```

将预热清单加入队列。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 预热清单。 |
| `options` | 可选参数，支持 entries_per_tick、max_seconds、touch_mode、keep_cached、instantiate_packed_scenes。 |

返回：队列标识；失败返回 -1。

结构：

- `options`: Dictionary，包含 entries_per_tick、max_seconds、touch_mode、keep_cached、instantiate_packed_scenes、temporary_parent 和 temporary_viewport_size。

<a id="member-gfrenderwarmuputility-methods-warmup_manifest_now"></a>

### `warmup_manifest_now`

- API：`public`

```gdscript
func warmup_manifest_now(manifest: GFRenderWarmupManifest, options: Dictionary = {}) -> Dictionary:
```

立即预热整个清单。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 预热清单。 |
| `options` | 可选参数，支持 max_seconds、touch_mode、keep_cached、instantiate_packed_scenes。 |

返回：预热摘要。

结构：

- `options`: Dictionary，包含 max_seconds、touch_mode、keep_cached、instantiate_packed_scenes、temporary_parent 和 temporary_viewport_size。
- `return`: Dictionary，包含 queue_id、manifest_id、total_count、processed_count、failed_count、ok、elapsed_seconds、stopped_by_budget、completed_at_unix 和 results。

<a id="member-gfrenderwarmuputility-methods-process_queue"></a>

### `process_queue`

- API：`public`

```gdscript
func process_queue(max_entries: int = 1) -> int:
```

按预算处理队列。

参数：

| 名称 | 说明 |
|---|---|
| `max_entries` | 最多处理条目数。 |

返回：实际处理条目数。

<a id="member-gfrenderwarmuputility-methods-build_manifest_from_tree"></a>

### `build_manifest_from_tree`

- API：`public`

```gdscript
func build_manifest_from_tree(root: Node, options: Dictionary = {}) -> GFRenderWarmupManifest:
```

从节点树收集可预热的渲染资源。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 根节点。 |
| `options` | 可选参数，支持 manifest_id、include_materials、include_meshes、include_textures。 |

返回：预热清单。

结构：

- `options`: Dictionary，包含 manifest_id、include_materials、include_meshes 和 include_textures。

<a id="member-gfrenderwarmuputility-methods-build_manifest_from_scene"></a>

### `build_manifest_from_scene`

- API：`public`

```gdscript
func build_manifest_from_scene(scene: PackedScene, options: Dictionary = {}) -> GFRenderWarmupManifest:
```

从场景资源收集可预热的渲染资源。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 场景资源。 |
| `options` | 可选参数，支持 manifest_id、include_materials、include_meshes、include_textures。 |

返回：预热清单。

结构：

- `options`: Dictionary，包含 manifest_id、include_materials、include_meshes 和 include_textures。

<a id="member-gfrenderwarmuputility-methods-build_manifest_from_scene_path"></a>

### `build_manifest_from_scene_path`

- API：`public`

```gdscript
func build_manifest_from_scene_path(scene_path: String, options: Dictionary = {}) -> GFRenderWarmupManifest:
```

从场景路径收集可预热的渲染资源。

参数：

| 名称 | 说明 |
|---|---|
| `scene_path` | 场景资源路径。 |
| `options` | 可选参数，支持 manifest_id、include_materials、include_meshes、include_textures。 |

返回：预热清单。

结构：

- `options`: Dictionary，包含 manifest_id、include_materials、include_meshes 和 include_textures。

<a id="member-gfrenderwarmuputility-methods-clear_queue"></a>

### `clear_queue`

- API：`public`

```gdscript
func clear_queue() -> void:
```

清空尚未处理的预热队列。

<a id="member-gfrenderwarmuputility-methods-release_cached_resources"></a>

### `release_cached_resources`

- API：`public`

```gdscript
func release_cached_resources() -> void:
```

释放预热缓存的资源引用。

<a id="member-gfrenderwarmuputility-methods-release_temporary_render_nodes"></a>

### `release_temporary_render_nodes`

- API：`public`

```gdscript
func release_temporary_render_nodes() -> void:
```

释放尚未清理的离屏临时渲染节点。

<a id="member-gfrenderwarmuputility-methods-get_cached_resource_count"></a>

### `get_cached_resource_count`

- API：`public`

```gdscript
func get_cached_resource_count() -> int:
```

获取预热缓存资源数量。

返回：缓存资源数量。

<a id="member-gfrenderwarmuputility-methods-get_queue_size"></a>

### `get_queue_size`

- API：`public`

```gdscript
func get_queue_size() -> int:
```

获取待处理队列数量。

返回：队列数量。

<a id="member-gfrenderwarmuputility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 queue_size、cached_resource_count、processed_entry_count、failed_entry_count、default_entries_per_tick、default_max_seconds、default_touch_mode、keep_resources_cached、instantiate_packed_scenes 和 temporary_render_node_count。
