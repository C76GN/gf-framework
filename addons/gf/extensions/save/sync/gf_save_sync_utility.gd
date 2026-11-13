## GFSaveSyncUtility: 将通用版本同步组合到受管 Profile 事务。
##
## prepare_profile() 必须早于目标 Profile 的加载或保存；同步使用最近已确认的完整
## 文档。业务修改须通过 Profile 保存或事务持久化，不从未登记的内存改动猜测代际。
## 账号会话冻结到一个 Profile、namespace、key 和 Transport；不自动合并游客数据。
## Journal 与下载应用复用既有 Coordinator，网络等待期间不占用业务事务。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSaveSyncUtility
extends GFUtility


# --- 常量 ---

## 框架 checkpoint 与上传剥离规则。
## [br]
## @api private
const _CHECKPOINT_SCRIPT = preload("res://addons/gf/extensions/save/sync/gf_save_sync_checkpoint.gd")


# --- 私有变量 ---

## 保存文档和内容代际的唯一权威。
## [br]
## @api private
var _profiles: GFSaveProfileUtility = null

## 本地业务事务协调器。
## [br]
## @api private
var _coordinator: GFSaveProfileTransactionCoordinator = null

## 项目显式的字段所有权投影。
## [br]
## @api private
var _projection: GFSaveSyncProjection = null

## 远端观察截止时间。
## [br]
## @api private
var _clock: GFClock = null

## 当前会话唯一的通用同步引擎。
## [br]
## @api private
var _engine: GFStorageSyncUtility = null

## 当前会话 Profile。
## [br]
## @api private
var _profile_id: StringName = &""

## 当前会话远端命名空间。
## [br]
## @api private
var _namespace: String = ""

## 当前会话远端记录键。
## [br]
## @api private
var _record_key: String = ""

## 会话替换时递增，迟到回调不得跨代写入。
## [br]
## @api private
var _epoch: int = 0

## 观察与本地事务的实例内序号。
## [br]
## @api private
var _serial: int = 0

## 当前对外观察；同一会话同时只允许一个。
## [br]
## @api private
var _current: _Observation = null

## 等待本地事务进入安全回调点的观察。
## [br]
## @api private
var _local: Dictionary[int, _LocalObservation] = {}

## dispose 后永久关闭。
## [br]
## @api private
var _disposed: bool = false


# --- GF 生命周期方法 ---

## 关闭会话并释放借用的服务引用；不释放外部 Profile 与 Coordinator。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	_disposed = true
	close_session()
	_profiles = null
	_coordinator = null
	_projection = null


## 停止接纳并结束当前观察，本地已准入事务仍由 Coordinator 排空。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _scope: 架构静默作用域。
## [br]
## @return 已结束观察的完成源。
func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
	dispose()
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _done: bool = completion.succeed()
	return completion


# --- 公共方法 ---

## 一次性装配，服务的生命周期仍由原所有者管理。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profiles: 本地存档服务。
## [br]
## @param coordinator: 管理同一服务的事务协调器。
## [br]
## @param projection: 项目显式投影，默认协议拒绝上传与下载。
## [br]
## @param clock: 可选单调时钟。
## [br]
## @return 装配成功时为 true。
func setup(
	profiles: GFSaveProfileUtility,
	coordinator: GFSaveProfileTransactionCoordinator,
	projection: GFSaveSyncProjection,
	clock: GFClock = null
) -> bool:
	if (
		_profiles != null
		or _disposed
		or profiles == null
		or coordinator == null
		or projection == null
	):
		return false
	if not coordinator.uses_profile_utility_for_framework(profiles):
		return false
	_profiles = profiles
	_coordinator = coordinator
	_projection = projection
	_clock = clock
	ignore_pause = true
	ignore_time_scale = true
	return true


## 为已注册 Profile 开启完整同步快照；之后须成功加载或保存一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 已注册目标 Profile。
## [br]
## @return 开启成功时为 true；不会替项目创建或切换档位。
func prepare_profile(profile_id: StringName) -> bool:
	return (
		not _disposed
		and _profiles != null
		and _profiles.enable_sync_snapshot_for_framework(profile_id)
	)


