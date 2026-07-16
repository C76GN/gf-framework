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
	var paused: bool = false
	var resumed: bool = false

	func execute() -> Variant:
		executed = true
		return completed

	func cancel() -> void:
		cancelled = true

	func pause() -> void:
		paused = true

	func resume() -> void:
		resumed = true

	func complete() -> void:
		completed.emit()


class ProbeAction:
	extends GFVisualAction

	var executed: bool = false
	var cancel_count: int = 0
	var pause_count: int = 0
	var resume_count: int = 0
	var finish_count: int = 0

	func execute() -> Variant:
		executed = true
		return null

	func cancel() -> void:
		cancel_count += 1

	func pause() -> void:
		pause_count += 1

	func resume() -> void:
		resume_count += 1

	func finish() -> void:
		finish_count += 1


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


func test_move_tween_action_finish_sets_final_position_and_releases_waiters() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var action: GFVisualAction = GFMoveTweenAction.new(node, Vector2(20.0, 0.0), 1.0)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.finish()
	await get_tree().process_frame

	assert_true(completed[0], "finish 应释放移动 Tween 等待者。")
	assert_eq(node.position, Vector2(20.0, 0.0), "finish 应直接写入最终位置。")


func test_move_tween_action_rejects_detached_target_for_timed_tween() -> void:
	var node: Node2D = Node2D.new()
	var action: GFVisualAction = GFMoveTweenAction.new(node, Vector2(20.0, 0.0), 1.0)

	var result: Variant = action.execute()

	assert_true(result == null, "离树目标不应创建移动 Tween。")
	assert_eq(node.position, Vector2.ZERO, "离树目标不应被定时移动动作改写。")
	assert_push_warning("[GFMoveTweenAction] 目标节点未进入场景树，无法创建 Tween。")
	node.free()


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


func test_configured_tween_action_finish_applies_final_values_and_releases_waiters() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)

	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _add_property_step_result: Variant = config.add_property_step(^"position", Vector2(18.0, 6.0), 1.0)
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

	assert_true(completed[0], "finish 应释放配置化 Tween 等待者。")
	assert_eq(node.position, Vector2(18.0, 6.0), "finish 应直接应用配置化 Tween 最终值。")


func test_configured_tween_action_rejects_detached_target_for_timed_steps() -> void:
	var node: Node2D = Node2D.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _add_property_step_result: Variant = config.add_property_step(^"position", Vector2(18.0, 6.0), 1.0)
	var action: GFVisualAction = config.create_action(node)

	var result: Variant = action.execute()

	assert_true(result == null, "离树目标不应创建配置化 Tween。")
	assert_eq(node.position, Vector2.ZERO, "离树目标不应被定时配置化 Tween 改写。")
	assert_push_warning("[GFConfiguredTweenAction] 缺少有效 Tween 宿主节点。")
	node.free()


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


func test_sequence_group_cancel_does_not_touch_unstarted_children() -> void:
	var waiting_action: ManualSignalAction = ManualSignalAction.new()
	var pending_action: ProbeAction = ProbeAction.new()
	var group: GFVisualActionGroup = GFAction.sequence([waiting_action, pending_action])
	var result: Variant = group.execute()
	var completed: Array[bool] = [false]
	var wait_for_group: Callable = func() -> void:
		await group.await_result_safely(result)
		completed[0] = true

	wait_for_group.call()
	await get_tree().process_frame
	group.cancel()
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "取消顺序组应只取消当前运行子动作。")
	assert_false(pending_action.executed, "未启动子动作不应被执行。")
	assert_eq(pending_action.cancel_count, 0, "未启动子动作不应收到 cancel。")
	assert_true(completed[0], "取消顺序组时等待者应释放。")


func test_sequence_group_pause_blocks_next_child_until_resume() -> void:
	var waiting_action: ManualSignalAction = ManualSignalAction.new()
	var pending_action: ProbeAction = ProbeAction.new()
	var group: GFVisualActionGroup = GFAction.sequence([waiting_action, pending_action])
	var _result: Variant = group.execute()

	await get_tree().process_frame
	group.pause()
	waiting_action.complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(waiting_action.paused, "暂停顺序组应暂停当前子动作。")
	assert_false(pending_action.executed, "顺序组暂停期间不应启动下一子动作。")

	group.resume()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(waiting_action.resumed, "恢复顺序组应恢复当前子动作。")
	assert_true(pending_action.executed, "恢复后应继续启动后续子动作。")


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


