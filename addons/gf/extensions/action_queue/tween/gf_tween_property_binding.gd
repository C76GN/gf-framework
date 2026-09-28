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

## 动作所有者的弱引用，避免绑定反向持有动作。
## [br]
## @api private
var _owner_ref: WeakRef

## 由该绑定代理读写的目标属性路径。
## [br]
## @api private
var _property_name: NodePath

## 创建该绑定时对应的动作执行世代。
## [br]
## @api private
var _generation: int

## 最近一次通过代理属性保存的值。
## [br]
## @api private
var _last_value: Variant


# --- Godot 生命周期方法 ---

func _init(owner: GFConfiguredTweenAction, property_name: NodePath, generation: int, initial_value: Variant) -> void:
	_owner_ref = weakref(owner)
	_property_name = property_name
	_generation = generation
	_last_value = initial_value


# --- 私有/辅助方法 ---

## 解析仍有效的弱引用所有者；失效或类型不符时返回 null。
## [br]
## @api private
func _get_owner() -> GFConfiguredTweenAction:
	var owner: Variant = _owner_ref.get_ref()
	if owner is GFConfiguredTweenAction:
		return owner
	return null
