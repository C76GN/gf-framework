@tool

## GFUIMotionPlayer: 在一个宿主中播放双页与组件轨道，逐次绑定，并隔离各次运行、取消和定位。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFUIMotionPlayer
extends Node


# --- 信号 ---

## 轨道对一个元素开始，仅正向播放跨过触点时发送。
## [br]
## @api public
## [br]
## @param cue: 作者设置的轨道标记。
## [br]
## @param target: 此次触发的目标。
## [br]
## @since unreleased
signal cue_reached(cue: StringName, target: Object)

## 新页的入场时间已结束，页内轨道可继续播放。
## [br]
## @api public
## [br]
## @since unreleased
signal page_entered

## 本次会话已经释放绑定。
## [br]
## @api public
## [br]
## @param reason: 自然、立即完成或取消。
## [br]
## @since unreleased
signal ended(reason: GFUIMotionBinding.EndReason)


# --- 常量 ---

## 统一适配外部动作完成信号携带的参数。
## [br]
## @api private
const _WAIT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")

## 每个实际目标共享一个弱引用替换作用域，空作用域随最后一个租约释放。
## [br]
## @api private
const _SCOPE_META: StringName = &"_gf_ui_motion_property_scope"


# --- 导出变量 ---

## 允许本播放器接管其他界面播放器已经拥有的属性。默认在修改任何目标前报告冲突。
## [br]
## @api public
## [br]
## @since unreleased
@export var take_over_properties: bool = false


# --- 私有变量 ---

## 按触发秒数和声明序号排列的独立目标。
## [br]
## @api private
var _lanes: Array[_Lane] = []

## 每个在树内的参与节点只连接一次退出通知。
## [br]
## @api private
var _guards: Dictionary[Node, Array] = {}

## 旧页或其子节点被最后一条轨道使用的时间。
## [br]
## @api private
var _outgoing_end: float = 0.0

## 由导航持有者提供的精确释放操作。
## [br]
## @api private
var _release_outgoing: Callable

## 已交还目标或交接中的实播会话无法重建过去的画面。
## [br]
## @api private
var _forward_only: bool = false

## 会话的最后一个有限端点。
## [br]
## @api private
var _duration: float = 0.0

## 当前墙钟进度，以秒计。
## [br]
## @api private
var _elapsed: float = 0.0

## 新页入场终点，独立于动作完成。
## [br]
## @api private
var _arrival: float = 0.0

## 这次前进已经经过入场终点。
## [br]
## @api private
var _arrived: bool = false

## 会话已就绪，可暂停、取消或定位。
## [br]
## @api private
var _active: bool = false

## 防止钩子同步重入覆盖正在验证、采样或回收的会话。
## [br]
## @api private
var _busy: bool = false

## 采样期间收到的中断，在返回宿主时结算。
## [br]
## @api private
var _cancel_pending: bool = false

## 保留最近一次调用的校验结果。
## [br]
## @api private
var _diagnostic: String = ""


# --- Godot 生命周期方法 ---

func _ready() -> void:
	set_process(_active and is_processing())


func _process(delta: float) -> void:
	_update(
		minf(
			_elapsed + delta,
			_duration
		),
		true,
		false
	)


func _exit_tree() -> void:
	cancel()


# --- 公共方法 ---

## 先检查完整配方和具名绑定，再替换本宿主的会话。配置的时间及曲线在本次播放开始时冻结。
## [br]
## @api public
## [br]
## @param recipe: 双页与独立局部轨道。
## [br]
## @param targets: 单一目标或同一轨道的有序目标数组。
## [br]
## @schema targets: Dictionary，StringName 映射到 Object 或有序 Array[Object]。
## [br]
## @param inputs: 共用的显式项目输入。
## [br]
## @schema inputs: Dictionary，StringName 映射到效果声明的输入类型。
## [br]
## @param paused: 从可定位的初始画面开始，仅实播动作等待恢复。
## [br]
## @return: OK 或错误码，细节可由 get_diagnostic 获取。
## [br]
## @since unreleased
func play(
	recipe: GFUIMotionRecipe,
	targets: Dictionary,
	inputs: Dictionary = {},
	paused: bool = false
) -> Error:
	return _play(
		recipe,
		targets,
		inputs,
		paused,
		null,
		Callable()
	)


