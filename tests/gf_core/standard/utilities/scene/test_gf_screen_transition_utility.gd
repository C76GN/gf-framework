extends GutTest


var _transition: GFScreenTransitionUtility


func before_each() -> void:
	_transition = GFScreenTransitionUtility.new()
	_transition.init()
	await get_tree().process_frame


func test_effect_samples_weight_and_alpha() -> void:
	var effect: GFScreenTransitionEffect = GFScreenTransitionEffect.new()
	effect.duration_seconds = 2.0
	effect.from_alpha = 0.25
	effect.to_alpha = 0.75
	effect.easing_mode = GFScreenTransitionEffect.EasingMode.LINEAR

	assert_almost_eq(effect.sample_weight(1.0), 0.5, 0.001, "线性转场中点权重应为 0.5。")
	assert_almost_eq(effect.sample_alpha(0.5), 0.5, 0.001, "透明度应按权重插值。")


func test_fade_out_advances_and_invokes_callback() -> void:
	var state: TransitionState = TransitionState.new()

	assert_eq(_transition.fade_out(1.0, Color.RED, func() -> void:
		state.finished = true
	), OK, "淡出转场应能启动。")
	assert_true(_transition.is_transition_active(), "启动后应存在活动转场。")

	_transition.tick(0.5)

	assert_almost_eq(_transition.get_overlay_alpha(), 0.5, 0.001, "默认 smoothstep 在中点应输出 0.5。")

	assert_true(_transition.complete_transition(), "活动转场应能被立即完成。")
	assert_false(_transition.is_transition_active(), "完成后不应继续保持活动状态。")
	assert_true(state.finished, "完成转场应调用完成回调。")
	assert_almost_eq(_transition.get_overlay_alpha(), 1.0, 0.001, "完成淡出后覆盖层应保持不透明。")


func test_cancel_transition_does_not_call_finished_callback() -> void:
	var state: TransitionState = TransitionState.new()

	assert_eq(_transition.fade_in(1.0, Color.BLACK, func() -> void:
		state.finished = true
	), OK, "淡入转场应能启动。")

	assert_true(_transition.cancel_transition(), "活动转场应能取消。")
	assert_false(_transition.is_transition_active(), "取消后不应继续保持活动状态。")
	assert_false(state.finished, "取消转场不应调用完成回调。")


func test_manual_overlay_alpha_and_hide() -> void:
	_transition.set_overlay_alpha(0.4, Color.BLUE)

	var snapshot: Dictionary = _transition.get_debug_snapshot()
	assert_true(GFVariantData.get_option_bool(snapshot, "overlay_visible"), "手动设置透明度后覆盖层应可见。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "overlay_alpha"), 0.4, 0.001, "快照应记录覆盖层透明度。")

	_transition.hide_overlay()
	snapshot = _transition.get_debug_snapshot()
	assert_false(GFVariantData.get_option_bool(snapshot, "overlay_visible"), "hide_overlay 应隐藏覆盖层。")


func test_dispose_leaves_overlay_attached_during_autoload_tree_exit() -> void:
	var overlay_layer: CanvasLayer = get_tree().root.get_node_or_null("GFScreenTransition") as CanvasLayer
	assert_not_null(overlay_layer, "初始化后应创建屏幕转场覆盖层。")
	GFAutoload.begin_tree_exit_scope()

	_transition.dispose()
	_transition = null

	assert_not_null(overlay_layer.get_parent(), "AutoLoad 退出时不应重入修改转场覆盖层的父节点。")

	GFAutoload.end_tree_exit_scope()
	await get_tree().process_frame
	assert_false(is_instance_valid(overlay_layer), "退出阶段登记 queue_free 后仍应完成释放。")


func after_each() -> void:
	GFAutoload.reset_tree_exit_state()
	if _transition != null:
		_transition.dispose()
	await get_tree().process_frame


# --- 辅助类 ---

class TransitionState:
	extends RefCounted

	var finished: bool = false
