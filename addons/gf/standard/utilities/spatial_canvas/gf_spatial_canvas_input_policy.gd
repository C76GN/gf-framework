## GFSpatialCanvasInputPolicy: 空间画布输入解释策略。
##
## 以数据方式声明平移、选择、滚轮、触摸和取消输入。策略不持有节点、
## Viewport 或父容器引用；[code]GFSpatialCanvas2D[/code] 只接受完整校验通过的隔离副本。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 11.0.0
class_name GFSpatialCanvasInputPolicy
extends Resource


# --- 枚举 ---

## 输入修饰键位掩码。
## [br]
## @api public
## [br]
## @since 11.0.0
enum ModifierMask {
	## 不要求修饰键。
	NONE = 0,
	## Shift 修饰键。
	SHIFT = 1,
	## Ctrl 修饰键。
	CTRL = 2,
	## Alt 修饰键。
	ALT = 4,
	## Meta 修饰键。
	META = 8,
}

## 滚轮缩放使用的物理轴。
## [br]
## @api public
## [br]
## @since 11.0.0
enum WheelAxis {
	## 使用向上/向下滚轮事件。
	VERTICAL,
	## 使用向左/向右滚轮事件。
	HORIZONTAL,
}

## 滚轮事件的画布路由策略。
## [br]
## @api public
## [br]
## @since 11.0.0
enum WheelRouting {
	## 画布处理目标轴上的所有滚轮事件。
	CANVAS,
	## 只有修饰键掩码精确匹配时由画布处理。
	MODIFIER_GATED,
	## 画布始终忽略滚轮，让 GUI 祖先继续处理。
	PARENT_ONLY,
}

## 单指触摸的主行为。
## [br]
## @api public
## [br]
## @since 11.0.0
enum TouchPrimaryBehavior {
	## 单指不执行画布行为；若启用任一多指行为，首触点仍会被捕获以等待后续触点。
	NONE,
	## 单指拖动平移画布。
	PAN,
	## 单指执行点选、框选或放置确认。
	SELECT,
}


# --- 常量 ---

## 单份策略允许声明的选择修饰键绑定绝对上限。
## [br]
## @api public
## [br]
## @since 11.0.0
const ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS: int = 15

## 校验单个 InputMap action 时允许扫描的事件绝对上限。
## [br]
## @api public
## [br]
## @since 11.0.0
const ABSOLUTE_MAX_ACTION_EVENTS: int = 64

const _ALL_MODIFIER_MASK: int = (
	ModifierMask.SHIFT
	| ModifierMask.CTRL
	| ModifierMask.ALT
	| ModifierMask.META
)


# --- 导出变量 ---

## 直接触发平移捕获的鼠标按钮；[constant MOUSE_BUTTON_NONE] 表示禁用直接按钮。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var pan_mouse_button: MouseButton = MOUSE_BUTTON_MIDDLE

## 通过 InputMap 触发平移捕获的动作；空名称表示禁用动作绑定。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var pan_action: StringName = &""

## 直接平移按钮必须精确匹配的修饰键掩码。
##
## 使用 [member pan_action] 时修饰键由 InputMap action 精确声明，本字段必须为 NONE。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_flags("Shift:1", "Ctrl:2", "Alt:4", "Meta:8") var pan_modifier_mask: int = ModifierMask.NONE

## 直接触发选择捕获的鼠标按钮；[constant MOUSE_BUTTON_NONE] 表示禁用直接按钮。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var selection_mouse_button: MouseButton = MOUSE_BUTTON_LEFT

## 通过 InputMap 触发选择捕获的动作；空名称表示禁用动作绑定。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var selection_action: StringName = &""

## 没有选择修饰键绑定精确匹配时使用的 [code]GFSpatialCanvas2D.SelectionMode[/code]。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var selection_default_mode: GFSpatialCanvas2D.SelectionMode = (
	GFSpatialCanvas2D.SelectionMode.REPLACE
)

## 修饰键到选择模式的精确匹配表；重复掩码会使策略校验失败。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var selection_modifier_bindings: Array[GFSpatialCanvasSelectionModeBinding] = []

