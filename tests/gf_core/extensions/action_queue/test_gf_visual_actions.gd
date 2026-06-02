## 测试 GFMoveTweenAction、GFFlashAction、GFShaderParameterAction、GFAudioAction 与 GFTweenActionStep 的基础行为。
extends GutTest


class TestAudioUtility:
	extends GFAudioUtility

	var played_paths: Array[String] = []
	var played_clip_ids: Array[StringName] = []

	func init() -> void:
		pass

	func dispose() -> void:
		pass

	func play_sfx(path: String) -> void:
		played_paths.append(path)

	func play_sfx_from_bank(_bank: GFAudioBank, clip_id: StringName) -> void:
		played_clip_ids.append(clip_id)


class ManualSignalAction:
	extends GFVisualAction

	signal completed

	var executed: bool = false
	var cancelled: bool = false

	func execute() -> Variant:
		executed = true
		return completed

	func cancel() -> void:
		cancelled = true

	func complete() -> void:
		completed.emit()


func after_each() -> void:
	if Gf.has_architecture():
		var arch: GFArchitecture = Gf.get_architecture()
		if arch != null:
			arch.dispose()

	await Gf.set_architecture(GFArchitecture.new())
	await get_tree().process_frame


func _signal_from_result(result: Variant) -> Signal:
	if result is Signal:
		return result
	return Signal()


func _configured_tween_action(action: GFVisualAction) -> GFConfiguredTweenAction:
	if action is GFConfiguredTweenAction:
		return action
	return null


func _make_shader_material(initial_strength: float = 0.0) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform float strength = 0.0;\n"
		+ "uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);\n"
		+ "void fragment() {\n"
		+ "\tCOLOR = tint;\n"
		+ "}\n"
	)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"strength", initial_strength)
	return material


func _get_shader_strength(material: Material) -> float:
	if material is ShaderMaterial:
		var shader_material: ShaderMaterial = material
		return GFVariantData.to_float(shader_material.get_shader_parameter(&"strength"))
	return 0.0


func test_move_tween_action_sets_position_immediately_when_duration_zero() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var action: GFVisualAction = GFMoveTweenAction.new(node, Vector2(24.0, 32.0), 0.0)
	var result: Variant = action.execute()

	assert_true(result == null, "零时长移动动作应立即完成。")
	assert_eq(node.position, Vector2(24.0, 32.0), "零时长移动动作应立即写入目标位置。")


func test_move_tween_action_waits_for_tween() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var action: GFVisualAction = GFMoveTweenAction.new(node, Vector2(10.0, 0.0), 0.01)
	var result: Variant = action.execute()

	assert_true(result is Signal, "非零时长移动动作应返回 Tween 完成信号。")
	var completion: Signal = _signal_from_result(result)
	assert_eq(String(completion.get_name()), "_action_completed", "Tween 动作应返回自身完成信号，而不是手动发射引擎 Tween.finished。")
	await action.await_result_safely(result)

	assert_almost_eq(node.position.x, 10.0, 0.01, "移动 Tween 完成后应到达目标 x。")
	assert_almost_eq(node.position.y, 0.0, 0.01, "移动 Tween 完成后应到达目标 y。")


func test_move_tween_action_wait_ends_when_target_exits_tree() -> void:
	var node: Node2D = Node2D.new()
	add_child(node)

	var action: GFVisualAction = GFMoveTweenAction.new(node, Vector2(100.0, 0.0), 1.0)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(completed[0], "Tween 目标节点退出树时，等待应立即结束。")


func test_move_tween_action_rejects_incompatible_target_value() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var action: GFVisualAction = GFMoveTweenAction.new(node, "bad_target", 0.0)
	var result: Variant = action.execute()

	assert_true(result == null, "类型不兼容的移动动作不应创建 Tween。")
	assert_eq(node.position, Vector2.ZERO, "类型不兼容时不应写入目标属性。")


func test_move_tween_action_rejects_missing_property() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var action: GFVisualAction = GFMoveTweenAction.new(node, Vector2.ONE, 0.0, ^"missing_position")
	var result: Variant = action.execute()

	assert_true(result == null, "缺失属性不应创建移动 Tween。")


