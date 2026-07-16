## GFScreenTransitionUtility: 通用屏幕覆盖式转场工具。
##
## 管理一个轻量 CanvasLayer + ColorRect 覆盖层，按 GFScreenTransitionEffect 推进颜色、
## 透明度和可选 shader progress。它不直接切换场景，项目可把它组合到任意流程中。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.23.0
class_name GFScreenTransitionUtility
extends GFUtility


# --- 信号 ---

## 转场开始后发出。
## [br]
## @api public
## [br]
## @param effect: 本次转场使用的效果配置副本。
signal transition_started(effect: GFScreenTransitionEffect)

## 转场推进时发出。
## [br]
## @api public
## [br]
## @param progress: 0 到 1 的转场权重。
## [br]
## @param alpha: 当前覆盖层透明度。
signal transition_progressed(progress: float, alpha: float)

## 转场正常完成后发出。
## [br]
## @api public
## [br]
## @param effect: 完成的效果配置副本。
signal transition_finished(effect: GFScreenTransitionEffect)

## 转场被取消后发出。
## [br]
## @api public
## [br]
## @param effect: 被取消的效果配置副本。
signal transition_cancelled(effect: GFScreenTransitionEffect)


# --- 私有变量 ---

var _overlay_layer: CanvasLayer
var _overlay_rect: ColorRect
var _active_effect: GFScreenTransitionEffect
var _finished_callback: Callable
var _elapsed_seconds: float = 0.0
var _transition_active: bool = false
var _overlay_generation: int = 0


# --- GF 生命周期方法 ---

## 初始化覆盖层节点。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	ignore_time_scale = true
	tick_enabled = true
	_ensure_overlay()


## 释放覆盖层节点并取消当前转场。
## [br]
## @api public
func dispose() -> void:
	_overlay_generation += 1
	var _cancel_transition_result_74: Variant = cancel_transition()
	_finished_callback = Callable()
	if is_instance_valid(_overlay_layer):
		var parent: Node = _overlay_layer.get_parent()
		if parent != null and not GFAutoload.is_tree_exit_in_progress():
			parent.remove_child(_overlay_layer)
		_overlay_layer.queue_free()
	_overlay_layer = null
	_overlay_rect = null


## 推进当前转场。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if not _transition_active or _active_effect == null:
		return

	_elapsed_seconds += maxf(delta, 0.0)
	var progress: float = _active_effect.sample_weight(_elapsed_seconds)
	_apply_effect_visuals(progress)
	transition_progressed.emit(progress, get_overlay_alpha())
	if progress >= 1.0:
		_finish_transition()


# --- 公共方法 ---

## 播放一个转场效果。若已有转场正在播放，会先取消旧转场。
## [br]
## @api public
## [br]
## @param effect: 转场效果配置；Utility 会复制后使用。
## [br]
## @param on_finished: 可选完成回调。
## [br]
## @return 启动结果。
func play(effect: GFScreenTransitionEffect, on_finished: Callable = Callable()) -> Error:
	if effect == null:
		return ERR_INVALID_PARAMETER

	if _transition_active:
		var _cancel_transition_result_118: Variant = cancel_transition()

	_ensure_overlay()
	if not is_instance_valid(_overlay_rect):
		return ERR_UNAVAILABLE

	_active_effect = effect.duplicate_effect()
	_finished_callback = on_finished
	_elapsed_seconds = 0.0
	_transition_active = true
	_apply_effect_visuals(0.0)
	_overlay_layer.visible = true
	transition_started.emit(_active_effect)
	if _active_effect.duration_seconds <= 0.0:
		_apply_effect_visuals(1.0)
		_finish_transition()
	return OK


## 播放淡出到不透明覆盖层的转场。
## [br]
## @api public
## [br]
## @param duration_seconds: 转场时长，单位秒。
## [br]
## @param color: 覆盖层颜色。
## [br]
## @param on_finished: 可选完成回调。
## [br]
## @return 启动结果。
func fade_out(
	duration_seconds: float = 0.25,
	color: Color = Color.BLACK,
	on_finished: Callable = Callable()
) -> Error:
	var effect: GFScreenTransitionEffect = GFScreenTransitionEffect.new()
	var _configure_result_154: Variant = effect.configure(duration_seconds, 0.0, 1.0, color)
	return play(effect, on_finished)


## 播放从不透明覆盖层淡入画面的转场。
## [br]
## @api public
## [br]
## @param duration_seconds: 转场时长，单位秒。
## [br]
## @param color: 覆盖层颜色。
## [br]
## @param on_finished: 可选完成回调。
## [br]
## @return 启动结果。
func fade_in(
	duration_seconds: float = 0.25,
	color: Color = Color.BLACK,
	on_finished: Callable = Callable()
) -> Error:
	var effect: GFScreenTransitionEffect = GFScreenTransitionEffect.new()
	var _configure_result_175: Variant = effect.configure(duration_seconds, 1.0, 0.0, color)
	return play(effect, on_finished)