## 区分点选和框选的局部画布像素阈值。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var drag_threshold: float = 4.0

## 用于画布缩放的滚轮轴。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var wheel_axis: WheelAxis = WheelAxis.VERTICAL

## 滚轮缩放路由策略。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var wheel_routing: WheelRouting = WheelRouting.CANVAS

## [constant WheelRouting.MODIFIER_GATED] 下必须精确匹配的修饰键掩码。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_flags("Shift:1", "Ctrl:2", "Alt:4", "Meta:8") var wheel_modifier_mask: int = ModifierMask.NONE

## 每个滚轮刻度的缩放倍率，必须为有限且大于 1 的值。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var wheel_zoom_factor: float = 1.1

## 是否处理原始 ScreenTouch / ScreenDrag 事件。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var touch_enabled: bool = true

## 单指触摸的主行为。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var touch_primary_behavior: TouchPrimaryBehavior = TouchPrimaryBehavior.PAN

## 是否允许双指及以上触点驱动平移。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var touch_multi_pan_enabled: bool = true

## 是否允许双指及以上触点驱动捏合缩放。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var touch_multi_zoom_enabled: bool = true

## 是否处理 Godot 的系统 PanGesture 事件。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var system_pan_gesture_enabled: bool = true

## 是否处理 Godot 的系统 MagnifyGesture 事件。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var system_magnify_gesture_enabled: bool = true

## 取消活动放置或瞬态选择的非指针 InputMap 动作；空名称表示禁用取消输入。
##
## 动作不得包含鼠标、触摸或位置手势事件，避免取消优先级饿死画布指针行为。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var placement_cancel_action: StringName = &"ui_cancel"

## 一般已处理事件是否由 Canvas GUI 边界消费。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var consume_handled_events: bool = true

## 已处理滚轮事件是否由 Canvas GUI 边界消费。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var consume_wheel_events: bool = true


# --- Godot 生命周期方法 ---

func _init() -> void:
	selection_modifier_bindings = [
		_make_selection_binding(
			ModifierMask.SHIFT,
			GFSpatialCanvas2D.SelectionMode.ADD
		),
		_make_selection_binding(
			ModifierMask.CTRL,
			GFSpatialCanvas2D.SelectionMode.TOGGLE
		),
		_make_selection_binding(
			ModifierMask.META,
			GFSpatialCanvas2D.SelectionMode.TOGGLE
		),
	]


# --- 公共方法 ---

## 校验完整策略。
##
## 校验失败时调用方必须保留上一份有效策略；报告遵循
## [code]GFValidationReportDictionary[/code] 结构。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 策略校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues describing invalid fields.
func validate_policy() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	_validate_pointer_mapping(report, &"pan", pan_mouse_button, pan_action)
	_validate_pointer_mapping(report, &"selection", selection_mouse_button, selection_action)
	_validate_modifier_mask(report, &"pan_modifier_mask", pan_modifier_mask)
	_validate_modifier_mask(report, &"wheel_modifier_mask", wheel_modifier_mask)
	_validate_selection_bindings(report)
	_validate_pointer_mapping_overlap(report)

	if pan_action != &"" and pan_modifier_mask != ModifierMask.NONE:
		_append_issue(
			report,
			&"action_modifier_conflict",
			"pan_action 的修饰键由 InputMap 精确声明，pan_modifier_mask 必须为 NONE。",
			&"pan_modifier_mask"
		)
	if not _is_valid_selection_mode(selection_default_mode):
		_append_issue(report, &"invalid_selection_mode", "selection_default_mode 超出有效枚举范围。", &"selection_default_mode")
	if not _is_finite_float(drag_threshold) or drag_threshold < 0.0:
		_append_issue(report, &"invalid_drag_threshold", "drag_threshold 必须为有限非负值。", &"drag_threshold")
	if wheel_axis < WheelAxis.VERTICAL or wheel_axis > WheelAxis.HORIZONTAL:
		_append_issue(report, &"invalid_wheel_axis", "wheel_axis 超出有效枚举范围。", &"wheel_axis")
	if wheel_routing < WheelRouting.CANVAS or wheel_routing > WheelRouting.PARENT_ONLY:
		_append_issue(report, &"invalid_wheel_routing", "wheel_routing 超出有效枚举范围。", &"wheel_routing")
	if wheel_routing == WheelRouting.MODIFIER_GATED and wheel_modifier_mask == ModifierMask.NONE:
		_append_issue(report, &"missing_wheel_modifier", "Modifier-gated wheel 必须声明非零修饰键。", &"wheel_modifier_mask")
	if not _is_finite_float(wheel_zoom_factor) or wheel_zoom_factor <= 1.0:
		_append_issue(report, &"invalid_wheel_zoom_factor", "wheel_zoom_factor 必须为有限且大于 1 的值。", &"wheel_zoom_factor")
	if (
		touch_primary_behavior < TouchPrimaryBehavior.NONE
		or touch_primary_behavior > TouchPrimaryBehavior.SELECT
	):
		_append_issue(report, &"invalid_touch_behavior", "touch_primary_behavior 超出有效枚举范围。", &"touch_primary_behavior")
	_validate_cancel_action(report)

	return GFValidationReportDictionary.finalize_report(
		report,
		"Spatial canvas input policy",
		{
			"fallback_action": "Fix the first invalid spatial canvas input policy field.",
			"no_action": "No action required.",
		}
	)