func test_configured_tween_action_applies_zero_duration_steps_immediately() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _add_property_step_result_138: Variant = config.add_property_step(^"position", Vector2(8.0, 12.0), 0.0)
	var action: GFVisualAction = config.create_action(node)
	var result: Variant = action.execute()

	assert_true(result == null, "零时长配置化 Tween 应立即完成。")
	assert_eq(node.position, Vector2(8.0, 12.0), "零时长配置化 Tween 应写入目标属性。")


func test_configured_tween_action_waits_for_timed_steps() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _add_property_step_result_151: Variant = config.add_property_step(^"position", Vector2(16.0, 4.0), 0.01)
	var action: GFVisualAction = config.create_action(node)
	var result: Variant = action.execute()

	assert_true(result is Signal, "带时长的配置化 Tween 应返回完成 Signal。")
	var completion: Signal = _signal_from_result(result)
	assert_eq(String(completion.get_name()), "_action_completed", "配置化 Tween 应通过动作自身完成信号释放等待者。")
	await action.await_result_safely(result)
	assert_almost_eq(node.position.x, 16.0, 0.01, "配置化 Tween 完成后应写入 x。")
	assert_almost_eq(node.position.y, 4.0, 0.01, "配置化 Tween 完成后应写入 y。")


func test_configured_tween_action_finish_handles_infinite_loop() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.loop_count = 0
	var _add_property_step_result_169: Variant = config.add_property_step(^"position", Vector2(16.0, 4.0), 0.1)
	var action: GFVisualAction = config.create_action(node)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.finish()
	await get_tree().process_frame

	assert_true(completed[0], "无限循环 Tween 的 finish 不应卡住等待。")


func test_configured_tween_action_cancel_releases_waiters() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _add_property_step_result_190: Variant = config.add_property_step(^"position", Vector2(32.0, 0.0), 1.0)
	var action: GFVisualAction = config.create_action(node)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.cancel()
	await get_tree().process_frame

	assert_true(completed[0], "取消配置化 Tween 时等待者应被释放。")


func test_configured_tween_action_emits_step_markers() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = config.add_property_step(^"position", Vector2(4.0, 0.0), 0.01)
	step.marker_id = &"arrived"
	var action: GFConfiguredTweenAction = _configured_tween_action(config.create_action(node))
	var markers: Array[StringName] = []
	var _connect_result_215: Variant = action.marker_reached.connect(func(marker_id: StringName, _step_index: int, _target: Object) -> void:
		markers.append(marker_id)
	)
	var result: Variant = action.execute()
	await action.await_result_safely(result)

	assert_eq(markers, [&"arrived"], "带 marker_id 的步骤完成后应发出 marker_reached。")


func test_configured_tween_action_can_restore_initial_values_on_cancel() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	node.position = Vector2(2.0, 3.0)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.restore_initial_values_on_cancel = true
	var _add_property_step_result_231: Variant = config.add_property_step(^"position", Vector2(40.0, 0.0), 1.0)
	var action: GFVisualAction = config.create_action(node)
	var result: Variant = action.execute()
	await get_tree().process_frame
	action.cancel()
	await get_tree().process_frame

	assert_true(result is Signal, "带时长步骤应创建可等待动作。")
	assert_eq(node.position, Vector2(2.0, 3.0), "取消时应恢复播放前捕获的属性值。")


func test_tween_action_config_reports_invalid_steps() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _add_property_step_result_246: Variant = config.add_property_step(^"missing_property", Vector2.ONE, 0.0)

	var report: GFValidationReport = config.get_validation_report(node)

	assert_false(report.is_ok(), "配置校验应复用 GFValidationReport 表达无效步骤。")
	assert_eq(report.get_error_count(), 1, "缺失属性应产生一个错误。")


