## GFResourceServiceDomain：一个 Broker 及其消费者的稳定资源服务入口。
## 模式在 configure 时固定；主线程上请求、切换与 pump 串行执行。
## 受控切换暂停时明确拒绝新请求；在途热切换最多保留两代且不会重放已接纳工作。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFResourceServiceDomain
extends GFUtility


# --- 信号 ---

## 新请求入口完成统一换代；旧代结果仍按原请求交付。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param previous_generation: 原入口代次。
## [br]
## @param current_generation: 新入口代次。
signal generation_changed(previous_generation: int, current_generation: int)


# --- 枚举 ---

## 服务域初始化时固定的切换合同。
## [br]
## @api public
## [br]
## @since unreleased
enum Mode {
	## 稳定绑定：生命周期内固定 Broker。
	STABLE,
	## 受控切换：拒绝新请求，等待原代工作和所有权引用收尾后换代。
	CONTROLLED,
	## 在途热切换：新请求立即换代，旧代保留推进到全部所有权引用释放。
	IN_FLIGHT,
}


# --- 常量 ---

## 每代请求票据、句柄保留票据和租约的总预算。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_GENERATION_REFERENCES: int = 8192

## 原生后端身份；可切换域拒绝改写所有权协议的未知子类。
## [br]
## @api private
const _BROKER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_broker.gd")

## 此后端不访问全局 ResourceLoader，能力由实现身份而非自报布尔值证明。
## [br]
## @api private
const _SNAPSHOT_BROKER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_snapshot_broker.gd")


# --- 私有变量 ---

## 配置完成后不可修改的模式。
## [br]
## @api private
var _mode: Mode = Mode.STABLE

## 0 表示尚未配置；退出后不复用代次。
## [br]
## @api private
var _current_generation: int = 0

## 最多两代，每项保存 broker、租约弱引用和请求/句柄票据弱引用。
## [br]
## @api private
var _generations: Dictionary[int, Dictionary] = {}

## 在途热切换中已停止新准入但必须继续 pump 的原代。
## [br]
## @api private
var _retiring_generation: int = 0

## 受控切换中已验证、接管且没有发出任何资源请求的新实例。
## [br]
## @api private
var _candidate: GFResourceBroker = null

## 当前切换的一次性终态；失败不会伪造收尾成功。
## [br]
## @api private
var _switch_completion: GFAsyncCompletion = null

## 单调时间截止；只限制等待，不强制中止底层加载。
## [br]
## @api private
var _switch_deadline: int = 0

## 受控切换排空期间或失败后保持暂停，只有显式成功切换才恢复准入。
## [br]
## @api private
var _paused: bool = false

## 一旦关闭不再恢复准入。
## [br]
## @api private
var _closing: bool = false

## 关闭所有代次的完成源。
## [br]
## @api private
var _close_completion: GFAsyncCompletion = null

## 回调可重入但不能嵌套推进或启动第二次切换。
## [br]
## @api private
var _pumping: bool = false

## 仅异常 dispose 后尚未收尾时存在的局部树推进器。
## [br]
## @api private
var _retirement_guard: WeakRef = null


# --- GF 生命周期方法 ---

## 开启生命周期 tick；不会重置已经配置的域或模式。
## [br]
## @api public
## [br]
## @since unreleased
func init() -> void:
	ignore_pause = true
	tick_enabled = true


## 推进当前、旧代和切换等待。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 不用于期限计算。
func tick(_delta: float = 0.0) -> void:
	pump()


## 停止新接纳，继续完成已经接纳的本地队列、租约和引用释放。
## scope 取消只结束等待；未收尾实例仍需继续 pump，不能强杀加载器。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scope: 调用方的关闭期限与取消作用域。
## [br]
## @return 全部代次收尾后成功；取消不表示已物理退出。
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
	if _close_completion != null:
		return _close_completion
	_closing = true
	_close_completion = GFAsyncCompletion.new()
	if scope != null:
		var _bound: bool = _close_completion.bind_cancel_token(scope)
	_discard_candidate()
	if _switch_completion != null and _switch_completion.is_pending():
		var _failed: bool = _switch_completion.fail("resource_service_domain_closing")
	pump()
	return _close_completion


