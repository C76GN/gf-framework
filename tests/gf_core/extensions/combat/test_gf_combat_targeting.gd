## 测试战斗索敌规则、排序与施法中心解析行为。
extends GutTest




class DummyEntity:
	var global_position: Vector2 = Vector2.ZERO
	var _tags: GFTagComponent = GFTagComponent.new()
	var _attributes: Dictionary = {}

	func get_tag_component() -> GFTagComponent:
		return _tags

	func get_attribute(p_name: StringName) -> GFModifiedAttribute:
		var attribute: Variant = GFVariantData.get_option_value(_attributes, p_name)
		if attribute is GFModifiedAttribute:
			return attribute
		return null

	func add_attr(p_name: StringName, p_val: float) -> void:
		_attributes[p_name] = GFModifiedAttribute.new(p_val)


class SampleSkill extends GFSkill:
	var last_targets: Array[Object] = []
	var candidates: Array = []
	var execute_count: int = 0

	func get_targeting_candidates() -> Array:
		return candidates

	func _on_execute(p_targets: Array[Object]) -> void:
		execute_count += 1
		last_targets = p_targets


func before_each() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_utility_instance(GFSkillTargetingUtility.new())
	await Gf.set_architecture(arch)


func after_each() -> void:
	var arch: GFArchitecture = Gf.get_architecture()
	if arch != null:
		arch.dispose()
	Gf._architecture = null


func _targeting_utility() -> GFSkillTargetingUtility:
	var utility: Variant = Gf.get_utility(GFSkillTargetingUtility)
	if utility is GFSkillTargetingUtility:
		return utility
	return null


func test_targeting_distance_sorting() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.shape = GFSkillTargetingRule.Shape.CIRCLE
	rule.radius = 200.0
	rule.max_count = 10

	var e1: DummyEntity = DummyEntity.new()
	e1.global_position = Vector2(100, 0)

	var e2: DummyEntity = DummyEntity.new()
	e2.global_position = Vector2(50, 0)

	var e3: DummyEntity = DummyEntity.new()
	e3.global_position = Vector2(150, 0)

	var candidates: Array[Object] = [e1, e2, e3]

	rule.sort_rule = GFSkillTargetingRule.SortRule.DISTANCE_CLOSEST
	var targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, candidates)
	assert_eq(targets.size(), 3)
	assert_eq(targets[0], e2)
	assert_eq(targets[1], e1)
	assert_eq(targets[2], e3)

	rule.sort_rule = GFSkillTargetingRule.SortRule.DISTANCE_FURTHEST
	targets = utility.find_targets(Vector2.ZERO, rule, candidates)
	assert_eq(targets[0], e3)
	assert_eq(targets[2], e2)


func test_targeting_attribute_sorting() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.shape = GFSkillTargetingRule.Shape.CIRCLE
	rule.radius = 1000.0
	rule.max_count = 3
	rule.sort_attribute_name = &"CustomVal"

	var e1: DummyEntity = DummyEntity.new()
	e1.add_attr(&"CustomVal", 10.0)

	var e2: DummyEntity = DummyEntity.new()
	e2.add_attr(&"CustomVal", 50.0)

	var e3: DummyEntity = DummyEntity.new()
	e3.add_attr(&"CustomVal", 5.0)

	var candidates: Array[Object] = [e1, e2, e3]

	rule.sort_rule = GFSkillTargetingRule.SortRule.ATTRIBUTE_HIGHEST
	var targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, candidates)
	assert_eq(targets[0], e2)
	assert_eq(targets[2], e3)

	rule.sort_rule = GFSkillTargetingRule.SortRule.ATTRIBUTE_LOWEST
	targets = utility.find_targets(Vector2.ZERO, rule, candidates)
	assert_eq(targets[0], e3)
	assert_eq(targets[2], e2)


func test_targeting_tag_filtering() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 1000.0
	rule.require_tags = [&"Ally"]
	rule.ignore_tags = [&"Dead"]

	var e1: DummyEntity = DummyEntity.new()
	e1.get_tag_component().add_tag(&"Ally")

	var e2: DummyEntity = DummyEntity.new()
	e2.get_tag_component().add_tag(&"Enemy")

	var e3: DummyEntity = DummyEntity.new()
	e3.get_tag_component().add_tag(&"Ally")
	e3.get_tag_component().add_tag(&"Dead")

	var candidates: Array[Object] = [e1, e2, e3]
	var targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, candidates)
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], e1)


func test_targeting_max_count() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 1000.0
	rule.max_count = 2

	var e1: DummyEntity = DummyEntity.new()
	var e2: DummyEntity = DummyEntity.new()
	var e3: DummyEntity = DummyEntity.new()

	var candidates: Array[Object] = [e1, e2, e3]
	var targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, candidates)
	assert_eq(targets.size(), 2)