## 接受 GFUIUtility.navigate_with_presentation 的同步交接。普通页面切换直接播放原有控件。
## 项目按实际节点提供角色；旧页使用完毕时恢复其姿态并交还路由，页内动画继续。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param outgoing: 路由保留的旧页。
## [br]
## @param incoming: 已经接管导航和焦点的新页。
## [br]
## @param release: 路由提供的幂等释放回调。
## [br]
## @param recipe: 可在不同页面之间复用的时序。
## [br]
## @param bind_roles: 接收旧页和新页，返回角色到目标或有序目标列表的字典。
## [br]
## @param inputs: 项目提供的额外输入。
## [br]
## @schema inputs: Dictionary，StringName 映射到效果声明的输入。
## [br]
## @return: 播放是否已启动。
func play_transition(
	outgoing: Control,
	incoming: Control,
	release: Callable,
	recipe: GFUIMotionRecipe,
	bind_roles: Callable,
	inputs: Dictionary = {}
) -> Error:
	# 路由已提交新栈。即使本次绑定失败，上一段表现也应把其旧页交还。
	if _busy:
		cancel()
		return ERR_BUSY
	if _active:
		cancel()
		if _active:
			return ERR_BUSY
	if (
		not bind_roles.is_valid()
		or not release.is_valid()
		or not _available(outgoing)
		or not _available(incoming)
	):
		return ERR_INVALID_PARAMETER
	var roles: Variant = bind_roles.call(outgoing, incoming)
	if not roles is Dictionary:
		return ERR_INVALID_DATA
	var targets: Dictionary = roles
	return _play(
		recipe,
		targets,
		inputs,
		false,
		outgoing,
		release
	)


## 停止时间推进，同时暂停当前正在播放的外部动作。
## [br]
## @api public
## [br]
## @since unreleased
func pause() -> void:
	if _busy or not _active:
		return
	set_process(false)
	_control_actions(true)


## 从当前时间继续前进。
## [br]
## @api public
## [br]
## @since unreleased
func resume() -> void:
	if _busy or not _active:
		return
	var current: Array[_Lane] = _lanes
	_control_actions(false)
	if _active and is_same(current, _lanes):
		set_process(true)
		_update(
			_elapsed,
			true,
			false
		)


## 暂停并直接重建指定时间的姿态，不触发标记或结束会话。实播动作拒绝定位。
## [br]
## @api public
## [br]
## @param seconds: 闭区间内的会话秒数。
## [br]
## @return: 是否成功重建。
## [br]
## @since unreleased
func seek(seconds: float) -> bool:
	if (
		_busy
		or not _active
		or not can_seek()
		or not is_finite(seconds)
		or seconds < 0.0
		or seconds > _duration
	):
		return false
	set_process(false)
	var current: Array[_Lane] = _lanes
	_arrived = seconds >= _arrival
	for lane: _Lane in _lanes:
		lane._triggered = lane._start <= seconds
	_update(
		seconds,
		false,
		false
	)
	return _active and is_same(current, _lanes)


## 应用采样动作的终点，结束已经启动的实播动作，跳过尚未触发的事件。
## [br]
## @api public
## [br]
## @since unreleased
func finish() -> void:
	if not _busy and _active:
		_update(
			_duration,
			false,
			true
		)


## 取消本次播放并释放拥有的临时资源。采样时发起的取消会在当前钩子返回后处理。
## [br]
## @api public
## [br]
## @since unreleased
func cancel() -> void:
	if _busy:
		_cancel_pending = true
	elif _active:
		_busy = true
		_close(GFUIMotionBinding.EndReason.CANCELLED)
		_busy = false


