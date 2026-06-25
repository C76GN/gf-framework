## GFInputBinding: 把一个 Godot 输入事件映射到动作值贡献。
##
## 该资源只描述输入来源和数值方向，实际动作归属由 GFInputMapping 决定。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputBinding
extends Resource


# --- 枚举 ---

## 输入值贡献目标。
## [br]
## @api public
enum ValueTarget {
	## 根据动作值类型自动映射；二维/三维轴默认写入 X 分量，需要其他分量时使用显式 AXIS_* 目标。
	AUTO,
	## 只作为开关输入。
	BOOL,
	## 一维轴正向。
	AXIS_1D_POSITIVE,
	## 一维轴负向。
	AXIS_1D_NEGATIVE,
	## 二维轴 X 正向。
	AXIS_2D_X_POSITIVE,
	## 二维轴 X 负向。
	AXIS_2D_X_NEGATIVE,
	## 二维轴 Y 正向。
	AXIS_2D_Y_POSITIVE,
	## 二维轴 Y 负向。
	AXIS_2D_Y_NEGATIVE,
	## 三维轴 X 正向。
	AXIS_3D_X_POSITIVE,
	## 三维轴 X 负向。
	AXIS_3D_X_NEGATIVE,
	## 三维轴 Y 正向。
	AXIS_3D_Y_POSITIVE,
	## 三维轴 Y 负向。
	AXIS_3D_Y_NEGATIVE,
	## 三维轴 Z 正向。
	AXIS_3D_Z_POSITIVE,
	## 三维轴 Z 负向。
	AXIS_3D_Z_NEGATIVE,
}


# --- 导出变量 ---

## Godot 原生输入事件模板。
## [br]
## @api public
@export var input_event: InputEvent

## 当前绑定贡献到动作值的方向。
## [br]
## @api public
@export var value_target: ValueTarget = ValueTarget.AUTO

## 轴输入死区。对按键和按钮输入无影响。
## [br]
## @api public
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.2

## 输入贡献缩放。
## [br]
## @api public
@export var scale: float = 1.0

## 绑定级输入修饰器，按顺序作用于该绑定产生的贡献值。
## [br]
## @api public
@export var modifiers: Array[GFInputModifier] = []

## 是否按设备 ID 精确匹配。关闭时同类按键、鼠标按钮或手柄按钮可跨设备匹配。
## 旧资源中的键鼠设备 ID 0 会兼容 Godot 4.7 的键鼠设备 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var match_device: bool = false

## 是否按触点 index 精确匹配 InputEventScreenTouch。
## 默认关闭，表示任意触点都可匹配该绑定。
## [br]
## @api public
@export var match_touch_index: bool = false

## 覆盖显示名称。
## [br]
## @api public
@export var display_name: String = ""

## 该绑定是否可被玩家重绑。
## [br]
## @api public
@export var remappable: bool = true


# --- 公共方法 ---

## 创建深拷贝，避免运行时重映射污染原始资源。
## [br]
## @api public
## [br]
## @return 新绑定。
func duplicate_binding() -> GFInputBinding:
	var binding: GFInputBinding = _instantiate_binding()
	if input_event != null:
		binding.input_event = _variant_to_input_event(input_event.duplicate(true))
	else:
		binding.input_event = null
	binding.value_target = value_target
	binding.deadzone = deadzone
	binding.scale = scale
	binding.modifiers = _duplicate_modifiers()
	binding.match_device = match_device
	binding.match_touch_index = match_touch_index
	binding.display_name = display_name
	binding.remappable = remappable
	return binding


