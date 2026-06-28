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


## 设置数值范围并返回自身。
## [br]
## @api public
## [br]
## @param p_min_value: 最小值。
## [br]
## @param p_max_value: 最大值。
## [br]
## @param p_step: 建议步长。
## [br]
## @return: 当前属性声明。
func with_range(p_min_value: float, p_max_value: float, p_step: float = 1.0) -> GFRuntimeTunableProperty:
	has_min_value = true
	has_max_value = true
	min_value = p_min_value
	max_value = p_max_value
	step = maxf(p_step, 0.0)
	return self


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

	var normalized_value: Variant = normalize_value(value)
	if validator.is_valid() and not GFVariantData.to_bool(validator.call(target, self, normalized_value)):
		return false
	if setter.is_valid():
		setter.call(target, self, normalized_value)
		return true
	if property_name.is_empty():
		return false
	var result: Dictionary = _OBJECT_PROPERTY_TOOLS.write_property(target, property_name, normalized_value)
	return GFVariantData.get_option_bool(result, "ok", false)


## 根据 schema 归一化写入值。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return: 归一化后的值。
## [br]
## @schema value: Variant，输入值。
## [br]
## @schema return: Variant，归一化后的值，类型由 value_kind 决定。
func normalize_value(value: Variant) -> Variant:
	var normalized: Variant = _normalize_value_by_kind(value)
	if not options.is_empty():
		var normalized_options: Array = _get_normalized_options()
		if not normalized_options.has(normalized) and not normalized_options.is_empty():
			return normalized_options[0]
	return normalized


## 生成可序列化 schema 快照。
## [br]
## @api public
## [br]
## @return: schema 字典。
## [br]
## @schema return: Dictionary，包含 property_id、label、group、property_name、value_kind、read_only、visible、has_min_value、min_value、has_max_value、max_value、step、options 和 metadata 字段。
func to_schema() -> Dictionary:
	return {
		"property_id": property_id,
		"label": label if not label.is_empty() else String(property_id),
		"group": group,
		"property_name": String(property_name),
		"value_kind": value_kind,
		"read_only": read_only,
		"visible": visible,
		"has_min_value": has_min_value,
		"min_value": min_value,
		"has_max_value": has_max_value,
		"max_value": max_value,
		"step": step,
		"options": options.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _normalize_value_by_kind(value: Variant) -> Variant:
	match value_kind:
		ValueKind.BOOL:
			return GFVariantData.to_bool(value)
		ValueKind.INT:
			return _normalize_int(value)
		ValueKind.FLOAT:
			return _normalize_float(value)
		ValueKind.STRING:
			return GFVariantData.to_text(value)
		ValueKind.STRING_NAME:
			return StringName(GFVariantData.to_text(value))
		ValueKind.VECTOR2:
			return value if value is Vector2 else Vector2.ZERO
		ValueKind.VECTOR3:
			return value if value is Vector3 else Vector3.ZERO
		ValueKind.COLOR:
			return value if value is Color else Color.WHITE
		_:
			return value


func _get_normalized_options() -> Array:
	var result: Array = []
	for option_value: Variant in options:
		result.append(_normalize_value_by_kind(option_value))
	return result


func _normalize_int(value: Variant) -> int:
	var number: int = GFVariantData.to_int(value)
	if has_min_value:
		number = maxi(number, int(min_value))
	if has_max_value:
		number = mini(number, int(max_value))
	return number


func _normalize_float(value: Variant) -> float:
	var number: float = GFVariantData.to_float(value)
	if has_min_value:
		number = maxf(number, min_value)
	if has_max_value:
		number = minf(number, max_value)
	return number
