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


class GlobalOnlyInputRuntime extends RefCounted:
	func is_action_active(_action_id: StringName) -> bool:
		return true

	func was_action_just_started(_action_id: StringName) -> bool:
		return true

	func was_action_just_completed(_action_id: StringName) -> bool:
		return true

	func get_last_completed_duration(_action_id: StringName) -> float:
		return 1.0


class PartialPlayerInputRuntime extends GlobalOnlyInputRuntime:
	func is_action_active_for_player(_player_index: int, _action_id: StringName) -> bool:
		return true


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


## 验证布尔动作不受仅属于轴动作的迟滞阈值配置影响。
func test_bool_action_ignores_axis_threshold_configuration() -> void:
	var action: GFInputAction = _make_action(&"confirm")
	action.activation_threshold = 0.1
	action.release_threshold = 0.9
	var context: GFInputContext = _make_context(&"menu", [
		_make_mapping(action, [
			_make_key_binding(KEY_ENTER),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_ENTER, true))

	assert_true(
		_utility.is_action_active(&"confirm"),
		"布尔动作不得因无语义的轴阈值顺序而从有效映射中被排除。"
	)


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


func test_input_dispatch_stops_when_signal_callback_replaces_context_epoch() -> void:
	var initial_context: GFInputContext = _make_context(&"initial", [
		_make_mapping(_make_action(&"initial_action"), [
			_make_key_binding(KEY_E),
		]),
	])
	var replacement_context: GFInputContext = _make_context(&"replacement", [
		_make_mapping(_make_action(&"replacement_first"), [
			_make_key_binding(KEY_E),
		]),
		_make_mapping(_make_action(&"replacement_second"), [
			_make_key_binding(KEY_E),
		]),
	])
	var callback_state: Dictionary = { "replaced": false }
	var _started_connection: int = _utility.action_started.connect(func(action_id: StringName, _value: Variant) -> void:
		if action_id != &"initial_action" or GFVariantData.get_option_bool(callback_state, "replaced"):
			return
		callback_state["replaced"] = true
		_utility.set_enabled_contexts([replacement_context])
	)

	_utility.enable_context(initial_context)
	_utility.handle_input_event(_make_key_event(KEY_E, true))

	assert_true(GFVariantData.get_option_bool(callback_state, "replaced"), "动作回调应替换当前上下文代际。")
	assert_false(
		_utility.is_action_active(&"replacement_second"),
		"当前事件不得继续遍历回调重建后的新 entry 集。"
	)


func test_action_value_callback_clear_does_not_emit_stale_started_signal() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])
	var _value_connection: int = _utility.action_value_changed.connect(func(action_id: StringName, _value: Variant) -> void:
		if action_id == &"jump":
			_utility.clear_contexts()
	)
	watch_signals(_utility)

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_SPACE, true))

	assert_false(_utility.is_action_active(&"jump"), "清空回调后旧动作不得重新进入 active。")
	assert_signal_emit_count(
		_utility,
		"action_started",
		0,
		"动作值回调切换代际后不得继续发出旧代际 started。"
	)


func test_action_started_callback_can_dispose_without_continuing_dispatch() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"first"), [
			_make_key_binding(KEY_E),
		]),
		_make_mapping(_make_action(&"second"), [
			_make_key_binding(KEY_E),
		]),
	])
	var _started_connection: int = _utility.action_started.connect(
		func(action_id: StringName, _value: Variant) -> void:
			if action_id == &"first":
				_utility.dispose()
	)

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_E, true))

	assert_false(_utility.is_action_active(&"second"), "dispose 回调后不得继续派发后续 entry。")
	assert_true(_utility.get_enabled_contexts().is_empty(), "dispose 回调必须留下完整清理后的状态。")


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
	action.release_threshold = 0.1
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
	action.release_threshold = 0.1
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


## 验证轴动作激活后使用较低的释放阈值，避免边界抖动。
func test_axis_action_uses_release_threshold_after_activation() -> void:
	var action: GFInputAction = _make_action(&"throttle", GFInputAction.ValueType.AXIS_1D)
	action.activation_threshold = 0.5
	action.release_threshold = 0.2
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(action, [
			_make_joy_axis_binding(JOY_AXIS_TRIGGER_RIGHT, GFInputBinding.ValueTarget.AUTO),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_TRIGGER_RIGHT, 0.6))
	assert_true(_utility.is_action_active(&"throttle"), "跨过激活阈值后动作应活跃。")

	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_TRIGGER_RIGHT, 0.3))
	assert_true(_utility.is_action_active(&"throttle"), "回落到两阈值之间时应保持活跃。")

	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_TRIGGER_RIGHT, 0.2))
	assert_true(_utility.is_action_active(&"throttle"), "等于释放阈值时应保持活跃。")

	_utility.handle_input_event(_make_joy_motion_event(JOY_AXIS_TRIGGER_RIGHT, 0.19))
	assert_false(_utility.is_action_active(&"throttle"), "低于释放阈值后动作应结束。")


## 验证零释放阈值仍会在轴回到精确中立值时结束动作。
func test_axis_action_with_zero_release_threshold_releases_at_neutral() -> void:
	var action: GFInputAction = _make_action(&"throttle", GFInputAction.ValueType.AXIS_1D)
	action.activation_threshold = 0.5
	action.release_threshold = 0.0
	var no_bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(action, no_bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"axis", 2)

	assert_true(source.set_axis_1d(&"throttle", 1.0))
	assert_true(_utility.is_action_active(&"throttle"))
	assert_true(_utility.is_action_active_for_player(2, &"throttle"))
	assert_true(source.set_axis_1d(&"throttle", 0.0))

	assert_false(
		_utility.is_action_active(&"throttle"),
		"轴回到精确中立值时必须释放全局动作。"
	)
	assert_false(
		_utility.is_action_active_for_player(2, &"throttle"),
		"轴回到精确中立值时必须释放玩家动作。"
	)


## 验证玩家作用域与全局作用域共享同一轴迟滞语义。
func test_player_axis_action_uses_release_threshold_after_activation() -> void:
	var action: GFInputAction = _make_action(&"steer", GFInputAction.ValueType.AXIS_1D)
	action.activation_threshold = 0.6
	action.release_threshold = 0.25
	var no_bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(action, no_bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"player_axis", 2)

	assert_true(source.set_axis_1d(&"steer", 0.7))
	assert_true(_utility.is_action_active_for_player(2, &"steer"))
	assert_true(source.set_axis_1d(&"steer", 0.4))
	assert_true(
		_utility.is_action_active_for_player(2, &"steer"),
		"玩家轴回落到两阈值之间时应保持活跃。"
	)
	assert_true(source.set_axis_1d(&"steer", 0.2))
	assert_false(
		_utility.is_action_active_for_player(2, &"steer"),
		"玩家轴低于释放阈值时应结束。"
	)


