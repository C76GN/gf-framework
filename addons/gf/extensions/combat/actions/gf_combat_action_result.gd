## GFCombatActionResult: 通用战斗动作应用结果。
##
## 保存动作是否被接受、原始动作、最终动作、数值变化和元数据，
## 方便项目统一记录日志、派发事件或驱动反馈。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFCombatActionResult
extends RefCounted


# --- 公共变量 ---

## 是否成功应用。
## [br]
## @api public
var ok: bool = false

## 结果原因。
## [br]
## @api public
var reason: StringName = &""

## 原始动作副本。
## [br]
## @api public
var original_action: GFCombatAction = null

## 最终动作副本。
## [br]
## @api public
var action: GFCombatAction = null

## 应用前数值。
## [br]
## @api public
var previous_value: float = 0.0

## 应用后数值。
## [br]
## @api public
var current_value: float = 0.0

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义结果元数据；框架只复制并透传。
var metadata: Dictionary = {}


# --- 公共方法 ---

## 创建成功结果。
## [br]
## @api public
## [br]
## @param p_original_action: 原始动作。
## [br]
## @param p_action: 最终动作。
## [br]
## @param p_previous_value: 应用前数值。
## [br]
## @param p_current_value: 应用后数值。
## [br]
## @param p_metadata: 元数据。
## [br]
## @return 成功结果。
## [br]
## @schema p_metadata: Dictionary，项目自定义结果元数据；框架只复制并透传。
static func make_success(
	p_original_action: GFCombatAction,
	p_action: GFCombatAction,
	p_previous_value: float,
	p_current_value: float,
	p_metadata: Dictionary = {}
) -> GFCombatActionResult:
	var result: GFCombatActionResult = GFCombatActionResult.new()
	result.ok = true
	result.reason = &"applied"
	result.original_action = p_original_action.duplicate_action() if p_original_action != null else null
	result.action = p_action.duplicate_action() if p_action != null else null
	result.previous_value = p_previous_value
	result.current_value = p_current_value
	result.metadata = p_metadata.duplicate(true)
	return result


## 创建失败结果。
## [br]
## @api public
## [br]
## @param p_reason: 失败原因。
## [br]
## @param p_original_action: 原始动作。
## [br]
## @param p_previous_value: 当前数值。
## [br]
## @param p_metadata: 元数据。
## [br]
## @return 失败结果。
## [br]
## @schema p_metadata: Dictionary，项目自定义结果元数据；框架只复制并透传。
static func make_failure(
	p_reason: StringName,
	p_original_action: GFCombatAction = null,
	p_previous_value: float = 0.0,
	p_metadata: Dictionary = {}
) -> GFCombatActionResult:
	var result: GFCombatActionResult = GFCombatActionResult.new()
	result.ok = false
	result.reason = p_reason
	result.original_action = p_original_action.duplicate_action() if p_original_action != null else null
	result.action = p_original_action.duplicate_action() if p_original_action != null else null
	result.previous_value = p_previous_value
	result.current_value = p_previous_value
	result.metadata = p_metadata.duplicate(true)
	return result


## 转为字典。
## [br]
## @api public
## [br]
## @return 字典快照。
## [br]
## @schema return: Dictionary，包含 ok、reason、original_action、action、previous_value、current_value、delta 和 metadata。
func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"original_action": original_action.to_dict() if original_action != null else {},
		"action": action.to_dict() if action != null else {},
		"previous_value": previous_value,
		"current_value": current_value,
		"delta": current_value - previous_value,
		"metadata": metadata.duplicate(true),
	}


## 转为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 报告字典快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on to_dict().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(to_dict(), options)
