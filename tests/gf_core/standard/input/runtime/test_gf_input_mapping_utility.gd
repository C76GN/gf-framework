## 测试 GFInputMappingUtility 的资源化输入上下文、重映射和动作状态行为。
extends GutTest

# --- 辅助类 ---

class CustomKeyTextProvider extends GFInputTextProvider:
	func _init(p_priority: int = 0) -> void:
		priority = p_priority

	func supports_event(input_event: InputEvent, _options: Dictionary = {}) -> bool:
		if not (input_event is InputEventKey):
			return false
		var key_event: InputEventKey = input_event
		return key_event.keycode == KEY_K

	func get_event_text(_input_event: InputEvent, options: Dictionary = {}) -> String:
		return GFVariantData.get_option_string(options, "label", "Custom K")


class CustomKeyIconProvider extends GFInputIconProvider:
	func supports_event(input_event: InputEvent, _options: Dictionary = {}) -> bool:
		if not (input_event is InputEventKey):
			return false
		var key_event: InputEventKey = input_event
		return key_event.keycode == KEY_K

	func get_event_rich_text(_input_event: InputEvent, _options: Dictionary = {}) -> String:
		return "[color=yellow]K[/color]"


class InputConsumeSystem extends GFSystem:
	var input_runtime: GFInputMappingUtility = null
	var action_id: StringName = &"jump"
	var consumed_count: int = 0

	func tick(_delta: float) -> void:
		if input_runtime != null and input_runtime.consume_action(action_id):
			consumed_count += 1


# --- 私有变量 ---

var _utility: GFInputMappingUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_utility = GFInputMappingUtility.new()
	_utility.init()


func after_each() -> void:
	GFInputFormatter.clear_text_providers()
	GFInputFormatter.clear_icon_providers()
	if _utility != null:
		_utility.dispose()
		_utility = null
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	await get_tree().process_frame


# --- 测试方法 ---

## 验证布尔动作可由按键事件激活、消费并释放。
func test_bool_action_press_consume_and_release() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_SPACE, true))

	assert_true(_utility.is_action_active(&"jump"), "按下绑定按键后动作应活跃。")
	assert_true(_utility.was_action_just_started(&"jump"), "首次按下应记录 just started。")
	assert_true(_utility.consume_action(&"jump"), "刚触发动作应可被消费。")
	assert_false(_utility.consume_action(&"jump"), "同一次触发不应被重复消费。")

	_utility.tick(0.2)
	_utility.handle_input_event(_make_key_event(KEY_SPACE, false))

	assert_false(_utility.is_action_active(&"jump"), "释放按键后动作应结束。")
	assert_true(_utility.was_action_just_completed(&"jump"), "释放帧应记录 just completed。")
	assert_almost_eq(_utility.get_last_completed_duration(&"jump"), 0.2, 0.001, "应记录本次按住时间。")


## 验证 just started 状态会保留到 Utility tick 清理窗口。
func test_just_started_survives_process_frame_until_utility_tick() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_SPACE, true))

	assert_true(_utility.was_action_just_started(&"jump"), "按下后应记录 just started。")
	await get_tree().process_frame
	assert_true(_utility.was_action_just_started(&"jump"), "process_frame 信号阶段不应过早清理 just started。")
	_utility.tick(0.0)
	assert_false(_utility.was_action_just_started(&"jump"), "Utility tick 清理窗口后应清理 just started。")


## 验证架构中的 System tick 可以消费输入帧产生的一次性动作。
func test_action_can_be_consumed_by_system_tick_after_process_frame_signal() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var input: GFInputMappingUtility = GFInputMappingUtility.new()
	var consumer: InputConsumeSystem = InputConsumeSystem.new()
	consumer.input_runtime = input
	await arch.register_utility_instance(input)
	await arch.register_system_instance(consumer)
	await arch.init()
	input.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	]))

	input.handle_input_event(_make_key_event(KEY_SPACE, true))
	await get_tree().process_frame
	arch.tick(0.0)

	assert_eq(consumer.consumed_count, 1, "System tick 应能在 process_frame 信号之后消费刚触发的动作。")
	arch.tick(0.0)
	assert_eq(consumer.consumed_count, 1, "同一次触发在清理后不应被下一帧重复消费。")
	arch.dispose()
	await get_tree().process_frame


## 验证 Utility tick 内由触发器生成的动作会保留到下一次 System tick。
func test_trigger_generated_action_survives_until_next_system_tick() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var input: GFInputMappingUtility = GFInputMappingUtility.new()
	var consumer: InputConsumeSystem = InputConsumeSystem.new()
	consumer.input_runtime = input
	consumer.action_id = &"charge"
	await arch.register_utility_instance(input)
	await arch.register_system_instance(consumer)
	await arch.init()
	var action: GFInputAction = _make_action(&"charge")
	var trigger: GFInputHoldTrigger = GFInputHoldTrigger.new()
	trigger.hold_seconds = 0.1
	var mapping: GFInputMapping = _make_mapping(action, [
		_make_key_binding(KEY_C),
	])
	mapping.triggers = [trigger]
	input.enable_context(_make_context(&"gameplay", [mapping]))

	input.handle_input_event(_make_key_event(KEY_C, true))
	arch.tick(0.05)
	arch.tick(0.06)
	arch.tick(0.0)

	assert_eq(consumer.consumed_count, 1, "触发器在 Utility tick 中产生的 just started 应留给下一次 System tick 消费。")
	arch.tick(0.0)
	assert_eq(consumer.consumed_count, 1, "触发器产生的同一次动作不应重复消费。")
	arch.dispose()
	await get_tree().process_frame


