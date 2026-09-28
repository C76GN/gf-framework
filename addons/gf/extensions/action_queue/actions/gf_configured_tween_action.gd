## GFConfiguredTweenAction: 配置驱动的 Tween 动作，支持可选冻结时间轴与属性替换。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFConfiguredTweenAction
extends GFVisualAction


# --- 信号 ---

## 正向到达标记时发出；定位、倒放和立即完成不补发标记。
## [br]
## @api public
## [br]
## @since 3.9.0
## [br]
## @param marker_id: 标记标识。
## [br]
## @param step_index: 步骤索引。
## [br]
## @param target: 本次执行的缓动目标。
signal marker_reached(marker_id: StringName, step_index: int, target: Object)


# --- 常量 ---

## 原生 Tween finish 展开步骤与循环乘积允许执行的上限。
## [br]
## @api private
const _MAX_FINISH_STEPS: int = 4096


# --- 公共变量 ---

## 被缓动的目标对象。
## [br]
## @api public
## [br]
## @since 3.6.0
var target: Object

## Tween 配置；执行后修改不改变已捕获的时间轴。
## [br]
## @api public
## [br]
## @since 3.6.0
var config: GFTweenActionConfig

## 可选宿主节点，目标不是 Node 时必须提供。
## [br]
## @api public
## [br]
## @since 3.6.0
var host_node: Node

## 属性替换作用域；启用冻结时间轴，接管时旧动作保留当前姿态并完成。
## [br]
## @api public
## [br]
## @since unreleased
var replacement_scope: GFTweenReplacementScope = null


# --- 私有变量 ---

## 当前执行使用的原生 Tween 或受控时钟 Tween。
## [br]
## @api private
var _active_tween: Tween = null

## 当前 Tween.finished 信号连接。
## [br]
## @api private
var _finished_callback: Callable = Callable()

## 原生 Tween 当前使用的属性代理绑定。
## [br]
## @api private
var _bindings: Array[GFTweenPropertyBinding] = []

## 当前执行开始时捕获、可按策略恢复的属性值。
## [br]
## @api private
var _initial_values: Dictionary = {}

## 本次执行捕获的受控播放计划；原生播放时为空。
## [br]
## @api private
var _plan: GFTweenPlaybackPlan = null

## 本次执行使用的目标对象快照。
## [br]
## @api private
var _run_target: Object = null

## 本次执行创建 Tween 的有效宿主节点。
## [br]
## @api private
var _run_host: Node = null

## 本次执行使用的可选属性替换作用域。
## [br]
## @api private
var _run_scope: GFTweenReplacementScope = null

## 本次执行从替换作用域取得的属性写入租约。
## [br]
## @api private
var _lease: int = 0

## 标记作用域 claim 调用尚未返回。
## [br]
## @api private
var _claiming: bool = false

## 标记当前执行仍拥有写入资格。
## [br]
## @api private
var _run_active: bool = false

## 标记本代执行已退出但完成通知尚待发出。
## [br]
## @api private
var _pending_completion: bool = false

## 每次启动新执行递增，用于拒绝旧代回调。
## [br]
## @api private
var _generation: int = 0

## 每次 execute 请求递增，用于发现重入请求取代当前启动。
## [br]
## @api private
var _execute_request: int = 0

## Tween 被清除或时钟重启时递增，隔离旧时钟回调。
## [br]
## @api private
var _clock_serial: int = 0

## 原生属性读写代理或标记回调的嵌套调用深度。
## [br]
## @api private
var _native_call_depth: int = 0

## 标记当前是否正在执行 finish 流程。
## [br]
## @api private
var _finishing: bool = false

## 标记原生回调期间的 finish 请求已排入延后处理。
## [br]
## @api private
var _finish_requested: bool = false

## 捕获配置规定取消时是否恢复初始属性值。
## [br]
## @api private
var _restore_on_cancel: bool = false