## 请求关闭并推进一次；尚未收尾且存在 SceneTree 时托管局部退出推进器。
## 没有 SceneTree 时，租约/句柄仍保留域，调用者须显式 pump。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	var _completion: GFAsyncCompletion = begin_quiesce(null)
	if not _generations.is_empty():
		_ensure_retirement_guard()


# --- 公共方法 ---

## 初始化域并接管一个全新 Broker。模式不能在运行中修改。
## 受控切换仅支持框架原生或快照后端；在途热切换仅支持框架快照后端，原生 threaded 后端拒绝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param broker: 已初始化、未被固定消费者使用且尚未注册进架构的实例。
## [br]
## @param mode: 域唯一模式，默认为 STABLE。
## [br]
## @return 已配置为 ERR_ALREADY_IN_USE，能力不满足为 ERR_UNAVAILABLE。
func configure(broker: GFResourceBroker, mode: Mode = Mode.STABLE) -> Error:
	if not Thread.is_main_thread():
		return ERR_UNAUTHORIZED
	if _current_generation != 0 or _closing:
		return ERR_ALREADY_IN_USE
	if (
		mode != Mode.STABLE
		and mode != Mode.CONTROLLED
		and mode != Mode.IN_FLIGHT
	):
		return ERR_INVALID_PARAMETER
	if not _supports_mode(broker, mode):
		return ERR_UNAVAILABLE
	var claim_error: Error = broker.claim_service_domain(self)
	if claim_error != OK:
		return claim_error
	_mode = mode
	_current_generation = 1
	_generations[1] = _make_generation(broker)
	init()
	return OK


## 读取固定模式。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 初始化选择的模式。
func get_mode() -> Mode:
	return _mode


## 读取新请求使用的代次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 未配置时为 0。
func get_current_generation() -> int:
	return _current_generation


## 判断当前入口是否接纳新工作；暂停期间不会无限排队。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且未暂停、未关闭时为 true。
func is_accepting_requests() -> bool:
	return (
		_current_generation > 0
		and not _closing
		and not _paused
	)


## 立即发起绑定当前代次的请求；旧结果仍通过返回租约读取。
## 已完成租约也需 release；只取 Resource 后释放租约表示资源已脱离服务所有权。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param path: 逻辑资源路径。
## [br]
## @param type_hint: 冻结类型提示。
## [br]
## @param options: Broker 准入选项。
## [br]
## @schema options: Dictionary with optional exclusive: bool, require_idle: bool, consumer_id: StringName.
## [br]
## @return 拒绝返回 failed Lease，绝不静默降级。
func request(
	path: String,
	type_hint: String = "",
	options: Dictionary = {}
) -> GFResourceLease:
	var reservation: GFResourceServiceReservation = reserve_for_framework(
		path,
		type_hint,
		options
	)
	if reservation == null:
		return _failed_lease("resource_service_not_accepting")
	var lease: GFResourceLease = reservation.start()
	reservation.release()
	return lease


## 准备并接管新代。受控切换等待旧代所有工作及引用释放后提交；在途热切换立即换入口后继续收尾旧代。
## 超时失败不会撤销已接纳工作，受控切换保持暂停，在途热切换保留新入口和旧代推进。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param broker: 全新且满足当前模式能力的已初始化实例。
## [br]
## @param timeout_msec: 收尾等待期限，范围 1–600000 毫秒。
## [br]
## @return 旧代安全退出后成功；拒绝或期限失败提供稳定错误文本。非主线程错误调用返回 null。
func begin_switch(broker: GFResourceBroker, timeout_msec: int = 30000) -> GFAsyncCompletion:
	if not Thread.is_main_thread():
		return null
	if _closing or _current_generation == 0:
		return _failed_completion("resource_service_domain_closing_or_unconfigured")
	if _mode == Mode.STABLE:
		return _failed_completion("resource_service_stable_mode")
	if (
		_pumping
		or _candidate != null
		or _retiring_generation != 0
		or (
			_switch_completion != null
			and _switch_completion.is_pending()
		)
	):
		return _failed_completion("resource_service_switch_busy")
	if timeout_msec < 1 or timeout_msec > 600000:
		return _failed_completion("resource_service_invalid_deadline")
	if not _supports_mode(broker, _mode) or not broker.can_claim_service_domain():
		return _failed_completion("resource_service_candidate_not_admissible")
	var claim_error: Error = broker.claim_service_domain(self)
	if claim_error != OK:
		return _failed_completion("resource_service_candidate_already_owned")
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	_switch_completion = completion
	_switch_deadline = Time.get_ticks_msec() + timeout_msec
	if _mode == Mode.CONTROLLED:
		_paused = true
		_candidate = broker
	else:
		_retiring_generation = _current_generation
		_current_generation += 1
		_generations[_current_generation] = _make_generation(broker)
		generation_changed.emit(_retiring_generation, _current_generation)
	return completion


