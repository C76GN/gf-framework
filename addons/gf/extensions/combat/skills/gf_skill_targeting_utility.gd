## GFSkillTargetingUtility: 技能索敌处理工具。
##
## 提供统一的目标筛选流程：先做空间过滤，
## 再执行标签过滤、排序与数量截断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSkillTargetingUtility
extends GFUtility


# --- 公共方法 ---

## 执行索敌 pipeline。
## [br]
## @api public
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
func find_targets(p_center: Vector2, p_rule: GFSkillTargetingRule, p_available_entities: Array) -> Array[Object]:
	if p_rule == null:
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

func _is_entity_in_shape(p_entity: Object, p_center: Vector2, p_rule: GFSkillTargetingRule) -> bool:
	var pos: Vector2 = _get_entity_position(p_entity)
	var offset: Vector2 = pos - p_center

	match p_rule.shape:
		GFSkillTargetingRule.Shape.RECTANGLE:
			var half_size: Vector2 = p_rule.rectangle_size * 0.5
			return absf(offset.x) <= half_size.x and absf(offset.y) <= half_size.y

		GFSkillTargetingRule.Shape.CIRCLE, GFSkillTargetingRule.Shape.SINGLE:
			return offset.length_squared() <= p_rule.radius * p_rule.radius

		GFSkillTargetingRule.Shape.SECTOR:
			if offset.length_squared() > p_rule.radius * p_rule.radius:
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
func _check_tags(p_entity: Object, p_rule: GFSkillTargetingRule) -> bool:
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
func _sort_targets(p_targets: Array[Object], p_center: Vector2, p_rule: GFSkillTargetingRule) -> void:
	match p_rule.sort_rule:
		GFSkillTargetingRule.SortRule.DISTANCE_CLOSEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return p_center.distance_squared_to(_get_entity_position(a)) < p_center.distance_squared_to(_get_entity_position(b))
			)
		GFSkillTargetingRule.SortRule.DISTANCE_FURTHEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return p_center.distance_squared_to(_get_entity_position(a)) > p_center.distance_squared_to(_get_entity_position(b))
			)
		GFSkillTargetingRule.SortRule.ATTRIBUTE_LOWEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return _get_entity_attribute_value(a, p_rule.sort_attribute_name) < _get_entity_attribute_value(b, p_rule.sort_attribute_name)
			)
		GFSkillTargetingRule.SortRule.ATTRIBUTE_HIGHEST:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				return _get_entity_attribute_value(a, p_rule.sort_attribute_name) > _get_entity_attribute_value(b, p_rule.sort_attribute_name)
			)
		GFSkillTargetingRule.SortRule.RANDOM:
			p_targets.sort_custom(func(a: Object, b: Object) -> bool:
				var left_key: int = _get_random_sort_key(a, p_rule.random_seed)
				var right_key: int = _get_random_sort_key(b, p_rule.random_seed)
				if left_key != right_key:
					return left_key < right_key
				return a.get_instance_id() < b.get_instance_id()
			)


# 获取实体坐标位置。
func _get_entity_position(p_entity: Object) -> Vector2:
	var position: Variant = GFObjectPropertyTools.read_property(p_entity, NodePath("global_position"))
	if position is Vector2:
		return position

	return Vector2.ZERO


# 获取实体属性值。
func _get_entity_attribute_value(p_entity: Object, p_attr_name: StringName) -> float:
	if p_entity.has_method(&"get_attribute"):
		var attribute: GFModifiedAttribute = _get_modified_attribute_value(p_entity.call(&"get_attribute", p_attr_name))
		if attribute != null:
			return attribute.current_value.get_value()

	var value: Variant = GFObjectPropertyTools.read_property(p_entity, NodePath(String(p_attr_name)))
	if value is float or value is int:
		return GFVariantData.to_float(value)

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
