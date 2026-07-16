## GFRuntimeTunableProperty: 运行时可调属性声明。
##
## 用显式 schema 描述一个目标对象上允许被运行时工具读取或写入的属性。
## 它不自动扫描业务对象，也不决定具体调参界面。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFRuntimeTunableProperty
extends Resource


# --- 枚举 ---

## 运行时值类型约束。
## [br]
## @api public
enum ValueKind {
	## 不转换类型。
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
	## Vector3。
	VECTOR3,
	## Color。
	COLOR,
}


# --- 常量 ---

const _OBJECT_PROPERTY_TOOLS = preload("res://addons/gf/kernel/core/gf_object_property_tools.gd")


# --- 导出变量 ---

## 属性 ID，在同一目标内必须唯一。
## [br]
## @api public
@export var property_id: StringName = &""

## 展示标签；为空时使用 property_id。
## [br]
## @api public
@export var label: String = ""

## 展示分组。
## [br]
## @api public
@export var group: String = "Runtime"

## 目标对象上的属性路径。使用 getter/setter 回调时可为空。
## [br]
## @api public
@export var property_name: NodePath = NodePath("")

## 值类型约束。
## [br]
## @api public
@export var value_kind: ValueKind = ValueKind.ANY

## 是否只读。
## [br]
## @api public
@export var read_only: bool = false

## 是否默认出现在快照中。
## [br]
## @api public
@export var visible: bool = true

## 是否启用最小值限制，仅对 int/float 生效。
## [br]
## @api public
@export var has_min_value: bool = false

## 最小值。
## [br]
## @api public
@export var min_value: float = 0.0

## 是否启用最大值限制，仅对 int/float 生效。
## [br]
## @api public
@export var has_max_value: bool = false

## 最大值。
## [br]
## @api public
@export var max_value: float = 0.0

## 建议步长，仅供 UI 使用。
## [br]
## @api public
@export var step: float = 1.0

## 可选值列表。非空时写入值必须归一到列表内。
## [br]
## @api public
## [br]
## @schema options: Array，保存允许写入的候选值。
@export var options: Array = []

## 自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义属性元数据。
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 可选读取回调，签名为 `func(target: Object, property: GFRuntimeTunableProperty) -> Variant`。
## [br]
## @api public
var getter: Callable

## 可选写入回调，签名为 `func(target: Object, property: GFRuntimeTunableProperty, value: Variant) -> void`。
## [br]
## @api public
var setter: Callable

## 可选校验回调，签名为 `func(target: Object, property: GFRuntimeTunableProperty, value: Variant) -> bool`。
## [br]
## @api public
var validator: Callable


# --- Godot 生命周期方法 ---

func _init(
	p_property_id: StringName = &"",
	p_property_name: NodePath = NodePath(""),
	p_value_kind: ValueKind = ValueKind.ANY
) -> void:
	property_id = p_property_id
	property_name = p_property_name
	value_kind = p_value_kind


# --- 公共方法 ---

## 设置基础字段并返回自身，便于代码构造 schema。
## [br]
## @api public
## [br]
## @param p_property_id: 属性 ID。
## [br]
## @param p_property_name: 目标属性路径。
## [br]
## @param p_value_kind: 值类型约束。
## [br]
## @return: 当前属性声明。
func setup(
	p_property_id: StringName,
	p_property_name: NodePath = NodePath(""),
	p_value_kind: ValueKind = ValueKind.ANY
) -> GFRuntimeTunableProperty:
	property_id = p_property_id
	property_name = p_property_name
	value_kind = p_value_kind
	return self


## 配置数值范围。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_min_value: 最小值。
## [br]
## @param p_max_value: 最大值。
## [br]
## @param p_step: 建议步长。
## [br]
## @return: schema 有效并完成配置时返回 true；失败时保持原配置。
func configure_range(p_min_value: float, p_max_value: float, p_step: float = 1.0) -> bool:
	if (
		not is_finite(p_min_value)
		or not is_finite(p_max_value)
		or not is_finite(p_step)
		or p_min_value > p_max_value
		or p_step < 0.0
	):
		return false
	has_min_value = true
	has_max_value = true
	min_value = p_min_value
	max_value = p_max_value
	step = p_step
	return true