## 捕获配置规定自然完成或 finish 时是否恢复初始属性值。
## [br]
## @api private
var _restore_on_finish: bool = false

## 原生有限 Tween finish 的累计时长预算。
## [br]
## @api private
var _native_finish_budget: float = 0.0

## 原生 Tween 的循环次数；非正值交由无限循环路径处理。
## [br]
## @api private
var _native_loop_count: int = 1

## 标记原生有限 Tween 是否满足 finish 步数与时长预算。
## [br]
## @api private
var _native_finish_bounded: bool = true

## 当前播放是否要求宿主保持有效且在场景树中。
## [br]
## @api private
var _requires_host: bool = false

## 捕获配置要求 Tween 忽略时间缩放。
## [br]
## @api private
var _ignore_time_scale: bool = false

## 捕获配置指定的 Tween 处理阶段。
## [br]
## @api private
var _process_mode: Tween.TweenProcessMode = Tween.TWEEN_PROCESS_IDLE

## 捕获配置指定的 Tween 暂停策略。
## [br]
## @api private
var _pause_mode: Tween.TweenPauseMode = Tween.TWEEN_PAUSE_BOUND

## 受控播放计划最近一次提交的时间位置，单位为秒。
## [br]
## @api private
var _time_seconds: float = 0.0

## 受控播放时钟当前是否朝时间轴起点运行。
## [br]
## @api private
var _backwards: bool = false

## 记录本次受控执行已经发出的计划标记索引。
## [br]
## @api private
var _visited_markers: Dictionary = {}

## 本次执行监听 tree_exited 的宿主与 Node 目标。
## [br]
## @api private
var _guard_nodes: Array[Node] = []

## 本次执行连接到 guard 节点的退出回调。
## [br]
## @api private
var _guard_callback: Callable = Callable()


# --- Godot 生命周期方法 ---

func _init(p_target: Object = null, p_config: GFTweenActionConfig = null, p_host_node: Node = null) -> void:
	target = p_target
	config = p_config
	host_node = p_host_node


# --- 公共方法 ---