## 验证非有限、越界或反向迟滞阈值不会进入全局与玩家运行时。
func test_invalid_axis_thresholds_are_skipped_fail_closed() -> void:
	var reversed_action: GFInputAction = _make_action(
		&"reversed_axis",
		GFInputAction.ValueType.AXIS_1D
	)
	reversed_action.activation_threshold = 0.25
	reversed_action.release_threshold = 0.5
	var nonfinite_action: GFInputAction = _make_action(
		&"nonfinite_axis",
		GFInputAction.ValueType.AXIS_1D
	)
	nonfinite_action.activation_threshold = NAN
	nonfinite_action.release_threshold = 0.1
	var no_bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"invalid_thresholds", [
		_make_mapping(reversed_action, no_bindings),
		_make_mapping(nonfinite_action, no_bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"invalid_axis_source", 3)

	assert_false(source.set_axis_1d(&"reversed_axis", 1.0))
	assert_false(source.set_axis_1d(&"nonfinite_axis", 1.0))
	assert_false(_utility.is_action_active(&"reversed_axis"))
	assert_false(_utility.is_action_active_for_player(3, &"reversed_axis"))
	assert_false(_utility.is_action_active(&"nonfinite_axis"))
	assert_false(_utility.is_action_active_for_player(3, &"nonfinite_axis"))


## 验证映射级修饰器会作用于聚合后的动作值。
func test_mapping_modifier_scales_aggregated_value() -> void:
	var action: GFInputAction = _make_action(&"move_x", GFInputAction.ValueType.AXIS_1D)
	action.activation_threshold = 0.1
	action.release_threshold = 0.1
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


func test_mapping_modifiers_preserve_declared_order() -> void:
	var scale: GFInputScaleModifier = GFInputScaleModifier.new()
	scale.scale_x = 0.5
	var deadzone: GFInputDeadzoneModifier = GFInputDeadzoneModifier.new()
	deadzone.lower_threshold = 0.6
	deadzone.upper_threshold = 1.0
	deadzone.rescale_after_deadzone = false

	var scale_then_deadzone: GFInputMapping = _make_mapping(
		_make_action(&"scale_then_deadzone", GFInputAction.ValueType.AXIS_1D),
		[]
	)
	scale_then_deadzone.modifiers = [scale, deadzone]
	var deadzone_then_scale: GFInputMapping = _make_mapping(
		_make_action(&"deadzone_then_scale", GFInputAction.ValueType.AXIS_1D),
		[]
	)
	deadzone_then_scale.modifiers = [deadzone, scale]
	_utility.enable_context(_make_context(&"gameplay", [
		scale_then_deadzone,
		deadzone_then_scale,
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"modifier_order")

	assert_true(source.set_axis_1d(&"scale_then_deadzone", 1.0))
	assert_true(source.set_axis_1d(&"deadzone_then_scale", 1.0))

	assert_eq(_action_float(&"scale_then_deadzone"), 0.0, "scale 后的 0.5 应被后续 0.6 deadzone 过滤。")
	assert_almost_eq(_action_float(&"deadzone_then_scale"), 0.5, 0.001, "deadzone 后再 scale 应保留声明顺序的 0.5。")


func test_runtime_modifier_duplicates_isolate_state_between_mappings() -> void:
	var shared_cursor: GFInputVirtualCursorModifier = GFInputVirtualCursorModifier.new()
	shared_cursor.apply_delta_time = false
	shared_cursor.initial_position = Vector2.ZERO
	shared_cursor.speed = Vector2(0.25, 0.0)
	shared_cursor.clamp_to_rect = false

	var first_mapping: GFInputMapping = _make_mapping(
		_make_action(&"first_cursor", GFInputAction.ValueType.AXIS_2D),
		[]
	)
	first_mapping.modifiers = [shared_cursor]
	var second_mapping: GFInputMapping = _make_mapping(
		_make_action(&"second_cursor", GFInputAction.ValueType.AXIS_2D),
		[]
	)
	second_mapping.modifiers = [shared_cursor]
	_utility.enable_context(_make_context(&"gameplay", [first_mapping, second_mapping]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"modifier_state")

	assert_true(source.set_axis_2d(&"first_cursor", Vector2.RIGHT))
	assert_true(source.set_axis_2d(&"second_cursor", Vector2.RIGHT))

	assert_eq(_action_vector2(&"first_cursor"), Vector2(0.25, 0.0), "第一份运行时 modifier 应推进自己的位置。")
	assert_eq(_action_vector2(&"second_cursor"), Vector2(0.25, 0.0), "同一 Resource 配置的第二份运行时副本不得继承第一份位置。")


## 验证同一 action_id 出现在多个上下文时，高优先级动作定义不会被低优先级覆盖。
func test_duplicate_action_id_keeps_higher_priority_definition() -> void:
	var high_action: GFInputAction = _make_action(&"move_x", GFInputAction.ValueType.AXIS_1D)
	high_action.activation_threshold = 0.1
	high_action.release_threshold = 0.1
	var high_scale: GFInputScaleModifier = GFInputScaleModifier.new()
	high_scale.scale_x = 0.5
	var high_mapping: GFInputMapping = _make_mapping(high_action, [
		_make_key_binding(KEY_D, GFInputBinding.ValueTarget.AXIS_1D_POSITIVE),
	])
	high_mapping.modifiers = [high_scale]

	var low_action: GFInputAction = _make_action(&"move_x", GFInputAction.ValueType.AXIS_1D)
	low_action.activation_threshold = 0.1
	low_action.release_threshold = 0.1
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
	action.release_threshold = 0.1
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


func test_pulse_trigger_rejects_nonfinite_delta_and_recovers() -> void:
	var trigger: GFInputPulseTrigger = GFInputPulseTrigger.new()
	trigger.interval_seconds = 0.1
	trigger.trigger_immediately = false
	var state: Dictionary = {}
	trigger.reset_trigger_state(state)

	assert_eq(trigger.update(true, true, 0.0, state), GFInputTrigger.TriggerState.ONGOING)
	assert_eq(trigger.update(true, true, INF, state), GFInputTrigger.TriggerState.ONGOING, "Infinity delta 应被忽略。")
	assert_true(is_finite(GFVariantData.get_option_float(state, "elapsed")), "Infinity delta 后 elapsed 必须有限。")
	assert_eq(trigger.update(true, true, NAN, state), GFInputTrigger.TriggerState.ONGOING, "NaN delta 应被忽略。")
	assert_true(is_finite(GFVariantData.get_option_float(state, "elapsed")), "NaN delta 后 elapsed 必须有限。")
	assert_eq(trigger.update(true, true, 0.1, state), GFInputTrigger.TriggerState.TRIGGERED, "后续有限 delta 应可正常恢复脉冲。")
	assert_true(is_finite(GFVariantData.get_option_float(state, "elapsed")), "触发后的 remainder 必须有限。")

	var _released: GFInputTrigger.TriggerState = trigger.update(false, false, 0.0, state)
	assert_eq(GFVariantData.get_option_float(state, "elapsed"), 0.0, "释放应完整清理受攻击后的时间状态。")


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


func test_player_scoped_chord_fails_closed_without_player_protocol() -> void:
	var trigger: GFInputChordTrigger = GFInputChordTrigger.new()
	trigger.required_action_id = &"modifier"
	trigger.player_scoped = true
	var state: Dictionary = {}
	trigger.prepare_runtime(&"special", GlobalOnlyInputRuntime.new(), 1, state)

	var result: GFInputTrigger.TriggerState = trigger.update(true, true, 0.0, state)

	assert_eq(result, GFInputTrigger.TriggerState.INACTIVE, "player-scoped chord 缺玩家查询协议时不得回落到其他玩家的全局状态。")


func test_player_scoped_sequence_fails_closed_on_partial_player_protocol() -> void:
	var trigger: GFInputSequenceTrigger = GFInputSequenceTrigger.new()
	var action_ids: Array[StringName] = [&"step"]
	trigger.required_action_ids = action_ids
	trigger.player_scoped = true
	var state: Dictionary = {}
	trigger.reset_trigger_state(state)
	trigger.prepare_runtime(&"special", PartialPlayerInputRuntime.new(), 1, state)

	var result: GFInputTrigger.TriggerState = trigger.update(true, true, 0.0, state)

	assert_ne(result, GFInputTrigger.TriggerState.TRIGGERED, "player-scoped sequence 缺任一玩家查询方法时不得混用全局时间线。")


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


func test_sequence_trigger_required_action_cache_updates_when_ids_change() -> void:
	var sequence_trigger: GFInputSequenceTrigger = GFInputSequenceTrigger.new()
	var left_ids: Array[StringName] = [&"left"]
	sequence_trigger.required_action_ids = left_ids
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
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_true(_utility.is_action_active(&"special"), "旧 required_action_ids 应按 left 触发。")

	_utility.clear_input_state()
	var down_ids: Array[StringName] = [&"down"]
	sequence_trigger.required_action_ids = down_ids
	_utility.handle_input_event(_make_key_event(KEY_A, true))
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_false(_utility.is_action_active(&"special"), "修改 required_action_ids 后不应继续使用旧分支缓存。")

	_utility.clear_input_state()
	_utility.handle_input_event(_make_key_event(KEY_S, true))
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_true(_utility.is_action_active(&"special"), "新 required_action_ids 应按 down 触发。")


func test_sequence_trigger_resets_progress_when_same_count_branch_configuration_changes() -> void:
	var sequence_trigger: GFInputSequenceTrigger = GFInputSequenceTrigger.new()
	var left_ids: Array[StringName] = [&"left"]
	var initial_branches: Array[GFInputSequenceBranch] = [
		GFInputSequenceBranch.from_action_ids(left_ids, 0.3),
	]
	sequence_trigger.branches = initial_branches
	var special_mapping: GFInputMapping = _make_mapping(_make_action(&"special"), [
		_make_key_binding(KEY_P),
	])
	special_mapping.triggers = [sequence_trigger]
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"left"), [_make_key_binding(KEY_A)]),
		_make_mapping(_make_action(&"down"), [_make_key_binding(KEY_S)]),
		special_mapping,
	])
	_utility.enable_context(context)

	_utility.handle_input_event(_make_key_event(KEY_A, true))
	var down_ids: Array[StringName] = [&"down"]
	var replacement_branches: Array[GFInputSequenceBranch] = [
		GFInputSequenceBranch.from_action_ids(down_ids, 0.3),
	]
	sequence_trigger.branches = replacement_branches
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_false(_utility.is_action_active(&"special"), "同分支数量的热变更也必须清除旧配置进度。")

	_utility.clear_input_state()
	_utility.handle_input_event(_make_key_event(KEY_S, true))
	_utility.handle_input_event(_make_key_event(KEY_P, true))

	assert_true(_utility.is_action_active(&"special"), "热变更后应按新分支重新完成序列。")


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


