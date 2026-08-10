## GFModifiedAttributeSet: 一组可修饰运行时属性。
##
## 用 StringName 管理多个 GFModifiedAttribute，便于角色、装备或能力对象集中维护
## 移动速度、攻击、防御等项目自定义数值。它不规定属性含义，也不直接处理 Buff 生命周期。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFModifiedAttributeSet
extends RefCounted


# --- 信号 ---

## 属性被定义或替换时发出。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param attribute: 属性实例。
signal attribute_defined(attribute_id: StringName, attribute: GFModifiedAttribute)

## 属性被移除时发出。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
signal attribute_removed(attribute_id: StringName)

## 属性当前值变化时发出。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param current_value: 当前值。
## [br]
## @param previous_value: 变化前的值。
signal attribute_changed(attribute_id: StringName, current_value: float, previous_value: float)


# --- 私有变量 ---

var _attributes: Dictionary[StringName, GFModifiedAttribute] = {}


# --- 公共方法 ---

## 定义或替换属性。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param base_value: 基础值。
## [br]
## @return 新创建的属性；attribute_id 为空时返回 null。
func define_attribute(attribute_id: StringName, base_value: float = 0.0) -> GFModifiedAttribute:
	if attribute_id == &"":
		return null

	var attribute: GFModifiedAttribute = GFModifiedAttribute.new(base_value)
	var _set: bool = set_attribute(attribute_id, attribute)
	return attribute


## 设置已有属性实例。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param attribute: 属性实例。
## [br]
## @return 设置成功返回 true。
func set_attribute(attribute_id: StringName, attribute: GFModifiedAttribute) -> bool:
	if attribute_id == &"" or attribute == null:
		return false

	if _attributes.has(attribute_id):
		_disconnect_attribute(attribute_id, _attributes[attribute_id])
	_attributes[attribute_id] = attribute
	_connect_attribute(attribute_id, attribute)
	attribute_defined.emit(attribute_id, attribute)
	return true


## 批量定义默认属性。
## [br]
## @api public
## [br]
## @param defaults: attribute_id -> base_value 字典。
## [br]
## @schema defaults: Dictionary，键为属性标识，值为基础数值。
func define_defaults(defaults: Dictionary) -> void:
	for attribute_id_variant: Variant in defaults.keys():
		var _defined: GFModifiedAttribute = define_attribute(
			GFVariantData.to_string_name(attribute_id_variant),
			GFVariantData.to_float(defaults[attribute_id_variant])
		)


## 检查属性是否存在。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @return 存在返回 true。
func has_attribute(attribute_id: StringName) -> bool:
	return _attributes.has(attribute_id)


## 获取属性实例。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @return 属性实例；不存在时返回 null。
func get_attribute(attribute_id: StringName) -> GFModifiedAttribute:
	return _get_attribute_value(GFVariantData.get_option_value(_attributes, attribute_id))


## 获取属性实例，不存在时自动定义。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param base_value: 自动定义时使用的基础值。
## [br]
## @return 属性实例；attribute_id 为空时返回 null。
func get_or_define_attribute(attribute_id: StringName, base_value: float = 0.0) -> GFModifiedAttribute:
	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute != null:
		return attribute
	return define_attribute(attribute_id, base_value)


## 移除属性。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @return 移除成功返回 true。
func remove_attribute(attribute_id: StringName) -> bool:
	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute == null:
		return false

	_disconnect_attribute(attribute_id, attribute)
	var _erased: bool = _attributes.erase(attribute_id)
	attribute_removed.emit(attribute_id)
	return true


## 清空所有属性。
## 清理会先原子地脱离原有索引与信号，再发送移除通知；通知期间新定义的属性会保留。
## [br]
## @api public
## [br]
## @since 11.0.0
func clear() -> void:
	var removed_attributes: Dictionary[StringName, GFModifiedAttribute] = _attributes.duplicate()
	_attributes.clear()
	for attribute_id_variant: Variant in removed_attributes.keys():
		var attribute_id: StringName = GFVariantData.to_string_name(attribute_id_variant)
		_disconnect_attribute(
			attribute_id,
			_get_attribute_value(GFVariantData.get_option_value(removed_attributes, attribute_id))
		)
	for attribute_id_variant: Variant in removed_attributes.keys():
		var attribute_id: StringName = GFVariantData.to_string_name(attribute_id_variant)
		attribute_removed.emit(attribute_id)


## 获取属性 ID 列表。
## [br]
## @api public
## [br]
## @return 属性 ID 列表。
## [br]
## @schema return: Array[StringName]，元素为属性标识。
func get_attribute_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for attribute_id_variant: Variant in _attributes.keys():
		result.append(GFVariantData.to_string_name(attribute_id_variant))
	return result


## 获取属性字典副本。
## [br]
## @api public
## [br]
## @return attribute_id -> GFModifiedAttribute 字典副本。
## [br]
## @schema return: Dictionary，键为属性标识，值为 GFModifiedAttribute 实例。
func get_attributes() -> Dictionary:
	return _attributes.duplicate()


## 获取属性当前值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param default_value: 属性不存在时返回的默认值。
## [br]
## @return 当前值。
func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:
	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute == null:
		return default_value
	return GFVariantData.to_float(attribute.current_value.get_value(), default_value)


