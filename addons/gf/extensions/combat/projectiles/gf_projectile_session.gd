## GFProjectileSession: 一次 typed projectile 发射的运行期句柄。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFProjectileSession
extends RefCounted


# --- 信号 ---

## session 首次进入 FINISHED 时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param session: 已结算的同一 session。
## [br]
## @param reason: `EndReason` 枚举值。
signal finished(session: GFProjectileSession, reason: int)


# --- 枚举 ---

## 定义 session 的空间维度。
## [br]
## @api public
## [br]
## @since unreleased
enum Dimension {
	## 2D runtime、adapter 与 motion。
	TWO_D = 0,
	## 3D runtime、adapter 与 motion。
	THREE_D = 1,
}


## 定义 session 的封闭生命周期状态。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 尚未由 runtime 激活。
	UNCONFIGURED = 0,
	## 正在接受 motion、impact 与 lifetime 更新。
	ACTIVE = 1,
	## 已以 first-wins 原因结算。
	FINISHED = 2,
}


## 定义首次结束 session 的稳定原因。
## [br]
## @api public
## [br]
## @since unreleased
enum EndReason {
	## 尚未结束。
	NONE = 0,
	## 调用方显式结束。
	CALLER_FINISHED = 1,
	## 达到最大活动时长。
	LIFETIME_SECONDS = 2,
	## 达到累计实际位移上限。
	LIFETIME_DISTANCE = 3,
	## 达到已接受 impact 上限。
	LIFETIME_IMPACTS = 4,
	## 自定义 lifetime hook 请求结束。
	LIFETIME_CUSTOM = 5,
	## Motion 正常请求结束。
	MOTION_FINISHED = 6,
	## 必需目标已丢失。
	TARGET_LOST = 7,
	## Motion 返回不可应用 intent。
	INVALID_MOTION_INTENT = 8,
	## Motion state 或计算失败。
	MOTION_FAILED = 9,
	## Body adapter 捕获或应用失败。
	BODY_APPLICATION_FAILED = 10,
	## 完整实例 root 已丢失。
	ROOT_LOST = 11,
	## Runtime 已丢失。
	RUNTIME_LOST = 12,
	## 显式 impact source topology 已丢失。
	IMPACT_SOURCE_LOST = 13,
	## Emitter 或 allocator 主动释放。
	EMITTER_RELEASED = 14,
	## 无法归类的框架内部失败。
	INTERNAL_FAILURE = 15,
}


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 私有变量 ---

var _status: Status = Status.UNCONFIGURED
var _dimension: Dimension = Dimension.TWO_D
var _generation: int = 0
var _root_ref: WeakRef = null
var _runtime_ref: WeakRef = null
var _body_adapter: Resource = null
var _elapsed_seconds: float = 0.0
var _travelled_distance: float = 0.0
var _accepted_impact_count: int = 0
var _end_reason: EndReason = EndReason.NONE
var _metadata: Dictionary = {}
var _notification_barrier_depth: int = 0
var _finished_notification_pending: bool = false
var _terminal_body_observation_recorded: bool = false


# --- 公共方法 ---

## 返回当前生命周期状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 封闭 `Status` 值。
func get_status() -> Status:
	return _status


## 返回空间维度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: TWO_D 或 THREE_D。
func get_dimension() -> Dimension:
	return _dimension


## 返回 runtime 分配的单调 generation。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 激活后为正数。
func get_generation() -> int:
	return _generation


## 返回完整实例 root。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: live root；释放后为 null。
func get_instance_root() -> Node:
	return _node_from_ref(_root_ref)


## 返回本次 session 的 runtime。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: live runtime；释放后为 null。
func get_runtime() -> Node:
	return _node_from_ref(_runtime_ref)


## 返回累计活动时长。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 非负秒数。
func get_elapsed_seconds() -> float:
	return _elapsed_seconds


## 返回累计实际 world displacement 长度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 非负累计距离，不是起点到当前位置净距离。
func get_travelled_distance() -> float:
	return _travelled_distance


## 返回被当前 generation 接受的 impact 数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 非负计数。
func get_accepted_impact_count() -> int:
	return _accepted_impact_count


## 返回首次结束原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: ACTIVE 时为 NONE，FINISHED 时为冻结原因。
func get_end_reason() -> EndReason:
	return _end_reason


## 返回 launch metadata 深副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 可由调用方修改的独立 metadata。
## [br]
## @schema return: Dictionary，激活时冻结的项目 metadata 深副本。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 判断 session 是否仍 ACTIVE。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前状态为 ACTIVE 时为 true。
func is_active() -> bool:
	return _status == Status.ACTIVE


## 判断 session 是否已结算。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前状态为 FINISHED 时为 true。
func is_finished() -> bool:
	return _status == Status.FINISHED


## 以 first-wins 语义结束 session，并 best-effort 要求 adapter 停止 body。
## stop 在 reason 冻结后执行，其结果不会改写本次既有终结原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 非 NONE 的结束原因。
## [br]
## @return: 本调用是否首次完成结算。
func finish(reason: EndReason = EndReason.CALLER_FINISHED) -> bool:
	if _status != Status.ACTIVE or reason == EndReason.NONE:
		return false
	_status = Status.FINISHED
	_end_reason = reason
	_stop_body_once()
	if _notification_barrier_depth > 0:
		_finished_notification_pending = true
	else:
		finished.emit(self, reason)
	return true

# --- 框架内部方法 ---

