@tool

## GFEditorToolOption: 编辑器工具选项声明。
##
## 用通用字段描述工具面板需要的一个选项，不绑定具体 UI 控件或资源类型。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorToolOption
extends Resource


# --- 枚举 ---

## 编辑器工具选项的通用值类型。
## [br]
## @api public
enum ValueType {
	## 不做类型约束。
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
	## Color。
	COLOR,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## NodePath。
	NODE_PATH,
	## 从 choices 中选择。
	OPTION,
}


# --- 常量 ---

## 将任意 Variant 转为选项声明所需基础类型的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 导出变量 ---

## 选项稳定标识。
## [br]
## @api public
@export var option_id: StringName = &""

## 选项显示名称。
## [br]
## @api public
@export var label: String = ""

## 选项提示文本。
## [br]
## @api public
@export_multiline var tooltip: String = ""

## 选项值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.ANY

## 默认值。
## [br]
## @api public
## [br]
## @schema default_value: Variant default value duplicated when needed.
@export var default_value: Variant = null

## 数值最小值。
## [br]
## @api public
@export var min_value: float = 0.0

## 数值最大值。
## [br]
## @api public
@export var max_value: float = 1.0

## 数值步长。
## [br]
## @api public
@export var step: float = 0.01

## 可选项列表。`value_type` 为 OPTION 时用于校验。
## [br]
## @api public
## [br]
## @schema choices: Array of allowed values for OPTION value_type.
@export var choices: Array = []

## 可选元数据，供工具 UI、持久化或项目层扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary for caller-defined option metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定选项标识。
## [br]
## @api public
## [br]
## @return 选项标识。
func get_option_id() -> StringName:
	return option_id


## 检查选项声明是否有效。
## [br]
## @api public
## [br]
## @return 有效返回 true。
func is_valid_definition() -> bool:
	return option_id != &""


## 规范化输入值。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @schema value: Variant raw option value.
## [br]
## @return 规范化后的值。
## [br]
## @schema return: Variant normalized option value.
func normalize_value(value: Variant) -> Variant:
	if value == null:
		return _duplicate_variant(default_value)

	match value_type:
		ValueType.BOOL:
			return _GF_VARIANT_ACCESS_SCRIPT.to_bool(value)
		ValueType.INT:
			return clampi(_GF_VARIANT_ACCESS_SCRIPT.to_int(value), roundi(min_value), roundi(max_value))
		ValueType.FLOAT:
			return clampf(_GF_VARIANT_ACCESS_SCRIPT.to_float(value), min_value, max_value)
		ValueType.STRING:
			return _GF_VARIANT_ACCESS_SCRIPT.to_text(value)
		ValueType.STRING_NAME:
			return _GF_VARIANT_ACCESS_SCRIPT.to_string_name(value)
		ValueType.COLOR:
			return value if value is Color else default_value
		ValueType.VECTOR2:
			return value if value is Vector2 else default_value
		ValueType.VECTOR2I:
			return value if value is Vector2i else default_value
		ValueType.NODE_PATH:
			return value if value is NodePath else NodePath(_GF_VARIANT_ACCESS_SCRIPT.to_text(value))
		ValueType.OPTION:
			return value if choices.is_empty() or choices.has(value) else _duplicate_variant(default_value)
		_:
			return _duplicate_variant(value)


## 检查值是否符合选项声明。
## [br]
## @api public
## [br]
## @param value: 待检查值。
## [br]
## @schema value: Variant option value to validate.
## [br]
## @return 符合声明时返回 true。
func is_value_valid(value: Variant) -> bool:
	if value == null:
		return true
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
		ValueType.COLOR:
			return value is Color
		ValueType.VECTOR2:
			return value is Vector2
		ValueType.VECTOR2I:
			return value is Vector2i
		ValueType.NODE_PATH:
			return value is NodePath
		ValueType.OPTION:
			return choices.is_empty() or choices.has(value)
		_:
			return true


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新选项声明。
func duplicate_option() -> GFEditorToolOption:
	var option: GFEditorToolOption = GFEditorToolOption.new()
	option.option_id = option_id
	option.label = label
	option.tooltip = tooltip
	option.value_type = value_type
	option.default_value = _duplicate_variant(default_value)
	option.min_value = min_value
	option.max_value = max_value
	option.step = step
	option.choices = choices.duplicate(true)
	option.metadata = metadata.duplicate(true)
	return option


## 导出选项声明摘要。
## [br]
## @api public
## [br]
## @return 选项声明字典。
## [br]
## @schema return: Dictionary containing option_id, label, tooltip, value_type, default_value, numeric constraints, choices, and metadata.
func describe() -> Dictionary:
	return {
		"option_id": option_id,
		"label": label,
		"tooltip": tooltip,
		"value_type": value_type,
		"default_value": _duplicate_variant(default_value),
		"min_value": min_value,
		"max_value": max_value,
		"step": step,
		"choices": choices.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 深复制 Dictionary 和 Array 默认值；其余 Variant（包括对象值）原样返回。
## [br]
## @api private
func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	if value is Array:
		var array: Array = value
		return array.duplicate(true)
	return value
