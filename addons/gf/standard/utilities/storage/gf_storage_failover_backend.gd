## GFStorageFailoverBackend: 有序存储故障转移后端。
##
## 该组合后端按稳定 ID 管理一组调用方持有的 `GFStorageBackend`。读取总是按序
## 尝试，写入和删除可选择只访问主后端或在失败后访问下一后端。它不会复制、
## 同步或关闭子后端，也不宣称跨后端原子性；需要镜像和冲突处理时应使用
## `GFStorageSyncUtility`。每次操作都会保留一个不含业务数据的有界尝试报告。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFStorageFailoverBackend
extends GFStorageBackend


# --- 枚举 ---

## 写入和删除的后端选择策略。
## [br]
## @api public
## [br]
## @since unreleased
enum MutationPolicy {
	## 只访问第一个配置后端，错误原样返回。
	PRIMARY_ONLY,
	## 按顺序尝试，首次成功后立即停止。
	FIRST_SUCCESS,
}


# --- 常量 ---

const _MAX_BACKEND_COUNT: int = 32
const _MAX_FAILURE_THRESHOLD: int = 1000
const _MAX_COOLDOWN_MSEC: int = 86_400_000
const _DEFAULT_FAILURE_THRESHOLD: int = 2
const _DEFAULT_COOLDOWN_MSEC: int = 30_000

const _STATUS_SUCCEEDED: String = "succeeded"
const _STATUS_FAILED: String = "failed"
const _STATUS_SKIPPED: String = "skipped"
const _STATUS_MISS: String = "miss"

const _REASON_UNSUPPORTED: String = "unsupported"
const _REASON_COOLDOWN: String = "cooldown"


# --- 私有变量 ---

var _backends: Array[GFStorageBackend] = []
var _backend_ids: PackedStringArray = PackedStringArray()
var _mutation_policy: MutationPolicy = MutationPolicy.FIRST_SUCCESS
var _failure_threshold: int = _DEFAULT_FAILURE_THRESHOLD
var _cooldown_msec: int = _DEFAULT_COOLDOWN_MSEC
var _clock: GFClock = GFClock.new()
var _health_by_backend_id: Dictionary = {}
var _last_operation_report: Dictionary = {}


# --- 公共方法 ---

