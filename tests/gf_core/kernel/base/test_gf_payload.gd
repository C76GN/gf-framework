## 测试 GFPayload 的继承模式、to_dict/from_dict 约定及 validate 接口。
extends GutTest

const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试：基本接口 ---

## 验证子类可以持有并访问强类型字段。
func test_subclass_holds_typed_fields() -> void:
	var payload: AttackPayload = AttackPayload.new()
	payload.attacker_id = 1
	payload.damage = 50

	assert_eq(
		payload.attacker_id,
		1,
		"attacker_id 应为 1。"
	)
	assert_eq(
		payload.damage,
		50,
		"damage 应为 50。"
	)


# --- 测试：to_dict / from_dict 往返 ---

## 验证 to_dict 后再 from_dict 可完整还原字段值。
func test_to_dict_and_from_dict_roundtrip() -> void:
	var original: AttackPayload = AttackPayload.new()
	original.attacker_id = 7
	original.damage = 120

	var dict: Dictionary = original.to_dict()

	var restored: AttackPayload = AttackPayload.new()
	restored.from_dict(dict)

	assert_eq(
		restored.attacker_id,
		7,
		"还原后 attacker_id 应为 7。"
	)
	assert_eq(
		restored.damage,
		120,
		"还原后 damage 应为 120。"
	)


## 验证基类的默认 to_dict 返回空字典而不崩溃。
func test_base_to_dict_returns_empty_dict() -> void:
	var base: GFPayload = GFPayload.new()
	var result: Dictionary = base.to_dict()
	assert_eq(
		result.size(),
		0,
		"基类 to_dict 默认应返回空字典。"
	)


# --- 测试：validate ---

## 验证数据合法时 validate 返回 true。
func test_validate_returns_true_when_valid() -> void:
	var payload: AttackPayload = AttackPayload.new()
	payload.attacker_id = 0
	payload.damage = 1

	assert_true(
		payload.validate(),
		"合法数据应通过校验。"
	)


## 验证数据非法时 validate 返回 false。
func test_validate_returns_false_when_invalid() -> void:
	var payload: AttackPayload = AttackPayload.new()
	payload.attacker_id = -1
	payload.damage = 0

	assert_false(
		payload.validate(),
		"非法数据应不通过校验。"
	)


## 验证基类的默认 validate 始终返回 true。
func test_base_validate_returns_true() -> void:
	var base: GFPayload = GFPayload.new()
	assert_true(
		base.validate(),
		"基类 validate 默认应返回 true。"
	)


# --- 辅助子类 ---

## 用于测试的具体 Payload 实现，携带两个强类型字段。
class AttackPayload:
	extends GFPayload

	var attacker_id: int = -1
	var damage: int = 0

	func to_dict() -> Dictionary:
		return { "attacker_id": attacker_id, "damage": damage }


	func from_dict(data: Dictionary) -> void:
		attacker_id = GF_VARIANT_ACCESS.get_option_int(
			data,
			"attacker_id",
			-1
		)
		damage = GF_VARIANT_ACCESS.get_option_int(data, "damage")


	func validate() -> bool:
		return attacker_id >= 0 and damage > 0
