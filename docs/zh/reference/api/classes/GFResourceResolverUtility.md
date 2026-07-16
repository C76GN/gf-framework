# GFResourceResolverUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_resolver_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

通用资源键解析工具。 将项目稳定资源键解析为路径或已加载 Resource，并支持显式注册表、provider 覆盖链和显式直接路径回退。 它不扫描目录、不下载资源、不解释业务内容类型，也不负责实例化节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`PROVIDER_METHOD`](#member-gfresourceresolverutility-constants-provider_method) | `const PROVIDER_METHOD: StringName = &"resolve_resource"` |
| 方法 | [`init`](#member-gfresourceresolverutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfresourceresolverutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_path`](#member-gfresourceresolverutility-methods-register_path) | `func register_path( resource_key: StringName, path: String, type_hint: String = "", priority: int = 0, metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`register_path_for_owner`](#member-gfresourceresolverutility-methods-register_path_for_owner) | `func register_path_for_owner( resource_key: StringName, owner_id: StringName, path: String, type_hint: String = "", priority: int = 0, metadata: Dictionary = {} ) -> StringName:` |
| 方法 | [`unregister_path`](#member-gfresourceresolverutility-methods-unregister_path) | `func unregister_path(resource_key: StringName) -> bool:` |
| 方法 | [`unregister_registration`](#member-gfresourceresolverutility-methods-unregister_registration) | `func unregister_registration(registration_id: StringName) -> bool:` |
| 方法 | [`unregister_owner`](#member-gfresourceresolverutility-methods-unregister_owner) | `func unregister_owner(owner_id: StringName) -> int:` |
| 方法 | [`replace_owner_paths`](#member-gfresourceresolverutility-methods-replace_owner_paths) | `func replace_owner_paths(owner_id: StringName, entries: Array) -> Dictionary:` |
| 方法 | [`clear_paths`](#member-gfresourceresolverutility-methods-clear_paths) | `func clear_paths() -> void:` |
| 方法 | [`register_provider`](#member-gfresourceresolverutility-methods-register_provider) | `func register_provider(provider: Object, provider_id: StringName = &"", priority: int = 0) -> bool:` |
| 方法 | [`unregister_provider`](#member-gfresourceresolverutility-methods-unregister_provider) | `func unregister_provider(provider: Object) -> bool:` |
| 方法 | [`clear_providers`](#member-gfresourceresolverutility-methods-clear_providers) | `func clear_providers() -> void:` |
| 方法 | [`has_registered_key`](#member-gfresourceresolverutility-methods-has_registered_key) | `func has_registered_key(resource_key: StringName) -> bool:` |
| 方法 | [`get_registered_keys`](#member-gfresourceresolverutility-methods-get_registered_keys) | `func get_registered_keys() -> PackedStringArray:` |
| 方法 | [`resolve`](#member-gfresourceresolverutility-methods-resolve) | `func resolve( resource_key: StringName, type_hint_override: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`resolve_path`](#member-gfresourceresolverutility-methods-resolve_path) | `func resolve_path( resource_key: StringName, type_hint_override: String = "", options: Dictionary = {} ) -> String:` |
| 方法 | [`load`](#member-gfresourceresolverutility-methods-load) | `func load( resource_key: StringName, type_hint_override: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE, options: Dictionary = {} ) -> Resource:` |
| 方法 | [`load_async`](#member-gfresourceresolverutility-methods-load_async) | `func load_async( asset_utility: GFAssetUtility, resource_key: StringName, on_loaded: Callable, type_hint_override: String = "", options: Dictionary = {} ) -> void:` |
| 方法 | [`make_asset_group_entries`](#member-gfresourceresolverutility-methods-make_asset_group_entries) | `func make_asset_group_entries( resource_keys: PackedStringArray, type_hint_override: String = "", options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourceresolverutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfresourceresolverutility-constants-provider_method"></a>

### `PROVIDER_METHOD`

- API：`public`

```gdscript
const PROVIDER_METHOD: StringName = &"resolve_resource"
```

provider 协议方法名。

## 方法

<a id="member-gfresourceresolverutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化解析器运行时状态。

<a id="member-gfresourceresolverutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放解析器运行时状态。

<a id="member-gfresourceresolverutility-methods-register_path"></a>

### `register_path`

- API：`public`

```gdscript
func register_path( resource_key: StringName, path: String, type_hint: String = "", priority: int = 0, metadata: Dictionary = {} ) -> bool:
```

注册一个资源键到资源路径的显式映射。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `path` | Godot 资源路径，通常为 `res://` 或 `uid://`。 |
| `type_hint` | 可选 ResourceLoader 类型提示。 |
| `priority` | 覆盖优先级；数值越大越优先。 |
| `metadata` | 项目自定义元数据，会复制到解析报告。 |

返回：注册成功返回 true。

结构：

- `metadata`: Dictionary project-defined metadata copied into resolution reports.

<a id="member-gfresourceresolverutility-methods-register_path_for_owner"></a>

### `register_path_for_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_path_for_owner( resource_key: StringName, owner_id: StringName, path: String, type_hint: String = "", priority: int = 0, metadata: Dictionary = {} ) -> StringName:
```

注册一个带 owner 的资源键到资源路径映射。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `owner_id` | 注册拥有者 ID；用于批量注销同一来源贡献的映射。 |
| `path` | Godot 资源路径，通常为 `res://` 或 `uid://`。 |
| `type_hint` | 可选 ResourceLoader 类型提示。 |
| `priority` | 覆盖优先级；数值越大越优先。 |
| `metadata` | 项目自定义元数据，会复制到解析报告。 |

返回：成功时返回注册 token；失败时返回空 StringName。

结构：

- `metadata`: Dictionary project-defined metadata copied into resolution reports.

<a id="member-gfresourceresolverutility-methods-unregister_path"></a>

### `unregister_path`

- API：`public`

```gdscript
func unregister_path(resource_key: StringName) -> bool:
```

注销显式路径映射。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |

返回：成功移除返回 true。

<a id="member-gfresourceresolverutility-methods-unregister_registration"></a>

### `unregister_registration`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_registration(registration_id: StringName) -> bool:
```

注销指定注册 token 对应的路径映射。

参数：

| 名称 | 说明 |
|---|---|
| `registration_id` | register_path_for_owner() 返回的注册 token。 |

返回：成功移除返回 true。

<a id="member-gfresourceresolverutility-methods-unregister_owner"></a>

### `unregister_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_owner(owner_id: StringName) -> int:
```

注销指定 owner 的全部路径映射。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | register_path_for_owner() 使用的 owner ID。 |

返回：被移除的映射数量。

<a id="member-gfresourceresolverutility-methods-replace_owner_paths"></a>

### `replace_owner_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func replace_owner_paths(owner_id: StringName, entries: Array) -> Dictionary:
```

原子替换指定 owner 的全部路径映射。 所有条目先在隔离候选表中完成严格 schema 校验和资源身份构建；任一条目失败时， 当前解析表和注册顺序都保持不变。空 entries 表示原子清空该 owner 的映射。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 注册拥有者 ID。 |
| `entries` | owner 的完整路径映射快照。 |

返回：原子替换报告。

结构：

- `entries`: Array[Dictionary]，每项必须包含 resource_key 和 path，可包含 type_hint、priority 与 metadata。
- `return`: Dictionary with ok, owner_id, registered_count, registration_ids, reason, and failed_index.

<a id="member-gfresourceresolverutility-methods-clear_paths"></a>

### `clear_paths`

- API：`public`

```gdscript
func clear_paths() -> void:
```

清空所有显式路径映射。

<a id="member-gfresourceresolverutility-methods-register_provider"></a>

### `register_provider`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func register_provider(provider: Object, provider_id: StringName = &"", priority: int = 0) -> bool:
```

注册一个资源解析 provider。 provider 应实现 `resolve_resource(request: Dictionary) -> Variant`。返回值可为 Dictionary、String 路径或 Resource。 Dictionary 可包含 `ok`、`path`、`resource`、`type_hint`、`cache_key`、`resource_identity`、`reason`、`metadata` 和 `provider_id`。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | provider 对象。 |
| `provider_id` | provider 标识；为空时使用对象类名或实例 ID。 |
| `priority` | 覆盖优先级；数值越大越优先。 |

返回：注册成功返回 true。

<a id="member-gfresourceresolverutility-methods-unregister_provider"></a>

### `unregister_provider`

- API：`public`

```gdscript
func unregister_provider(provider: Object) -> bool:
```

注销资源解析 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | provider 对象。 |

返回：成功移除返回 true。

<a id="member-gfresourceresolverutility-methods-clear_providers"></a>

### `clear_providers`

- API：`public`

```gdscript
func clear_providers() -> void:
```

清空所有 provider。

<a id="member-gfresourceresolverutility-methods-has_registered_key"></a>

### `has_registered_key`

- API：`public`

```gdscript
func has_registered_key(resource_key: StringName) -> bool:
```

检查显式路径映射是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |

返回：存在显式映射时返回 true。

<a id="member-gfresourceresolverutility-methods-get_registered_keys"></a>

### `get_registered_keys`

- API：`public`

```gdscript
func get_registered_keys() -> PackedStringArray:
```

获取已注册的显式资源键。

返回：排序后的资源键列表。

<a id="member-gfresourceresolverutility-methods-resolve"></a>

### `resolve`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func resolve( resource_key: StringName, type_hint_override: String = "", options: Dictionary = {} ) -> Dictionary:
```

解析资源键。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键；启用直接路径回退时也可传 `res://`、`uid://` 或 `user://` 路径。 |
| `type_hint_override` | 可选 ResourceLoader 类型提示覆盖。 |
| `options` | 可选参数。`check_exists` 默认为 true；`allow_direct_path` 默认为 false。 |

返回：解析报告。

结构：

- `options`: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
- `return`: Dictionary with `ok`, `key`, `path`, `type_hint`, `cache_key`, `resource_identity`, `provider_id`, `reason`, `metadata`, and optional `resource`.

<a id="member-gfresourceresolverutility-methods-resolve_path"></a>

### `resolve_path`

- API：`public`

```gdscript
func resolve_path( resource_key: StringName, type_hint_override: String = "", options: Dictionary = {} ) -> String:
```

解析资源键并返回路径。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `type_hint_override` | 可选 ResourceLoader 类型提示覆盖。 |
| `options` | 可选参数，见 `resolve()`。 |

返回：解析成功且结果包含路径时返回路径，否则返回空字符串。

结构：

- `options`: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.

<a id="member-gfresourceresolverutility-methods-load"></a>

### `load`

- API：`public`

```gdscript
func load( resource_key: StringName, type_hint_override: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE, options: Dictionary = {} ) -> Resource:
```

同步加载解析结果。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `type_hint_override` | 可选 ResourceLoader 类型提示覆盖。 |
| `cache_mode` | ResourceLoader 缓存模式。 |
| `options` | 可选参数，见 `resolve()`。 |

返回：加载到的 Resource；解析或加载失败时返回 null。

结构：

- `options`: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.

<a id="member-gfresourceresolverutility-methods-load_async"></a>

### `load_async`

- API：`public`

```gdscript
func load_async( asset_utility: GFAssetUtility, resource_key: StringName, on_loaded: Callable, type_hint_override: String = "", options: Dictionary = {} ) -> void:
```

通过 GFAssetUtility 异步加载解析结果。

参数：

| 名称 | 说明 |
|---|---|
| `asset_utility` | 资源加载工具。 |
| `resource_key` | 稳定资源键。 |
| `on_loaded` | 加载完成回调，签名为 func(resource: Resource)。 |
| `type_hint_override` | 可选 ResourceLoader 类型提示覆盖。 |
| `options` | 可选参数，见 `resolve()`。 |

结构：

- `options`: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.

<a id="member-gfresourceresolverutility-methods-make_asset_group_entries"></a>

### `make_asset_group_entries`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func make_asset_group_entries( resource_keys: PackedStringArray, type_hint_override: String = "", options: Dictionary = {} ) -> Array[Dictionary]:
```

构建可传给 GFAssetUtility.preload_group_async() 的资源请求列表。

参数：

| 名称 | 说明 |
|---|---|
| `resource_keys` | 资源键列表。 |
| `type_hint_override` | 可选 ResourceLoader 类型提示覆盖。 |
| `options` | 可选参数，见 `resolve()`。 |

返回：资源请求列表。

结构：

- `resource_keys`: PackedStringArray selected resource keys.
- `options`: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
- `return`: Array[Dictionary] where each item contains `path`, `type_hint`, `cache_key`, and `resource_identity`.

<a id="member-gfresourceresolverutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取解析器诊断快照。

返回：诊断信息。

结构：

- `return`: Dictionary with `registered_key_count`, `registered_path_count`, `registered_keys`, `registered_cache_keys`, `registered_owner_ids`, `provider_count`, and `providers`.