## 原子替换有序子后端及其稳定 ID。
##
## 子后端由调用方持有和管理生命周期；同一实例或同一 ID 不能重复注册。
## 配置失败时保留原配置。健康熔断只统计明确的暂时性 Godot Error。
## `failure_threshold` 或 `cooldown_msec` 为 0 时关闭冷却跳过。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param backends: 按优先级从高到低排列的子后端，数量限制为 1 至 32。
## [br]
## @param backend_ids: 与子后端一一对应的稳定 ID；为空时生成 backend_0 等 ID。
## [br]
## @param options: mutation_policy、failure_threshold（0 至 1000）和 cooldown_msec（0 至 86400000）；非法类型或范围会使配置整体失败。
## [br]
## @schema options: Dictionary，包含 mutation_policy: MutationPolicy、failure_threshold: int 和 cooldown_msec: int。
## [br]
## @return 配置合法并完成替换时返回 true。
func configure_backends(
	backends: Array[GFStorageBackend],
	backend_ids: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> bool:
	if backends.is_empty() or backends.size() > _MAX_BACKEND_COUNT:
		return false
	if not backend_ids.is_empty() and backend_ids.size() != backends.size():
		return false
	var parsed_options: Dictionary = _parse_options(options, false)
	if not GFVariantData.get_option_bool(parsed_options, "ok"):
		return false

	var candidate_backends: Array[GFStorageBackend] = []
	var candidate_ids: PackedStringArray = PackedStringArray()
	var seen_instances: Dictionary = {}
	var seen_ids: Dictionary = {}
	for index: int in range(backends.size()):
		var backend: GFStorageBackend = backends[index]
		if backend == null or not is_instance_valid(backend) or backend == self:
			return false
		var instance_id: int = backend.get_instance_id()
		if seen_instances.has(instance_id):
			return false
		seen_instances[instance_id] = true

		var backend_id_text: String = backend_ids[index].strip_edges() if not backend_ids.is_empty() else "backend_%d" % index
		if backend_id_text.is_empty():
			return false
		var backend_id: StringName = StringName(backend_id_text)
		if seen_ids.has(backend_id):
			return false
		seen_ids[backend_id] = true
		candidate_backends.append(backend)
		var _id_append: bool = candidate_ids.append(backend_id_text)

	_backends = candidate_backends
	_backend_ids = candidate_ids
	_apply_parsed_options(parsed_options)
	_reset_all_health()
	_last_operation_report.clear()
	return true


## 注入用于冷却窗口的单调时钟。
##
## 时钟域变化时会清空既有失败计数和冷却截止时间，避免用新时钟解释旧时间戳。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param clock: 系统、测试或模拟时钟。
## [br]
## @return 非空时钟设置成功返回 true。
func set_clock(clock: GFClock) -> bool:
	if clock == null:
		return false
	_clock = clock
	_reset_all_health()
	return true


## 返回当前子后端数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置子后端数量。
func get_backend_count() -> int:
	return _backends.size()


## 返回有序稳定后端 ID 副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与子后端顺序一致的稳定 ID。
func get_backend_ids() -> PackedStringArray:
	return _backend_ids.duplicate()


## 返回最近一次操作的结构化尝试报告。
##
## 报告最多包含 32 个尝试项，不包含读写业务载荷或后端私有元数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 报告深拷贝；尚未执行操作时返回空字典。
## [br]
## @schema return: Dictionary，包含 schema_version、operation、file_name、ok、selected_backend_id、error_code、error、attempt_count、skipped_count、attempts 和 timestamp_msec；每个 attempt 包含 backend_id、backend_index、capability、status、reason、error_code、error、consecutive_failures 和 cooldown_until_msec。
func get_last_operation_report() -> Dictionary:
	return _last_operation_report.duplicate(true)


## 返回后端健康与冷却状态快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 配置和逐后端健康状态，不包含业务数据。
## [br]
## @schema return: Dictionary，包含 mutation_policy、failure_threshold、cooldown_msec、backend_count 和 backends；每个 backend 包含 backend_id、backend_index、consecutive_failures、cooldown_until_msec 和 cooling_down。
func get_health_snapshot() -> Dictionary:
	var backend_states: Array[Dictionary] = []
	for index: int in range(_backends.size()):
		var backend_id: StringName = _get_backend_id(index)
		var state: Dictionary = _get_health_state(backend_id)
		backend_states.append({
			"backend_id": backend_id,
			"backend_index": index,
			"consecutive_failures": GFVariantData.get_option_int(state, "consecutive_failures"),
			"cooldown_until_msec": GFVariantData.get_option_int(state, "cooldown_until_msec"),
			"cooling_down": _is_backend_cooling_down(backend_id),
		})
	return {
		"mutation_policy": int(_mutation_policy),
		"failure_threshold": _failure_threshold,
		"cooldown_msec": _cooldown_msec,
		"backend_count": _backends.size(),
		"backends": backend_states,
	}


## 重置一个或全部后端的失败计数与冷却窗口。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param backend_id: 目标稳定 ID；为空时重置全部后端。
## [br]
## @return 至少重置一个已配置后端时返回 true。
func reset_backend_health(backend_id: StringName = &"") -> bool:
	if backend_id == &"":
		if _backends.is_empty():
			return false
		_reset_all_health()
		return true
	if not _health_by_backend_id.has(backend_id):
		return false
	_health_by_backend_id[backend_id] = _make_healthy_state()
	return true


# --- 可重写钩子 / 虚方法 ---

## 校验组合后端已配置，并应用故障转移选项；不初始化子后端。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param config: mutation_policy、failure_threshold（0 至 1000）和 cooldown_msec（0 至 86400000）。
## [br]
## @schema config: Dictionary，包含 mutation_policy: MutationPolicy、failure_threshold: int 和 cooldown_msec: int。
## [br]
## @return 已配置且选项合法时返回 OK；未配置返回 ERR_UNCONFIGURED，非法选项返回 ERR_INVALID_PARAMETER。
func _initialize(config: Dictionary) -> Error:
	if _backends.is_empty():
		return ERR_UNCONFIGURED
	var parsed_options: Dictionary = _parse_options(config, true)
	if not GFVariantData.get_option_bool(parsed_options, "ok"):
		return ERR_INVALID_PARAMETER
	_apply_parsed_options(parsed_options)
	_reset_all_health()
	_last_operation_report.clear()
	return OK


## 清空运行期报告和健康状态；不关闭调用方持有的子后端。
## [br]
## @api protected
## [br]
## @since unreleased
func _shutdown() -> void:
	_reset_all_health()
	_last_operation_report.clear()


## 按当前 mutation_policy 保存数据。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @param data: 业务数据副本。
## [br]
## @param metadata: 元数据副本。
## [br]
## @schema data: Dictionary，调用方业务数据。
## [br]
## @schema metadata: Dictionary，后端特定元数据。
## [br]
## @return 首次成功时返回 OK，否则返回最后一个可观察错误。
func _save_data(file_name: String, data: Dictionary, metadata: Dictionary) -> Error:
	return _execute_mutation(&"save", file_name, data, metadata)


## 按顺序读取首个成功结果。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @return 首个成功子后端结果或聚合失败结果。
## [br]
## @schema return: Dictionary，包含 ok、data、metadata、error 和 error_code。
func _load_data(file_name: String) -> Dictionary:
	var attempts: Array[Dictionary] = []
	var last_error_code: Error = ERR_UNAVAILABLE
	var last_error: String = "No readable storage backend succeeded."
	for index: int in range(_backends.size()):
		var backend_id: StringName = _get_backend_id(index)
		var skip_reason: String = _get_skip_reason(index, &"read")
		if not skip_reason.is_empty():
			attempts.append(_make_attempt(index, &"read", _STATUS_SKIPPED, skip_reason, ERR_UNAVAILABLE, ""))
			continue

		var result: Dictionary = _backends[index].load_data(file_name)
		var ok: bool = GFVariantData.get_option_bool(result, "ok")
		var error_code: Error = _get_load_error_code(result, ok)
		var error_text: String = GFVariantData.get_option_string(result, "error")
		if ok:
			_mark_backend_success(backend_id)
			attempts.append(_make_attempt(index, &"read", _STATUS_SUCCEEDED, "", OK, ""))
			_set_last_report(&"load", file_name, true, backend_id, OK, "", attempts)
			return result.duplicate(true)

		last_error_code = error_code
		last_error = error_text if not error_text.is_empty() else error_string(error_code)
		_mark_backend_result(backend_id, error_code)
		attempts.append(_make_attempt(index, &"read", _STATUS_FAILED, "", error_code, last_error))

	_set_last_report(&"load", file_name, false, &"", last_error_code, last_error, attempts)
	return {
		"ok": false,
		"data": {},
		"metadata": {},
		"error": last_error,
		"error_code": int(last_error_code),
	}


## 按当前 mutation_policy 删除数据。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @return 首次成功时返回 OK，否则返回最后一个可观察错误。
func _delete_data(file_name: String) -> Error:
	return _execute_mutation(&"delete", file_name)


## 按顺序检查任一可读后端是否包含数据。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @return 任一可读后端存在数据时返回 true。
func _has_data(file_name: String) -> bool:
	var attempts: Array[Dictionary] = []
	for index: int in range(_backends.size()):
		var backend_id: StringName = _get_backend_id(index)
		var skip_reason: String = _get_skip_reason(index, &"read")
		if not skip_reason.is_empty():
			attempts.append(_make_attempt(index, &"read", _STATUS_SKIPPED, skip_reason, ERR_UNAVAILABLE, ""))
			continue
		if _backends[index].has_data(file_name):
			_mark_backend_success(backend_id)
			attempts.append(_make_attempt(index, &"read", _STATUS_SUCCEEDED, "", OK, ""))
			_set_last_report(&"has", file_name, true, backend_id, OK, "", attempts)
			return true
		_mark_backend_success(backend_id)
		attempts.append(_make_attempt(index, &"read", _STATUS_MISS, "", ERR_DOES_NOT_EXIST, ""))

	_set_last_report(&"has", file_name, false, &"", ERR_DOES_NOT_EXIST, "Data was not found.", attempts)
	return false


## 从首个支持枚举且未冷却的后端读取文件摘要。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 首个可用后端的文件摘要。
## [br]
## @schema return: Array，包含 file_name 和可选 metadata 的 Dictionary 条目。
func _list_data() -> Array[Dictionary]:
	var attempts: Array[Dictionary] = []
	for index: int in range(_backends.size()):
		var backend_id: StringName = _get_backend_id(index)
		var skip_reason: String = _get_skip_reason(index, &"list")
		if not skip_reason.is_empty():
			attempts.append(_make_attempt(index, &"list", _STATUS_SKIPPED, skip_reason, ERR_UNAVAILABLE, ""))
			continue
		var entries: Array[Dictionary] = _backends[index].list_data()
		_mark_backend_success(backend_id)
		attempts.append(_make_attempt(index, &"list", _STATUS_SUCCEEDED, "", OK, ""))
		_set_last_report(&"list", "", true, backend_id, OK, "", attempts)
		return entries

	_set_last_report(&"list", "", false, &"", ERR_UNAVAILABLE, "No list-capable backend is available.", attempts)
	return []


## 汇总组合后端能力。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return read、write、delete、list 和 sync 能力。
## [br]
## @schema return: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。
func _get_capabilities() -> Dictionary:
	return {
		"read": _has_any_capability(&"read"),
		"write": _has_mutation_capability(&"write"),
		"delete": _has_mutation_capability(&"delete"),
		"list": _has_any_capability(&"list"),
		"sync": false,
	}


# --- 私有/辅助方法 ---

func _parse_options(options: Dictionary, use_current_defaults: bool) -> Dictionary:
	var default_policy: int = int(_mutation_policy) if use_current_defaults else int(MutationPolicy.FIRST_SUCCESS)
	var default_failure_threshold: int = _failure_threshold if use_current_defaults else _DEFAULT_FAILURE_THRESHOLD
	var default_cooldown_msec: int = _cooldown_msec if use_current_defaults else _DEFAULT_COOLDOWN_MSEC
	var mutation_policy_value: Variant = GFVariantData.get_option_value(
		options,
		"mutation_policy",
		default_policy
	)
	var failure_threshold_value: Variant = GFVariantData.get_option_value(
		options,
		"failure_threshold",
		default_failure_threshold
	)
	var cooldown_msec_value: Variant = GFVariantData.get_option_value(
		options,
		"cooldown_msec",
		default_cooldown_msec
	)
	if not (mutation_policy_value is int):
		return {"ok": false}
	if not (failure_threshold_value is int):
		return {"ok": false}
	if not (cooldown_msec_value is int):
		return {"ok": false}
	var mutation_policy: int = mutation_policy_value
	var failure_threshold: int = failure_threshold_value
	var cooldown_msec: int = cooldown_msec_value
	if mutation_policy != MutationPolicy.PRIMARY_ONLY and mutation_policy != MutationPolicy.FIRST_SUCCESS:
		return {"ok": false}
	if failure_threshold < 0 or failure_threshold > _MAX_FAILURE_THRESHOLD:
		return {"ok": false}
	if cooldown_msec < 0 or cooldown_msec > _MAX_COOLDOWN_MSEC:
		return {"ok": false}
	return {
		"ok": true,
		"mutation_policy": mutation_policy,
		"failure_threshold": failure_threshold,
		"cooldown_msec": cooldown_msec,
	}


func _apply_parsed_options(parsed_options: Dictionary) -> void:
	_mutation_policy = _to_mutation_policy(
		GFVariantData.get_option_int(parsed_options, "mutation_policy", int(MutationPolicy.FIRST_SUCCESS))
	)
	_failure_threshold = GFVariantData.get_option_int(
		parsed_options,
		"failure_threshold",
		_DEFAULT_FAILURE_THRESHOLD
	)
	_cooldown_msec = GFVariantData.get_option_int(
		parsed_options,
		"cooldown_msec",
		_DEFAULT_COOLDOWN_MSEC
	)


func _execute_mutation(
	operation: StringName,
	file_name: String,
	data: Dictionary = {},
	metadata: Dictionary = {}
) -> Error:
	var attempts: Array[Dictionary] = []
	var last_error: Error = ERR_UNAVAILABLE
	var limit: int = mini(_backends.size(), 1) if _mutation_policy == MutationPolicy.PRIMARY_ONLY else _backends.size()
	var capability: StringName = &"write" if operation == &"save" else &"delete"
	for index: int in range(limit):
		var backend_id: StringName = _get_backend_id(index)
		var skip_reason: String = _get_skip_reason(index, capability)
		if not skip_reason.is_empty():
			attempts.append(_make_attempt(index, capability, _STATUS_SKIPPED, skip_reason, ERR_UNAVAILABLE, ""))
			continue

		var error_code: Error = _backends[index].save_data(file_name, data, metadata) if operation == &"save" else _backends[index].delete_data(file_name)
		if error_code == OK:
			_mark_backend_success(backend_id)
			attempts.append(_make_attempt(index, capability, _STATUS_SUCCEEDED, "", OK, ""))
			_set_last_report(operation, file_name, true, backend_id, OK, "", attempts)
			return OK

		last_error = error_code
		_mark_backend_result(backend_id, error_code)
		attempts.append(_make_attempt(
			index,
			capability,
			_STATUS_FAILED,
			"",
			error_code,
			error_string(error_code)
		))

	_set_last_report(operation, file_name, false, &"", last_error, error_string(last_error), attempts)
	return last_error


func _get_skip_reason(index: int, capability: StringName) -> String:
	if index < 0 or index >= _backends.size():
		return _REASON_UNSUPPORTED
	if not GFVariantData.get_option_bool(_backends[index].get_capabilities(), capability):
		return _REASON_UNSUPPORTED
	if _is_backend_cooling_down(_get_backend_id(index)):
		return _REASON_COOLDOWN
	return ""


func _has_any_capability(capability: StringName) -> bool:
	for backend: GFStorageBackend in _backends:
		if GFVariantData.get_option_bool(backend.get_capabilities(), capability):
			return true
	return false


func _has_mutation_capability(capability: StringName) -> bool:
	if _backends.is_empty():
		return false
	if _mutation_policy == MutationPolicy.PRIMARY_ONLY:
		return GFVariantData.get_option_bool(_backends[0].get_capabilities(), capability)
	return _has_any_capability(capability)


func _get_backend_id(index: int) -> StringName:
	if index < 0 or index >= _backend_ids.size():
		return &""
	return StringName(_backend_ids[index])


func _get_load_error_code(result: Dictionary, ok: bool) -> Error:
	if ok:
		return OK
	var error_code: int = GFVariantData.get_option_int(result, "error_code", ERR_CANT_OPEN)
	return error_code as Error


func _mark_backend_result(backend_id: StringName, error_code: Error) -> void:
	if not _is_transient_error(error_code):
		_mark_backend_success(backend_id)
		return
	if _failure_threshold <= 0 or _cooldown_msec <= 0:
		return
	var state: Dictionary = _get_health_state(backend_id)
	var failures: int = GFVariantData.get_option_int(state, "consecutive_failures") + 1
	state["consecutive_failures"] = failures
	if failures >= _failure_threshold:
		state["cooldown_until_msec"] = _clock.get_monotonic_msec() + _cooldown_msec
	_health_by_backend_id[backend_id] = state


func _mark_backend_success(backend_id: StringName) -> void:
	if backend_id == &"":
		return
	_health_by_backend_id[backend_id] = _make_healthy_state()


func _is_backend_cooling_down(backend_id: StringName) -> bool:
	if _failure_threshold <= 0 or _cooldown_msec <= 0:
		return false
	var state: Dictionary = _get_health_state(backend_id)
	var cooldown_until: int = GFVariantData.get_option_int(state, "cooldown_until_msec")
	return cooldown_until > _clock.get_monotonic_msec()


func _is_transient_error(error_code: Error) -> bool:
	return (
		error_code == ERR_UNAVAILABLE
		or error_code == ERR_BUSY
		or error_code == ERR_TIMEOUT
		or error_code == ERR_CANT_CONNECT
		or error_code == ERR_CONNECTION_ERROR
	)


func _reset_all_health() -> void:
	_health_by_backend_id.clear()
	for backend_id_text: String in _backend_ids:
		_health_by_backend_id[StringName(backend_id_text)] = _make_healthy_state()


func _get_health_state(backend_id: StringName) -> Dictionary:
	var state_value: Variant = _health_by_backend_id.get(backend_id)
	if state_value is Dictionary:
		var state: Dictionary = state_value
		return state.duplicate(true)
	return _make_healthy_state()


func _make_healthy_state() -> Dictionary:
	return {
		"consecutive_failures": 0,
		"cooldown_until_msec": 0,
	}


func _make_attempt(
	index: int,
	capability: StringName,
	status: String,
	reason: String,
	error_code: Error,
	error_text: String
) -> Dictionary:
	var backend_id: StringName = _get_backend_id(index)
	var state: Dictionary = _get_health_state(backend_id)
	return {
		"backend_id": backend_id,
		"backend_index": index,
		"capability": capability,
		"status": status,
		"reason": reason,
		"error_code": int(error_code),
		"error": error_text,
		"consecutive_failures": GFVariantData.get_option_int(state, "consecutive_failures"),
		"cooldown_until_msec": GFVariantData.get_option_int(state, "cooldown_until_msec"),
	}


func _set_last_report(
	operation: StringName,
	file_name: String,
	ok: bool,
	selected_backend_id: StringName,
	error_code: Error,
	error_text: String,
	attempts: Array[Dictionary]
) -> void:
	var attempted_count: int = 0
	var skipped_count: int = 0
	for attempt: Dictionary in attempts:
		if GFVariantData.get_option_string(attempt, "status") == _STATUS_SKIPPED:
			skipped_count += 1
		else:
			attempted_count += 1
	_last_operation_report = {
		"schema_version": 1,
		"operation": operation,
		"file_name": file_name,
		"ok": ok,
		"selected_backend_id": selected_backend_id,
		"error_code": int(error_code),
		"error": error_text,
		"attempt_count": attempted_count,
		"skipped_count": skipped_count,
		"attempts": attempts.duplicate(true),
		"timestamp_msec": _clock.get_monotonic_msec(),
	}


static func _to_mutation_policy(value: int) -> MutationPolicy:
	return MutationPolicy.PRIMARY_ONLY if value == MutationPolicy.PRIMARY_ONLY else MutationPolicy.FIRST_SUCCESS
