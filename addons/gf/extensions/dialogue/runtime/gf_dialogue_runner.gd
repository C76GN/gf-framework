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
const SNAPSHOT_SCHEMA_VERSION: int = 2


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

var _resource: GFDialogueResource = null
var _context: GFDialogueContext = null
var _current_line_id: StringName = &""
var _current_line: GFDialogueLine = null
var _is_running: bool = false
var _architecture_ref: WeakRef = null


# --- 公共方法 ---

## 注入架构。通常由 GFArchitecture 创建或注册时自动调用。
## [br]
## @api framework_internal
## [br]
## @param architecture: 架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


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
	if _is_running:
		_end_dialogue()
	_resource = resource
	_context = _prepare_context(context)

	var start_line: GFDialogueLine = resource.get_start_line(start_line_id)
	_current_line_id = start_line.line_id if start_line != null else &""
	_current_line = null
	_is_running = true
	dialogue_started.emit(resource)
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
	if response_id != &"":
		if not _apply_response(response_id):
			return _current_line
	elif _current_line != null:
		_current_line_id = _current_line.get_default_next_line_id()
		_current_line = null
		if _current_line_id == &"":
			_end_dialogue()
			return null
	return _advance_to_next_text()


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
	return _current_line.get_available_responses(_context)


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
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return: 运行快照。
## [br]
## @schema return: 包含 schema_version、is_running、current_line_id、resource_fingerprint 和 context_values 字段的 Dictionary。
func create_runtime_snapshot() -> Dictionary:
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"is_running": _is_running,
		"current_line_id": _current_line_id,
		"resource_fingerprint": _get_resource_fingerprint(_resource),
		"context_values": _context.serialize_values() if _context != null else {},
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
## @param context: 可选上下文；为空时创建新上下文并恢复快照中的 context_values。
## [br]
## @return: 恢复后的当前可展示行；快照无效、已结束或资源不匹配时返回 null。
## [br]
## @schema snapshot: 包含 schema_version、is_running、current_line_id、resource_fingerprint 和 context_values 字段的 Dictionary。
func restore_runtime_snapshot(
	resource: GFDialogueResource,
	snapshot: Dictionary,
	context: GFDialogueContext = null
) -> GFDialogueLine:
	_reset_runtime_state()

	if GFVariantData.get_option_int(snapshot, "schema_version", -1) != SNAPSHOT_SCHEMA_VERSION:
		return null

	var restored_context: GFDialogueContext = _prepare_context(context)
	restored_context.deserialize_values(GFVariantData.get_option_dictionary(snapshot, "context_values", {}))
	_context = restored_context

	if not GFVariantData.get_option_bool(snapshot, "is_running", false):
		return null
	if resource == null:
		return null
	var snapshot_fingerprint: String = GFVariantData.get_option_string(snapshot, "resource_fingerprint")
	if snapshot_fingerprint == "" or snapshot_fingerprint != _get_resource_fingerprint(resource):
		return null

	var line_id: StringName = GFVariantData.get_option_string_name(snapshot, "current_line_id", &"")
	if line_id == &"":
		return null

	var line: GFDialogueLine = resource.get_line(line_id)
	if line == null or line.kind != GFDialogueLine.LineKind.TEXT:
		return null

	_resource = resource
	_current_line_id = line_id
	_current_line = line
	_is_running = true
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


# --- 私有/辅助方法 ---

func _prepare_context(context: GFDialogueContext = null) -> GFDialogueContext:
	var resolved_context: GFDialogueContext = context if context != null else GFDialogueContext.new(_get_architecture_or_null())
	if resolved_context.get_architecture() == null:
		var _set_architecture_result_258: Variant = resolved_context.set_architecture(_get_architecture_or_null())
	return resolved_context


func _reset_runtime_state() -> void:
	_resource = null
	_current_line = null
	_current_line_id = &""
	_is_running = false


func _advance_to_next_text() -> GFDialogueLine:
	var steps: int = 0
	var visited_line_ids: Dictionary = {}
	while _is_running:
		if max_steps_per_advance > 0 and steps >= max_steps_per_advance:
			line_blocked.emit(_current_line_id, &"max_steps_reached")
			_end_dialogue()
			return null
		steps += 1

		if _current_line_id != &"":
			if visited_line_ids.has(_current_line_id):
				line_blocked.emit(_current_line_id, &"automatic_cycle_detected")
				_end_dialogue()
				return null
			visited_line_ids[_current_line_id] = true

		var line: GFDialogueLine = _resource.get_line(_current_line_id)
		if line == null:
			_end_dialogue()
			return null
		if not line.can_enter(_context):
			if not _move_after_blocked_line(line):
				return null
			continue

		match line.kind:
			GFDialogueLine.LineKind.TEXT:
				_current_line = line
				line_reached.emit(line)
				return line
			GFDialogueLine.LineKind.MUTATION:
				if not _apply_line_mutation(line):
					line_blocked.emit(line.line_id, &"line_mutation_failed")
					_end_dialogue()
					return null
				_current_line_id = line.get_default_next_line_id()
			GFDialogueLine.LineKind.JUMP:
				_current_line_id = line.get_default_next_line_id()
			GFDialogueLine.LineKind.END:
				_end_dialogue()
				return null

		if _current_line_id == &"":
			_end_dialogue()
			return null
	return null


func _apply_response(response_id: StringName) -> bool:
	if _current_line == null:
		line_blocked.emit(_current_line_id, &"missing_current_line")
		return false

	var response: GFDialogueResponse = _current_line.get_response(response_id)
	if response == null:
		line_blocked.emit(_current_line.line_id, &"missing_response")
		return false
	if not response.is_available(_context):
		line_blocked.emit(_current_line.line_id, &"response_condition_failed")
		return false

	if response.mutation_id != &"":
		var mutation_result: Dictionary = _context.apply_mutation(response.mutation_id, response.mutation_payload, response)
		if not GFVariantData.get_option_bool(mutation_result, "ok", false):
			line_blocked.emit(_current_line.line_id, &"response_mutation_failed")
			return false
	var next_id: StringName = response.next_line_id if response.next_line_id != &"" else _current_line.get_default_next_line_id()
	_current_line_id = next_id
	_current_line = null
	if _current_line_id == &"":
		_end_dialogue()
		return false
	return true


func _apply_line_mutation(line: GFDialogueLine) -> bool:
	if line.mutation_id == &"":
		return true
	mutation_requested.emit(line.mutation_id, line.mutation_payload, line)
	var mutation_result: Dictionary = _context.apply_mutation(line.mutation_id, line.mutation_payload, line)
	return GFVariantData.get_option_bool(mutation_result, "ok", false)


func _move_after_blocked_line(line: GFDialogueLine) -> bool:
	line_blocked.emit(line.line_id, &"line_condition_failed")
	if line.fallback_line_id != &"":
		_current_line_id = line.fallback_line_id
		return true
	if skip_blocked_lines and line.get_default_next_line_id() != &"":
		_current_line_id = line.get_default_next_line_id()
		return true
	_end_dialogue()
	return false


func _end_dialogue() -> void:
	var ended_resource: GFDialogueResource = _resource
	_current_line = null
	_current_line_id = &""
	_resource = null
	_is_running = false
	if ended_resource != null:
		dialogue_ended.emit(ended_resource)


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture: GFArchitecture = _get_architecture_value(_architecture_ref.get_ref())
		if architecture != null:
			return architecture
	return GFAutoload.get_architecture_or_null()


func _get_architecture_value(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


func _get_resource_fingerprint(resource: GFDialogueResource) -> String:
	if resource == null:
		return ""
	return JSON.stringify(resource.to_dictionary())