## 判断会话仍可控制。
## [br]
## @api public
## [br]
## @return: 已准备且未释放时为 true。
## [br]
## @since unreleased
func is_active() -> bool:
	return _active


## 当前会话是否所有轨道均可任意定位。
## [br]
## @api public
## [br]
## @return: 有实播动作、已经交还目标或路由正在交接时为 false。
## [br]
## @since unreleased
func can_seek() -> bool:
	if _forward_only:
		return false
	for lane: _Lane in _lanes:
		if lane._binding != null and lane._binding.action != null:
			return false
	return _active


## 读取最近一次有效会话的总长。
## [br]
## @api public
## [br]
## @return: 以秒计的有限端点。
## [br]
## @since unreleased
func get_duration_seconds() -> float:
	return _duration


## 读取当前的时间。
## [br]
## @api public
## [br]
## @return: 会话开始后的秒数。
## [br]
## @since unreleased
func get_time_seconds() -> float:
	return _elapsed


## 取得最近一次准备错误以定位轨道和输入。
## [br]
## @api public
## [br]
## @return: 成功时为空。
## [br]
## @since unreleased
func get_diagnostic() -> String:
	return _diagnostic


## 获取当前会话已绑定的各目标区间，按实际触发时刻排列。
## [br]
## @api public
## [br]
## @return: 每次调用返回独立快照；空闲时为空。
## [br]
## @schema return: Array[Dictionary]，每项含 track_index(int)、start_seconds(float)、end_seconds(float)，区间以会话起点为零。
## [br]
## @since unreleased
func get_track_intervals() -> Array[Dictionary]:
	var intervals: Array[Dictionary] = []
	for lane: _Lane in _lanes:
		intervals.append(
			{
				"track_index": lane._track_index,
				"start_seconds": lane._start,
				"end_seconds": lane._start + lane._span,
			}
		)
	return intervals


# --- 私有/辅助方法 ---

## 准备全部目标和租约后发布一次会话，路由与样机共用同一个时间轴。
## [br]
## @api private
func _play(
	recipe: GFUIMotionRecipe,
	targets: Dictionary,
	inputs: Dictionary,
	paused: bool,
	outgoing: Control,
	release: Callable
) -> Error:
	if _busy:
		return ERR_BUSY
	if not is_inside_tree():
		_diagnostic = "播放器需要先进入场景树"
		return ERR_UNCONFIGURED
	_busy = true
	var prepared: Array[_Lane] = []
	var sources: Dictionary = inputs.duplicate()
	_diagnostic = _compile(
		recipe,
		targets,
		sources,
		prepared
	)
	if not _diagnostic.is_empty():
		_busy = false
		if _cancel_pending:
			cancel()
		return ERR_INVALID_DATA
	for lane: _Lane in prepared:
		if not _can_claim(lane):
			_busy = false
			if _cancel_pending:
				cancel()
			return ERR_BUSY
	if _active:
		_close(GFUIMotionBinding.EndReason.CANCELLED, true)
	_lanes = prepared
	_release_outgoing = release
	_outgoing_end = 0.0
	_forward_only = release.is_valid()
	_arrival = recipe.enter_delay + recipe.enter_seconds
	_duration = maxf(
		_arrival,
		recipe.exit_delay + recipe.exit_seconds
	)
	_elapsed = 0.0
	_arrived = false
	_cancel_pending = false
	_active = true
	for lane: _Lane in _lanes:
		if not _available(lane._target):
			_diagnostic = "绑定期间目标已退出场景或释放"
			break
		lane._player = self
		_duration = maxf(
			_duration,
			lane._start + lane._span
		)
		for source: Variant in lane._nodes:
			if not _available(source):
				_diagnostic = "轨道 %d 的节点输入已退出场景" % lane._track_index
				break
			var node: Node = source
			_guard(node, lane)
			if (
				outgoing != null
				and (
					node == outgoing
					or outgoing.is_ancestor_of(node)
				)
			):
				lane._uses_outgoing = true
				_outgoing_end = maxf(
					_outgoing_end,
					lane._start + lane._span
				)
		if not _diagnostic.is_empty():
			break
		if lane._uses_outgoing and lane._target is Node:
			lane._restore_outgoing = lane._target == outgoing or outgoing.is_ancestor_of(lane._target as Node)
		if not lane._paths.is_empty():
			# 上一条租约的结束通知可能同步启动了另一个播放器。
			if not _can_claim(lane):
				break
			if not lane._target.has_meta(_SCOPE_META):
				lane._target.set_meta(
					_SCOPE_META,
					GFTweenReplacementScope.new()
				)
			lane._scope = lane._target.get_meta(_SCOPE_META)
			lane._lease = lane._scope.claim(
				lane,
				lane._target,
				lane._paths,
				true
			)
			if lane._lease == 0:
				_diagnostic = "轨道 %d 未取得属性写入权" % lane._track_index
				break
		if lane._effect == null:
			continue
		lane._binding = lane._effect.bind_target(lane._target, sources)
		if (
			lane._binding == null
			or (
				not lane._binding.sample.is_valid()
				and lane._binding.action == null
			)
		):
			_diagnostic = "轨道 %d 未返回有效采样操作或动作" % lane._track_index
			break
	_busy = false
	if not _diagnostic.is_empty() or _cancel_pending:
		cancel()
		return ERR_CANT_CREATE
	set_process(not paused)
	_update(
		0.0,
		not paused,
		false
	)
	return OK