func test_touch_binding_keeps_contributions_for_distinct_touch_indices() -> void:
	var action: GFInputAction = _make_action(&"touch_action")
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = _make_touch_event(0, true)
	var entry: Dictionary = {
		"action": action,
		"action_id": &"touch_action",
		"bindings": [{
			"binding": binding,
			"key": "touch/action/0",
		}],
	}

	var _first_press: Variant = _utility._apply_entry_event(entry, _make_touch_event(0, true), 0)
	var _second_press: Variant = _utility._apply_entry_event(entry, _make_touch_event(7, true), 0)
	var _first_release: Variant = _utility._apply_entry_event(entry, _make_touch_event(0, false), 0)

	assert_true(_utility.is_action_active(&"touch_action"), "另一个触点仍按住时，全局动作必须保持活跃。")
	assert_true(
		_utility.is_action_active_for_player(0, &"touch_action"),
		"另一个触点仍按住时，玩家动作必须保持活跃。"
	)

	var _second_release: Variant = _utility._apply_entry_event(entry, _make_touch_event(7, false), 0)
	assert_false(_utility.is_action_active(&"touch_action"), "最后一个触点释放后，全局动作才应结束。")
	assert_false(
		_utility.is_action_active_for_player(0, &"touch_action"),
		"最后一个触点释放后，玩家动作才应结束。"
	)


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


func test_player_queries_do_not_allocate_runtime_metadata_for_unknown_actions() -> void:
	for player_index: int in range(100):
		var action_id: StringName = StringName("missing_action_%d" % player_index)
		var _value: Variant = _utility.get_action_value_for_player(player_index, action_id)
		var _active: bool = _utility.is_action_active_for_player(player_index, action_id)
		var _just_started: bool = _utility.was_action_just_started_for_player(player_index, action_id)
		var _just_completed: bool = _utility.was_action_just_completed_for_player(player_index, action_id)
		var _duration: float = _utility.get_last_completed_duration_for_player(player_index, action_id)

	var metadata: Dictionary = GFVariantData.as_dictionary(_utility.get("_player_action_metadata"))
	assert_true(metadata.is_empty(), "纯查询不得为不存在的玩家动作累积元数据。")


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


func test_input_remap_config_apply_dict_is_transactional_and_reports_commit() -> void:
	var remap_config: GFInputRemapConfig = GFInputRemapConfig.new()
	remap_config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE, true))
	remap_config.custom_data = { "profile": "stable" }
	var invalid_data: Dictionary = {
		"remapped_events": {
			"gameplay": {
				"jump": {
					"0": {
						"event_class": "NotInputEvent",
						"properties": {},
					},
				},
			},
		},
		"custom_data": { "profile": "replacement" },
	}

	var invalid_report: Dictionary = remap_config.apply_dict(invalid_data)
	var preserved_event_value: InputEvent = remap_config.get_bound_event_or_null(&"gameplay", &"jump", 0)

	assert_false(GFVariantData.get_option_bool(invalid_report, "ok"), "非法候选配置应返回失败。")
	assert_false(GFVariantData.get_option_bool(invalid_report, "committed"), "非法候选配置不得提交。")
	assert_true(preserved_event_value is InputEventKey, "失败后原绑定类型应保留。")
	if preserved_event_value is InputEventKey:
		var preserved_event: InputEventKey = preserved_event_value
		assert_eq(preserved_event.keycode, KEY_SPACE, "失败后原绑定内容应保留。")
	assert_eq(GFVariantData.get_option_string(remap_config.custom_data, "profile"), "stable", "失败后自定义数据也应保持原值。")

	var replacement: GFInputRemapConfig = GFInputRemapConfig.new()
	replacement.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_ENTER, true))
	replacement.custom_data = { "profile": "replacement" }
	var success_report: Dictionary = remap_config.apply_dict(replacement.to_dict())
	var committed_event_value: InputEvent = remap_config.get_bound_event_or_null(&"gameplay", &"jump", 0)

	assert_true(GFVariantData.get_option_bool(success_report, "ok"), "有效候选配置应成功。")
	assert_true(GFVariantData.get_option_bool(success_report, "committed"), "有效候选配置应显式报告已提交。")
	assert_eq(GFVariantData.get_option_int(success_report, "binding_count"), 1)
	assert_true(committed_event_value is InputEventKey, "提交后应恢复有效按键事件。")
	if committed_event_value is InputEventKey:
		var committed_event: InputEventKey = committed_event_value
		assert_eq(committed_event.keycode, KEY_ENTER, "提交后应切换到候选绑定。")


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


func test_input_conflict_analyzer_reports_event_records_without_raw_events() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	var report: Dictionary = GFInputConflictAnalyzer.build_rebind_report([context])
	var items: Array = GFVariantData.get_option_array(report, "items")
	var item: Dictionary = GFVariantData.as_dictionary(items[0])
	var event_record: Dictionary = GFVariantData.get_option_dictionary(item, "event_record")

	assert_false(item.has("event"), "重绑定报告不应暴露原始 InputEvent。")
	assert_eq(GFVariantData.get_option_string(event_record, "event_class"), "InputEventKey")
	assert_false(JSON.stringify(report).is_empty(), "重绑定报告应可直接 JSON 序列化。")


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


func test_unassigned_physical_input_does_not_drive_global_action_when_device_utility_is_bound() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var devices: GFInputDeviceUtility = GFInputDeviceUtility.new()
	devices.include_keyboard_mouse = false
	devices.include_touch = false
	devices.max_players = 1
	await arch.register_utility_instance(devices)
	await arch.register_utility_instance(_utility)
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_key_binding(KEY_SPACE),
		]),
	])

	_utility.enable_context(context)
	_utility.handle_input_event(_make_key_event(KEY_SPACE, true))

	assert_false(_utility.is_action_active(&"jump"), "绑定设备工具后，未归属物理输入不应污染全局动作状态。")
	arch.dispose()
	_utility = null
	await get_tree().process_frame


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
	action.release_threshold = 0.1
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


