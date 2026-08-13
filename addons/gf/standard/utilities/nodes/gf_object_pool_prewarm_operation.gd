## GFObjectPoolPrewarmOperation: 单次异步对象池预热请求句柄。
##
## Operation 冻结请求身份并跟踪最终有效的容量准入和实时进度，只接受一个类型化终态。同步校验、
## 零工作或同步退化请求可能在入口返回前完成；调用方应先查询 `is_completed()`。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
## [br]
## @layer standard/utilities/nodes
class_name GFObjectPoolPrewarmOperation
extends RefCounted


# --- 信号 ---

## 已处理数量增加时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param operation: 当前规范 Operation。
signal progressed(operation: GFObjectPoolPrewarmOperation)

## 请求进入唯一终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 当前请求的隔离终态结果。
signal completed(result: GFObjectPoolPrewarmResult)


# --- 私有变量 ---

var _request_id: int = 0
var _scene_ref: WeakRef = null
var _scene_identity: String = ""
var _requested_count: int = 0
var _admitted_count: int = 0
var _created_count: int = 0
var _skipped_count: int = 0
var _cancelled_count: int = 0
var _failed_count: int = 0
var _result: GFObjectPoolPrewarmResult = null
var _cancel_delegate: GFWeakMethodInvocation = null
var _settlement_authority: RefCounted = null
var _cancel_requested: bool = false
var _completed_signal_emitted: bool = false
var _progress_notification_depth: int = 0
var _settlement_barrier_active: bool = false
var _pending_terminal_result: GFObjectPoolPrewarmResult = null
var _pending_final_cancelled_count: int = 0
var _pending_final_failed_count: int = 0


# --- 公共方法 ---

## 取消等待中的请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Utility 首次接受 caller 取消时返回 true。
func cancel() -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or not _has_unresolved_admitted_count()
		or _cancel_delegate == null
		or _cancel_requested
	):
		return false
	_cancel_requested = true
	var result: Dictionary = _cancel_delegate.invoke(
		[self, GFObjectPoolPrewarmResult.REASON_CALLER_CANCELLED]
	)
	var accepted: bool = _invocation_returned_true(result)
	if not accepted and is_pending():
		_cancel_requested = false
	return accepted


## 获取 Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取仍存活的 PackedScene。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求场景；已释放时返回 null。
func get_scene() -> PackedScene:
	if _scene_ref == null:
		return null
	var value: Variant = _scene_ref.get_ref()
	if value is PackedScene and is_instance_valid(value):
		var scene: PackedScene = value
		return scene
	return null


## 获取冻结的场景身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 资源路径或实例 ID 身份。
func get_scene_identity() -> String:
	return _scene_identity


## 检查请求是否仍等待终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且未完成时返回 true。
func is_pending() -> bool:
	return _request_id > 0 and _result == null


## 检查请求是否已经进入终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取请求数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负请求数量。
func get_requested_count() -> int:
	return _requested_count


## 获取当前有效的容量准入数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负且不大于 requested 的数量；运行期容量复核可在终态前减少该值。
func get_admitted_count() -> int:
	return _admitted_count


## 获取成功创建数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已提交节点数量。
func get_created_count() -> int:
	return _created_count


## 获取未获准入或因运行期容量复核而跳过的数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `requested - admitted`。
func get_skipped_count() -> int:
	return _skipped_count


## 获取取消数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前已归类取消的单位数。
func get_cancelled_count() -> int:
	return _cancelled_count


## 获取失败数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前已归类失败的单位数。
func get_failed_count() -> int:
	return _failed_count


## 获取已处理数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return created、skipped、cancelled 与 failed 的总和。
func get_processed_count() -> int:
	return _created_count + _skipped_count + _cancelled_count + _failed_count


## 获取尚未进入 disposition 的数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `requested - processed`。
func get_remaining_count() -> int:
	return maxi(_requested_count - get_processed_count(), 0)


## 获取标准化进度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 0.0 到 1.0；零工作为 1.0。
func get_progress_ratio() -> float:
	if _requested_count <= 0:
		return 1.0
	return clampf(float(get_processed_count()) / float(_requested_count), 0.0, 1.0)


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFObjectPoolPrewarmResult:
	return _result.duplicate_result() if _result != null else null


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求身份、实时计数、进度和可选终态。
## [br]
## @schema return: Exact Dictionary with request_id, scene_identity, pending, completed, requested_count, admitted_count, created_count, skipped_count, cancelled_count, failed_count, processed_count, remaining_count, progress_ratio, and result fields.
func get_debug_snapshot() -> Dictionary:
	return {
		"request_id": _request_id,
		"scene_identity": _scene_identity,
		"pending": is_pending(),
		"completed": is_completed(),
		"requested_count": _requested_count,
		"admitted_count": _admitted_count,
		"created_count": _created_count,
		"skipped_count": _skipped_count,
		"cancelled_count": _cancelled_count,
		"failed_count": _failed_count,
		"processed_count": get_processed_count(),
		"remaining_count": get_remaining_count(),
		"progress_ratio": get_progress_ratio(),
		"result": _result.to_dict() if _result != null else {},
	}