## 绑定一个活动 Profile 的冻结账号会话，成功才替换旧会话。
##
## 已有 checkpoint 的账号和记录键必须匹配。切换账号应使用隔离 Profile，
## 或由项目执行明确的数据迁移；此入口不会清除旧账号意图或合并游客文档。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 已准备、加载且当前活动的 Profile。
## [br]
## @param record_namespace: 稳定账号命名空间。
## [br]
## @param record_key: 远端记录键。
## [br]
## @param transport: 已冻结该账号凭证的适配器。
## [br]
## @return 身份和快照均通过检查时为 true。
func open_session(
	profile_id: StringName,
	record_namespace: String,
	record_key: String,
	transport: GFStorageSyncTransport
) -> bool:
	if (
		_disposed
		or _profiles == null
		or transport == null
		or _coordinator.get_active_profile_id(profile_id) != profile_id
	):
		return false
	if GFStorageSyncRequest.create(
		record_namespace,
		record_key,
		"session-validation"
	) == null:
		return false
	var snapshot: Dictionary = _profiles.get_sync_snapshot_for_framework(profile_id)
	if snapshot.is_empty() or not _binding_matches(
		GFVariantData.get_option_dictionary(snapshot, "checkpoint"),
		record_namespace,
		record_key
	):
		return false
	close_session()
	_profile_id = profile_id
	_namespace = record_namespace
	_record_key = record_key
	var journal: _ProfileJournal = _ProfileJournal.new()
	journal._owner_ref = weakref(self)
	journal._epoch = _epoch
	_engine = GFStorageSyncUtility.new()
	return _engine.setup(
		transport,
		journal,
		_clock
	)


## 结束会话观察，撤销迟到回调的本地写入资格。
## [br]
## @api public
## [br]
## @since unreleased
func close_session() -> void:
	_epoch += 1
	if _engine != null:
		_engine.dispose()
	_engine = null
	if _current != null:
		var remote: GFStorageSyncResult = _current._remote.get_result() if _current._remote != null else null
		_finish(
			false,
			&"session_ended",
			remote,
			null,
			false,
			_current._remote == null
			or not _local.is_empty()
			or (
				remote != null
				and remote.requires_recovery()
			)
		)
	for observation: _LocalObservation in _local.values():
		if observation._operation.completed.is_connected(observation._callback):
			observation._operation.completed.disconnect(observation._callback)
		var _failed: bool = observation._completion.fail("session_ended")
	_local.clear()
	_profile_id = &""
	_namespace = ""
	_record_key = ""