## 创建策略及嵌套选择绑定的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新策略。
func duplicate_policy() -> GFSpatialCanvasInputPolicy:
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.pan_mouse_button = pan_mouse_button
	policy.pan_action = pan_action
	policy.pan_modifier_mask = pan_modifier_mask
	policy.selection_mouse_button = selection_mouse_button
	policy.selection_action = selection_action
	policy.selection_default_mode = selection_default_mode
	policy.selection_modifier_bindings.clear()
	var binding_count: int = mini(
		selection_modifier_bindings.size(),
		ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS
	)
	for binding_index: int in range(binding_count):
		var binding: GFSpatialCanvasSelectionModeBinding = selection_modifier_bindings[binding_index]
		if binding == null:
			policy.selection_modifier_bindings.append(null)
		else:
			var copied_binding: GFSpatialCanvasSelectionModeBinding = (
				GFSpatialCanvasSelectionModeBinding.new()
			)
			copied_binding.modifier_mask = binding.modifier_mask
			copied_binding.selection_mode = binding.selection_mode
			policy.selection_modifier_bindings.append(copied_binding)
	if selection_modifier_bindings.size() > ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS:
		policy.selection_modifier_bindings.append(null)
	policy.drag_threshold = drag_threshold
	policy.wheel_axis = wheel_axis
	policy.wheel_routing = wheel_routing
	policy.wheel_modifier_mask = wheel_modifier_mask
	policy.wheel_zoom_factor = wheel_zoom_factor
	policy.touch_enabled = touch_enabled
	policy.touch_primary_behavior = touch_primary_behavior
	policy.touch_multi_pan_enabled = touch_multi_pan_enabled
	policy.touch_multi_zoom_enabled = touch_multi_zoom_enabled
	policy.system_pan_gesture_enabled = system_pan_gesture_enabled
	policy.system_magnify_gesture_enabled = system_magnify_gesture_enabled
	policy.placement_cancel_action = placement_cancel_action
	policy.consume_handled_events = consume_handled_events
	policy.consume_wheel_events = consume_wheel_events
	return policy


# --- 私有/辅助方法 ---