## 验证上下文优先级可以阻断较低优先级的同输入动作。
func test_higher_priority_context_blocks_lower_priority_same_input() -> void:
	var high_context: GFInputContext = _make_context(&"menu", [
		_make_mapping(_make_action(&"confirm"), [
			_make_key_binding(KEY_E),
		]),
	])
	var low_context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"interact"), [
			_make_key_binding(KEY_E),
		]),
	])

	_utility.enable_context(low_context, 0)
	_utility.enable_context(high_context, 10)
	_utility.handle_input_event(_make_key_event(KEY_E, true))

	assert_true(_utility.is_action_active(&"confirm"), "高优先级动作应触发。")
	assert_false(_utility.is_action_active(&"interact"), "低优先级同输入动作应被阻断。")


## 验证运行时重绑定覆盖默认输入。
func test_remap_override_replaces_default_binding() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	_utility.enable_context(context)
	_utility.set_binding_override(&"gameplay", &"jump", 0, _make_key_event(KEY_ENTER, true))

	_utility.handle_input_event(_make_key_event(KEY_SPACE, true))
	assert_false(_utility.is_action_active(&"jump"), "默认绑定被覆盖后不应再触发。")

	_utility.handle_input_event(_make_key_event(KEY_ENTER, true))
	assert_true(_utility.is_action_active(&"jump"), "覆盖后的绑定应触发动作。")


## 验证二维轴动作会合并多个数字输入方向。
func test_axis_2d_action_combines_directional_bindings() -> void:
	var action: GFInputAction = _make_action(&"move", GFInputAction.ValueType.AXIS_2D)
	action.activation_threshold = 0.1
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(action, [
			_make_key_binding(KEY_A, GFInputBinding.ValueTarget.AXIS_2D_X_NEGATIVE),
			_make_key_binding(KEY_D, GFInputBinding.ValueTarget.AXIS_2D_X_POSITIVE),
			_make_key_binding(KEY_W, GFInputBinding.ValueTarget.AXIS_2D_Y_NEGATIVE),
			_make_key_binding(KEY_S, GFInputBinding.ValueTarget.AXIS_2D_Y_POSITIVE),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_D, true))
	_utility.handle_input_event(_make_key_event(KEY_S, true))

	var value: Vector2 = GFVariantData.to_vector2(_utility.get_action_value(&"move"))
	assert_gt(value.x, 0.0, "D 键应贡献 X 正向。")
	assert_gt(value.y, 0.0, "S 键应贡献 Y 正向。")
	assert_true(_utility.is_action_active(&"move"), "轴值超过阈值时动作应活跃。")


## 验证手柄轴正负向绑定会按轴值符号过滤。
func test_joy_axis_directional_binding_respects_axis_sign() -> void:
	var action: GFInputAction = _make_action(&"look_x", GFInputAction.ValueType.AXIS_1D)
	action.activation_threshold = 0.1
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(action, [
			_make_joy_axis_binding(JOY_AXIS_LEFT_X, GFInputBinding.ValueTarget.AXIS_1D_POSITIVE),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_LEFT_X, -0.8))

	assert_eq(_action_float(&"look_x"), 0.0, "负向轴值不应触发正向绑定。")
	assert_false(_utility.is_action_active(&"look_x"), "符号不匹配时动作应保持非活跃。")

	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_LEFT_X, 0.8))

	assert_gt(_action_float(&"look_x"), 0.0, "正向轴值应触发正向绑定。")
	assert_true(_utility.is_action_active(&"look_x"), "符号匹配且超过阈值时动作应活跃。")


## 验证映射级修饰器会作用于聚合后的动作值。
func test_mapping_modifier_scales_aggregated_value() -> void:
	var action: GFInputAction = _make_action(&"move_x", GFInputAction.ValueType.AXIS_1D)
	action.activation_threshold = 0.1
	var scale: GFInputScaleModifier = GFInputScaleModifier.new()
	scale.scale_x = 0.5
	var mapping: GFInputMapping = _make_mapping(action, [
		_make_joy_axis_binding(JOY_AXIS_LEFT_X, GFInputBinding.ValueTarget.AUTO),
	])
	mapping.modifiers = [scale]
	var context: GFInputContext = _make_context(&"gameplay", [mapping])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_LEFT_X, 0.8))

	assert_almost_eq(_action_float(&"move_x"), 0.4, 0.001, "映射级修饰器应缩放聚合值。")