## 同步最近已确认的完整文档；不会悄悄捕获或保存未登记的运行状态。
##
## 完成源成功表示观察正常终结，业务结果必须检查返回记录的 ok/status。
## 取消完成源或 cancel_wait() 仅结束观察，不能撤销远端或已准入的本地事务。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param operation_id: 本次新提交的唯一 ID。
## [br]
## @param options: 模式、冲突选择和阶段超时。
## [br]
## @schema options: Closed Dictionary with mode(push/pull/preview),resolution(report/local/remote),timeout_msec:int1..300000; defaults follow GFStorageSyncRequest.
## [br]
## @return 主线程完成源；可能已经完成。
## [br]
## @schema return: GFAsyncCompletion success result is closed Dictionary with ok:bool,status:StringName,sync_result:GFStorageSyncResult/null,local_result:GFSaveProfileTransactionResult/null,local_applied:bool,acknowledged_generation:int,requires_recovery:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary.
func synchronize(operation_id: String, options: Dictionary = {}) -> GFAsyncCompletion:
	var admission: GFAsyncCompletion = _admit()
	if admission.is_completed():
		return admission
	var serial: int = _current._serial
	var epoch: int = _epoch
	var snapshot: Dictionary = _session_snapshot(epoch)
	for key: Variant in options:
		if key not in [
			"mode",
			"resolution",
			"timeout_msec",
		]:
			_finish(false, &"invalid_options")
			return admission
	var document: GFSaveDocument = snapshot.get("document")
	var request_options: Dictionary = options.duplicate()
	var checkpoint: Dictionary = GFVariantData.get_option_dictionary(snapshot, "checkpoint")
	request_options["expected_revision"] = GFVariantData.get_option_string(checkpoint, "revision")
	request_options["local_generation"] = GFVariantData.get_option_int(snapshot, "local_generation")
	var request: GFStorageSyncRequest = GFStorageSyncRequest.create(
		_namespace,
		_record_key,
		operation_id,
		{},
		request_options
	)
	if request == null or request.get_mode() == &"probe":
		_finish(false, &"invalid_request")
		return admission
	if request.get_mode() != &"preview" and not GFVariantData.get_option_dictionary(checkpoint, "intent").is_empty():
		_finish(
			false,
			&"recovery_pending",
			null,
			null,
			false,
			true
		)
		return admission
	if request.get_mode() != &"pull" and request.get_resolution() != &"remote":
		var candidate: GFSaveDocument = _projection.project_upload(_CHECKPOINT_SCRIPT.project_document(document))
		if not _is_current(serial, epoch):
			return admission
		if not _valid_projection(candidate, document):
			_finish(false, &"invalid_upload_projection")
			return admission
		var upload_data: Dictionary = candidate.to_dict()
		request = GFStorageSyncRequest.create(
			_namespace,
			_record_key,
			operation_id,
			upload_data,
			request_options
		)
		if request == null:
			var diagnostic: Dictionary = GFStorageSyncRequest.validate_input(
				_namespace,
				_record_key,
				operation_id,
				upload_data,
				request_options
			)
			var status: StringName = &"upload_budget_exceeded" if GFVariantData.get_option_string_name(diagnostic, "error_kind") == &"request_budget_exceeded" else &"invalid_upload_projection"
			_finish(
				false,
				status,
				null,
				null,
				false,
				false,
				diagnostic
			)
			return admission
	_start_remote(request, false)
	return admission


## 读取当前账号的未解决意图并复用通用引擎查证，绝不隐式重发。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与 synchronize() 相同的完成记录；本地处于对账阻断时须先完成 Profile 恢复。
## [br]
## @schema return: GFAsyncCompletion success result follows synchronize().
func recover_pending() -> GFAsyncCompletion:
	var admission: GFAsyncCompletion = _admit()
	if admission.is_completed():
		return admission
	var snapshot: Dictionary = _session_snapshot(_epoch)
	var checkpoint: Dictionary = GFVariantData.get_option_dictionary(snapshot, "checkpoint")
	var request: GFStorageSyncRequest = GFStorageSyncRequest.from_record(GFVariantData.get_option_dictionary(checkpoint, "intent"))
	if request == null:
		_finish(false, &"no_pending_intent")
	else:
		_start_remote(request, true)
	return admission


## 结束当前观察；已经准入的下载或 checkpoint 事务继续由协调器排空。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 有观察可结束时为 true。
func cancel_wait() -> bool:
	if _current == null:
		return false
	if _current._remote != null and not _current._remote.is_completed():
		return _current._remote.cancel_wait()
	_finish(
		false,
		&"local_outcome_unknown",
		_current._remote_result,
		null,
		false,
		true
	)
	return true


## 推进本地安全完成通知及通用引擎超时；不替调用方驱动借用的服务。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param delta: 帧间隔，远端超时仍使用单调时间。
func tick(delta: float) -> void:
	for serial: int in _local.keys():
		var observation: _LocalObservation = _local.get(serial)
		if observation == null or observation._result == null:
			continue
		var _erased: bool = _local.erase(serial)
		if observation._epoch != _epoch:
			var _failed: bool = observation._completion.fail("session_ended")
		elif observation._result.is_successful():
			var _done: bool = observation._completion.succeed(observation._result)
		else:
			var _failed: bool = observation._completion.fail(
				"local_transaction_failed",
				{ "local_result": observation._result }
			)
	if _engine != null:
		_engine.tick(delta)


