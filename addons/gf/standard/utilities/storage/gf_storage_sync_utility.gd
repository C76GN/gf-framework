## GFStorageSyncUtility: 以持久化意图和远端条件写入组织记录同步。
##
## 只在主线程使用。setup() 后可独立使用；独立使用者须驱动 tick() 处理超时，
## 并在结束时 dispose()。网络等待不持有项目业务事务。每个记录同时只接纳一个操作。
## 远端提交前确认意图落盘，提交后确认结果落盘；未知结果只按原操作 ID 查证。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFStorageSyncUtility
extends GFUtility


# --- 私有变量 ---

## 冻结装配的远端适配器。
## [br]
## @api private
var _transport: GFStorageSyncTransport = null

## 持久化意图和结果的本地接口。
## [br]
## @api private
var _journal: GFStorageSyncJournal = null

## 可注入的单调时钟。
## [br]
## @api private
var _clock: GFClock = GFClock.new()

## 序号到 _Pending 的所有权表。
## [br]
## @api private
var _pending: Dictionary[int, _Pending] = {}

## 记录身份到序号的准入表。
## [br]
## @api private
var _records: Dictionary[String, int] = {}

## 单调递增的本实例观察序号。
## [br]
## @api private
var _serial: int = 0

## 只允许一次装配。
## [br]
## @api private
var _configured: bool = false

## 静默或释放后拒绝新工作。
## [br]
## @api private
var _closed: bool = false


# --- GF 生命周期方法 ---

## 停止接纳并终结所有观察；不声称撤销已发送的远端操作。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _scope: 架构关闭作用域。
## [br]
## @return 已完成的静默完成源；未知提交保留在持久化日志供后续恢复。
func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
	_stop(&"quiesced")
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _accepted: bool = completion.succeed()
	return completion


## 释放全部观察和适配器引用，原意图仍由持久化日志拥有。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	_stop(&"disposed")
	_transport = null
	_journal = null


# --- 公共方法 ---

## 一次性装配；只读用途允许 journal 为空。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param transport: 冻结认证会话的远端适配器。
## [br]
## @param journal: 写入与恢复需要的持久化日志。
## [br]
## @param clock: 单调时钟；空时使用系统单调时间。
## [br]
## @return 装配成功返回 true；重复装配或关闭后返回 false。
func setup(
	transport: GFStorageSyncTransport,
	journal: GFStorageSyncJournal = null,
	clock: GFClock = null
) -> bool:
	if (
		_configured
		or _closed
		or transport == null
		or not Thread.is_main_thread()
	):
		return false
	_transport = transport
	_journal = journal
	_clock = clock if clock != null else GFClock.new()
	ignore_pause = true
	ignore_time_scale = true
	_configured = true
	return true


## 只读检查本模式的协议能力与日志要求，不开始网络或日志 IO。
##
## 能力来自 Transport 当前声明，不证明服务端实现正确；实际准入会再次检查。
## pull、preview 与 push/remote 不需要 Journal；probe 只需要 probe 与 Journal。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param mode: push、pull、preview 或 probe。
## [br]
## @param resolution: report、local 或 remote。
## [br]
## @return 模式支持报告，不包含账号或业务数据。
## [br]
## @schema return: Dictionary with ok:bool,error_kind:StringName,path:String,mode:StringName,resolution:StringName,required_capabilities:PackedStringArray,missing_capabilities:PackedStringArray,journal_required:bool,journal_available:bool.
func inspect_support(mode: StringName = &"push", resolution: StringName = &"report") -> Dictionary:
	var input_report: Dictionary = GFStorageSyncRequest.validate_input(
		"support",
		"record",
		"inspect",
		{},
		{ "mode": mode, "resolution": resolution }
	)
	var report: Dictionary = {
		"ok": false,
		"error_kind": &"",
		"path": "",
		"mode": mode,
		"resolution": resolution,
		"required_capabilities": PackedStringArray(),
		"missing_capabilities": PackedStringArray(),
		"journal_required": false,
		"journal_available": _journal != null,
	}
	if not GFVariantData.get_option_bool(input_report, "ok"):
		report["error_kind"] = input_report["error_kind"]
		report["path"] = input_report["path"]
		return report
	if (
		not _configured
		or _closed
		or _transport == null
	):
		report["error_kind"] = &"unavailable"
		report["path"] = "utility"
		return report
	var required: PackedStringArray = PackedStringArray(["probe"] if mode == &"probe" else ["read"])
	var writing: bool = mode == &"push" and resolution != &"remote"
	if writing:
		required.append_array(PackedStringArray(["conditional_write", "probe"]))
	var capabilities: Dictionary = _transport.get_capabilities()
	var missing: PackedStringArray = PackedStringArray()
	for capability: String in required:
		if not GFVariantData.get_option_bool(capabilities, capability):
			var _appended: bool = missing.append(capability)
	var journal_required: bool = writing or mode == &"probe"
	report["required_capabilities"] = required
	report["missing_capabilities"] = missing
	report["journal_required"] = journal_required
	if journal_required and _journal == null:
		report["error_kind"] = &"capability_unavailable"
		report["path"] = "journal"
	elif not missing.is_empty():
		report["error_kind"] = &"capability_unavailable"
		report["path"] = "transport.capabilities"
	else:
		report["ok"] = true
	return report


