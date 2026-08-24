## GFStorageFamilyResetResult: 单个 Storage logical family 破坏性 reset/recreate 的不可变终态。
##
## 结果只公开 logical 层分类、阶段与有界计数，不暴露 Storage root、family path、
## retirement staging 或任何私有 sidecar 名称。实例只能由 Storage 框架内部配置一次。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageFamilyResetResult
extends RefCounted


# --- 枚举 ---

## reset/recreate 失败的稳定分类。
## [br]
## @api public
## [br]
## @since unreleased
enum FailureKind {
	## reset/recreate 成功。
	NONE,
	## logical identity、参数或结果形状无效。
	INVALID_REQUEST,
	## 目标 logical family 不存在。
	NOT_FOUND,
	## 未提供匹配且可用的一次性破坏性授权。
	UNAUTHORIZED,
	## 私有 layout 版本高于当前运行时理解范围。
	UNSUPPORTED_LAYOUT,
	## 当前 layout 或 retirement evidence 无法安全归属于精确目标。
	CONFLICT,
	## reset worker 线程未能启动。
	THREAD_START_FAILED,
	## Utility 生命周期、准入或同 family 串行边界未接纳请求。
	UNAVAILABLE,
	## retirement、recreate 或 cleanup I/O 失败。
	IO_FAILED,
}

## reset 前精确目标的稳定分类。
## [br]
## @api public
## [br]
## @since unreleased
enum SourceKind {
	## 尚未完成目标分类。
	UNKNOWN,
	## 精确 logical family 不存在。
	MISSING,
	## catalog/owner identity 有效；损坏只可能位于 payload 或可变事务 evidence。
	PAYLOAD_ONLY,
	## catalog、owner、事务身份或 family 结构发生冲突。
	STRUCTURAL_IDENTITY,
}

## 失败发生的稳定 reset 阶段。
## [br]
## @api public
## [br]
## @since unreleased
enum Phase {
	## 没有失败阶段。
	NONE,
	## layout、authorization 或目标 evidence 预检。
	PREFLIGHT,
	## 把精确旧 family identity 移入 retirement staging。
	RETIRE,
	## 发布新的 owner 与 catalog claim。
	RECREATE,
	## 清理已退休的私有 evidence。
	CLEANUP,
}

## reset 结果可报告的路径无关成员分类。
## [br]
## @api public
## [br]
## @since unreleased
enum FamilyMember {
	## 没有失败成员。
	NONE,
	## 全局私有 layout manifest 或版本目录。
	LAYOUT,
	## 精确 logical identity 的 catalog claim。
	CATALOG,
	## family owner claim。
	OWNER,
	## payload、candidate、backup、resource stage 或事务 evidence。
	MUTABLE_EVIDENCE,
	## 精确 family 容器或其 retirement staging。
	FAMILY_CONTAINER,
	## 与精确 logical identity 绑定的不可变 reset intent。
	RESET_INTENT,
}


# --- 常量 ---

const _MAX_RETIRED_MEMBER_COUNT: int = 2
const _MAX_RECREATED_MEMBER_COUNT: int = 3
const _MAX_REMAINING_EVIDENCE_COUNT: int = 5


# --- 私有变量 ---

var _configured: bool = false
var _error_code: Error = FAILED
var _failure_kind: FailureKind = FailureKind.IO_FAILED
var _source_kind: SourceKind = SourceKind.UNKNOWN
var _failed_phase: Phase = Phase.PREFLIGHT
var _retired_member_count: int = 0
var _recreated_member_count: int = 0
var _remaining_evidence_count: int = 0
var _failed_member: FamilyMember = FamilyMember.NONE


# --- 公共方法 ---

## 检查 reset/recreate 是否完整成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置为无剩余 evidence 的成功终态时返回 true。
func is_successful() -> bool:
	return _configured and _error_code == OK


## 获取 reset/recreate 的 Godot Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK；未配置实例返回 FAILED。
func get_error_code() -> Error:
	return _error_code


## 获取稳定失败分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return FailureKind 枚举值。
func get_failure_kind() -> FailureKind:
	return _failure_kind


## 获取 reset 前目标状态分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return SourceKind 枚举值。
func get_source_kind() -> SourceKind:
	return _source_kind


## 获取失败发生的阶段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 Phase.NONE。
func get_failed_phase() -> Phase:
	return _failed_phase


## 获取已移入 retirement staging 的 identity root 数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 0 到 2，分别对应 family container 与 catalog claim。
func get_retired_member_count() -> int:
	return _retired_member_count


## 获取已重新发布的 claim 成员数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 0 到 3，分别计 family container、owner 与 catalog。
func get_recreated_member_count() -> int:
	return _recreated_member_count