## 获取不含身份与文档载荷的状态摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 会话和观察计数。
## [br]
## @schema return: Dictionary with session_open:bool,observing:bool,local_pending_count:int,disposed:bool.
func get_debug_snapshot() -> Dictionary:
	return {
		"session_open": _engine != null,
		"observing": _current != null,
		"local_pending_count": _local.size(),
		"disposed": _disposed,
	}


# --- 私有/辅助方法 ---

## 建立对外观察所有权，非法准入直接返回失败记录。
## [br]
## @api private
func _admit() -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if _current != null or _session_snapshot(_epoch).is_empty():
		var _done: bool = completion.succeed(_result(false, &"local_state_unavailable"))
		return completion
	_serial += 1
	_current = _Observation.new()
	_current._serial = _serial
	_current._epoch = _epoch
	_current._completion = completion
	_current._cancellation = _on_observer_completed.bind(_serial, _epoch)
	var _connected: int = completion.completed.connect(_current._cancellation)
	return completion


## 每次读取重新确认活动档位与账号绑定，避免使用过期会话。
## [br]
## @api private
func _session_snapshot(epoch: int) -> Dictionary:
	if (
		_disposed
		or epoch != _epoch
		or _engine == null
		or _profiles == null
		or _coordinator.get_active_profile_id(_profile_id) != _profile_id
	):
		return {}
	var snapshot: Dictionary = _profiles.get_sync_snapshot_for_framework(_profile_id)
	if snapshot.is_empty() or not _binding_matches(
		GFVariantData.get_option_dictionary(snapshot, "checkpoint"),
		_namespace,
		_record_key
	):
		return {}
	return snapshot


## 空绑定仅能由首次意图或明确下载事务建立。
## [br]
## @api private
static func _binding_matches(
	checkpoint: Dictionary,
	record_namespace: String,
	record_key: String
) -> bool:
	if not _CHECKPOINT_SCRIPT.validate(checkpoint):
		return false
	var existing: String = GFVariantData.get_option_string(checkpoint, "namespace")
	return (
		existing.is_empty()
		or (
			existing == record_namespace
			and GFVariantData.get_option_string(checkpoint, "record_key") == record_key
		)
	)


## 验证项目投影仍是同一文档身份且不含框架字段。
## [br]
## @api private
static func _valid_projection(candidate: GFSaveDocument, original: GFSaveDocument) -> bool:
	return (
		candidate != null
		and original != null
		and candidate.get_schema_id() == original.get_schema_id()
		and candidate.get_schema_version() == original.get_schema_version()
		and not candidate.get_metadata().has(_CHECKPOINT_SCRIPT.METADATA_KEY)
		and GFVariantData.get_option_bool(
			candidate.validate_document(),
			"ok"
		)
	)


## 绑定远端一次性结果，兼容同步完成。
## [br]
## @api private
func _start_remote(request: GFStorageSyncRequest, recovering: bool) -> void:
	var serial: int = _current._serial
	var epoch: int = _epoch
	var operation: GFStorageSyncOperation = _engine.recover(request) if recovering else _engine.synchronize(request)
	if not _is_current(serial, epoch):
		return
	_current._remote = operation
	_current._remote_callback = _on_remote_completed.bind(serial, epoch)
	if operation.is_completed():
		_on_remote_completed(
			operation.get_result(),
			serial,
			epoch
		)
	else:
		var _connected: int = operation.completed.connect(_current._remote_callback)