func _validate_pointer_mapping(
	report: Dictionary,
	behavior: StringName,
	button: MouseButton,
	action: StringName
) -> void:
	if button != MOUSE_BUTTON_NONE and not _is_pointer_button(button):
		_append_issue(
			report,
			&"invalid_pointer_button",
			"%s_mouse_button 必须是非滚轮鼠标按钮或 MOUSE_BUTTON_NONE。" % String(behavior),
			StringName("%s_mouse_button" % String(behavior))
		)
	if button != MOUSE_BUTTON_NONE and action != &"":
		_append_issue(
			report,
			&"conflicting_pointer_mapping",
			"%s 不得同时声明直接鼠标按钮与 InputMap action。" % String(behavior),
			StringName("%s_action" % String(behavior))
		)
	if action == &"":
		return
	if not InputMap.has_action(action):
		_append_issue(
			report,
			&"missing_input_action",
			"%s_action 未在 InputMap 中声明。" % String(behavior),
			StringName("%s_action" % String(behavior))
		)
		return
	var action_events: Array[InputEvent] = InputMap.action_get_events(action)
	if action_events.size() > ABSOLUTE_MAX_ACTION_EVENTS:
		_append_issue(
			report,
			&"too_many_action_events",
			"%s_action 的事件数量超过固定校验预算。" % String(behavior),
			StringName("%s_action" % String(behavior))
		)
		return
	var has_pointer_event: bool = false
	for action_event_value: Variant in action_events:
		if not action_event_value is InputEventMouseButton:
			continue
		var action_event: InputEventMouseButton = action_event_value
		if _is_pointer_button(action_event.button_index):
			has_pointer_event = true
			break
	if not has_pointer_event:
		_append_issue(
			report,
			&"missing_pointer_action_event",
			"%s_action 必须至少包含一个非滚轮 InputEventMouseButton。" % String(behavior),
			StringName("%s_action" % String(behavior))
		)


func _validate_modifier_mask(report: Dictionary, field_name: StringName, mask: int) -> void:
	if mask < 0 or (mask & ~_ALL_MODIFIER_MASK) != 0:
		_append_issue(report, &"invalid_modifier_mask", "%s 包含未知修饰键位。" % String(field_name), field_name)


func _validate_selection_bindings(report: Dictionary) -> void:
	var seen_masks: Dictionary = {}
	if (
		selection_modifier_bindings.size()
		> ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS
	):
		_append_issue(
			report,
			&"too_many_selection_bindings",
			"selection_modifier_bindings 超过 15 个非零修饰键组合的固定上限。",
			&"selection_modifier_bindings"
		)
	var binding_count: int = mini(
		selection_modifier_bindings.size(),
		ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS
	)
	for binding_index: int in range(binding_count):
		var binding: GFSpatialCanvasSelectionModeBinding = selection_modifier_bindings[binding_index]
		if binding == null:
			_append_issue(report, &"null_selection_binding", "selection_modifier_bindings 包含空绑定。", &"selection_modifier_bindings", binding_index)
			continue
		_validate_modifier_mask(report, &"selection_modifier_bindings", binding.modifier_mask)
		if binding.modifier_mask == ModifierMask.NONE:
			_append_issue(report, &"empty_selection_modifier", "选择修饰键绑定必须声明非零掩码。", &"selection_modifier_bindings", binding_index)
		if seen_masks.has(binding.modifier_mask):
			_append_issue(report, &"duplicate_selection_modifier", "选择修饰键掩码不得重复。", &"selection_modifier_bindings", binding_index)
		else:
			seen_masks[binding.modifier_mask] = true
		if not _is_valid_selection_mode(binding.selection_mode):
			_append_issue(report, &"invalid_selection_mode", "选择修饰键绑定的 selection_mode 无效。", &"selection_modifier_bindings", binding_index)


func _validate_cancel_action(report: Dictionary) -> void:
	if placement_cancel_action == &"":
		return
	if not InputMap.has_action(placement_cancel_action):
		_append_issue(
			report,
			&"missing_input_action",
			"placement_cancel_action 未在 InputMap 中声明。",
			&"placement_cancel_action"
		)
		return
	var action_events: Array[InputEvent] = InputMap.action_get_events(
		placement_cancel_action
	)
	if action_events.size() > ABSOLUTE_MAX_ACTION_EVENTS:
		_append_issue(
			report,
			&"too_many_action_events",
			"placement_cancel_action 的事件数量超过固定校验预算。",
			&"placement_cancel_action"
		)
		return
	for action_event: InputEvent in action_events:
		if _is_pointer_action_event(action_event):
			_append_issue(
				report,
				&"pointer_cancel_action_event",
				"placement_cancel_action 不得包含鼠标、触摸或位置手势事件。",
				&"placement_cancel_action"
			)
			return


