## GFSequenceContext: 指令序列执行上下文。
##
## 用于在一组序列步骤之间传递共享数据，并为步骤提供架构访问入口。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSequenceContext
extends RefCounted


# --- 公共变量 ---

## 共享数据表。
## [br]
## @api public
## [br]
## @schema values: Dictionary shared by sequence steps.
var values: Dictionary = {}


# --- 私有变量 ---

## 所属架构的弱引用；引用失效时由 get_architecture() 尝试全局回退。
## [br]
## @api private
## [br]
var _architecture_ref: WeakRef = null


# --- Godot 生命周期方法 ---

## 创建序列上下文。
## [br]
## @api public
## [br]
## @param architecture: 可选架构实例。
## [br]
## @param p_values: 初始共享数据。
## [br]
## @schema p_values: Dictionary copied into values.
func _init(architecture: GFArchitecture = null, p_values: Dictionary = {}) -> void:
	values = p_values.duplicate(true)
	set_architecture(architecture)


# --- 公共方法 ---

## 设置上下文所属架构。
## [br]
## @api public
## [br]
## @param architecture: 架构实例。
func set_architecture(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 获取上下文所属架构。
## [br]
## @api public
## [br]
## @return 架构实例；不可用时返回 null。
func get_architecture() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture_value: Object = _architecture_ref.get_ref()
		var architecture: GFArchitecture = _variant_to_architecture(architecture_value)
		if architecture != null:
			return architecture
	return GFAutoload.get_architecture_or_null()


## 写入共享值。
## [br]
## @api public
## [br]
## @param key: 键。
## [br]
## @param value: 值。
## [br]
## @return 当前上下文，便于链式构造。
## [br]
## @schema value: Variant value stored in the sequence context.
func set_value(key: StringName, value: Variant) -> GFSequenceContext:
	values[key] = value
	return self


## 读取共享值。
## [br]
## @api public
## [br]
## @param key: 键。
## [br]
## @param default_value: 默认值。
## [br]
## @return 共享值或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant stored value or fallback value.
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(values, key, default_value)


# --- 私有/辅助方法 ---

## 将 Variant 窄化为 GFArchitecture；类型不符时返回 null。
## [br]
## @api private
## [br]
func _variant_to_architecture(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null
