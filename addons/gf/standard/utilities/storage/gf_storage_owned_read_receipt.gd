## GFStorageOwnedReadReceipt: 独占读取的不可变 caller 终态诊断。
##
## 只保留请求身份、稳定状态、版本、完整性和实际读取的 committed revision。
## 不持有业务载荷、任意 metadata、物理路径或领取权限；共享诊断不会复制载荷。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageOwnedReadReceipt
extends RefCounted


# --- 枚举 ---

## 独占读取交付的稳定失败分类。
## [br]
## @api public
## [br]
## @since unreleased
enum FailureKind {
	## 读取及交付均成功。
	NONE,
	## 文件读取、解码、校验或迁移失败，详见读取失败分类。
	READ_FAILED,
	## 载荷无法安全隔离为独占纯数据；不表示磁盘文件损坏。
	UNSUPPORTED_PAYLOAD,
	## caller 在成功交付前停止观察。
	CANCELLED,
}


# --- 常量 ---

const _INTEGER_FIELDS: PackedStringArray = [
	"request_id", "consumer_id", "status", "end_kind", "error_code",
	"failure_kind", "read_failure_kind", "source_version", "target_version",
]
const _BOOLEAN_FIELDS: PackedStringArray = ["migrated", "integrity_checked", "integrity_ok"]


# --- 私有变量 ---

var _request_id: int = 0
var _consumer_id: int = 0
var _file_name: String = ""
var _status: GFStorageAsyncCallerResult.Status = GFStorageAsyncCallerResult.Status.CANCELLED
var _end_kind: GFStorageAsyncCallerResult.EndKind = GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
var _error_code: Error = ERR_UNCONFIGURED
var _failure_kind: FailureKind = FailureKind.READ_FAILED
var _read_failure_kind: GFStorageReadResult.FailureKind = GFStorageReadResult.FailureKind.UNAVAILABLE
var _source_version: int = 0
var _target_version: int = 0
var _migrated: bool = false
var _integrity_checked: bool = false
var _integrity_ok: bool = false
var _committed_revision: GFStorageRevisionResult = null


# --- 公共方法 ---

## 获取 Utility 内唯一的物理请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；未配置时为 0。
func get_request_id() -> int:
	return _request_id


## 获取 Utility 内唯一的 consumer ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的 consumer ID；未配置时为 0。
func get_consumer_id() -> int:
	return _consumer_id


## 获取已校验的规范逻辑文件名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 逻辑文件名；文件名校验前失败时可能为空。
func get_file_name() -> String:
	return _file_name


## 获取 caller 终态分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return PHYSICAL_SETTLED 或 CANCELLED；独占读取不会返回 OUTCOME_UNKNOWN。
func get_status() -> GFStorageAsyncCallerResult.Status:
	return _status


## 获取 caller 终态的来源分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 物理结算、显式取消、令牌、超时、owner 释放或 Utility dispose。
func get_end_kind() -> GFStorageAsyncCallerResult.EndKind:
	return _end_kind


## 获取稳定的 Godot Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK，失败或取消时为非 OK。
func get_error_code() -> Error:
	return _error_code


## 获取独占读取交付的失败分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功、读取失败、不支持独占交付或取消。
func get_failure_kind() -> FailureKind:
	return _failure_kind


## 获取文件读取、解码、校验或迁移的失败分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return READ_FAILED 的具体原因；成功、取消和不支持交付时为 NONE。
func get_read_failure_kind() -> GFStorageReadResult.FailureKind:
	return _read_failure_kind


## 检查 caller 是否获得成功的独占读取交付。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成读取且没有读取或交付失败时返回 true。
func is_ok() -> bool:
	return (
		_request_id > 0
		and _status == GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED
		and _failure_kind == FailureKind.NONE
		and _error_code == OK
	)


## 获取本次读取发现的数据版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 迁移前的数据版本；未取得版本时为 0。
func get_source_version() -> int:
	return _source_version


## 获取本次读取完成迁移后的数据版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 迁移后的数据版本；未取得版本时为 0。
func get_target_version() -> int:
	return _target_version


## 检查本次读取是否完成过数据迁移。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已执行数据迁移时返回 true。
func was_migrated() -> bool:
	return _migrated


## 检查本次读取是否包含完整性检查结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整性状态不是 NOT_CHECKED 时返回 true。
func was_integrity_checked() -> bool:
	return _integrity_checked


## 检查本次读取的完整性校验是否明确通过。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整性状态为 VALID 时返回 true；未检查不视为已通过。
func is_integrity_ok() -> bool:
	return _integrity_ok


## 获取与本次实际读取配对的不可变 committed revision 结果。
##
## 不会重新查询当前磁盘状态；revision 仅支持相等比较，不表示时间或内容完整性。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 本次捕获的 revision 状态；未捕获时为 null。
func get_committed_revision() -> GFStorageRevisionResult:
	return _committed_revision


