# GFBgmSessionHandle

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_bgm_session_handle.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

已提交 BGM 播放会话的类型化控制句柄。 句柄只代表一个精确的逻辑会话身份，不暴露本地播放器或后端对象。替换后的旧句柄 不能停止新会话；会话终态只由 Audio Utility 写入一次。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`ended`](#member-gfbgmsessionhandle-signals-ended) | `signal ended(handle: GFBgmSessionHandle, end_kind: EndKind)` |
| 枚举 | [`OwnerKind`](#member-gfbgmsessionhandle-enums-ownerkind) | `enum OwnerKind` |
| 枚举 | [`EndKind`](#member-gfbgmsessionhandle-enums-endkind) | `enum EndKind` |
| 方法 | [`get_session_id`](#member-gfbgmsessionhandle-methods-get_session_id) | `func get_session_id() -> int:` |
| 方法 | [`get_request_id`](#member-gfbgmsessionhandle-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_history_key`](#member-gfbgmsessionhandle-methods-get_history_key) | `func get_history_key() -> String:` |
| 方法 | [`get_owner_kind`](#member-gfbgmsessionhandle-methods-get_owner_kind) | `func get_owner_kind() -> OwnerKind:` |
| 方法 | [`is_active`](#member-gfbgmsessionhandle-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`is_terminal`](#member-gfbgmsessionhandle-methods-is_terminal) | `func is_terminal() -> bool:` |
| 方法 | [`get_end_kind`](#member-gfbgmsessionhandle-methods-get_end_kind) | `func get_end_kind() -> EndKind:` |
| 方法 | [`stop`](#member-gfbgmsessionhandle-methods-stop) | `func stop(fade_seconds: float = 0.0) -> bool:` |

## 信号

<a id="member-gfbgmsessionhandle-signals-ended"></a>

### `ended`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal ended(handle: GFBgmSessionHandle, end_kind: EndKind)
```

会话进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 当前规范会话句柄。 |
| `end_kind` | 会话的唯一终结原因。 |

## 枚举

<a id="member-gfbgmsessionhandle-enums-ownerkind"></a>

### `OwnerKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum OwnerKind {
	## 尚未配置或没有播放 owner。
	NONE,
	## GF 本地 AudioStreamPlayer 会话。
	LOCAL,
	## GFAudioBackend 持有的会话。
	BACKEND,
}
```

BGM 会话的物理播放 owner。

<a id="member-gfbgmsessionhandle-enums-endkind"></a>

### `EndKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum EndKind {
	## 会话仍在活动中；不是终态。
	NONE,
	## 音频自然播放完毕。
	NATURAL_FINISH,
	## 调用方或全局通道显式停止会话。
	STOPPED,
	## 新会话替换了当前会话。
	REPLACED,
	## 会话 owner 已退出生命周期。
	OWNER_RELEASED,
	## Audio Utility 已释放。
	UTILITY_DISPOSED,
	## 已提交的播放会话随后发生物理播放失败。
	PLAYBACK_FAILED,
}
```

BGM 会话的终结原因。

## 方法

<a id="member-gfbgmsessionhandle-methods-get_session_id"></a>

### `get_session_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_session_id() -> int:
```

获取 Utility 内唯一会话 ID。

返回：大于零的会话 ID；尚未配置时返回 0。

<a id="member-gfbgmsessionhandle-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取创建当前会话的 BGM start request ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfbgmsessionhandle-methods-get_history_key"></a>

### `get_history_key`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_history_key() -> String:
```

获取提交会话时冻结的 BGM history key。

返回：会话 history key；未提供时为空字符串。

<a id="member-gfbgmsessionhandle-methods-get_owner_kind"></a>

### `get_owner_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_owner_kind() -> OwnerKind:
```

获取提交会话的物理播放 owner。

返回：`LOCAL`、`BACKEND` 或尚未配置时的 `NONE`。

<a id="member-gfbgmsessionhandle-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

检查会话是否仍处于活动状态。

返回：已配置且尚未终结时返回 true。

<a id="member-gfbgmsessionhandle-methods-is_terminal"></a>

### `is_terminal`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_terminal() -> bool:
```

检查会话是否已经进入终态。

返回：已配置并终结时返回 true。

<a id="member-gfbgmsessionhandle-methods-get_end_kind"></a>

### `get_end_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_end_kind() -> EndKind:
```

获取会话终结原因。

返回：活动会话返回 `NONE`；终态会话返回其唯一终结原因。

<a id="member-gfbgmsessionhandle-methods-stop"></a>

### `stop`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func stop(fade_seconds: float = 0.0) -> bool:
```

请求停止当前精确会话。 返回 true 只表示 Audio Utility 接受了该会话的停止请求；淡出可能在之后完成。 句柄已终结、会话已被替换、Utility 已释放或参数非法时返回 false。

参数：

| 名称 | 说明 |
|---|---|
| `fade_seconds` | 非负且有限的淡出秒数。 |

返回：本次精确会话停止请求被接受时返回 true。
