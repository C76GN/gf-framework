## GFStorageDeleteResult: 单次异步 Storage family 删除的不可变终态。
##
## 结果只公开有界成员计数与失败成员分类，不暴露 Storage root、family path 或
## 私有 sidecar 文件名。实例只能由 Storage 框架内部配置一次。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageDeleteResult
extends RefCounted


# --- 枚举 ---

## 删除失败的稳定分类。
## [br]
## @api public
## [br]
## @since unreleased
enum FailureKind {
	## 删除成功。
	NONE,
	## 请求参数或 logical identity 无效。
	INVALID_REQUEST,
	## 精确 logical family 未 claim，或已 claim family 不存在任何可变成员。
	NOT_FOUND,
	## family metadata、owner 或事务证据发生冲突。
	CONFLICT,
	## 删除 worker 线程未能启动。
	THREAD_START_FAILED,
	## Utility 生命周期边界拒绝或终止了尚未执行的请求。
	UNAVAILABLE,
	## family 成员删除或底层文件 I/O 失败；无法解析 worker 终态时也使用此回退分类。
	IO_FAILED,
}

## 删除 family 时可报告的有界成员分类。
## [br]
## @api public
## [br]
## @since unreleased
enum FamilyMember {
	## 没有失败成员。
	NONE,
	## layout、catalog、owner 或 family metadata。
	FAMILY_METADATA,
	## 已提交 payload 的备份成员。
	BACKUP,
	## prepare、commit 或 pending 事务证据。
	TRANSACTION_EVIDENCE,
	## 尚未提交的 candidate payload。
	CANDIDATE,
	## Resource 保存使用的 staging 成员。
	RESOURCE_STAGE,
	## committed final payload。
	FINAL,
}


# --- 私有变量 ---

var _configured: bool = false
var _error_code: Error = FAILED
var _failure_kind: FailureKind = FailureKind.IO_FAILED
var _existing_member_count: int = 0
var _removed_member_count: int = 0
var _remaining_member_count: int = 0
var _failed_member: FamilyMember = FamilyMember.NONE


# --- 公共方法 ---

## 检查删除是否成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置为完整成功终态时返回 true。
func is_successful() -> bool:
	return _configured and _error_code == OK


## 获取删除 Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK；未配置实例返回 FAILED。
func get_error_code() -> Error:
	return _error_code


## 获取删除失败分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `FailureKind` 枚举值。
func get_failure_kind() -> FailureKind:
	return _failure_kind


## 获取删除开始时存在的可变 family 成员数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 0 到 8 的成员数量。
func get_existing_member_count() -> int:
	return _existing_member_count


## 获取本次请求已删除的 family 成员数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 0 到 8 的成员数量。
func get_removed_member_count() -> int:
	return _removed_member_count


## 获取本次请求终态仍存在的 family 成员数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 0 到 8 的成员数量。
func get_remaining_member_count() -> int:
	return _remaining_member_count


## 获取阻止删除继续执行的成员分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 没有失败成员时返回 `FamilyMember.NONE`；无法解析 worker 结果时返回 `FAMILY_METADATA`。
func get_failed_member() -> FamilyMember:
	return _failed_member


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象；未配置实例返回新的未配置对象。
func duplicate_result() -> GFStorageDeleteResult:
	var copy: GFStorageDeleteResult = GFStorageDeleteResult.new()
	if _configured:
		var _configured_copy: bool = copy.configure_for_framework(
			_error_code,
			_failure_kind,
			_existing_member_count,
			_removed_member_count,
			_remaining_member_count,
			_failed_member
		)
	return copy


## 转换为不含物理路径的可报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 删除终态及有界 family 成员计数。
## [br]
## @schema return: Dictionary with exactly ok: bool, error_code: int (Error), failure_kind: int (FailureKind), existing_member_count: int, removed_member_count: int, remaining_member_count: int, and failed_member: int (FamilyMember).
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"error_code": int(_error_code),
		"failure_kind": int(_failure_kind),
		"existing_member_count": _existing_member_count,
		"removed_member_count": _removed_member_count,
		"remaining_member_count": _remaining_member_count,
		"failed_member": int(_failed_member),
	}