## 创建只包含稳定诊断白名单的独立字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不包含载荷、任意 metadata、物理路径或领取权限的诊断字典。
## [br]
## @schema return: 精确 Dictionary，包含 request_id: int、consumer_id: int、file_name: String、status: int (GFStorageAsyncCallerResult.Status)、end_kind: int (GFStorageAsyncCallerResult.EndKind)、error_code: int (Error)、failure_kind: int (FailureKind)、read_failure_kind: int (GFStorageReadResult.FailureKind)、source_version: int、target_version: int、migrated: bool、integrity_checked: bool、integrity_ok: bool、committed_revision: Dictionary（未捕获时为空，否则含 status: int、error_code: int、revision: String）。
func to_dict() -> Dictionary:
	return {
		"request_id": _request_id,
		"consumer_id": _consumer_id,
		"file_name": _file_name,
		"status": int(_status),
		"end_kind": int(_end_kind),
		"error_code": int(_error_code),
		"failure_kind": int(_failure_kind),
		"read_failure_kind": int(_read_failure_kind),
		"source_version": _source_version,
		"target_version": _target_version,
		"migrated": _migrated,
		"integrity_checked": _integrity_checked,
		"integrity_ok": _integrity_ok,
		"committed_revision": _committed_revision.to_dict() if _committed_revision != null else {},
	}


# --- 框架内部方法 ---

## 一次性冻结独占读取的小型 caller 终态，拒绝白名单之外的数据。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param info: 完整且闭合匹配的诊断字段，不含 payload 或任意 metadata。
## [br]
## @schema info: 精确 Dictionary，与 to_dict 字段一致，但 committed_revision 为 GFStorageRevisionResult 或 null。
## [br]
## @return 首次配置合法诊断时返回 true；无效输入不改变实例。
func configure_for_framework(info: Dictionary) -> bool:
	if _request_id != 0 or not _has_valid_shape(info):
		return false
	var request_id: int = GFVariantData.get_option_int(info, "request_id", 0)
	var consumer_id: int = GFVariantData.get_option_int(info, "consumer_id", 0)
	var status: int = GFVariantData.get_option_int(info, "status", -1)
	var end_kind: int = GFVariantData.get_option_int(info, "end_kind", -1)
	var error_code: int = GFVariantData.get_option_int(info, "error_code", -1)
	var failure_kind: int = GFVariantData.get_option_int(info, "failure_kind", -1)
	var read_failure_kind: int = GFVariantData.get_option_int(info, "read_failure_kind", -1)
	var source_version: int = GFVariantData.get_option_int(info, "source_version", -1)
	var target_version: int = GFVariantData.get_option_int(info, "target_version", -1)
	if request_id <= 0 or consumer_id <= 0 or source_version < 0 or target_version < 0:
		return false
	if (
		status not in [
			GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED,
			GFStorageAsyncCallerResult.Status.CANCELLED,
		]
		or not GFStorageAsyncCallerResult.EndKind.values().has(end_kind)
		or not FailureKind.values().has(failure_kind)
		or not GFStorageReadResult.FailureKind.values().has(read_failure_kind)
		or error_code < OK
	):
		return false
	if failure_kind == FailureKind.CANCELLED:
		if (
			end_kind == GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
			or error_code != ERR_SKIP
		):
			return false
	elif (
		status != GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED
		or end_kind != GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
		or (failure_kind == FailureKind.NONE) != (error_code == OK)
	):
		return false
	if (failure_kind == FailureKind.READ_FAILED) != (read_failure_kind != GFStorageReadResult.FailureKind.NONE):
		return false
	_request_id = request_id
	_consumer_id = consumer_id
	_file_name = GFVariantData.get_option_string(info, "file_name", "")
	_status = status as GFStorageAsyncCallerResult.Status
	_end_kind = end_kind as GFStorageAsyncCallerResult.EndKind
	_error_code = error_code as Error
	_failure_kind = failure_kind as FailureKind
	_read_failure_kind = read_failure_kind as GFStorageReadResult.FailureKind
	_source_version = source_version
	_target_version = target_version
	_migrated = GFVariantData.get_option_bool(info, "migrated", false)
	_integrity_checked = GFVariantData.get_option_bool(info, "integrity_checked", false)
	_integrity_ok = GFVariantData.get_option_bool(info, "integrity_ok", false)
	var revision_value: Variant = info.get("committed_revision")
	if revision_value is GFStorageRevisionResult:
		_committed_revision = revision_value
	return true


# --- 私有/辅助方法 ---

func _has_valid_shape(info: Dictionary) -> bool:
	if info.size() != _INTEGER_FIELDS.size() + _BOOLEAN_FIELDS.size() + 2:
		return false
	for field: String in _INTEGER_FIELDS:
		if not info.get(field) is int:
			return false
	for field: String in _BOOLEAN_FIELDS:
		if not info.get(field) is bool:
			return false
	if not info.get("file_name") is String or not info.has("committed_revision"):
		return false
	var revision_value: Variant = info.get("committed_revision")
	return revision_value == null or revision_value is GFStorageRevisionResult