## 验证同一 action_id 出现在多个上下文时，高优先级动作定义不会被低优先级覆盖。
func test_duplicate_action_id_keeps_higher_priority_definition() -> void:
	var high_action: GFInputAction = _make_action(&"move_x", GFInputAction.ValueType.AXIS_1D)
	high_action.activation_threshold = 0.1
	var high_scale: GFInputScaleModifier = GFInputScaleModifier.new()
	high_scale.scale_x = 0.5
	var high_mapping: GFInputMapping = _make_mapping(high_action, [
		_make_key_binding(KEY_D, GFInputBinding.ValueTarget.AXIS_1D_POSITIVE),
	])
	high_mapping.modifiers = [high_scale]

	var low_action: GFInputAction = _make_action(&"move_x", GFInputAction.ValueType.AXIS_1D)
	low_action.activation_threshold = 0.1
	var low_scale: GFInputScaleModifier = GFInputScaleModifier.new()
	low_scale.scale_x = 2.0
	var low_mapping: GFInputMapping = _make_mapping(low_action, [
		_make_key_binding(KEY_A, GFInputBinding.ValueTarget.AXIS_1D_POSITIVE),
	])
	low_mapping.modifiers = [low_scale]

	_utility.enable_context(_make_context(&"low", [low_mapping]), 0)
	_utility.enable_context(_make_context(&"high", [high_mapping]), 10)
	_utility.handle_input_event(_make_key_event(KEY_D, true))

	assert_almost_eq(_action_float(&"move_x"), 0.5, 0.001, "重复 action_id 应保留高优先级映射的修饰器。")


## 验证三维轴动作可以聚合不同方向绑定并应用三维修饰器。
func test_axis_3d_action_combines_directional_bindings() -> void:
	var action: GFInputAction = _make_action(&"move_3d", GFInputAction.ValueType.AXIS_3D)
	action.activation_threshold = 0.1
	var scale: GFInputScaleModifier = GFInputScaleModifier.new()
	scale.scale_z = 0.5
	var mapping: GFInputMapping = _make_mapping(action, [
		_make_key_binding(KEY_D, GFInputBinding.ValueTarget.AXIS_3D_X_POSITIVE),
		_make_key_binding(KEY_E, GFInputBinding.ValueTarget.AXIS_3D_Z_POSITIVE),
	])
	mapping.modifiers = [scale]
	var context: GFInputContext = _make_context(&"gameplay", [mapping])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_D, true))
	_utility.handle_input_event(_make_key_event(KEY_E, true))

	var value: Vector3 = GFVariantData.to_vector3(_utility.get_action_value(&"move_3d"))
	assert_gt(value.x, 0.0, "D 键应贡献 X 正向。")
	assert_almost_eq(value.z, sqrt(0.5) * 0.5, 0.001, "三维修饰器应缩放归一化后的 Z 分量。")
	assert_true(_utility.is_action_active(&"move_3d"), "三维轴超过阈值时动作应活跃。")


## 验证长按触发器会延迟动作活跃状态。
func test_hold_trigger_delays_action_activation_until_tick_threshold() -> void:
	var action: GFInputAction = _make_action(&"charge")
	var trigger: GFInputHoldTrigger = GFInputHoldTrigger.new()
	trigger.hold_seconds = 0.1
	var mapping: GFInputMapping = _make_mapping(action, [
		_make_key_binding(KEY_C),
	])
	mapping.triggers = [trigger]
	var context: GFInputContext = _make_context(&"gameplay", [mapping])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_C, true))

	assert_false(_utility.is_action_active(&"charge"), "刚按下时长按动作不应立刻活跃。")
	_utility.tick(0.05)
	assert_false(_utility.is_action_active(&"charge"), "未达到长按时间前不应活跃。")
	_utility.tick(0.06)
	assert_true(_utility.is_action_active(&"charge"), "达到长按时间后应活跃。")
	assert_true(_utility.was_action_just_started(&"charge"), "长按完成帧应记录 just started。")


## 验证短按触发器会在释放时触发一次。
func test_tap_trigger_activates_on_quick_release() -> void:
	var action: GFInputAction = _make_action(&"tap")
	var trigger: GFInputTapTrigger = GFInputTapTrigger.new()
	trigger.max_tap_seconds = 0.2
	var mapping: GFInputMapping = _make_mapping(action, [
		_make_key_binding(KEY_T),
	])
	mapping.triggers = [trigger]
	var context: GFInputContext = _make_context(&"gameplay", [mapping])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_T, true))
	_utility.tick(0.05)
	_utility.handle_input_event(_make_key_event(KEY_T, false))

	assert_true(_utility.is_action_active(&"tap"), "短按释放时动作应短暂活跃。")
	assert_true(_utility.was_action_just_started(&"tap"), "短按释放帧应记录 just started。")


## 验证脉冲触发器会在持续输入时按间隔重复触发。
func test_pulse_trigger_repeats_while_raw_input_is_active() -> void:
	var action: GFInputAction = _make_action(&"repeat")
	var trigger: GFInputPulseTrigger = GFInputPulseTrigger.new()
	trigger.interval_seconds = 0.1
	trigger.trigger_immediately = false
	var mapping: GFInputMapping = _make_mapping(action, [
		_make_key_binding(KEY_R),
	])
	mapping.triggers = [trigger]
	var context: GFInputContext = _make_context(&"gameplay", [mapping])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_R, true))
	_utility.tick(0.05)
	assert_false(_utility.is_action_active(&"repeat"), "未达到间隔前不应触发。")
	_utility.tick(0.06)

	assert_true(_utility.is_action_active(&"repeat"), "达到间隔后应触发一次。")


