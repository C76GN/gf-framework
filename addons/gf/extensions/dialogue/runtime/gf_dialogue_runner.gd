## GFDialogueRunner: 通用对话资源执行器。
##
## Runner 只沿 GFDialogueResource 的行、响应、跳转、条件和 mutation 推进，
## 并发出结构化事件。显示、输入、存档和业务状态由项目层决定。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDialogueRunner
extends RefCounted


# --- 信号 ---

## 对话开始时发出。
## [br]
## @api public
## [br]
## @param resource: 对话资源。
signal dialogue_started(resource: GFDialogueResource)

## 到达可展示文本行时发出。
## [br]
## @api public
## [br]
## @param line: 当前行。
signal line_reached(line: GFDialogueLine)

## 请求执行 mutation 时发出。
## [br]
## @api public
## [br]
## @param mutation_id: mutation ID。
## [br]
## @param payload: mutation 载荷。
## [br]
## @schema payload: mutation 处理器接收的任意项目载荷；框架只透传。
## [br]
## @param line: 当前行。
signal mutation_requested(mutation_id: StringName, payload: Variant, line: GFDialogueLine)

## 对话结束时发出。
## [br]
## @api public
## [br]
## @param resource: 对话资源。
signal dialogue_ended(resource: GFDialogueResource)

## 推进被阻止时发出。
## [br]
## @api public
## [br]
## @param line_id: 被阻止的行 ID。
## [br]
## @param reason: 原因。
signal line_blocked(line_id: StringName, reason: StringName)


# --- 常量 ---

## 对话运行快照结构版本。
## [br]
## @api public
## [br]
## @since 5.0.0
const SNAPSHOT_SCHEMA_VERSION: int = 4


# --- 公共变量 ---

## 最多连续推进的非展示行数量，避免错误资源无限循环。
## [br]
## @api public
var max_steps_per_advance: int = 1024

## 条件不通过且没有 fallback 时，是否尝试跳到默认后继。
## [br]
## @api public
var skip_blocked_lines: bool = true


# --- 私有变量 ---

## 当前执行的对话资源。
## [br]
## @api private
var _resource: GFDialogueResource = null

## 当前会话使用的运行上下文。
## [br]
## @api private
var _context: GFDialogueContext = null

## 当前待处理或正在展示的行 ID。
## [br]
## @api private
var _current_line_id: StringName = &""

## 当前可展示行；会话尚未到达展示行时为 null。
## [br]
## @api private
var _current_line: GFDialogueLine = null

## 指示 Runner 是否处于活动会话中。
## [br]
## @api private
var _is_running: bool = false

## 保存架构实例的弱引用，供上下文准备时使用。
## [br]
## @api private
var _architecture_ref: WeakRef = null

## 当前资源完整身份的 SHA-256 指纹。
## [br]
## @api private
var _resource_fingerprint: String = ""

## 保留快照对应资源的强引用，使对话结束后仍能校验结束态快照的资源身份。
## [br]
## @api private
var _snapshot_resource: GFDialogueResource = null

## 标识当前会话代次，用于拒绝过期的同步回调结果。
## [br]
## @api private
var _session_serial: int = 0

## 当前快照推进深度所对应的会话代次。
## [br]
## @api private
var _snapshot_transition_serial: int = -1

## 当前会话内尚未结束的快照推进层数。
## [br]
## @api private
var _snapshot_transition_depth: int = 0

## 当前快照发布状态所对应的会话代次。
## [br]
## @api private
var _snapshot_publication_serial: int = -1

## 嵌套快照发布开始时记录的推进深度栈。
## [br]
## @api private
var _snapshot_publication_transition_depths: Array[int] = []


# --- 公共方法 ---