## 手动设置覆盖层透明度，不会启动转场。
## [br]
## @api public
## [br]
## @param alpha: 覆盖层透明度。
## [br]
## @param color: 覆盖层颜色。
func set_overlay_alpha(alpha: float, color: Color = Color.BLACK) -> void:
	_ensure_overlay()
	if not is_instance_valid(_overlay_rect):
		return

	var next_color: Color = color
	next_color.a = clampf(alpha, 0.0, 1.0)
	_overlay_rect.material = null
	_overlay_rect.color = next_color
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_STOP as Control.MouseFilter
	_overlay_layer.visible = next_color.a > 0.0


## 隐藏覆盖层并清空临时材质。
## [br]
## @api public
func hide_overlay() -> void:
	if not is_instance_valid(_overlay_layer):
		return
	_overlay_layer.visible = false
	if is_instance_valid(_overlay_rect):
		_overlay_rect.material = null
		_overlay_rect.color.a = 0.0


## 检查是否有转场正在播放。
## [br]
## @api public
## [br]
## @return 正在播放时返回 true。
func is_transition_active() -> bool:
	return _transition_active


## 获取当前覆盖层透明度。
## [br]
## @api public
## [br]
## @return 当前透明度。
func get_overlay_alpha() -> float:
	if not is_instance_valid(_overlay_rect):
		return 0.0
	return _overlay_rect.color.a


## 立即完成当前转场。
## [br]
## @api public
## [br]
## @return 有活动转场并完成时返回 true。
func complete_transition() -> bool:
	if not _transition_active or _active_effect == null:
		return false
	_apply_effect_visuals(1.0)
	_finish_transition()
	return true


## 取消当前转场，不调用完成回调。
## [br]
## @api public
## [br]
## @return 有活动转场并取消时返回 true。
func cancel_transition() -> bool:
	if not _transition_active:
		return false

	var cancelled_effect: GFScreenTransitionEffect = _active_effect
	_transition_active = false
	_active_effect = null
	_finished_callback = Callable()
	_elapsed_seconds = 0.0
	if cancelled_effect != null:
		transition_cancelled.emit(cancelled_effect)
	return true


## 获取转场工具运行时快照。
## [br]
## @api public
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 overlay_created、overlay_visible、transition_active、elapsed_seconds、overlay_alpha 和 active_effect。
func get_debug_snapshot() -> Dictionary:
	return {
		"overlay_created": is_instance_valid(_overlay_layer) and is_instance_valid(_overlay_rect),
		"overlay_visible": _overlay_layer.visible if is_instance_valid(_overlay_layer) else false,
		"transition_active": _transition_active,
		"elapsed_seconds": _elapsed_seconds,
		"overlay_alpha": get_overlay_alpha(),
		"active_effect": _active_effect.to_dict() if _active_effect != null else {},
	}


# --- 私有/辅助方法 ---

func _ensure_overlay() -> void:
	if is_instance_valid(_overlay_layer) and is_instance_valid(_overlay_rect):
		return

	_overlay_generation += 1
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "GFScreenTransition"
	_overlay_layer.layer = 120
	_overlay_layer.visible = false
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "Overlay"
	_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_STOP as Control.MouseFilter
	_overlay_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay_layer.add_child(_overlay_rect)

	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		call_deferred("_add_overlay_if_current", _overlay_layer, _overlay_generation)


func _add_overlay_if_current(layer: CanvasLayer, generation: int) -> void:
	if generation != _overlay_generation or not is_instance_valid(layer):
		return
	if layer.get_parent() != null:
		return
	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		tree.root.add_child(layer)


func _apply_effect_visuals(progress: float) -> void:
	if _active_effect == null or not is_instance_valid(_overlay_rect):
		return

	var alpha: float = _active_effect.sample_alpha(progress)
	var next_color: Color = _active_effect.color
	next_color.a = alpha
	_overlay_layer.layer = _active_effect.layer
	_overlay_rect.mouse_filter = (
		Control.MOUSE_FILTER_STOP as Control.MouseFilter
		if _active_effect.block_input
		else Control.MOUSE_FILTER_IGNORE as Control.MouseFilter
	)
	_overlay_rect.color = next_color

	if _active_effect.shader_material != null:
		_overlay_rect.material = _active_effect.shader_material
		if _active_effect.progress_parameter != &"":
			_active_effect.shader_material.set_shader_parameter(_active_effect.progress_parameter, clampf(progress, 0.0, 1.0))
	else:
		_overlay_rect.material = null


func _finish_transition() -> void:
	var finished_effect: GFScreenTransitionEffect = _active_effect
	var callback: Callable = _finished_callback
	_transition_active = false
	_active_effect = null
	_finished_callback = Callable()
	_elapsed_seconds = 0.0
	if is_instance_valid(_overlay_layer):
		_overlay_layer.visible = get_overlay_alpha() > 0.0
	if finished_effect != null:
		transition_finished.emit(finished_effect)
	if callback.is_valid():
		callback.call()


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop
	return tree
