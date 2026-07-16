## GFSkillTargetingUtility2D: 2D 技能索敌处理工具。
##
## 提供统一的 2D 目标筛选流程：先做空间过滤，
## 再执行标签过滤、排序与数量截断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFSkillTargetingUtility2D
extends GFUtility


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 公共方法 ---

## 执行索敌 pipeline。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_center: 索敌中心点。
## [br]
## @param p_rule: 索敌规则资源。
## [br]
## @param p_available_entities: 候选实体池。
## [br]
## @return 最终筛选出的目标数组。
## [br]
## @schema p_available_entities: Array，元素为候选实体 Object；无效实例会被跳过。
func find_targets(p_center: Vector2, p_rule: GFSkillTargetingRule2D, p_available_entities: Array) -> Array[Object]:
	if (
		p_rule == null
		or not p_rule.is_configuration_valid()
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(p_center)
	):
		return []

	var targets: Array[Object] = []

	for entity: Object in p_available_entities:
		if not is_instance_valid(entity):
			continue

		if not _is_entity_in_shape(entity, p_center, p_rule):
			continue

		if not _check_tags(entity, p_rule):
			continue

		targets.append(entity)

	if targets.is_empty():
		return []

	_sort_targets(targets, p_center, p_rule)

	if p_rule.max_count > 0 and targets.size() > p_rule.max_count:
		targets = targets.slice(0, p_rule.max_count)

	return targets


# --- 私有/辅助方法 ---

func _is_entity_in_shape(p_entity: Object, p_center: Vector2, p_rule: GFSkillTargetingRule2D) -> bool:
	var position_value: Variant = _get_entity_position(p_entity)
	if not position_value is Vector2:
		return false
	var pos: Vector2 = position_value
	var offset: Vector2 = pos - p_center
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(offset):
		return false

	match p_rule.shape:
		GFSkillTargetingRule2D.Shape.RECTANGLE:
			var half_size: Vector2 = p_rule.rectangle_size * 0.5
			return absf(offset.x) <= half_size.x and absf(offset.y) <= half_size.y

		GFSkillTargetingRule2D.Shape.CIRCLE, GFSkillTargetingRule2D.Shape.SINGLE:
			return _is_within_radius(offset, p_rule.radius)

		GFSkillTargetingRule2D.Shape.SECTOR:
			if not _is_within_radius(offset, p_rule.radius):
				return false

			if offset == Vector2.ZERO:
				return true

			var forward: Vector2 = p_rule.forward_direction
			if forward == Vector2.ZERO:
				forward = Vector2.RIGHT

			var half_angle_radians: float = deg_to_rad(clampf(p_rule.sector_angle_degrees, 0.0, 360.0) * 0.5)
			if half_angle_radians >= PI:
				return true

			return absf(forward.normalized().angle_to(offset.normalized())) <= half_angle_radians

	return false


# 检查实体标签是否符合规则。
func _check_tags(p_entity: Object, p_rule: GFSkillTargetingRule2D) -> bool:
	if not p_entity.has_method(&"get_tag_component"):
		return p_rule.require_tags.is_empty()

	var tag_component: GFTagComponent = _get_tag_component_value(p_entity.call(&"get_tag_component"))
	if tag_component == null:
		return p_rule.require_tags.is_empty()

	for tag: StringName in p_rule.require_tags:
		if not tag_component.has_tag(tag):
			return false

	for tag: StringName in p_rule.ignore_tags:
		if tag_component.has_tag(tag):
			return false

	return true


# 对目标列表进行排序。
func _sort_targets(p_targets: Array[Object], p_center: Vector2, p_rule: GFSkillTargetingRule2D) -> void:
	match p_rule.sort_rule:
		GFSkillTargetingRule2D.SortRule.DISTANCE_CLOSEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return _get_distance_sort_value(p_center, a) < _get_distance_sort_value(p_center, b)
			)
		GFSkillTargetingRule2D.SortRule.DISTANCE_FURTHEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return _get_distance_sort_value(p_center, a) > _get_distance_sort_value(p_center, b)
			)
		GFSkillTargetingRule2D.SortRule.ATTRIBUTE_LOWEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return _get_entity_attribute_value(a, p_rule.sort_attribute_name) < _get_entity_attribute_value(b, p_rule.sort_attribute_name)
			)
		GFSkillTargetingRule2D.SortRule.ATTRIBUTE_HIGHEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return _get_entity_attribute_value(a, p_rule.sort_attribute_name) > _get_entity_attribute_value(b, p_rule.sort_attribute_name)
			)
		GFSkillTargetingRule2D.SortRule.RANDOM:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				var left_key: int = _get_random_sort_key(a, p_rule.random_seed)
				var right_key: int = _get_random_sort_key(b, p_rule.random_seed)
				if left_key != right_key:
					return left_key < right_key
				return a.get_instance_id() < b.get_instance_id()
			)


# 获取实体坐标位置。
func _get_entity_position(p_entity: Object) -> Variant:
	if p_entity is Node and not p_entity is Node2D:
		return null

	var position: Variant = GFObjectPropertyTools.read_property(p_entity, NodePath("global_position"))
	if position is Vector2:
		var position_2d: Vector2 = position
		if _GF_COMBAT_FINITE_MATH.is_finite_vector2(position_2d):
			return position_2d

	return null


func _get_entity_position_or_default(p_entity: Object, default_position: Vector2) -> Vector2:
	var position: Variant = _get_entity_position(p_entity)
	if position is Vector2:
		return position
	return default_position


func _get_distance_sort_value(center: Vector2, entity: Object) -> float:
	var offset: Vector2 = _get_entity_position_or_default(entity, center) - center
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(offset):
		return 1.0e300
	var distance_squared: float = offset.length_squared()
	return distance_squared if _GF_COMBAT_FINITE_MATH.is_finite_float(distance_squared) else 1.0e300


func _is_within_radius(offset: Vector2, radius: float) -> bool:
	if radius == 0.0:
		return offset == Vector2.ZERO
	if absf(offset.x) > radius or absf(offset.y) > radius:
		return false
	var normalized_offset: Vector2 = offset / radius
	return normalized_offset.length_squared() <= 1.0


# 获取实体属性值。
func _get_entity_attribute_value(p_entity: Object, p_attr_name: StringName) -> float:
	if p_entity.has_method(&"get_attribute"):
		var attribute: GFModifiedAttribute = _get_modified_attribute_value(p_entity.call(&"get_attribute", p_attr_name))
		if attribute != null:
			var attribute_value: float = attribute.current_value.get_value()
			return attribute_value if _GF_COMBAT_FINITE_MATH.is_finite_float(attribute_value) else 0.0

	var value: Variant = GFObjectPropertyTools.read_property(p_entity, NodePath(String(p_attr_name)))
	if value is float or value is int:
		var numeric_value: float = GFVariantData.to_float(value)
		return numeric_value if _GF_COMBAT_FINITE_MATH.is_finite_float(numeric_value) else 0.0

	return 0.0


func _get_random_sort_key(entity: Object, random_seed: int) -> int:
	if not is_instance_valid(entity):
		return 0
	return ("%d:%d" % [random_seed, entity.get_instance_id()]).hash()


func _get_tag_component_value(value: Variant) -> GFTagComponent:
	if value is GFTagComponent:
		var tag_component: GFTagComponent = value
		return tag_component
	return null


func _get_modified_attribute_value(value: Variant) -> GFModifiedAttribute:
	if value is GFModifiedAttribute:
		var attribute: GFModifiedAttribute = value
		return attribute
	return null
