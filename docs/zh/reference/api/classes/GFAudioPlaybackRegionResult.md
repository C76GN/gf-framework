# GFAudioPlaybackRegionResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_playback_region_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

音频播放区间验证与流准备结果。 以稳定状态和原因说明区间是否有效、是否被执行者精确接受，以及本地准备路径 成功生成的 session 私有音频流。后端评估返回 APPLIED 时可以不携带本地流； 结果不会把音频载荷写入字典快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfaudioplaybackregionresult-enums-status) | `enum Status` |
| 属性 | [`status`](#member-gfaudioplaybackregionresult-properties-status) | `var status: Status = Status.NONE` |
| 属性 | [`reason`](#member-gfaudioplaybackregionresult-properties-reason) | `var reason: StringName:` |
| 属性 | [`message`](#member-gfaudioplaybackregionresult-properties-message) | `var message: String = ""` |
| 属性 | [`prepared_stream`](#member-gfaudioplaybackregionresult-properties-prepared_stream) | `var prepared_stream: AudioStream = null` |
| 属性 | [`start_seconds`](#member-gfaudioplaybackregionresult-properties-start_seconds) | `var start_seconds: float = 0.0` |
| 属性 | [`end_seconds`](#member-gfaudioplaybackregionresult-properties-end_seconds) | `var end_seconds: float = -1.0` |
| 属性 | [`loop_start_seconds`](#member-gfaudioplaybackregionresult-properties-loop_start_seconds) | `var loop_start_seconds: float = -1.0` |
| 属性 | [`loop_mode`](#member-gfaudioplaybackregionresult-properties-loop_mode) | `var loop_mode: int = 0` |
| 方法 | [`is_success`](#member-gfaudioplaybackregionresult-methods-is_success) | `func is_success() -> bool:` |
| 方法 | [`is_applied`](#member-gfaudioplaybackregionresult-methods-is_applied) | `func is_applied() -> bool:` |
| 方法 | [`to_dictionary`](#member-gfaudioplaybackregionresult-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`unsupported`](#member-gfaudioplaybackregionresult-methods-unsupported) | `static func unsupported( reason_id: StringName, result_message: String ) -> GFAudioPlaybackRegionResult:` |
| 方法 | [`status_to_string`](#member-gfaudioplaybackregionresult-methods-status_to_string) | `static func status_to_string(result_status: Status) -> StringName:` |

## 枚举

<a id="member-gfaudioplaybackregionresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 尚未执行验证或准备。
	NONE,
	## 区间结构已验证，但尚未由执行者应用。
	VALID,
	## 执行者已精确接受区间；本地准备路径同时提供 session 私有音频流。
	APPLIED,
	## 区间字段或音频流输入无效。
	INVALID,
	## 区间有效，但当前音频流无法精确表达。
	UNSUPPORTED,
}
```

区间处理状态。

## 属性

<a id="member-gfaudioplaybackregionresult-properties-status"></a>

### `status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var status: Status = Status.NONE
```

区间处理状态。

<a id="member-gfaudioplaybackregionresult-properties-reason"></a>

### `reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var reason: StringName:
```

稳定原因标识。 只接受不超过 128 个字符的小写 ASCII 标识；非法输入会规范化为 `invalid_reason`，避免后端自由文本进入信号或诊断快照。

<a id="member-gfaudioplaybackregionresult-properties-message"></a>

### `message`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var message: String = ""
```

面向开发者的结果说明。

<a id="member-gfaudioplaybackregionresult-properties-prepared_stream"></a>

### `prepared_stream`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var prepared_stream: AudioStream = null
```

本地准备出的 session 私有音频流；后端评估结果不需要填写。

<a id="member-gfaudioplaybackregionresult-properties-start_seconds"></a>

### `start_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var start_seconds: float = 0.0
```

实际播放起点，单位为秒。

<a id="member-gfaudioplaybackregionresult-properties-end_seconds"></a>

### `end_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var end_seconds: float = -1.0
```

实际播放或循环终点，单位为秒；-1 表示自然结尾。

<a id="member-gfaudioplaybackregionresult-properties-loop_start_seconds"></a>

### `loop_start_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var loop_start_seconds: float = -1.0
```

实际循环起点，单位为秒；禁用循环时为 -1。

<a id="member-gfaudioplaybackregionresult-properties-loop_mode"></a>

### `loop_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var loop_mode: int = 0
```

实际循环模式，对应 GFAudioPlaybackRegion.LoopMode 枚举值。

结构：

- `loop_mode`: GFAudioPlaybackRegion.LoopMode enum value stored as int.

## 方法

<a id="member-gfaudioplaybackregionresult-methods-is_success"></a>

### `is_success`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_success() -> bool:
```

检查验证或准备是否成功。

返回：状态为 VALID 或 APPLIED 时返回 true。

<a id="member-gfaudioplaybackregionresult-methods-is_applied"></a>

### `is_applied`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_applied() -> bool:
```

检查执行者是否已经精确接受该播放区间。

返回：状态为 APPLIED 时返回 true。

<a id="member-gfaudioplaybackregionresult-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为不包含音频载荷的字典快照。

返回：区间处理结果字典。

结构：

- `return`: Dictionary with status, success, applied, reason, message, has_prepared_stream, start_seconds, end_seconds, loop_start_seconds, and loop_mode fields.

<a id="member-gfaudioplaybackregionresult-methods-unsupported"></a>

### `unsupported`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func unsupported( reason_id: StringName, result_message: String ) -> GFAudioPlaybackRegionResult:
```

创建显式不支持结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason_id` | 稳定原因标识。 |
| `result_message` | 面向开发者的结果说明。 |

返回：UNSUPPORTED 状态结果。

<a id="member-gfaudioplaybackregionresult-methods-status_to_string"></a>

### `status_to_string`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func status_to_string(result_status: Status) -> StringName:
```

获取处理状态的稳定字符串。

参数：

| 名称 | 说明 |
|---|---|
| `result_status` | 区间处理状态。 |

返回：稳定状态字符串。