## 验证组合触发器依赖另一个抽象动作，而不是具体按键。
func test_chord_trigger_requires_another_action_active() -> void:
	var chord: GFInputChordTrigger = GFInputChordTrigger.new()
	chord.required_action_id = &"modifier"
	var chord_mapping: GFInputMapping = _make_mapping(_make_action(&"special"), [
		_make_key_binding(KEY_K),
	])
	chord_mapping.triggers = [chord]
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"modifier"), [
			_make_key_binding(KEY_SHIFT),
		]),
		chord_mapping,
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_K, true))
	assert_false(_utility.is_action_active(&"special"), "缺少组合动作时不应触发。")

	_utility.handle_input_event(_make_key_event(KEY_SHIFT, true))
	_utility.handle_input_event(_make_key_event(KEY_K, true))
	assert_true(_utility.is_action_active(&"special"), "组合动作活跃后应触发。")


## 验证序列触发器支持多分支抽象动作路径。
func test_sequence_trigger_supports_branch_alternatives() -> void:
	var sequence_trigger: GFInputSequenceTrigger = GFInputSequenceTrigger.new()
	var branch_a_ids: Array[StringName] = [&"left", &"down"]
	var branch_b_ids: Array[StringName] = [&"cancel"]
	var branch_a: GFInputSequenceBranch = GFInputSequenceBranch.from_action_ids(branch_a_ids, 0.3)
	var branch_b: GFInputSequenceBranch = GFInputSequenceBranch.from_action_ids(branch_b_ids, 0.3)
	var branches: Array[GFInputSequenceBranch] = [branch_a, branch_b]
	sequence_trigger.branches = branches
	var special_mapping: GFInputMapping = _make_mapping(_make_action(&"special"), [
		_make_key_binding(KEY_P),
	])
	special_mapping.triggers = [sequence_trigger]
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"left"), [
			_make_key_binding(KEY_A),
		]),
		_make_mapping(_make_action(&"down"), [
			_make_key_binding(KEY_S),
		]),
		_make_mapping(_make_action(&"cancel"), [
			_make_key_binding(KEY_Q),
		]),
		special_mapping,
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_Q, true))
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_true(_utility.is_action_active(&"special"), "任一序列分支完成后当前动作应可触发。")


## 验证序列步骤支持按住后释放作为完成条件。
func test_sequence_trigger_supports_hold_then_release_step() -> void:
	var step: GFInputSequenceStep = GFInputSequenceStep.new()
	step.action_id = &"charge"
	step.min_hold_seconds = 0.1
	step.trigger_on_release = true
	var branch: GFInputSequenceBranch = GFInputSequenceBranch.new()
	var steps: Array[GFInputSequenceStep] = [step]
	branch.steps = steps
	var sequence_trigger: GFInputSequenceTrigger = GFInputSequenceTrigger.new()
	var branches: Array[GFInputSequenceBranch] = [branch]
	sequence_trigger.branches = branches
	var release_mapping: GFInputMapping = _make_mapping(_make_action(&"release_attack"), [
		_make_key_binding(KEY_F),
	])
	release_mapping.triggers = [sequence_trigger]
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"charge"), [
			_make_key_binding(KEY_C),
		]),
		release_mapping,
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_C, true))
	_utility.tick(0.12)
	_utility.handle_input_event(_make_key_event(KEY_C, false))
	_utility.handle_input_event(_make_key_event(KEY_F, true))

	assert_true(_utility.is_action_active(&"release_attack"), "满足按住时间并释放后，应允许后续动作触发。")


## 验证触屏绑定可按需精确匹配触点 index。
func test_touch_binding_can_match_touch_index() -> void:
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = _make_touch_event(1, true)

	assert_true(binding.matches_event(_make_touch_event(2, true)), "默认触屏绑定应保持任意触点兼容语义。")

	binding.match_touch_index = true

	assert_true(binding.matches_event(_make_touch_event(1, true)), "启用 index 匹配后应接受同一触点。")
	assert_false(binding.matches_event(_make_touch_event(2, true)), "启用 index 匹配后应拒绝不同触点。")


## 验证可重绑条目会返回上下文、动作和有效事件。
func test_get_remappable_items_returns_effective_event() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	_utility.enable_context(context)
	_utility.set_binding_override(&"gameplay", &"jump", 0, _make_key_event(KEY_ENTER, true))
	var items: Array[Dictionary] = _utility.get_remappable_items()
	var item_event_value: Variant = GFVariantData.get_option_value(items[0], "event")
	assert_true(item_event_value is InputEvent, "可重绑条目应包含有效输入事件。")
	if not (item_event_value is InputEvent):
		return
	var item_event: InputEvent = item_event_value

	assert_eq(items.size(), 1, "应返回一个可重绑条目。")
	assert_eq(GFVariantData.get_option_string_name(items[0], "context_id"), &"gameplay", "条目应包含上下文标识。")
	assert_eq(GFVariantData.get_option_string_name(items[0], "action_id"), &"jump", "条目应包含动作标识。")
	assert_eq(GFInputFormatter.input_event_as_text(item_event), "Enter", "条目应使用重映射后的事件。")