## 开始对话。
## [br]
## @api public
## [br]
## @param resource: 对话资源。
## [br]
## @param start_line_id: 可选起始行 ID。
## [br]
## @param context: 可选上下文。
## [br]
## @return: 到达的第一条可展示行；结束或失败时返回 null。
func start(
	resource: GFDialogueResource,
	start_line_id: StringName = &"",
	context: GFDialogueContext = null
) -> GFDialogueLine:
	if resource == null:
		return null
	var resource_fingerprint: String = _get_resource_fingerprint(resource)
	if resource_fingerprint.is_empty():
		return null
	if _is_running:
		var previous_session_serial: int = _session_serial
		_end_dialogue()
		if _is_running or _session_serial != previous_session_serial + 1:
			return null
		resource_fingerprint = _get_resource_fingerprint(resource)
		if resource_fingerprint.is_empty():
			return null
	_session_serial += 1
	_resource = resource
	_resource_fingerprint = resource_fingerprint
	_snapshot_resource = resource
	_context = _prepare_context(context)

	var start_line: GFDialogueLine = resource.get_start_line(start_line_id)
	_current_line_id = start_line.line_id if start_line != null else &""
	_current_line = null
	_is_running = true
	var session_lease: _DialogueSessionLease = _capture_session_lease()
	dialogue_started.emit(resource)
	if not _is_session_lease_current(session_lease):
		return null
	return advance()


## 推进对话。
## [br]
## @api public
## [br]
## @param response_id: 可选响应 ID；非空时从当前行选择响应后推进。
## [br]
## @return: 到达的下一条可展示行；结束或失败时返回 null。
func advance(response_id: StringName = &"") -> GFDialogueLine:
	if not _is_running or _resource == null:
		return null
	var transition_serial: int = _begin_snapshot_transition()
	var reached_line: GFDialogueLine = _advance_for_current_session(response_id)
	_end_snapshot_transition(transition_serial)
	return reached_line


## 选择当前行响应并推进。
## [br]
## @api public
## [br]
## @param response_id: 响应 ID。
## [br]
## @return: 到达的下一条可展示行；结束或失败时返回 null。
func choose_response(response_id: StringName) -> GFDialogueLine:
	return advance(response_id)


## 结束当前对话。
## [br]
## @api public
func stop() -> void:
	if not _is_running:
		return
	_end_dialogue()


## 获取当前行。
## [br]
## @api public
## [br]
## @return: 当前可展示行；没有时返回 null。
func get_current_line() -> GFDialogueLine:
	return _current_line


## 获取当前可用响应。
## [br]
## @api public
## [br]
## @return: 响应列表。
func get_available_responses() -> Array[GFDialogueResponse]:
	if _current_line == null:
		return []
	var lease: _DialogueSessionLease = _capture_session_lease()
	var responses: Array[GFDialogueResponse] = []
	for response: GFDialogueResponse in lease._line.responses:
		if response == null:
			continue
		var available: bool = response.is_available(lease._context)
		if not _is_session_lease_current(lease):
			return []
		if available:
			responses.append(response)
	return responses


## 检查是否正在运行。
## [br]
## @api public
## [br]
## @return: 运行中返回 true。
func is_running() -> bool:
	return _is_running


## 创建可存档的运行快照。
##
## 快照只保存 Runner 的当前位置和上下文值，不保存对话资源本体。
## 恢复时由调用方重新提供 GFDialogueResource，避免框架绑定项目存档结构。
## 只有已发布且资源身份一致的 TEXT checkpoint 或已提交的停止状态可创建快照；
## dialogue_started、推进中的条件与 mutation 回调、自动转换等窗口会返回空 Dictionary。
## 创建前会重新核对当前资源完整身份；会话开始或恢复后资源内容发生变化也会返回空 Dictionary。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return: 成功时返回运行快照；当前状态尚不可恢复时返回空 Dictionary。
## [br]
## @schema return: 包含 schema_version、is_running、current_line_id、resource_fingerprint 和 context_values 字段的 Dictionary。
func create_runtime_snapshot() -> Dictionary:
	if not _can_create_runtime_snapshot():
		return {}
	var context_values: Dictionary = _context.serialize_values() if _context != null else {}
	if _context != null and context_values.is_empty():
		return {}
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"is_running": _is_running,
		"current_line_id": _current_line_id,
		"resource_fingerprint": _resource_fingerprint,
		"context_values": context_values,
	}