func test_gf_action_factories_create_common_actions() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	node.position = Vector2(3.0, 4.0)
	node.modulate = Color(1.0, 1.0, 1.0, 0.5)
	node.material = _make_shader_material()

	var move_action: GFVisualAction = GFAction.move_by(node, Vector2(2.0, 5.0), 0.0)
	assert_true(move_action is GFConfiguredTweenAction, "move_by 应创建配置化相对 Tween。")
	assert_true(move_action.execute() == null)
	assert_eq(node.position, Vector2(5.0, 9.0), "零时长 move_by 应立即应用相对偏移。")

	var fade_action: GFVisualAction = GFAction.fade_by(node, 0.25, 0.0)
	fade_action.execute()
	assert_almost_eq(node.modulate.a, 0.75, 0.001, "fade_by 应创建相对透明度 Tween。")

	var hide_action: GFVisualAction = GFAction.hide(node)
	hide_action.execute()
	assert_false(node.visible, "hide 工厂应创建可见性动作。")

	var show_action: GFVisualAction = GFAction.show(node)
	show_action.execute()
	assert_true(node.visible, "show 工厂应创建可见性动作。")

	var shader_action: GFVisualAction = GFAction.shader_parameter(node, &"strength", 0.6, 0.0)
	shader_action.execute()
	assert_almost_eq(_get_shader_strength(node.material), 0.6, 0.001, "shader_parameter 工厂应创建 Shader 参数动作。")

	var call_state: Dictionary = { "count": 0 }
	var call_action: GFVisualAction = GFAction.callback(func(amount: int) -> void:
		call_state["count"] = GFVariantData.get_option_int(call_state, "count") + amount
	, [3])
	call_action.execute()
	assert_eq(GFVariantData.get_option_int(call_state, "count"), 3, "callback 动作应执行回调并传递参数。")

	var group: GFVisualActionGroup = GFAction.sequence([call_action])
	assert_false(group.is_parallel, "sequence 工厂应创建顺序动作组。")
	assert_true(GFAction.parallel([call_action]).is_parallel, "parallel 工厂应创建并行动作组。")
	var race_group: GFVisualActionGroup = GFAction.race([call_action], false)
	assert_eq(
		race_group.parallel_completion_policy,
		GFVisualActionGroup.ParallelCompletionPolicy.FIRST_COMPLETED,
		"race 工厂应创建任一子动作完成即结束的并行动作组。"
	)
	assert_false(race_group.cancel_remaining_on_first_completed, "race 工厂应透传剩余动作取消策略。")


func test_gf_action_remove_node_queues_target_for_free() -> void:
	var node: Node = Node.new()
	add_child(node)

	var action: GFVisualAction = GFAction.remove_node(node)
	action.execute()

	assert_true(node.is_queued_for_deletion(), "remove_node 应把目标节点加入释放队列。")


func test_wait_action_can_finish_early() -> void:
	var action: GFWaitAction = GFAction.wait(1.0, self)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.finish()
	await get_tree().process_frame

	assert_true(completed[0], "finish 应提前完成等待动作。")


func test_wait_action_cancel_suppresses_wait_completed() -> void:
	var action: GFWaitAction = GFAction.wait(1.0, self)
	var result: Variant = action.execute()
	var completed: Array[bool] = []
	var completion: Signal = _signal_from_result(result)
	var _connect_result_327: Variant = completion.connect(func() -> void:
		completed.append(true)
	)

	await get_tree().process_frame
	action.cancel()
	await get_tree().create_timer(0.03).timeout

	assert_true(completed.is_empty(), "取消等待动作不应发出等待完成信号。")


func test_action_group_cancel_releases_sequence_waiters() -> void:
	var group: GFVisualAction = GFAction.sequence([GFAction.wait(1.0, self)])
	var result: Variant = group.execute()
	var completed: Array[bool] = [false]
	var wait_for_group: Callable = func() -> void:
		await group.await_result_safely(result)
		completed[0] = true

	wait_for_group.call()
	await get_tree().process_frame
	group.cancel()
	await get_tree().process_frame

	assert_true(completed[0], "取消顺序动作组时等待者应被释放。")


