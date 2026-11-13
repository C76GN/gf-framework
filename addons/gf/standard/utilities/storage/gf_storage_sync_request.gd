## GFStorageSyncRequest: 与命名空间、记录和操作身份绑定的冻结同步请求。
##
## revision 是不透明文本，空文本只表示预期记录不存在。operation_id 必须由调用方
## 唯一分配；恢复同一次提交时沿用原 ID，不得用它提交不同载荷。请求不包含账号凭证。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageSyncRequest
extends RefCounted


# --- 私有变量 ---

## 经有界校验并隔离的规范请求记录。
## [br]
## @api private
## [br]
## @schema _record: Dictionary，包含 namespace、key、operation_id、data、mode、resolution、expected_revision、local_generation 和 timeout_msec。
var _record: Dictionary = {}


# --- 公共方法 ---

## 创建冻结请求；只接受明确选项和有界原生数据，任何失败均返回 null。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record_namespace: 调用方的稳定命名空间，不代表远端授权。
## [br]
## @param record_key: 命名空间内的稳定记录键。
## [br]
## @param operation_id: 本次提交的唯一操作 ID，恢复时保持不变。
## [br]
## @param data: 本次上传的完整候选；pull/preview 可为空。
## [br]
## @param options: 同步模式、冲突选择、已知 revision 和本地代际。
## [br]
## @schema data: Dictionary of finite native Variant values, without Object, Callable, Signal, RID or cycles; complete request limited to depth64,100000 nodes,16MiB canonical bytes.
## [br]
## @schema options: Closed Dictionary with optional mode: StringName/String (push, pull, preview, probe; default push), resolution: StringName/String (report, local, remote; default report), expected_revision: String (default empty), local_generation: int>=0 (default0), timeout_msec: int in1..300000 (default30000).
## [br]
## @return 有效请求或 null。
static func create(
	record_namespace: String,
	record_key: String,
	operation_id: String,
	data: Dictionary = {},
	options: Dictionary = {}
) -> GFStorageSyncRequest:
	var candidate: Dictionary = _inspect_candidate(
		record_namespace,
		record_key,
		operation_id,
		data,
		options
	)
	var report: Dictionary = GFVariantData.get_option_dictionary(candidate, "report")
	if not GFVariantData.get_option_bool(report, "ok"):
		return null
	var request: GFStorageSyncRequest = GFStorageSyncRequest.new()
	request._record = GFVariantData.get_option_dictionary(candidate, "record").duplicate(true)
	return request


## 获取完整请求的规范编码硬预算；修改返回字典不会改变准入规则。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求封套及其载荷共同使用的预算，不是压缩后的文件大小。
## [br]
## @schema return: Dictionary with max_depth:int,max_items:int,max_output_bytes:int,max_string_length:int.
static func get_limits() -> Dictionary:
	return {
		"max_depth": 64,
		"max_items": 100000,
		"max_output_bytes": 16777216,
		"max_string_length": 16777216,
	}


