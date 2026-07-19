# GFAssetLoadSessionResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_load_session_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`9.0.0`

资产加载会话终态结果。 结果区分 committed、failed 和 rolled_back，并显式说明回滚只撤销会话分组， 不破坏可能被其他 owner 共享的缓存项。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_COMMITTED`](#member-gfassetloadsessionresult-constants-status_committed) | `const STATUS_COMMITTED: StringName = &"committed"` |
| 常量 | [`STATUS_FAILED`](#member-gfassetloadsessionresult-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`STATUS_ROLLED_BACK`](#member-gfassetloadsessionresult-constants-status_rolled_back) | `const STATUS_ROLLED_BACK: StringName = &"rolled_back"` |
| 方法 | [`is_successful`](#member-gfassetloadsessionresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfassetloadsessionresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_session_id`](#member-gfassetloadsessionresult-methods-get_session_id) | `func get_session_id() -> StringName:` |
| 方法 | [`get_plan_id`](#member-gfassetloadsessionresult-methods-get_plan_id) | `func get_plan_id() -> StringName:` |
| 方法 | [`get_group_id`](#member-gfassetloadsessionresult-methods-get_group_id) | `func get_group_id() -> StringName:` |
| 方法 | [`get_loaded_paths`](#member-gfassetloadsessionresult-methods-get_loaded_paths) | `func get_loaded_paths() -> PackedStringArray:` |
| 方法 | [`get_failed_paths`](#member-gfassetloadsessionresult-methods-get_failed_paths) | `func get_failed_paths() -> PackedStringArray:` |
| 方法 | [`get_error`](#member-gfassetloadsessionresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_rollback_reason`](#member-gfassetloadsessionresult-methods-get_rollback_reason) | `func get_rollback_reason() -> StringName:` |
| 方法 | [`is_cache_retained_on_rollback`](#member-gfassetloadsessionresult-methods-is_cache_retained_on_rollback) | `func is_cache_retained_on_rollback() -> bool:` |
| 方法 | [`get_metadata`](#member-gfassetloadsessionresult-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfassetloadsessionresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_result`](#member-gfassetloadsessionresult-methods-duplicate_result) | `func duplicate_result() -> GFAssetLoadSessionResult:` |

## 常量

<a id="member-gfassetloadsessionresult-constants-status_committed"></a>

### `STATUS_COMMITTED`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STATUS_COMMITTED: StringName = &"committed"
```

会话已原子提交到目标分组。

<a id="member-gfassetloadsessionresult-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

会话因校验或加载失败而回滚。

<a id="member-gfassetloadsessionresult-constants-status_rolled_back"></a>

### `STATUS_ROLLED_BACK`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STATUS_ROLLED_BACK: StringName = &"rolled_back"
```

调用方主动回滚会话。

## 方法

<a id="member-gfassetloadsessionresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_successful() -> bool:
```

检查会话是否已提交。

返回：committed 终态返回 true。

<a id="member-gfassetloadsessionresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_status() -> StringName:
```

获取终态状态。

返回：committed、failed 或 rolled_back。

<a id="member-gfassetloadsessionresult-methods-get_session_id"></a>

### `get_session_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_session_id() -> StringName:
```

获取会话 ID。

返回：会话 ID。

<a id="member-gfassetloadsessionresult-methods-get_plan_id"></a>

### `get_plan_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_plan_id() -> StringName:
```

获取计划 ID。

返回：计划 ID。

<a id="member-gfassetloadsessionresult-methods-get_group_id"></a>

### `get_group_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_group_id() -> StringName:
```

获取目标分组 ID。

返回：目标分组 ID。

<a id="member-gfassetloadsessionresult-methods-get_loaded_paths"></a>

### `get_loaded_paths`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_loaded_paths() -> PackedStringArray:
```

获取成功加载路径副本。

返回：成功加载路径。

<a id="member-gfassetloadsessionresult-methods-get_failed_paths"></a>

### `get_failed_paths`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_failed_paths() -> PackedStringArray:
```

获取失败路径副本。

返回：失败路径。

<a id="member-gfassetloadsessionresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_error() -> String:
```

获取失败说明。

返回：失败说明；提交或主动回滚时可为空。

<a id="member-gfassetloadsessionresult-methods-get_rollback_reason"></a>

### `get_rollback_reason`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_rollback_reason() -> StringName:
```

获取回滚原因。

返回：回滚原因；提交时为空。

<a id="member-gfassetloadsessionresult-methods-is_cache_retained_on_rollback"></a>

### `is_cache_retained_on_rollback`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_cache_retained_on_rollback() -> bool:
```

检查回滚后是否保留已加载缓存。

返回：为保护共享 owner 而保留缓存时返回 true。

<a id="member-gfassetloadsessionresult-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取结果元数据副本。

返回：调用方元数据副本。

结构：

- `return`: Dictionary caller-defined session metadata.

<a id="member-gfassetloadsessionresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：会话结果字典。

结构：

- `return`: Dictionary with ok, status, session_id, plan_id, group_id, loaded_paths, failed_paths, error, rollback_reason, cache_retained_on_rollback, and metadata.

<a id="member-gfassetloadsessionresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_result() -> GFAssetLoadSessionResult:
```

创建结果副本。

返回：隔离结果副本。