func test_action_group_cancel_releases_parallel_waiters() -> void:
	var group: GFVisualAction = GFAction.parallel([
		GFAction.wait(1.0, self),
		GFAction.wait(1.0, self),
	])
	var result: Variant = group.execute()
	var completed: Array[bool] = [false]
	var wait_for_group: Callable = func() -> void:
		await group.await_result_safely(result)
		completed[0] = true

	wait_for_group.call()
	await get_tree().process_frame
	group.cancel()
	await get_tree().process_frame

	assert_true(completed[0], "取消并行动作组时等待者应被释放。")


func test_parallel_action_group_waits_for_all_children_by_default() -> void:
	var first: ManualSignalAction = ManualSignalAction.new()
	var second: ManualSignalAction = ManualSignalAction.new()
	var group: GFVisualAction = GFAction.parallel([first, second])
	var result: Variant = group.execute()
	var completed: Array[bool] = [false]
	var wait_for_group: Callable = func() -> void:
		await group.await_result_safely(result)
		completed[0] = true

	wait_for_group.call()
	await get_tree().process_frame
	first.complete()
	await get_tree().process_frame

	assert_false(completed[0], "默认并行动作组应等待全部子动作。")

	second.complete()
	await get_tree().process_frame

	assert_true(completed[0], "全部子动作完成后，并行动作组才应释放等待者。")


func test_action_race_completes_on_first_child_and_cancels_remaining() -> void:
	var slow: ManualSignalAction = ManualSignalAction.new()
	var fast: ManualSignalAction = ManualSignalAction.new()
	var group: GFVisualAction = GFAction.race([slow, fast])
	var result: Variant = group.execute()
	var completed: Array[bool] = [false]
	var wait_for_group: Callable = func() -> void:
		await group.await_result_safely(result)
		completed[0] = true

	wait_for_group.call()
	await get_tree().process_frame
	fast.complete()
	await get_tree().process_frame

	assert_true(completed[0], "race 动作组应在首个子动作完成后释放等待者。")
	assert_true(slow.cancelled, "默认 race 应取消仍在等待的子动作。")
	assert_false(fast.cancelled, "已完成的子动作不应被重复取消。")


func test_action_race_can_keep_remaining_children_running() -> void:
	var slow: ManualSignalAction = ManualSignalAction.new()
	var fast: ManualSignalAction = ManualSignalAction.new()
	var group: GFVisualAction = GFAction.race([slow, fast], false)
	var result: Variant = group.execute()
	var completed: Array[bool] = [false]
	var wait_for_group: Callable = func() -> void:
		await group.await_result_safely(result)
		completed[0] = true

	wait_for_group.call()
	await get_tree().process_frame
	fast.complete()
	await get_tree().process_frame

	assert_true(completed[0], "race 动作组应仍在首个子动作完成后结束。")
	assert_false(slow.cancelled, "关闭取消策略时，race 不应替调用方取消剩余动作。")


func test_repeat_action_creates_fresh_action_each_iteration() -> void:
	var order: Array[int] = []
	var repeat: GFRepeatAction = GFAction.repeat(func() -> GFVisualAction:
		return GFAction.callback(func() -> void:
			order.append(order.size())
		)
	, 3)
	var result: Variant = repeat.execute()
	await repeat.await_result_safely(result)

	assert_eq(order, [0, 1, 2], "repeat 应按次数执行工厂创建的动作。")


func test_tween_action_step_apply_instant_relative_vector2() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	node.position = Vector2(10.0, 20.0)
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = ^"position"
	step.target_value = Vector2(1.0, 2.0)
	step.as_relative = true
	step.apply_instant(node)
	assert_eq(node.position, Vector2(11.0, 22.0), "相对 Vector2 应与当前位置相加。")


func test_tween_action_step_apply_instant_relative_rotation_scalar() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	node.rotation = 1.0
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = ^"rotation"
	step.target_value = 0.5
	step.as_relative = true
	step.apply_instant(node)
	assert_almost_eq(node.rotation, 1.5, 0.0001, "相对浮点属性应与当前值相加。")