## 开始一次冻结请求；可能同步完成，观察前应检查 is_completed()。
##
## push 默认报告版本冲突；显式 local 选择使用本次读到的 revision 再执行一次 CAS。
## pull/remote 只返回远端候选，由调用方以自己的事务应用。preview 从不写入。
## 自定义合并使用冲突报告构建新请求，填入实际 revision 和新的 operation_id。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 冻结请求；probe 模式进入 recover()。
## [br]
## @return 唯一终态操作；非法输入也返回已拒绝操作。
func synchronize(request: GFStorageSyncRequest) -> GFStorageSyncOperation:
	if (
		request != null
		and request.is_valid()
		and request.get_mode() == &"probe"
	):
		return recover(request)
	var state: _Pending = _admit(request, false)
	if state._operation.is_completed():
		return state._operation
	var writing: bool = request.get_mode() == &"push" and request.get_resolution() != &"remote"
	var support: Dictionary = inspect_support(
		request.get_mode(),
		request.get_resolution()
	)
	if not GFVariantData.get_option_bool(support, "ok"):
		_finish(
			state,
			GFStorageSyncResult.Status.REJECTED,
			&"capability_unavailable"
		)
	elif writing:
		_begin_phase(state, &"load")
	else:
		_begin_phase(state, &"read")
	return state._operation


## 查证原意图的历史结果，绝不重发条件写入。
##
## 调用方可先使用 journal.load_intent() 读取完整记录并调用 Request.from_record()。
## 引擎再次验证日志仍包含同一意图，防止错认操作或跨记录恢复。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 原持久化请求；除观察模式外的规范记录必须一致。
## [br]
## @return 查证操作；未知结果和本地 checkpoint 失败仍保留恢复责任。
func recover(request: GFStorageSyncRequest) -> GFStorageSyncOperation:
	var state: _Pending = _admit(request, true)
	if state._operation.is_completed():
		return state._operation
	var support: Dictionary = inspect_support(
		&"probe",
		request.get_resolution()
	)
	if not GFVariantData.get_option_bool(support, "ok"):
		_finish(
			state,
			GFStorageSyncResult.Status.REJECTED,
			&"capability_unavailable"
		)
	else:
		_begin_phase(state, &"load")
	return state._operation


## 启动相互独立的记录操作，不提供跨记录原子性。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param requests: 最多256个冻结请求；同记录在途竞争逐项拒绝。
## [br]
## @return 与输入顺序一致的操作；超限时不启动任何请求，只返回一个 batch_limit 拒绝结果。
func synchronize_many(requests: Array[GFStorageSyncRequest]) -> Array[GFStorageSyncOperation]:
	var operations: Array[GFStorageSyncOperation] = []
	if requests.size() > 256:
		var state: _Pending = _rejected(null, &"batch_limit")
		operations.append(state._operation)
		return operations
	for request: GFStorageSyncRequest in requests:
		operations.append(synchronize(request))
	return operations