## 在投影前后及事务应用前都检查冻结内容代际。
## [br]
## @api private
func _apply_download(result: GFStorageSyncResult) -> void:
	var serial: int = _current._serial
	var epoch: int = _epoch
	var snapshot: Dictionary = _session_snapshot(epoch)
	var generation: int = result.get_request().get_local_generation()
	if snapshot.is_empty() or GFVariantData.get_option_int(snapshot, "local_generation") != generation:
		_finish(
			false,
			&"local_generation_changed",
			result
		)
		return
	var remote: GFSaveDocument = GFSaveDocument.from_dict(result.get_data())
	var current: GFSaveDocument = snapshot.get("document")
	if (
		remote == null
		or remote.get_metadata().has(_CHECKPOINT_SCRIPT.METADATA_KEY)
		or remote.get_schema_id() != current.get_schema_id()
		or remote.get_schema_version() > current.get_schema_version()
	):
		_finish(
			false,
			&"invalid_remote_document",
			result
		)
		return
	var candidate: GFSaveDocument = _projection.prepare_download(
		remote,
		_CHECKPOINT_SCRIPT.project_document(current)
	)
	if not _is_current(serial, epoch):
		return
	if not _valid_projection(candidate, current):
		_finish(
			false,
			&"invalid_download_projection",
			result
		)
		return
	var checkpoint: Dictionary = _bound_checkpoint(snapshot)
	checkpoint["revision"] = result.get_revision()
	checkpoint["local_generation"] = generation + 1
	checkpoint["acknowledged_generation"] = generation + 1
	checkpoint["intent"] = {}
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create_sync_document_for_framework(
		candidate,
		checkpoint,
		generation
	)
	_observe_application(
		_persist(request, epoch),
		result,
		true,
		serial,
		epoch
	)


## 相同远端内容仍需持久化当前本地代际的确认，不冒充远端写入。
## [br]
## @api private
func _acknowledge_unchanged(result: GFStorageSyncResult) -> void:
	var snapshot: Dictionary = _session_snapshot(_epoch)
	if snapshot.is_empty():
		_finish(
			false,
			&"local_state_unavailable",
			result
		)
		return
	var checkpoint: Dictionary = _bound_checkpoint(snapshot)
	checkpoint["revision"] = result.get_revision()
	checkpoint["acknowledged_generation"] = result.get_request().get_local_generation()
	if not GFVariantData.get_option_dictionary(checkpoint, "intent").is_empty():
		_finish(
			false,
			&"recovery_pending",
			result,
			null,
			false,
			true
		)
		return
	var completion: GFAsyncCompletion = _persist_checkpoint(
		snapshot,
		checkpoint,
		_epoch
	)
	_observe_application(
		completion,
		result,
		false,
		_current._serial,
		_epoch
	)


## 观察已经准入的本地事务，不引入第二套回滚或持久化状态机。
## [br]
## @api private
func _observe_application(
	completion: GFAsyncCompletion,
	remote: GFStorageSyncResult,
	applied: bool,
	serial: int,
	epoch: int
) -> void:
	if not _is_current(serial, epoch):
		return
	_current._application = completion
	_current._application_callback = _on_application_completed.bind(
		remote,
		applied,
		serial,
		epoch
	)
	if completion.is_completed():
		_on_application_completed(
			completion,
			remote,
			applied,
			serial,
			epoch
		)
	else:
		var _connected: int = completion.completed.connect(_current._application_callback)


## 从当前快照派生绑定记录，保留最新内容代际。
## [br]
## @api private
func _bound_checkpoint(snapshot: Dictionary) -> Dictionary:
	var checkpoint: Dictionary = GFVariantData.get_option_dictionary(snapshot, "checkpoint").duplicate(true)
	checkpoint["namespace"] = _namespace
	checkpoint["record_key"] = _record_key
	return checkpoint


## 读取同一会话的持久化意图，失败不能冒充不存在。
## [br]
## @api private
func _journal_load(
	epoch: int,
	record_namespace: String,
	record_key: String
) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var snapshot: Dictionary = _session_snapshot(epoch)
	if (
		snapshot.is_empty()
		or record_namespace != _namespace
		or record_key != _record_key
	):
		var _failed: bool = completion.fail("session_unavailable")
	else:
		var checkpoint: Dictionary = GFVariantData.get_option_dictionary(snapshot, "checkpoint")
		var _done: bool = completion.succeed(GFVariantData.get_option_dictionary(checkpoint, "intent").duplicate(true))
	return completion