# --- 框架内部方法 ---

## 由 Object Pool Utility 冻结请求身份和弱取消委托。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param cancel_delegate: Utility 方法，签名为 `(operation, reason) -> bool`。
## [br]
## @param settlement_authority: 仅由所属 Utility 持有的终态 barrier 权限。
## [br]
## @param request_id: Utility 内唯一请求 ID。
## [br]
## @param scene: 请求 PackedScene。
## [br]
## @param requested_count: 非负请求数量。
## [br]
## @param admitted_count: 初始容量准入数量；运行期容量复核可收窄该值。
## [br]
## @return 首次完整配置成功返回 true。
func configure_for_framework(
	cancel_delegate: Callable,
	settlement_authority: RefCounted,
	request_id: int,
	scene: PackedScene,
	requested_count: int,
	admitted_count: int
) -> bool:
	if (
		not Thread.is_main_thread()
		or _request_id != 0
		or settlement_authority == null
		or request_id <= 0
		or requested_count < 0
		or admitted_count < 0
		or admitted_count > requested_count
	):
		return false
	var invocation: GFWeakMethodInvocation = _make_weak_invocation(cancel_delegate)
	if invocation == null:
		return false
	_request_id = request_id
	_scene_ref = weakref(scene) if scene != null else null
	_scene_identity = _make_scene_identity(scene)
	_requested_count = requested_count
	_admitted_count = admitted_count
	_skipped_count = requested_count - admitted_count
	_cancel_delegate = invocation
	_settlement_authority = settlement_authority
	return true


## 在不触碰 Utility 运行时状态的线程上冻结同步拒绝终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param request_id: Utility 内线程安全分配的唯一请求 ID。
## [br]
## @param requested_count: 非负请求数量。
## [br]
## @param status: 仅允许不依赖 Utility 运行时状态的同步终态。
## [br]
## @param reason: 与 status 对应的原因。
## [br]
## @param error_code: 与 status/reason 对应的 Error。
## [br]
## @return 首次完整配置成功返回 true。
func configure_terminal_for_framework(
	request_id: int,
	requested_count: int,
	status: GFObjectPoolPrewarmResult.Status,
	reason: StringName,
	error_code: Error
) -> bool:
	if _request_id != 0 or request_id <= 0 or requested_count < 0:
		return false
	var result: GFObjectPoolPrewarmResult = GFObjectPoolPrewarmResult.new()
	if not result.configure_for_framework(
		status,
		request_id,
		"",
		requested_count,
		0,
		0,
		requested_count,
		0,
		0,
		reason,
		error_code
	):
		return false
	_request_id = request_id
	_requested_count = requested_count
	_skipped_count = requested_count
	_result = result
	_completed_signal_emitted = true
	return true


## 将尚未提交的容量准入改归为 skipped。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param settlement_authority: 配置时由所属 Utility 冻结的同一权限对象。
## [br]
## @return 仍有未处理准入单位时更新成功返回 true。
func record_capacity_skipped_for_framework(settlement_authority: RefCounted) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or _pending_terminal_result != null
		or settlement_authority == null
		or settlement_authority != _settlement_authority
		or not _has_unresolved_admitted_count()
	):
		return false
	var skipped_delta: int = _admitted_count - _created_count - _cancelled_count - _failed_count
	_admitted_count -= skipped_delta
	_skipped_count += skipped_delta
	_emit_progress_notification()
	return true


## 记录一个已成功提交的候选并发出进度。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param settlement_authority: 配置时由所属 Utility 冻结的同一权限对象。
## [br]
## @return 仍有未处理准入单位时首次记录成功返回 true。
func record_created_for_framework(settlement_authority: RefCounted) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or _pending_terminal_result != null
		or settlement_authority == null
		or settlement_authority != _settlement_authority
		or not _has_unresolved_admitted_count()
	):
		return false
	_created_count += 1
	_emit_progress_notification()
	return true


## 延迟终态发布，直到 Utility 已经清理当前 provisional candidate。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param settlement_authority: 配置时由所属 Utility 冻结的同一权限对象。
## [br]
## @return 所属 Utility 首次进入 barrier 时返回 true。
func begin_settlement_barrier_for_framework(settlement_authority: RefCounted) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or _pending_terminal_result != null
		or _settlement_barrier_active
		or settlement_authority == null
		or settlement_authority != _settlement_authority
	):
		return false
	_settlement_barrier_active = true
	return true