## 验证页钟、输入、目标和属性占有关系。每个轨道仅在开始前展开一次。
## [br]
## @api private
func _compile(
	recipe: GFUIMotionRecipe,
	targets: Dictionary,
	inputs: Dictionary,
	output: Array[_Lane]
) -> String:
	if recipe == null:
		return "缺少配方"
	for seconds: float in [
		recipe.enter_delay,
		recipe.enter_seconds,
		recipe.exit_delay,
		recipe.exit_seconds,
	]:
		if not is_finite(seconds) or seconds < 0.0:
			return "页面时长必须是有限非负值"
	var claims: Dictionary = {}
	for index: int in recipe.tracks.size():
		var track: GFUIMotionTrack = recipe.tracks[index]
		if (
			track == null
			or (
				track.effect == null
				and track.cue.is_empty()
			)
		):
			return "轨道 %d 需要效果或标记" % index
		for seconds: float in [
			track.at,
			track.delay_seconds,
			track.duration,
			track.stagger_seconds,
		]:
			if not is_finite(seconds) or seconds < 0.0:
				return "轨道 %d 的时间非法" % index
		if track.at > 1.0:
			return "轨道 %d 的触发比例超出范围" % index
		var types: Dictionary = track.effect.input_types() if track.effect != null else {}
		for slot: Variant in types:
			var spec: Variant = types[slot]
			var type_name: String = str(spec)
			if typeof(spec) == TYPE_INT:
				var kind: int = spec
				if spec < 0 or spec >= TYPE_MAX:
					return (
						"轨道 %d 输入 %s 声明了无效的 Variant 类型"
						% [index, slot]
					)
				type_name = type_string(kind)
			elif typeof(spec) != TYPE_OBJECT or not is_instance_valid(spec):
				return (
					"轨道 %d 输入 %s 需要 Variant、原生类或脚本类型"
					% [index, slot]
				)
			var input: Variant = inputs.get(slot)
			var available: bool = typeof(input) != TYPE_OBJECT or _available(input)
			if (
				not inputs.has(slot)
				or not available
				or not is_instance_of(input, spec)
			):
				return (
					"轨道 %d 输入 %s 期望 %s，实际 %s"
					% [
						index,
						slot,
						type_name,
						type_string(typeof(inputs.get(slot))),
					]
				)
		var value: Variant = targets.get(track.target)
		var items: Array = value if value is Array else [value]
		var reference: float = recipe.enter_seconds if track.clock == GFUIMotionTrack.Clock.ENTER else recipe.exit_seconds
		var start: float = recipe.enter_delay if track.clock == GFUIMotionTrack.Clock.ENTER else recipe.exit_delay
		start += reference * track.at
		if track.clock == GFUIMotionTrack.Clock.SESSION:
			start = 0.0
			reference = 1.0
		var span: float = track.duration * reference if track.relative_duration else track.duration
		for i: int in items.size():
			var target: Variant = items[i]
			if typeof(target) != TYPE_OBJECT or not _available(target):
				return (
					"轨道 %d 缺少有效目标 %s"
					% [index, track.target]
				)
			var object: Object = target
			var lane: _Lane = _Lane.new()
			if track.effect != null:
				lane._paths = track.effect.written_properties()
				var issue: String = _validate_target(
					track.effect,
					object,
					inputs,
					claims,
					lane._paths
				)
				if not issue.is_empty():
					return (
						"轨道 %d (%s): %s"
						% [
							index,
							track.target,
							issue,
						]
					)
			if object is Node:
				lane._nodes.append(object)
			for slot: Variant in types:
				var source: Variant = inputs[slot]
				if source is Node and not lane._nodes.has(source):
					lane._nodes.append(source)
			lane._target = target
			lane._effect = track.effect
			lane._order = output.size()
			lane._track_index = index
			lane._cue = track.cue
			lane._start = start + track.delay_seconds + i * track.stagger_seconds
			lane._span = span if track.effect != null else 0.0
			lane._transition = track.transition
			lane._easing = track.easing
			if track.effect != null and track.curve != null:
				lane._curve = track.curve.duplicate() as Curve
			output.append(lane)
	output.sort_custom(_starts_before)
	return ""


