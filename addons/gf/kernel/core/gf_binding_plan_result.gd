## GFBindingPlanResult: required binding plan 的不可变终态结果。
##
## 结果精确标识首个失败 entry、绑定类别、阶段与稳定原因；不保留 Builder、
## Architecture、Scope、实例或 Callable 引用，可安全用于诊断与持久化日志。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFBindingPlanResult
extends RefCounted


# --- 枚举 ---

## Plan 终态。
## [br]
## @api public
## [br]
## @since 11.0.0
enum Status {
	## 全部 required entry 已按顺序成功执行。
	SUCCESS = 0,
	## 某个 required entry 执行失败。
	FAILED = 1,
	## Scope 在执行前或执行期间取消。
	CANCELLED = 2,
	## Plan、Builder ownership 或 Scope 请求无效。
	INVALID_REQUEST = 3,
}

## 绑定类别。
## [br]
## @api public
## [br]
## @since 11.0.0
enum BindingKind {
	## 没有具体 entry。
	NONE = 0,
	## Model 生命周期模块。
	MODEL = 1,
	## System 生命周期模块。
	SYSTEM = 2,
	## Utility 生命周期模块。
	UTILITY = 3,
	## 短生命周期对象工厂。
	FACTORY = 4,
}

## 首个失败阶段。
## [br]
## @api public
## [br]
## @since 11.0.0
enum Phase {
	## 没有失败阶段。
	NONE = 0,
	## Plan、Scope、Architecture 或 entry 前置校验。
	VALIDATION = 1,
	## SELF、factory 或 instance 来源的 candidate 创建。
	INSTANCE_CREATION = 2,
	## 生命周期模块或对象工厂注册。
	REGISTRATION = 3,
	## 模块查询别名注册。
	ALIAS = 4,
	## Scope 取消观察。
	CANCELLATION = 5,
}

## 稳定失败原因。
## [br]
## @api public
## [br]
## @since 11.0.0
enum Reason {
	## 没有失败原因。
	NONE = 0,
	## Plan 配置无效。
	INVALID_PLAN = 1,
	## Builder 不属于 Plan 的 Architecture。
	BUILDER_OWNERSHIP_MISMATCH = 2,
	## binding_id 在同一 Plan 中重复。
	DUPLICATE_BINDING_ID = 3,
	## 正在执行的 Plan 被重入，或已结算 Plan 被再次执行。
	ALREADY_EXECUTED = 4,
	## Scope 为空或已经 complete。
	SCOPE_UNAVAILABLE = 5,
	## Scope 在执行前或执行期间取消。
	SCOPE_CANCELLED = 6,
	## Architecture 不再接纳 required binding mutation。
	ARCHITECTURE_UNAVAILABLE = 7,
	## Entry 目标或冻结配置无效。
	INVALID_ENTRY = 8,
	## Entry 生命周期与目标类别不兼容。
	INVALID_LIFETIME = 9,
	## 无法创建绑定 candidate。
	INSTANCE_CREATION_FAILED = 10,
	## Architecture 拒绝注册模块或工厂。
	REGISTRATION_REJECTED = 11,
	## Architecture 拒绝注册模块别名。
	ALIAS_REJECTED = 12,
}


# --- 常量 ---

const _MAX_DETAIL_LENGTH: int = 512
const _MAX_BINDING_ID_LENGTH: int = 128
const _MAX_TARGET_PATH_LENGTH: int = 512
const _GF_BINDING_LIFETIMES_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_binding_lifetimes.gd"
)


# --- 私有变量 ---

var _configured: bool = false
var _status: Status = Status.INVALID_REQUEST
var _binding_kind: BindingKind = BindingKind.NONE
var _failed_phase: Phase = Phase.VALIDATION
var _reason: Reason = Reason.INVALID_PLAN
var _entry_index: int = -1
var _binding_id: StringName = &""
var _target_path: String = ""
var _lifetime: int = -1
var _executed_count: int = 0
var _detail: String = "Binding plan result is not configured."


# --- 公共方法 ---

## 返回终态是否成功。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 全部 required entry 成功时返回 true。
func is_successful() -> bool:
	return _status == Status.SUCCESS


## 返回 Plan 终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return Status 枚举值。
func get_status() -> Status:
	return _status


## 返回首个失败 entry 的绑定类别。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return BindingKind 枚举值；成功或无具体 entry 时为 NONE。
func get_binding_kind() -> BindingKind:
	return _binding_kind


## 返回首个失败阶段。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return Phase 枚举值；成功时为 NONE。
func get_failed_phase() -> Phase:
	return _failed_phase


## 返回稳定失败原因。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return Reason 枚举值；成功时为 NONE。
func get_reason() -> Reason:
	return _reason


## 返回首个失败 entry 的零基索引。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 首个失败 entry 索引；成功或无具体 entry 时为 -1。
func get_entry_index() -> int:
	return _entry_index


## 返回首个失败 entry 的稳定调用方 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return binding_id；成功或无具体 entry 时为空。
func get_binding_id() -> StringName:
	return _binding_id


## 返回目标脚本的稳定 res:// 路径。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 目标脚本路径；没有可识别目标时为空。
func get_target_path() -> String:
	return _target_path


## 返回 entry 请求的绑定生命周期。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return GFBindingLifetimes.Lifetime 枚举值；无具体 entry 时为 -1。
func get_lifetime() -> int:
	return _lifetime