## 开始新执行；先结束旧会话，再按当前配置捕获新会话。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @return: 需要等待时返回内部完成 Signal；拒绝、重入失权或瞬时执行时返回 null。
## [br]
## @schema return: Variant，内部完成 Signal 或 null。
func execute() -> Variant:
	_execute_request += 1
	var request: int = _execute_request
	if _run_active:
		_end_run(_generation, _restore_on_cancel)
	elif _pending_completion:
		_notify_completion(_generation)
	if request != _execute_request:
		return null
	if config == null or config.is_empty() or not is_instance_valid(target):
		return null
	var requested_target: Object = target
	var requested_scope: GFTweenReplacementScope = replacement_scope
	var tween_host: Node = _get_tween_host()
	var controlled: bool = config.enable_playback_control or config.ping_pong or requested_scope != null
	var captured_config: GFTweenActionConfig = config
	var captured_plan: GFTweenPlaybackPlan = null
	if controlled:
		captured_plan = GFTweenPlaybackPlan.capture(captured_config, requested_target, captured_config.ping_pong)
		if not captured_plan.error.is_empty():
			push_warning("[GFConfiguredTweenAction][configured_tween_action.invalid_timeline] Cannot play the timeline: %s." % captured_plan.error)
			return null
		# 先检查整组预算；仅接管后需重新捕获初值的路径保留配置副本。
		if requested_scope != null:
			captured_config = config.duplicate_config()
			if captured_config == null:
				return null
	if request != _execute_request:
		return null
	if (controlled or captured_config.has_timed_steps()) and tween_host == null:
		push_warning("[GFConfiguredTweenAction][configured_tween_action.missing_host] Cannot start playback: a valid host node is required.")
		return null
	_generation += 1
	var generation: int = _generation
	_reset_completion_state()
	_run_active = true
	_pending_completion = false
	_run_target = requested_target
	_run_host = tween_host
	_run_scope = requested_scope
	_requires_host = controlled or captured_config.has_timed_steps()
	_lease = 0
	_claiming = false
	_plan = captured_plan
	_initial_values = {}
	_time_seconds = 0.0
	_backwards = false
	_visited_markers.clear()
	_finishing = false
	_finish_requested = false
	_restore_on_cancel = captured_config.restore_initial_values_on_cancel
	_restore_on_finish = captured_config.restore_initial_values_on_finish
	_ignore_time_scale = captured_config.ignore_time_scale
	_process_mode = captured_config.process_mode
	_pause_mode = captured_config.pause_mode
	_native_loop_count = captured_config.loop_count
	_connect_guards(generation)
	if _run_scope != null:
		_claiming = true
		var lease: int = requested_scope.claim(self, _run_target, _plan.property_names)
		if generation != _generation:
			requested_scope.release(self, lease)
			return null
		_claiming = false
		_lease = lease
		if lease <= 0 or not _can_write(generation):
			requested_scope.release(self, lease)
			_end_run(generation, false)
			return null
		# 接管回调可能改变姿态；仍使用冻结配置捕获接管后的初值。
		captured_plan = GFTweenPlaybackPlan.capture(captured_config, _run_target, captured_config.ping_pong)
		if not _can_write(generation):
			_end_run(generation, false)
			return null
		if not captured_plan.error.is_empty():
			_end_run(generation, false)
			return null
		_plan = captured_plan
	if _plan != null:
		_initial_values = _plan.initial_values.duplicate()
	elif _restore_on_cancel or _restore_on_finish:
		_initial_values = captured_config.capture_initial_values(_run_target)
	if not _can_write(generation):
		_end_run(generation, false)
		return null
	if _plan != null:
		_start_clock(generation)
	elif not captured_config.has_timed_steps():
		for step: GFTweenActionStep in captured_config.steps:
			if not _can_write(generation):
				return null
			if step != null:
				step.apply_instant(_run_target)
		_end_run(generation, _restore_on_finish)
		return null
	else:
		_start_native(captured_config, generation)
	if _can_write(generation):
		return _action_completed
	return null


## 取消当前执行并按捕获配置恢复初值；终态重复调用无副作用。
## [br]
## @api public
## [br]
## @since 3.6.0
func cancel() -> void:
	_end_run(_generation, _restore_on_cancel)


## 暂停当前 Tween。
## [br]
## @api public
## [br]
## @since 3.6.0
func pause() -> void:
	if _run_active and is_instance_valid(_active_tween):
		_active_tween.pause()


## 沿当前方向恢复播放。
## [br]
## @api public
## [br]
## @since 3.6.0
func resume() -> void:
	if not _can_write(_generation) or _finishing:
		return
	if _plan != null:
		_start_clock(_generation)
	elif is_instance_valid(_active_tween):
		_active_tween.play()


## 立即完成当前方向，不补发标记；按捕获配置恢复初值。
## 原生有限 Tween 推进到实际终点；无限循环停在当前姿态。
## 有限原生计划超过 4096 个展开属性步骤或总时长非有限时，警告并停止在当前姿态。
## 原生属性 setter 或标记回调内调用时延后到安全时机。
## [br]
## @api public
## [br]
## @since 3.6.0
func finish() -> void:
	if not _can_write(_generation) or _finishing:
		return
	if _plan == null and _native_call_depth > 0:
		if not _finish_requested:
			_finish_requested = true
			pause()
			_finish_deferred.call_deferred(_generation)
		return
	var generation: int = _generation
	_finishing = true
	if _plan != null:
		_clear_active_tween()
		var endpoint: float = 0.0 if _backwards else _plan.duration_seconds
		var _sampled: bool = _commit_sample(endpoint, generation)
	elif is_instance_valid(_active_tween) and _native_loop_count > 0:
		if _native_finish_bounded:
			var tween: Tween = _active_tween
			_disconnect_finished()
			var _stepped: bool = tween.custom_step(_native_finish_budget)
		else:
			push_warning("[GFConfiguredTweenAction][configured_tween_action.finish_budget_exceeded] finish exceeded the finite evaluation budget; playback stopped at the current pose.")
	if generation == _generation:
		_end_run(generation, _restore_on_finish)