## 从运行快照恢复到当前可展示行。
##
## 恢复不会重新触发 dialogue_started、line_reached 或 mutation_requested，
## 也不会重新执行 mutation。调用方可使用返回行刷新自己的 UI。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param resource: 快照对应的对话资源。
## [br]
## @param snapshot: create_runtime_snapshot() 生成的快照。
## [br]
## @param context: 可选上下文；全部快照及资源校验通过后调用其 deserialize_values()，保留子类恢复契约；为空时创建新上下文。
## [br]
## @return: 恢复后的当前可展示行；快照无效、已结束或资源不匹配时返回 null。
## [br]
## @schema snapshot: 包含 schema_version、is_running、current_line_id、resource_fingerprint 和 context_values 字段的 Dictionary。
func restore_runtime_snapshot(
	resource: GFDialogueResource,
	snapshot: Dictionary,
	context: GFDialogueContext = null
) -> GFDialogueLine:
	if GFVariantData.get_option_int(snapshot, "schema_version", -1) != SNAPSHOT_SCHEMA_VERSION:
		return null

	var context_value: Variant = snapshot.get("context_values")
	if not context_value is Dictionary:
		return null
	var context_values: Dictionary = context_value
	if resource == null:
		return null
	var snapshot_fingerprint: String = GFVariantData.get_option_string(snapshot, "resource_fingerprint")
	var resource_fingerprint: String = _get_resource_fingerprint(resource)
	if resource_fingerprint.is_empty():
		return null
	if snapshot_fingerprint == "" or snapshot_fingerprint != resource_fingerprint:
		return null

	var running: bool = GFVariantData.get_option_bool(snapshot, "is_running", false)
	var line_id: StringName = &""
	var line: GFDialogueLine = null
	if running:
		line_id = GFVariantData.get_option_string_name(snapshot, "current_line_id", &"")
		if line_id == &"":
			return null
		line = resource.get_line(line_id)
		if line == null or line.kind != GFDialogueLine.LineKind.TEXT:
			return null

	# The context owns its decoding and atomic failure contract. No fallible runner
	# validation may follow this call: a successful override has committed its state.
	var restored_context: GFDialogueContext = context if context != null else GFDialogueContext.new(_get_architecture_or_null())
	if not restored_context.deserialize_values(context_values):
		return null

	_reset_runtime_state()
	_resource = resource if running else null
	_resource_fingerprint = snapshot_fingerprint
	_snapshot_resource = resource
	_context = _prepare_context(restored_context)
	_current_line_id = line_id
	_current_line = line
	_is_running = running
	return line


## 获取运行快照。
## [br]
## @api public
## [br]
## @return: 调试快照。
## [br]
## @schema return: 包含 is_running、current_line_id、has_resource 和 context_values 字段的 Dictionary。
func get_debug_snapshot() -> Dictionary:
	return {
		"is_running": _is_running,
		"current_line_id": _current_line_id,
		"has_resource": _resource != null,
		"context_values": _context.serialize_values() if _context != null else {},
	}


# --- 框架内部方法 ---

## 注入架构。通常由 GFArchitecture 创建或注册时自动调用。
## [br]
## @api framework_internal
## [br]
## @param architecture: 架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


# --- 私有/辅助方法 ---

## 选择或创建运行上下文，并在其尚无架构时注入当前架构。
## [br]
## @api private
func _prepare_context(context: GFDialogueContext = null) -> GFDialogueContext:
	var resolved_context: GFDialogueContext = context if context != null else GFDialogueContext.new(_get_architecture_or_null())
	if resolved_context.get_architecture() == null:
		var _set_architecture_result_258: Variant = resolved_context.set_architecture(_get_architecture_or_null())
	return resolved_context