## 返回已尝试的 entry 数量。
## 只计已经进入 Builder attempt 的 entry：attempt 内失败的当前 entry 计入，声明、
## Plan、Scope 或 Architecture preflight 失败不计，未尝试的后续 entry 也不计。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负 entry 尝试数量。
func get_executed_count() -> int:
	return _executed_count


## 返回有界稳定诊断文本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最多 512 个字符的诊断文本。
func get_detail() -> String:
	return _detail


## 创建终态结果的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 字段相同的新 GFBindingPlanResult。
func duplicate_result() -> GFBindingPlanResult:
	var duplicate: GFBindingPlanResult = GFBindingPlanResult.new()
	var _configured_duplicate: Error = duplicate.configure_for_framework(
		_status,
		_binding_kind,
		_failed_phase,
		_reason,
		_entry_index,
		_binding_id,
		_target_path,
		_lifetime,
		_executed_count,
		_detail
	)
	return duplicate


## 转换为精确、纯数据 Dictionary。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return Plan 终态的纯数据投影。
## [br]
## @schema return: Dictionary，精确包含 status: int、is_successful: bool、binding_kind: int、failed_phase: int、reason: int、entry_index: int、binding_id: String、target_path: String、lifetime: int、executed_count: int 和 detail: String。
func to_dict() -> Dictionary:
	return {
		"status": int(_status),
		"is_successful": is_successful(),
		"binding_kind": int(_binding_kind),
		"failed_phase": int(_failed_phase),
		"reason": int(_reason),
		"entry_index": _entry_index,
		"binding_id": String(_binding_id),
		"target_path": _target_path,
		"lifetime": _lifetime,
		"executed_count": _executed_count,
		"detail": _detail,
	}


# --- 框架内部方法 ---

## 一次性写入终态字段。
## [br]
## @api framework_internal
## [br]
## @param status: Status 枚举值。
## [br]
## @param binding_kind: BindingKind 枚举值。
## [br]
## @param failed_phase: Phase 枚举值。
## [br]
## @param reason: Reason 枚举值。
## [br]
## @param entry_index: 首个失败 entry 索引，或 -1。
## [br]
## @param binding_id: 首个失败 entry 的稳定 ID。
## [br]
## @param target_path: 目标脚本的稳定资源路径。
## [br]
## @param lifetime: GFBindingLifetimes.Lifetime 枚举值，或 -1。
## [br]
## @param executed_count: 已尝试 entry 数量。
## [br]
## @param detail: 有界稳定诊断文本。
## [br]
## @return 首次写入返回 OK；重复或字段无效时返回 Error。
func configure_for_framework(
	status: Status,
	binding_kind: BindingKind,
	failed_phase: Phase,
	reason: Reason,
	entry_index: int,
	binding_id: StringName,
	target_path: String,
	lifetime: int,
	executed_count: int,
	detail: String
) -> Error:
	if _configured:
		return ERR_ALREADY_IN_USE
	var bounded_detail: String = detail.left(_MAX_DETAIL_LENGTH)
	if status < Status.SUCCESS or status > Status.INVALID_REQUEST:
		return ERR_INVALID_PARAMETER
	if binding_kind < BindingKind.NONE or binding_kind > BindingKind.FACTORY:
		return ERR_INVALID_PARAMETER
	if failed_phase < Phase.NONE or failed_phase > Phase.CANCELLATION:
		return ERR_INVALID_PARAMETER
	if reason < Reason.NONE or reason > Reason.ALIAS_REJECTED:
		return ERR_INVALID_PARAMETER
	if entry_index < -1 or lifetime < -1 or executed_count < 0:
		return ERR_INVALID_PARAMETER
	if String(binding_id).length() > _MAX_BINDING_ID_LENGTH:
		return ERR_INVALID_PARAMETER
	if target_path.length() > _MAX_TARGET_PATH_LENGTH:
		return ERR_INVALID_PARAMETER
	if entry_index >= 0:
		if binding_kind == BindingKind.NONE or binding_id == &"":
			return ERR_INVALID_PARAMETER
		if lifetime not in [
			_GF_BINDING_LIFETIMES_SCRIPT.Lifetime.SINGLETON,
			_GF_BINDING_LIFETIMES_SCRIPT.Lifetime.TRANSIENT,
		]:
			return ERR_INVALID_PARAMETER
	if entry_index == -1 and (
		binding_kind != BindingKind.NONE
		or binding_id != &""
		or not target_path.is_empty()
		or lifetime != -1
	):
		return ERR_INVALID_PARAMETER
	if status == Status.SUCCESS and (
		binding_kind != BindingKind.NONE
		or failed_phase != Phase.NONE
		or reason != Reason.NONE
		or entry_index != -1
		or binding_id != &""
		or not target_path.is_empty()
		or lifetime != -1
	):
		return ERR_INVALID_PARAMETER
	if status != Status.SUCCESS and (
		failed_phase == Phase.NONE
		or reason == Reason.NONE
		or bounded_detail.strip_edges().is_empty()
	):
		return ERR_INVALID_PARAMETER
	if status == Status.SUCCESS and not detail.is_empty():
		return ERR_INVALID_PARAMETER
	if status == Status.CANCELLED and (
		failed_phase != Phase.CANCELLATION
		or reason != Reason.SCOPE_CANCELLED
	):
		return ERR_INVALID_PARAMETER

	_status = status
	_binding_kind = binding_kind
	_failed_phase = failed_phase
	_reason = reason
	_entry_index = entry_index
	_binding_id = binding_id
	_target_path = target_path
	_lifetime = lifetime
	_executed_count = executed_count
	_detail = bounded_detail
	_configured = true
	return OK