## 注意跨播放器接管只在当前旧持有者没有执行用户回调时发生。
## [br]
## @api private
func _can_claim(lane: _Lane) -> bool:
	if lane._paths.is_empty() or not lane._target.has_meta(_SCOPE_META):
		return true
	var scope: GFTweenReplacementScope = lane._target.get_meta(_SCOPE_META)
	for holder: Object in scope.conflicting_actions(
		lane._target,
		lane._paths,
		true
	):
		var owned: _Lane = holder as _Lane
		if owned != null and owned._player == self:
			continue
		if (
			not take_over_properties
			or owned == null
			or owned._player._busy
		):
			_diagnostic = "轨道 %d 的属性已由另一播放器占用" % lane._track_index
			return false
		if owned._action_running and not owned._pose_stop().is_valid():
			_diagnostic = "轨道 %d 的实播动作不支持按当前姿态交接" % lane._track_index
			return false
	return true


## 校验实际目标和属性占用。仅派发标记的轨道不读取或写入目标属性。
## [br]
## @api private
func _validate_target(
	effect: GFUIMotionEffect,
	target: Object,
	inputs: Dictionary,
	claims: Dictionary,
	writes: Array[NodePath]
) -> String:
	var issue: String = effect.binding_error(target, inputs)
	if not issue.is_empty():
		return issue
	var paths: Array = claims.get(target, [])
	for path: NodePath in writes:
		var key: String = GFTweenReplacementScope.normalized_property(target, path)
		if key.is_empty():
			return "属性路径为空"
		for used: String in paths:
			if GFTweenReplacementScope.paths_overlap(key, used):
				return "重复写入 %s" % path
		paths.append(key)
	claims[target] = paths
	return ""


## 以时刻与声明序号构成稳定的全序。
## [br]
## @api private
func _starts_before(first: _Lane, second: _Lane) -> bool:
	if first._start == second._start:
		return first._order < second._order
	return first._start < second._start