## 获取终态仍未清除的旧 family、retirement 或 reset intent evidence 数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## 有效的 recreated exact claim 不计入该值。
## [br]
## @return 0 到 5 的有界计数。
func get_remaining_evidence_count() -> int:
	return _remaining_evidence_count


## 获取阻止 reset 继续执行的成员分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 没有失败成员时为 FamilyMember.NONE。
func get_failed_member() -> FamilyMember:
	return _failed_member


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象；未配置实例返回新的未配置对象。
func duplicate_result() -> GFStorageFamilyResetResult:
	var copy: GFStorageFamilyResetResult = GFStorageFamilyResetResult.new()
	if _configured:
		var _configured_copy: bool = copy.configure_for_framework(
			_error_code,
			_failure_kind,
			_source_kind,
			_failed_phase,
			_retired_member_count,
			_recreated_member_count,
			_remaining_evidence_count,
			_failed_member
		)
	return copy


## 转换为不含物理路径的可报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return reset/recreate 终态、分类、阶段与有界 evidence 计数。
## [br]
## @schema return: Exact Dictionary with ok: bool, error_code: int (Error), failure_kind: int (FailureKind), source_kind: int (SourceKind), failed_phase: int (Phase), retired_member_count: int, recreated_member_count: int, remaining_evidence_count: int, and failed_member: int (FamilyMember).
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"error_code": int(_error_code),
		"failure_kind": int(_failure_kind),
		"source_kind": int(_source_kind),
		"failed_phase": int(_failed_phase),
		"retired_member_count": _retired_member_count,
		"recreated_member_count": _recreated_member_count,
		"remaining_evidence_count": _remaining_evidence_count,
		"failed_member": int(_failed_member),
	}


# --- 框架内部方法 ---

## 由 GFStorageUtility 一次性写入 reset/recreate 终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @param error_code: 物理终态 Error。
## [br]
## @param failure_kind: 稳定失败分类。
## [br]
## @param source_kind: reset 前观察到的来源分类。
## [br]
## @param failed_phase: 失败阶段；成功时为 Phase.NONE。
## [br]
## @param retired_member_count: 已纳入 retirement 的 identity root 数。
## [br]
## @param recreated_member_count: 已发布的新 claim 成员数。
## [br]
## @param remaining_evidence_count: 尚未收敛的旧 identity/reset evidence 数。
## [br]
## @param failed_member: 首个失败成员；成功时为 FamilyMember.NONE。
## [br]
## @return 首次合法配置成功时返回 true。
func configure_for_framework(
	error_code: Error,
	failure_kind: FailureKind,
	source_kind: SourceKind,
	failed_phase: Phase,
	retired_member_count: int,
	recreated_member_count: int,
	remaining_evidence_count: int,
	failed_member: FamilyMember
) -> bool:
	if _configured or not _is_valid_configuration(
		error_code,
		failure_kind,
		source_kind,
		failed_phase,
		retired_member_count,
		recreated_member_count,
		remaining_evidence_count,
		failed_member
	):
		return false
	_configured = true
	_error_code = error_code
	_failure_kind = failure_kind
	_source_kind = source_kind
	_failed_phase = failed_phase
	_retired_member_count = retired_member_count
	_recreated_member_count = recreated_member_count
	_remaining_evidence_count = remaining_evidence_count
	_failed_member = failed_member
	return true


## 检查框架是否已经写入合法终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
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
	source_kind: SourceKind,
	failed_phase: Phase,
	retired_member_count: int,
	recreated_member_count: int,
	remaining_evidence_count: int,
	failed_member: FamilyMember
) -> bool:
	if (
		not FailureKind.values().has(int(failure_kind))
		or not SourceKind.values().has(int(source_kind))
		or not Phase.values().has(int(failed_phase))
		or not FamilyMember.values().has(int(failed_member))
		or retired_member_count < 0
		or retired_member_count > _MAX_RETIRED_MEMBER_COUNT
		or recreated_member_count < 0
		or recreated_member_count > _MAX_RECREATED_MEMBER_COUNT
		or remaining_evidence_count < 0
		or remaining_evidence_count > _MAX_REMAINING_EVIDENCE_COUNT
	):
		return false
	if error_code == OK:
		return (
			failure_kind == FailureKind.NONE
			and source_kind in [SourceKind.PAYLOAD_ONLY, SourceKind.STRUCTURAL_IDENTITY]
			and failed_phase == Phase.NONE
			and retired_member_count > 0
			and recreated_member_count == _MAX_RECREATED_MEMBER_COUNT
			and remaining_evidence_count == 0
			and failed_member == FamilyMember.NONE
		)
	return failure_kind != FailureKind.NONE and failed_phase != Phase.NONE