func test_virtual_input_source_reconfigure_releases_old_identity_contributions() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"old_source", 0)

	assert_true(source.press(&"jump"), "旧身份应能写入动作贡献。")
	var _same_configuration: GFVirtualInputSource = source.configure(_utility, &"old_source", 0)
	assert_true(_utility.is_action_active(&"jump"), "重复配置同一身份必须保持既有贡献。")
	var _configured_source: GFVirtualInputSource = source.configure(_utility, &"new_source", 1)

	assert_false(_utility.is_action_active(&"jump"), "重配置必须清理旧身份留下的全局贡献。")
	assert_false(_utility.is_action_active_for_player(0, &"jump"), "重配置必须清理旧玩家贡献。")
	assert_true(source.press(&"jump"), "重配置后的新身份应可继续使用。")
	assert_true(_utility.is_action_active_for_player(1, &"jump"), "新贡献只能进入新玩家身份。")
	assert_true(source.release(&"jump"), "新身份应能正常释放自己的贡献。")


func test_virtual_input_source_public_identity_setters_release_old_contributions() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"source", 0)

	assert_true(source.press(&"jump"), "初始身份应能写入动作贡献。")
	source.player_index = 1

	assert_false(_utility.is_action_active(&"jump"), "直接修改 player_index 也必须释放旧身份贡献。")
	assert_false(_utility.is_action_active_for_player(0, &"jump"), "旧玩家不得保留不可达贡献。")

	assert_true(source.press(&"jump"), "修改 player_index 后应能以新身份写入。")
	source.source_id = &"renamed"

	assert_false(_utility.is_action_active_for_player(1, &"jump"), "直接修改 source_id 必须释放旧 source 贡献。")


func test_virtual_input_source_mapping_change_releases_old_mapping_contributions() -> void:
	var no_bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"old_mapping", [
		_make_mapping(_make_action(&"jump"), no_bindings),
	]))
	var replacement: GFInputMappingUtility = GFInputMappingUtility.new()
	replacement.init()
	replacement.enable_context(_make_context(&"new_mapping", [
		_make_mapping(_make_action(&"jump"), no_bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"source", 0)

	assert_true(source.press(&"jump"))
	var _configured_source: GFVirtualInputSource = source.configure(replacement, &"source", 0)

	assert_false(_utility.is_action_active(&"jump"), "迁移 mapping 必须释放旧 mapping 中的贡献。")
	assert_true(source.press(&"jump"), "迁移后的 source 应能写入新 mapping。")
	assert_true(replacement.is_action_active_for_player(0, &"jump"), "新贡献必须只进入新 mapping。")
	replacement.dispose()


func test_virtual_input_source_rejects_nonfinite_values_without_mutation() -> void:
	var axis_1d: GFInputAction = _make_action(&"axis_1d", GFInputAction.ValueType.AXIS_1D)
	var axis_2d: GFInputAction = _make_action(&"axis_2d", GFInputAction.ValueType.AXIS_2D)
	var axis_3d: GFInputAction = _make_action(&"axis_3d", GFInputAction.ValueType.AXIS_3D)
	var bool_action: GFInputAction = _make_action(&"bool_action")
	var no_bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(axis_1d, no_bindings),
		_make_mapping(axis_2d, no_bindings),
		_make_mapping(axis_3d, no_bindings),
		_make_mapping(bool_action, no_bindings),
	]))
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"valid")
	var hostile: GFVirtualInputSource = _utility.create_virtual_source(&"hostile")

	assert_true(source.set_axis_1d(&"axis_1d", 0.25))
	assert_true(source.set_axis_2d(&"axis_2d", Vector2(0.25, -0.5)))
	assert_true(source.set_axis_3d(&"axis_3d", Vector3(0.25, -0.5, 0.75)))
	assert_false(hostile.set_axis_1d(&"axis_1d", NAN), "NaN 标量必须被拒绝。")
	assert_false(hostile.set_axis_2d(&"axis_2d", Vector2(INF, 0.0)), "无限二维分量必须被拒绝。")
	assert_false(hostile.set_axis_3d(&"axis_3d", Vector3(0.0, -INF, 0.0)), "无限三维分量必须被拒绝。")
	assert_false(hostile.set_action_value(&"bool_action", NAN), "布尔动作也不得把非有限数解释为 release。")

	assert_almost_eq(_action_float(&"axis_1d"), 0.25, 0.001, "坏来源不得污染合法一维贡献。")
	assert_eq(_action_vector2(&"axis_2d"), Vector2(0.25, -0.5), "坏来源不得污染合法二维贡献。")
	assert_eq(
		GFVariantData.to_vector3(_utility.get_action_value(&"axis_3d")),
		Vector3(0.25, -0.5, 0.75),
		"坏来源不得污染合法三维贡献。"
	)
	assert_false(_utility.is_action_active(&"bool_action"), "被拒绝的布尔值不得产生贡献。")


func test_virtual_input_source_snapshot_has_stable_player_scoped_schema() -> void:
	var no_bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"player_zero"), no_bindings),
		_make_mapping(_make_action(&"player_one"), no_bindings),
	]))
	var player_zero: GFVirtualInputSource = _utility.create_virtual_source(&"shared", 0)
	var player_one: GFVirtualInputSource = _utility.create_virtual_source(&"shared", 1)
	assert_true(player_zero.press(&"player_zero"))
	assert_true(player_one.press(&"player_one"))

	var live_snapshot: Dictionary = player_zero.get_snapshot()
	var live_actions: Array = GFVariantData.get_option_array(live_snapshot, "actions")

	assert_eq(live_snapshot.size(), 3, "存活 mapping 快照应返回精确稳定字段集。")
	assert_true(live_snapshot.has("source_id"))
	assert_true(live_snapshot.has("player_index"))
	assert_true(live_snapshot.has("actions"))
	assert_eq(GFVariantData.get_option_int(live_snapshot, "player_index"), 0)
	assert_eq(live_actions.size(), 1, "handle 快照只能包含当前玩家身份的贡献。")
	assert_eq(
		GFVariantData.get_option_string_name(GFVariantData.as_dictionary(live_actions[0]), "action_id"),
		&"player_zero"
	)

	_utility.dispose()
	_utility = null
	var released_snapshot: Dictionary = player_zero.get_snapshot()
	assert_eq(released_snapshot.size(), 3, "mapping 释放后快照字段集不得改变。")
	assert_true(released_snapshot.has("source_id"))
	assert_true(released_snapshot.has("player_index"))
	assert_true(released_snapshot.has("actions"))
	assert_true(GFVariantData.get_option_array(released_snapshot, "actions").is_empty())


func test_clear_player_input_state_removes_player_global_contributions() -> void:
	var action: GFInputAction = _make_action(&"move", GFInputAction.ValueType.AXIS_2D)
	action.activation_threshold = 0.1
	action.release_threshold = 0.1
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


func test_virtual_source_ids_with_delimiters_do_not_clear_each_other() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"boost"), bindings),
	])
	_utility.enable_context(context)
	var nested_source: GFVirtualInputSource = _utility.create_virtual_source(&"pad/one")
	var parent_source: GFVirtualInputSource = _utility.create_virtual_source(&"pad")

	assert_true(nested_source.press(&"boost"), "带分隔符的虚拟源应能写入动作。")
	assert_true(parent_source.press(&"boost"), "普通虚拟源应能写入同一动作。")

	parent_source.clear_all()

	assert_true(_utility.is_action_active(&"boost"), "清理 pad 不应误伤 pad/one 的虚拟贡献。")
	assert_true(nested_source.release(&"boost"), "剩余虚拟源仍应能独立释放动作。")
	assert_false(_utility.is_action_active(&"boost"), "释放剩余贡献后动作才应结束。")