## 验证格式化工具可以输出组合键文本。
func test_input_formatter_formats_key_modifiers() -> void:
	var event: InputEventKey = _make_key_event(KEY_K, true)
	event.ctrl_pressed = true
	event.shift_pressed = true

	assert_eq(GFInputFormatter.input_event_as_text(event), "Ctrl + Shift + K", "组合键文本应稳定。")


## 验证输入格式化工具可注册文本 provider。
func test_input_formatter_uses_text_provider() -> void:
	var provider: CustomKeyTextProvider = CustomKeyTextProvider.new(10)
	GFInputFormatter.add_text_provider(provider)

	assert_eq(GFInputFormatter.input_event_as_text(_make_key_event(KEY_K, true)), "Custom K", "文本 provider 应覆盖默认按键文本。")
	assert_eq(GFInputFormatter.input_event_as_text(_make_key_event(KEY_K, true), { "label": "Keyboard K" }), "Keyboard K", "格式化 options 应传递给 provider。")


## 验证输入格式化工具可注册 RichText 图标 provider。
func test_input_formatter_uses_icon_provider_for_rich_text() -> void:
	GFInputFormatter.add_icon_provider(CustomKeyIconProvider.new())

	assert_eq(GFInputFormatter.input_event_as_rich_text(_make_key_event(KEY_K, true)), "[color=yellow]K[/color]", "图标 provider 应优先生成 RichText。")
	assert_eq(GFInputFormatter.input_event_as_rich_text(_make_key_event(KEY_SPACE, true)), "Space", "无图标 provider 时应回退到文本。")


## 验证输入格式化工具为 Joypad 提供通用方位文本，并允许覆盖。
func test_input_formatter_formats_joypad_with_standard_labels() -> void:
	assert_eq(GFInputFormatter.input_event_as_text(_make_joy_button_event(0, JOY_BUTTON_A, true)), "Button South", "手柄按钮应使用通用方位文本。")
	assert_eq(GFInputFormatter.input_event_as_text(_make_joy_motion_event(JOY_AXIS_LEFT_X, 0.5)), "Left Stick X +", "手柄轴应显示方向。")
	assert_eq(
		GFInputFormatter.input_event_as_text(
			_make_joy_button_event(0, JOY_BUTTON_A, true),
			{ "joypad_button_labels": { JOY_BUTTON_A: "Confirm" } }
		),
		"Confirm",
		"项目应可通过 options 覆盖手柄文本。"
	)


## 验证输入冲突分析器会使用重映射后的有效事件。
func test_input_conflict_analyzer_reports_remap_conflicts() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
		_make_mapping(_make_action(&"confirm"), [
			_make_key_binding(KEY_ENTER),
		]),
	])
	var remap_config: GFInputRemapConfig = GFInputRemapConfig.new()
	remap_config.set_binding(&"gameplay", &"confirm", 0, _make_key_event(KEY_SPACE, true))

	var conflicts: Array[Dictionary] = GFInputConflictAnalyzer.analyze_context(context, remap_config)

	assert_eq(conflicts.size(), 1, "重映射到同一按键后应报告一个冲突。")
	assert_eq(GFVariantData.get_option_string(conflicts[0], "event_text"), "Space", "冲突文本应使用有效事件。")


func test_input_remap_config_uses_structured_event_records() -> void:
	var remap_config: GFInputRemapConfig = GFInputRemapConfig.new()
	remap_config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE, true))

	var data: Dictionary = remap_config.to_dict()
	var remapped_events: Dictionary = GFVariantData.get_option_dictionary(data, "remapped_events")
	var gameplay_events: Dictionary = GFVariantData.get_option_dictionary(remapped_events, "gameplay")
	var jump_events: Dictionary = GFVariantData.get_option_dictionary(gameplay_events, "jump")
	var record: Dictionary = GFVariantData.get_option_dictionary(jump_events, "0")
	var restored: GFInputRemapConfig = GFInputRemapConfig.from_dict(data)
	var restored_event_value: InputEvent = restored.get_bound_event_or_null(&"gameplay", &"jump", 0)
	assert_true(restored_event_value is InputEventKey, "结构化记录应恢复为按键事件。")
	if not (restored_event_value is InputEventKey):
		return
	var restored_event: InputEventKey = restored_event_value

	assert_false(record.has("event"), "新重映射记录不应再使用 str_to_var 文本。")
	assert_eq(GFVariantData.get_option_string(record, "event_class"), "InputEventKey", "重映射记录应保存白名单事件类型。")
	assert_not_null(restored_event, "结构化记录应能恢复输入事件。")
	assert_eq(restored_event.keycode, KEY_SPACE, "恢复后的按键事件应保留 keycode。")