## 采样与事件分开执行，保证同帧的触发处理看到一致的画面。
## [br]
## @api private
func _update(
	seconds: float,
	dispatch: bool,
	immediate: bool
) -> void:
	if not _active or _busy:
		return
	_busy = true
	_elapsed = seconds
	for lane: _Lane in _lanes:
		if lane._retired:
			continue
		if not is_instance_valid(lane._target):
			_cancel_pending = true
			break
		if lane._binding == null or not lane._binding.sample.is_valid():
			continue
		var local: float = clampf(
			(seconds - lane._start) / lane._span,
			0.0,
			1.0
		) if lane._span > 0.0 else float(seconds >= lane._start)
		if local != lane._sampled or not dispatch:
			var weight: float = local
			if lane._curve != null:
				weight = lane._curve.sample_baked(local)
			elif local > 0.0 and local < 1.0:
				weight = Tween.interpolate_value(
					0.0,
					1.0,
					local,
					1.0,
					lane._transition,
					lane._easing
				)
			lane._binding.sample.call(weight)
			lane._sampled = local
		if _cancel_pending:
			break
	if dispatch and not _cancel_pending:
		_dispatch(seconds)
	var moving_forward: bool = dispatch or immediate
	if (
		_release_outgoing.is_valid()
		and moving_forward
		and seconds >= _outgoing_end
		and not _cancel_pending
	):
		for lane: _Lane in _lanes:
			if lane._uses_outgoing:
				_release_lane(
					lane,
					GFUIMotionBinding.EndReason.CANCELLED if lane._restore_outgoing else GFUIMotionBinding.EndReason.COMPLETED
				)
		_return_outgoing()
	if _cancel_pending:
		_close(GFUIMotionBinding.EndReason.CANCELLED)
	elif immediate:
		_close(GFUIMotionBinding.EndReason.FINISHED)
	elif dispatch and seconds >= _duration:
		_close(GFUIMotionBinding.EndReason.COMPLETED)
	_busy = false


## 按时间顺序发送开始事件、入场结束及实播动作的终态。
## [br]
## @api private
func _dispatch(seconds: float) -> void:
	for lane: _Lane in _lanes:
		if lane._retired:
			continue
		if not lane._triggered and lane._start <= seconds:
			if not _arrived and _arrival < lane._start:
				_arrived = true
				page_entered.emit()
			if _cancel_pending:
				return
			lane._triggered = true
			var action: GFVisualAction = lane._binding.action if lane._binding != null else null
			if action != null and action.can_execute():
				var result: Variant = action.execute()
				var completion: Signal
				if result is Signal:
					completion = result
				if not completion.is_null():
					lane._action_running = true
					lane._completion = completion
					lane._on_completion = _WAIT.make_signal_resume_callable(
						completion,
						_disarm_action.bind(lane)
					)
					var _connected: int = lane._completion.connect(lane._on_completion)
			if not lane._cue.is_empty() and not _cancel_pending:
				cue_reached.emit(lane._cue, lane._target)
		if _cancel_pending:
			return
		if lane._action_running and seconds >= lane._start + lane._span:
			_disarm_action(lane)
			lane._binding.action.finish()
		if _cancel_pending:
			return
	if not _arrived and seconds >= _arrival:
		_arrived = true
		page_entered.emit()


## 主动终止和项目自然完成共享解绑路径，短动作只结算一次。
## [br]
## @api private
func _disarm_action(lane: _Lane) -> void:
	lane._action_running = false
	if not lane._completion.is_null() and lane._completion.is_connected(lane._on_completion):
		lane._completion.disconnect(lane._on_completion)
	lane._completion = Signal()
	lane._on_completion = Callable()


## 取消或完成只交接本次绑定拥有的资源。钩子执行期间拒绝同步替换。
## [br]
## @api private
func _close(reason: GFUIMotionBinding.EndReason, replacing: bool = false) -> void:
	set_process(false)
	_active = false
	for i: int in range(
		_lanes.size() - 1,
		-1,
		-1
	):
		var lane: _Lane = _lanes[i]
		_release_lane(
			lane,
			GFUIMotionBinding.EndReason.CANCELLED if lane._restore_outgoing else reason
		)
	_lanes.clear()
	_return_outgoing()
	_cancel_pending = false
	if not replacing:
		_busy = false
	ended.emit(reason)