## 定位并暂停，只提交最终样本；不触发完成或标记。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param time_seconds: 0 至总时长的有限秒数，包含全部循环。
## [br]
## @return: 定位成功返回 true；拒绝或提交期间失权返回 false。
func seek(time_seconds: float) -> bool:
	if not can_control_playback() or not is_finite(time_seconds):
		return false
	if time_seconds < 0.0 or time_seconds > _plan.duration_seconds:
		return false
	var generation: int = _generation
	_clear_active_tween()
	_skip_markers_through(time_seconds)
	return _commit_sample(time_seconds, generation)


## 从当前时间向时间轴终点播放。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 活跃可控会话开始播放时返回 true。
func play_forward() -> bool:
	return _play_direction(false)


## 从当前时间倒放到时间轴起点，不发出步骤标记。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 活跃可控会话开始倒放时返回 true。
func play_backward() -> bool:
	return _play_direction(true)


## 查询本次执行是否支持定位和方向控制。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已捕获且尚未终结的可控会话返回 true。
func can_control_playback() -> bool:
	return _plan != null and not _finishing and _can_write(_generation)


## 获取可控会话当前时间；未捕获时为 0。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前秒数，终态保留最后提交时间。
func get_time_seconds() -> float:
	return _time_seconds


## 获取捕获时间轴的总时长，包含全部循环与回程。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 总秒数；原生模式或未捕获时为 0。
func get_duration_seconds() -> float:
	return _plan.duration_seconds if _plan != null else 0.0


## 获取保护等待生命周期的宿主节点。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @return: 有效宿主，无效时返回 null。
func get_wait_guard_node() -> Node:
	return _run_host if _run_active and is_instance_valid(_run_host) else _get_tween_host()


# --- 框架内部方法 ---

## 替换第一阶段：停止写入，不恢复初值或发出完成。
## [br]
## @api framework_internal
## [br]
## @param lease: 撤销的租约，包括 claim 尚未返回的租约。
## [br]
## @return: 待完成通知的世代；没有对应执行时为 0。
func detach_replacement(lease: int) -> int:
	if not _run_active or (_lease != lease and not _claiming):
		return 0
	_run_active = false
	_pending_completion = true
	_lease = 0
	_clear_active_tween()
	_disconnect_guards()
	return _generation


## 替换第二阶段：通知对应世代完成。
## [br]
## @api framework_internal
## [br]
## @param generation: detach_replacement 返回的世代。
func notify_replaced(generation: int) -> void:
	_notify_completion(generation)


## 原生代理读取当前世代的目标属性。
## [br]
## @api framework_internal
## [br]
## @param property_name: 已校验属性。
## [br]
## @param generation: 代理捕获的世代。
## [br]
## @param fallback: 旧世代的缓存值。
## [br]
## @return: 属性值，失权时返回缓存。
## [br]
## @schema fallback: Variant，与原生属性兼容的值。
## [br]
## @schema return: Variant，与原生属性兼容的值。
func read_bound_property(property_name: NodePath, generation: int, fallback: Variant) -> Variant:
	if not _can_write(generation):
		return fallback
	_native_call_depth += 1
	var value: Variant = _run_target.get_indexed(property_name)
	_native_call_depth -= 1
	return value


## 原生代理提交仍持权的值，阻止旧并行 Tweener 后续写入。
## [br]
## @api framework_internal
## [br]
## @param property_name: 已校验属性。
## [br]
## @param value: 原生插值结果。
## [br]
## @param generation: 代理捕获的世代。
## [br]
## @schema value: Variant，与原生属性兼容的值。
func write_bound_property(property_name: NodePath, value: Variant, generation: int) -> void:
	if not _can_write(generation):
		return
	_native_call_depth += 1
	_run_target.set_indexed(property_name, value)
	_native_call_depth -= 1