## 用单调时间终结超时观察，delta 不参与截止时间计算。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 架构传入的帧间隔。
func tick(_delta: float) -> void:
	var now: int = _clock.get_monotonic_msec()
	for serial: int in _pending.keys():
		var state: _Pending = _pending.get(serial)
		if state != null and now >= state._deadline:
			_interrupt(state, &"timeout")


## 获取不包含账号、记录键、载荷或 revision 的诊断。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前观察数量和装配状态。
## [br]
## @schema return: Dictionary with configured:bool,closed:bool,pending_count:int,phases:Dictionary[StringName,int].
func get_debug_snapshot() -> Dictionary:
	var phases: Dictionary = {}
	for state: _Pending in _pending.values():
		phases[state._phase] = GFVariantData.get_option_int(phases, state._phase) + 1
	return {
		"configured": _configured,
		"closed": _closed,
		"pending_count": _pending.size(),
		"phases": phases,
	}


# --- 私有/辅助方法 ---

## 检查装配、输入和记录独占；先建立所有权，再允许适配器执行。
## [br]
## @api private
func _admit(request: GFStorageSyncRequest, recovering: bool) -> _Pending:
	if (
		not Thread.is_main_thread()
		or request == null
		or not request.is_valid()
	):
		return _rejected(null, &"invalid_request")
	if not _configured or _closed:
		return _rejected(request, &"unavailable")
	var record_id: String = JSON.stringify([request.get_namespace(), request.get_key()])
	if _records.has(record_id):
		return _rejected(request, &"record_busy")
	_serial += 1
	var state: _Pending = _Pending.new()
	state._serial = _serial
	state._record_id = record_id
	state._request = request
	state._operation = GFStorageSyncOperation.new()
	state._recovering = recovering
	state._dispatched = recovering
	state._cancellation = _on_cancel.bind(state._serial)
	var _connected: int = state._operation.cancel_requested.connect(state._cancellation)
	_records[record_id] = state._serial
	_pending[state._serial] = state
	return state


## 返回未进入所有权表的拒绝操作。
## [br]
## @api private
func _rejected(request: GFStorageSyncRequest, error_kind: StringName) -> _Pending:
	var state: _Pending = _Pending.new()
	state._request = request
	state._operation = GFStorageSyncOperation.new()
	var result: GFStorageSyncResult = GFStorageSyncResult.new()
	var _configured_result: bool = result.configure_for_framework(
		request,
		GFStorageSyncResult.Status.REJECTED,
		{ "error_kind": error_kind }
	)
	var _completed: bool = state._operation.complete_for_framework(result)
	return state


## 在调用外部实现前安装阶段、代次和截止时间；适配器允许同步重入。
## [br]
## @api private
func _begin_phase(state: _Pending, phase: StringName) -> void:
	if not _pending.has(state._serial):
		return
	_disconnect(state)
	state._phase = phase
	state._token += 1
	state._deadline = _clock.get_monotonic_msec() + state._request.get_timeout_msec()
	var token: int = state._token
	var completion: GFAsyncCompletion = null
	match phase:
		&"load":
			completion = _journal.load_intent(
				state._request.get_namespace(),
				state._request.get_key()
			)
		&"read":
			completion = _transport.read(state._request)
		&"intent":
			completion = _journal.persist_intent(state._request)
		&"write":
			state._dispatched = true
			completion = _transport.conditional_write(state._request)
		&"probe":
			completion = _transport.probe(state._request)
		&"checkpoint":
			completion = _journal.persist_outcome(
				state._request,
				state._outcome.duplicate(true)
			)
	if not _pending.has(state._serial) or state._token != token:
		return
	if completion == null:
		_interrupt(state, &"adapter_unavailable")
		return
	state._completion = completion
	state._callback = _on_phase_completed.bind(state._serial, token)
	if completion.is_completed():
		_on_phase_completed(
			completion,
			state._serial,
			token
		)
	else:
		var _connected: int = completion.completed.connect(state._callback, CONNECT_ONE_SHOT)


