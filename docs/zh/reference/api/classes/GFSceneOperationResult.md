# GFSceneOperationResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_operation_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

单次类型化场景请求的不可变终态。 结果冻结请求种类、资源身份、可选 PackedScene 与闭合 status/reason/error 联合。 所有身份 getter 返回隔离快照，调用方不能改写 Operation 已冻结的资源身份。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfsceneoperationresult-enums-status) | `enum Status` |
| 常量 | [`REASON_SCENE_LOADED`](#member-gfsceneoperationresult-constants-reason_scene_loaded) | `const REASON_SCENE_LOADED: StringName = &"scene_loaded"` |
| 常量 | [`REASON_SCENE_PRELOADED`](#member-gfsceneoperationresult-constants-reason_scene_preloaded) | `const REASON_SCENE_PRELOADED: StringName = &"scene_preloaded"` |
| 常量 | [`REASON_CACHE_HIT`](#member-gfsceneoperationresult-constants-reason_cache_hit) | `const REASON_CACHE_HIT: StringName = &"cache_hit"` |
| 常量 | [`REASON_INVALID_PATH`](#member-gfsceneoperationresult-constants-reason_invalid_path) | `const REASON_INVALID_PATH: StringName = &"invalid_path"` |
| 常量 | [`REASON_OWNER_UNAVAILABLE`](#member-gfsceneoperationresult-constants-reason_owner_unavailable) | `const REASON_OWNER_UNAVAILABLE: StringName = &"owner_unavailable"` |
| 常量 | [`REASON_LOAD_BUSY`](#member-gfsceneoperationresult-constants-reason_load_busy) | `const REASON_LOAD_BUSY: StringName = &"load_busy"` |
| 常量 | [`REASON_BROKER_REJECTED`](#member-gfsceneoperationresult-constants-reason_broker_rejected) | `const REASON_BROKER_REJECTED: StringName = &"broker_rejected"` |
| 常量 | [`REASON_RESOURCE_LOAD_FAILED`](#member-gfsceneoperationresult-constants-reason_resource_load_failed) | `const REASON_RESOURCE_LOAD_FAILED: StringName = &"resource_load_failed"` |
| 常量 | [`REASON_RESOURCE_TYPE_MISMATCH`](#member-gfsceneoperationresult-constants-reason_resource_type_mismatch) | `const REASON_RESOURCE_TYPE_MISMATCH: StringName = &"resource_type_mismatch"` |
| 常量 | [`REASON_SCENE_CHANGE_FAILED`](#member-gfsceneoperationresult-constants-reason_scene_change_failed) | `const REASON_SCENE_CHANGE_FAILED: StringName = &"scene_change_failed"` |
| 常量 | [`REASON_CALLER_CANCELLED`](#member-gfsceneoperationresult-constants-reason_caller_cancelled) | `const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"` |
| 常量 | [`REASON_TOKEN_CANCELLED`](#member-gfsceneoperationresult-constants-reason_token_cancelled) | `const REASON_TOKEN_CANCELLED: StringName = &"token_cancelled"` |
| 常量 | [`REASON_OWNER_RELEASED`](#member-gfsceneoperationresult-constants-reason_owner_released) | `const REASON_OWNER_RELEASED: StringName = &"owner_released"` |
| 常量 | [`REASON_PATH_CANCELLED`](#member-gfsceneoperationresult-constants-reason_path_cancelled) | `const REASON_PATH_CANCELLED: StringName = &"path_cancelled"` |
| 常量 | [`REASON_EXTERNAL_CANCELLED`](#member-gfsceneoperationresult-constants-reason_external_cancelled) | `const REASON_EXTERNAL_CANCELLED: StringName = &"external_cancelled"` |
| 常量 | [`REASON_BROKER_DISPOSED`](#member-gfsceneoperationresult-constants-reason_broker_disposed) | `const REASON_BROKER_DISPOSED: StringName = &"broker_disposed"` |
| 常量 | [`REASON_BROKER_CANCELLED`](#member-gfsceneoperationresult-constants-reason_broker_cancelled) | `const REASON_BROKER_CANCELLED: StringName = &"broker_cancelled"` |
| 常量 | [`REASON_UTILITY_DISPOSED`](#member-gfsceneoperationresult-constants-reason_utility_disposed) | `const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"` |
| 方法 | [`get_status`](#member-gfsceneoperationresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`is_successful`](#member-gfsceneoperationresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_request_id`](#member-gfsceneoperationresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_kind`](#member-gfsceneoperationresult-methods-get_kind) | `func get_kind() -> int:` |
| 方法 | [`get_scene_identity`](#member-gfsceneoperationresult-methods-get_scene_identity) | `func get_scene_identity() -> GFResourceIdentity:` |
| 方法 | [`get_scene`](#member-gfsceneoperationresult-methods-get_scene) | `func get_scene() -> PackedScene:` |
| 方法 | [`get_reason`](#member-gfsceneoperationresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfsceneoperationresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`duplicate_result`](#member-gfsceneoperationresult-methods-duplicate_result) | `func duplicate_result() -> GFSceneOperationResult:` |
| 方法 | [`to_dict`](#member-gfsceneoperationresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfsceneoperationresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Status {
	## 场景已缓存，或已经在安全帧成功切换。
	COMPLETED,
	## 请求在 Broker dispatch 前或 admission 边界被拒绝。
	REJECTED,
	## 有效请求在资源加载、类型校验或场景切换阶段失败。
	FAILED,
	## caller、token、owner、path 或共享 Broker 生命周期取消了当前 consumer。
	CANCELLED,
	## Scene Utility 已释放。
	DISPOSED,
}
```

类型化场景请求的唯一 caller 终态。

## 常量

<a id="member-gfsceneoperationresult-constants-reason_scene_loaded"></a>

### `REASON_SCENE_LOADED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_SCENE_LOADED: StringName = &"scene_loaded"
```

已在安全帧成功切换到目标场景。

<a id="member-gfsceneoperationresult-constants-reason_scene_preloaded"></a>

### `REASON_SCENE_PRELOADED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_SCENE_PRELOADED: StringName = &"scene_preloaded"
```

场景资源已成功预加载；是否继续保留在缓存由容量与 fixed 策略决定。

<a id="member-gfsceneoperationresult-constants-reason_cache_hit"></a>

### `REASON_CACHE_HIT`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_CACHE_HIT: StringName = &"cache_hit"
```

请求直接命中已有场景缓存。

<a id="member-gfsceneoperationresult-constants-reason_invalid_path"></a>

### `REASON_INVALID_PATH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_INVALID_PATH: StringName = &"invalid_path"
```

场景路径为空、逃逸项目根目录、不存在或不是 PackedScene。

<a id="member-gfsceneoperationresult-constants-reason_owner_unavailable"></a>

### `REASON_OWNER_UNAVAILABLE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_OWNER_UNAVAILABLE: StringName = &"owner_unavailable"
```

请求 owner 在接纳前已经无效。

<a id="member-gfsceneoperationresult-constants-reason_load_busy"></a>

### `REASON_LOAD_BUSY`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_LOAD_BUSY: StringName = &"load_busy"
```

已有 load 请求正在等待，不允许 replacement。

<a id="member-gfsceneoperationresult-constants-reason_broker_rejected"></a>

### `REASON_BROKER_REJECTED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_BROKER_REJECTED: StringName = &"broker_rejected"
```

Resource Broker 拒绝 consumer Lease 或底层请求 admission。

<a id="member-gfsceneoperationresult-constants-reason_resource_load_failed"></a>

### `REASON_RESOURCE_LOAD_FAILED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_RESOURCE_LOAD_FAILED: StringName = &"resource_load_failed"
```

已接纳的 Broker 请求在运行期加载失败。

<a id="member-gfsceneoperationresult-constants-reason_resource_type_mismatch"></a>

### `REASON_RESOURCE_TYPE_MISMATCH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_RESOURCE_TYPE_MISMATCH: StringName = &"resource_type_mismatch"
```

Broker 完成的资源不是 PackedScene。

<a id="member-gfsceneoperationresult-constants-reason_scene_change_failed"></a>

### `REASON_SCENE_CHANGE_FAILED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_SCENE_CHANGE_FAILED: StringName = &"scene_change_failed"
```

PackedScene 已准备完成，但安全帧场景切换失败。

<a id="member-gfsceneoperationresult-constants-reason_caller_cancelled"></a>

### `REASON_CALLER_CANCELLED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"
```

caller 通过 Operation.cancel() 显式取消当前 consumer。

<a id="member-gfsceneoperationresult-constants-reason_token_cancelled"></a>

### `REASON_TOKEN_CANCELLED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_TOKEN_CANCELLED: StringName = &"token_cancelled"
```

绑定的 cancellation token 请求取消。

<a id="member-gfsceneoperationresult-constants-reason_owner_released"></a>

### `REASON_OWNER_RELEASED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_OWNER_RELEASED: StringName = &"owner_released"
```

绑定的请求 owner 已释放。

<a id="member-gfsceneoperationresult-constants-reason_path_cancelled"></a>

### `REASON_PATH_CANCELLED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_PATH_CANCELLED: StringName = &"path_cancelled"
```

旧 path-level cancel API 取消了同路径的全部 consumer。

<a id="member-gfsceneoperationresult-constants-reason_external_cancelled"></a>

### `REASON_EXTERNAL_CANCELLED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_EXTERNAL_CANCELLED: StringName = &"external_cancelled"
```

共享 Resource Broker 被外部调用方显式取消。

<a id="member-gfsceneoperationresult-constants-reason_broker_disposed"></a>

### `REASON_BROKER_DISPOSED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_BROKER_DISPOSED: StringName = &"broker_disposed"
```

共享 Resource Broker 已释放并取消当前 consumer Lease。

<a id="member-gfsceneoperationresult-constants-reason_broker_cancelled"></a>

### `REASON_BROKER_CANCELLED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_BROKER_CANCELLED: StringName = &"broker_cancelled"
```

Broker 返回了未纳入公开闭合集的取消原因。

<a id="member-gfsceneoperationresult-constants-reason_utility_disposed"></a>

### `REASON_UTILITY_DISPOSED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"
```

Scene Utility 已释放并终结所有等待请求。

## 方法

<a id="member-gfsceneoperationresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> Status:
```

获取请求终态。

返回：`Status` 闭合枚举值。

<a id="member-gfsceneoperationresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

检查请求是否成功完成。

返回：仅 `COMPLETED` 返回 true。

<a id="member-gfsceneoperationresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_request_id() -> int:
```

获取 Scene Utility 内唯一请求 ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfsceneoperationresult-methods-get_kind"></a>

### `get_kind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_kind() -> int:
```

获取请求执行种类。

返回：与 `GFSceneOperation.Kind` 对应的 int enum。

<a id="member-gfsceneoperationresult-methods-get_scene_identity"></a>

### `get_scene_identity`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_scene_identity() -> GFResourceIdentity:
```

获取请求冻结的资源身份副本。

返回：隔离的 GFResourceIdentity 快照；尚未配置时返回 null。

<a id="member-gfsceneoperationresult-methods-get_scene"></a>

### `get_scene`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_scene() -> PackedScene:
```

获取成功完成的 PackedScene。 PackedScene 是 Broker 或缓存交付的规范资源引用；结果副本共享该资源，不复制资源内容。

返回：`COMPLETED` 时返回场景资源；其它终态返回 null。

<a id="member-gfsceneoperationresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reason() -> StringName:
```

获取闭合终态原因。

返回：当前 status 允许的 `REASON_*` 常量之一。

<a id="member-gfsceneoperationresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error_code() -> Error:
```

获取终态 Error 码。

返回：`COMPLETED` 为 OK；其它 status 为与 reason 对应的非 OK 码。

<a id="member-gfsceneoperationresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_result() -> GFSceneOperationResult:
```

创建隔离的结果 value 副本。 资源身份会深复制，PackedScene 保持规范共享引用。

返回：新结果对象。

<a id="member-gfsceneoperationresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为闭合诊断字典。

返回：请求身份、种类、终态、可选场景与错误信息。

结构：

- `return`: Exact Dictionary with status: int enum, successful: bool, request_id: int, kind: int enum, scene_identity: Dictionary, scene: PackedScene or null, has_scene: bool, reason: StringName, and error_code: int fields.