## 判断当前绑定是否匹配输入事件。
## [br]
## @api public
## [br]
## @param event: 运行时输入事件。
## [br]
## @return 是否匹配。
func matches_event(event: InputEvent) -> bool:
	if input_event == null or event == null:
		return false
	if match_device and not _devices_match(event, input_event):
		return false

	if input_event is InputEventAction and event is InputEventAction:
		var template_action: InputEventAction = input_event
		var runtime_action: InputEventAction = event
		return template_action.action == runtime_action.action

	if input_event is InputEventKey and event is InputEventKey:
		var template_key_event: InputEventKey = input_event
		var runtime_key_event: InputEventKey = event
		return _matches_key(runtime_key_event, template_key_event)

	if input_event is InputEventMouseButton and event is InputEventMouseButton:
		var template_mouse: InputEventMouseButton = input_event
		var runtime_mouse: InputEventMouseButton = event
		return template_mouse.button_index == runtime_mouse.button_index

	if input_event is InputEventJoypadButton and event is InputEventJoypadButton:
		var template_button: InputEventJoypadButton = input_event
		var runtime_button: InputEventJoypadButton = event
		return template_button.button_index == runtime_button.button_index

	if input_event is InputEventJoypadMotion and event is InputEventJoypadMotion:
		var template_axis: InputEventJoypadMotion = input_event
		var runtime_axis: InputEventJoypadMotion = event
		return template_axis.axis == runtime_axis.axis

	if input_event is InputEventScreenTouch and event is InputEventScreenTouch:
		var template_touch: InputEventScreenTouch = input_event
		var runtime_touch: InputEventScreenTouch = event
		return (
			not match_touch_index
			or template_touch.index == runtime_touch.index
		)

	return input_event.is_match(event, true)