## 载入日志失败不能当作没有意图；恢复只接受完全相同的持久化候选。
## [br]
## @api private
func _handle_loaded_intent(state: _Pending, value: Variant) -> void:
	if not value is Dictionary:
		_interrupt(state, &"invalid_journal")
		return
	var record: Dictionary = value
	if not state._recovering:
		if not record.is_empty():
			_finish(
				state,
				GFStorageSyncResult.Status.REJECTED,
				&"recovery_pending"
			)
		else:
			_begin_phase(state, &"read")
		return
	var saved: GFStorageSyncRequest = GFStorageSyncRequest.from_record(record)
	var expected: Dictionary = state._request.to_record()
	if saved != null:
		expected["mode"] = saved.get_mode()
	if saved == null or expected != saved.to_record():
		_finish(
			state,
			GFStorageSyncResult.Status.REJECTED,
			&"intent_mismatch"
		)
		return
	state._request = saved
	_begin_phase(state, &"probe")


## 根据版本、模式和明确选择准备一次条件提交；不排序 revision。
## [br]
## @api private
func _handle_remote_read(state: _Pending, reply: Dictionary) -> void:
	var request: GFStorageSyncRequest = state._request
	var matches: bool = request.get_expected_revision() == GFVariantData.get_option_string(reply, "revision")
	if request.get_mode() == &"preview":
		_finish(
			state,
			GFStorageSyncResult.Status.PREVIEW,
			&"",
			reply,
			not matches
		)
		return
	if request.get_mode() == &"pull" or request.get_resolution() == &"remote":
		if GFVariantData.get_option_bool(reply, "exists"):
			_finish(
				state,
				GFStorageSyncResult.Status.REMOTE_SELECTED,
				&"",
				reply
			)
		else:
			_finish(
				state,
				GFStorageSyncResult.Status.NOT_COMMITTED,
				&"record_missing"
			)
		return
	if not matches and request.get_resolution() == &"report":
		_finish(
			state,
			GFStorageSyncResult.Status.CONFLICT,
			&"revision_conflict",
			reply,
			true
		)
		return
	if GFVariantData.get_option_bool(reply, "exists") and GFVariantData.get_option_dictionary(reply, "data") == request.get_data():
		_finish(
			state,
			GFStorageSyncResult.Status.UNCHANGED,
			&"",
			reply
		)
		return
	if not matches:
		var record: Dictionary = request.to_record()
		record["expected_revision"] = GFVariantData.get_option_string(reply, "revision")
		state._request = GFStorageSyncRequest.from_record(record)
		if state._request == null:
			state._request = request
			_finish(
				state,
				GFStorageSyncResult.Status.REJECTED,
				&"invalid_candidate"
			)
			return
	_begin_phase(state, &"intent")


## 未知结果保留意图；明确结果先写 checkpoint 再对外确认。
## [br]
## @api private
func _handle_remote_outcome(state: _Pending, reply: Dictionary) -> void:
	if GFVariantData.get_option_string_name(reply, "status") == &"unknown":
		_finish(
			state,
			GFStorageSyncResult.Status.OUTCOME_UNKNOWN,
			&"outcome_unknown"
		)
		return
	state._outcome = reply
	_begin_phase(state, &"checkpoint")


## 本地 checkpoint 已确认，返回远端历史结果。
## [br]
## @api private
func _finish_outcome(state: _Pending) -> void:
	match GFVariantData.get_option_string_name(state._outcome, "status"):
		&"committed":
			_finish(
				state,
				GFStorageSyncResult.Status.COMMITTED,
				&"",
				state._outcome
			)
		&"conflict":
			_finish(
				state,
				GFStorageSyncResult.Status.CONFLICT,
				&"revision_conflict",
				state._outcome,
				true
			)
		_:
			_finish(
				state,
				GFStorageSyncResult.Status.NOT_COMMITTED,
				&"not_committed"
			)