## 设置属性基础值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param base_value: 新基础值。
## [br]
## @return 设置成功返回 true。
func set_base_value(attribute_id: StringName, base_value: float) -> bool:
	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute == null:
		return false

	attribute.set_base_value(base_value)
	return true


## 获取属性基础值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param default_value: 属性不存在时返回的默认值。
## [br]
## @return 基础值。
func get_base_value(attribute_id: StringName, default_value: float = 0.0) -> float:
	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute == null:
		return default_value
	return attribute.get_base_value()


## 添加修饰器。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param modifier: 修饰器实例。
## [br]
## @param define_if_missing: 属性不存在时是否自动定义。
## [br]
## @return 添加成功返回 true。
func add_modifier(
	attribute_id: StringName,
	modifier: GFModifier,
	define_if_missing: bool = false
) -> bool:
	if modifier == null:
		return false

	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute == null and define_if_missing:
		attribute = define_attribute(attribute_id)
	if attribute == null:
		return false

	attribute.add_modifier(modifier)
	return true


## 移除修饰器。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param modifier: 修饰器实例。
## [br]
## @return 属性存在且 modifier 有效时返回 true。
func remove_modifier(attribute_id: StringName, modifier: GFModifier) -> bool:
	var attribute: GFModifiedAttribute = get_attribute(attribute_id)
	if attribute == null or modifier == null:
		return false

	attribute.remove_modifier(modifier)
	return true


## 按来源移除修饰器；attribute_id 为空时会作用于全部属性。
## [br]
## @api public
## [br]
## @param source_id: 来源标识。
## [br]
## @param attribute_id: 可选属性标识。
func remove_modifiers_by_source(source_id: StringName, attribute_id: StringName = &"") -> void:
	if attribute_id != &"":
		var attribute: GFModifiedAttribute = get_attribute(attribute_id)
		if attribute != null:
			attribute.remove_modifiers_by_source(source_id)
		return

	for attribute_variant: Variant in _attributes.values():
		var attribute: GFModifiedAttribute = _get_attribute_value(attribute_variant)
		if attribute != null:
			attribute.remove_modifiers_by_source(source_id)


## 强制重算属性；attribute_id 为空时会重算全部属性。
## [br]
## @api public
## [br]
## @param attribute_id: 可选属性标识。
func force_recalculate(attribute_id: StringName = &"") -> void:
	if attribute_id != &"":
		var attribute: GFModifiedAttribute = get_attribute(attribute_id)
		if attribute != null:
			attribute.force_recalculate()
		return

	for attribute_variant: Variant in _attributes.values():
		var attribute: GFModifiedAttribute = _get_attribute_value(attribute_variant)
		if attribute != null:
			attribute.force_recalculate()


## 导出基础值快照。修饰器属于运行时状态，不会进入该快照。
## [br]
## @api public
## [br]
## @return attribute_id -> base_value 字典。
## [br]
## @schema return: Dictionary，键为属性标识，值为基础数值。
func get_base_value_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for attribute_id_variant: Variant in _attributes.keys():
		var attribute_id: StringName = GFVariantData.to_string_name(attribute_id_variant)
		var attribute: GFModifiedAttribute = _get_attribute_value(GFVariantData.get_option_value(_attributes, attribute_id))
		if attribute != null:
			snapshot[String(attribute_id)] = attribute.get_base_value()
	return snapshot


## 从基础值快照恢复。
## [br]
## @api public
## [br]
## @param snapshot: attribute_id -> base_value 字典。
## [br]
## @param clear_existing: 是否先清空现有属性。
## [br]
## @schema snapshot: Dictionary，键为属性标识，值为基础数值。
func restore_base_value_snapshot(snapshot: Dictionary, clear_existing: bool = false) -> void:
	if clear_existing:
		clear()
	for attribute_id_variant: Variant in snapshot.keys():
		var attribute_id: StringName = GFVariantData.to_string_name(attribute_id_variant)
		var base_value: float = GFVariantData.to_float(snapshot[attribute_id_variant])
		var attribute: GFModifiedAttribute = get_attribute(attribute_id)
		if attribute == null:
			var _defined: GFModifiedAttribute = define_attribute(attribute_id, base_value)
		else:
			attribute.set_base_value(base_value)


# --- 私有/辅助方法 ---

func _connect_attribute(attribute_id: StringName, attribute: GFModifiedAttribute) -> void:
	var callable: Callable = _get_attribute_changed_callable(attribute_id)
	if not attribute.current_value.value_changed.is_connected(callable):
		var _connected: int = attribute.current_value.value_changed.connect(callable)


func _disconnect_attribute(attribute_id: StringName, attribute: GFModifiedAttribute) -> void:
	if attribute == null:
		return
	var callable: Callable = _get_attribute_changed_callable(attribute_id)
	if attribute.current_value.value_changed.is_connected(callable):
		attribute.current_value.value_changed.disconnect(callable)


func _get_attribute_changed_callable(attribute_id: StringName) -> Callable:
	return Callable(self, "_on_attribute_value_changed").bind(attribute_id)


func _get_attribute_value(value: Variant) -> GFModifiedAttribute:
	if value is GFModifiedAttribute:
		var attribute: GFModifiedAttribute = value
		return attribute
	return null


func _on_attribute_value_changed(previous_value: Variant, current_value: Variant, attribute_id: StringName) -> void:
	attribute_changed.emit(
		attribute_id,
		GFVariantData.to_float(current_value),
		GFVariantData.to_float(previous_value)
	)