## 只读验证工厂输入，不创建请求、不复制载荷，也不发起 IO。
##
## 与 create() 使用同一准入路径；报告不授权之后被修改的数据。计量失败时 observed
## 只包含已遍历部分，不提供完整输入大小；报告不含业务值或记录身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record_namespace: 稳定命名空间。
## [br]
## @param record_key: 稳定记录键。
## [br]
## @param operation_id: 唯一操作身份。
## [br]
## @param data: 保持不变的候选载荷。
## [br]
## @schema data: 与 create() 相同的有限原生数据；非法值在复制前拒绝。
## [br]
## @param options: 与 create() 相同的闭合选项。
## [br]
## @schema options: Closed Dictionary with mode,resolution,expected_revision,local_generation,timeout_msec.
## [br]
## @return 不含载荷的准入诊断。
## [br]
## @schema return: Dictionary with ok:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary; observed is empty or a measure_canonical() report.
static func validate_input(
	record_namespace: String,
	record_key: String,
	operation_id: String,
	data: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	return GFVariantData.get_option_dictionary(
		_inspect_candidate(
			record_namespace,
			record_key,
			operation_id,
			data,
			options
		),
		"report"
	)


## 从持久化意图恢复同一请求，严格拒绝缺失或额外字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record: to_record() 产生的完整记录。
## [br]
## @schema record: Closed Dictionary containing namespace,key,operation_id,data,mode,resolution,expected_revision,local_generation,timeout_msec.
## [br]
## @return 已重新验证的冻结请求或 null。
static func from_record(record: Dictionary) -> GFStorageSyncRequest:
	if record.size() != 9:
		return null
	for key: String in [
		"namespace",
		"key",
		"operation_id",
	]:
		if not record.get(key) is String:
			return null
	if not record.get("data") is Dictionary:
		return null
	var options: Dictionary = {}
	for key: String in [
		"mode",
		"resolution",
		"expected_revision",
		"local_generation",
		"timeout_msec",
	]:
		if not record.has(key):
			return null
		options[key] = record[key]
	return create(
		GFVariantData.get_option_string(record, "namespace"),
		GFVariantData.get_option_string(record, "key"),
		GFVariantData.get_option_string(record, "operation_id"),
		GFVariantData.get_option_dictionary(record, "data"),
		options
	)


## 检查请求是否由成功的工厂调用创建。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 有效时返回 true。
func is_valid() -> bool:
	return not _record.is_empty()


## 获取命名空间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定命名空间。
func get_namespace() -> String:
	return GFVariantData.get_option_string(_record, "namespace")


## 获取记录键。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定记录键。
func get_key() -> String:
	return GFVariantData.get_option_string(_record, "key")


## 获取操作 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 唯一提交身份。
func get_operation_id() -> String:
	return GFVariantData.get_option_string(_record, "operation_id")


## 获取请求模式。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return push、pull、preview 或 probe。
func get_mode() -> StringName:
	return GFVariantData.get_option_string_name(_record, "mode")


## 获取明确的冲突选择。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return report、local 或 remote。
func get_resolution() -> StringName:
	return GFVariantData.get_option_string_name(_record, "resolution")


## 获取预期 revision；只能比较相等。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不透明 revision，空文本表示预期不存在。
func get_expected_revision() -> String:
	return GFVariantData.get_option_string(_record, "expected_revision")


## 获取本次冻结的本地代际。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负本地代际，不用于与远端 revision 排序比较。
func get_local_generation() -> int:
	return GFVariantData.get_option_int(_record, "local_generation")


## 获取每个协议阶段的单调时间等待上限。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数毫秒。
func get_timeout_msec() -> int:
	return GFVariantData.get_option_int(_record, "timeout_msec")


## 显式获取候选载荷的独立副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 候选数据副本。
## [br]
## @schema return: Dictionary of admitted native data.
func get_data() -> Dictionary:
	return GFVariantData.get_option_dictionary(_record, "data").duplicate(true)


## 显式导出可持久化意图；包含业务载荷，不能用作日志或诊断。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整独立记录。
## [br]
## @schema return: Closed Dictionary accepted by from_record().
func to_record() -> Dictionary:
	return _record.duplicate(true)


## 获取不含命名空间、载荷、revision 或操作 ID 的诊断摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求模式和代际摘要。
## [br]
## @schema return: Dictionary with valid,mode,resolution,local_generation,timeout_msec.
func get_debug_snapshot() -> Dictionary:
	return {
		"valid": is_valid(),
		"mode": get_mode(),
		"resolution": get_resolution(),
		"local_generation": get_local_generation(),
		"timeout_msec": get_timeout_msec(),
	}


# --- 私有/辅助方法 ---

## 先形成只借用载荷的浅封套；只有工厂在整个报告成功后才能复制该记录。
## [br]
## @api private
static func _inspect_candidate(
	record_namespace: String,
	record_key: String,
	operation_id: String,
	data: Dictionary,
	options: Dictionary
) -> Dictionary:
	var identities: Dictionary = {
		"namespace": record_namespace,
		"key": record_key,
		"operation_id": operation_id,
	}
	for field: String in identities:
		var identity: String = identities[field]
		if (
			identity.is_empty()
			or identity != identity.strip_edges()
			or identity.length() > 512
		):
			return _inspection_failure(&"invalid_identity", field)
		for index: int in range(identity.length()):
			if identity.unicode_at(index) < 32:
				return _inspection_failure(&"invalid_identity", field)
	for key: Variant in options:
		if key not in [
			"mode",
			"resolution",
			"expected_revision",
			"local_generation",
			"timeout_msec",
		]:
			return _inspection_failure(&"unknown_option", "options")
	var mode_value: Variant = options.get("mode", &"push")
	var resolution_value: Variant = options.get("resolution", &"report")
	var revision_value: Variant = options.get("expected_revision", "")
	var generation_value: Variant = options.get("local_generation", 0)
	var timeout_value: Variant = options.get("timeout_msec", 30000)
	if not mode_value is String and not mode_value is StringName:
		return _inspection_failure(&"invalid_mode", "options.mode")
	if not resolution_value is String and not resolution_value is StringName:
		return _inspection_failure(&"invalid_resolution", "options.resolution")
	if not revision_value is String:
		return _inspection_failure(&"invalid_revision", "options.expected_revision")
	if not generation_value is int:
		return _inspection_failure(&"invalid_generation", "options.local_generation")
	if not timeout_value is int:
		return _inspection_failure(&"invalid_timeout", "options.timeout_msec")
	var mode: StringName = GFVariantData.to_string_name(mode_value)
	var resolution: StringName = GFVariantData.to_string_name(resolution_value)
	var revision: String = revision_value
	var generation: int = generation_value
	var timeout: int = timeout_value
	if mode not in [
		&"push",
		&"pull",
		&"preview",
		&"probe",
	]:
		return _inspection_failure(&"invalid_mode", "options.mode")
	if resolution not in [
		&"report",
		&"local",
		&"remote",
	]:
		return _inspection_failure(&"invalid_resolution", "options.resolution")
	if generation < 0:
		return _inspection_failure(&"invalid_generation", "options.local_generation")
	if timeout < 1 or timeout > 300000:
		return _inspection_failure(&"invalid_timeout", "options.timeout_msec")
	if revision.length() > 65536:
		return _inspection_failure(&"invalid_revision", "options.expected_revision")
	var record: Dictionary = {
		"namespace": record_namespace,
		"key": record_key,
		"operation_id": operation_id,
		"data": data,
		"mode": mode,
		"resolution": resolution,
		"expected_revision": revision,
		"local_generation": generation,
		"timeout_msec": timeout,
	}
	var measure_options: Dictionary = get_limits()
	measure_options["allow_floats"] = true
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(record, measure_options)
	if not GFVariantData.get_option_bool(measured, "ok"):
		var kind: StringName = &"request_budget_exceeded" if not GFVariantData.get_option_string(measured, "limit_kind").is_empty() else &"invalid_request_data"
		return _inspection_failure(
			kind,
			"request",
			measured
		)
	return {
		"record": record,
		"report": _inspection_report(
			true,
			&"",
			"",
			measured
		),
	}


## 失败候选不携带未经验证的输入引用。
## [br]
## @api private
static func _inspection_failure(
	kind: StringName,
	path: String,
	observed: Dictionary = {}
) -> Dictionary:
	return {
		"report": _inspection_report(
			false,
			kind,
			path,
			observed
		),
	}


## 报告只包含预算与计量，不包含身份、revision 或业务值。
## [br]
## @api private
static func _inspection_report(
	ok: bool,
	kind: StringName,
	path: String,
	observed: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"error_kind": kind,
		"path": path,
		"layer": &"storage_sync_request",
		"limits": get_limits(),
		"observed": observed,
	}
