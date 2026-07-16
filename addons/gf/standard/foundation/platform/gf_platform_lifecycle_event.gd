## GFPlatformLifecycleEvent: 平台生命周期事件。
##
## 用纯数据表达平台 adapter 观察到的前后台、窗口、网络、输入法或资源压力等事件。
## 它不订阅任何平台回调，也不持有场景树状态。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFPlatformLifecycleEvent
extends Resource


# --- 常量 ---

## 平台进入前台或恢复可交互。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_FOREGROUND: StringName = &"foreground"

## 平台进入后台、挂起或不可交互。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_BACKGROUND: StringName = &"background"

## 窗口尺寸或显示区域变化。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_WINDOW_RESIZED: StringName = &"window_resized"

## 安全区域变化。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_SAFE_AREA_CHANGED: StringName = &"safe_area_changed"

## 网络状态变化。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_NETWORK_CHANGED: StringName = &"network_changed"

## 输入法或软键盘显示。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_KEYBOARD_SHOWN: StringName = &"keyboard_shown"

## 输入法或软键盘隐藏。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_KEYBOARD_HIDDEN: StringName = &"keyboard_hidden"

## 平台发出内存压力警告。
## [br]
## @api public
## [br]
## @since 8.0.0
const TYPE_MEMORY_WARNING: StringName = &"memory_warning"


# --- 导出变量 ---

## 事件类型。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var event_type: StringName = &""

## 平台标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var platform_id: StringName = &""

## 单调递增序号。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var sequence: int = 0

## 事件时间戳，单位毫秒。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var timestamp_msec: int = 0

## 事件载荷。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema payload: Dictionary adapter-defined event payload.
@export var payload: Dictionary = {}

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置生命周期事件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_event_type: 事件类型。
## [br]
## @param p_platform_id: 平台标识。
## [br]
## @param p_payload: 事件载荷。
## [br]
## @param p_sequence: 单调递增序号。
## [br]
## @param p_timestamp_msec: 时间戳；小于等于 0 时使用 Time.get_ticks_msec()。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_payload: Dictionary adapter-defined event payload.
## [br]
## @schema p_metadata: Dictionary caller-defined metadata.
## [br]
## @return 当前事件。
func configure(
	p_event_type: StringName,
	p_platform_id: StringName = &"",
	p_payload: Dictionary = {},
	p_sequence: int = 0,
	p_timestamp_msec: int = 0,
	p_metadata: Dictionary = {}
) -> GFPlatformLifecycleEvent:
	event_type = p_event_type
	platform_id = p_platform_id
	payload = p_payload.duplicate(true)
	sequence = max(p_sequence, 0)
	timestamp_msec = p_timestamp_msec if p_timestamp_msec > 0 else Time.get_ticks_msec()
	metadata = p_metadata.duplicate(true)
	return self


## 检查事件类型。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param expected_type: 期望事件类型。
## [br]
## @return 类型一致返回 true。
func is_type(expected_type: StringName) -> bool:
	return event_type == expected_type


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 生命周期事件字典。
## [br]
## @schema return: Dictionary with event_type, platform_id, sequence, timestamp_msec, payload, and metadata.
func to_dict() -> Dictionary:
	return {
		"event_type": event_type,
		"platform_id": platform_id,
		"sequence": sequence,
		"timestamp_msec": timestamp_msec,
		"payload": payload.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用生命周期事件字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 生命周期事件字典。
## [br]
## @schema data: Dictionary with event_type, platform_id, sequence, timestamp_msec, payload, and metadata.
func apply_dict(data: Dictionary) -> void:
	event_type = GFVariantData.get_option_string_name(data, "event_type")
	platform_id = GFVariantData.get_option_string_name(data, "platform_id")
	sequence = max(GFVariantData.get_option_int(data, "sequence"), 0)
	timestamp_msec = max(GFVariantData.get_option_int(data, "timestamp_msec"), 0)
	payload = GFVariantData.get_option_dictionary(data, "payload")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建生命周期事件深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新生命周期事件。
func duplicate_event() -> GFPlatformLifecycleEvent:
	return from_dict(to_dict())


## 从字典创建生命周期事件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 生命周期事件字典。
## [br]
## @schema data: Dictionary with event_type, platform_id, sequence, timestamp_msec, payload, and metadata.
## [br]
## @return 新生命周期事件。
static func from_dict(data: Dictionary) -> GFPlatformLifecycleEvent:
	var result: GFPlatformLifecycleEvent = GFPlatformLifecycleEvent.new()
	result.apply_dict(data)
	return result