## 使旧会话租约失效并清除当前会话的资源、行和运行标志。
## [br]
## @api private
func _reset_runtime_state() -> void:
	_session_serial += 1
	_resource = null
	_snapshot_resource = null
	_current_line = null
	_current_line_id = &""
	_is_running = false


## 处理可选响应或当前行的默认后继，再推进到下一条展示行。
## [br]
## @api private
func _advance_for_current_session(response_id: StringName) -> GFDialogueLine:
	if response_id != &"":
		var session_lease: _DialogueSessionLease = _capture_session_lease()
		if not _apply_response(response_id):
			if not _is_session_lease_current(session_lease):
				return null
			return _current_line
	elif _current_line != null:
		if _current_line.has_responses():
			var session_lease: _DialogueSessionLease = _capture_session_lease()
			var available_responses: Array[GFDialogueResponse] = (
				session_lease._line.get_available_responses(session_lease._context)
			)
			if not _is_session_lease_current(session_lease):
				return null
			var reason: StringName = &"response_required" if not available_responses.is_empty() else &"no_available_response"
			if not _emit_line_blocked_for_lease(
				session_lease,
				session_lease._line.line_id,
				reason
			):
				return null
			return session_lease._line
		_current_line_id = _current_line.get_default_next_line_id()
		_current_line = null
		if _current_line_id == &"":
			_end_dialogue()
			return null
	return _advance_to_next_text()


## 跳过条件阻止的行并执行非展示行，直到到达文本行或会话结束。
## [br]
## @api private
func _advance_to_next_text() -> GFDialogueLine:
	var steps: int = 0
	var visited_line_ids: Dictionary = {}
	while _is_running:
		var session_lease: _DialogueSessionLease = _capture_session_lease()
		var line: GFDialogueLine = session_lease._resource.get_line(session_lease._line_id)
		if line == null:
			_end_session_after_block(
				session_lease,
				session_lease._line_id,
				&"missing_line"
			)
			return null
		var can_enter: bool = line.can_enter(session_lease._context)
		if not _is_session_lease_current(session_lease):
			return null
		if not can_enter:
			if not _try_begin_non_display_step(steps, session_lease, line.line_id):
				return null
			steps += 1
			if not _move_after_blocked_line(line, session_lease):
				return null
			continue
		if session_lease._line_id != &"":
			if visited_line_ids.has(session_lease._line_id):
				_end_session_after_block(
					session_lease,
					session_lease._line_id,
					&"automatic_cycle_detected"
				)
				return null
			visited_line_ids[session_lease._line_id] = true

		match line.kind:
			GFDialogueLine.LineKind.TEXT:
				_current_line = line
				var reached_lease: _DialogueSessionLease = _capture_session_lease()
				var publication_serial: int = _session_serial
				var publication_transition_depth: int = _begin_snapshot_publication()
				line_reached.emit(line)
				_end_snapshot_publication(
					publication_serial,
					publication_transition_depth
				)
				if not _is_session_lease_current(reached_lease):
					return null
				return line
			GFDialogueLine.LineKind.MUTATION:
				if not _try_begin_non_display_step(steps, session_lease, line.line_id):
					return null
				steps += 1
				if not _apply_line_mutation(line):
					if not _is_session_lease_current(session_lease):
						return null
					_end_session_after_block(
						session_lease,
						line.line_id,
						&"line_mutation_failed"
					)
					return null
				_current_line_id = line.get_default_next_line_id()
			GFDialogueLine.LineKind.JUMP:
				if not _try_begin_non_display_step(steps, session_lease, line.line_id):
					return null
				steps += 1
				_current_line_id = line.get_default_next_line_id()
			GFDialogueLine.LineKind.END:
				_end_dialogue()
				return null
			_:
				_end_session_after_block(
					session_lease,
					line.line_id,
					&"invalid_line_kind"
				)
				return null

		if _current_line_id == &"":
			_end_dialogue()
			return null
	return null


