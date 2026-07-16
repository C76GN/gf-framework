## GFModifiedAttribute: 带修饰器公式的响应式属性。
## 
## 持有基础值并管理多个修饰器 (GFModifier)。
## 内部使用公式 (Base + BaseAdd) * (1.0 + PercentAdd) + FinalAdd 进行自动重算。
## 对外通过只读的 current_value 暴露响应式结果，方便 UI 绑定。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFModifiedAttribute
extends RefCounted


# --- 常量 ---

const _READ_ONLY_BINDABLE_PROPERTY_SCRIPT = preload("res://addons/gf/kernel/core/gf_read_only_bindable_property.gd")
const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 公共变量 ---

## 属性的只读响应式当前值。
## [br]
## @api public
var current_value: GFBindableProperty:
	get:
		return _current_value_view


# --- 私有变量 ---

var _current_value_view: GFBindableProperty
var _base_value: float = 0.0
var _modifiers: Array[GFModifier] = []


# --- Godot 生命周期方法 ---

func _init(p_base_value: float = 0.0) -> void:
	_base_value = p_base_value if _GF_COMBAT_FINITE_MATH.is_finite_float(p_base_value) else 0.0
	_current_value_view = _READ_ONLY_BINDABLE_PROPERTY_SCRIPT.new(_base_value)
	_recalculate()


# --- 公共方法 ---

## 设置基础值。
## [br]
## @api public
## [br]
## @param p_value: 新的基础值。
func set_base_value(p_value: float) -> void:
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(p_value):
		return
	if _base_value == p_value:
		return
	_base_value = p_value
	_recalculate()


## 获取基础值。
## [br]
## @api public
## [br]
## @return: 当前基础值。
func get_base_value() -> float:
	return _base_value


## 添加修饰器。
## [br]
## @api public
## [br]
## @param p_modifier: 修饰器实例。
func add_modifier(p_modifier: GFModifier) -> void:
	if p_modifier == null or not p_modifier.is_numeric_state_valid():
		return

	_modifiers.append(p_modifier)
	_recalculate()


## 移除修饰器。
## [br]
## @api public
## [br]
## @param p_modifier: 要移除的修饰器实例。
func remove_modifier(p_modifier: GFModifier) -> void:
	if p_modifier == null:
		return

	_modifiers.erase(p_modifier)
	_recalculate()


## 根据 source_id 移除所有匹配的修饰器。
## [br]
## @api public
## [br]
## @param p_source_id: 来源标识。
func remove_modifiers_by_source(p_source_id: StringName) -> void:
	var to_remove: Array[GFModifier] = []
	for modifier: GFModifier in _modifiers:
		if modifier.source_id == p_source_id:
			to_remove.append(modifier)
	
	if to_remove.is_empty():
		return
		
	for modifier: GFModifier in to_remove:
		_modifiers.erase(modifier)
	_recalculate()


## 强制执行一次属性重算。
## 当外部直接修改了 Modifier 的数值时，可手动调用此方法触发 UI 更新。
## [br]
## @api public
func force_recalculate() -> void:
	_recalculate()


# --- 私有/辅助方法 ---

# 执行公式重算：(Base + BaseAdd) * (1.0 + PercentAdd) + FinalAdd
func _recalculate() -> void:
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(_base_value):
		return
	var base_add: float = 0.0
	var percent_add: float = 0.0
	var final_add: float = 0.0
	
	for mod: GFModifier in _modifiers:
		if mod == null or not mod.is_numeric_state_valid():
			return
		var next_value: float = 0.0
		match mod.type:
			GFModifier.Type.BASE_ADD:
				next_value = base_add + mod.value
				if not _GF_COMBAT_FINITE_MATH.is_finite_float(next_value):
					return
				base_add = next_value
			GFModifier.Type.PERCENT_ADD:
				next_value = percent_add + mod.value
				if not _GF_COMBAT_FINITE_MATH.is_finite_float(next_value):
					return
				percent_add = next_value
			GFModifier.Type.FINAL_ADD:
				next_value = final_add + mod.value
				if not _GF_COMBAT_FINITE_MATH.is_finite_float(next_value):
					return
				final_add = next_value

	var base_total: float = _base_value + base_add
	var multiplier: float = 1.0 + percent_add
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(base_total)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(multiplier)
	):
		return
	var multiplied_value: float = base_total * multiplier
	var final_value: float = multiplied_value + final_add
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(multiplied_value)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(final_value)
	):
		return
	_current_value_view.call("_set_value_from_owner", final_value)
