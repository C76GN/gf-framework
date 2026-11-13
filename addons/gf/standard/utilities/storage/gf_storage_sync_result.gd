## GFStorageSyncResult: 一次同步观察的不可变终态。
##
## COMMITTED 表示远端提交与本地 checkpoint 均已确认。OUTCOME_UNKNOWN 表示无法
## 查证远端结果；RECOVERY_REQUIRED 可以表示远端已确认而本地 checkpoint 尚未确认。
## preview 和 remote_selected 都不表示已写入本地业务状态。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageSyncResult
extends RefCounted


# --- 枚举 ---

## 唯一终态；不会因迟到响应重新变更。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 只读比较完成。
	PREVIEW,
	## 当前远端数据与候选相同，没有提交写入。
	UNCHANGED,
	## 已取得明确选择的远端候选，尚未应用到本地业务状态。
	REMOTE_SELECTED,
	## 远端提交和本地 checkpoint 都已持久化确认。
	COMMITTED,
	## revision 不匹配或条件提交发生并发竞争。
	CONFLICT,
	## 本次未发送，或已查证没有提交。
	NOT_COMMITTED,
	## 本次可能已提交，需要按原操作 ID 查证。
	OUTCOME_UNKNOWN,
	## 远端结果已取得，但本地持久化结果尚待恢复。
	RECOVERY_REQUIRED,
	## 请求、能力、所有权或协议准入被拒绝。
	REJECTED,
}


# --- 私有变量 ---

## 首次配置完成后禁止重写。
## [br]
## @api private
var _configured: bool = false

## 实际准备或提交的冻结请求。
## [br]
## @api private
var _request: GFStorageSyncRequest = null

## 唯一观察终态。
## [br]
## @api private
var _status: Status = Status.REJECTED

## 已校验并隔离的结果字段。
## [br]
## @api private
## [br]
## @schema _details: Dictionary with exists:bool,revision:String,data:Dictionary,error_kind:StringName,remote_committed:bool.
var _details: Dictionary = {}

## 可选的隔离冲突报告。
## [br]
## @api private
var _conflict: GFStorageConflictReport = null


# --- 公共方法 ---

## 检查结果是否已经由引擎封存。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置返回 true。
func is_valid() -> bool:
	return _configured


## 获取唯一终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Status 枚举值。
func get_status() -> Status:
	return _status


## 获取稳定的 ASCII 状态名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 对应 Status 的小写名称。
func get_status_name() -> StringName:
	match _status:
		Status.PREVIEW:
			return &"preview"
		Status.UNCHANGED:
			return &"unchanged"
		Status.REMOTE_SELECTED:
			return &"remote_selected"
		Status.COMMITTED:
			return &"committed"
		Status.CONFLICT:
			return &"conflict"
		Status.NOT_COMMITTED:
			return &"not_committed"
		Status.OUTCOME_UNKNOWN:
			return &"outcome_unknown"
		Status.RECOVERY_REQUIRED:
			return &"recovery_required"
		_:
			return &"rejected"


## 检查本次观察是否成功完成；不能替代 COMMITTED 或本地业务事务结果检查。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return preview、unchanged、remote_selected 或 committed 时为 true。
func is_successful() -> bool:
	return _configured and _status in [
		Status.PREVIEW,
		Status.UNCHANGED,
		Status.REMOTE_SELECTED,
		Status.COMMITTED,
	]


## 检查是否需要按持久化意图恢复。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 未知远端结果或未确认本地 checkpoint 时为 true。
func requires_recovery() -> bool:
	return _status in [Status.OUTCOME_UNKNOWN, Status.RECOVERY_REQUIRED]


## 获取本次实际使用的冻结请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求对象；拒绝非法输入时可能为空。
func get_request() -> GFStorageSyncRequest:
	return _request


## 获取稳定错误种类，不包含适配器的任意原始错误文本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return ASCII 错误种类或空。
func get_error_kind() -> StringName:
	return GFVariantData.get_option_string_name(_details, "error_kind")


## 检查已观察的远端记录是否存在。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 存在时为 true；结果未知时不能据此推断记录不存在。
func record_exists() -> bool:
	return GFVariantData.get_option_bool(_details, "exists")


## 获取已观察的远端 revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不透明文本；不得排序比较。
func get_revision() -> String:
	return GFVariantData.get_option_string(_details, "revision")


