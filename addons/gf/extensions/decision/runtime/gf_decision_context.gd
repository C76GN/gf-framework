## GFDecisionContext: 通用决策上下文。
##
## 组合黑板、主体、目标和元数据，供决策候选与考虑项读取状态。
## 该类型不持久化对象引用，也不定义任何具体游戏字段。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 4.3.0
class_name GFDecisionContext
extends RefCounted


# --- 公共变量 ---

## 决策黑板。
## [br]
## @api public
var blackboard: GFDecisionBlackboard = null

## 决策主体，例如当前 agent、系统或导演对象。
## [br]
## @api public
var subject: Object = null

## 可选决策目标。
## [br]
## @api public
var target: Object = null

## 项目自定义上下文元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[StringName, Variant] project-defined decision metadata.
var metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	context_blackboard: GFDecisionBlackboard = null,
	context_subject: Object = null,
	context_target: Object = null,
	context_metadata: Dictionary = {}
) -> void:
	blackboard = context_blackboard if context_blackboard != null else GFDecisionBlackboard.new()
	subject = context_subject
	target = context_target
	metadata = context_metadata.duplicate(true)


# --- 公共方法 ---

## 设置黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param value: 要写入或修改的值。
## [br]
## @schema value: 要写入黑板的任意项目值。
func set_value(key: StringName, value: Variant) -> void:
	_ensure_blackboard().set_value(key, value)


## 获取黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @return: 黑板值或默认值。
## [br]
## @schema default_value: 黑板缺失时返回的任意默认值。
## [br]
## @schema return: 黑板中的项目值，或传入的 default_value。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _ensure_blackboard().get_value(key, default_value)


## 检查黑板值是否存在。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @return: 存在返回 true。
func has_value(key: StringName) -> bool:
	return _ensure_blackboard().has_value(key)


## 设置元数据值。
## [br]
## @api public
## [br]
## @param key: 元数据键。
## [br]
## @param value: 元数据值。
## [br]
## @schema value: 要写入元数据的任意项目值。
func set_metadata_value(key: StringName, value: Variant) -> void:
	if key == &"":
		return
	metadata[key] = value


## 获取元数据值。
## [br]
## @api public
## [br]
## @param key: 元数据键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @return: 元数据值或默认值。
## [br]
## @schema default_value: 元数据缺失时返回的任意默认值。
## [br]
## @schema return: 元数据中的项目值，或传入的 default_value。
func get_metadata_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(metadata, key, default_value)


## 从主体读取决策值。
##
## 优先调用主体的 `get_decision_value(key, fallback)`，否则读取同名属性。
## [br]
## @api public
## [br]
## @param key: 值键或属性名。
## [br]
## @param fallback: 读取失败时的兜底值。
## [br]
## @return: 主体值或兜底值。
## [br]
## @schema fallback: 读取失败时返回的任意项目值。
## [br]
## @schema return: 从主体读取的项目值，或传入的 fallback。
func get_subject_value(key: StringName, fallback: Variant = null) -> Variant:
	return _read_object_value(subject, key, fallback)


## 从目标读取决策值。
##
## 优先调用目标的 `get_decision_value(key, fallback)`，否则读取同名属性。
## [br]
## @api public
## [br]
## @param key: 值键或属性名。
## [br]
## @param fallback: 读取失败时的兜底值。
## [br]
## @return: 目标值或兜底值。
## [br]
## @schema fallback: 读取失败时返回的任意项目值。
## [br]
## @schema return: 从目标读取的项目值，或传入的 fallback。
func get_target_value(key: StringName, fallback: Variant = null) -> Variant:
	return _read_object_value(target, key, fallback)


## 创建上下文副本。
##
## 默认复用 subject 与 target 对象引用，只复制黑板值和元数据。
## [br]
## @api public
## [br]
## @return: 新上下文实例。
func duplicate_context() -> GFDecisionContext:
	return GFDecisionContext.new(
		_ensure_blackboard().duplicate_blackboard(),
		subject,
		target,
		metadata.duplicate(true)
	)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 blackboard、metadata、subject_class 和 target_class 字段的 Dictionary。
func get_debug_snapshot() -> Dictionary:
	return {
		"blackboard": _ensure_blackboard().get_debug_snapshot(),
		"metadata": metadata.duplicate(true),
		"subject_class": subject.get_class() if subject != null and is_instance_valid(subject) else "",
		"target_class": target.get_class() if target != null and is_instance_valid(target) else "",
	}


# --- 私有/辅助方法 ---

func _ensure_blackboard() -> GFDecisionBlackboard:
	if blackboard == null:
		blackboard = GFDecisionBlackboard.new()
	return blackboard


func _read_object_value(object_ref: Object, key: StringName, fallback: Variant = null) -> Variant:
	if object_ref == null or not is_instance_valid(object_ref):
		return fallback
	if object_ref.has_method("get_decision_value"):
		var sentinel: RefCounted = RefCounted.new()
		var method_value: Variant = object_ref.call("get_decision_value", key, sentinel)
		if method_value is Object:
			var method_object: Object = method_value
			if method_object == sentinel:
				method_value = null
			else:
				return method_value
		elif method_value != null:
			return method_value

	var property_path: NodePath = NodePath(String(key))
	if GFObjectPropertyTools.has_property_path(object_ref, property_path):
		return GFObjectPropertyTools.read_property(object_ref, property_path, fallback)

	var direct_value: Variant = object_ref.get(String(key))
	return direct_value if direct_value != null else fallback