# --- 私有/辅助方法 ---

## 优先返回有效的显式宿主，否则在目标本身为树内 Node 时将其作为宿主。
## [br]
## @api private
func _get_tween_host() -> Node:
	if is_instance_valid(host_node) and host_node.is_inside_tree() and not host_node.is_queued_for_deletion():
		return host_node
	if is_instance_valid(target) and target is Node:
		var node: Node = target
		if node.is_inside_tree() and not node.is_queued_for_deletion():
			return node
	return null


## 验证执行代次、目标与宿主存活状态，以及替换作用域当前仍归本动作持有。
## [br]
## @api private
func _can_write(generation: int) -> bool:
	if generation != _generation or not _run_active or not is_instance_valid(_run_target):
		return false
	if _requires_host and (
		not is_instance_valid(_run_host) or not _run_host.is_inside_tree() or _run_host.is_queued_for_deletion()
	):
		return false
	if _run_target is Node:
		var node: Node = _run_target
		if node.is_queued_for_deletion():
			return false
	return _run_scope == null or (_lease > 0 and _run_scope.owns(self, _lease))


## 从本次宿主创建 Tween，并应用捕获的时间缩放、处理和暂停策略。
## [br]
## @api private
func _create_tween() -> Tween:
	var tween: Tween = _run_host.create_tween()
	var _ignore_result: Tween = tween.set_ignore_time_scale(_ignore_time_scale)
	var _process_result: Tween = tween.set_process_mode(_process_mode)
	var _pause_result: Tween = tween.set_pause_mode(_pause_mode)
	return tween


## 按捕获配置建立原生 Tween、属性绑定与标记回调，并累计 finish 预算。
## 无有效属性绑定时结束本次执行；结束信号仅在绑定存在时连接。
## [br]
## @api private
func _start_native(captured_config: GFTweenActionConfig, generation: int) -> void:
	_active_tween = _create_tween()
	_bindings.clear()
	_native_finish_budget = 0.0
	if _native_loop_count != 1:
		var _loops_result: Tween = _active_tween.set_loops(_native_loop_count)
	for step_index: int in range(captured_config.steps.size()):
		if not _can_write(generation):
			return
		var step: GFTweenActionStep = captured_config.steps[step_index]
		if step == null:
			continue
		var property_error: String = step.get_property_validation_error(_run_target)
		if not property_error.is_empty():
			push_warning("[GFTweenActionStep][tween_action_step.invalid_tween_step] Skipped an invalid Tween step: %s." % property_error)
			continue
		var initial: Variant = _run_target.get_indexed(step.property_name)
		if not _can_write(generation):
			return
		var binding: GFTweenPropertyBinding = GFTweenPropertyBinding.new(self, step.property_name, generation, initial)
		if step.append_for_action(_active_tween, _run_target, captured_config.duration_scale, binding) != null:
			_bindings.append(binding)
			var duration: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(step.duration * captured_config.duration_scale)
			var delay: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(step.delay * captured_config.duration_scale)
			_native_finish_budget += duration + delay
			_append_marker_callback(step, step_index, duration + delay, generation)
	if _bindings.is_empty():
		_end_run(generation, false)
		return
	_native_finish_budget = (_native_finish_budget + 1.0) * float(maxi(_native_loop_count, 1))
	_native_finish_bounded = (
		is_finite(_native_finish_budget) and _native_loop_count > 0
		and _native_loop_count <= _MAX_FINISH_STEPS
		and _bindings.size() * _native_loop_count <= _MAX_FINISH_STEPS
	)
	_connect_finished(generation)