## 显式获取远端数据的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已验证数据副本，是否存在由 record_exists() 和终态决定。
## [br]
## @schema return: Dictionary of admitted native data.
func get_data() -> Dictionary:
	return GFVariantData.get_option_dictionary(_details, "data").duplicate(true)


## 检查是否已有远端提交的明确证据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已查证提交时为 true，即使本地 checkpoint 仍待恢复。
func is_remote_committed() -> bool:
	return GFVariantData.get_option_bool(_details, "remote_committed")


## 获取隔离的冲突报告。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 报告副本或 null。
func get_conflict_report() -> GFStorageConflictReport:
	return _conflict.duplicate_report() if _conflict != null else null


## 获取不含业务载荷、身份文本或 revision 的诊断摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 终态和确认边界摘要。
## [br]
## @schema return: Dictionary with valid,status,error_kind,remote_committed,requires_recovery,has_conflict,local_generation.
func get_debug_snapshot() -> Dictionary:
	return {
		"valid": _configured,
		"status": get_status_name(),
		"error_kind": get_error_kind(),
		"remote_committed": is_remote_committed(),
		"requires_recovery": requires_recovery(),
		"has_conflict": _conflict != null,
		"local_generation": _request.get_local_generation() if _request != null else 0,
	}


# --- 框架内部方法 ---

## 封存已校验的协议结果，禁止再次配置。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param request: 实际准备或提交的请求；非法准入结果可为空。
## [br]
## @param status: 唯一终态。
## [br]
## @param details: 已校验的终态字段。
## [br]
## @param conflict: 可选冲突报告。
## [br]
## @schema details: Closed Dictionary with optional exists:bool,revision:String,data:Dictionary,error_kind:StringName/String,remote_committed:bool. Data obeys the bounded native request contract.
## [br]
## @return 首次有效配置成功时为 true。
func configure_for_framework(
	request: GFStorageSyncRequest,
	status: Status,
	details: Dictionary = {},
	conflict: GFStorageConflictReport = null
) -> bool:
	if (
		_configured
		or status < Status.PREVIEW
		or status > Status.REJECTED
	):
		return false
	if request == null and status != Status.REJECTED:
		return false
	if request != null and not request.is_valid():
		return false
	for key: Variant in details:
		if key not in [
			"exists",
			"revision",
			"data",
			"error_kind",
			"remote_committed",
		]:
			return false
	var exists_value: Variant = details.get("exists", false)
	var revision_value: Variant = details.get("revision", "")
	var data_value: Variant = details.get("data", {})
	var error_value: Variant = details.get("error_kind", &"")
	var committed_value: Variant = details.get("remote_committed", false)
	if (
		not exists_value is bool
		or not revision_value is String
		or not data_value is Dictionary
		or not committed_value is bool
	):
		return false
	if not error_value is String and not error_value is StringName:
		return false
	var exists: bool = exists_value
	var revision: String = revision_value
	var data: Dictionary = data_value
	var committed: bool = committed_value
	if (
		exists == revision.is_empty()
		or (
			not exists
			and not data.is_empty()
		)
	):
		return false
	if status == Status.COMMITTED and not committed:
		return false
	if committed and not exists:
		return false
	if committed and status not in [Status.COMMITTED, Status.RECOVERY_REQUIRED]:
		return false
	var error_kind: String = GFVariantData.to_text(error_value)
	if error_kind.length() > 64:
		return false
	for index: int in range(error_kind.length()):
		var code: int = error_kind.unicode_at(index)
		if (
			code != 95
			and not (
				code >= 97
				and code <= 122
			)
			and not (
				code >= 48
				and code <= 57
			)
		):
			return false
	var measure: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		details,
		{
			"allow_floats": true,
			"max_depth": 64,
			"max_items": 100000,
			"max_output_bytes": 16777216,
			"max_string_length": 16777216,
		}
	)
	if not GFVariantData.get_option_bool(measure, "ok"):
		return false
	_details = {
		"exists": exists_value,
		"revision": revision_value,
		"data": GFVariantData.as_dictionary(data_value).duplicate(true),
		"error_kind": GFVariantData.to_string_name(error_value),
		"remote_committed": committed_value,
	}
	_conflict = conflict.duplicate_report() if conflict != null else null
	_request = request
	_status = status
	_configured = true
	return true