## 校验并应用当前行响应，执行其 mutation 后切换到后继行。
## [br]
## @api private
func _apply_response(response_id: StringName) -> bool:
	var session_lease: _DialogueSessionLease = _capture_session_lease()
	if session_lease._line == null:
		var _current_after_missing_line: bool = _emit_line_blocked_for_lease(
			session_lease,
			session_lease._line_id,
			&"missing_current_line"
		)
		return false

	var response: GFDialogueResponse = session_lease._line.get_response(response_id)
	if response == null:
		var _current_after_missing_response: bool = _emit_line_blocked_for_lease(
			session_lease,
			session_lease._line.line_id,
			&"missing_response"
		)
		return false
	var is_available: bool = response.is_available(session_lease._context)
	if not _is_session_lease_current(session_lease):
		return false
	if not is_available:
		var _current_after_response_condition: bool = _emit_line_blocked_for_lease(
			session_lease,
			session_lease._line.line_id,
			&"response_condition_failed"
		)
		return false

	if response.mutation_id != &"":
		mutation_requested.emit(response.mutation_id, response.mutation_payload, session_lease._line)
		if not _is_session_lease_current(session_lease):
			return false
		var mutation_result: Dictionary = session_lease._context.apply_mutation(
			response.mutation_id,
			response.mutation_payload,
			response
		)
		if not _is_session_lease_current(session_lease):
			return false
		if not GFVariantData.get_option_bool(mutation_result, "ok", false):
			var _current_after_response_mutation: bool = _emit_line_blocked_for_lease(
				session_lease,
				session_lease._line.line_id,
				&"response_mutation_failed"
			)
			return false
	var next_id: StringName = (
		response.next_line_id
		if response.next_line_id != &""
		else session_lease._line.get_default_next_line_id()
	)
	_current_line_id = next_id
	_current_line = null
	if _current_line_id == &"":
		_end_dialogue()
		return false
	return true


## 发出行 mutation 请求并委托上下文执行，返回处理结果。
## [br]
## @api private
func _apply_line_mutation(line: GFDialogueLine) -> bool:
	if line.mutation_id == &"":
		return true
	var session_lease: _DialogueSessionLease = _capture_session_lease()
	mutation_requested.emit(line.mutation_id, line.mutation_payload, line)
	if not _is_session_lease_current(session_lease):
		return false
	var mutation_result: Dictionary = session_lease._context.apply_mutation(
		line.mutation_id,
		line.mutation_payload,
		line
	)
	if not _is_session_lease_current(session_lease):
		return false
	return GFVariantData.get_option_bool(mutation_result, "ok", false)


## 发出阻止事件后尝试 fallback、默认跳过或结束当前会话。
## [br]
## @api private
func _move_after_blocked_line(
	line: GFDialogueLine,
	session_lease: _DialogueSessionLease
) -> bool:
	if not _emit_line_blocked_for_lease(session_lease, line.line_id, &"line_condition_failed"):
		return false
	if line.fallback_line_id != &"":
		_current_line_id = line.fallback_line_id
		return true
	if skip_blocked_lines:
		var continuation_id: StringName = line.next_line_id if line.kind == GFDialogueLine.LineKind.JUMP else line.get_default_next_line_id()
		if continuation_id != &"":
			_current_line_id = continuation_id
			return true
	_end_dialogue()
	return false


## 捕获当前会话字段，用于同步回调前后的代次校验。
## [br]
## @api private
func _capture_session_lease() -> _DialogueSessionLease:
	var lease: _DialogueSessionLease = _DialogueSessionLease.new()
	lease._session_serial = _session_serial
	lease._resource = _resource
	lease._context = _context
	lease._line_id = _current_line_id
	lease._line = _current_line
	return lease


