## GFViewportSurfaceInputCapture: 表面指针按下代际的不可变回执。
##
## 调用方必须保留该回执并在 move、release 或 cancel 时原样交回创建它的
## [code]GFViewportSurfaceInputBridge[/code]。同一 source/device/pointer key 重用后，旧回执不能操作新代际。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFViewportSurfaceInputCapture
extends RefCounted


# --- 私有变量 ---

var _configured: bool = false
var _bridge_instance_id: int = 0
var _source_id: StringName = &""
var _device_id: int = -1
var _pointer_id: int = -1
var _pointer_type: int = -1
var _capture_generation: int = 0
var _target_generation: int = 0


# --- 公共方法 ---

## 检查回执是否已由桥成功配置。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 包含完整指针与代际身份时返回 true。
func is_valid() -> bool:
	return _configured


## 获取输入源标识。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: Resolver 提供的稳定输入源标识。
func get_source_id() -> StringName:
	return _source_id


## 获取设备标识。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 按下时的非负设备标识。
func get_device_id() -> int:
	return _device_id


## 获取输入源内的指针标识。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 按下时的非负指针标识。
func get_pointer_id() -> int:
	return _pointer_id


## 获取指针类型。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: `GFViewportSurfaceInputBridge.PointerType` 值。
func get_pointer_type() -> int:
	return _pointer_type


## 获取桥分配的单调捕获代际。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 大于 0 的捕获代际。
func get_capture_generation() -> int:
	return _capture_generation


## 获取 Resolver 在按下时提供的目标代际。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 大于 0 的外部目标代际。
func get_target_generation() -> int:
	return _target_generation


# --- 层内方法 ---

## 由 Input 层一次性配置回执身份。
## [br]
## @api layer_internal
## [br]
## @layer standard/input
## [br]
## @since 11.0.0
## [br]
## @param bridge_instance_id: 创建桥的非零 Object 实例 ID。
## [br]
## @param source_id: 稳定输入源标识。
## [br]
## @param device_id: 非负设备标识。
## [br]
## @param pointer_id: 非负指针标识。
## [br]
## @param pointer_type: `GFViewportSurfaceInputBridge.PointerType` 值。
## [br]
## @param capture_generation: 桥分配的捕获代际。
## [br]
## @param target_generation: Resolver 提供的目标代际。
## [br]
## @return: 首次且所有身份合法时返回 true。
func configure_from_input_layer(
	bridge_instance_id: int,
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	pointer_type: int,
	capture_generation: int,
	target_generation: int
) -> bool:
	if (
		_configured
		or bridge_instance_id == 0
		or source_id == &""
		or device_id < 0
		or pointer_id < 0
		or pointer_type < 0
		or capture_generation <= 0
		or target_generation <= 0
	):
		return false
	_configured = true
	_bridge_instance_id = bridge_instance_id
	_source_id = source_id
	_device_id = device_id
	_pointer_id = pointer_id
	_pointer_type = pointer_type
	_capture_generation = capture_generation
	_target_generation = target_generation
	return true


## 检查回执是否由指定 Input 桥创建。
## [br]
## @api layer_internal
## [br]
## @layer standard/input
## [br]
## @since 11.0.0
## [br]
## @param bridge_instance_id: 待比对的桥实例 ID。
## [br]
## @return: 回执有效且实例 ID 匹配时返回 true。
func belongs_to_bridge_from_input_layer(bridge_instance_id: int) -> bool:
	return _configured and _bridge_instance_id == bridge_instance_id