func _validate_pointer_mapping_overlap(report: Dictionary) -> void:
	var pan_chords: Dictionary = _collect_mapping_chords(
		pan_mouse_button,
		pan_action,
		pan_modifier_mask,
		false
	)
	var selection_chords: Dictionary = _collect_mapping_chords(
		selection_mouse_button,
		selection_action,
		ModifierMask.NONE,
		true
	)
	for chord_key: Variant in pan_chords.keys():
		if selection_chords.has(chord_key):
			_append_issue(
				report,
				&"ambiguous_pointer_mapping",
				"pan 与 selection 的物理按钮及修饰键组合发生重叠。",
				&"pan_mouse_button"
			)
			return


func _collect_mapping_chords(
	direct_button: MouseButton,
	action: StringName,
	direct_modifier_mask: int,
	direct_accepts_all_modifiers: bool
) -> Dictionary:
	var result: Dictionary = {}
	if direct_button != MOUSE_BUTTON_NONE:
		if not _is_pointer_button(direct_button):
			return result
		if direct_accepts_all_modifiers:
			for modifier_mask: int in range(_ALL_MODIFIER_MASK + 1):
				result[_make_chord_key(direct_button, modifier_mask)] = true
		else:
			result[_make_chord_key(direct_button, direct_modifier_mask)] = true
		return result
	if action == &"" or not InputMap.has_action(action):
		return result
	var action_events: Array[InputEvent] = InputMap.action_get_events(action)
	if action_events.size() > ABSOLUTE_MAX_ACTION_EVENTS:
		return result
	for action_event_value: Variant in action_events:
		if not action_event_value is InputEventMouseButton:
			continue
		var action_event: InputEventMouseButton = action_event_value
		if not _is_pointer_button(action_event.button_index):
			continue
		var modifier_mask: int = _modifier_mask_from_mouse_event(action_event)
		result[_make_chord_key(action_event.button_index, modifier_mask)] = true
	return result


func _make_chord_key(button: MouseButton, modifier_mask: int) -> int:
	return (int(button) << 8) | modifier_mask


func _modifier_mask_from_mouse_event(event: InputEventMouseButton) -> int:
	var result: int = ModifierMask.NONE
	if event.shift_pressed:
		result |= ModifierMask.SHIFT
	if event.ctrl_pressed:
		result |= ModifierMask.CTRL
	if event.alt_pressed:
		result |= ModifierMask.ALT
	if event.meta_pressed:
		result |= ModifierMask.META
	return result


func _is_pointer_action_event(event: InputEvent) -> bool:
	return (
		event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventGesture
	)


func _append_issue(
	report: Dictionary,
	kind: StringName,
	message: String,
	field_name: StringName,
	index: int = -1
) -> void:
	var fields: Dictionary = { "field": String(field_name) }
	if index >= 0:
		fields["index"] = index
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message,
		fields
	)


func _is_pointer_button(button: MouseButton) -> bool:
	return (
		button == MOUSE_BUTTON_LEFT
		or button == MOUSE_BUTTON_RIGHT
		or button == MOUSE_BUTTON_MIDDLE
		or button == MOUSE_BUTTON_XBUTTON1
		or button == MOUSE_BUTTON_XBUTTON2
	)


func _is_valid_selection_mode(mode: GFSpatialCanvas2D.SelectionMode) -> bool:
	return (
		mode == GFSpatialCanvas2D.SelectionMode.REPLACE
		or mode == GFSpatialCanvas2D.SelectionMode.ADD
		or mode == GFSpatialCanvas2D.SelectionMode.TOGGLE
		or mode == GFSpatialCanvas2D.SelectionMode.SUBTRACT
	)


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _make_selection_binding(
	mask: int,
	mode: GFSpatialCanvas2D.SelectionMode
) -> GFSpatialCanvasSelectionModeBinding:
	var binding: GFSpatialCanvasSelectionModeBinding = GFSpatialCanvasSelectionModeBinding.new()
	binding.modifier_mask = mask
	binding.selection_mode = mode
	return binding