## 仅在租约有效时发送阻塞信号，并在同步信号回调后重新校验会话。
## 回调可能结束或替换会话；调用方只能在返回 true 时继续修改原会话。
## [br]
## @api private
## [br]
## @return: 原会话租约仍有效；返回 false 不代表信号一定未发出。
func _emit_line_blocked_for_lease(
	session_lease: _DialogueSessionLease,
	line_id: StringName,
	reason: StringName
) -> bool:
	if not _is_session_lease_current(session_lease):
		return false
	line_blocked.emit(line_id, reason)
	return _is_session_lease_current(session_lease)


## 在会话租约仍有效时发送阻止事件并结束会话。
## [br]
## @api private
func _end_session_after_block(
	session_lease: _DialogueSessionLease,
	line_id: StringName,
	reason: StringName
) -> void:
	if _emit_line_blocked_for_lease(session_lease, line_id, reason):
		_end_dialogue()


## 在非展示步骤尚未达到推进上限时允许继续，否则结束会话。
## [br]
## @api private
func _try_begin_non_display_step(
	steps: int,
	session_lease: _DialogueSessionLease,
	line_id: StringName
) -> bool:
	if max_steps_per_advance <= 0 or steps < max_steps_per_advance:
		return true
	_end_session_after_block(session_lease, line_id, &"max_steps_reached")
	return false


## 清除运行会话、保留结束快照的资源引用并发出结束信号。
## [br]
## @api private
func _end_dialogue() -> void:
	var ended_resource: GFDialogueResource = _resource
	_session_serial += 1
	_snapshot_resource = ended_resource
	_current_line = null
	_current_line_id = &""
	_resource = null
	_is_running = false
	if ended_resource != null:
		dialogue_ended.emit(ended_resource)


## 检查租约记录的会话代次、资源、上下文和当前行是否仍匹配。
## [br]
## @api private
func _is_session_lease_current(session_lease: _DialogueSessionLease) -> bool:
	return (
		_is_running
		and session_lease != null
		and _session_serial == session_lease._session_serial
		and _resource == session_lease._resource
		and _context == session_lease._context
		and _current_line_id == session_lease._line_id
		and _current_line == session_lease._line
	)


## 判断当前状态、推进窗口及资源身份是否允许生成运行快照。
## [br]
## @api private
func _can_create_runtime_snapshot() -> bool:
	if (
		_resource_fingerprint.is_empty()
		or _context == null
	):
		return false
	var state_is_restorable: bool = (
		_resource == null
		and _current_line == null
		and _current_line_id == &""
		and not _is_running
	) if not _is_running else _is_current_text_checkpoint_consistent()
	if not state_is_restorable:
		return false
	if _is_snapshot_transition_active() and not _is_snapshot_publication_active():
		return false
	return _snapshot_resource_identity_is_current()


## 验证当前状态指向资源中同一实例的文本检查点。
## [br]
## @api private
func _is_current_text_checkpoint_consistent() -> bool:
	if (
		not _is_running
		or _resource == null
		or _current_line == null
		or _current_line_id == &""
		or _current_line.kind != GFDialogueLine.LineKind.TEXT
		or _current_line.line_id != _current_line_id
	):
		return false
	return _resource.get_line(_current_line_id) == _current_line


## 重新计算快照资源指纹并与会话保存的指纹比较。
## [br]
## @api private
func _snapshot_resource_identity_is_current() -> bool:
	var snapshot_resource: GFDialogueResource = _get_snapshot_resource_or_null()
	if snapshot_resource == null:
		return false
	var current_fingerprint: String = _get_resource_fingerprint(snapshot_resource, false)
	return not current_fingerprint.is_empty() and current_fingerprint == _resource_fingerprint


## 返回活动会话资源；会话结束后返回保留的快照资源。
## [br]
## @api private
func _get_snapshot_resource_or_null() -> GFDialogueResource:
	if _resource != null:
		return _resource
	return _snapshot_resource


