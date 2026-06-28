## GFTurnAction: 通用回合行动基类。
##
## 行动只描述“谁执行、对谁执行、排序值与载荷”，具体效果由子类重写 `_resolve()`。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFTurnAction
extends RefCounted


# --- 公共变量 ---

## 行动标识。
## [br]
## @api public
var action_id: StringName = &""

## 行动发起者。
## [br]
## @api public
var actor: Object = null

## 行动目标列表。
## [br]
## @api public
var targets: Array[Object] = []

## 行动载荷，框架只存储并传递，不解释其结构。
## [br]
## @api public
## [br]
## @schema payload: Variant payload consumed by project-specific action resolvers.
var payload: Variant = null

## 主排序优先级，值越大越先处理。
## [br]
## @api public
var priority: int = 0

## 次排序值，值越大越先处理。
## [br]
## @api public
var sort_value: float = 0.0

## 是否已取消。
## [br]
## @api public
var is_cancelled: bool = false


# --- Godot 生命周期方法 ---

func _init(
	p_actor: Object = null,
	p_targets: Array[Object] = [],
	p_payload: Variant = null,
	p_priority: int = 0,
	p_sort_value: float = 0.0
) -> void:
	actor = p_actor
	targets = _sanitize_targets(p_targets)
	payload = p_payload
	priority = p_priority
	sort_value = p_sort_value


# --- 公共方法 ---

## 取消行动。
## [br]
## @api public
func cancel() -> void:
	is_cancelled = true


# --- 可重写钩子 / 虚方法 ---

## 解析行动时由 GFTurnFlowSystem 调用。
## [br]
## @api protected
## [br]
## @param _context: 回合上下文。
## [br]
## @return 可等待结果。
## [br]
## @schema return: Variant that is null or a Signal awaited before action resolution completes.
func _resolve(_context: GFTurnContext) -> Variant:
	return null


# --- 私有/辅助方法 ---

func _sanitize_targets(source_targets: Array[Object]) -> Array[Object]:
	var result: Array[Object] = []
	for target: Object in source_targets:
		if target == null or not is_instance_valid(target) or result.has(target):
			continue
		result.append(target)
	return result