## 用线性 MethodTweener 从当前时间运行到当前方向的时间轴端点。
## [br]
## @api private
func _start_clock(generation: int) -> void:
	if not _can_write(generation):
		return
	_clear_active_tween()
	var endpoint: float = 0.0 if _backwards else _plan.duration_seconds
	if _time_seconds == endpoint:
		_end_run(generation, _restore_on_finish)
		return
	_active_tween = _create_tween()
	var clock: MethodTweener = _active_tween.tween_method(
		_on_clock_sample.bind(generation, _clock_serial), _time_seconds, endpoint, absf(endpoint - _time_seconds)
	)
	var _linear_result: MethodTweener = clock.set_trans(Tween.TRANS_LINEAR)
	_connect_finished(generation)


## 仅对有效受控会话切换播放方向并启动时钟。
## [br]
## @api private
func _play_direction(backwards: bool) -> bool:
	if not can_control_playback():
		return false
	_backwards = backwards
	_start_clock(_generation)
	return true


## 从捕获计划采样时间点，并在每次属性写入前验证执行代次与时钟序号。
## 采样为空时终结执行；返回提交后是否仍持有写入资格。
## [br]
## @api private
func _commit_sample(time_seconds: float, generation: int) -> bool:
	if not _can_write(generation):
		return false
	var serial: int = _clock_serial
	var values: Dictionary = _plan.sample(time_seconds)
	if values.is_empty():
		_end_run(generation, false)
		return false
	_time_seconds = time_seconds
	for property_name: String in values:
		if not _can_write(generation) or serial != _clock_serial:
			return false
		_run_target.set_indexed(NodePath(property_name), values[property_name])
	return _can_write(generation) and serial == _clock_serial


## 将计划时间不晚于给定位置的标记登记为已访问，供 seek 避免回放补发。
## [br]
## @api private
func _skip_markers_through(time_seconds: float) -> void:
	for index: int in range(_plan.markers.size()):
		if GFVariantData.get_option_float(_plan.markers[index], "time_seconds") <= time_seconds:
			_visited_markers[index] = true