func test_sequence_group_reexecute_cancels_previous_run_and_releases_waiter() -> void:
	var first: ManualSignalAction = ManualSignalAction.new()
	var second: ManualSignalAction = ManualSignalAction.new()
	var group: GFVisualActionGroup = GFAction.sequence([first, second])
	var first_result: Variant = group.execute()
	var first_completed: Array[bool] = [false]
	var wait_for_first: Callable = func() -> void:
		await group.await_result_safely(first_result)
		first_completed[0] = true

	wait_for_first.call()
	await get_tree().process_frame
	var second_result: Variant = group.execute()
	await get_tree().process_frame

	assert_true(first.cancelled, "运行中重复 execute 应取消上一轮正在等待的子动作。")
	assert_true(first_completed[0], "运行中重复 execute 应释放上一轮等待者。")
	assert_true(second_result is Signal, "新一轮 execute 仍应返回可等待信号。")


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


func test_repeat_action_reexecute_cancels_previous_active_action() -> void:
	var actions: Array[ManualSignalAction] = []
	var repeat: GFRepeatAction = GFAction.repeat(func() -> GFVisualAction:
		var action: ManualSignalAction = ManualSignalAction.new()
		actions.append(action)
		return action
	, 2)
	var first_result: Variant = repeat.execute()
	var first_completed: Array[bool] = [false]
	var wait_for_first: Callable = func() -> void:
		await repeat.await_result_safely(first_result)
		first_completed[0] = true

	wait_for_first.call()
	await get_tree().process_frame
	var second_result: Variant = repeat.execute()
	await get_tree().process_frame

	assert_eq(actions.size(), 2, "第二轮 repeat 应创建新的当前动作。")
	assert_true(actions[0].cancelled, "运行中重复 execute 应取消上一轮当前动作。")
	assert_true(first_completed[0], "运行中重复 execute 应释放上一轮等待者。")
	assert_true(second_result is Signal, "第二轮 repeat 仍应返回完成信号。")


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


func test_tween_action_step_duplicate_step_deep_copies_collection_target_value() -> void:
	var step: GFTweenActionStep = GFTweenActionStep.new()
	var target_payload: Dictionary = {
		"points": [Vector2.ONE],
	}
	step.target_value = target_payload

	var duplicate_step: GFTweenActionStep = step.duplicate_step()
	var duplicate_payload: Dictionary = GFVariantData.as_dictionary(duplicate_step.target_value)
	var duplicate_points: Array = GFVariantData.as_array(GFVariantData.get_option_value(duplicate_payload, "points"))
	var original_points: Array = GFVariantData.as_array(GFVariantData.get_option_value(target_payload, "points"))
	original_points.append(Vector2.ZERO)

	assert_eq(duplicate_points.size(), 1, "duplicate_step 应深拷贝 Array/Dictionary target_value，避免配置污染。")


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


func test_flash_action_zero_duration_applies_flash_color_immediately() -> void:
	var item: ColorRect = ColorRect.new()
	item.modulate = Color(0.2, 0.4, 0.6)
	add_child_autofree(item)

	var action: GFVisualAction = GFFlashAction.new(item, Color.RED, 0.0)
	var result: Variant = action.execute()

	assert_true(result == null, "零时长闪色动作应立即完成。")
	assert_eq(item.modulate, Color.RED, "零时长闪色动作应立即写入闪色目标值。")


func test_flash_action_rejects_detached_target_for_timed_tween() -> void:
	var item: ColorRect = ColorRect.new()
	item.modulate = Color(0.2, 0.4, 0.6)
	var action: GFFlashAction = GFFlashAction.new(item, Color.RED, 1.0)

	var result: Variant = action.execute()

	assert_true(result == null, "离树目标不应创建 Flash Tween。")
	assert_eq(item.modulate, Color(0.2, 0.4, 0.6), "拒绝离树 Tween 时不应修改目标颜色。")
	assert_push_warning("[GFFlashAction] 带时长动作需要位于场景树内的目标。")
	item.free()


