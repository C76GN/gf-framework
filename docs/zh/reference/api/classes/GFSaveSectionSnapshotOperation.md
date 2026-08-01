# GFSaveSectionSnapshotOperation

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_section_snapshot_operation.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

section 主线程协作式快照操作。 Provider 在 `_advance_snapshot()` 中按 work budget 推进一个有界 slice，并通过 `_complete_snapshot()` 或 `_fail_snapshot()` 进入唯一终态。该操作不会创建线程； 所有 Provider 回调仍由 GFSaveProfileUtility 在主线程调度。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_PENDING`](#member-gfsavesectionsnapshotoperation-constants-status_pending) | `const STATUS_PENDING: StringName = &"pending"` |
| 常量 | [`STATUS_RUNNING`](#member-gfsavesectionsnapshotoperation-constants-status_running) | `const STATUS_RUNNING: StringName = &"running"` |
| 常量 | [`STATUS_SUCCEEDED`](#member-gfsavesectionsnapshotoperation-constants-status_succeeded) | `const STATUS_SUCCEEDED: StringName = &"succeeded"` |
| 常量 | [`STATUS_FAILED`](#member-gfsavesectionsnapshotoperation-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfsavesectionsnapshotoperation-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_CLAIMED`](#member-gfsavesectionsnapshotoperation-constants-status_claimed) | `const STATUS_CLAIMED: StringName = &"claimed"` |
| 方法 | [`completed`](#member-gfsavesectionsnapshotoperation-methods-completed) | `static func completed(snapshot: GFSaveSectionSnapshot) -> GFSaveSectionSnapshotOperation:` |
| 方法 | [`get_status`](#member-gfsavesectionsnapshotoperation-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_section_id`](#member-gfsavesectionsnapshotoperation-methods-get_section_id) | `func get_section_id() -> StringName:` |
| 方法 | [`get_schema_version`](#member-gfsavesectionsnapshotoperation-methods-get_schema_version) | `func get_schema_version() -> int:` |
| 方法 | [`is_pending`](#member-gfsavesectionsnapshotoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfsavesectionsnapshotoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`is_successful`](#member-gfsavesectionsnapshotoperation-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfsavesectionsnapshotoperation-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfsavesectionsnapshotoperation-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_consumed_work_units`](#member-gfsavesectionsnapshotoperation-methods-get_consumed_work_units) | `func get_consumed_work_units() -> int:` |
| 方法 | [`_complete_snapshot`](#member-gfsavesectionsnapshotoperation-methods-_complete_snapshot) | `func _complete_snapshot(snapshot: GFSaveSectionSnapshot) -> bool:` |
| 方法 | [`_fail_snapshot`](#member-gfsavesectionsnapshotoperation-methods-_fail_snapshot) | `func _fail_snapshot(error_code: Error, error: String) -> bool:` |
| 方法 | [`_advance_snapshot`](#member-gfsavesectionsnapshotoperation-methods-_advance_snapshot) | `func _advance_snapshot(_step_budget: int) -> int:` |
| 方法 | [`_cancel_snapshot`](#member-gfsavesectionsnapshotoperation-methods-_cancel_snapshot) | `func _cancel_snapshot() -> void:` |

## 常量

<a id="member-gfsavesectionsnapshotoperation-constants-status_pending"></a>

### `STATUS_PENDING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_PENDING: StringName = &"pending"
```

尚未执行 Provider slice。

<a id="member-gfsavesectionsnapshotoperation-constants-status_running"></a>

### `STATUS_RUNNING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RUNNING: StringName = &"running"
```

正在等待后续主线程 slice。

<a id="member-gfsavesectionsnapshotoperation-constants-status_succeeded"></a>

### `STATUS_SUCCEEDED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_SUCCEEDED: StringName = &"succeeded"
```

Snapshot 已准备完成且等待框架接管。

<a id="member-gfsavesectionsnapshotoperation-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

Provider 准备失败。

<a id="member-gfsavesectionsnapshotoperation-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

框架停止了未完成准备。

<a id="member-gfsavesectionsnapshotoperation-constants-status_claimed"></a>

### `STATUS_CLAIMED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_CLAIMED: StringName = &"claimed"
```

成功 Snapshot 已被框架接管。

## 方法

<a id="member-gfsavesectionsnapshotoperation-methods-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func completed(snapshot: GFSaveSectionSnapshot) -> GFSaveSectionSnapshotOperation:
```

创建一个已完成的小型 Snapshot 操作。 大型 Provider 不应在 begin 回调中调用该便捷方法构造完整数据，而应返回自定义 Operation，并在 `_advance_snapshot()` 中按预算分片。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 已封存且尚未接管的 Snapshot。 |

返回：已成功操作；Snapshot 无效时返回已失败操作。

<a id="member-gfsavesectionsnapshotoperation-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取当前稳定状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfsavesectionsnapshotoperation-methods-get_section_id"></a>

### `get_section_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_section_id() -> StringName:
```

获取绑定的 section ID。

返回：配置前为空。

<a id="member-gfsavesectionsnapshotoperation-methods-get_schema_version"></a>

### `get_schema_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_schema_version() -> int:
```

获取绑定的 schema 版本。

返回：配置前为 0。

<a id="member-gfsavesectionsnapshotoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_pending() -> bool:
```

检查是否仍需主线程推进。

返回：pending 或 running 时返回 true。

<a id="member-gfsavesectionsnapshotoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查操作是否已经进入终态。

返回：成功、失败、取消或已接管时返回 true。

<a id="member-gfsavesectionsnapshotoperation-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查 Provider 是否成功准备 Snapshot。

返回：成功或已接管时返回 true。

<a id="member-gfsavesectionsnapshotoperation-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取稳定 Error 码。

返回：失败或取消时的 Error；其他状态为 OK。

<a id="member-gfsavesectionsnapshotoperation-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

获取稳定错误描述。

返回：失败或取消描述。

<a id="member-gfsavesectionsnapshotoperation-methods-get_consumed_work_units"></a>

### `get_consumed_work_units`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_consumed_work_units() -> int:
```

获取框架已计入预算的工作量。

返回：非负 work units。

<a id="member-gfsavesectionsnapshotoperation-methods-_complete_snapshot"></a>

### `_complete_snapshot`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _complete_snapshot(snapshot: GFSaveSectionSnapshot) -> bool:
```

以唯一成功 Snapshot 完成操作。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 已封存且尚未接管的 Snapshot。 |

返回：首次成功完成时返回 true。

<a id="member-gfsavesectionsnapshotoperation-methods-_fail_snapshot"></a>

### `_fail_snapshot`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _fail_snapshot(error_code: Error, error: String) -> bool:
```

以稳定错误完成操作。

参数：

| 名称 | 说明 |
|---|---|
| `error_code` | 非 OK 的 Godot Error 码。 |
| `error` | 不含业务载荷的错误描述。 |

返回：首次失败完成时返回 true。

<a id="member-gfsavesectionsnapshotoperation-methods-_advance_snapshot"></a>

### `_advance_snapshot`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _advance_snapshot(_step_budget: int) -> int:
```

推进一个有界主线程 slice。 实现必须遵守 step_budget，并返回实际消费的 work units。框架无法抢占单次回调， 因此每个 unit 的上界由 Provider 契约保证。

参数：

| 名称 | 说明 |
|---|---|
| `_step_budget` | 本次最多可消费的 work units。 |

返回：实际消费量；框架至少按 1 计费。

<a id="member-gfsavesectionsnapshotoperation-methods-_cancel_snapshot"></a>

### `_cancel_snapshot`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _cancel_snapshot() -> void:
```

响应框架取消。