func test_virtual_input_pulse_completes_with_exactly_one_release() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", 0, timer_utility)

	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 0.1)

	assert_true(operation.is_pending(), "有效脉冲应返回 pending 类型化句柄。")
	assert_true(_utility.is_action_active(&"confirm"), "脉冲启动后应立即写入动作值。")
	timer_utility.tick(0.1)

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.COMPLETED, "到时后应进入 COMPLETED。")
	assert_eq(operation.get_release_count(), 1, "取得 lease 的脉冲必须恰好完成一次匹配释放。")
	assert_false(_utility.is_action_active(&"confirm"), "匹配释放后动作应结束。")
	timer_utility.tick(1.0)
	assert_eq(operation.get_release_count(), 1, "后续 tick 不得重复释放已完成脉冲。")
	timer_utility.dispose()


func test_virtual_input_pulse_zero_duration_completes_synchronously() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", 0, timer_utility)

	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 0.0)

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.COMPLETED, "0 秒脉冲应在返回前同步完成。")
	assert_eq(operation.get_release_count(), 1, "0 秒脉冲也必须完成一次匹配释放。")
	assert_false(_utility.is_action_active(&"confirm"), "同步完成后不得遗留动作贡献。")
	assert_eq(
		GFVariantData.get_option_int(timer_utility.get_debug_snapshot(), "pending_count"),
		0,
		"0 秒脉冲不得遗留排队 timer。"
	)
	timer_utility.dispose()


func test_virtual_input_pulse_replacement_is_safe_across_duplicate_source_objects() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var first_source: GFVirtualInputSource = _utility.create_virtual_source(&"shared", 0, timer_utility)
	var second_source: GFVirtualInputSource = _utility.create_virtual_source(&"shared", 0, timer_utility)
	var first: GFVirtualInputPulseOperation = first_source.pulse_action(&"confirm", true, 0.1)
	var completed_actions: Array[StringName] = []
	var on_action_completed: Callable = func(action_id: StringName, _value: Variant) -> void:
		completed_actions.append(action_id)
	var _connected: Error = _utility.action_completed.connect(on_action_completed) as Error
	timer_utility.tick(0.04)

	var second: GFVirtualInputPulseOperation = second_source.pulse_action(&"confirm", true, 0.2)

	assert_eq(first.get_status(), GFVirtualInputPulseOperation.Status.REPLACED, "同稳定输入键的新脉冲应替换旧 lease。")
	assert_eq(first.get_release_count(), 0, "原子交接不得把旧 lease 计为实际释放。")
	assert_true(second.is_pending(), "新脉冲应持有权威 lease。")
	assert_true(_utility.is_action_active(&"confirm"), "替换完成后新脉冲应保持动作激活。")
	assert_eq(completed_actions.size(), 0, "同键替换不得暴露中间 inactive 状态。")
	timer_utility.tick(0.07)
	assert_true(_utility.is_action_active(&"confirm"), "旧脉冲原到期点不得清除新 generation。")
	assert_true(second.is_pending(), "旧定时器不得终止新句柄。")
	timer_utility.tick(0.13)
	assert_eq(second.get_status(), GFVirtualInputPulseOperation.Status.COMPLETED, "新脉冲应按自己的时长完成。")
	assert_eq(second.get_release_count(), 1, "新 lease 也应只释放一次。")
	assert_false(_utility.is_action_active(&"confirm"), "新脉冲完成后动作应结束。")
	timer_utility.dispose()


func test_virtual_input_pulse_reject_new_preserves_current_lease() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var current: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 0.2)

	var rejected: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		0.1,
		null,
		null,
		GFVirtualInputSource.PulseReplacementPolicy.REJECT_NEW
	)

	assert_eq(rejected.get_status(), GFVirtualInputPulseOperation.Status.REJECTED, "REJECT_NEW 应让新句柄立即拒绝。")
	assert_eq(rejected.get_release_count(), 0, "未取得 lease 的拒绝句柄不得执行释放。")
	assert_true(current.is_pending(), "拒绝新请求不得终止当前 lease。")
	assert_true(_utility.is_action_active(&"confirm"), "拒绝新请求不得改变当前动作值。")
	timer_utility.tick(0.2)
	assert_eq(current.get_status(), GFVirtualInputPulseOperation.Status.COMPLETED, "原脉冲仍应正常完成。")
	timer_utility.dispose()


func test_manual_virtual_write_terminates_pulse_before_overwrite() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 0.1)
	var reentrant_operations: Array[GFVirtualInputPulseOperation] = []
	var completed_actions: Array[StringName] = []
	var on_action_completed: Callable = func(action_id: StringName, _value: Variant) -> void:
		completed_actions.append(action_id)
	var _action_connected: Error = _utility.action_completed.connect(on_action_completed) as Error
	var on_completed: Callable = func(_completed_operation: GFVirtualInputPulseOperation) -> void:
		reentrant_operations.append(source.pulse_action(&"confirm", true, 0.1))
	var _connected: Error = operation.completed.connect(on_completed, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error

	assert_true(source.press(&"confirm"), "手动写入应覆盖当前脉冲。")

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "手动写入前应取消匹配 pulse lease。")
	assert_eq(operation.get_terminal_reason(), &"manual_write", "终态应暴露稳定覆盖原因。")
	assert_eq(operation.get_release_count(), 0, "无中间 clear 的手动覆盖不得计为实际释放。")
	assert_eq(completed_actions.size(), 0, "同键手动覆盖不得暴露中间 inactive 状态。")
	assert_eq(reentrant_operations.size(), 1, "终态回调应被同步观察。")
	assert_eq(
		reentrant_operations[0].get_status(),
		GFVirtualInputPulseOperation.Status.REJECTED,
		"权威手动写事务中重入的新脉冲必须 fail closed。"
	)
	timer_utility.tick(0.2)
	assert_true(_utility.is_action_active(&"confirm"), "旧定时器不得清除覆盖后的手动值。")
	assert_true(source.release(&"confirm"), "手动值仍应由调用方显式释放。")
	timer_utility.dispose()


func test_manual_virtual_clear_terminates_matching_pulse_once() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 0.1)

	assert_true(source.clear_action(&"confirm"), "手动 clear 应终止当前脉冲并报告状态变化。")

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "手动 clear 应取消匹配 lease。")
	assert_eq(operation.get_terminal_reason(), &"manual_clear", "clear 终态原因应稳定。")
	assert_eq(operation.get_release_count(), 1, "手动 clear 应只释放一次。")
	assert_false(_utility.is_action_active(&"confirm"), "手动 clear 后动作应结束。")
	timer_utility.tick(0.2)
	assert_eq(operation.get_release_count(), 1, "旧定时器不得重复 clear。")
	timer_utility.dispose()


func test_virtual_input_pulse_fails_closed_for_invalid_lifecycle_anchors() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var released_owner: Object = Object.new()
	released_owner.free()
	var released_owner_operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		released_owner
	)

	assert_eq(
		released_owner_operation.get_status(),
		GFVirtualInputPulseOperation.Status.FAILED,
		"已释放 owner 不得被当作未提供 owner。"
	)
	assert_eq(
		released_owner_operation.get_terminal_reason(),
		&"invalid_owner_lifecycle",
		"已释放 owner 应提供稳定失败原因。"
	)
	assert_eq(released_owner_operation.get_release_count(), 0, "已释放 owner 不得取得 lease。")
	assert_false(_utility.is_action_active(&"confirm"), "已释放 owner 不得产生输入写入。")

	var tree_outside_owner: Node = Node.new()

	var invalid_owner_operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		tree_outside_owner
	)

	assert_eq(
		invalid_owner_operation.get_status(),
		GFVirtualInputPulseOperation.Status.FAILED,
		"树外 Node 不能形成可靠生命周期锚点，应 fail closed。"
	)
	assert_eq(
		invalid_owner_operation.get_terminal_reason(),
		&"invalid_owner_lifecycle",
		"无效 owner 应提供稳定失败原因。"
	)
	assert_eq(invalid_owner_operation.get_release_count(), 0, "绑定失败不得写入或释放 lease。")
	assert_false(_utility.is_action_active(&"confirm"), "生命周期校验失败时不得产生输入写入。")
	tree_outside_owner.free()

	var completed_scope: GFAsyncScope = GFAsyncScope.new()
	completed_scope.complete()
	var completed_scope_operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		null,
		completed_scope
	)

	assert_eq(
		completed_scope_operation.get_status(),
		GFVirtualInputPulseOperation.Status.FAILED,
		"已完成 GFAsyncScope 不得被重新用作活动取消锚点。"
	)
	assert_eq(
		completed_scope_operation.get_terminal_reason(),
		&"cancellation_scope_completed",
		"已完成 scope 应提供可诊断的稳定原因。"
	)
	assert_eq(completed_scope_operation.get_release_count(), 0, "scope 绑定失败不得取得 lease。")
	assert_false(_utility.is_action_active(&"confirm"), "scope 绑定失败时不得写入动作。")
	timer_utility.dispose()


