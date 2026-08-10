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
## @since 3.17.0
## [br]
## @param actor: 参与者对象。Context 会强持有 RefCounted，直到 remove_actor() 或 Context 自身释放。
func add_actor(actor: Object) -> void:
	if actor == null or not is_instance_valid(actor) or _actors.has(actor):
		return
	_actors.append(actor)


## 移除参与者。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param actor: 参与者对象；移除会释放 Context 对 RefCounted 的强所有权。
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
## 优先调用参数兼容的 `get_turn_value(key, fallback)`，其次读取对象属性。
## 同名方法若不接受两个实参或参数类型不兼容，会被视为不可调用并继续属性读取。
## GDScript 无法捕获方法内部脚本错误；项目实现必须自行保证回调可安全返回。
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
	var arguments: Array = [key, fallback]
	if _can_invoke_actor_method(actor, &"get_turn_value", arguments):
		return actor.callv(&"get_turn_value", arguments)

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


# --- 私有/辅助方法 ---

func _can_invoke_actor_method(
	actor: Object,
	method_name: StringName,
	arguments: Array
) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.has_method(method_name):
		return false
	for method_info: Dictionary in actor.get_method_list():
		if GFVariantData.get_option_string_name(method_info, "name") != method_name:
			continue
		if not _method_accepts_argument_count(method_info, arguments.size()):
			return false
		var method_arguments: Array = GFVariantData.get_option_array(method_info, "args")
		var fixed_argument_count: int = mini(arguments.size(), method_arguments.size())
		for index: int in range(fixed_argument_count):
			var argument_info: Dictionary = GFVariantData.as_dictionary(method_arguments[index])
			if not _method_argument_accepts_value(argument_info, arguments[index]):
				return false
		return true
	return false


func _method_accepts_argument_count(method_info: Dictionary, argument_count: int) -> bool:
	var method_arguments: Array = GFVariantData.get_option_array(method_info, "args")
	var default_arguments: Array = GFVariantData.get_option_array(method_info, "default_args")
	if default_arguments.size() > method_arguments.size():
		return false
	var required_count: int = method_arguments.size() - default_arguments.size()
	var method_flags: int = GFVariantData.get_option_int(method_info, "flags", 0)
	var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
	return (
		required_count <= argument_count
		and (argument_count <= method_arguments.size() or accepts_varargs)
	)


func _method_argument_accepts_value(argument_info: Dictionary, value: Variant) -> bool:
	var expected_type: int = GFVariantData.get_option_int(argument_info, "type", TYPE_NIL)
	if expected_type == TYPE_NIL:
		return true
	if value == null:
		return expected_type == TYPE_OBJECT

	var actual_type: int = typeof(value)
	if expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
		return true
	if (
		(expected_type == TYPE_STRING and actual_type == TYPE_STRING_NAME)
		or (expected_type == TYPE_STRING_NAME and actual_type == TYPE_STRING)
	):
		return true
	if actual_type != expected_type:
		return false
	if expected_type != TYPE_OBJECT:
		return true

	var expected_class_name: StringName = GFVariantData.get_option_string_name(
		argument_info,
		"class_name"
	)
	if expected_class_name == &"":
		return true
	var object_value: Object = value
	return _object_matches_class_name(object_value, expected_class_name)


func _object_matches_class_name(value: Object, expected_class_name: StringName) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	if value.is_class(String(expected_class_name)):
		return true

	var script_value: Variant = value.get_script()
	while script_value is Script:
		var script: Script = script_value
		if (
			StringName(script.get_global_name()) == expected_class_name
			or StringName(script.resource_path) == expected_class_name
		):
			return true
		script_value = script.get_base_script()
	return false