## 开始当前会话的一层快照推进并返回会话代次。
## [br]
## @api private
func _begin_snapshot_transition() -> int:
	if _snapshot_transition_serial != _session_serial:
		_snapshot_transition_serial = _session_serial
		_snapshot_transition_depth = 0
	_snapshot_transition_depth += 1
	return _session_serial


## 仅在代次匹配且深度有效时结束一层快照推进。
## [br]
## @api private
func _end_snapshot_transition(transition_serial: int) -> void:
	if (
		_snapshot_transition_serial != transition_serial
		or _snapshot_transition_depth <= 0
	):
		return
	_snapshot_transition_depth -= 1


## 记录当前推进深度并开始一层快照发布窗口。
## [br]
## @api private
func _begin_snapshot_publication() -> int:
	if _snapshot_publication_serial != _session_serial:
		_snapshot_publication_serial = _session_serial
		_snapshot_publication_transition_depths.clear()
	_snapshot_publication_transition_depths.append(_snapshot_transition_depth)
	return _snapshot_transition_depth


## 在会话代次和发布栈顶深度仍匹配时结束发布窗口。
## [br]
## @api private
func _end_snapshot_publication(
	publication_serial: int,
	publication_transition_depth: int
) -> void:
	if (
		_snapshot_publication_serial != publication_serial
		or _snapshot_publication_transition_depths.is_empty()
		or _snapshot_publication_transition_depths.back() != publication_transition_depth
	):
		return
	_snapshot_publication_transition_depths.pop_back()


## 判断当前会话是否处于快照推进窗口。
## [br]
## @api private
func _is_snapshot_transition_active() -> bool:
	return (
		_snapshot_transition_serial == _session_serial
		and _snapshot_transition_depth > 0
	)


## 判断当前会话是否处于与当前推进深度匹配的发布窗口。
## [br]
## @api private
func _is_snapshot_publication_active() -> bool:
	return (
		_snapshot_publication_serial == _session_serial
		and not _snapshot_publication_transition_depths.is_empty()
		and _snapshot_publication_transition_depths.back() == _snapshot_transition_depth
	)


## 优先从弱引用获取架构，失效时回退到全局架构访问器。
## [br]
## @api private
func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture: GFArchitecture = _get_architecture_value(_architecture_ref.get_ref())
		if architecture != null:
			return architecture
	return GFAutoload.get_architecture_or_null()


