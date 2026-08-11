# GFBgmStartResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_bgm_start_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单次 BGM start request 的不可变类型化终态。 结果使用闭合 status/reason/error/disposition 联合。只有 `STARTED` 携带已提交的规范 会话句柄；其他终态不伪造会话身份或播放 owner。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfbgmstartresult-enums-status) | `enum Status` |
| 枚举 | [`BackendDisposition`](#member-gfbgmstartresult-enums-backenddisposition) | `enum BackendDisposition` |
| 常量 | [`REASON_LOCAL_STARTED`](#member-gfbgmstartresult-constants-reason_local_started) | `const REASON_LOCAL_STARTED: StringName = &"local_started"` |
| 常量 | [`REASON_BACKEND_STARTED`](#member-gfbgmstartresult-constants-reason_backend_started) | `const REASON_BACKEND_STARTED: StringName = &"backend_started"` |
| 常量 | [`REASON_BACKEND_FALLBACK_STARTED`](#member-gfbgmstartresult-constants-reason_backend_fallback_started) | `const REASON_BACKEND_FALLBACK_STARTED: StringName = &"backend_fallback_started"` |
| 常量 | [`REASON_INVALID_PATH`](#member-gfbgmstartresult-constants-reason_invalid_path) | `const REASON_INVALID_PATH: StringName = &"invalid_path"` |
| 常量 | [`REASON_INVALID_OPTIONS`](#member-gfbgmstartresult-constants-reason_invalid_options) | `const REASON_INVALID_OPTIONS: StringName = &"invalid_options"` |
| 常量 | [`REASON_INVALID_CLIP`](#member-gfbgmstartresult-constants-reason_invalid_clip) | `const REASON_INVALID_CLIP: StringName = &"invalid_clip"` |
| 常量 | [`REASON_INVALID_PLAYBACK_REGION`](#member-gfbgmstartresult-constants-reason_invalid_playback_region) | `const REASON_INVALID_PLAYBACK_REGION: StringName = &"invalid_playback_region"` |
| 常量 | [`REASON_UTILITY_NOT_INITIALIZED`](#member-gfbgmstartresult-constants-reason_utility_not_initialized) | `const REASON_UTILITY_NOT_INITIALIZED: StringName = &"utility_not_initialized"` |
| 常量 | [`REASON_BACKEND_DISPATCH_IN_PROGRESS`](#member-gfbgmstartresult-constants-reason_backend_dispatch_in_progress) | `const REASON_BACKEND_DISPATCH_IN_PROGRESS: StringName = &"backend_dispatch_in_progress"` |
| 常量 | [`REASON_OWNER_UNAVAILABLE`](#member-gfbgmstartresult-constants-reason_owner_unavailable) | `const REASON_OWNER_UNAVAILABLE: StringName = &"owner_unavailable"` |
| 常量 | [`REASON_ASSET_LOAD_FAILED`](#member-gfbgmstartresult-constants-reason_asset_load_failed) | `const REASON_ASSET_LOAD_FAILED: StringName = &"asset_load_failed"` |
| 常量 | [`REASON_STREAM_UNPLAYABLE`](#member-gfbgmstartresult-constants-reason_stream_unplayable) | `const REASON_STREAM_UNPLAYABLE: StringName = &"stream_unplayable"` |
| 常量 | [`REASON_BACKEND_REJECTED_AND_LOCAL_FAILED`](#member-gfbgmstartresult-constants-reason_backend_rejected_and_local_failed) | `const REASON_BACKEND_REJECTED_AND_LOCAL_FAILED: StringName = ( 	&"backend_rejected_and_local_failed" )` |
| 常量 | [`REASON_BACKEND_OWNER_RELEASE_FAILED`](#member-gfbgmstartresult-constants-reason_backend_owner_release_failed) | `const REASON_BACKEND_OWNER_RELEASE_FAILED: StringName = &"backend_owner_release_failed"` |
| 常量 | [`REASON_LOCAL_PLAYER_REJECTED`](#member-gfbgmstartresult-constants-reason_local_player_rejected) | `const REASON_LOCAL_PLAYER_REJECTED: StringName = &"local_player_rejected"` |
| 常量 | [`REASON_SESSION_PUBLICATION_FAILED`](#member-gfbgmstartresult-constants-reason_session_publication_failed) | `const REASON_SESSION_PUBLICATION_FAILED: StringName = &"session_publication_failed"` |
| 常量 | [`REASON_NEWER_REQUEST`](#member-gfbgmstartresult-constants-reason_newer_request) | `const REASON_NEWER_REQUEST: StringName = &"newer_request"` |
| 常量 | [`REASON_CALLER_CANCELLED`](#member-gfbgmstartresult-constants-reason_caller_cancelled) | `const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"` |
| 常量 | [`REASON_OWNER_RELEASED`](#member-gfbgmstartresult-constants-reason_owner_released) | `const REASON_OWNER_RELEASED: StringName = &"owner_released"` |
| 常量 | [`REASON_STOP_REQUESTED`](#member-gfbgmstartresult-constants-reason_stop_requested) | `const REASON_STOP_REQUESTED: StringName = &"stop_requested"` |
| 常量 | [`REASON_UTILITY_DISPOSED`](#member-gfbgmstartresult-constants-reason_utility_disposed) | `const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"` |
| 常量 | [`REASON_BACKEND_CHANGED`](#member-gfbgmstartresult-constants-reason_backend_changed) | `const REASON_BACKEND_CHANGED: StringName = &"backend_changed"` |
| 方法 | [`get_status`](#member-gfbgmstartresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`is_successful`](#member-gfbgmstartresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_request_id`](#member-gfbgmstartresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_reason`](#member-gfbgmstartresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfbgmstartresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_history_key`](#member-gfbgmstartresult-methods-get_history_key) | `func get_history_key() -> String:` |
| 方法 | [`get_owner_kind`](#member-gfbgmstartresult-methods-get_owner_kind) | `func get_owner_kind() -> GFBgmSessionHandle.OwnerKind:` |
| 方法 | [`get_backend_disposition`](#member-gfbgmstartresult-methods-get_backend_disposition) | `func get_backend_disposition() -> BackendDisposition:` |
| 方法 | [`used_backend_fallback`](#member-gfbgmstartresult-methods-used_backend_fallback) | `func used_backend_fallback() -> bool:` |
| 方法 | [`get_session_id`](#member-gfbgmstartresult-methods-get_session_id) | `func get_session_id() -> int:` |
| 方法 | [`get_session_handle`](#member-gfbgmstartresult-methods-get_session_handle) | `func get_session_handle() -> GFBgmSessionHandle:` |
| 方法 | [`duplicate_result`](#member-gfbgmstartresult-methods-duplicate_result) | `func duplicate_result() -> GFBgmStartResult:` |
| 方法 | [`to_dict`](#member-gfbgmstartresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfbgmstartresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 后端或本地播放器已经接受并提交会话。
	STARTED,
	## 请求在接纳前因输入、生命周期或重入边界被拒绝。
	REJECTED,
	## 有效请求在准备或提交阶段失败。
	FAILED,
	## 更新且有效的 BGM 请求取代了当前等待请求。
	SUPERSEDED,
	## 调用方或 owner/Utility 生命周期取消了等待请求。
	CANCELLED,
}
```

BGM start request 的唯一 caller 终态。

<a id="member-gfbgmstartresult-enums-backenddisposition"></a>

### `BackendDisposition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum BackendDisposition {
	## 没有可用后端，或请求在探测前终结。
	NOT_ATTEMPTED,
	## 后端明确不处理该请求，本地路径可继续准备。
	NOT_CLAIMED,
	## 后端声明可处理但拒绝接受播放，本地路径可继续准备。
	REJECTED,
	## 后端接受并持有已提交的 BGM 会话。
	STARTED,
	## 后端调用身份、backend topology/epoch 变化，或已接受候选的 Session 发布失败，
	## 使原请求失效；返回值不得提交。
	INVALIDATED,
}
```

当前请求与可选 Audio Backend 的交互结果。

## 常量

<a id="member-gfbgmstartresult-constants-reason_local_started"></a>

### `REASON_LOCAL_STARTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_LOCAL_STARTED: StringName = &"local_started"
```

本地播放器接受并提交会话。

<a id="member-gfbgmstartresult-constants-reason_backend_started"></a>

### `REASON_BACKEND_STARTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BACKEND_STARTED: StringName = &"backend_started"
```

Audio Backend 接受并提交会话。

<a id="member-gfbgmstartresult-constants-reason_backend_fallback_started"></a>

### `REASON_BACKEND_FALLBACK_STARTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BACKEND_FALLBACK_STARTED: StringName = &"backend_fallback_started"
```

后端未接受请求，本地 fallback 接受并提交会话。

<a id="member-gfbgmstartresult-constants-reason_invalid_path"></a>

### `REASON_INVALID_PATH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_PATH: StringName = &"invalid_path"
```

BGM 路径为空或不符合请求契约。

<a id="member-gfbgmstartresult-constants-reason_invalid_options"></a>

### `REASON_INVALID_OPTIONS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_OPTIONS: StringName = &"invalid_options"
```

BGM options 不符合闭合选项契约。

<a id="member-gfbgmstartresult-constants-reason_invalid_clip"></a>

### `REASON_INVALID_CLIP`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_CLIP: StringName = &"invalid_clip"
```

GFAudioClip 为空、没有 source 或无法冻结。

<a id="member-gfbgmstartresult-constants-reason_invalid_playback_region"></a>

### `REASON_INVALID_PLAYBACK_REGION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_PLAYBACK_REGION: StringName = &"invalid_playback_region"
```

播放区间不符合本地或后端的精确执行契约。

<a id="member-gfbgmstartresult-constants-reason_utility_not_initialized"></a>

### `REASON_UTILITY_NOT_INITIALIZED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_UTILITY_NOT_INITIALIZED: StringName = &"utility_not_initialized"
```

Audio Utility 尚未初始化或已经释放。

<a id="member-gfbgmstartresult-constants-reason_backend_dispatch_in_progress"></a>

### `REASON_BACKEND_DISPATCH_IN_PROGRESS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BACKEND_DISPATCH_IN_PROGRESS: StringName = &"backend_dispatch_in_progress"
```

BGM 请求从 Audio Backend 回调中重入，不能安全接纳。

<a id="member-gfbgmstartresult-constants-reason_owner_unavailable"></a>

### `REASON_OWNER_UNAVAILABLE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_OWNER_UNAVAILABLE: StringName = &"owner_unavailable"
```

请求 owner 在接纳前已经无效。

<a id="member-gfbgmstartresult-constants-reason_asset_load_failed"></a>

### `REASON_ASSET_LOAD_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_ASSET_LOAD_FAILED: StringName = &"asset_load_failed"
```

异步或同步资源加载没有取得音频流。

<a id="member-gfbgmstartresult-constants-reason_stream_unplayable"></a>

### `REASON_STREAM_UNPLAYABLE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_STREAM_UNPLAYABLE: StringName = &"stream_unplayable"
```

取得的音频流无法构造可执行播放计划。

<a id="member-gfbgmstartresult-constants-reason_backend_rejected_and_local_failed"></a>

### `REASON_BACKEND_REJECTED_AND_LOCAL_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BACKEND_REJECTED_AND_LOCAL_FAILED: StringName = (
	&"backend_rejected_and_local_failed"
)
```

后端拒绝后，本地 fallback 也无法开始。

<a id="member-gfbgmstartresult-constants-reason_backend_owner_release_failed"></a>

### `REASON_BACKEND_OWNER_RELEASE_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BACKEND_OWNER_RELEASE_FAILED: StringName = &"backend_owner_release_failed"
```

从旧 backend-owned 会话交接到本地会话时，后端拒绝释放 owner。

<a id="member-gfbgmstartresult-constants-reason_local_player_rejected"></a>

### `REASON_LOCAL_PLAYER_REJECTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_LOCAL_PLAYER_REJECTED: StringName = &"local_player_rejected"
```

本地播放器拒绝已经准备完成的执行计划。

<a id="member-gfbgmstartresult-constants-reason_session_publication_failed"></a>

### `REASON_SESSION_PUBLICATION_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_SESSION_PUBLICATION_FAILED: StringName = &"session_publication_failed"
```

Audio Backend 已接受物理播放候选，但框架无法发布规范 Session 身份。

<a id="member-gfbgmstartresult-constants-reason_newer_request"></a>

### `REASON_NEWER_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_NEWER_REQUEST: StringName = &"newer_request"
```

更新且有效的 BGM 请求取代了当前等待请求。

<a id="member-gfbgmstartresult-constants-reason_caller_cancelled"></a>

### `REASON_CALLER_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"
```

调用方显式取消等待中的 start request。

<a id="member-gfbgmstartresult-constants-reason_owner_released"></a>

### `REASON_OWNER_RELEASED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_OWNER_RELEASED: StringName = &"owner_released"
```

请求 owner 已退出生命周期。

<a id="member-gfbgmstartresult-constants-reason_stop_requested"></a>

### `REASON_STOP_REQUESTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_STOP_REQUESTED: StringName = &"stop_requested"
```

BGM 通道被显式停止。

<a id="member-gfbgmstartresult-constants-reason_utility_disposed"></a>

### `REASON_UTILITY_DISPOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"
```

Audio Utility 已释放。

<a id="member-gfbgmstartresult-constants-reason_backend_changed"></a>

### `REASON_BACKEND_CHANGED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BACKEND_CHANGED: StringName = &"backend_changed"
```

Audio Backend topology 变更流程在请求等待期间开始，并使当前请求失效。

## 方法

<a id="member-gfbgmstartresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取请求终态。

返回：`STARTED`、`REJECTED`、`FAILED`、`SUPERSEDED` 或 `CANCELLED`。

<a id="member-gfbgmstartresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查请求是否成功提交播放会话。

返回：仅 `STARTED` 返回 true。

<a id="member-gfbgmstartresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Utility 内唯一请求 ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfbgmstartresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_reason() -> StringName:
```

获取闭合终态原因。

返回：当前 status 允许的 `REASON_*` 常量之一。

<a id="member-gfbgmstartresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取终态 Error 码。

返回：`STARTED` 为 OK；其他 status 为与 reason 对应的非 OK 码。

<a id="member-gfbgmstartresult-methods-get_history_key"></a>

### `get_history_key`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_history_key() -> String:
```

获取请求冻结的 BGM history key。

返回：请求 history key；未提供时为空字符串。

<a id="member-gfbgmstartresult-methods-get_owner_kind"></a>

### `get_owner_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_owner_kind() -> GFBgmSessionHandle.OwnerKind:
```

获取已提交会话的物理播放 owner。

返回：`STARTED` 为 `LOCAL` 或 `BACKEND`；其他终态为 `NONE`。

<a id="member-gfbgmstartresult-methods-get_backend_disposition"></a>

### `get_backend_disposition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_backend_disposition() -> BackendDisposition:
```

获取本次请求的 Audio Backend 处理结果。

返回：`BackendDisposition` 闭合枚举值。

<a id="member-gfbgmstartresult-methods-used_backend_fallback"></a>

### `used_backend_fallback`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func used_backend_fallback() -> bool:
```

检查请求是否在 backend 未接纳后由本地播放器成功提交。

返回：`STARTED/LOCAL` 且 backend 为 `NOT_CLAIMED` 或 `REJECTED` 时返回 true。

<a id="member-gfbgmstartresult-methods-get_session_id"></a>

### `get_session_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_session_id() -> int:
```

获取已提交会话 ID。

返回：`STARTED` 返回大于零的会话 ID；其他终态返回 0。

<a id="member-gfbgmstartresult-methods-get_session_handle"></a>

### `get_session_handle`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_session_handle() -> GFBgmSessionHandle:
```

获取已提交的规范会话句柄。 结果副本共享同一个会话 capability，避免复制出彼此独立的终态或停止权限。

返回：`STARTED` 返回规范句柄；其他终态返回 null。

<a id="member-gfbgmstartresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFBgmStartResult:
```

创建隔离的结果 value 副本。 标量字段会复制；会话句柄保持规范共享引用。

返回：新结果对象。

<a id="member-gfbgmstartresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不暴露对象引用的闭合报告字典。

返回：请求、终态、backend 处理结果和会话身份的隔离报告。

结构：

- `return`: Exact Dictionary with status: int enum, request_id: int, reason: StringName, error_code: int, history_key: String, owner_kind: int enum, backend_disposition: int enum, used_backend_fallback: bool, and session_id: int fields.
