@tool

## GFUIPropertyMotion: 在绑定对象上插值一个属性，支持按父级布局大小计算的位移和相对初始姿态。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFUIPropertyMotion
extends GFUIMotionEffect


# --- 导出变量 ---

## Godot 索引属性路径，例如 position 或 modulate:a。
## [br]
## @api public
## [br]
## @since unreleased
@export var property: NodePath = ^"modulate:a"

## 局部进度为零时的值。
## [br]
## @api public
## [br]
## @schema start_value: Variant，可为 float、int、Vector2、Vector3、Rect2 或 Color。
## [br]
## @since unreleased
@export var start_value: Variant = 0.0

## 局部进度为一时的值。
## [br]
## @api public
## [br]
## @schema end_value: Variant，必须与起始值相容。
## [br]
## @since unreleased
@export var end_value: Variant = 1.0

## 把端点解释为相对于开始时真实属性的增量。
## [br]
## @api public
## [br]
## @since unreleased
@export var relative: bool = false

## 将 Vector2 起止值按 Control 所在父区域的当前尺寸缩放。
## [br]
## @api public
## [br]
## @since unreleased
@export var in_parent_units: bool = false


# --- 公共方法 ---

## 声明本次会话独占的属性路径。
## [br]
## @api public
## [br]
## @return: 用于冲突检查的单一属性。
## [br]
## @since unreleased
func written_properties() -> Array[NodePath]:
	return [property]


## 检查属性存在、类型相容和布局坐标要求。
## [br]
## @api public
## [br]
## @param target: 目标对象。
## [br]
## @param _inputs: 保留给项目输入。
## [br]
## @schema _inputs: Dictionary，属性动作不需要额外输入。
## [br]
## @return: 失败原因或空串。
## [br]
## @since unreleased
func binding_error(target: Object, _inputs: Dictionary) -> String:
	if (
		property.is_empty()
		or property.is_absolute()
		or property.get_name_count() != 1
	):
		return "无效属性路径 %s" % property
	if not property.get_name(0) in target:
		return "目标缺少属性 %s" % property
	var base: Variant = target.get_indexed(property)
	var type: int = typeof(base)
	if type not in [
		TYPE_FLOAT,
		TYPE_INT,
		TYPE_VECTOR2,
		TYPE_VECTOR3,
		TYPE_RECT2,
		TYPE_COLOR,
	]:
		return "无法插值属性 %s" % property
	for endpoint: Variant in [start_value, end_value]:
		if (
			typeof(endpoint) != type
			and not (
				type in [TYPE_FLOAT, TYPE_INT]
				and typeof(endpoint) in [TYPE_FLOAT, TYPE_INT]
			)
		):
			return (
				"属性 %s 端点类型与 %s 不符"
				% [property, type_string(type)]
			)
	if (
		in_parent_units
		and (
			type != TYPE_VECTOR2
			or not target is Control
		)
	):
		return "父区域单位需要 Control 与 Vector2 属性"
	if relative and type == TYPE_RECT2:
		return "Rect2 仅支持绝对端点"
	return ""


## 冻结端点及基线，窗口改变时重新读取父区域大小。
## [br]
## @api public
## [br]
## @param target: 已确认兼容的对象。
## [br]
## @param _inputs: 保留给项目输入。
## [br]
## @schema _inputs: Dictionary，属性动作不读取此映射。
## [br]
## @return: 每次播放独立的属性写入与回滚操作。
## [br]
## @since unreleased
func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
	var path: NodePath = property
	var baseline: Variant = target.get_indexed(path)
	var first: Variant = start_value
	var last: Variant = end_value
	if typeof(baseline) in [TYPE_INT, TYPE_FLOAT]:
		var numeric_start: float = first
		var numeric_end: float = last
		first = numeric_start
		last = numeric_end
	var use_area: bool = in_parent_units
	var offset: bool = relative
	var sample: Callable = func(weight: float) -> void:
		var value: Variant
		if typeof(baseline) == TYPE_RECT2:
			var first_rect: Rect2 = first
			var last_rect: Rect2 = last
			value = Rect2(
				first_rect.position.lerp(last_rect.position, weight),
				first_rect.size.lerp(last_rect.size, weight)
			)
		else:
			value = lerp(
				first,
				last,
				weight
			)
		if use_area:
			var displacement: Vector2 = value
			value = displacement * (target as Control).get_parent_area_size()
		if offset:
			value = baseline + value
		if typeof(baseline) == TYPE_INT:
			var numeric: float = value
			value = roundi(numeric)
		target.set_indexed(path, value)
	var release: Callable = func(reason: int) -> void:
		if reason == GFUIMotionBinding.EndReason.CANCELLED and is_instance_valid(target):
			target.set_indexed(path, baseline)
	return GFUIMotionBinding.new(sample, release)
