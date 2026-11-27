@tool

## GFUILayoutMotion: 在项目提供的两份实测矩形之间移动和缩放表现节点，适用于共享元素及列表重排。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFUILayoutMotion
extends GFUIMotionEffect


# --- 导出变量 ---

## 起始布局表的具名输入。
## [br]
## @api public
## [br]
## @since unreleased
@export var from_layout: StringName = &"from_rects"

## 目标布局表的具名输入。
## [br]
## @api public
## [br]
## @since unreleased
@export var to_layout: StringName = &"to_rects"


# --- 公共方法 ---

## 布局表以实际节点为键，矩形与表现节点使用同一父坐标系。
## [br]
## @api public
## [br]
## @return: 两份布局表的类型。
## [br]
## @schema return: Dictionary，输入名映射到 TYPE_DICTIONARY。
## [br]
## @since unreleased
func input_types() -> Dictionary:
	return { from_layout: TYPE_DICTIONARY, to_layout: TYPE_DICTIONARY }


## 占有布局表现节点的矩形。
## [br]
## @api public
## [br]
## @return: 位置和尺寸。
## [br]
## @since unreleased
func written_properties() -> Array[NodePath]:
	return [^"position", ^"size"]


## 确认两次布局均包含同一目标。
## [br]
## @api public
## [br]
## @param target: 位于同一父坐标空间的表现节点。
## [br]
## @param inputs: 捕获的前后布局。
## [br]
## @schema inputs: Dictionary，两个具名布局表分别从 Object 映射到 Rect2。
## [br]
## @return: 错误或空串。
## [br]
## @since unreleased
func binding_error(target: Object, inputs: Dictionary) -> String:
	if not target is Control:
		return "布局插值需要 Control"
	for key: StringName in [from_layout, to_layout]:
		var rects: Dictionary = inputs[key]
		if not rects.get(target) is Rect2:
			return "布局 %s 缺少该目标的 Rect2" % key
	return ""


## 取得两个矩形后直接驱动专用表现节点。
## [br]
## @api public
## [br]
## @param target: 目标控件。
## [br]
## @param inputs: 起止布局。
## [br]
## @schema inputs: Dictionary，包含 from_layout 与 to_layout 所指的布局表。
## [br]
## @return: 基于实际布局的可定位操作。
## [br]
## @since unreleased
func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:
	var node: Control = target as Control
	var first: Rect2 = inputs[from_layout][target]
	var last: Rect2 = inputs[to_layout][target]
	var baseline: Rect2 = node.get_rect()
	var sample: Callable = func(weight: float) -> void:
		node.position = first.position.lerp(last.position, weight)
		node.size = first.size.lerp(last.size, weight)
	var release: Callable = func(reason: int) -> void:
		if reason == GFUIMotionBinding.EndReason.CANCELLED and is_instance_valid(node):
			node.position = baseline.position
			node.size = baseline.size
	return GFUIMotionBinding.new(sample, release)
