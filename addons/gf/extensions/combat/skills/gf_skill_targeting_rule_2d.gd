## GFSkillTargetingRule2D: 2D 技能索敌规则资源。
##
## 使用纯数据结构描述 2D 目标筛选时的空间范围、
## 朝向约束、排序规则与标签过滤条件。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFSkillTargetingRule2D
extends Resource


# --- 枚举 ---

## 索敌形状。
## [br]
## @api public
## [br]
## @since 8.0.0
enum Shape {
	## 轴对齐矩形范围。
	RECTANGLE,
	## 圆形范围。
	CIRCLE,
	## 扇形范围。
	SECTOR,
	## 单体目标。
	SINGLE,
}

## 排序规则。
## [br]
## @api public
## [br]
## @since 8.0.0
enum SortRule {
	## 距离最近优先。
	DISTANCE_CLOSEST,
	## 距离最远优先。
	DISTANCE_FURTHEST,
	## 属性值最低优先。
	ATTRIBUTE_LOWEST,
	## 属性值最高优先。
	ATTRIBUTE_HIGHEST,
	## 随机顺序。
	RANDOM,
}


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

@export_group("空间设置")

## 索敌形状。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var shape: Shape = Shape.CIRCLE

## 圆形、扇形与单体规则使用的最大半径。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var radius: float = 100.0

## 矩形范围尺寸，使用轴对齐包围盒判断。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var rectangle_size: Vector2 = Vector2(200.0, 200.0)

## 最多选中的目标数量。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_count: int = 1

@export_group("朝向设置")

## 扇形朝向；为零向量时回退到 `Vector2.RIGHT`。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var forward_direction: Vector2 = Vector2.RIGHT

## 扇形夹角，单位为角度。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(0.0, 360.0, 1.0) var sector_angle_degrees: float = 90.0

@export_group("排序规则")

## 目标排序逻辑。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var sort_rule: SortRule = SortRule.DISTANCE_CLOSEST

## 按属性排序时使用的属性名。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var sort_attribute_name: StringName = &"HP"

## RANDOM 排序使用的确定性种子。相同候选集合、相同实例顺序与相同种子会得到相同顺序。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var random_seed: int = 0

@export_group("标签过滤")

## 目标必须拥有的标签列表。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var require_tags: Array[StringName] = []

## 目标禁止拥有的标签列表。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var ignore_tags: Array[StringName] = []


# --- 公共方法 ---

## 检查规则是否满足 2D 索敌运行时契约。
## [br]
## @api public
## [br]
## @return 所有枚举、范围与空间数值均合法时返回 true。
## [br]
## @since 8.0.0
func is_configuration_valid() -> bool:
	if shape < Shape.RECTANGLE or shape > Shape.SINGLE:
		return false
	if sort_rule < SortRule.DISTANCE_CLOSEST or sort_rule > SortRule.RANDOM:
		return false
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(radius) or radius < 0.0:
		return false
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(rectangle_size):
		return false
	if rectangle_size.x < 0.0 or rectangle_size.y < 0.0:
		return false
	if max_count < 0:
		return false
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(forward_direction):
		return false
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(sector_angle_degrees):
		return false
	return sector_angle_degrees >= 0.0 and sector_angle_degrees <= 360.0
