# GFAssetUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

异步资源加载管理器，带 LRU 缓存。 封装 Godot 的 threaded `ResourceLoader` 请求， 用于避免大资源同步加载阻塞主线程，并在完成后统一分发回调与维护缓存。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`asset_handle_acquired`](#member-gfassetutility-signals-asset_handle_acquired) | `signal asset_handle_acquired(handle: GFAssetHandle)` |
| 信号 | [`asset_handle_released`](#member-gfassetutility-signals-asset_handle_released) | `signal asset_handle_released(path: String, reference_count: int)` |
| 信号 | [`asset_load_progress`](#member-gfassetutility-signals-asset_load_progress) | `signal asset_load_progress(path: String, progress: float)` |
| 信号 | [`asset_group_preloaded`](#member-gfassetutility-signals-asset_group_preloaded) | `signal asset_group_preloaded(group_id: StringName, report: Dictionary)` |
| 属性 | [`max_cache_size`](#member-gfassetutility-properties-max_cache_size) | `var max_cache_size: int:` |
| 方法 | [`init`](#member-gfassetutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfassetutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`load_async`](#member-gfassetutility-methods-load_async) | `func load_async(path: String, on_loaded: Callable, type_hint: String = "") -> void:` |
| 方法 | [`load_handle_async`](#member-gfassetutility-methods-load_handle_async) | `func load_handle_async( path: String, on_loaded: Callable, type_hint: String = "", owner: Object = null, group_id: StringName = &"" ) -> void:` |
| 方法 | [`acquire_handle`](#member-gfassetutility-methods-acquire_handle) | `func acquire_handle( path: String, owner: Object = null, group_id: StringName = &"", type_hint: String = "", resource_override: Resource = null ) -> GFAssetHandle:` |
| 方法 | [`release_handle`](#member-gfassetutility-methods-release_handle) | `func release_handle(handle: GFAssetHandle) -> bool:` |
| 方法 | [`release_owner`](#member-gfassetutility-methods-release_owner) | `func release_owner(owner: Object) -> int:` |
| 方法 | [`get_asset_reference_count`](#member-gfassetutility-methods-get_asset_reference_count) | `func get_asset_reference_count(path: String) -> int:` |
| 方法 | [`register_group_path`](#member-gfassetutility-methods-register_group_path) | `func register_group_path(group_id: StringName, path: String, pin: bool = false) -> void:` |
| 方法 | [`get_group_paths`](#member-gfassetutility-methods-get_group_paths) | `func get_group_paths(group_id: StringName) -> PackedStringArray:` |
| 方法 | [`preload_group_async`](#member-gfassetutility-methods-preload_group_async) | `func preload_group_async( group_id: StringName, entries: Array, on_completed: Callable = Callable(), options: Dictionary = {} ) -> void:` |
| 方法 | [`unload_group`](#member-gfassetutility-methods-unload_group) | `func unload_group(group_id: StringName, remove_unreferenced_cache: bool = false) -> void:` |
| 方法 | [`tick`](#member-gfassetutility-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`get_cached`](#member-gfassetutility-methods-get_cached) | `func get_cached(path: String) -> Resource:` |
| 方法 | [`is_loading`](#member-gfassetutility-methods-is_loading) | `func is_loading(path: String, type_hint: String = "") -> bool:` |
| 方法 | [`get_load_progress`](#member-gfassetutility-methods-get_load_progress) | `func get_load_progress(path: String) -> float:` |
| 方法 | [`is_cached`](#member-gfassetutility-methods-is_cached) | `func is_cached(path: String) -> bool:` |
| 方法 | [`cancel`](#member-gfassetutility-methods-cancel) | `func cancel(path: String, type_hint: String = "") -> void:` |
| 方法 | [`put_cache`](#member-gfassetutility-methods-put_cache) | `func put_cache(path: String, resource: Resource) -> void:` |
| 方法 | [`remove_cache`](#member-gfassetutility-methods-remove_cache) | `func remove_cache(path: String) -> void:` |
| 方法 | [`clear_cache`](#member-gfassetutility-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`get_cache_count`](#member-gfassetutility-methods-get_cache_count) | `func get_cache_count() -> int:` |
| 方法 | [`pin_cache`](#member-gfassetutility-methods-pin_cache) | `func pin_cache(path: String) -> void:` |
| 方法 | [`unpin_cache`](#member-gfassetutility-methods-unpin_cache) | `func unpin_cache(path: String) -> void:` |
| 方法 | [`is_cache_pinned`](#member-gfassetutility-methods-is_cache_pinned) | `func is_cache_pinned(path: String) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfassetutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfassetutility-signals-asset_handle_acquired"></a>

### `asset_handle_acquired`

- API：`public`

```gdscript
signal asset_handle_acquired(handle: GFAssetHandle)
```

创建资源句柄时发出。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 新创建的资源句柄。 |

<a id="member-gfassetutility-signals-asset_handle_released"></a>

### `asset_handle_released`

- API：`public`

```gdscript
signal asset_handle_released(path: String, reference_count: int)
```

资源句柄释放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `reference_count` | 剩余引用数量。 |

<a id="member-gfassetutility-signals-asset_load_progress"></a>

### `asset_load_progress`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
signal asset_load_progress(path: String, progress: float)
```

资源异步加载进度更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `progress` | 当前加载进度，范围 0.0 到 1.0。 |

<a id="member-gfassetutility-signals-asset_group_preloaded"></a>

### `asset_group_preloaded`

- API：`public`

```gdscript
signal asset_group_preloaded(group_id: StringName, report: Dictionary)
```

资源分组预加载完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `group_id` | 分组标识。 |
| `report` | 预加载报告。 |

结构：

- `report`: Dictionary with `ok: bool`, `group_id: StringName`, `paths: PackedStringArray`, `failed_paths: PackedStringArray`, `total: int`, and `completed: int`.

## 属性

<a id="member-gfassetutility-properties-max_cache_size"></a>

### `max_cache_size`

- API：`public`

```gdscript
var max_cache_size: int:
```

LRU 缓存最大容量；设为 `0` 时表示禁用缓存。

## 方法

<a id="member-gfassetutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化资源加载工具的运行时状态。

<a id="member-gfassetutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放资源加载工具持有的运行时状态。

<a id="member-gfassetutility-methods-load_async"></a>

### `load_async`

- API：`public`

```gdscript
func load_async(path: String, on_loaded: Callable, type_hint: String = "") -> void:
```

发起异步资源加载。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标资源路径。 |
| `on_loaded` | 加载完成后的回调。 |
| `type_hint` | 可选资源类型提示。 |

<a id="member-gfassetutility-methods-load_handle_async"></a>

### `load_handle_async`

- API：`public`

```gdscript
func load_handle_async( path: String, on_loaded: Callable, type_hint: String = "", owner: Object = null, group_id: StringName = &"" ) -> void:
```

异步加载资源并在成功后返回所有权句柄。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标资源路径。 |
| `on_loaded` | 加载完成回调，签名为 func(handle: GFAssetHandle)；失败时传入 null。 |
| `type_hint` | 可选资源类型提示。 |
| `owner` | 可选拥有者。若为 Node，会在退出树时自动释放其持有的句柄引用。 |
| `group_id` | 可选资源分组。 |

<a id="member-gfassetutility-methods-acquire_handle"></a>

### `acquire_handle`

- API：`public`

```gdscript
func acquire_handle( path: String, owner: Object = null, group_id: StringName = &"", type_hint: String = "", resource_override: Resource = null ) -> GFAssetHandle:
```

为已缓存或指定资源创建所有权句柄。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `owner` | 可选拥有者。若为 Node，会在退出树时自动释放其持有的句柄引用。 |
| `group_id` | 可选资源分组。 |
| `type_hint` | 可选资源类型提示。 |
| `resource_override` | 可选资源实例；为空时使用当前缓存。 |

返回：成功时返回句柄；资源不可用时返回 null。

<a id="member-gfassetutility-methods-release_handle"></a>

### `release_handle`

- API：`public`

```gdscript
func release_handle(handle: GFAssetHandle) -> bool:
```

释放资源句柄。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 要释放的资源句柄。 |

返回：释放成功返回 true。

<a id="member-gfassetutility-methods-release_owner"></a>

### `release_owner`

- API：`public`

```gdscript
func release_owner(owner: Object) -> int:
```

释放指定 owner 持有的所有资源引用。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 拥有者对象。 |

返回：释放的引用数量。

<a id="member-gfassetutility-methods-get_asset_reference_count"></a>

### `get_asset_reference_count`

- API：`public`

```gdscript
func get_asset_reference_count(path: String) -> int:
```

获取指定资源路径当前句柄引用数量。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

返回：引用数量。

<a id="member-gfassetutility-methods-register_group_path"></a>

### `register_group_path`

- API：`public`

```gdscript
func register_group_path(group_id: StringName, path: String, pin: bool = false) -> void:
```

注册资源路径到分组。

参数：

| 名称 | 说明 |
|---|---|
| `group_id` | 分组标识。 |
| `path` | 资源路径。 |
| `pin` | 是否以分组名义锁定缓存，避免 LRU 淘汰。 |

<a id="member-gfassetutility-methods-get_group_paths"></a>

### `get_group_paths`

- API：`public`

```gdscript
func get_group_paths(group_id: StringName) -> PackedStringArray:
```

获取分组中的资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `group_id` | 分组标识。 |

返回：路径列表。

<a id="member-gfassetutility-methods-preload_group_async"></a>

### `preload_group_async`

- API：`public`

```gdscript
func preload_group_async( group_id: StringName, entries: Array, on_completed: Callable = Callable(), options: Dictionary = {} ) -> void:
```

异步预加载资源分组。

参数：

| 名称 | 说明 |
|---|---|
| `group_id` | 分组标识。 |
| `entries` | 路径字符串，或包含 path/type_hint 字段的字典数组。 |
| `on_completed` | 完成回调，签名为 func(report: Dictionary)。 |
| `options` | 可选参数，支持 pin_cache。 |

结构：

- `entries`: Array[String|Dictionary] where dictionary entries may contain `path: String` and `type_hint: String`.
- `options`: Dictionary with optional `pin_cache: bool`.

<a id="member-gfassetutility-methods-unload_group"></a>

### `unload_group`

- API：`public`

```gdscript
func unload_group(group_id: StringName, remove_unreferenced_cache: bool = false) -> void:
```

卸载资源分组。

参数：

| 名称 | 说明 |
|---|---|
| `group_id` | 分组标识。 |
| `remove_unreferenced_cache` | 是否移除没有句柄引用的缓存项。 |

<a id="member-gfassetutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

驱动异步加载轮询。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 为兼容统一 tick 签名而保留的参数。 |

<a id="member-gfassetutility-methods-get_cached"></a>

### `get_cached`

- API：`public`

```gdscript
func get_cached(path: String) -> Resource:
```

获取缓存中的资源。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

返回：命中缓存时返回资源，否则返回 `null`。

<a id="member-gfassetutility-methods-is_loading"></a>

### `is_loading`

- API：`public`

```gdscript
func is_loading(path: String, type_hint: String = "") -> bool:
```

检查指定路径是否正在加载中。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `type_hint` | 可选资源类型提示；为空时只检查路径。 |

返回：正在加载时返回 `true`。

<a id="member-gfassetutility-methods-get_load_progress"></a>

### `get_load_progress`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
func get_load_progress(path: String) -> float:
```

获取资源异步加载进度。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

返回：已缓存返回 1.0，正在加载返回最近轮询进度，其余返回 0.0。

<a id="member-gfassetutility-methods-is_cached"></a>

### `is_cached`

- API：`public`

```gdscript
func is_cached(path: String) -> bool:
```

检查指定路径是否已缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

返回：已缓存时返回 `true`。

<a id="member-gfassetutility-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel(path: String, type_hint: String = "") -> void:
```

取消指定路径的异步加载请求。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `type_hint` | 可选资源类型提示；为空时取消该路径的当前请求。 |

<a id="member-gfassetutility-methods-put_cache"></a>

### `put_cache`

- API：`public`

```gdscript
func put_cache(path: String, resource: Resource) -> void:
```

手动写入缓存。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `resource` | 要缓存的资源实例。 |

<a id="member-gfassetutility-methods-remove_cache"></a>

### `remove_cache`

- API：`public`

```gdscript
func remove_cache(path: String) -> void:
```

手动移除缓存项。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

<a id="member-gfassetutility-methods-clear_cache"></a>

### `clear_cache`

- API：`public`

```gdscript
func clear_cache() -> void:
```

清空全部缓存。

<a id="member-gfassetutility-methods-get_cache_count"></a>

### `get_cache_count`

- API：`public`

```gdscript
func get_cache_count() -> int:
```

获取当前缓存数量。

返回：当前缓存中的资源数。

<a id="member-gfassetutility-methods-pin_cache"></a>

### `pin_cache`

- API：`public`

```gdscript
func pin_cache(path: String) -> void:
```

锁定指定缓存路径，使其不参与 LRU 淘汰。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

<a id="member-gfassetutility-methods-unpin_cache"></a>

### `unpin_cache`

- API：`public`

```gdscript
func unpin_cache(path: String) -> void:
```

解除指定缓存路径的 LRU 锁定。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

<a id="member-gfassetutility-methods-is_cache_pinned"></a>

### `is_cache_pinned`

- API：`public`

```gdscript
func is_cache_pinned(path: String) -> bool:
```

检查指定缓存路径是否已被锁定。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |

返回：已锁定返回 true。

<a id="member-gfassetutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取资源加载工具诊断快照。

返回：诊断快照字典。

结构：

- `return`: Dictionary with cache, pending, pending_progress, pinned, reference count, and group count diagnostic fields.
