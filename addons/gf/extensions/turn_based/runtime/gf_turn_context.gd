## GFTurnContext: 通用回合流程上下文。
##
## 只记录参与者、行动、轮次和元数据，不假设生命值、阵营、技能等业务概念。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFTurnContext
extends RefCounted


# --- 公共变量 ---

## 当前流程参与者。
## [br]
## @api public
var actors: Array[Object] = []

## 当前待处理行动。
## [br]
## @api public
var actions: Array[GFTurnAction] = []

## 当前行动主体。
## [br]
## @api public
var current_actor: Object = null

## 当前轮次索引。
## [br]
## @api public
var round_index: int = 0

## 自定义元数据，框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant] project-defined turn flow metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加参与者。
## [br]
## @api public
## [br]
## @param actor: 参与者对象。
func add_actor(actor: Object) -> void:
	if actor == null or not is_instance_valid(actor) or actors.has(actor):
		return
	actors.append(actor)


## 移除参与者。
## [br]
## @api public
## [br]
## @param actor: 参与者对象。
func remove_actor(actor: Object) -> void:
	actors.erase(actor)
	if current_actor == actor:
		current_actor = null


## 清空运行时行动。
## [br]
## @api public
func clear_actions() -> void:
	actions.clear()


## 从参与者读取排序或判定值。
##
## 优先调用 `get_turn_value(key, fallback)`，其次读取对象属性。
## [br]
## @api public
## [br]
## @param actor: 参与者对象。
## [br]
## @param key: 值键。
## [br]
## @param fallback: 读取失败时的兜底值。
## [br]
## @return 读取到的值。
## [br]
## @schema fallback: Variant returned when no actor value can be read.
## [br]
## @schema return: Variant read from get_turn_value(), object property access, or fallback.
func get_actor_value(actor: Object, key: StringName, fallback: Variant = null) -> Variant:
	if actor == null or not is_instance_valid(actor):
		return fallback
	if actor.has_method("get_turn_value"):
		return actor.call("get_turn_value", key, fallback)

	var property_name: StringName = key
	return GFObjectPropertyTools.read_property(actor, NodePath(String(property_name)), fallback)