## 由 runtime 原子激活 session。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param dimension: 本次 session 的空间维度。
## [br]
## @param generation: runtime 分配的正 generation。
## [br]
## @param instance_root: 完整实例 root。
## [br]
## @param runtime: 本次激活的 runtime。
## [br]
## @param body_adapter: dimension-specific body adapter。
## [br]
## @param metadata: 调用方 metadata 的深快照。
## [br]
## @return: 激活结果；非初始状态或无效参数返回错误。
## [br]
## @schema metadata: Dictionary，调用方 metadata 的深快照。
func activate_for_framework(
	dimension: Dimension,
	generation: int,
	instance_root: Node,
	runtime: Node,
	body_adapter: Resource,
	metadata: Dictionary
) -> Error:
	if (
		_status != Status.UNCONFIGURED
		or generation <= 0
		or instance_root == null
		or not is_instance_valid(instance_root)
		or instance_root.is_queued_for_deletion()
		or runtime == null
		or not is_instance_valid(runtime)
		or runtime.is_queued_for_deletion()
		or body_adapter == null
		or not is_instance_valid(body_adapter)
	):
		return ERR_INVALID_PARAMETER
	_dimension = dimension
	_generation = generation
	_root_ref = weakref(instance_root)
	_runtime_ref = weakref(runtime)
	_body_adapter = body_adapter
	_metadata = metadata.duplicate(true)
	_status = Status.ACTIVE
	return OK


## 累加一帧真实运行期观测。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param delta: 本帧有限非负秒数。
## [br]
## @param displacement_length: adapter 返回的有限非负实际位移长度。
## 两项累计值必须保持有限；溢出会以 INTERNAL_FAILURE 结束且保留最后有限快照。
func advance_for_framework(delta: float, displacement_length: float) -> void:
	if _status != Status.ACTIVE:
		return
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(displacement_length)
		or delta < 0.0
		or displacement_length < 0.0
	):
		var _invalid_observation: bool = finish(EndReason.INTERNAL_FAILURE)
		return
	var next_elapsed_seconds: float = _elapsed_seconds + delta
	var next_travelled_distance: float = _travelled_distance + displacement_length
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(next_elapsed_seconds)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(next_travelled_distance)
	):
		var _overflowed_observation: bool = finish(EndReason.INTERNAL_FAILURE)
		return
	_elapsed_seconds = next_elapsed_seconds
	_travelled_distance = next_travelled_distance


## 记录 adapter apply 回调内同步结束后返回的最后一次 body 观测。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param generation: 发起 apply 的同一 session generation。
## [br]
## @param delta: 最后一次 apply 对应的有限非负秒数。
## [br]
## @param displacement_length: apply 已产生的有限非负实际位移长度。
## [br]
## @return: 同 generation 的首次有限 terminal 观测被记录时为 OK；累计溢出返回 ERR_INVALID_DATA。
func advance_terminal_body_result_for_framework(
	generation: int,
	delta: float,
	displacement_length: float
) -> Error:
	if (
		_status != Status.FINISHED
		or generation != _generation
		or _terminal_body_observation_recorded
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(displacement_length)
		or delta < 0.0
		or displacement_length < 0.0
	):
		return ERR_INVALID_DATA
	var next_elapsed_seconds: float = _elapsed_seconds + delta
	var next_travelled_distance: float = _travelled_distance + displacement_length
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(next_elapsed_seconds)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(next_travelled_distance)
	):
		return ERR_INVALID_DATA
	_terminal_body_observation_recorded = true
	_elapsed_seconds = next_elapsed_seconds
	_travelled_distance = next_travelled_distance
	return OK


## 记录一次被 source 接受的 impact。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func accept_impact_for_framework() -> void:
	if _status == Status.ACTIVE:
		_accepted_impact_count += 1


## 延迟 terminal notification，供 emitter 批次发布建立 started-before-finished 顺序。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: ACTIVE 时建立一层 barrier 并返回 OK，否则返回错误。
func begin_notification_barrier_for_framework() -> Error:
	if _status != Status.ACTIVE:
		return ERR_INVALID_PARAMETER
	_notification_barrier_depth += 1
	return OK


## 释放一层 terminal notification barrier。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 成功释放一层 barrier 时返回 OK，否则返回错误。
func release_notification_barrier_for_framework() -> Error:
	if _notification_barrier_depth <= 0:
		return ERR_INVALID_PARAMETER
	_notification_barrier_depth -= 1
	if _notification_barrier_depth == 0 and _finished_notification_pending:
		_finished_notification_pending = false
		finished.emit(self, _end_reason)
	return OK


# --- 私有/辅助方法 ---

func _stop_body_once() -> void:
	var root: Node = get_instance_root()
	if root == null or _body_adapter == null or not is_instance_valid(_body_adapter):
		return
	if _dimension == Dimension.TWO_D and _body_adapter is GFProjectileBodyAdapter2D:
		var adapter_2d: GFProjectileBodyAdapter2D = _body_adapter
		var _stop_result_2d: Variant = adapter_2d.stop(root)
	elif _dimension == Dimension.THREE_D and _body_adapter is GFProjectileBodyAdapter3D:
		var adapter_3d: GFProjectileBodyAdapter3D = _body_adapter
		var _stop_result_3d: Variant = adapter_3d.stop(root)


func _node_from_ref(weak_reference: WeakRef) -> Node:
	if weak_reference == null:
		return null
	var value: Variant = weak_reference.get_ref()
	if value is Node:
		var node: Node = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null