## 推进全部存活代次并尝试收尾；关闭或超时后仍可调用，不强制销毁被引用对象。
## [br]
## @api public
## [br]
## @since unreleased
func pump() -> void:
	if _pumping or not Thread.is_main_thread():
		return
	_pumping = true
	for generation: int in _generations.keys():
		var broker: GFResourceBroker = _get_broker(generation)
		broker.pump()
		_prune_references(_generations[generation])
	if _closing:
		for generation: int in _generations.keys():
			if _can_retire(generation):
				_retire(generation)
		if (
			_generations.is_empty()
			and _close_completion != null
			and _close_completion.is_pending()
		):
			var _closed: bool = _close_completion.succeed()
	elif _switch_completion != null:
		if _switch_completion.is_pending() and Time.get_ticks_msec() >= _switch_deadline:
			_discard_candidate()
			var _timed_out: bool = _switch_completion.fail("resource_service_retirement_timeout")
		if _candidate != null and not _switch_completion.is_pending():
			_discard_candidate()
		if _candidate != null and _can_retire(_current_generation):
			var previous: int = _current_generation
			_retire(previous)
			_current_generation += 1
			_generations[_current_generation] = _make_generation(_candidate)
			_candidate = null
			_paused = false
			generation_changed.emit(previous, _current_generation)
			if not _closing:
				var _switched: bool = _switch_completion.succeed()
		elif _retiring_generation != 0 and _can_retire(_retiring_generation):
			_retire(_retiring_generation)
			_retiring_generation = 0
			if _switch_completion.is_pending():
				var _retired: bool = _switch_completion.succeed()
	_pumping = false


## 域稳定入口不能通过架构移除后重新注册来绕过模式合同。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 始终 false；架构整体关闭仍允许。
func can_remove_from_active_lifecycle() -> bool:
	return false


## 读取有界代次与等待诊断，不暴露可变 Broker 实例。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前入口与收尾状态。
## [br]
## @schema return: Dictionary with mode: int, current_generation: int, retiring_generation: int, live_generations: int, paused: bool, closing: bool, accepting: bool, retirement_pump: String, retirement_reason: String, generations: Array[Dictionary] containing generation: int, references: int, idle: bool.
func get_debug_snapshot() -> Dictionary:
	var generations: Array[Dictionary] = []
	for generation: int in _generations:
		var record: Dictionary = _generations[generation]
		_prune_references(record)
		generations.append(
			{
				"generation": generation,
				"references": _reference_count(record),
				"idle": _get_broker(generation).is_idle(),
			}
		)
	return {
		"mode": _mode,
		"current_generation": _current_generation,
		"retiring_generation": _retiring_generation,
		"live_generations": _generations.size(),
		"paused": _paused,
		"closing": _closing,
		"accepting": is_accepting_requests(),
		"retirement_pump": "scene_tree" if _has_retirement_guard() else "caller",
		"retirement_reason": "outstanding_requests_or_references" if _closing and not _generations.is_empty() else "",
		"generations": generations,
	}


# --- 框架内部方法 ---

