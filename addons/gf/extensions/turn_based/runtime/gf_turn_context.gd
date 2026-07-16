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

## 当前行动主体。
## [br]
## @api public
## [br]
## @since 3.17.0
var current_actor: Object:
	get:
		return _current_actor

## 当前轮次索引。
## [br]
## @api public
## [br]
## @since 3.17.0
var round_index: int:
	get:
		return _round_index

## 自定义元数据，框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant] project-defined turn flow metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _actors: Array[Object] = []
var _current_actor: Object = null
var _round_index: int = 0


# --- 公共方法 ---

## 添加参与者。
## [br]
## @api public
## [br]
## @param actor: 参与者对象。
func add_actor(actor: Object) -> void:
	if actor == null or not is_instance_valid(actor) or _actors.has(actor):
		return
	_actors.append(actor)


## 移除参与者。
## [br]
## @api public
## [br]
## @param actor: 参与者对象。
func remove_actor(actor: Object) -> void:
	_actors.erase(actor)
	if _current_actor == actor:
		_current_actor = null


## 获取参与者只读快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 当前有效性尚未重新校验的参与者数组快照。
func get_actors() -> Array[Object]:
	return _actors.duplicate()


## 清理已经失效的参与者引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 被移除的失效参与者数量。
## [br]
## @schema return: int removed invalid actor reference count.
func cleanup_invalid_actors() -> int:
	var removed_count: int = 0
	for index: int in range(_actors.size() - 1, -1, -1):
		var actor: Object = _actors[index]
		if actor == null or not is_instance_valid(actor):
			_actors.remove_at(index)
			removed_count += 1
	if _current_actor != null and not is_instance_valid(_current_actor):
		_current_actor = null
	return removed_count


## 从参与者读取排序或判定值。
##
## 优先调用 `get_turn_value(key, fallback)`，其次读取对象属性。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param actor: 参与者对象。
## [br]
## @param key: 值键。
## [br]
## @param fallback: 读取失败时的兜底值。
## [br]
## @return: 读取到的值。
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


# --- 框架内部方法 ---

## 设置当前行动主体。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param actor: 当前行动主体；传入失效对象时归一为空。
func set_current_actor_from_flow(actor: Object) -> void:
	_current_actor = actor if actor == null or is_instance_valid(actor) else null


## 重置轮次索引。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
func reset_round_from_flow() -> void:
	_round_index = 0


## 推进一个轮次。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
func advance_round_from_flow() -> void:
	_round_index += 1