func test_virtual_input_pulse_releases_when_scope_completes_after_lease_acquisition() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		null,
		scope
	)

	assert_true(operation.is_pending(), "活动 scope 应允许 pulse 取得 lease。")
	assert_true(_utility.is_action_active(&"confirm"), "scope 完成前动作应保持活动。")
	scope.complete()
	_utility.tick(0.0)

	assert_eq(
		operation.get_status(),
		GFVirtualInputPulseOperation.Status.CANCELLED,
		"scope 完成后 Mapping tick 应取消 pulse。"
	)
	assert_eq(
		operation.get_terminal_reason(),
		&"cancellation_scope_completed",
		"scope 完成应提供稳定终态原因。"
	)
	assert_eq(operation.get_release_count(), 1, "scope 完成应执行一次匹配释放。")
	assert_false(_utility.is_action_active(&"confirm"), "scope 完成后动作不得保持粘滞。")
	timer_utility.tick(2.0)
	assert_eq(operation.get_release_count(), 1, "scope 终止后旧 timer 不得重复释放。")
	timer_utility.dispose()


func test_virtual_input_pulse_honors_pre_cancelled_token_before_write() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	var _cancelled: bool = cancellation_source.cancel(&"already_closed")

	var operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		null,
		cancellation_source.get_token()
	)

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "预取消 token 应同步取消句柄。")
	assert_eq(operation.get_terminal_reason(), &"already_closed", "应保留预取消 token 的首次原因。")
	assert_eq(operation.get_release_count(), 0, "预取消操作不得取得或释放 lease。")
	assert_false(_utility.is_action_active(&"confirm"), "预取消 token 不得产生瞬时输入写入。")
	timer_utility.dispose()


func test_virtual_input_pulse_owner_and_token_use_or_cancellation() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var owner_node: Node = Node.new()
	add_child(owner_node)
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	var operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		owner_node,
		cancellation_source.get_token()
	)

	var cancel_requested: bool = cancellation_source.cancel(&"view_closed")

	assert_true(cancel_requested, "测试 token 应成功提交首次取消。")
	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "任一锚点取消都应终止脉冲。")
	assert_eq(operation.get_terminal_reason(), &"view_closed", "应保留 first-terminal token 原因。")
	assert_eq(operation.get_release_count(), 1, "token 取消应完成一次匹配释放。")
	owner_node.queue_free()
	await get_tree().process_frame
	assert_eq(operation.get_release_count(), 1, "后到 owner 终态不得重复释放。")
	assert_false(_utility.is_action_active(&"confirm"), "OR 取消后动作应结束。")
	timer_utility.dispose()


func test_virtual_input_pulse_node_owner_tree_exit_releases_matching_lease() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var owner_node: Node = Node.new()
	add_child(owner_node)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		owner_node
	)

	owner_node.queue_free()
	await get_tree().process_frame

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "Node owner 离树应取消脉冲。")
	assert_eq(operation.get_terminal_reason(), &"owner_released", "Node owner 离树应提供稳定原因。")
	assert_eq(operation.get_release_count(), 1, "Node owner 离树应完成一次匹配释放。")
	assert_false(_utility.is_action_active(&"confirm"), "Node owner 离树后动作不得粘住。")
	timer_utility.tick(2.0)
	assert_eq(operation.get_release_count(), 1, "owner 终止后旧 timer 不得重复释放。")
	timer_utility.dispose()


func test_virtual_input_pulse_prunes_released_ref_counted_owner_on_mapping_tick() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var operation: GFVirtualInputPulseOperation = source.pulse_action(
		&"confirm",
		true,
		1.0,
		lifecycle_owner
	)
	lifecycle_owner = null

	_utility.tick(0.0)

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "Mapping tick 应发现普通 Object owner 已释放。")
	assert_eq(operation.get_terminal_reason(), &"owner_released", "弱 owner 清理应提供稳定原因。")
	assert_eq(operation.get_release_count(), 1, "弱 owner 释放应完成一次匹配释放。")
	assert_false(_utility.is_action_active(&"confirm"), "普通 Object owner 释放后动作不得粘住。")
	timer_utility.dispose()


func test_virtual_input_source_dispose_releases_owned_pulses() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 1.0)

	source.dispose()

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "Source dispose 应取消其活动脉冲。")
	assert_eq(operation.get_terminal_reason(), &"source_disposed", "Source dispose 应提供稳定原因。")
	assert_eq(operation.get_release_count(), 1, "Source dispose 应释放 lease 一次。")
	assert_false(_utility.is_action_active(&"confirm"), "Source dispose 后动作不得粘住。")
	timer_utility.tick(2.0)
	assert_eq(operation.get_release_count(), 1, "dispose 后旧 timer 不得重复释放。")
	var _reconfigure_result: GFVirtualInputSource = source.configure(
		_utility,
		&"revived",
		-1,
		timer_utility
	)
	assert_false(source.press(&"confirm"), "dispose 应为不可逆终态，configure 不得复活手动写入。")
	var refused_after_dispose: GFVirtualInputPulseOperation = source.pulse_action(&"confirm")
	assert_eq(
		refused_after_dispose.get_status(),
		GFVirtualInputPulseOperation.Status.FAILED,
		"dispose 后 pulse 应 fail closed。"
	)
	assert_eq(refused_after_dispose.get_terminal_reason(), &"source_disposed", "失败原因应稳定。")
	timer_utility.dispose()


func test_mapping_rebuild_and_dispose_terminate_pulse_leases() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	])
	_utility.enable_context(context)
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var rebuilt_operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 1.0)

	_utility.set_enabled_contexts([context])

	assert_eq(rebuilt_operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "Mapping rebuild 应取消旧 lease。")
	assert_eq(rebuilt_operation.get_terminal_reason(), &"mapping_rebuilt", "重建原因应稳定。")
	assert_eq(rebuilt_operation.get_release_count(), 1, "重建应先完成一次匹配释放。")
	var disposed_operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 1.0)
	assert_true(disposed_operation.is_pending(), "重建后的 Source 应能启动新脉冲。")

	_utility.dispose()

	assert_eq(disposed_operation.get_status(), GFVirtualInputPulseOperation.Status.CANCELLED, "Mapping dispose 应取消活动 lease。")
	assert_eq(disposed_operation.get_terminal_reason(), &"mapping_disposed", "dispose 原因应稳定。")
	assert_eq(disposed_operation.get_release_count(), 1, "Mapping dispose 应释放一次。")
	timer_utility.tick(2.0)
	assert_eq(disposed_operation.get_release_count(), 1, "dispose 后旧 timer 不得重复释放。")
	_utility = null
	timer_utility.dispose()