## 验证输入冲突分析器可构建完整重绑定报告。
func test_input_conflict_analyzer_builds_rebind_report() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
		_make_mapping(_make_action(&"confirm"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	var report: Dictionary = GFInputConflictAnalyzer.build_rebind_report([context])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "存在冲突时报告 ok 应为 false。")
	assert_eq(GFVariantData.get_option_int(report, "context_count"), 1, "报告应包含上下文数量。")
	assert_eq(GFVariantData.get_option_int(report, "item_count"), 2, "报告应包含绑定条目数量。")
	assert_eq(GFVariantData.get_option_int(report, "conflict_count"), 1, "报告应包含冲突数量。")


## 验证延迟挂载在 Utility 销毁后不会留下输入路由节点。
func test_deferred_router_attach_is_canceled_after_dispose() -> void:
	_utility.dispose()
	await get_tree().process_frame

	assert_null(_find_router_node(), "Utility 已销毁时，延迟挂载不应留下输入 Router。")


## 验证同一动作可以按输入设备映射维护玩家级状态。
func test_player_action_state_is_scoped_by_device_assignment() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var devices: GFInputDeviceUtility = GFInputDeviceUtility.new()
	devices.include_keyboard_mouse = false
	devices.include_touch = false
	devices.max_players = 2
	await arch.register_utility_instance(devices)
	await arch.register_utility_instance(_utility)

	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_joy_button_binding(JOY_BUTTON_A),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_joy_button_event(0, JOY_BUTTON_A, true))
	_utility.handle_input_event(_make_joy_button_event(1, JOY_BUTTON_A, true))
	_utility.handle_input_event(_make_joy_button_event(0, JOY_BUTTON_A, false))

	assert_false(_utility.is_action_active_for_player(0, &"jump"), "0 号玩家释放后自己的动作应结束。")
	assert_true(_utility.is_action_active_for_player(1, &"jump"), "1 号玩家仍按住时自己的动作应保持活跃。")
	assert_true(_utility.is_action_active(&"jump"), "全局动作状态应聚合仍活跃的设备来源。")

	arch.dispose()
	_utility = null
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout


func test_player_action_state_keeps_multiple_sources_for_same_player_binding() -> void:
	var action: GFInputAction = _make_action(&"jump")
	var binding: GFInputBinding = _make_joy_button_binding(JOY_BUTTON_A)
	var entry: Dictionary = {
		"action": action,
		"action_id": &"jump",
		"bindings": [{
			"binding": binding,
			"key": "gameplay/jump/0",
		}],
	}

	var _apply_entry_event_result_656: Variant = _utility._apply_entry_event(entry, _make_joy_button_event(0, JOY_BUTTON_A, true), 0)
	var _apply_entry_event_result_657: Variant = _utility._apply_entry_event(entry, _make_joy_button_event(1, JOY_BUTTON_A, true), 0)
	var _apply_entry_event_result_658: Variant = _utility._apply_entry_event(entry, _make_joy_button_event(0, JOY_BUTTON_A, false), 0)

	assert_true(_utility.is_action_active_for_player(0, &"jump"), "同一玩家另一个来源仍按住时，玩家动作应保持活跃。")

	var _apply_entry_event_result_662: Variant = _utility._apply_entry_event(entry, _make_joy_button_event(1, JOY_BUTTON_A, false), 0)
	assert_false(_utility.is_action_active_for_player(0, &"jump"), "所有来源释放后玩家动作才应结束。")


func test_virtual_input_source_drives_global_and_player_action_state() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"replay", 0)

	assert_true(source.press(&"jump"), "虚拟输入源应能按下已注册动作。")
	assert_true(_utility.is_action_active(&"jump"), "虚拟按下应激活全局动作。")
	assert_true(_utility.is_action_active_for_player(0, &"jump"), "带玩家索引的虚拟源应激活玩家动作。")
	assert_true(_utility.was_action_just_started(&"jump"), "虚拟按下应产生 just started。")

	assert_true(source.release(&"jump"), "虚拟输入源应能释放动作。")
	assert_false(_utility.is_action_active(&"jump"), "虚拟释放后全局动作应结束。")
	assert_true(_utility.was_action_just_completed(&"jump"), "虚拟释放应产生 just completed。")


func test_virtual_input_source_supports_axis_values_and_clear() -> void:
	var action: GFInputAction = _make_action(&"move", GFInputAction.ValueType.AXIS_2D)
	action.activation_threshold = 0.1
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(action, bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"ai")

	assert_true(source.set_axis_2d(&"move", Vector2(0.25, -0.5)), "虚拟源应能写入二维轴值。")
	assert_eq(_action_vector2(&"move"), Vector2(0.25, -0.5), "二维虚拟值应可按动作读取。")
	assert_true(_utility.is_action_active(&"move"), "超过阈值的虚拟轴值应激活动作。")

	source.clear_all()

	assert_eq(_action_vector2(&"move"), Vector2.ZERO, "清理虚拟源后动作值应回到默认值。")
	assert_false(_utility.is_action_active(&"move"), "清理虚拟源后动作应结束。")