## 退出推进器只在所有代次物理退出后解除其强所有权。
## [br]
## @api framework_internal
## [br]
## @return 仍有请求或所有权引用时为 true。
func has_live_generations_for_framework() -> bool:
	return not _generations.is_empty()


## 在 Asset 本地排队之前捕获代次；暂停时返回 null，不接纳隐藏队列。
## [br]
## @api framework_internal
## [br]
## @param path: 冻结路径。
## [br]
## @param type_hint: 冻结类型提示。
## [br]
## @param options: 准入选项的独立快照。
## [br]
## @schema options: Dictionary with optional exclusive: bool, require_idle: bool, consumer_id: StringName.
## [br]
## @return 原代请求票据；未准入返回 null。
func reserve_for_framework(
	path: String,
	type_hint: String,
	options: Dictionary
) -> GFResourceServiceReservation:
	if not Thread.is_main_thread() or not is_accepting_requests():
		return null
	var admission: Dictionary = {
		"exclusive": GFVariantData.get_option_bool(options, "exclusive"),
		"require_idle": GFVariantData.get_option_bool(options, "require_idle"),
		"consumer_id": GFVariantData.get_option_string_name(options, "consumer_id"),
	}
	return _retain(
		_current_generation,
		{
			"path": path,
			"type_hint": type_hint,
			"options": admission,
		}
	)


## 为已接纳请求或已交付句柄保留原代；不能创建新的请求载荷。
## [br]
## @api framework_internal
## [br]
## @param generation: 仍存活的固定代次。
## [br]
## @return 保留票据；预算耗尽或代次已退出时返回 null。
func retain_generation_for_framework(generation: int) -> GFResourceServiceReservation:
	return _retain(generation, {})


## 消费属于本域的单次请求票据，不能把其他域或旧已释放票据送入当前 Broker。
## [br]
## @api framework_internal
## [br]
## @param reservation: 本域记录中的票据。
## [br]
## @param payload: 票据冻结的请求。
## [br]
## @schema payload: Dictionary with path: String, type_hint: String, options: Dictionary.
## [br]
## @return 固定到票据代次的租约。
func start_reservation_for_framework(reservation: GFResourceServiceReservation, payload: Dictionary) -> GFResourceLease:
	var generation: int = reservation.get_generation()
	if not _generations.has(generation) or reservation.is_released():
		return _failed_lease("resource_service_generation_retired")
	var record: Dictionary = _generations[generation]
	var references: Array = record["references"]
	var found: bool = false
	for weak_reference: WeakRef in references:
		if weak_reference.get_ref() == reservation:
			found = true
	if not found:
		return _failed_lease("resource_service_reservation_foreign")
	_prune_references(record)
	if _reference_count(record) >= MAX_GENERATION_REFERENCES:
		return _failed_lease("resource_service_reference_budget")
	var lease: GFResourceLease = (
		_get_broker(generation).request_for_service_domain(
			self,
			GFVariantData.get_option_string(payload, "path"),
			GFVariantData.get_option_string(payload, "type_hint"),
			GFVariantData.get_option_dictionary(payload, "options")
		)
	)
	lease.bind_service_generation(generation, self)
	references.append(weakref(lease))
	return lease


# --- 私有/辅助方法 ---

## dispose 幂等地转交未完成退出的推进责任，不更改 scope 终态或加载结果。
## [br]
## @api private
func _ensure_retirement_guard() -> void:
	if _has_retirement_guard() or not Thread.is_main_thread():
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return
	var tree: SceneTree = loop
	if (
		tree.root == null
		or not tree.root.is_inside_tree()
		or tree.root.is_queued_for_deletion()
	):
		return
	var guard: GFResourceServiceRetirement = GFResourceServiceRetirement.new()
	guard.bind(self)
	_retirement_guard = weakref(guard)
	tree.root.add_child(guard)


## 树退出后弱引用不构成仍有自动推进的虚假保证。
## [br]
## @api private
func _has_retirement_guard() -> bool:
	if _retirement_guard == null:
		return false
	var value: Object = _retirement_guard.get_ref()
	if value is GFResourceServiceRetirement:
		var guard: GFResourceServiceRetirement = value
		return guard.is_inside_tree() and not guard.is_queued_for_deletion()
	return false