# --- 框架内部方法 ---

## 由 Storage Utility 一次性写入删除终态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param error_code: 删除 Error 码。
## [br]
## @param failure_kind: 稳定失败分类。
## [br]
## @param existing_member_count: 删除开始时存在的可变 family 成员数量。
## [br]
## @param removed_member_count: 已删除的成员数量。
## [br]
## @param remaining_member_count: 终态仍存在的成员数量。
## [br]
## @param failed_member: 阻止删除继续执行的成员分类。
## [br]
## @return 首次合法配置成功返回 true；非法组合不修改当前实例。
func configure_for_framework(
	error_code: Error,
	failure_kind: FailureKind,
	existing_member_count: int,
	removed_member_count: int,
	remaining_member_count: int,
	failed_member: FamilyMember
) -> bool:
	if _configured:
		return false
	if not _is_valid_configuration(
		error_code,
		failure_kind,
		existing_member_count,
		removed_member_count,
		remaining_member_count,
		failed_member
	):
		return false

	_error_code = error_code
	_failure_kind = failure_kind
	_existing_member_count = existing_member_count
	_removed_member_count = removed_member_count
	_remaining_member_count = remaining_member_count
	_failed_member = failed_member
	_configured = true
	return true


## 检查框架是否已经写入合法终态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 已配置时返回 true。
func is_configured_for_framework() -> bool:
	return _configured


# --- 私有/辅助方法 ---

static func _is_valid_configuration(
	error_code: Error,
	failure_kind: FailureKind,
	existing_member_count: int,
	removed_member_count: int,
	remaining_member_count: int,
	failed_member: FamilyMember
) -> bool:
	if not FailureKind.values().has(int(failure_kind)):
		return false
	if not FamilyMember.values().has(int(failed_member)):
		return false
	if (
		existing_member_count < 0
		or existing_member_count > 8
		or removed_member_count < 0
		or removed_member_count > 8
		or remaining_member_count < 0
		or remaining_member_count > 8
		or existing_member_count != removed_member_count + remaining_member_count
	):
		return false
	if (error_code == OK) != (failure_kind == FailureKind.NONE):
		return false

	match failure_kind:
		FailureKind.NONE:
			return (
				existing_member_count >= 1
				and removed_member_count == existing_member_count
				and remaining_member_count == 0
				and failed_member == FamilyMember.NONE
			)
		FailureKind.INVALID_REQUEST:
			return (
				error_code == ERR_INVALID_PARAMETER
				and _has_no_physical_work(
					existing_member_count,
					removed_member_count,
					remaining_member_count,
					failed_member
				)
			)
		FailureKind.NOT_FOUND:
			return (
				error_code == ERR_FILE_NOT_FOUND
				and _has_no_physical_work(
					existing_member_count,
					removed_member_count,
					remaining_member_count,
					failed_member
				)
			)
		FailureKind.THREAD_START_FAILED:
			return _has_no_physical_work(
				existing_member_count,
				removed_member_count,
				remaining_member_count,
				failed_member
			)
		FailureKind.UNAVAILABLE:
			return (
				error_code == ERR_UNAVAILABLE
				and _has_no_physical_work(
					existing_member_count,
					removed_member_count,
					remaining_member_count,
					failed_member
				)
			)
		FailureKind.CONFLICT:
			return (
				removed_member_count == 0
				and existing_member_count == remaining_member_count
				and failed_member in [
					FamilyMember.FAMILY_METADATA,
					FamilyMember.TRANSACTION_EVIDENCE,
				]
			)
		FailureKind.IO_FAILED:
			if existing_member_count == 0:
				return failed_member == FamilyMember.FAMILY_METADATA
			return failed_member != FamilyMember.NONE
	return false


static func _has_no_physical_work(
	existing_member_count: int,
	removed_member_count: int,
	remaining_member_count: int,
	failed_member: FamilyMember
) -> bool:
	return (
		existing_member_count == 0
		and removed_member_count == 0
		and remaining_member_count == 0
		and failed_member == FamilyMember.NONE
	)