func test_virtual_input_pulse_releases_when_timer_schedule_is_rebuilt() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"touch", -1, timer_utility)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 1.0)
	var original_timer_handle: int = GFVariantData.get_option_int(
		operation.get_debug_snapshot(),
		"timer_handle"
	)

	timer_utility.dispose()
	timer_utility.init()
	var unrelated_state: Dictionary = {"count": 0}
	var unrelated_handle: int = timer_utility.execute_after(0.25, func() -> void:
		unrelated_state["count"] = GFVariantData.get_option_int(unrelated_state, "count") + 1
	)
	assert_eq(unrelated_handle, original_timer_handle, "夹具应证明 dispose/init 后 timer handle 已被复用。")

	_utility.tick(0.0)

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.FAILED, "丢失的 timer 排程应 fail closed。")
	assert_eq(operation.get_terminal_reason(), &"timer_schedule_lost", "timer 重建应提供稳定失败原因。")
	assert_eq(operation.get_release_count(), 1, "timer 排程丢失后应补偿释放当前 lease。")
	assert_false(_utility.is_action_active(&"confirm"), "timer 排程丢失后动作不得粘住。")
	timer_utility.tick(0.25)
	assert_eq(
		GFVariantData.get_option_int(unrelated_state, "count"),
		1,
		"旧 pulse 终止不得误取消复用 handle 的无关 timer。"
	)
	timer_utility.dispose()


func test_mapping_tick_releases_pulse_when_source_and_handle_are_dropped() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"ephemeral", -1, timer_utility)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 1.0)
	var operation_ref: WeakRef = weakref(operation)
	operation = null
	source = null

	_utility.tick(0.0)

	assert_false(operation_ref.get_ref() is Object, "Mapping lease 不得强持有已丢弃的 pulse operation。")
	assert_false(_utility.is_action_active(&"confirm"), "Mapping tick 应补偿释放弱 operation 遗留贡献。")
	timer_utility.dispose()


func test_virtual_input_pulse_freezes_identity_across_source_reconfiguration() -> void:
	var bindings: Array[GFInputBinding] = []
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"confirm"), bindings),
	]))
	var timer_utility: GFTimerUtility = GFTimerUtility.new()
	timer_utility.init()
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"before", 0, timer_utility)
	var operation: GFVirtualInputPulseOperation = source.pulse_action(&"confirm", true, 0.1)
	source.source_id = &"after"
	source.player_index = 1

	assert_eq(operation.get_source_id(), &"before", "操作应冻结创建时 source_id。")
	assert_eq(operation.get_player_index(), 0, "操作应冻结创建时 player_index。")
	timer_utility.tick(0.1)

	assert_eq(operation.get_status(), GFVirtualInputPulseOperation.Status.COMPLETED, "重配 Source 不应阻断旧操作完成。")
	assert_false(_utility.is_action_active(&"confirm"), "旧操作应按冻结身份完成匹配释放。")
	timer_utility.dispose()


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


func test_input_playback_event_callback_stop_invalidates_due_event_loop() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), []),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"stop_reentrant")
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 0.0)
	var playback: GFInputPlayback = GFInputPlayback.new()
	var callback_state: Dictionary = {
		"count": 0,
		"stopped": false,
	}
	var event_applied_callback: Callable = func(_event: Dictionary) -> void:
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		if GFVariantData.get_option_bool(callback_state, "stopped"):
			return
		callback_state["stopped"] = true
		playback.stop(true)
	var _event_connection: int = playback.event_applied.connect(event_applied_callback)
	assert_true(playback.start(recording, source))

	var applied: int = playback.tick(0.0)
	var snapshot: Dictionary = playback.get_debug_snapshot()

	assert_eq(applied, 1, "首个事件回调 stop 后，旧 due-event 调用栈不得继续应用同时间事件。")
	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 1, "stop 后不得再次发出旧会话 event_applied。")
	assert_eq(GFVariantData.get_option_int(snapshot, "next_event_index"), 1, "事件应先提交索引再通知，停止后不会重复消费首事件。")
	assert_false(playback.is_playing, "回调 stop 后播放器应保持停止。")
	assert_false(_utility.is_action_active(&"jump"), "stop(true) 清空 source 后旧调用栈不得重新写入。")
	playback.event_applied.disconnect(event_applied_callback)


func test_input_playback_event_callback_restart_preserves_new_session_state() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"old_action"), []),
		_make_mapping(_make_action(&"new_action"), []),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"restart_reentrant")
	var old_recording: GFInputRecording = GFInputRecording.new()
	var _old_first: Dictionary = old_recording.add_event(&"old_action", true, 0.0)
	var _old_second: Dictionary = old_recording.add_event(&"old_action", false, 0.0)
	var new_recording: GFInputRecording = GFInputRecording.new()
	var _new_event: Dictionary = new_recording.add_event(&"new_action", true, 0.0)
	var playback: GFInputPlayback = GFInputPlayback.new()
	var callback_state: Dictionary = { "restarted": false }
	var event_applied_callback: Callable = func(_event: Dictionary) -> void:
		if GFVariantData.get_option_bool(callback_state, "restarted"):
			return
		callback_state["restarted"] = true
		var _restart_result: bool = playback.start(new_recording, source)
	var _event_connection: int = playback.event_applied.connect(event_applied_callback)
	assert_true(playback.start(old_recording, source))

	var old_applied: int = playback.tick(0.0)
	var restarted_snapshot: Dictionary = playback.get_debug_snapshot()

	assert_eq(old_applied, 1, "restart 后旧 tick 只应计入已经提交的首事件。")
	assert_eq(playback.recording, new_recording, "回调启动的新录制必须保持为当前会话。")
	assert_true(playback.is_playing, "旧调用栈不得把新会话误判为自然完成。")
	assert_eq(GFVariantData.get_option_int(restarted_snapshot, "next_event_index"), 0, "旧调用栈不得推进新会话索引。")
	assert_false(_utility.is_action_active(&"old_action"), "新 start 清理 source 后旧会话不得重新写入。")
	assert_false(_utility.is_action_active(&"new_action"), "新会话事件应留给下一次 tick。")

	assert_eq(playback.tick(0.0), 1, "后续 tick 应从新会话索引 0 正常应用事件。")
	assert_true(_utility.is_action_active(&"new_action"), "新会话事件不得被旧索引跳过。")
	playback.event_applied.disconnect(event_applied_callback)


func test_input_playback_event_callback_null_source_stops_without_old_stack_dereference() -> void:
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), []),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"null_source_reentrant")
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 0.0)
	var playback: GFInputPlayback = GFInputPlayback.new()
	var callback_state: Dictionary = { "count": 0 }
	var event_applied_callback: Callable = func(_event: Dictionary) -> void:
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		playback.source = null
	var _event_connection: int = playback.event_applied.connect(event_applied_callback)
	assert_true(playback.start(recording, source))

	var applied: int = playback.tick(0.0)

	assert_eq(applied, 1, "换源前已提交的首事件应计入结果。")
	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 1, "source=null 后不得继续通知旧会话事件。")
	assert_false(playback.is_playing, "直接替换会话 source 应使当前会话失效。")
	assert_eq(playback.tick(0.0), 0, "失效会话后续 tick 应安全返回，不得空引用。")
	playback.event_applied.disconnect(event_applied_callback)


func test_input_playback_defers_excess_loop_cycles_without_losing_events() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"loop_recording")
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 0.5)
	recording.duration_seconds = 1.0
	var playback: GFInputPlayback = GFInputPlayback.new()
	playback.loop = true
	playback.max_loop_cycles_per_tick = 1
	watch_signals(playback)
	assert_true(playback.start(recording, source))

	var first_applied: int = playback.tick(2.25)
	var deferred_snapshot: Dictionary = playback.get_debug_snapshot()
	var second_applied: int = playback.tick(0.0)
	var completed_snapshot: Dictionary = playback.get_debug_snapshot()

	assert_eq(first_applied + second_applied, 5, "延后策略应跨后续 tick 应用全部到期事件。")
	assert_almost_eq(GFVariantData.get_option_float(deferred_snapshot, "pending_advance_seconds"), 1.25, 0.001, "超预算时间应显式进入待处理队列。")
	assert_almost_eq(GFVariantData.get_option_float(completed_snapshot, "pending_advance_seconds"), 0.0, 0.001, "后续 tick 应清空待处理时间。")
	assert_true(_utility.is_action_active(&"jump"), "最终周期 0.25 秒处应保持按下状态。")
	assert_signal_emitted(playback, "loop_catch_up_limited", "达到循环预算时应暴露背压诊断。")


