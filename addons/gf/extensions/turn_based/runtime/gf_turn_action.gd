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
## [br]
## @since 3.17.0
var action_id: StringName:
	get:
		return _action_id
	set(value):
		if _can_change_configuration(&"action_id"):
			_action_id = value

## 行动发起者。
## [br]
## @api public
## [br]
## @since 3.17.0
var actor: Object:
	get:
		return _actor
	set(value):
		if _can_change_configuration(&"actor"):
			_actor = value

## 行动目标列表。
## [br]
## @api public
## [br]
## @since 3.17.0
var targets: Array[Object]:
	get:
		return _targets.duplicate()
	set(value):
		if _can_change_configuration(&"targets"):
			_targets = _sanitize_targets(value)

## 行动载荷，框架只存储并传递，不解释其结构。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema payload: Variant payload consumed by project-specific action resolvers.
var payload: Variant:
	get:
		return GFVariantData.duplicate_variant(_payload) if _is_claimed else _payload
	set(value):
		if _can_change_configuration(&"payload"):
			_payload = value

## 主排序优先级，值越大越先处理。
## [br]
## @api public
## [br]
## @since 3.17.0
var priority: int:
	get:
		return _priority
	set(value):
		if _can_change_configuration(&"priority"):
			_priority = value

## 次排序值，值越大越先处理。
## [br]
## @api public
## [br]
## @since 3.17.0
var sort_value: float:
	get:
		return _sort_value
	set(value):
		if _can_change_configuration(&"sort_value"):
			_sort_value = value

## 是否已取消。
## [br]
## @api public
## [br]
## @since 3.17.0
var is_cancelled: bool:
	get:
		return _is_cancelled


# --- 私有变量 ---

var _action_id: StringName = &""
var _actor: Object = null
var _targets: Array[Object] = []
var _payload: Variant = null
var _priority: int = 0
var _sort_value: float = 0.0
var _is_cancelled: bool = false
var _is_claimed: bool = false
var _is_sealed: bool = false


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
	_is_cancelled = true


## 查询行动是否已完成或被丢弃。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 已离开所属队列且不可再次使用时返回 true。
func is_sealed() -> bool:
	return _is_sealed


# --- 可重写钩子 / 虚方法 ---

## 解析行动时由 GFTurnFlowSystem 调用。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _context: 回合上下文。
## [br]
## @return: 可等待结果。
## [br]
## @schema return: Variant that is null or a Signal awaited before action resolution completes.
func _resolve(_context: GFTurnContext) -> Variant:
	return null


## 注入当前 Flow 所属架构。子类只应缓存实际需要的依赖。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _architecture: 当前架构。
func _inject_dependencies(_architecture: GFArchitecture) -> void:
	pass


# --- 框架内部方法 ---

## 由回合流系统注入所属架构依赖。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param architecture: 当前 Flow 所属架构。
func inject_dependencies_from_flow(architecture: GFArchitecture) -> void:
	_inject_dependencies(architecture)


## 声明行动首次进入 Flow 队列，并冻结配置。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @return: 首次成功声明时返回 true。
func claim_for_queue() -> bool:
	if _is_claimed or _is_sealed or _is_cancelled:
		return false
	_targets = _sanitize_targets(_targets)
	_payload = GFVariantData.duplicate_variant(_payload)
	_is_claimed = true
	return true


## 更新解析前仍然有效的目标快照。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param p_targets: 解析前仍有效的目标数组。
func replace_runtime_targets(p_targets: Array[Object]) -> void:
	_targets = _sanitize_targets(p_targets)


## 标记行动已离开队列并永久不可复用。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
func seal_after_queue() -> void:
	_is_sealed = true


# --- 私有/辅助方法 ---

func _sanitize_targets(source_targets: Array[Object]) -> Array[Object]:
	var result: Array[Object] = []
	for target: Object in source_targets:
		if target == null or not is_instance_valid(target) or result.has(target):
			continue
		result.append(target)
	return result


func _can_change_configuration(property_name: StringName) -> bool:
	if not _is_claimed:
		return true
	push_error("[GFTurnAction] 行动已入队，不能修改配置：%s。" % String(property_name))
	return false