## 归还作者传入的交接回调，每次导航只调用一次。
## [br]
## @api private
func _return_outgoing() -> void:
	var callback: Callable = _release_outgoing
	_release_outgoing = Callable()
	if callback.is_valid():
		callback.call()


## 精确解除当前轨道的写入权、退出监听和临时操作。
## [br]
## @api private
func _release_lane(lane: _Lane, reason: GFUIMotionBinding.EndReason) -> void:
	if lane._retired:
		return
	lane._retired = true
	for source: Variant in lane._nodes:
		if not is_instance_valid(source) or not _guards.has(source):
			continue
		var node: Node = source
		var guarded: Array = _guards[node]
		guarded.erase(lane)
		if guarded.is_empty():
			var _erased: bool = _guards.erase(node)
			node.tree_exiting.disconnect(_on_target_exiting.bind(node))
	lane._nodes.clear()
	if lane._binding != null:
		if lane._action_running:
			_disarm_action(lane)
			var stop: Callable = lane._pose_stop() if reason == GFUIMotionBinding.EndReason.REPLACED else Callable()
			if stop.is_valid():
				stop.call()
			elif reason in [GFUIMotionBinding.EndReason.CANCELLED, GFUIMotionBinding.EndReason.REPLACED]:
				lane._binding.action.cancel()
			else:
				lane._binding.action.finish()
		if is_instance_valid(lane._target) and lane._binding.release.is_valid():
			lane._binding.release.call(reason)
		lane._binding = null
	if lane._scope != null:
		lane._scope.release(lane, lane._lease)
		if (
			is_instance_valid(lane._target)
			and lane._scope.get_active_count() == 0
			and lane._target.has_meta(_SCOPE_META)
			and lane._target.get_meta(_SCOPE_META) == lane._scope
		):
			lane._target.remove_meta(_SCOPE_META)
		lane._scope = null
	lane._target = null


## 仅监听效果真正引用的输入与目标，按节点共用一个连接。
## [br]
## @api private
func _guard(node: Node, lane: _Lane) -> void:
	if not _guards.has(node):
		_guards[node] = []
		var _connection: int = node.tree_exiting.connect(_on_target_exiting.bind(node))
	_guards[node].append(lane)


## 树外或任一祖先正等待释放的节点无法绑定。
## [br]
## @api private
func _available(object: Variant) -> bool:
	if not is_instance_valid(object):
		return false
	if object is Node:
		var node: Node = object
		if not node.is_inside_tree():
			return false
		while node != null:
			if node.is_queued_for_deletion():
				return false
			node = node.get_parent()
	return true


## 将宿主的暂停控制交给当前活动的外部动作。
## [br]
## @api private
func _control_actions(paused: bool) -> void:
	_busy = true
	for lane: _Lane in _lanes:
		if lane._action_running:
			if paused:
				lane._binding.action.pause()
			else:
				lane._binding.action.resume()
		if _cancel_pending:
			break
	if _cancel_pending:
		_close(GFUIMotionBinding.EndReason.CANCELLED)
	_busy = false


# --- 信号处理函数 ---

## 已用完的节点可先退出，仍在使用的目标提前退出则中断会话。
## [br]
## @api private
func _on_target_exiting(node: Node) -> void:
	var affected: Array = _guards[node].duplicate()
	for lane: _Lane in affected:
		if (
			_elapsed < lane._start + lane._span
			or not lane._triggered
			or lane._action_running
		):
			cancel()
			return
	var was_busy: bool = _busy
	_busy = true
	_forward_only = true
	for lane: _Lane in affected:
		_release_lane(lane, GFUIMotionBinding.EndReason.COMPLETED)
	_busy = was_busy
	if _cancel_pending and not was_busy:
		cancel()


# --- 内部类 ---