## 设置可选值列表并返回自身。
## [br]
## @api public
## [br]
## @param p_options: 可选值列表。
## [br]
## @return: 当前属性声明。
## [br]
## @schema p_options: Array，保存允许写入的候选值。
func with_options(p_options: Array) -> GFRuntimeTunableProperty:
	options = p_options.duplicate(true)
	return self


## 读取目标对象当前值。
## [br]
## @api public
## [br]
## @param target: 目标对象。
## [br]
## @return: 当前值；无法读取时返回 null。
## [br]
## @schema return: Variant，类型由 value_kind 和实际目标属性决定。
func read_value(target: Object) -> Variant:
	if getter.is_valid():
		return getter.call(target, self)
	if not is_instance_valid(target) or property_name.is_empty():
		return null
	return _OBJECT_PROPERTY_TOOLS.read_property(target, property_name)


## 写入目标对象。
## [br]
## @api public
## [br]
## @param target: 目标对象。
## [br]
## @param value: 请求写入的值。
## [br]
## @return: 写入成功返回 true。
## [br]
## @schema value: Variant，请求写入的原始值，会按 value_kind 和范围配置归一化。
func write_value(target: Object, value: Variant) -> bool:
	if read_only or not is_instance_valid(target):
		return false
	var normalization: Dictionary = try_normalize_value(value)
	if not GFVariantData.get_option_bool(normalization, "ok"):
		return false

	var normalized_value: Variant = GFVariantData.get_option_value(normalization, "value")
	if validator.is_valid() and not GFVariantData.to_bool(validator.call(target, self, normalized_value)):
		return false
	if setter.is_valid():
		setter.call(target, self, normalized_value)
		return true
	if property_name.is_empty():
		return false
	var result: Dictionary = _OBJECT_PROPERTY_TOOLS.write_property(target, property_name, normalized_value)
	return GFVariantData.get_option_bool(result, "ok", false)


## 尝试根据 schema 解析并归一化写入值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 输入值。
## [br]
## @return: 解析报告。
## [br]
## @schema value: Variant，输入值。
## [br]
## @schema return: Dictionary，包含 ok、value 和 error；失败时 value 为 null。
func try_normalize_value(value: Variant) -> Dictionary:
	var schema_error: String = _get_numeric_schema_error()
	if not schema_error.is_empty():
		return _make_normalization_report(false, null, schema_error)
	var kind_report: Dictionary = _try_normalize_value_by_kind(value)
	if not GFVariantData.get_option_bool(kind_report, "ok"):
		return kind_report
	var normalized: Variant = GFVariantData.get_option_value(kind_report, "value")
	if not options.is_empty():
		var normalized_options: Array = _get_normalized_options()
		if normalized_options.is_empty():
			return _make_normalization_report(false, null, "option_schema_invalid")
		if not normalized_options.has(normalized):
			return _make_normalization_report(false, null, "value_not_allowed")
	return _make_normalization_report(true, normalized, "")


## 生成可序列化 schema 快照。
## [br]
## @api public
## [br]
## @return: schema 字典。
## [br]
## @schema return: Dictionary，包含 property_id、label、group、property_name、value_kind、read_only、visible、has_min_value、min_value、has_max_value、max_value、step、options 和 metadata 字段。
func to_schema() -> Dictionary:
	var schema_error: String = _get_numeric_schema_error()
	return {
		"property_id": property_id,
		"label": label if not label.is_empty() else String(property_id),
		"group": group,
		"property_name": String(property_name),
		"value_kind": value_kind,
		"read_only": read_only,
		"visible": visible,
		"has_min_value": has_min_value,
		"min_value": min_value if is_finite(min_value) else 0.0,
		"has_max_value": has_max_value,
		"max_value": max_value if is_finite(max_value) else 0.0,
		"step": step if is_finite(step) and step >= 0.0 else 0.0,
		"options": options.duplicate(true),
		"metadata": metadata.duplicate(true),
		"schema_valid": schema_error.is_empty(),
		"schema_error": schema_error,
	}