## 只认可框架已实现的所有权和后端隔离，不采用调用方自报能力布尔值。
## [br]
## @api private
func _supports_mode(broker: GFResourceBroker, mode: Mode) -> bool:
	if broker == null:
		return false
	if broker is GFResourceSnapshotBroker:
		var configured_broker: GFResourceSnapshotBroker = broker
		if not configured_broker.is_configured():
			return false
	if mode == Mode.STABLE:
		return true
	if broker.get_script() == _SNAPSHOT_BROKER_SCRIPT and broker is GFResourceSnapshotBroker:
		var snapshot_broker: GFResourceSnapshotBroker = broker
		return snapshot_broker.is_configured()
	return mode == Mode.CONTROLLED and broker.get_script() == _BROKER_SCRIPT


## 以弱引用记录外部所有权，避免未显式 release 的已丢弃句柄形成永久环。
## [br]
## @api private
func _make_generation(broker: GFResourceBroker) -> Dictionary:
	return { "broker": broker, "references": [] }


## 不改变请求准入，只保留已经存在的代次。
## [br]
## @api private
func _retain(generation: int, request_payload: Dictionary) -> GFResourceServiceReservation:
	if not _generations.has(generation):
		return null
	var record: Dictionary = _generations[generation]
	_prune_references(record)
	if _reference_count(record) >= MAX_GENERATION_REFERENCES - 1:
		return null
	var reservation: GFResourceServiceReservation = GFResourceServiceReservation.new()
	reservation.bind(
		self,
		generation,
		request_payload
	)
	var references: Array = record["references"]
	references.append(weakref(reservation))
	return reservation


## 返回由域强引用持有的原代 Broker。
## [br]
## @api private
func _get_broker(generation: int) -> GFResourceBroker:
	var broker: GFResourceBroker = _generations[generation]["broker"]
	return broker


## 已释放或不再被调用者持有的票据不继续阻止退休。
## [br]
## @api private
func _prune_references(record: Dictionary) -> void:
	var references: Array = record["references"]
	for index: int in range(
		references.size() - 1,
		-1,
		-1
	):
		var weak_reference: WeakRef = references[index]
		var object: Object = weak_reference.get_ref()
		if object == null:
			references.remove_at(index)
		elif object is GFResourceServiceReservation:
			var reservation: GFResourceServiceReservation = object
			if reservation.is_released():
				references.remove_at(index)
		elif object is GFResourceLease:
			var lease: GFResourceLease = object
			if lease.is_released():
				references.remove_at(index)


## 同一预算同时覆盖排队工作、租约和句柄保留。
## [br]
## @api private
func _reference_count(record: Dictionary) -> int:
	var references: Array = record["references"]
	return references.size()


## idle 仅是必要条件，仍须所有请求与资源所有权票据释放。
## [br]
## @api private
func _can_retire(generation: int) -> bool:
	return (
		_generations.has(generation)
		and _get_broker(generation).is_idle()
		and _reference_count(_generations[generation]) == 0
	)


## 仅在安全条件满足后释放代次；底层未收尾从不强制 dispose。
## [br]
## @api private
func _retire(generation: int) -> void:
	var _disposed: bool = _get_broker(generation).dispose_for_service_domain(self)
	var _erased: bool = _generations.erase(generation)


## 受控切换的候选尚未接单，可以在失败或关闭时安全丢弃。
## [br]
## @api private
func _discard_candidate() -> void:
	if _candidate != null:
		var _disposed: bool = _candidate.dispose_for_service_domain(self)
		_candidate = null


## 拒绝结果不隐式选择其他模式。
## [br]
## @api private
func _failed_completion(reason: String) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail(reason)
	return completion


## 请求拒绝仍沿用现有 Lease 终态合同。
## [br]
## @api private
func _failed_lease(reason: String) -> GFResourceLease:
	var lease: GFResourceLease = GFResourceLease.new()
	lease.broker_mark_failed(ERR_UNAVAILABLE, reason)
	return lease