func test_clear_player_input_state_removes_player_global_contributions() -> void:
	var action: GFInputAction = _make_action(&"move", GFInputAction.ValueType.AXIS_2D)
	action.activation_threshold = 0.1
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(action, bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"player", 1)

	assert_true(source.set_axis_2d(&"move", Vector2.RIGHT), "玩家虚拟源应能写入动作。")
	assert_true(_utility.is_action_active(&"move"), "玩家贡献也会聚合到全局动作。")
	assert_true(_utility.is_action_active_for_player(1, &"move"), "玩家级动作应被激活。")

	_utility.clear_player_input_state(1)

	assert_eq(_action_vector2(&"move"), Vector2.ZERO, "清理玩家状态应同步移除其全局贡献。")
	assert_false(_utility.is_action_active(&"move"), "玩家贡献被清理后全局动作应结束。")
	assert_false(_utility.is_action_active_for_player(1, &"move"), "玩家级动作应结束。")


func test_input_recording_playback_drives_virtual_source() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"recording")
	var recording: GFInputRecording = GFInputRecording.new()
	var _add_event_result_733: Variant = recording.add_event(&"jump", true, 0.0)
	var _add_event_result_734: Variant = recording.add_event(&"jump", false, 0.1)
	var playback: GFInputPlayback = GFInputPlayback.new()

	assert_true(playback.start(recording, source), "回放应能启动。")
	assert_eq(playback.tick(0.0), 1, "0 秒事件应在首帧应用。")
	assert_true(_utility.is_action_active(&"jump"), "回放按下事件应激活动作。")

	var _tick_result_741: Variant = playback.tick(0.1)

	assert_false(_utility.is_action_active(&"jump"), "回放释放事件应结束动作。")
	assert_false(playback.is_playing, "非循环回放到末尾后应停止。")


func test_input_recording_json_roundtrip_preserves_values() -> void:
	var recording: GFInputRecording = GFInputRecording.new()
	recording.recording_id = &"sample"
	var _add_event_result_750: Variant = recording.add_event(&"move", Vector2(0.25, -0.5), 0.2, 1, &"demo", {
		"tags": PackedStringArray(["tutorial"]),
	})

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(recording.to_dict(true))
	var decoded_data: Dictionary = GFVariantData.as_dictionary(
		GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(JSON.stringify(encoded)))
	)
	var decoded: GFInputRecording = GFInputRecording.from_dict(decoded_data)
	var event: Dictionary = decoded.events[0]
	var metadata: Dictionary = GFVariantData.get_option_dictionary(event, "metadata")

	assert_eq(decoded.recording_id, &"sample", "录制 ID 应保留。")
	assert_eq(GFVariantData.to_vector2(GFVariantData.get_option_value(event, "value")), Vector2(0.25, -0.5), "录制事件值应保留 Godot 类型。")
	assert_eq(GFVariantData.get_option_packed_string_array(metadata, "tags"), PackedStringArray(["tutorial"]), "事件元数据应保留 PackedStringArray。")


func test_input_playback_can_respect_recorded_player_index() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"recording")
	var recording: GFInputRecording = GFInputRecording.new()
	var _add_event_result_775: Variant = recording.add_event(&"jump", true, 0.0, 1)
	var playback: GFInputPlayback = GFInputPlayback.new()
	playback.respect_recorded_player_index = true

	var _start_result_779: Variant = playback.start(recording, source)
	var _tick_result_780: Variant = playback.tick(0.0)

	assert_false(_utility.is_action_active_for_player(0, &"jump"), "未录制的玩家不应被激活。")
	assert_true(_utility.is_action_active_for_player(1, &"jump"), "录制玩家索引应被用于虚拟源写入。")


func test_assignment_removal_clears_player_input_state() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var devices: GFInputDeviceUtility = GFInputDeviceUtility.new()
	devices.include_keyboard_mouse = false
	devices.include_touch = false
	devices.max_players = 1
	await arch.register_utility_instance(devices)
	await arch.register_utility_instance(_utility)
	await arch.init()
	devices.set_assignment(devices.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 7))
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_joy_button_binding(JOY_BUTTON_A),
		]),
	]))

	_utility.handle_input_event(_make_joy_button_event(7, JOY_BUTTON_A, true))
	assert_true(_utility.is_action_active_for_player(0, &"jump"), "设备移除前玩家动作应处于按下状态。")

	devices.remove_assignment(0, &"test_disconnect")

	assert_false(_utility.is_action_active_for_player(0, &"jump"), "移除玩家设备后应清理该玩家输入状态。")
	assert_false(_utility.is_action_active(&"jump"), "玩家贡献被清理后全局动作也应结束。")
	arch.dispose()
	_utility = null
	await get_tree().process_frame


func test_input_playback_seek_rebuilds_virtual_source_state() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"recording")
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 1.0)
	var playback: GFInputPlayback = GFInputPlayback.new()
	var _started: bool = playback.start(recording, source)

	playback.seek(0.5)

	assert_true(_utility.is_action_active(&"jump"), "seek 到按下和释放之间时应重建为按下状态。")

	playback.seek(1.0)

	assert_false(_utility.is_action_active(&"jump"), "seek 到释放事件之后时应重建为释放状态。")
	assert_eq(playback.tick(0.0), 0, "seek 已应用到期事件后，同时间 tick 不应重复应用。")


