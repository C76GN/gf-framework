## GFTweenPropertyBinding: 原生 PropertyTweener 的执行世代写入保护。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFTweenPropertyBinding
extends RefCounted


# --- 公共变量 ---

## 代理属性；旧执行世代只能读取缓存，不能继续写目标。
## [br]
## @api framework_internal
## [br]
## @schema value: Variant，与被代理属性具有相同类型。
var value: Variant:
	get:
		var owner: GFConfiguredTweenAction = _get_owner()
		if owner != null:
			return owner.read_bound_property(_property_name, _generation, _last_value)
		return _last_value
	set(next_value):
		_last_value = next_value
		var owner: GFConfiguredTweenAction = _get_owner()
		if owner != null:
			owner.write_bound_property(_property_name, next_value, _generation)


# --- 私有变量 ---

var _owner_ref: WeakRef
var _property_name: NodePath
var _generation: int
var _last_value: Variant


# --- Godot 生命周期方法 ---

func _init(owner: GFConfiguredTweenAction, property_name: NodePath, generation: int, initial_value: Variant) -> void:
	_owner_ref = weakref(owner)
	_property_name = property_name
	_generation = generation
	_last_value = initial_value


# --- 私有/辅助方法 ---

func _get_owner() -> GFConfiguredTweenAction:
	var owner: Variant = _owner_ref.get_ref()
	if owner is GFConfiguredTweenAction:
		return owner
	return null