## 将任意值收窄为 GFArchitecture 实例，否则返回 null。
## [br]
## @api private
func _get_architecture_value(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


## 生成资源完整身份的规范化 JSON SHA-256 指纹。
## 身份无法完整编码时返回空字符串，并可选择输出诊断。
## [br]
## @api private
func _get_resource_fingerprint(
	resource: GFDialogueResource,
	report_errors: bool = true
) -> String:
	if resource == null:
		return ""
	var identity_report: Dictionary = resource.build_identity_report()
	if not GFVariantData.get_option_bool(identity_report, "ok", false):
		if report_errors:
			push_error(
				"[GFDialogueRunner][dialogue_runner.incomplete_resource_identity] Refused an incomplete resource identity (%s at %s)." % [
					GFVariantData.get_option_string(identity_report, "error", "unknown_error"),
					GFVariantData.get_option_string(identity_report, "path", "$"),
				]
			)
		return ""
	var identity_value: Variant = identity_report.get("value")
	var encoded_identity_value: Variant = GFVariantJsonCodec.variant_to_json_compatible(
		identity_value,
		{
			"encode_dictionary_keys": true,
			"encode_unsafe_ints": true,
			"max_depth": 0,
			"max_nodes": 0,
			"max_collection_items": 0,
		}
	)
	var canonical_identity: Variant = _canonicalize_identity_json(encoded_identity_value)
	var encoded_identity: String = JSON.stringify(canonical_identity, "", true)
	if encoded_identity.is_empty():
		if report_errors:
			push_error("[GFDialogueRunner][dialogue_runner.resource_identity_encoding_failed] Could not encode the complete resource identity.")
		return ""
	return encoded_identity.sha256_text()


## 递归规范化身份 JSON，并对编码后的字典条目进行排序。
## [br]
## @api private
func _canonicalize_identity_json(value: Variant) -> Variant:
	if value is Array:
		var source_array: Array = value
		var canonical_array: Array = []
		for item: Variant in source_array:
			canonical_array.append(_canonicalize_identity_json(item))
		return canonical_array
	if value is Dictionary:
		var source_dictionary: Dictionary = value
		var canonical_dictionary: Dictionary = {}
		for key: Variant in source_dictionary:
			canonical_dictionary[key] = _canonicalize_identity_json(source_dictionary[key])
		if _is_encoded_dictionary_marker(canonical_dictionary):
			_sort_encoded_dictionary_entries(canonical_dictionary)
		return canonical_dictionary
	return value


## 检查字典是否符合当前 JSON Codec 的编码字典标记结构。
## [br]
## @api private
func _is_encoded_dictionary_marker(value: Dictionary) -> bool:
	if value.size() != 1 or not value.has(GFVariantJsonCodec.JSON_MARKER_KEY):
		return false
	var marker: Dictionary = GFVariantData.as_dictionary(
		value.get(GFVariantJsonCodec.JSON_MARKER_KEY)
	)
	return (
		GFVariantData.get_option_int(marker, GFVariantJsonCodec.JSON_VERSION_KEY, 0)
			== GFVariantJsonCodec.JSON_SCHEMA_VERSION
		and GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_CODEC_KEY)
			== GFVariantJsonCodec.JSON_CODEC_ID
		and GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_TYPE_KEY)
			== "Dictionary"
		and marker.get(GFVariantJsonCodec.JSON_VALUE_KEY) is Array
	)


## 按规范比较器排序编码字典条目并写回标记值。
## [br]
## @api private
func _sort_encoded_dictionary_entries(value: Dictionary) -> void:
	var marker: Dictionary = GFVariantData.as_dictionary(
		value.get(GFVariantJsonCodec.JSON_MARKER_KEY)
	)
	var entries: Array = GFVariantData.get_option_array(
		marker,
		GFVariantJsonCodec.JSON_VALUE_KEY
	)
	entries.sort_custom(_encoded_dictionary_entry_less)
	marker[GFVariantJsonCodec.JSON_VALUE_KEY] = entries
	value[GFVariantJsonCodec.JSON_MARKER_KEY] = marker


## 先比较编码键，再比较完整条目的 JSON 文本以确定稳定顺序。
## [br]
## @api private
func _encoded_dictionary_entry_less(first_value: Variant, second_value: Variant) -> bool:
	var first: Dictionary = GFVariantData.as_dictionary(first_value)
	var second: Dictionary = GFVariantData.as_dictionary(second_value)
	var first_key: String = JSON.stringify(first.get("key"), "", true)
	var second_key: String = JSON.stringify(second.get("key"), "", true)
	if first_key != second_key:
		return first_key < second_key
	return JSON.stringify(first, "", true) < JSON.stringify(second, "", true)


# --- 内部类 ---

## 记录一次回调前捕获的会话代次及资源、上下文和行状态。
## [br]
## @api private
class _DialogueSessionLease extends RefCounted:
	# --- 私有变量 ---

	## 回调前捕获的会话代次，用于拒绝旧会话继续写回。
	## [br]
	## @api private
	var _session_serial: int = 0

	## 捕获时的对话资源引用，用于回调后身份复核。
	## [br]
	## @api private
	var _resource: GFDialogueResource = null

	## 捕获时的上下文引用，用于确认会话仍使用同一上下文。
	## [br]
	## @api private
	var _context: GFDialogueContext = null

	## 捕获时的行标识，供回调后当前行资格检查。
	## [br]
	## @api private
	var _line_id: StringName = &""

	## 捕获时的行资源引用；与行标识一起校验当前行身份。
	## [br]
	## @api private
	var _line: GFDialogueLine = null