## 退出 Utility provisional candidate barrier，并在最外层退出后发布待定终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param settlement_authority: 与 begin 使用的同一 Utility 权限对象。
## [br]
## @return 所属 Utility 成功匹配活动 barrier 时返回 true。
func end_settlement_barrier_for_framework(settlement_authority: RefCounted) -> bool:
	if (
		not Thread.is_main_thread()
		or not _settlement_barrier_active
		or settlement_authority == null
		or settlement_authority != _settlement_authority
	):
		return false
	_settlement_barrier_active = false
	_flush_pending_terminal_if_possible()
	return true


## 冻结并发出唯一终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param settlement_authority: 配置时由所属 Utility 冻结的同一权限对象。
## [br]
## @param status: Result 唯一终态。
## [br]
## @param reason: 与 status 对应的原因。
## [br]
## @param error_code: 与 status/reason 对应的 Error。
## [br]
## @return 首次合法完成返回 true。
func finish_for_framework(
	settlement_authority: RefCounted,
	status: GFObjectPoolPrewarmResult.Status,
	reason: StringName,
	error_code: Error
) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or _pending_terminal_result != null
		or settlement_authority == null
		or settlement_authority != _settlement_authority
	):
		return false
	var unresolved_admitted: int = maxi(
		_admitted_count - _created_count - _cancelled_count - _failed_count,
		0
	)
	var final_cancelled_count: int = _cancelled_count
	var final_failed_count: int = _failed_count
	if status in [
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.Status.DISPOSED,
	]:
		final_cancelled_count += unresolved_admitted
	elif status == GFObjectPoolPrewarmResult.Status.FAILED:
		final_failed_count += unresolved_admitted
	elif unresolved_admitted != 0:
		return false
	var result: GFObjectPoolPrewarmResult = GFObjectPoolPrewarmResult.new()
	if not result.configure_for_framework(
		status,
		_request_id,
		_scene_identity,
		_requested_count,
		_admitted_count,
		_created_count,
		_skipped_count,
		final_cancelled_count,
		final_failed_count,
		reason,
		error_code
	):
		return false
	_cancel_delegate = null
	if _progress_notification_depth > 0 or _settlement_barrier_active:
		_pending_terminal_result = result
		_pending_final_cancelled_count = final_cancelled_count
		_pending_final_failed_count = final_failed_count
		return true
	_commit_terminal_result(result, final_cancelled_count, final_failed_count)
	return true


## 发出已冻结的唯一完成通知。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @return 首次通知返回 true。
func emit_completed_for_framework() -> bool:
	if (
		not Thread.is_main_thread()
		or not is_completed()
		or _completed_signal_emitted
		or _progress_notification_depth > 0
	):
		return false
	_completed_signal_emitted = true
	completed.emit(_result.duplicate_result())
	return true


# --- 私有/辅助方法 ---

func _emit_progress_notification() -> void:
	_progress_notification_depth += 1
	progressed.emit(self)
	_progress_notification_depth -= 1
	_flush_pending_terminal_if_possible()


func _flush_pending_terminal_if_possible() -> void:
	if (
		_progress_notification_depth > 0
		or _settlement_barrier_active
		or _pending_terminal_result == null
	):
		return
	var pending_result: GFObjectPoolPrewarmResult = _pending_terminal_result
	var pending_cancelled_count: int = _pending_final_cancelled_count
	var pending_failed_count: int = _pending_final_failed_count
	_pending_terminal_result = null
	_pending_final_cancelled_count = 0
	_pending_final_failed_count = 0
	_commit_terminal_result(
		pending_result,
		pending_cancelled_count,
		pending_failed_count
	)


func _commit_terminal_result(
	result: GFObjectPoolPrewarmResult,
	final_cancelled_count: int,
	final_failed_count: int
) -> void:
	var previous_processed_count: int = get_processed_count()
	_cancelled_count = final_cancelled_count
	_failed_count = final_failed_count
	_result = result
	_settlement_authority = null
	if get_processed_count() > previous_processed_count:
		_emit_progress_notification()
	var _completed_emitted: bool = emit_completed_for_framework()

static func _make_weak_invocation(delegate: Callable) -> GFWeakMethodInvocation:
	if not delegate.is_valid() or delegate.get_bound_arguments_count() != 0:
		return null
	var owner: Object = delegate.get_object()
	var method_name: StringName = delegate.get_method()
	if owner == null or not is_instance_valid(owner) or method_name.is_empty():
		return null
	return GFWeakMethodInvocation.new(owner, method_name)


static func _invocation_returned_true(result: Dictionary) -> bool:
	var invoked_value: Variant = result.get("invoked", false)
	var return_value: Variant = result.get("value", false)
	return (
		invoked_value is bool
		and invoked_value
		and return_value is bool
		and return_value
	)


func _has_unresolved_admitted_count() -> bool:
	return _created_count + _cancelled_count + _failed_count < _admitted_count


static func _make_scene_identity(scene: PackedScene) -> String:
	if scene == null:
		return ""
	if not scene.resource_path.is_empty():
		return scene.resource_path
	return "PackedScene:%d" % scene.get_instance_id()