## 将精确意图或已查证结果放入同一 Profile 事务；不等待网络。
## [br]
## @api private
func _journal_write(
	epoch: int,
	request: GFStorageSyncRequest,
	outcome: Dictionary
) -> GFAsyncCompletion:
	var snapshot: Dictionary = _session_snapshot(epoch)
	if (
		snapshot.is_empty()
		or request.get_namespace() != _namespace
		or request.get_key() != _record_key
	):
		return _failed_completion("session_unavailable")
	var checkpoint: Dictionary = _bound_checkpoint(snapshot)
	var previous: Dictionary = GFVariantData.get_option_dictionary(checkpoint, "intent")
	if outcome.is_empty():
		if not previous.is_empty() and previous != request.to_record():
			return _failed_completion("recovery_pending")
		checkpoint["intent"] = request.to_record()
	else:
		if previous != request.to_record():
			return _failed_completion("intent_mismatch")
		checkpoint["intent"] = {}
		if GFVariantData.get_option_string_name(outcome, "status") == &"committed":
			checkpoint["revision"] = GFVariantData.get_option_string(outcome, "revision")
			checkpoint["acknowledged_generation"] = request.get_local_generation()
	return _persist_checkpoint(
		snapshot,
		checkpoint,
		epoch
	)


## 只替换框架元数据，项目文档元数据从当前快照保留。
## [br]
## @api private
func _persist_checkpoint(
	snapshot: Dictionary,
	checkpoint: Dictionary,
	epoch: int
) -> GFAsyncCompletion:
	var document: GFSaveDocument = snapshot.get("document")
	var metadata: Dictionary = _CHECKPOINT_SCRIPT.project_document(document).get_metadata()
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create_sync_for_framework(
		[],
		checkpoint,
		GFVariantData.get_option_int(snapshot, "local_generation"),
		metadata
	)
	return _persist(request, epoch)


## 使用既有 Coordinator 准入事务，成功通知推迟到下一 tick 的安全状态。
## [br]
## @api private
func _persist(request: GFSaveProfileMutationRequest, epoch: int) -> GFAsyncCompletion:
	if request == null or _session_snapshot(epoch).is_empty():
		return _failed_completion("local_state_unavailable")
	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(_profile_id, request)
	_serial += 1
	var observation: _LocalObservation = _LocalObservation.new()
	observation._epoch = epoch
	observation._operation = operation
	observation._completion = GFAsyncCompletion.new()
	observation._callback = _on_local_completed.bind(_serial)
	_local[_serial] = observation
	if operation.is_completed():
		_on_local_completed(
			operation.get_result(),
			_serial
		)
	else:
		var _connected: int = operation.completed.connect(observation._callback)
	return observation._completion


## 检查当前观察身份。
## [br]
## @api private
func _is_current(serial: int, epoch: int) -> bool:
	return (
		_current != null
		and _current._serial == serial
		and _current._epoch == epoch
		and epoch == _epoch
		and not _disposed
	)


## 先撤销所有权和监听，再发出唯一结果，允许完成回调安全重入。
## [br]
## @api private
func _finish(
	ok: bool,
	status: StringName,
	remote: GFStorageSyncResult = null,
	local_result: GFSaveProfileTransactionResult = null,
	applied: bool = false,
	recovery: bool = false,
	diagnostic: Dictionary = {}
) -> void:
	if _current == null:
		return
	var observation: _Observation = _current
	_current = null
	if observation._remote != null and observation._remote.completed.is_connected(observation._remote_callback):
		observation._remote.completed.disconnect(observation._remote_callback)
	if observation._application != null and observation._application.completed.is_connected(observation._application_callback):
		observation._application.completed.disconnect(observation._application_callback)
	if observation._completion.completed.is_connected(observation._cancellation):
		observation._completion.completed.disconnect(observation._cancellation)
	var result: Dictionary = _result(ok, status)
	for key: String in [
		"error_kind",
		"path",
		"layer",
		"limits",
		"observed",
	]:
		if diagnostic.has(key):
			result[key] = GFVariantData.duplicate_variant(diagnostic[key])
	result["sync_result"] = remote
	result["local_result"] = local_result if local_result != null else observation._last_local_result
	result["local_applied"] = applied
	result["requires_recovery"] = recovery
	var snapshot: Dictionary = _session_snapshot(_epoch)
	var checkpoint: Dictionary = GFVariantData.get_option_dictionary(snapshot, "checkpoint")
	result["acknowledged_generation"] = GFVariantData.get_option_int(checkpoint, "acknowledged_generation")
	var _done: bool = observation._completion.succeed(result)


