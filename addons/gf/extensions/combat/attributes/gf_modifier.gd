## GFModifier: 属性修饰器数据类。
##
## 定义了如何修改一个通用属性（如加值、乘值）。
## `attribute_id` 表示目标属性，`source_id` 表示来源，避免把“改谁”和“从哪来”混在一起。
## 通常由 Buff、装备或被动技能产生。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFModifier
extends RefCounted


# --- 枚举 ---

## 修饰器计算类型。
## [br]
## @api public
enum Type {
	## 基础加值。
	BASE_ADD,
	## 百分比乘区。
	PERCENT_ADD,
	## 最终加值。
	FINAL_ADD,
}


# --- 公共变量 ---

## 修饰器类型。
## [br]
## @api public
var type: Type = Type.BASE_ADD

## 修饰器的数值。
## [br]
## @api public
var value: float = 0.0

## 目标属性标识，例如 &"ATK"、&"HP"。
## [br]
## @api public
var attribute_id: StringName = &""

## 来源标识，例如 Buff ID、装备 ID 或被动技能 ID，用于查找和移除。
## [br]
## @api public
var source_id: StringName = &""


# --- Godot 生命周期方法 ---

func _init(
	p_type: Type = Type.BASE_ADD,
	p_value: float = 0.0,
	p_attribute_id: StringName = &"",
	p_source_id: StringName = &""
) -> void:
	type = p_type
	value = p_value
	attribute_id = p_attribute_id
	source_id = p_source_id


# --- 公共方法 ---

## 静态工厂方法：创建基础加值修饰器。
## [br]
## @api public
## [br]
## @param p_value: 修饰器数值。
## [br]
## @param p_attribute_id: 修饰器作用的属性标识。
## [br]
## @param p_source_id: 修饰器来源标识。
## [br]
## @return: 新修饰器。
static func create_base_add(
	p_value: float,
	p_attribute_id: StringName = &"",
	p_source_id: StringName = &""
) -> GFModifier:
	return GFModifier.new(Type.BASE_ADD, p_value, p_attribute_id, p_source_id)


## 静态工厂方法：创建百分比加值修饰器。
## [br]
## @api public
## [br]
## @param p_value: 修饰器数值。
## [br]
## @param p_attribute_id: 修饰器作用的属性标识。
## [br]
## @param p_source_id: 修饰器来源标识。
## [br]
## @return: 新修饰器。
static func create_percent_add(
	p_value: float,
	p_attribute_id: StringName = &"",
	p_source_id: StringName = &""
) -> GFModifier:
	return GFModifier.new(Type.PERCENT_ADD, p_value, p_attribute_id, p_source_id)


## 静态工厂方法：创建最终加值修饰器。
## [br]
## @api public
## [br]
## @param p_value: 修饰器数值。
## [br]
## @param p_attribute_id: 修饰器作用的属性标识。
## [br]
## @param p_source_id: 修饰器来源标识。
## [br]
## @return: 新修饰器。
static func create_final_add(
	p_value: float,
	p_attribute_id: StringName = &"",
	p_source_id: StringName = &""
) -> GFModifier:
	return GFModifier.new(Type.FINAL_ADD, p_value, p_attribute_id, p_source_id)


## 创建修饰器副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 新修饰器。
func duplicate_modifier() -> GFModifier:
	return GFModifier.new(type, value, attribute_id, source_id)


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 修饰器字典。
## [br]
## @schema return: Dictionary with type, value, attribute_id, and source_id.
func to_dictionary() -> Dictionary:
	return {
		"type": type,
		"value": value,
		"attribute_id": attribute_id,
		"source_id": source_id,
	}


## 从字典应用修饰器字段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param data: 修饰器字典。
## [br]
## @schema data: Dictionary with optional type, value, attribute_id, and source_id.
func apply_dictionary(data: Dictionary) -> void:
	type = _normalize_type(GFVariantData.get_option_value(data, "type", type))
	value = GFVariantData.get_option_float(data, "value", value)
	attribute_id = GFVariantData.get_option_string_name(data, "attribute_id", attribute_id)
	source_id = GFVariantData.get_option_string_name(data, "source_id", source_id)


## 从字典创建修饰器。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param data: 修饰器字典。
## [br]
## @return 新修饰器。
## [br]
## @schema data: Dictionary with optional type, value, attribute_id, and source_id.
static func from_dictionary(data: Dictionary) -> GFModifier:
	var modifier: GFModifier = GFModifier.new()
	modifier.apply_dictionary(data)
	return modifier


# --- 私有/辅助方法 ---

static func _normalize_type(raw_value: Variant) -> Type:
	if raw_value is int:
		var type_value: int = raw_value
		return _int_to_type(type_value)
	match GFVariantData.to_text(raw_value).strip_edges().to_lower():
		"percent_add", "percent":
			return Type.PERCENT_ADD
		"final_add", "final":
			return Type.FINAL_ADD
		_:
			return Type.BASE_ADD


static func _int_to_type(type_index: int) -> Type:
	match clampi(type_index, Type.BASE_ADD, Type.FINAL_ADD):
		Type.PERCENT_ADD:
			return Type.PERCENT_ADD
		Type.FINAL_ADD:
			return Type.FINAL_ADD
		_:
			return Type.BASE_ADD
