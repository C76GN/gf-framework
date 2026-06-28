## 测试通用输入修饰器。
extends GutTest


# --- 测试方法 ---

## 验证曲线修饰器可按分量采样并保留符号。
func test_curve_modifier_samples_components() -> void:
	var curve: Curve = Curve.new()
	var _first_point: int = curve.add_point(Vector2(0.0, 0.0))
	var _second_point: int = curve.add_point(Vector2(1.0, 1.0))

	var modifier: GFInputCurveModifier = GFInputCurveModifier.new()
	modifier.curve = curve
	modifier.apply_y = false

	var result: Vector2 = modifier.modify(Vector2(-0.5, 0.25))

	assert_almost_eq(result.x, -0.5, 0.05, "X 分量应按曲线采样并保留符号。")
	assert_eq(result.y, 0.25, "禁用的分量应保留原值。")


## 验证分量重排修饰器可处理三维输入。
func test_swizzle_modifier_reorders_3d_components() -> void:
	var modifier: GFInputSwizzleModifier = GFInputSwizzleModifier.new()
	modifier.order = GFInputSwizzleModifier.SwizzleOrder.ZXY

	var result: Vector3 = modifier.modify_3d(Vector3(1.0, 2.0, 3.0))

	assert_eq(result, Vector3(3.0, 1.0, 2.0), "三维分量应按配置顺序重排。")


## 验证幅值修饰器可将多轴输入投影为一维长度。
func test_magnitude_modifier_outputs_selected_components() -> void:
	var modifier: GFInputMagnitudeModifier = GFInputMagnitudeModifier.new()
	modifier.output_x = true
	modifier.output_y = true

	var result: Vector2 = modifier.modify(Vector2(3.0, 4.0))

	assert_eq(result, Vector2(5.0, 5.0), "幅值应写入选中的输出分量。")


## 验证符号限制修饰器可只保留负向输入并转为正值。
func test_sign_clamp_modifier_filters_direction() -> void:
	var modifier: GFInputSignClampModifier = GFInputSignClampModifier.new()
	modifier.allowed_sign = GFInputSignClampModifier.AllowedSign.NEGATIVE
	modifier.remap_to_positive = true

	var result: Vector2 = modifier.modify(Vector2(-0.75, 0.5))

	assert_eq(result, Vector2(0.75, 0.0), "只应保留负向输入并按配置转为正值。")


## 验证虚拟光标修饰器按速度积分并限制范围。
func test_virtual_cursor_modifier_integrates_position() -> void:
	var modifier: GFInputVirtualCursorModifier = GFInputVirtualCursorModifier.new()
	modifier.apply_delta_time = false
	modifier.initial_position = Vector2(0.5, 0.5)
	modifier.speed = Vector2(0.25, 0.5)
	modifier.clamp_rect = Rect2(Vector2.ZERO, Vector2.ONE)

	var result: Vector2 = modifier.modify(Vector2(1.0, -1.0))

	assert_eq(result, Vector2(0.75, 0.0), "虚拟光标应按速度更新并限制在矩形范围内。")


## 验证虚拟光标运行时副本不会继承旧位置。
func test_virtual_cursor_duplicate_resets_runtime_state() -> void:
	var modifier: GFInputVirtualCursorModifier = GFInputVirtualCursorModifier.new()
	modifier.apply_delta_time = false
	modifier.initial_position = Vector2(0.25, 0.25)
	var _advanced_position: Vector2 = modifier.modify(Vector2(1.0, 0.0))

	var duplicated_modifier: GFInputVirtualCursorModifier = _virtual_cursor_modifier(
		modifier.duplicate_modifier()
	)

	assert_eq(duplicated_modifier.modify(Vector2.ZERO), Vector2(0.25, 0.25), "副本应从初始位置开始。")


## 验证虚拟光标可用手动 delta 做确定性积分。
func test_virtual_cursor_modifier_uses_manual_delta_for_deterministic_replay() -> void:
	var modifier: GFInputVirtualCursorModifier = GFInputVirtualCursorModifier.new()
	modifier.initial_position = Vector2.ZERO
	modifier.speed = Vector2(2.0, 1.0)
	modifier.clamp_to_rect = false
	var _manual_delta: GFInputVirtualCursorModifier = modifier.set_manual_delta_seconds(0.25)

	var first_position: Vector2 = modifier.modify(Vector2(1.0, 0.0))
	var second_position: Vector2 = modifier.modify(Vector2(1.0, 0.0))

	assert_eq(first_position, Vector2(0.5, 0.0), "手动 delta 应驱动第一步积分。")
	assert_eq(second_position, Vector2(1.0, 0.0), "相同手动 delta 应稳定驱动后续积分。")


## 验证虚拟光标运行时状态可恢复后继续确定性回放。
func test_virtual_cursor_runtime_state_roundtrips_for_replay() -> void:
	var modifier: GFInputVirtualCursorModifier = GFInputVirtualCursorModifier.new()
	modifier.initial_position = Vector2.ZERO
	modifier.speed = Vector2(4.0, 2.0)
	modifier.clamp_to_rect = false
	var _manual_delta: GFInputVirtualCursorModifier = modifier.set_manual_delta_seconds(0.125)
	var _first_step: Vector2 = modifier.modify(Vector2(1.0, -1.0))
	var runtime_state: Dictionary = modifier.get_runtime_state()

	var replay_modifier: GFInputVirtualCursorModifier = GFInputVirtualCursorModifier.new()
	replay_modifier.initial_position = Vector2.ZERO
	replay_modifier.speed = Vector2(4.0, 2.0)
	replay_modifier.clamp_to_rect = false
	var _replay_manual_delta: GFInputVirtualCursorModifier = replay_modifier.set_manual_delta_seconds(0.125)
	var _restored: GFInputVirtualCursorModifier = replay_modifier.restore_runtime_state(runtime_state)

	assert_eq(replay_modifier.modify(Vector2(0.0, 1.0)), modifier.modify(Vector2(0.0, 1.0)), "恢复状态后同一输入应得到同一位置。")


# --- 私有/辅助方法 ---

func _virtual_cursor_modifier(modifier: GFInputModifier) -> GFInputVirtualCursorModifier:
	if modifier is GFInputVirtualCursorModifier:
		var cursor_modifier: GFInputVirtualCursorModifier = modifier
		return cursor_modifier
	return null
