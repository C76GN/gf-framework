## GFAudioPlaybackRegionResult: 音频播放区间验证与流准备结果。
##
## 以稳定状态和原因说明区间是否有效、是否被执行者精确接受，以及本地准备路径
## 成功生成的 session 私有音频流。后端评估返回 APPLIED 时可以不携带本地流；
## 结果不会把音频载荷写入字典快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFAudioPlaybackRegionResult
extends RefCounted


# --- 枚举 ---

## 区间处理状态。
## [br]
## @api public
## [br]
## @since 11.0.0
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


# --- 公共变量 ---

## 区间处理状态。
## [br]
## @api public
## [br]
## @since 11.0.0
var status: Status = Status.NONE

## 稳定原因标识。
## 只接受不超过 128 个字符的小写 ASCII 标识；非法输入会规范化为
## `invalid_reason`，避免后端自由文本进入信号或诊断快照。
## [br]
## @api public
## [br]
## @since 11.0.0
var reason: StringName:
	get:
		return _reason
	set(value):
		_reason = _normalize_reason(value)

## 面向开发者的结果说明。
## [br]
## @api public
## [br]
## @since 11.0.0
var message: String = ""

## 本地准备出的 session 私有音频流；后端评估结果不需要填写。
## [br]
## @api public
## [br]
## @since 11.0.0
var prepared_stream: AudioStream = null

## 实际播放起点，单位为秒。
## [br]
## @api public
## [br]
## @since 11.0.0
var start_seconds: float = 0.0

## 实际播放或循环终点，单位为秒；-1 表示自然结尾。
## [br]
## @api public
## [br]
## @since 11.0.0
var end_seconds: float = -1.0

## 实际循环起点，单位为秒；禁用循环时为 -1。
## [br]
## @api public
## [br]
## @since 11.0.0
var loop_start_seconds: float = -1.0

## 实际循环模式，对应 GFAudioPlaybackRegion.LoopMode 枚举值。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @schema loop_mode: GFAudioPlaybackRegion.LoopMode enum value stored as int.
var loop_mode: int = 0


# --- 私有变量 ---

var _reason: StringName = &"none"


# --- 公共方法 ---

## 检查验证或准备是否成功。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 状态为 VALID 或 APPLIED 时返回 true。
func is_success() -> bool:
	return status == Status.VALID or status == Status.APPLIED


## 检查执行者是否已经精确接受该播放区间。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 状态为 APPLIED 时返回 true。
func is_applied() -> bool:
	return status == Status.APPLIED


## 转换为不包含音频载荷的字典快照。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 区间处理结果字典。
## [br]
## @schema return: Dictionary with status, success, applied, reason, message, has_prepared_stream, start_seconds, end_seconds, loop_start_seconds, and loop_mode fields.
func to_dictionary() -> Dictionary:
	return {
		"status": String(status_to_string(status)),
		"success": is_success(),
		"applied": is_applied(),
		"reason": String(reason),
		"message": message,
		"has_prepared_stream": prepared_stream != null,
		"start_seconds": start_seconds,
		"end_seconds": end_seconds,
		"loop_start_seconds": loop_start_seconds,
		"loop_mode": loop_mode,
	}


## 创建显式不支持结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param reason_id: 稳定原因标识。
## [br]
## @param result_message: 面向开发者的结果说明。
## [br]
## @return: UNSUPPORTED 状态结果。
static func unsupported(
	reason_id: StringName,
	result_message: String
) -> GFAudioPlaybackRegionResult:
	var result: GFAudioPlaybackRegionResult = GFAudioPlaybackRegionResult.new()
	result.status = Status.UNSUPPORTED
	result.reason = reason_id
	result.message = result_message
	return result


## 获取处理状态的稳定字符串。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result_status: 区间处理状态。
## [br]
## @return 稳定状态字符串。
static func status_to_string(result_status: Status) -> StringName:
	match result_status:
		Status.NONE:
			return &"none"
		Status.VALID:
			return &"valid"
		Status.APPLIED:
			return &"applied"
		Status.INVALID:
			return &"invalid"
		Status.UNSUPPORTED:
			return &"unsupported"
	return &"invalid"


# --- 私有/辅助方法 ---

static func _normalize_reason(value: StringName) -> StringName:
	var text: String = String(value)
	if text.is_empty() or text.length() > 128:
		return &"invalid_reason"
	for index: int in range(text.length()):
		var codepoint: int = text.unicode_at(index)
		var allowed: bool = (
			(codepoint >= 48 and codepoint <= 57)
			or (codepoint >= 97 and codepoint <= 122)
			or codepoint in [45, 46, 95]
		)
		if not allowed:
			return &"invalid_reason"
	return value