# --- 私有/辅助方法 ---

func _try_normalize_value_by_kind(value: Variant) -> Dictionary:
	match value_kind:
		ValueKind.BOOL:
			if value is bool:
				return _make_normalization_report(true, value, "")
		ValueKind.INT:
			return _try_normalize_int(value)
		ValueKind.FLOAT:
			return _try_normalize_float(value)
		ValueKind.STRING:
			if value is String or value is StringName:
				return _make_normalization_report(true, GFVariantData.to_text(value), "")
		ValueKind.STRING_NAME:
			if value is String or value is StringName:
				return _make_normalization_report(true, StringName(GFVariantData.to_text(value)), "")
		ValueKind.VECTOR2:
			if value is Vector2:
				var vector_2_value: Vector2 = value
				if is_finite(vector_2_value.x) and is_finite(vector_2_value.y):
					return _make_normalization_report(true, vector_2_value, "")
		ValueKind.VECTOR3:
			if value is Vector3:
				var vector_3_value: Vector3 = value
				if is_finite(vector_3_value.x) and is_finite(vector_3_value.y) and is_finite(vector_3_value.z):
					return _make_normalization_report(true, vector_3_value, "")
		ValueKind.COLOR:
			if value is Color:
				var color_value: Color = value
				if is_finite(color_value.r) and is_finite(color_value.g) and is_finite(color_value.b) and is_finite(color_value.a):
					return _make_normalization_report(true, color_value, "")
		_:
			return _make_normalization_report(true, value, "")
	return _make_normalization_report(false, null, "value_type_mismatch")


func _get_normalized_options() -> Array:
	var result: Array = []
	for option_value: Variant in options:
		var option_report: Dictionary = _try_normalize_value_by_kind(option_value)
		if GFVariantData.get_option_bool(option_report, "ok"):
			result.append(GFVariantData.get_option_value(option_report, "value"))
	return result


func _try_normalize_int(value: Variant) -> Dictionary:
	var number: int = 0
	if value is int:
		number = value
	elif value is float:
		var float_value: float = value
		if not is_finite(float_value) or floor(float_value) != float_value:
			return _make_normalization_report(false, null, "integer_value_invalid")
		number = int(float_value)
	elif value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if not text.is_valid_int():
			return _make_normalization_report(false, null, "integer_value_invalid")
		number = text.to_int()
	else:
		return _make_normalization_report(false, null, "integer_value_invalid")
	if has_min_value:
		number = maxi(number, ceili(min_value))
	if has_max_value:
		number = mini(number, floori(max_value))
	return _make_normalization_report(true, number, "")


func _try_normalize_float(value: Variant) -> Dictionary:
	var number: float = 0.0
	if value is int:
		var int_value: int = value
		number = float(int_value)
	elif value is float:
		var float_value: float = value
		number = float_value
	elif value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if not text.is_valid_float():
			return _make_normalization_report(false, null, "float_value_invalid")
		number = text.to_float()
	else:
		return _make_normalization_report(false, null, "float_value_invalid")
	if not is_finite(number):
		return _make_normalization_report(false, null, "float_value_non_finite")
	if has_min_value:
		number = maxf(number, min_value)
	if has_max_value:
		number = minf(number, max_value)
	return _make_normalization_report(true, number, "")


func _get_numeric_schema_error() -> String:
	if value_kind != ValueKind.INT and value_kind != ValueKind.FLOAT:
		return ""
	if not is_finite(step) or step < 0.0:
		return "numeric_step_invalid"
	if has_min_value and not is_finite(min_value):
		return "numeric_min_non_finite"
	if has_max_value and not is_finite(max_value):
		return "numeric_max_non_finite"
	if has_min_value and has_max_value and min_value > max_value:
		return "numeric_range_inverted"
	if value_kind == ValueKind.INT and has_min_value and has_max_value and ceili(min_value) > floori(max_value):
		return "integer_range_empty"
	return ""


func _make_normalization_report(ok: bool, value: Variant, error: String) -> Dictionary:
	return {
		"ok": ok,
		"value": value,
		"error": error,
	}