func test_input_recording_preserves_same_time_event_order() -> void:
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 0.0)
	var restored: GFInputRecording = GFInputRecording.from_dict(recording.to_dict())
	var events: Array[Dictionary] = restored.get_events()

	assert_true(GFVariantData.to_bool(GFVariantData.get_option_value(events[0], "value")), "同时间事件应保留原始插入顺序。")
	assert_false(GFVariantData.to_bool(GFVariantData.get_option_value(events[1], "value")), "同时间事件恢复后顺序仍应稳定。")


func test_tap_trigger_counts_release_delta_for_min_tap_window() -> void:
	var trigger: GFInputTapTrigger = GFInputTapTrigger.new()
	trigger.min_tap_seconds = 0.05
	trigger.max_tap_seconds = 0.2
	var state: Dictionary = {}
	trigger.reset_trigger_state(state)

	var _started: int = trigger.update(true, true, 0.0, state)
	var _held: int = trigger.update(true, true, 0.04, state)
	var released: int = trigger.update(false, false, 0.02, state)

	assert_eq(released, GFInputTrigger.TriggerState.TRIGGERED, "释放帧 delta 应计入短按时长。")


func test_sequence_trigger_completed_branch_expires_after_gap() -> void:
	var sequence_trigger: GFInputSequenceTrigger = GFInputSequenceTrigger.new()
	var branch_ids: Array[StringName] = [&"left", &"down"]
	var branches: Array[GFInputSequenceBranch] = [GFInputSequenceBranch.from_action_ids(branch_ids, 0.3)]
	sequence_trigger.branches = branches
	var special_mapping: GFInputMapping = _make_mapping(_make_action(&"special"), [
		_make_key_binding(KEY_P),
	])
	special_mapping.triggers = [sequence_trigger]
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"left"), [
			_make_key_binding(KEY_A),
		]),
		_make_mapping(_make_action(&"down"), [
			_make_key_binding(KEY_S),
		]),
		special_mapping,
	])
	_utility.enable_context(context)

	_utility.handle_input_event(_make_key_event(KEY_A, true))
	_utility.tick(0.0)
	_utility.handle_input_event(_make_key_event(KEY_S, true))
	_utility.tick(0.0)
	_utility.tick(0.31)
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_false(_utility.is_action_active(&"special"), "完成序列超过 gap 后不应无限期允许后续动作触发。")


func test_input_conflict_analyzer_separates_joy_axis_positive_and_negative_bindings() -> void:
	var left_mapping: GFInputMapping = _make_mapping(_make_action(&"move_left"), [
		_make_joy_axis_binding(JOY_AXIS_LEFT_X, GFInputBinding.ValueTarget.AXIS_1D_NEGATIVE),
	])
	var right_mapping: GFInputMapping = _make_mapping(_make_action(&"move_right"), [
		_make_joy_axis_binding(JOY_AXIS_LEFT_X, GFInputBinding.ValueTarget.AXIS_1D_POSITIVE),
	])
	var context: GFInputContext = _make_context(&"gameplay", [left_mapping, right_mapping])

	var conflicts: Array[Dictionary] = GFInputConflictAnalyzer.analyze_context(context)

	assert_true(conflicts.is_empty(), "同一手柄轴的正向和负向绑定不应互相冲突。")


# --- 私有/辅助方法 ---

func _action_float(action_id: StringName) -> float:
	return GFVariantData.to_float(_utility.get_action_value(action_id))


func _action_vector2(action_id: StringName) -> Vector2:
	return GFVariantData.to_vector2(_utility.get_action_value(action_id))


func _make_action(action_id: StringName, value_type: GFInputAction.ValueType = GFInputAction.ValueType.BOOL) -> GFInputAction:
	var action: GFInputAction = GFInputAction.new()
	action.action_id = action_id
	action.value_type = value_type
	return action


func _make_context(context_id: StringName, mappings: Array[GFInputMapping]) -> GFInputContext:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = context_id
	context.mappings = mappings
	return context


func _make_mapping(action: GFInputAction, bindings: Array[GFInputBinding]) -> GFInputMapping:
	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	mapping.bindings = bindings
	return mapping


func _make_key_binding(
	key: Key,
	target: GFInputBinding.ValueTarget = GFInputBinding.ValueTarget.AUTO
) -> GFInputBinding:
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = _make_key_event(key, true)
	binding.value_target = target
	return binding


func _make_joy_axis_binding(axis: JoyAxis, target: GFInputBinding.ValueTarget) -> GFInputBinding:
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = _make_joy_motion_event(axis, 1.0)
	binding.value_target = target
	return binding


func _make_joy_button_binding(button: JoyButton) -> GFInputBinding:
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = _make_joy_button_event(0, button, true)
	return binding


func _make_key_event(key: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event


func _make_joy_motion_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _make_joy_button_event(device: int, button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	return event


func _make_touch_event(index: int, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event


func _find_router_node() -> Node:
	for child: Node in get_tree().root.get_children():
		if child.name == "GFInputMappingRouter":
			return child
	return null