func test_tween_action_step_duplicate_step_preserves_exported_fields() -> void:
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = ^"modulate"
	step.target_value = Color.RED
	step.duration = 0.5
	step.delay = 0.1
	step.as_relative = true
	step.parallel = true
	step.transition_type = Tween.TRANS_LINEAR
	step.ease_type = Tween.EASE_IN_OUT
	var dup: GFTweenActionStep = step.duplicate_step()
	var duplicated_target: Variant = dup.target_value
	assert_ne(dup, step, "duplicate_step 应创建新 Resource。")
	assert_eq(dup.property_name, step.property_name)
	assert_true(duplicated_target is Color, "duplicate_step 应保留目标值类型。")
	if duplicated_target is Color:
		var target_color: Color = duplicated_target
		assert_eq(target_color, Color.RED, "duplicate_step 应保留目标值。")
	assert_eq(dup.duration, 0.5)
	assert_eq(dup.delay, 0.1)
	assert_true(dup.as_relative)
	assert_true(dup.parallel)
	assert_eq(dup.transition_type, Tween.TRANS_LINEAR)
	assert_eq(dup.ease_type, Tween.EASE_IN_OUT)


func test_tween_action_step_rejects_relative_type_mismatch() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = ^"position"
	step.target_value = 5
	step.as_relative = true
	assert_false(step.can_apply_to(node), "position 为 Vector2 时不应与标量 target 做相对相加。")
	assert_true(
		step.get_validation_error(node).contains("Relative"),
		"校验错误应提示相对值类型不兼容。"
	)


func test_tween_action_step_append_to_tween_returns_null_for_null_tween() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = ^"position"
	step.target_value = Vector2.ZERO
	assert_true(step.append_to_tween(null, node) == null, "Tween 为 null 时应安全返回 null。")


func test_flash_action_restores_modulate() -> void:
	var item: ColorRect = ColorRect.new()
	item.modulate = Color(0.2, 0.4, 0.6)
	add_child_autofree(item)

	var action: GFVisualAction = GFFlashAction.new(item, Color.RED, 0.01)
	var result: Variant = action.execute()

	assert_true(result is Signal, "闪色动作应返回 Tween 完成信号。")
	var completion: Signal = _signal_from_result(result)
	assert_eq(String(completion.get_name()), "_action_completed", "闪色动作应通过动作自身完成信号释放等待者。")
	await action.await_result_safely(result)

	assert_eq(item.modulate, Color(0.2, 0.4, 0.6), "闪色动作完成后应恢复原始颜色。")


func test_flash_action_rejects_non_color_property() -> void:
	var item: ColorRect = ColorRect.new()
	add_child_autofree(item)

	var action: GFVisualAction = GFFlashAction.new(item, Color.RED, 0.01, ^"visible")
	var result: Variant = action.execute()

	assert_true(result == null, "非 Color 属性不应创建闪色 Tween。")
	assert_true(item.visible, "非 Color 属性不应被闪色动作改写。")


func test_flash_action_rejects_missing_property() -> void:
	var item: ColorRect = ColorRect.new()
	add_child_autofree(item)

	var action: GFVisualAction = GFFlashAction.new(item, Color.RED, 0.01, ^"missing_color")
	var result: Variant = action.execute()

	assert_true(result == null, "缺失属性不应创建闪色 Tween。")


func test_flash_action_cancel_releases_waiters() -> void:
	var item: ColorRect = ColorRect.new()
	add_child_autofree(item)

	var action: GFVisualAction = GFFlashAction.new(item, Color.RED, 1.0)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.cancel()
	await get_tree().process_frame

	assert_true(completed[0], "取消闪色动作时等待者应被释放。")


func test_shader_parameter_action_sets_value_immediately() -> void:
	var item: ColorRect = ColorRect.new()
	item.material = _make_shader_material()
	add_child_autofree(item)

	var action: GFVisualAction = GFShaderParameterAction.new(item, &"strength", 0.75, 0.0)
	var result: Variant = action.execute()

	assert_true(result == null, "零时长 Shader 参数动作应立即完成。")
	assert_almost_eq(_get_shader_strength(item.material), 0.75, 0.001, "零时长 Shader 参数动作应写入参数。")