## 计算该输入事件对动作值的贡献。
## [br]
## @api public
## [br]
## @param event: 运行时输入事件。
## [br]
## @param action_value_type: 动作值类型。
## [br]
## @param deadzone_override: 可选死区覆盖；小于 0 时使用绑定自身 deadzone。
## [br]
## @return 三维向量贡献；布尔与一维轴使用 x 分量，二维轴使用 x/y 分量。
func get_contribution(
	event: InputEvent,
	action_value_type: GFInputAction.ValueType,
	deadzone_override: float = -1.0
) -> Vector3:
	var effective_deadzone: float = deadzone if deadzone_override < 0.0 else clampf(deadzone_override, 0.0, 1.0)
	var raw_value: float = _read_event_value(event, effective_deadzone)
	if value_target == ValueTarget.AUTO:
		return _get_auto_contribution(raw_value, event, action_value_type)

	var strength: float = _get_target_strength(event, raw_value, value_target)
	if strength < effective_deadzone:
		strength = 0.0

	match value_target:
		ValueTarget.BOOL:
			return _apply_modifiers(Vector3(strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_1D_POSITIVE:
			return _apply_modifiers(Vector3(strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_1D_NEGATIVE:
			return _apply_modifiers(Vector3(-strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_2D_X_POSITIVE:
			return _apply_modifiers(Vector3(strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_2D_X_NEGATIVE:
			return _apply_modifiers(Vector3(-strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_2D_Y_POSITIVE:
			return _apply_modifiers(Vector3(0.0, strength * scale, 0.0), event, action_value_type)
		ValueTarget.AXIS_2D_Y_NEGATIVE:
			return _apply_modifiers(Vector3(0.0, -strength * scale, 0.0), event, action_value_type)
		ValueTarget.AXIS_3D_X_POSITIVE:
			return _apply_modifiers(Vector3(strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_3D_X_NEGATIVE:
			return _apply_modifiers(Vector3(-strength * scale, 0.0, 0.0), event, action_value_type)
		ValueTarget.AXIS_3D_Y_POSITIVE:
			return _apply_modifiers(Vector3(0.0, strength * scale, 0.0), event, action_value_type)
		ValueTarget.AXIS_3D_Y_NEGATIVE:
			return _apply_modifiers(Vector3(0.0, -strength * scale, 0.0), event, action_value_type)
		ValueTarget.AXIS_3D_Z_POSITIVE:
			return _apply_modifiers(Vector3(0.0, 0.0, strength * scale), event, action_value_type)
		ValueTarget.AXIS_3D_Z_NEGATIVE:
			return _apply_modifiers(Vector3(0.0, 0.0, -strength * scale), event, action_value_type)
		_:
			return Vector3.ZERO


## 获取显示名称。
## [br]
## @api public
## [br]
## @return 显示名称；为空时由输入事件格式化。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if input_event == null:
		return "Unbound"
	return input_event.as_text()


# --- 私有/辅助方法 ---

func _devices_match(event: InputEvent, template: InputEvent) -> bool:
	if event.device == template.device:
		return true
	if event.device != 0 and template.device != 0:
		return false
	return _is_keyboard_mouse_event(event) and _is_keyboard_mouse_event(template)


func _is_keyboard_mouse_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouse


func _matches_key(event: InputEventKey, template: InputEventKey) -> bool:
	var template_key: Key = template.physical_keycode
	if template_key == KEY_NONE:
		template_key = template.keycode

	var event_key: Key = event.physical_keycode
	if event_key == KEY_NONE:
		event_key = event.keycode

	if not event.pressed:
		return template_key == event_key

	return (
		template_key == event_key
		and template.ctrl_pressed == event.ctrl_pressed
		and template.alt_pressed == event.alt_pressed
		and template.shift_pressed == event.shift_pressed
		and template.meta_pressed == event.meta_pressed
	)


func _read_event_value(event: InputEvent, effective_deadzone: float) -> float:
	if event is InputEventAction:
		var action_event: InputEventAction = event
		return action_event.strength if action_event.pressed else 0.0

	if event is InputEventKey:
		var key_event: InputEventKey = event
		return 1.0 if key_event.pressed else 0.0

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		return mouse_event.factor if mouse_event.pressed else 0.0

	if event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event
		return joy_button.pressure if joy_button.pressed else 0.0

	if event is InputEventJoypadMotion:
		var axis_event: InputEventJoypadMotion = event
		return axis_event.axis_value if absf(axis_event.axis_value) >= effective_deadzone else 0.0

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		return 1.0 if touch_event.pressed else 0.0

	return 0.0


func _get_target_strength(event: InputEvent, raw_value: float, target: ValueTarget) -> float:
	if event is InputEventJoypadMotion:
		match target:
			ValueTarget.AXIS_1D_POSITIVE, ValueTarget.AXIS_2D_X_POSITIVE, ValueTarget.AXIS_2D_Y_POSITIVE, ValueTarget.AXIS_3D_X_POSITIVE, ValueTarget.AXIS_3D_Y_POSITIVE, ValueTarget.AXIS_3D_Z_POSITIVE:
				return maxf(raw_value, 0.0)
			ValueTarget.AXIS_1D_NEGATIVE, ValueTarget.AXIS_2D_X_NEGATIVE, ValueTarget.AXIS_2D_Y_NEGATIVE, ValueTarget.AXIS_3D_X_NEGATIVE, ValueTarget.AXIS_3D_Y_NEGATIVE, ValueTarget.AXIS_3D_Z_NEGATIVE:
				return maxf(-raw_value, 0.0)
			_:
				return absf(raw_value)
	return absf(raw_value)


func _get_auto_contribution(
	raw_value: float,
	event: InputEvent,
	action_value_type: GFInputAction.ValueType
) -> Vector3:
	match action_value_type:
		GFInputAction.ValueType.BOOL:
			return _apply_modifiers(Vector3(absf(raw_value) * scale, 0.0, 0.0), event, action_value_type)
		GFInputAction.ValueType.AXIS_1D:
			return _apply_modifiers(Vector3(raw_value * scale, 0.0, 0.0), event, action_value_type)
		GFInputAction.ValueType.AXIS_2D:
			return _apply_modifiers(Vector3(raw_value * scale, 0.0, 0.0), event, action_value_type)
		GFInputAction.ValueType.AXIS_3D:
			return _apply_modifiers(Vector3(raw_value * scale, 0.0, 0.0), event, action_value_type)
		_:
			return Vector3.ZERO


func _apply_modifiers(
	value: Vector3,
	event: InputEvent,
	action_value_type: GFInputAction.ValueType
) -> Vector3:
	var result: Vector3 = value
	for modifier: GFInputModifier in modifiers:
		if modifier != null:
			if action_value_type == GFInputAction.ValueType.AXIS_3D:
				result = modifier.modify_3d(result, event, null)
			else:
				var modified: Vector2 = modifier.modify(Vector2(result.x, result.y), event, null)
				result = Vector3(modified.x, modified.y, result.z)
	return result


func _duplicate_modifiers() -> Array[GFInputModifier]:
	var result: Array[GFInputModifier] = []
	for modifier: GFInputModifier in modifiers:
		if modifier == null:
			continue
		var duplicate_modifier: GFInputModifier = modifier.duplicate_modifier()
		if duplicate_modifier != null:
			result.append(duplicate_modifier)
	return result


func _instantiate_binding() -> GFInputBinding:
	var script_value: Variant = get_script()
	if script_value is Script:
		var script: Script = script_value
		var instance: Variant = script.call("new")
		if instance is GFInputBinding:
			var binding: GFInputBinding = instance
			return binding
	return GFInputBinding.new()


func _variant_to_input_event(value: Variant) -> InputEvent:
	if value is InputEvent:
		var event: InputEvent = value
		return event
	return null
