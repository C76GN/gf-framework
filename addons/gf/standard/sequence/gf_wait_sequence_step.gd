## GFWaitSequenceStep: 通用等待步骤。
##
## 用于在 `GFCommandSequence` 中插入时间间隔。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFWaitSequenceStep
extends GFSequenceStep


# --- 导出变量 ---

## 等待时长，单位秒。负值会规范化为 0；非有限赋值会被拒绝并保留上次有效值。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var duration: float = 0.0:
	set(value):
		if not is_finite(value):
			push_warning("[GFWaitSequenceStep] 等待时长必须是有限数值。")
			return
		duration = maxf(value, 0.0)

## 是否受 Engine.time_scale 影响。
## [br]
## @api public
@export var respect_engine_time_scale: bool = true


# --- 私有变量 ---

var _active_timer_refs_by_context: Dictionary = {}


# --- 公共方法 ---

## 执行等待步骤。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 序列上下文。
## [br]
## @return 等待用 Signal，时长小于等于 0 时返回 null。
## [br]
## @schema return: Variant, null or Signal.
func execute(context: GFSequenceContext) -> Variant:
	if not is_finite(duration) or duration <= 0.0:
		return null

	var tree: SceneTree = _variant_to_scene_tree(Engine.get_main_loop())
	if tree == null:
		return null

	var timer: SceneTreeTimer = tree.create_timer(
		duration,
		true,
		false,
		not respect_engine_time_scale
	)
	var context_id: int = _get_context_id(context)
	var timer_refs: Array[WeakRef] = _get_active_timer_refs(context_id)
	timer_refs.append(weakref(timer))
	_active_timer_refs_by_context[context_id] = timer_refs
	var _connect_result: Error = timer.timeout.connect(
		_on_wait_timer_timeout.bind(context_id, timer.get_instance_id()),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return timer.timeout


## 取消当前上下文由该步骤创建的全部未完成计时器。
## [br]
## 计时器会收敛到下一帧终态；序列自己的 Signal 等待会独立停止。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param context: 序列上下文。
func cancel(context: GFSequenceContext) -> void:
	var context_id: int = _get_context_id(context)
	var timer_refs: Array[WeakRef] = _get_active_timer_refs(context_id)
	var _had_context_timers: bool = _active_timer_refs_by_context.erase(context_id)
	for timer_ref: WeakRef in timer_refs:
		var timer_value: Variant = timer_ref.get_ref()
		if timer_value is SceneTreeTimer:
			var timer: SceneTreeTimer = timer_value
			if is_instance_valid(timer):
				timer.time_left = 0.0


# --- 私有/辅助方法 ---

func _get_context_id(context: GFSequenceContext) -> int:
	return context.get_instance_id() if context != null else 0


func _get_active_timer_refs(context_id: int) -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	var refs_value: Variant = _active_timer_refs_by_context.get(context_id)
	if not (refs_value is Array):
		return result
	for ref_value: Variant in refs_value:
		if ref_value is WeakRef:
			var timer_ref: WeakRef = ref_value
			result.append(timer_ref)
	return result


func _on_wait_timer_timeout(context_id: int, timer_id: int) -> void:
	var retained_refs: Array[WeakRef] = []
	for timer_ref: WeakRef in _get_active_timer_refs(context_id):
		var timer_value: Variant = timer_ref.get_ref()
		if not (timer_value is Object):
			continue
		var timer: Object = timer_value
		if not is_instance_valid(timer):
			continue
		if timer.get_instance_id() != timer_id:
			retained_refs.append(timer_ref)
	if retained_refs.is_empty():
		var _removed_context: bool = _active_timer_refs_by_context.erase(context_id)
	else:
		_active_timer_refs_by_context[context_id] = retained_refs

func _variant_to_scene_tree(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null