func test_shader_parameter_action_waits_for_tween() -> void:
	var item: ColorRect = ColorRect.new()
	item.material = _make_shader_material()
	add_child_autofree(item)

	var action: GFVisualAction = GFShaderParameterAction.new(item, &"strength", 1.0, 0.01)
	var result: Variant = action.execute()

	assert_true(result is Signal, "带时长 Shader 参数动作应返回完成 Signal。")
	await action.await_result_safely(result)

	assert_almost_eq(_get_shader_strength(item.material), 1.0, 0.01, "Shader 参数 Tween 完成后应到达目标值。")


func test_shader_parameter_action_can_tween_direct_material_with_host() -> void:
	var material: ShaderMaterial = _make_shader_material()
	var action: GFVisualAction = GFShaderParameterAction.new(material, &"strength", 0.5, 0.01, self)
	var result: Variant = action.execute()

	assert_true(result is Signal, "直接操作 ShaderMaterial 时可通过 host_node 创建 Tween。")
	await action.await_result_safely(result)

	assert_almost_eq(_get_shader_strength(material), 0.5, 0.01, "直接材质 Tween 应写入目标参数。")


func test_shader_parameter_action_duplicates_owner_material_when_requested() -> void:
	var shared_material: ShaderMaterial = _make_shader_material()
	var item_a: ColorRect = ColorRect.new()
	var item_b: ColorRect = ColorRect.new()
	item_a.material = shared_material
	item_b.material = shared_material
	add_child_autofree(item_a)
	add_child_autofree(item_b)

	var action: GFVisualAction = GFAction.shader_parameter(item_a, &"strength", 0.9, 0.0, {
		"duplicate_material_on_execute": true,
	})
	var result: Variant = action.execute()

	assert_true(result == null, "零时长 Shader 参数动作应立即完成。")
	assert_ne(item_a.material, item_b.material, "复制材质后不应继续修改共享材质资源。")
	assert_almost_eq(_get_shader_strength(item_a.material), 0.9, 0.001, "目标节点应使用复制后的材质参数。")
	assert_almost_eq(_get_shader_strength(item_b.material), 0.0, 0.001, "共享材质的其他使用者不应被改写。")


func test_shader_parameter_action_cancel_releases_waiters_and_restores() -> void:
	var item: ColorRect = ColorRect.new()
	item.material = _make_shader_material(0.25)
	add_child_autofree(item)

	var action: GFShaderParameterAction = GFShaderParameterAction.new(item, &"strength", 1.0, 1.0)
	action.restore_initial_value_on_cancel = true
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.cancel()
	await get_tree().process_frame

	assert_true(completed[0], "取消 Shader 参数动作时等待者应被释放。")
	assert_almost_eq(_get_shader_strength(item.material), 0.25, 0.001, "取消时应按配置恢复初始参数值。")


func test_audio_action_is_fire_and_forget() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch

	var audio: TestAudioUtility = TestAudioUtility.new()
	await Gf.register_utility(audio)
	await Gf.set_architecture(arch)
	await get_tree().process_frame

	var action: GFVisualAction = GFAudioAction.new("res://audio/hit.wav")
	var result: Variant = action.execute()

	assert_eq(action.completion_mode, GFVisualAction.CompletionMode.FIRE_AND_FORGET, "音效动作默认不阻塞队列。")
	assert_true(result == null, "音效动作应立即完成。")
	assert_eq(audio.played_paths, ["res://audio/hit.wav"], "音效动作应委托给 GFAudioUtility。")


func test_audio_action_can_play_bank_clip() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch

	var audio: TestAudioUtility = TestAudioUtility.new()
	await Gf.register_utility(audio)
	await Gf.set_architecture(arch)
	await get_tree().process_frame

	var action: GFAudioAction = GFAudioAction.new()
	action.bank = GFAudioBank.new()
	action.clip_id = &"ui_accept"
	var result: Variant = action.execute()

	assert_true(result == null, "音频集合动作也应立即完成。")
	assert_eq(audio.played_clip_ids, [&"ui_accept"], "音效动作应按 clip_id 委托给 GFAudioUtility。")