## 在准备时冻结时序、曲线和独立的目标操作。稳定序号用于同刻标记顺序。
## [br]
## @api private
class _Lane extends RefCounted:


	# --- 私有变量 ---

	## 本次绑定的实际显示目标。
	## [br]
	## @api private
	var _target: Object

	## 用于创建独立运行操作的效果。
	## [br]
	## @api private
	var _effect: GFUIMotionEffect

	## 会话持有的采样、动作和清理回调。
	## [br]
	## @api private
	var _binding: GFUIMotionBinding

	## 为本轨道监听的目标及显式输入节点。
	## [br]
	## @api private
	var _nodes: Array[Node] = []

	## 效果声明的实际写入路径。
	## [br]
	## @api private
	var _paths: Array[NodePath] = []

	## 归还本轨道所属的播放会话。
	## [br]
	## @api private
	var _player: GFUIMotionPlayer

	## 目标当前的替换作用域。
	## [br]
	## @api private
	var _scope: GFTweenReplacementScope

	## 本次申请的精确租约。
	## [br]
	## @api private
	var _lease: int = 0

	## 已经交还目标或写入权。
	## [br]
	## @api private
	var _retired: bool = false

	## 该轨道仍依赖退场面板。
	## [br]
	## @api private
	var _uses_outgoing: bool = false

	## 归还留在历史中的旧页时恢复原始姿态。
	## [br]
	## @api private
	var _restore_outgoing: bool = false

	## 来源配方中的轨道序号。
	## [br]
	## @api private
	var _track_index: int

	## 同一触发时刻的稳定声明序号。
	## [br]
	## @api private
	var _order: int

	## 触发时向项目发送的标记。
	## [br]
	## @api private
	var _cue: StringName

	## 相对会话起点的触发秒数。
	## [br]
	## @api private
	var _start: float

	## 本目标独立的局部秒数。
	## [br]
	## @api private
	var _span: float

	## 冻结的过渡曲线类型。
	## [br]
	## @api private
	var _transition: Tween.TransitionType

	## 冻结的缓动方向。
	## [br]
	## @api private
	var _easing: Tween.EaseType

	## 本轮使用的独立曲线副本。
	## [br]
	## @api private
	var _curve: Curve

	## 最近写入的归一化进度，负值表示未采样。
	## [br]
	## @api private
	var _sampled: float = -1.0

	## 正向播放已越过本目标的开始点。
	## [br]
	## @api private
	var _triggered: bool = false

	## 仅实播动作已启动且仍受宿主管理。
	## [br]
	## @api private
	var _action_running: bool = false

	## 项目本次执行返回的完成信号。
	## [br]
	## @api private
	var _completion: Signal

	## 连接使用的可调用对象，退出时按同一身份解除。
	## [br]
	## @api private
	var _on_completion: Callable


	# --- 框架内部方法 ---

	## 通过已有 Tween 两阶段替换协议撤销本轨道，以当前姿态交接。
	## [br]
	## @api framework_internal
	## [br]
	## @param lease: 失去的精确租约。
	## [br]
	## @return: 可通知的租约世代。
	func detach_replacement(lease: int) -> int:
		if (
			_retired
			or _lease != lease
			or not is_instance_valid(_player)
		):
			return 0
		_player._busy = true
		_player._forward_only = true
		_player._release_lane(self, GFUIMotionBinding.EndReason.REPLACED)
		_player._busy = false
		return lease


	## 其他目标继续播放，最后一条写入被接管后才结束旧会话。
	## [br]
	## @api framework_internal
	## [br]
	## @param _generation: 已经撤销的租约世代。
	func notify_replaced(_generation: int) -> void:
		if not is_instance_valid(_player) or not _player._active:
			return
		if _player._cancel_pending:
			_player.cancel()
			return
		for lane: _Lane in _player._lanes:
			if not lane._retired:
				return
		_player._busy = true
		_player._close(GFUIMotionBinding.EndReason.REPLACED)


	# --- 私有/辅助方法 ---

	## 实播动作可选择提供保留当前姿态的停止方法。
	## [br]
	## @api private
	func _pose_stop() -> Callable:
		var stop: Callable = Callable(_binding.action, &"stop_at_current_pose")
		return stop if stop.is_valid() and stop.get_argument_count() == 0 else Callable()
