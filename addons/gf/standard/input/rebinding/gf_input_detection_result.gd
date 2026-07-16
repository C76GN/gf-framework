## GFInputDetectionResult: 输入检测结束结果。
##
## 表达 GFInputDetector 一轮检测为什么结束，以及成功时捕获到的输入事件。
## 它不处理冲突、不修改 InputMap，也不绑定具体改键 UI 流程。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
## [br]
## @layer standard/input
class_name GFInputDetectionResult
extends RefCounted


# --- 枚举 ---

## 检测结束原因。
## [br]
## @api public
## [br]
## @since 8.0.0
enum FinishReason {
	## 已检测到可接受输入。
	SUCCESS,
	## 调用方或取消输入结束了检测。
	CANCELLED,
	## 检测超时结束。
	TIMEOUT,
	## 新一轮检测替换了上一轮检测。
	REPLACED,
}


# --- 公共变量 ---

## 检测结束原因。
## [br]
## @api public
## [br]
## @since 8.0.0
var reason: FinishReason = FinishReason.CANCELLED

## 捕获到的输入事件。只有 reason 为 SUCCESS 时应非空。
## [br]
## @api public
## [br]
## @since 8.0.0
var input_event: InputEvent = null

## 本轮检测经过的秒数。
## [br]
## @api public
## [br]
## @since 8.0.0
var elapsed_seconds: float = 0.0

## 本轮检测使用的动作值类型；-1 表示未限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var value_type: int = -1

## 本轮检测允许的设备类型。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema allowed_device_types: Array[int]，包含 GFInputDetector.DeviceType 枚举值；为空表示未限制。
var allowed_device_types: Array[int] = []


# --- 公共方法 ---

## 创建检测结束结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param finish_reason: 检测结束原因。
## [br]
## @param detected_event: 捕获到的输入事件；非成功结果应传 null。
## [br]
## @param detection_elapsed_seconds: 本轮检测经过的秒数。
## [br]
## @param detection_value_type: 本轮检测使用的动作值类型；-1 表示未限制。
## [br]
## @param detection_allowed_device_types: 本轮检测允许的设备类型。
## [br]
## @schema detection_allowed_device_types: Array[int]，包含 GFInputDetector.DeviceType 枚举值；为空表示未限制。
## [br]
## @return 检测结果。
static func create(
	finish_reason: FinishReason,
	detected_event: InputEvent = null,
	detection_elapsed_seconds: float = 0.0,
	detection_value_type: int = -1,
	detection_allowed_device_types: Array[int] = []
) -> GFInputDetectionResult:
	var result: GFInputDetectionResult = GFInputDetectionResult.new()
	result.reason = finish_reason
	result.input_event = detected_event if finish_reason == FinishReason.SUCCESS else null
	result.elapsed_seconds = maxf(detection_elapsed_seconds, 0.0)
	result.value_type = detection_value_type
	result.allowed_device_types = detection_allowed_device_types.duplicate()
	return result


## 检测是否成功捕获输入事件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 成功捕获输入事件时返回 true。
func is_success() -> bool:
	return reason == FinishReason.SUCCESS and input_event != null


## 检测结果是否包含输入事件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 包含输入事件时返回 true。
func has_input_event() -> bool:
	return input_event != null


## 转换为 JSON 安全字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 检测结果字典。
## [br]
## @schema return: Dictionary with reason, success, elapsed_seconds, value_type, allowed_device_types, and input_identity fields.
func to_dictionary() -> Dictionary:
	var input_identity: Dictionary = {}
	if input_event != null:
		input_identity = GFInputEventIdentity.from_event(input_event).to_dictionary()
	return {
		&"reason": String(reason_to_string(reason)),
		&"success": is_success(),
		&"elapsed_seconds": elapsed_seconds,
		&"value_type": value_type,
		&"allowed_device_types": allowed_device_types.duplicate(),
		&"input_identity": input_identity,
	}


## 获取结束原因的稳定字符串。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param finish_reason: 检测结束原因。
## [br]
## @return 结束原因字符串。
static func reason_to_string(finish_reason: FinishReason) -> StringName:
	match finish_reason:
		FinishReason.SUCCESS:
			return &"success"
		FinishReason.CANCELLED:
			return &"cancelled"
		FinishReason.TIMEOUT:
			return &"timeout"
		FinishReason.REPLACED:
			return &"replaced"
	return &"cancelled"