func test_input_playback_skips_cycles_only_under_explicit_policy() -> void:
	var bindings: Array[GFInputBinding] = []
	var context: GFInputContext = _make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), bindings),
	])
	_utility.enable_context(context)
	var source: GFVirtualInputSource = _utility.create_virtual_source(&"skip_recording")
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 0.5)
	recording.duration_seconds = 1.0
	var playback: GFInputPlayback = GFInputPlayback.new()
	playback.loop = true
	playback.max_loop_cycles_per_tick = 1
	playback.loop_catch_up_policy = GFInputPlayback.LoopCatchUpPolicy.SKIP_EXCESS_CYCLES
	watch_signals(playback)
	assert_true(playback.start(recording, source))

	var applied: int = playback.tick(3.25)
	var snapshot: Dictionary = playback.get_debug_snapshot()

	assert_eq(applied, 3, "显式跳过策略只应应用预算周期和最终周期状态事件。")
	assert_almost_eq(playback.elapsed_seconds, 0.25, 0.001, "跳过完整周期后应保留最终周期内时间。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "pending_advance_seconds"), 0.0, 0.001, "跳过策略不应留下待处理时间。")
	assert_true(_utility.is_action_active(&"jump"), "跳过后仍应重建最终周期状态。")
	assert_signal_emitted(playback, "loop_catch_up_limited", "显式跳过周期也应发出诊断信号。")


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


func test_max_players_shrink_clears_removed_player_input_state() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var devices: GFInputDeviceUtility = GFInputDeviceUtility.new()
	devices.include_keyboard_mouse = false
	devices.include_touch = false
	devices.max_players = 4
	await arch.register_utility_instance(devices)
	await arch.register_utility_instance(_utility)
	await arch.init()
	devices.set_assignment(devices.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 1))
	devices.set_assignment(devices.create_assignment(3, GFInputDeviceAssignment.DeviceType.JOYPAD, 7))
	_utility.enable_context(_make_context(&"gameplay", [
		_make_mapping(_make_action(&"jump"), [
			_make_joy_button_binding(JOY_BUTTON_A),
		]),
	]))

	_utility.handle_input_event(_make_joy_button_event(7, JOY_BUTTON_A, true))
	assert_true(_utility.is_action_active_for_player(3, &"jump"), "缩容前越界席位仍应有可观察状态。")

	devices.max_players = 1

	assert_false(_utility.is_action_active_for_player(3, &"jump"), "缩容撤销 assignment 时必须同步清理玩家状态。")
	assert_false(_utility.is_action_active(&"jump"), "被撤销玩家的贡献不得残留在全局聚合中。")
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


func test_input_playback_resume_rebuilds_virtual_source_state() -> void:
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
	playback.elapsed_seconds = 0.5

	assert_true(playback.start(recording, source, false), "中途继续回放应能启动。")

	assert_true(_utility.is_action_active(&"jump"), "中途继续时应先把虚拟源重建到当前时间。")
	assert_eq(playback.tick(0.0), 0, "重建已应用的历史事件不应在同时间 tick 重复发出。")


func test_input_recording_preserves_same_time_event_order() -> void:
	var recording: GFInputRecording = GFInputRecording.new()
	var _press: Dictionary = recording.add_event(&"jump", true, 0.0)
	var _release: Dictionary = recording.add_event(&"jump", false, 0.0)
	var restored: GFInputRecording = GFInputRecording.from_dict(recording.to_dict())
	var events: Array[Dictionary] = restored.get_events()

	assert_true(GFVariantData.to_bool(GFVariantData.get_option_value(events[0], "value")), "同时间事件应保留原始插入顺序。")
	assert_false(GFVariantData.to_bool(GFVariantData.get_option_value(events[1], "value")), "同时间事件恢复后顺序仍应稳定。")


func test_input_recording_events_property_returns_deep_read_only_snapshot() -> void:
	var recording: GFInputRecording = GFInputRecording.new()
	var _event: Dictionary = recording.add_event(&"jump", true, 0.0, -1, &"test", {
		"profile": "original",
	})
	var exposed_events: Array[Dictionary] = recording.events
	var exposed_metadata: Dictionary = GFVariantData.get_option_dictionary(exposed_events[0], "metadata")
	exposed_metadata["profile"] = "mutated"
	exposed_events.clear()

	var internal_events: Array[Dictionary] = recording.events
	var metadata: Dictionary = GFVariantData.get_option_dictionary(internal_events[0], "metadata")

	assert_eq(internal_events.size(), 1, "清空公开快照不得清空录制内部事件。")
	assert_eq(GFVariantData.get_option_string(metadata, "profile"), "original", "修改嵌套快照不得污染内部元数据。")


func test_input_recording_normalizes_nonfinite_event_times() -> void:
	var recording: GFInputRecording = GFInputRecording.new()
	var added_event: Dictionary = recording.add_event(&"jump", true, NAN)
	var restored: GFInputRecording = GFInputRecording.from_dict({
		"duration_seconds": INF,
		"events": [{
			"time_seconds": INF,
			"action_id": "jump",
			"value": false,
		}],
	})

	assert_almost_eq(GFVariantData.get_option_float(added_event, "time_seconds"), 0.0, 0.001, "新增事件不得保留 NaN 时间。")
	assert_almost_eq(GFVariantData.get_option_float(restored.events[0], "time_seconds"), 0.0, 0.001, "恢复事件不得保留 Infinity 时间。")
	assert_almost_eq(restored.duration_seconds, 0.0, 0.001, "录制总时长也必须保持有限。")
	assert_false(JSON.stringify(restored.to_dict(true)).contains(":null"), "录制报告不得把非有限时间退化为 null。")


func test_input_recording_inserts_out_of_order_events_by_time() -> void:
	var recording: GFInputRecording = GFInputRecording.new()
	var _late: Dictionary = recording.add_event(&"jump", true, 1.0)
	var _early: Dictionary = recording.add_event(&"jump", false, 0.25)
	var _middle: Dictionary = recording.add_event(&"move", true, 0.5)
	var events: Array[Dictionary] = recording.get_events()

	assert_almost_eq(GFVariantData.get_option_float(events[0], "time_seconds"), 0.25, 0.001, "较早事件应插入到前面。")
	assert_almost_eq(GFVariantData.get_option_float(events[1], "time_seconds"), 0.5, 0.001, "中间事件应保持时间顺序。")
	assert_almost_eq(GFVariantData.get_option_float(events[2], "time_seconds"), 1.0, 0.001, "较晚事件应留在末尾。")


func test_input_recording_apply_dict_extends_duration_to_last_event() -> void:
	var restored: GFInputRecording = GFInputRecording.from_dict({
		"recording_id": "sample",
		"duration_seconds": 0.1,
		"events": [
			{
				"time_seconds": 0.5,
				"action_id": "jump",
				"value": true,
				"player_index": -1,
				"source_id": "",
				"metadata": {},
			},
		],
		"metadata": {},
	})

	assert_almost_eq(restored.duration_seconds, 0.5, 0.001, "恢复录制时总时长不应短于最后一个事件。")


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


func test_tap_trigger_min_setter_keeps_window_valid() -> void:
	var trigger: GFInputTapTrigger = GFInputTapTrigger.new()
	trigger.max_tap_seconds = 0.1

	trigger.min_tap_seconds = 0.25

	assert_eq(trigger.max_tap_seconds, 0.25, "提高最短按住时间时最长时间应同步保持合法窗口。")


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
