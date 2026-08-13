# GFObjectPoolPrewarmResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_prewarm_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单次对象池预热请求的不可变终态。 结果冻结请求身份、容量准入和每个请求单位的唯一 disposition。调用方可以区分 完成、容量部分接纳、拒绝、取消、Utility 生命周期终结、输入无效与执行失败。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfobjectpoolprewarmresult-enums-status) | `enum Status` |
| 常量 | [`REASON_COMPLETED`](#member-gfobjectpoolprewarmresult-constants-reason_completed) | `const REASON_COMPLETED: StringName = &"completed"` |
| 常量 | [`REASON_CAPACITY_LIMITED`](#member-gfobjectpoolprewarmresult-constants-reason_capacity_limited) | `const REASON_CAPACITY_LIMITED: StringName = &"capacity_limited"` |
| 常量 | [`REASON_CAPACITY_UNAVAILABLE`](#member-gfobjectpoolprewarmresult-constants-reason_capacity_unavailable) | `const REASON_CAPACITY_UNAVAILABLE: StringName = &"capacity_unavailable"` |
| 常量 | [`REASON_CALLER_CANCELLED`](#member-gfobjectpoolprewarmresult-constants-reason_caller_cancelled) | `const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"` |
| 常量 | [`REASON_TOKEN_CANCELLED`](#member-gfobjectpoolprewarmresult-constants-reason_token_cancelled) | `const REASON_TOKEN_CANCELLED: StringName = &"token_cancelled"` |
| 常量 | [`REASON_CANCELLATION_SCOPE_COMPLETED`](#member-gfobjectpoolprewarmresult-constants-reason_cancellation_scope_completed) | `const REASON_CANCELLATION_SCOPE_COMPLETED: StringName = &"cancellation_scope_completed"` |
| 常量 | [`REASON_OWNER_RELEASED`](#member-gfobjectpoolprewarmresult-constants-reason_owner_released) | `const REASON_OWNER_RELEASED: StringName = &"owner_released"` |
| 常量 | [`REASON_PARENT_RELEASED`](#member-gfobjectpoolprewarmresult-constants-reason_parent_released) | `const REASON_PARENT_RELEASED: StringName = &"parent_released"` |
| 常量 | [`REASON_UTILITY_DISPOSED`](#member-gfobjectpoolprewarmresult-constants-reason_utility_disposed) | `const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"` |
| 常量 | [`REASON_UTILITY_REINITIALIZED`](#member-gfobjectpoolprewarmresult-constants-reason_utility_reinitialized) | `const REASON_UTILITY_REINITIALIZED: StringName = &"utility_reinitialized"` |
| 常量 | [`REASON_INVALID_SCENE`](#member-gfobjectpoolprewarmresult-constants-reason_invalid_scene) | `const REASON_INVALID_SCENE: StringName = &"invalid_scene"` |
| 常量 | [`REASON_INVALID_COUNT`](#member-gfobjectpoolprewarmresult-constants-reason_invalid_count) | `const REASON_INVALID_COUNT: StringName = &"invalid_count"` |
| 常量 | [`REASON_INVALID_PARENT`](#member-gfobjectpoolprewarmresult-constants-reason_invalid_parent) | `const REASON_INVALID_PARENT: StringName = &"invalid_parent"` |
| 常量 | [`REASON_INVALID_OWNER`](#member-gfobjectpoolprewarmresult-constants-reason_invalid_owner) | `const REASON_INVALID_OWNER: StringName = &"invalid_owner"` |
| 常量 | [`REASON_INVALID_PREPARE_CALLBACK`](#member-gfobjectpoolprewarmresult-constants-reason_invalid_prepare_callback) | `const REASON_INVALID_PREPARE_CALLBACK: StringName = &"invalid_prepare_callback"` |
| 常量 | [`REASON_SCENE_INSTANTIATION_FAILED`](#member-gfobjectpoolprewarmresult-constants-reason_scene_instantiation_failed) | `const REASON_SCENE_INSTANTIATION_FAILED: StringName = &"scene_instantiation_failed"` |
| 常量 | [`REASON_PREPARE_CALLBACK_FAILED`](#member-gfobjectpoolprewarmresult-constants-reason_prepare_callback_failed) | `const REASON_PREPARE_CALLBACK_FAILED: StringName = &"prepare_callback_failed"` |
| 常量 | [`REASON_INVALID_PREPARE_CALLBACK_RESULT`](#member-gfobjectpoolprewarmresult-constants-reason_invalid_prepare_callback_result) | `const REASON_INVALID_PREPARE_CALLBACK_RESULT: StringName = &"invalid_prepare_callback_result"` |
| 常量 | [`REASON_CANDIDATE_INVALIDATED`](#member-gfobjectpoolprewarmresult-constants-reason_candidate_invalidated) | `const REASON_CANDIDATE_INVALIDATED: StringName = &"candidate_invalidated"` |
| 常量 | [`REASON_INTERNAL_FAILURE`](#member-gfobjectpoolprewarmresult-constants-reason_internal_failure) | `const REASON_INTERNAL_FAILURE: StringName = &"internal_failure"` |
| 方法 | [`get_status`](#member-gfobjectpoolprewarmresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`is_successful`](#member-gfobjectpoolprewarmresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_request_id`](#member-gfobjectpoolprewarmresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_scene_identity`](#member-gfobjectpoolprewarmresult-methods-get_scene_identity) | `func get_scene_identity() -> String:` |
| 方法 | [`get_requested_count`](#member-gfobjectpoolprewarmresult-methods-get_requested_count) | `func get_requested_count() -> int:` |
| 方法 | [`get_admitted_count`](#member-gfobjectpoolprewarmresult-methods-get_admitted_count) | `func get_admitted_count() -> int:` |
| 方法 | [`get_created_count`](#member-gfobjectpoolprewarmresult-methods-get_created_count) | `func get_created_count() -> int:` |
| 方法 | [`get_skipped_count`](#member-gfobjectpoolprewarmresult-methods-get_skipped_count) | `func get_skipped_count() -> int:` |
| 方法 | [`get_cancelled_count`](#member-gfobjectpoolprewarmresult-methods-get_cancelled_count) | `func get_cancelled_count() -> int:` |
| 方法 | [`get_failed_count`](#member-gfobjectpoolprewarmresult-methods-get_failed_count) | `func get_failed_count() -> int:` |
| 方法 | [`get_reason`](#member-gfobjectpoolprewarmresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfobjectpoolprewarmresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`duplicate_result`](#member-gfobjectpoolprewarmresult-methods-duplicate_result) | `func duplicate_result() -> GFObjectPoolPrewarmResult:` |
| 方法 | [`to_dict`](#member-gfobjectpoolprewarmresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfobjectpoolprewarmresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 全部请求单位已经成功创建。
	COMPLETED,
	## 容量只接纳了部分单位，已接纳单位全部成功创建。
	PARTIAL,
	## 有效请求没有可用容量。
	REJECTED,
	## 请求因 caller、token、scope、owner 或 parent 生命周期终结。
	CANCELLED,
	## Object Pool Utility 释放或重新初始化了请求代际。
	DISPOSED,
	## 请求输入不符合契约。
	INVALID,
	## 场景实例化、准备回调或候选提交失败。
	FAILED,
}
```

预热请求的唯一终态。

## 常量

<a id="member-gfobjectpoolprewarmresult-constants-reason_completed"></a>

### `REASON_COMPLETED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_COMPLETED: StringName = &"completed"
```

全部请求单位已经创建。

<a id="member-gfobjectpoolprewarmresult-constants-reason_capacity_limited"></a>

### `REASON_CAPACITY_LIMITED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CAPACITY_LIMITED: StringName = &"capacity_limited"
```

容量只接纳部分请求单位。

<a id="member-gfobjectpoolprewarmresult-constants-reason_capacity_unavailable"></a>

### `REASON_CAPACITY_UNAVAILABLE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CAPACITY_UNAVAILABLE: StringName = &"capacity_unavailable"
```

当前没有可接纳容量。

<a id="member-gfobjectpoolprewarmresult-constants-reason_caller_cancelled"></a>

### `REASON_CALLER_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"
```

caller 显式取消请求。

<a id="member-gfobjectpoolprewarmresult-constants-reason_token_cancelled"></a>

### `REASON_TOKEN_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_TOKEN_CANCELLED: StringName = &"token_cancelled"
```

绑定的 cancellation token 请求取消。

<a id="member-gfobjectpoolprewarmresult-constants-reason_cancellation_scope_completed"></a>

### `REASON_CANCELLATION_SCOPE_COMPLETED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CANCELLATION_SCOPE_COMPLETED: StringName = &"cancellation_scope_completed"
```

绑定的异步作用域已经正常完成。

<a id="member-gfobjectpoolprewarmresult-constants-reason_owner_released"></a>

### `REASON_OWNER_RELEASED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_OWNER_RELEASED: StringName = &"owner_released"
```

请求 owner 已释放或离开场景树。

<a id="member-gfobjectpoolprewarmresult-constants-reason_parent_released"></a>

### `REASON_PARENT_RELEASED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_PARENT_RELEASED: StringName = &"parent_released"
```

请求 parent 已释放、离树或排队删除。

<a id="member-gfobjectpoolprewarmresult-constants-reason_utility_disposed"></a>

### `REASON_UTILITY_DISPOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"
```

Object Pool Utility 已释放。

<a id="member-gfobjectpoolprewarmresult-constants-reason_utility_reinitialized"></a>

### `REASON_UTILITY_REINITIALIZED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_UTILITY_REINITIALIZED: StringName = &"utility_reinitialized"
```

Object Pool Utility 已重新初始化。

<a id="member-gfobjectpoolprewarmresult-constants-reason_invalid_scene"></a>

### `REASON_INVALID_SCENE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_SCENE: StringName = &"invalid_scene"
```

PackedScene 无效。

<a id="member-gfobjectpoolprewarmresult-constants-reason_invalid_count"></a>

### `REASON_INVALID_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_COUNT: StringName = &"invalid_count"
```

请求数量小于零。

<a id="member-gfobjectpoolprewarmresult-constants-reason_invalid_parent"></a>

### `REASON_INVALID_PARENT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_PARENT: StringName = &"invalid_parent"
```

parent 在接纳时无效或已排队删除。

<a id="member-gfobjectpoolprewarmresult-constants-reason_invalid_owner"></a>

### `REASON_INVALID_OWNER`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_OWNER: StringName = &"invalid_owner"
```

owner 在接纳时无效或 Node owner 不在场景树中。

<a id="member-gfobjectpoolprewarmresult-constants-reason_invalid_prepare_callback"></a>

### `REASON_INVALID_PREPARE_CALLBACK`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_PREPARE_CALLBACK: StringName = &"invalid_prepare_callback"
```

prepare_callback 不是空 Callable 或有效 Callable。

<a id="member-gfobjectpoolprewarmresult-constants-reason_scene_instantiation_failed"></a>

### `REASON_SCENE_INSTANTIATION_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_SCENE_INSTANTIATION_FAILED: StringName = &"scene_instantiation_failed"
```

PackedScene 无法实例化为有效 Node。

<a id="member-gfobjectpoolprewarmresult-constants-reason_prepare_callback_failed"></a>

### `REASON_PREPARE_CALLBACK_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_PREPARE_CALLBACK_FAILED: StringName = &"prepare_callback_failed"
```

prepare_callback 显式返回非 OK Error。

<a id="member-gfobjectpoolprewarmresult-constants-reason_invalid_prepare_callback_result"></a>

### `REASON_INVALID_PREPARE_CALLBACK_RESULT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_PREPARE_CALLBACK_RESULT: StringName = &"invalid_prepare_callback_result"
```

prepare_callback 返回值不是合法 Error 整数。

<a id="member-gfobjectpoolprewarmresult-constants-reason_candidate_invalidated"></a>

### `REASON_CANDIDATE_INVALIDATED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CANDIDATE_INVALIDATED: StringName = &"candidate_invalidated"
```

候选在提交前被重入或生命周期变化失效。

<a id="member-gfobjectpoolprewarmresult-constants-reason_internal_failure"></a>

### `REASON_INTERNAL_FAILURE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INTERNAL_FAILURE: StringName = &"internal_failure"
```

框架无法安全归类的内部失败。

## 方法

<a id="member-gfobjectpoolprewarmresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取请求终态。

返回：`Status` 闭合枚举值。

<a id="member-gfobjectpoolprewarmresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查请求是否完成了全部或部分容量准入。

返回：`COMPLETED` 或 `PARTIAL` 返回 true。

<a id="member-gfobjectpoolprewarmresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Utility 内唯一请求 ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfobjectpoolprewarmresult-methods-get_scene_identity"></a>

### `get_scene_identity`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_scene_identity() -> String:
```

获取请求冻结的场景身份。

返回：资源路径或实例 ID 身份。

<a id="member-gfobjectpoolprewarmresult-methods-get_requested_count"></a>

### `get_requested_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_requested_count() -> int:
```

获取调用方请求数量。

返回：非负数量。

<a id="member-gfobjectpoolprewarmresult-methods-get_admitted_count"></a>

### `get_admitted_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_admitted_count() -> int:
```

获取容量准入数量。

返回：非负且不大于 requested 的数量。

<a id="member-gfobjectpoolprewarmresult-methods-get_created_count"></a>

### `get_created_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_created_count() -> int:
```

获取成功提交到池中的数量。

返回：成功创建数量。

<a id="member-gfobjectpoolprewarmresult-methods-get_skipped_count"></a>

### `get_skipped_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_skipped_count() -> int:
```

获取未获容量准入的数量。

返回：`requested - admitted`。

<a id="member-gfobjectpoolprewarmresult-methods-get_cancelled_count"></a>

### `get_cancelled_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cancelled_count() -> int:
```

获取因取消或生命周期终结而未创建的准入数量。

返回：取消数量。

<a id="member-gfobjectpoolprewarmresult-methods-get_failed_count"></a>

### `get_failed_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failed_count() -> int:
```

获取因执行失败而未创建的准入数量。

返回：失败数量。

<a id="member-gfobjectpoolprewarmresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_reason() -> StringName:
```

获取唯一终态原因。

返回：与 status/error 对应的 `REASON_*`。

<a id="member-gfobjectpoolprewarmresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取终态 Error。

返回：与 status/reason 对应的 Error。

<a id="member-gfobjectpoolprewarmresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFObjectPoolPrewarmResult:
```

创建隔离结果副本。

返回：新结果对象。

<a id="member-gfobjectpoolprewarmresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不含 Object 引用的闭合诊断字典。

返回：请求身份、计数与终态。

结构：

- `return`: Exact Dictionary with status: int enum, request_id: int, scene_identity: String, requested_count: int, admitted_count: int, created_count: int, skipped_count: int, cancelled_count: int, failed_count: int, reason: StringName, error_code: int, and successful: bool fields.
