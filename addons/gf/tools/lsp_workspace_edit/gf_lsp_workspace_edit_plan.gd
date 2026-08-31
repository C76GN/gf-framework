## GFLspWorkspaceEditPlan: 已预检 LSP WorkspaceEdit 的一次性提交计划。
##
## 该值对象由 GFLspWorkspaceEditAdapter 创建，绑定工作区身份与版本、文档版本、
## 来源 SHA-256、结果 SHA-256 和完整计划 SHA-256。公开读取只返回隔离副本，
## 不暴露待写入源码；计划一旦进入底层写事务即被消费，不能重复提交。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFLspWorkspaceEditPlan
extends RefCounted


# --- 私有变量 ---

var _initialized: bool = false
var _valid: bool = false
var _consumed: bool = false
var _plan_sha256: String = ""
var _report: Dictionary = {}
var _payload: Dictionary = {}


# --- 公共方法 ---

## 返回计划当前是否可提交。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 计划已成功预检且尚未被消费时为 true。
func is_valid() -> bool:
	return _initialized and _valid and not _consumed


## 返回计划是否已经进入过底层写事务。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 计划已被一次性消费时为 true。
func is_consumed() -> bool:
	return _consumed


## 返回绑定完整计划内容的 SHA-256。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 有效计划的 64 位小写十六进制摘要；无效计划返回空字符串。
func get_plan_sha256() -> String:
	return _plan_sha256


## 返回不含源码正文的隔离计划报告。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: JSON-safe 报告副本。
## [br]
## @schema return: closed Dictionary，包含 ok、status、plan_sha256、workspace_uri、workspace_version、position_encoding、document_count、edit_count、changed_count、source_bytes、result_bytes、issues、documents、consumed。
func get_report() -> Dictionary:
	var result: Dictionary = _report.duplicate(true)
	result["consumed"] = _consumed
	result["ok"] = is_valid()
	if _consumed:
		result["status"] = "consumed"
	return result


## 由 WorkspaceEdit 适配器初始化计划一次。
##
## 这是工具包内部桥接入口；其他调用方不应构造或改写 payload。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param valid: 预检是否成功。
## [br]
## @param plan_sha256: 成功计划的完整摘要。
## [br]
## @param report: 不含源码正文的公开报告。
## [br]
## @param payload: 只供适配器提交阶段复核的闭合内部载荷。
## [br]
## @return: 首次初始化成功时为 true。
## [br]
## @schema report: closed Dictionary，形状与 get_report() 返回值一致但可省略 consumed。
## [br]
## @schema payload: closed Dictionary，由 GFLspWorkspaceEditAdapter 定义并完整绑定进 plan_sha256。
func initialize_for_adapter(
	valid: bool,
	plan_sha256: String,
	report: Dictionary,
	payload: Dictionary
) -> bool:
	if _initialized:
		return false
	_initialized = true
	_valid = valid
	_plan_sha256 = plan_sha256 if valid else ""
	_report = report.duplicate(true)
	_payload = payload.duplicate(true) if valid else {}
	return true


## 返回适配器提交复核所需的隔离内部载荷。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return: 有效且未消费计划的 payload 副本；否则为空字典。
## [br]
## @schema return: closed Dictionary，由 GFLspWorkspaceEditAdapter 定义。
func read_payload_for_adapter() -> Dictionary:
	if not is_valid():
		return {}
	return _payload.duplicate(true)


## 在适配器即将调用底层事务时一次性认领计划。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param expected_plan_sha256: 适配器根据内部载荷重新计算的摘要。
## [br]
## @return: 摘要匹配且计划首次被认领时为 true。
func claim_for_adapter(expected_plan_sha256: String) -> bool:
	if not is_valid() or expected_plan_sha256 != _plan_sha256:
		return false
	_consumed = true
	return true
