## GFModalResult: 通用 modal 交互结果。
##
## 只描述用户选择、附加载荷和调用上下文，不解释业务含义。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFModalResult
extends RefCounted


# --- 常量 ---

## 表示肯定或主要操作。
## [br]
## @api public
const STATUS_CONFIRMED: StringName = &"confirmed"

## 表示取消、返回或关闭。
## [br]
## @api public
const STATUS_CANCELLED: StringName = &"cancelled"

## 表示中性关闭。
## [br]
## @api public
const STATUS_DISMISSED: StringName = &"dismissed"


# --- 公共变量 ---

## 结果状态。
## [br]
## @api public
var status: StringName = STATUS_DISMISSED

## 触发该结果的动作 ID。
## [br]
## @api public
var action_id: StringName = &""

## 动作携带的通用载荷。
## [br]
## @api public
## [br]
## @schema payload: Variant，项目自定义动作载荷。
var payload: Variant = null

## 结果元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，结果附带的项目侧元数据。
var metadata: Dictionary = {}

## 打开 modal 时传入的调用上下文。
## [br]
## @api public
## [br]
## @schema context: Dictionary，打开 modal 时传入的调用上下文。
var context: Dictionary = {}


# --- 公共方法 ---

## 创建结果实例。
## [br]
## @api public
## [br]
## @param result_status: 结果状态。
## [br]
## @param result_action_id: 触发动作 ID。
## [br]
## @param result_payload: 动作载荷。
## [br]
## @schema result_payload: Variant，项目自定义动作载荷。
## [br]
## @param result_metadata: 结果元数据。
## [br]
## @schema result_metadata: Dictionary，结果附带的项目侧元数据。
## [br]
## @param result_context: 调用上下文。
## [br]
## @schema result_context: Dictionary，打开 modal 时传入的调用上下文。
## [br]
## @return 新结果实例。
static func create(
	result_status: StringName,
	result_action_id: StringName = &"",
	result_payload: Variant = null,
	result_metadata: Dictionary = {},
	result_context: Dictionary = {}
) -> GFModalResult:
	var result: GFModalResult = GFModalResult.new()
	result.status = result_status
	result.action_id = result_action_id
	result.payload = result_payload
	result.metadata = result_metadata.duplicate(true)
	result.context = result_context.duplicate(true)
	return result


## 导出为字典。
## [br]
## @api public
## [br]
## @return 结果字典。
## [br]
## @schema return: Dictionary，包含 status、action_id、payload、metadata 和 context。
func to_dict() -> Dictionary:
	return {
		"status": status,
		"action_id": action_id,
		"payload": GFVariantData.duplicate_graph(payload),
		"metadata": metadata.duplicate(true),
		"context": context.duplicate(true),
	}
