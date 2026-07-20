# GFAssetLoadSession

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_load_session.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`9.0.0`

资产预加载事务句柄。 会话先把资源加载到唯一 staging group，只有全部成功后才提交目标 group。 失败或主动回滚只撤销 staging 所有权，不调用破坏共享句柄的 remove_cache()。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_changed`](#member-gfassetloadsession-signals-state_changed) | `signal state_changed(previous_state: State, current_state: State)` |
| 信号 | [`ready_to_commit`](#member-gfassetloadsession-signals-ready_to_commit) | `signal ready_to_commit(session: GFAssetLoadSession)` |
| 信号 | [`completed`](#member-gfassetloadsession-signals-completed) | `signal completed(result: GFAssetLoadSessionResult)` |
| 枚举 | [`State`](#member-gfassetloadsession-enums-state) | `enum State` |
| 方法 | [`get_session_id`](#member-gfassetloadsession-methods-get_session_id) | `func get_session_id() -> StringName:` |
| 方法 | [`get_group_id`](#member-gfassetloadsession-methods-get_group_id) | `func get_group_id() -> StringName:` |
| 方法 | [`get_state`](#member-gfassetloadsession-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`is_completed`](#member-gfassetloadsession-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfassetloadsession-methods-get_result) | `func get_result() -> GFAssetLoadSessionResult:` |
| 方法 | [`get_load_report`](#member-gfassetloadsession-methods-get_load_report) | `func get_load_report() -> Dictionary:` |
| 方法 | [`commit`](#member-gfassetloadsession-methods-commit) | `func commit() -> bool:` |
| 方法 | [`rollback`](#member-gfassetloadsession-methods-rollback) | `func rollback(reason: StringName = &"caller_requested") -> bool:` |

## 信号

<a id="member-gfassetloadsession-signals-state_changed"></a>

### `state_changed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal state_changed(previous_state: State, current_state: State)
```

会话状态变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_state` | 变化前状态。 |
| `current_state` | 变化后状态。 |

<a id="member-gfassetloadsession-signals-ready_to_commit"></a>

### `ready_to_commit`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal ready_to_commit(session: GFAssetLoadSession)
```

全部资源已加载且等待手动提交时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 当前会话。 |

<a id="member-gfassetloadsession-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal completed(result: GFAssetLoadSessionResult)
```

会话进入 committed、failed 或 rolled_back 终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 隔离终态结果。 |

## 枚举

<a id="member-gfassetloadsession-enums-state"></a>

### `State`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
enum State {
	## 已创建但未开始。
	CREATED,
	## 正在加载 staging group。
	LOADING,
	## 已加载并等待提交或回滚。
	READY,
	## 加载中收到回滚请求，等待在途回调收敛。
	ROLLBACK_PENDING,
	## 已提交目标 group。
	COMMITTED,
	## 加载或校验失败。
	FAILED,
	## 已由调用方回滚。
	ROLLED_BACK,
}
```

资产加载会话状态。

## 方法

<a id="member-gfassetloadsession-methods-get_session_id"></a>

### `get_session_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_session_id() -> StringName:
```

获取会话 ID。

返回：会话 ID。

<a id="member-gfassetloadsession-methods-get_group_id"></a>

### `get_group_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_group_id() -> StringName:
```

获取目标分组 ID。

返回：目标分组 ID。

<a id="member-gfassetloadsession-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_state() -> State:
```

获取会话状态。

返回：当前状态。

<a id="member-gfassetloadsession-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_completed() -> bool:
```

检查会话是否处于任一终态。

返回：committed、failed 或 rolled_back 时返回 true。

<a id="member-gfassetloadsession-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_result() -> GFAssetLoadSessionResult:
```

获取终态结果副本。

返回：终态结果；尚未完成时返回 null。

<a id="member-gfassetloadsession-methods-get_load_report"></a>

### `get_load_report`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_load_report() -> Dictionary:
```

获取底层加载报告副本。

返回：`preload_group_async` 报告副本。

结构：

- `return`: Dictionary with ok, group_id, paths, failed_paths, total, and completed.

<a id="member-gfassetloadsession-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func commit() -> bool:
```

把已加载 staging 路径提交到目标 group。

返回：READY 状态首次提交成功返回 true。

<a id="member-gfassetloadsession-methods-rollback"></a>

### `rollback`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func rollback(reason: StringName = &"caller_requested") -> bool:
```

回滚会话。 READY 状态立即撤销 staging group；LOADING 状态只记录意图，等待在途回调 收敛后再进入 rolled_back，避免迟到回调重新写入 staging group。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 回滚原因。 |

返回：首次接受回滚请求返回 true。
