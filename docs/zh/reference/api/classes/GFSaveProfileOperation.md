# GFSaveProfileOperation

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_operation.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`10.0.0`

Save Profile 异步操作句柄。 句柄由 `GFSaveProfileUtility` 完成一次且只完成一次。调用方可在连接信号前检查 `is_completed()`，避免立即拒绝或同步恢复结果造成竞态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfsaveprofileoperation-signals-completed) | `signal completed(result: GFSaveProfileResult)` |
| 常量 | [`OPERATION_SAVE`](#member-gfsaveprofileoperation-constants-operation_save) | `const OPERATION_SAVE: StringName = &"save"` |
| 常量 | [`OPERATION_LOAD`](#member-gfsaveprofileoperation-constants-operation_load) | `const OPERATION_LOAD: StringName = &"load"` |
| 常量 | [`OPERATION_FLUSH`](#member-gfsaveprofileoperation-constants-operation_flush) | `const OPERATION_FLUSH: StringName = &"flush"` |
| 方法 | [`get_operation`](#member-gfsaveprofileoperation-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_profile_id`](#member-gfsaveprofileoperation-methods-get_profile_id) | `func get_profile_id() -> StringName:` |
| 方法 | [`get_requested_generation`](#member-gfsaveprofileoperation-methods-get_requested_generation) | `func get_requested_generation() -> int:` |
| 方法 | [`is_pending`](#member-gfsaveprofileoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_running`](#member-gfsaveprofileoperation-methods-is_running) | `func is_running() -> bool:` |
| 方法 | [`is_completed`](#member-gfsaveprofileoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfsaveprofileoperation-methods-get_result) | `func get_result() -> GFSaveProfileResult:` |

## 信号

<a id="member-gfsaveprofileoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal completed(result: GFSaveProfileResult)
```

操作进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 隔离终态结果。 |

## 常量

<a id="member-gfsaveprofileoperation-constants-operation_save"></a>

### `OPERATION_SAVE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OPERATION_SAVE: StringName = &"save"
```

保存操作。

<a id="member-gfsaveprofileoperation-constants-operation_load"></a>

### `OPERATION_LOAD`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OPERATION_LOAD: StringName = &"load"
```

读取操作。

<a id="member-gfsaveprofileoperation-constants-operation_flush"></a>

### `OPERATION_FLUSH`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OPERATION_FLUSH: StringName = &"flush"
```

flush 操作。

## 方法

<a id="member-gfsaveprofileoperation-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_operation() -> StringName:
```

获取操作类型。

返回：save、load 或 flush。

<a id="member-gfsaveprofileoperation-methods-get_profile_id"></a>

### `get_profile_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_profile_id() -> StringName:
```

获取 profile ID。

返回：profile ID。

<a id="member-gfsaveprofileoperation-methods-get_requested_generation"></a>

### `get_requested_generation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_requested_generation() -> int:
```

获取调用时捕获的 generation。

返回：非负 generation。

<a id="member-gfsaveprofileoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_pending() -> bool:
```

检查操作是否等待调度。

返回：尚未运行或完成时返回 true。

<a id="member-gfsaveprofileoperation-methods-is_running"></a>

### `is_running`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_running() -> bool:
```

检查操作是否正在运行。

返回：已启动但无终态时返回 true。

<a id="member-gfsaveprofileoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_completed() -> bool:
```

检查操作是否已有终态。

返回：已完成时返回 true。

<a id="member-gfsaveprofileoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_result() -> GFSaveProfileResult:
```

获取终态结果副本。

返回：已完成结果；等待中返回 null。