## 创建固定结果结构，不包含文档或账号文本。
## [br]
## @api private
static func _result(ok: bool, status: StringName) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"error_kind": &"" if ok else status,
		"path": "",
		"layer": &"",
		"limits": {},
		"observed": {},
		"sync_result": null,
		"local_result": null,
		"local_applied": false,
		"acknowledged_generation": 0,
		"requires_recovery": false,
	}


## 创建已失败的内部完成源。
## [br]
## @api private
static func _failed_completion(error: String) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail(error)
	return completion


# --- 信号处理函数 ---

## 远端逻辑只由 Standard 决定；此处仅安排本地确认或下载事务。
## [br]
## @api private
func _on_remote_completed(
	result: GFStorageSyncResult,
	serial: int,
	epoch: int
) -> void:
	if not _is_current(serial, epoch):
		return
	_current._remote_result = result
	match result.get_status():
		GFStorageSyncResult.Status.REMOTE_SELECTED:
			_apply_download(result)
		GFStorageSyncResult.Status.UNCHANGED:
			_acknowledge_unchanged(result)
		_:
			_finish(
				result.is_successful(),
				result.get_status_name(),
				result,
				null,
				false,
				result.requires_recovery()
			)


## 只有本地事务确认成功才报告应用成功；未知本地写入保留 Coordinator 对账责任。
## [br]
## @api private
func _on_application_completed(
	completion: GFAsyncCompletion,
	remote: GFStorageSyncResult,
	applied: bool,
	serial: int,
	epoch: int
) -> void:
	if not _is_current(serial, epoch):
		return
	var value: Variant = completion.get_result() if completion.is_successful() else completion.get_metadata().get("local_result")
	var local_result: GFSaveProfileTransactionResult = value if value is GFSaveProfileTransactionResult else null
	var unknown: bool = local_result != null and local_result.get_status() in [GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN, GFSaveProfileTransactionResult.STATUS_ROLLBACK_FAILED]
	var status: StringName = &"local_persist_failed"
	if completion.is_successful():
		status = &"applied" if applied else &"unchanged"
	_finish(
		completion.is_successful(),
		status,
		remote,
		local_result,
		applied and completion.is_successful(),
		unknown
	)


## 接收本地结果时只缓存，不在低层 IO 完成信号栈内重入下一次保存。
## [br]
## @api private
func _on_local_completed(result: GFSaveProfileTransactionResult, serial: int) -> void:
	var observation: _LocalObservation = _local.get(serial)
	if observation == null:
		return
	if observation._operation.completed.is_connected(observation._callback):
		observation._operation.completed.disconnect(observation._callback)
	observation._result = result
	if _current != null and observation._epoch == _current._epoch:
		_current._last_local_result = result


## 观察者自行取消时解除回调并保留必要的远端恢复责任。
## [br]
## @api private
func _on_observer_completed(
	completion: GFAsyncCompletion,
	serial: int,
	epoch: int
) -> void:
	if _is_current(serial, epoch) and completion.is_cancelled():
		var _cancelled: bool = cancel_wait()


# --- 内部类 ---