## 严格验证闭合协议结构与冻结身份；不信任完成源中的任意错误文本。
## [br]
## @api private
func _parse_reply(state: _Pending, value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var reply: Dictionary = value
	if reply.size() != 7:
		return {}
	for key: String in [
		"namespace",
		"key",
		"operation_id",
		"revision",
	]:
		if not reply.get(key) is String:
			return {}
	if (
		reply.get("namespace") != state._request.get_namespace()
		or reply.get("key") != state._request.get_key()
		or reply.get("operation_id") != state._request.get_operation_id()
	):
		return {}
	if not reply.get("exists") is bool or not reply.get("data") is Dictionary:
		return {}
	var raw_status: Variant = reply.get("status")
	if not raw_status is String and not raw_status is StringName:
		return {}
	var status: StringName = GFVariantData.to_string_name(raw_status)
	var allowed: Array[StringName] = [&"read"]
	if state._phase == &"write":
		allowed = [
			&"committed",
			&"conflict",
			&"not_committed",
			&"unknown",
		]
	elif state._phase == &"probe":
		allowed = [
			&"committed",
			&"not_committed",
			&"unknown",
		]
	if status not in allowed:
		return {}
	var exists: bool = GFVariantData.get_option_bool(reply, "exists")
	var revision: String = GFVariantData.get_option_string(reply, "revision")
	var data: Dictionary = GFVariantData.get_option_dictionary(reply, "data")
	if (
		exists == revision.is_empty()
		or revision.length() > 65536
		or (
			not exists
			and not data.is_empty()
		)
	):
		return {}
	if status == &"committed" and not exists:
		return {}
	if status in [&"unknown", &"not_committed"] and exists:
		return {}
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		reply,
		{
			"allow_floats": true,
			"max_depth": 64,
			"max_items": 100000,
			"max_output_bytes": 16777216,
			"max_string_length": 16777216,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return {}
	return reply.duplicate(true)


## 结束观察时按实际发送边界分类，取消和超时都不伪装远端撤销。
## [br]
## @api private
func _interrupt(state: _Pending, error_kind: StringName) -> void:
	if not state._outcome.is_empty():
		_finish(
			state,
			GFStorageSyncResult.Status.RECOVERY_REQUIRED,
			error_kind,
			state._outcome
		)
	elif state._dispatched:
		_finish(
			state,
			GFStorageSyncResult.Status.OUTCOME_UNKNOWN,
			error_kind
		)
	else:
		_finish(
			state,
			GFStorageSyncResult.Status.NOT_COMMITTED,
			error_kind
		)


## 解除所有权和回调后才发送终态，允许监听器安全开始下一次操作。
## [br]
## @api private
func _finish(
	state: _Pending,
	status: GFStorageSyncResult.Status,
	error_kind: StringName = &"",
	reply: Dictionary = {},
	has_conflict: bool = false
) -> void:
	if not _pending.has(state._serial):
		return
	var details: Dictionary = {
		"error_kind": error_kind,
		"exists": GFVariantData.get_option_bool(reply, "exists"),
		"revision": GFVariantData.get_option_string(reply, "revision"),
		"data": GFVariantData.get_option_dictionary(reply, "data"),
		"remote_committed": GFVariantData.get_option_string_name(reply, "status") == &"committed",
	}
	var conflict: GFStorageConflictReport = null
	if has_conflict:
		conflict = GFStorageConflictReport.create(
			state._request.get_namespace(),
			state._request.get_key(),
			state._request.get_data(),
			GFVariantData.get_option_dictionary(reply, "data"),
			{
				"expected_revision": state._request.get_expected_revision(),
				"actual_revision": GFVariantData.get_option_string(reply, "revision"),
				"remote_exists": GFVariantData.get_option_bool(reply, "exists"),
			}
		)
	var result: GFStorageSyncResult = GFStorageSyncResult.new()
	var configured: bool = result.configure_for_framework(
		state._request,
		status,
		details,
		conflict
	)
	if not configured:
		var fallback: GFStorageSyncResult.Status = GFStorageSyncResult.Status.OUTCOME_UNKNOWN if state._dispatched else GFStorageSyncResult.Status.NOT_COMMITTED
		var _fallback_configured: bool = result.configure_for_framework(
			state._request,
			fallback,
			{ "error_kind": &"invalid_result" }
		)
	_disconnect(state)
	if state._operation.cancel_requested.is_connected(state._cancellation):
		state._operation.cancel_requested.disconnect(state._cancellation)
	var _erased_pending: bool = _pending.erase(state._serial)
	var _erased_record: bool = _records.erase(state._record_id)
	var _completed: bool = state._operation.complete_for_framework(result)


## 移除本引擎持有的完成观察，不取消适配器物理工作。
## [br]
## @api private
func _disconnect(state: _Pending) -> void:
	if (
		state._completion != null
		and state._callback.is_valid()
		and state._completion.completed.is_connected(state._callback)
	):
		state._completion.completed.disconnect(state._callback)
	state._completion = null
	state._callback = Callable()


## 先关闭准入再遍历，避免终态回调重入接纳新工作。
## [br]
## @api private
func _stop(error_kind: StringName) -> void:
	_closed = true
	for serial: int in _pending.keys():
		var state: _Pending = _pending.get(serial)
		if state != null:
			_interrupt(state, error_kind)


# --- 信号处理函数 ---

## 只接受当前阶段的唯一完成；迟到完成不改变已返回的终态。
## [br]
## @api private
func _on_phase_completed(
	completion: GFAsyncCompletion,
	serial: int,
	token: int
) -> void:
	var state: _Pending = _pending.get(serial)
	if state == null or state._token != token:
		return
	_disconnect(state)
	if not completion.is_successful():
		_interrupt(state, &"adapter_failed")
		return
	if state._phase == &"load":
		_handle_loaded_intent(
			state,
			completion.get_result()
		)
	elif state._phase == &"intent":
		_begin_phase(state, &"write")
	elif state._phase == &"checkpoint":
		_finish_outcome(state)
	else:
		var reply: Dictionary = _parse_reply(
			state,
			completion.get_result()
		)
		if reply.is_empty():
			_interrupt(state, &"invalid_reply")
		elif state._phase == &"read":
			_handle_remote_read(state, reply)
		else:
			_handle_remote_outcome(state, reply)


## 响应观察者取消。
## [br]
## @api private
func _on_cancel(serial: int) -> void:
	var state: _Pending = _pending.get(serial)
	if state != null:
		_interrupt(state, &"cancelled")


# --- 内部类 ---

## 一次观察的私有状态；回调只绑定序号，避免把状态绑定进完成源。
## [br]
## @api private
class _Pending extends RefCounted:


	# --- 私有变量 ---

	## 实例内观察序号。
	## [br]
	## @api private
	var _serial: int = 0

	## 仅用于准入的完整记录身份，不用于诊断。
	## [br]
	## @api private
	var _record_id: String = ""

	## 当前冻结请求。
	## [br]
	## @api private
	var _request: GFStorageSyncRequest = null

	## 对外唯一终态句柄。
	## [br]
	## @api private
	var _operation: GFStorageSyncOperation = null

	## 当前协议阶段。
	## [br]
	## @api private
	var _phase: StringName = &""

	## 阶段代次，隔离迟到完成。
	## [br]
	## @api private
	var _token: int = 0

	## 当前阶段的单调截止时间。
	## [br]
	## @api private
	var _deadline: int = 0

	## 当前观察的完成源。
	## [br]
	## @api private
	var _completion: GFAsyncCompletion = null

	## 已连接的阶段完成回调。
	## [br]
	## @api private
	var _callback: Callable = Callable()

	## 已连接的取消观察回调。
	## [br]
	## @api private
	var _cancellation: Callable = Callable()

	## 是否已发送或正在查证历史提交。
	## [br]
	## @api private
	var _dispatched: bool = false

	## 是否只查证原意图。
	## [br]
	## @api private
	var _recovering: bool = false

	## 已验证且待本地确认的远端结果。
	## [br]
	## @api private
	var _outcome: Dictionary = {}