func test_targeting_random_sort_is_deterministic_for_same_seed() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 1000.0
	rule.max_count = 10
	rule.sort_rule = GFSkillTargetingRule.SortRule.RANDOM
	rule.random_seed = 42

	var e1: DummyEntity = DummyEntity.new()
	var e2: DummyEntity = DummyEntity.new()
	var e3: DummyEntity = DummyEntity.new()

	var first_targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, [e1, e2, e3])
	var second_targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, [e3, e2, e1])

	assert_eq(second_targets, first_targets, "相同 seed 和候选集合应得到稳定 RANDOM 顺序。")


func test_rectangle_shape_filters_axis_aligned_bounds() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.shape = GFSkillTargetingRule.Shape.RECTANGLE
	rule.rectangle_size = Vector2(100.0, 80.0)
	rule.max_count = 10

	var inside: DummyEntity = DummyEntity.new()
	inside.global_position = Vector2(40, 20)

	var outside_x: DummyEntity = DummyEntity.new()
	outside_x.global_position = Vector2(60, 0)

	var outside_y: DummyEntity = DummyEntity.new()
	outside_y.global_position = Vector2(0, 50)

	var targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, [inside, outside_x, outside_y])
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], inside)


func test_sector_shape_filters_by_direction() -> void:
	var utility: GFSkillTargetingUtility = _targeting_utility()
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.shape = GFSkillTargetingRule.Shape.SECTOR
	rule.radius = 100.0
	rule.forward_direction = Vector2.RIGHT
	rule.sector_angle_degrees = 90.0
	rule.max_count = 10

	var forward_target: DummyEntity = DummyEntity.new()
	forward_target.global_position = Vector2(50, 0)

	var side_target: DummyEntity = DummyEntity.new()
	side_target.global_position = Vector2(0, 50)

	var back_target: DummyEntity = DummyEntity.new()
	back_target.global_position = Vector2(-50, 0)

	var targets: Array[Object] = utility.find_targets(Vector2.ZERO, rule, [forward_target, side_target, back_target])
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], forward_target)


func test_skill_auto_targeting() -> void:
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 100.0
	rule.max_count = 1

	var target: DummyEntity = DummyEntity.new()
	target.global_position = Vector2(50, 0)

	var owner_entity: DummyEntity = DummyEntity.new()
	owner_entity.global_position = Vector2.ZERO

	var test_skill: SampleSkill = SampleSkill.new(owner_entity)
	test_skill.targeting_rule = rule
	test_skill.candidates = [target]

	var _execute_result_216: Variant = test_skill.execute()
	assert_eq(test_skill.last_targets.size(), 1)
	assert_eq(test_skill.last_targets[0], target)


func test_skill_manual_target_defaults_center_to_owner_position() -> void:
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 30.0
	rule.max_count = 1

	var owner_entity: DummyEntity = DummyEntity.new()
	owner_entity.global_position = Vector2(100, 100)

	var target: DummyEntity = DummyEntity.new()
	target.global_position = Vector2(120, 100)

	var test_skill: SampleSkill = SampleSkill.new(owner_entity)
	test_skill.targeting_rule = rule

	var _execute_result_235: Variant = test_skill.execute(target)
	assert_eq(test_skill.last_targets.size(), 1)
	assert_eq(test_skill.last_targets[0], target)


func test_skill_manual_target_rejects_invalid_target_when_max_count_is_unlimited() -> void:
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 10.0
	rule.max_count = 0

	var owner_entity: DummyEntity = DummyEntity.new()
	owner_entity.global_position = Vector2.ZERO
	var target: DummyEntity = DummyEntity.new()
	target.global_position = Vector2(100, 0)

	var test_skill: SampleSkill = SampleSkill.new(owner_entity)
	test_skill.targeting_rule = rule

	var _execute_result_253: Variant = test_skill.execute(target)

	assert_eq(test_skill.execute_count, 0, "手动目标未通过 targeting_rule 校验时不应以空目标执行。")


func test_skill_explicit_origin_cast_center_is_respected() -> void:
	var rule: GFSkillTargetingRule = GFSkillTargetingRule.new()
	rule.radius = 30.0
	rule.max_count = 1

	var owner_entity: DummyEntity = DummyEntity.new()
	owner_entity.global_position = Vector2(300, 300)

	var origin_target: DummyEntity = DummyEntity.new()
	origin_target.global_position = Vector2(10, 0)

	var test_skill: SampleSkill = SampleSkill.new(owner_entity)
	test_skill.targeting_rule = rule
	test_skill.candidates = [origin_target]

	var _execute_result_273: Variant = test_skill.execute(null, Vector2.ZERO)
	assert_eq(test_skill.last_targets.size(), 1)
	assert_eq(test_skill.last_targets[0], origin_target)