## 对外观察所有权。
## [br]
## @api private
class _Observation extends RefCounted:


	# --- 私有变量 ---

	## 实例内观察序号。
	## [br]
	## @api private
	var _serial: int = 0

	## 冻结的会话代次。
	## [br]
	## @api private
	var _epoch: int = 0

	## 一次性完成源。
	## [br]
	## @api private
	var _completion: GFAsyncCompletion = null

	## 外部取消的完成回调。
	## [br]
	## @api private
	var _cancellation: Callable = Callable()

	## 通用远端观察。
	## [br]
	## @api private
	var _remote: GFStorageSyncOperation = null

	## 远端终态回调。
	## [br]
	## @api private
	var _remote_callback: Callable = Callable()

	## 已取得的远端终态。
	## [br]
	## @api private
	var _remote_result: GFStorageSyncResult = null

	## 最近的本地事务结果，保留精确对账 lease。
	## [br]
	## @api private
	var _last_local_result: GFSaveProfileTransactionResult = null

	## 下载或相同内容确认的本地完成源。
	## [br]
	## @api private
	var _application: GFAsyncCompletion = null

	## 本地应用结果回调。
	## [br]
	## @api private
	var _application_callback: Callable = Callable()


## 本地事务的异步观察；实际事务由 Coordinator 拥有。
## [br]
## @api private
class _LocalObservation extends RefCounted:


	# --- 私有变量 ---

	## 冻结的会话代次。
	## [br]
	## @api private
	var _epoch: int = 0

	## Coordinator 拥有的实际事务。
	## [br]
	## @api private
	var _operation: GFSaveProfileTransactionOperation = null

	## 一次性完成源。
	## [br]
	## @api private
	var _completion: GFAsyncCompletion = null

	## 已连接的事务结果回调。
	## [br]
	## @api private
	var _callback: Callable = Callable()

	## 等待安全 tick 转发的事务结果。
	## [br]
	## @api private
	var _result: GFSaveProfileTransactionResult = null


## 将 Journal 协议映射到同一会话的 Profile 事务。
## [br]
## @api private
class _ProfileJournal extends GFStorageSyncJournal:


	# --- 私有变量 ---

	## 组合器的弱引用，避免日志延长服务生命周期。
	## [br]
	## @api private
	var _owner_ref: WeakRef = null

	## 冻结的会话代次。
	## [br]
	## @api private
	var _epoch: int = 0


	# --- 可重写钩子 / 虚方法 ---

	## 从同一会话读取持久化意图。
	## [br]
	## @api protected
	## [br]
	## @since unreleased
	## [br]
	## @param record_namespace: 原命名空间。
	## [br]
	## @param record_key: 原记录键。
	## [br]
	## @return 规范意图或失败完成源。
	func _load_intent(record_namespace: String, record_key: String) -> GFAsyncCompletion:
		var owner: Variant = _owner_ref.get_ref()
		if owner is GFSaveSyncUtility:
			var utility: GFSaveSyncUtility = owner
			return utility._journal_load(
				_epoch,
				record_namespace,
				record_key
			)
		return GFSaveSyncUtility._failed_completion("owner_unavailable")


	## 先持久化精确提交意图。
	## [br]
	## @api protected
	## [br]
	## @since unreleased
	## [br]
	## @param request: 原冻结请求。
	## [br]
	## @return 持久化完成源。
	func _persist_intent(request: GFStorageSyncRequest) -> GFAsyncCompletion:
		var owner: Variant = _owner_ref.get_ref()
		if owner is GFSaveSyncUtility:
			var utility: GFSaveSyncUtility = owner
			return utility._journal_write(
				_epoch,
				request,
				{}
			)
		return GFSaveSyncUtility._failed_completion("owner_unavailable")


	## 将查证结果映射到本地 checkpoint 事务。
	## [br]
	## @api protected
	## [br]
	## @since unreleased
	## [br]
	## @param request: 原冻结请求。
	## [br]
	## @param outcome: 已验证的远端结果。
	## [br]
	## @schema outcome: Closed transport reply containing namespace,key,operation_id,status,exists,revision,data.
	## [br]
	## @return 持久化完成源。
	func _persist_outcome(request: GFStorageSyncRequest, outcome: Dictionary) -> GFAsyncCompletion:
		var owner: Variant = _owner_ref.get_ref()
		if owner is GFSaveSyncUtility:
			var utility: GFSaveSyncUtility = owner
			return utility._journal_write(
				_epoch,
				request,
				outcome
			)
		return GFSaveSyncUtility._failed_completion("owner_unavailable")