func test_action_time_fields_reject_non_finite_values() -> void:
	var item: ColorRect = ColorRect.new()
	add_child_autofree(item)
	var flash: GFFlashAction = GFFlashAction.new(item, Color.RED, INF)
	var wait_action: GFWaitAction = GFWaitAction.new(INF, self)
	var visual: GFVisualAction = GFVisualAction.new()
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.duration = INF
	step.delay = NAN
	var _configured_visual: GFVisualAction = visual.with_signal_timeout(INF)

	assert_eq(flash.duration, 0.0, "非有限 Flash 时长应收敛为安全的瞬时动作。")
	assert_eq(wait_action.seconds, 0.0, "非有限等待时长不应创建永久等待。")
	assert_eq(step.duration, 0.0, "Tween step 不应保留无限 duration。")
	assert_eq(step.delay, 0.0, "Tween step 不应保留 NaN delay。")
	assert_eq(visual.signal_timeout_seconds, 30.0, "非法 timeout 不应覆盖现有有效超时。")


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
	item.modulate = Color(0.2, 0.4, 0.6)
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
	assert_eq(item.modulate, Color(0.2, 0.4, 0.6), "取消闪色动作时应恢复原始颜色。")


func test_flash_action_pause_freezes_tween_until_resume() -> void:
	var item: ColorRect = ColorRect.new()
	item.modulate = Color(0.2, 0.4, 0.6)
	add_child_autofree(item)

	var action: GFFlashAction = GFFlashAction.new(item, Color.RED, 0.2)
	var result: Variant = action.execute()
	await get_tree().process_frame

	action.pause()
	var paused_color: Color = item.modulate
	await get_tree().create_timer(0.05).timeout

	assert_eq(item.modulate, paused_color, "暂停期间闪色 Tween 不应继续推进。")

	action.resume()
	await action.await_result_safely(result)

	assert_eq(item.modulate, Color(0.2, 0.4, 0.6), "恢复并完成后应恢复原始颜色。")


func test_wait_action_host_node_exit_suppresses_completion() -> void:
	var host: Node = Node.new()
	add_child(host)
	var action: GFWaitAction = GFAction.wait(0.02, host)
	var result: Variant = action.execute()
	var completed: Array[bool] = []
	var completion: Signal = _signal_from_result(result)
	var _connect_result: Variant = completion.connect(func() -> void:
		completed.append(true)
	)

	host.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

	assert_true(completed.is_empty(), "host_node 离树后等待动作不应继续发出完成信号。")


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


func test_shader_parameter_action_finish_sets_final_value_and_releases_waiters() -> void:
	var item: ColorRect = ColorRect.new()
	item.material = _make_shader_material()
	add_child_autofree(item)

	var action: GFVisualAction = GFShaderParameterAction.new(item, &"strength", 1.0, 1.0)
	var result: Variant = action.execute()
	var completed: Array[bool] = [false]
	var wait_for_action: Callable = func() -> void:
		await action.await_result_safely(result)
		completed[0] = true

	wait_for_action.call()
	await get_tree().process_frame
	action.finish()
	await get_tree().process_frame

	assert_true(completed[0], "finish 应释放 Shader 参数 Tween 等待者。")
	assert_almost_eq(_get_shader_strength(item.material), 1.0, 0.001, "finish 应直接写入 Shader 参数最终值。")


func test_shader_parameter_action_rejects_detached_target_for_timed_tween() -> void:
	var item: ColorRect = ColorRect.new()
	item.material = _make_shader_material()
	var action: GFVisualAction = GFShaderParameterAction.new(item, &"strength", 1.0, 1.0)

	var result: Variant = action.execute()

	assert_true(result == null, "离树目标不应创建 Shader 参数 Tween。")
	assert_almost_eq(_get_shader_strength(item.material), 0.0, 0.001, "离树目标不应被定时 Shader 参数动作改写。")
	assert_push_warning("[GFShaderParameterAction] 缺少有效 Tween 宿主节点。")
	item.free()


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


func test_shader_parameter_action_validates_before_duplicating_material() -> void:
	var shared_material: ShaderMaterial = _make_shader_material()
	var item: ColorRect = ColorRect.new()
	item.material = shared_material
	add_child_autofree(item)
	var action: GFShaderParameterAction = GFShaderParameterAction.new(item, &"missing", 1.0, 0.0)
	action.duplicate_material_on_execute = true

	var result: Variant = action.execute()

	assert_true(result == null, "无效参数动作应同步拒绝。")
	assert_same(item.material, shared_material, "校验失败前不得复制并写回材质。")
	assert_push_warning("[GFShaderParameterAction] Shader 参数不存在：missing。")


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