## 将 Tween.finished 以一次性方式连接到当前执行代次和时钟序号。
## [br]
## @api private
func _connect_finished(generation: int) -> void:
	_finished_callback = _on_active_tween_finished.bind(generation, _clock_serial)
	var _connected: Error = _active_tween.finished.connect(_finished_callback, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error


## 若当前 Tween 仍连接该回调则断开，并清空回调句柄。
## [br]
## @api private
func _disconnect_finished() -> void:
	if is_instance_valid(_active_tween) and _finished_callback.is_valid() and _active_tween.finished.is_connected(_finished_callback):
		_active_tween.finished.disconnect(_finished_callback)
	_finished_callback = Callable()


## 递增时钟序号、断开完成回调、终止现有 Tween 并清空引用。
## [br]
## @api private
func _clear_active_tween() -> void:
	_clock_serial += 1
	_disconnect_finished()
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null


## 结束匹配代次的执行，清理 Tween 与生命周期监听，并按需在仍持权时恢复属性。
## 释放替换租约后将完成通知排入终态处理。
## [br]
## @api private
func _end_run(generation: int, restore: bool) -> void:
	if generation != _generation or not _run_active:
		return
	_run_active = false
	_pending_completion = true
	_clear_active_tween()
	_disconnect_guards()
	var old_scope: GFTweenReplacementScope = _run_scope
	var old_lease: int = _lease
	if _claiming and old_scope != null:
		old_lease = old_scope.find_lease(self)
	var old_target: Object = _run_target
	var initial_values: Dictionary = _initial_values
	if restore:
		for property_name: String in initial_values:
			if generation != _generation or not is_instance_valid(old_target):
				break
			if old_scope != null and not old_scope.owns(self, old_lease):
				break
			old_target.set_indexed(NodePath(property_name), initial_values[property_name])
	if old_scope != null:
		old_scope.release(self, old_lease)
	if generation != _generation:
		return
	_lease = 0
	_finishing = false
	_finish_requested = false
	_notify_completion(generation)


## 仅对当前代次且待通知状态发出一次动作完成信号。
## [br]
## @api private
func _notify_completion(generation: int) -> void:
	if generation != _generation or not _pending_completion:
		return
	_pending_completion = false
	_emit_completed_once()


## 监听本次有效宿主和 Node 目标的 tree_exited，以结束对应代次执行。
## [br]
## @api private
func _connect_guards(generation: int) -> void:
	_guard_callback = _on_guard_exited.bind(generation)
	if is_instance_valid(_run_host):
		_guard_nodes.append(_run_host)
	if _run_target is Node:
		var node: Node = _run_target
		if not _guard_nodes.has(node):
			_guard_nodes.append(node)
	for node: Node in _guard_nodes:
		var _connected: Error = node.tree_exited.connect(_guard_callback) as Error


## 断开仍有效 guard 节点上的退出监听并清空回调与节点列表。
## [br]
## @api private
func _disconnect_guards() -> void:
	for node: Node in _guard_nodes:
		if is_instance_valid(node) and node.tree_exited.is_connected(_guard_callback):
			node.tree_exited.disconnect(_guard_callback)
	_guard_nodes.clear()
	_guard_callback = Callable()


## 为带标记的原生步骤追加并行回调，并按步骤累计时长设置延迟。
## [br]
## @api private
func _append_marker_callback(step: GFTweenActionStep, step_index: int, delay: float, generation: int) -> void:
	if step.marker_id == &"":
		return
	var _parallel_result: Tween = _active_tween.parallel()
	var marker: CallbackTweener = _active_tween.tween_callback(
		_on_step_marker_reached.bind(step.marker_id, step_index, generation)
	)
	var _delay_result: CallbackTweener = marker.set_delay(delay)


## 延后 finish 请求仅在执行代次匹配且请求标记仍有效时执行。
## [br]
## @api private
func _finish_deferred(generation: int) -> void:
	if generation == _generation and _finish_requested:
		_finish_requested = false
		finish()


# --- 信号处理函数 ---

## 提交受控时钟采样，并在正向跨越时按时间顺序发出尚未访问的标记。
## [br]
## @api private
func _on_clock_sample(time_seconds: float, generation: int, serial: int) -> void:
	if not _can_write(generation) or serial != _clock_serial:
		return
	var previous: float = _time_seconds
	if not _commit_sample(time_seconds, generation):
		return
	if _backwards or _finishing or time_seconds < previous:
		return
	for index: int in range(_plan.markers.size()):
		if not _can_write(generation) or serial != _clock_serial:
			return
		var marker: Dictionary = _plan.markers[index]
		var marker_time: float = GFVariantData.get_option_float(marker, "time_seconds")
		if marker_time <= time_seconds and marker_time >= previous and not _visited_markers.has(index):
			_visited_markers[index] = true
			marker_reached.emit(GFVariantData.get_option_string_name(marker, "marker_id"), GFVariantData.get_option_int(marker, "index"), _run_target)


## 当前 Tween 以同一代次和时钟序号完成时结束动作执行。
## [br]
## @api private
func _on_active_tween_finished(generation: int, serial: int) -> void:
	if generation == _generation and serial == _clock_serial and not _finishing:
		_end_run(generation, _restore_on_finish)


## 目标或宿主退出场景树时终止匹配代次且不恢复目标属性。
## [br]
## @api private
func _on_guard_exited(generation: int) -> void:
	_end_run(generation, false)


## 原生步骤标记回调在执行仍有效且未 finish 时发出标记信号。
## [br]
## @api private
func _on_step_marker_reached(marker_id: StringName, step_index: int, generation: int) -> void:
	if not _can_write(generation) or _finishing or _finish_requested:
		return
	_native_call_depth += 1
	marker_reached.emit(marker_id, step_index, _run_target)
	_native_call_depth -= 1
