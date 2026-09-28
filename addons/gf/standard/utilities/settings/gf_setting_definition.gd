## GFSettingDefinition: 单个运行时设置项的声明。
##
## 只描述稳定键、默认值、值类型和持久化策略，不绑定具体 UI 或业务含义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFSettingDefinition
extends Resource


# --- 枚举 ---

## 设置值类型，用于运行时输入钳制和持久化恢复。
## [br]
## @api public
enum ValueType {
	## 不做类型转换。
	ANY,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数。
	FLOAT,
	## 字符串。
	STRING,
	## StringName。
	STRING_NAME,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## Color。
	COLOR,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
}


# --- 导出变量 ---

## 设置项稳定键。建议使用 `category/name` 形式。
## [br]
## @api public
@export var key: StringName = &""

## 默认值。
## [br]
## @api public
## [br]
## @schema default_value: Variant setting value accepted by value_type.
@export var default_value: Variant = null

## 值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.ANY

## 是否参与持久化保存。
## [br]
## @api public
@export var persistent: bool = true

## 可选元数据，供设置界面分组、排序或展示使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary with optional UI grouping, ordering, label, and project-defined metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定设置键。
## [br]
## @api public
## [br]
## @return 设置键；未显式设置时尝试使用资源路径。
func get_setting_key() -> StringName:
	if key != &"":
		return key
	if not resource_path.is_empty():
		return StringName(resource_path)
	return &""


## 将输入值转换为当前定义要求的类型。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @schema value: Variant setting value accepted by value_type.
## [br]
## @return 转换后的值。
## [br]
## @schema return: Variant coerced to the configured value_type when possible.
func coerce_value(value: Variant) -> Variant:
	match value_type:
		ValueType.BOOL:
			return GFVariantData.to_bool(value)
		ValueType.INT:
			return GFVariantData.to_int(value)
		ValueType.FLOAT:
			return GFVariantData.to_float(value)
		ValueType.STRING:
			return str(value)
		ValueType.STRING_NAME:
			return StringName(str(value))
		ValueType.VECTOR2:
			return _coerce_vector2(value)
		ValueType.VECTOR2I:
			return _coerce_vector2i(value)
		ValueType.COLOR:
			return _coerce_color(value)
		ValueType.DICTIONARY:
			return GFVariantData.duplicate_variant(value) if value is Dictionary else {}
		ValueType.ARRAY:
			return GFVariantData.duplicate_variant(value) if value is Array else []
		_:
			return value


## 检查值是否符合声明类型。
## [br]
## @api public
## [br]
## @param value: 待检查值。
## [br]
## @schema value: Variant setting value to validate against value_type.
## [br]
## @return 符合时返回 true。
func is_value_valid(value: Variant) -> bool:
	match value_type:
		ValueType.ANY:
			return true
		ValueType.BOOL:
			return typeof(value) == TYPE_BOOL
		ValueType.INT:
			return typeof(value) == TYPE_INT
		ValueType.FLOAT:
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		ValueType.STRING:
			return typeof(value) == TYPE_STRING
		ValueType.STRING_NAME:
			return typeof(value) == TYPE_STRING_NAME
		ValueType.VECTOR2:
			return value is Vector2
		ValueType.VECTOR2I:
			return value is Vector2i
		ValueType.COLOR:
			return value is Color
		ValueType.DICTIONARY:
			return value is Dictionary
		ValueType.ARRAY:
			return value is Array
		_:
			return true


## 创建同内容拷贝，避免运行时修改污染共享资源。
## [br]
## @api public
## [br]
## @return 新定义。
func duplicate_definition() -> GFSettingDefinition:
	var definition: GFSettingDefinition = GFSettingDefinition.new()
	definition.key = key
	definition.default_value = GFVariantData.duplicate_collection(default_value)
	definition.value_type = value_type
	definition.persistent = persistent
	definition.metadata = metadata.duplicate(true)
	return definition


# --- 私有/辅助方法 ---

## 将 Variant、Vector2i 或带 x/y 字段的字典转换为 Vector2。
## [br]
## @api private
## [br]
func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		var vector2: Vector2 = value
		return vector2
	if value is Vector2i:
		var vector2i: Vector2i = value
		return Vector2(vector2i.x, vector2i.y)
	if value is Dictionary:
		var data: Dictionary = value
		return Vector2(
			GFVariantData.get_option_float(data, "x", 0.0),
			GFVariantData.get_option_float(data, "y", 0.0)
		)
	return Vector2.ZERO


## 将 Variant、Vector2 或带 x/y 字段的字典转换为 Vector2i。
## [br]
## @api private
## [br]
func _coerce_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		var vector2i: Vector2i = value
		return vector2i
	if value is Vector2:
		var vector2: Vector2 = value
		return Vector2i(roundi(vector2.x), roundi(vector2.y))
	if value is Dictionary:
		var data: Dictionary = value
		return Vector2i(
			GFVariantData.get_option_int(data, "x", 0),
			GFVariantData.get_option_int(data, "y", 0)
		)
	return Vector2i.ZERO


## 将 Variant、带 r/g/b/a 字段的字典或颜色文本转换为 Color。
## [br]
## @api private
## [br]
func _coerce_color(value: Variant) -> Color:
	if value is Color:
		var color: Color = value
		return color
	if value is Dictionary:
		var data: Dictionary = value
		return Color(
			GFVariantData.get_option_float(data, "r", 1.0),
			GFVariantData.get_option_float(data, "g", 1.0),
			GFVariantData.get_option_float(data, "b", 1.0),
			GFVariantData.get_option_float(data, "a", 1.0)
		)
	if typeof(value) == TYPE_STRING:
		return Color(GFVariantData.to_text(value))
	return Color.WHITE
