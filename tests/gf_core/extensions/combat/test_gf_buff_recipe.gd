## 测试数据化 Buff 配方、检查、效果和状态快照。
extends GutTest


# --- 测试用例 ---

func test_buff_recipe_creates_runtime_buff_without_business_semantics() -> void:
	var recipe: GFBuffRecipe = GFBuffRecipe.new()
	recipe.id = &"generic.power"
	recipe.duration = 3.0
	recipe.stacks = 2
	recipe.tags = [&"generic.tag"]
	recipe.modifier_entries = [
		{
			"type": "base_add",
			"value": 5.0,
			"attribute_id": &"power",
			"source_id": &"generic.power",
		},
	]
	recipe.effects.append(RecordingEffect.new())
	recipe.checks.append(AllowCheck.new())
	recipe.metadata = {
		"category": "test",
	}

	var buff: GFBuff = recipe.create_buff(null, {
		"metadata": {
			"runtime": true,
		},
	})
	var effect: RecordingEffect = _recording_effect(buff.effects[0])
	var apply_report: Dictionary = buff.get_apply_report()

	var _apply_lifecycle_report: Dictionary = buff.on_apply()
	buff.on_tick(0.25)
	buff.mark_removed(GFBuff.REMOVAL_REASON_CLEARED)
	var _remove_lifecycle_report: Dictionary = buff.on_remove()

	assert_true(GFVariantData.get_option_bool(apply_report, "ok"), "允许检查通过时 Buff 应可应用。")
	assert_eq(buff.id, &"generic.power")
	assert_eq(buff.stacks, 2)
	assert_eq(buff.modifiers.size(), 1)
	assert_eq(buff.modifiers[0].attribute_id, &"power")
	assert_true(buff.tags.has(&"generic.tag"))
	assert_true(GFVariantData.get_option_bool(buff.metadata, "runtime"), "运行时 metadata 应合并到 Buff。")
	assert_eq(effect.events, [&"apply", &"tick", &"remove"], "效果应按 Buff 生命周期触发。")
	assert_eq(buff.removal_reason, GFBuff.REMOVAL_REASON_CLEARED)


func test_buff_check_blocks_combat_system_add_buff() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: Object = Object.new()
	system.register_entity(entity)
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"blocked", 1.0, entity)
	var check: BlockingCheck = BlockingCheck.new()
	check.check_id = &"blocked_check"
	buff.checks.append(check)

	system.add_buff(entity, buff)

	assert_false(system.has_buff(entity, &"blocked"), "检查失败的 Buff 不应进入 CombatSystem。")
	system.dispose()
	entity.free()


func test_buff_state_snapshot_restores_generic_runtime_fields_and_effect_state() -> void:
	var effect: RecordingEffect = RecordingEffect.new()
	var buff: GFBuff = GFBuff.new()
	buff.effects.append(effect)
	buff.modifiers.append(GFModifier.create_percent_add(0.25, &"speed", &"haste"))
	buff.tags.append(&"state.fast")
	buff.metadata = {
		"source": "test",
	}
	buff.setup(&"haste", 5.0, null)
	buff.time_left = 2.0
	buff.stacks = 3
	var _apply_lifecycle_report: Dictionary = buff.on_apply()

	var snapshot: Dictionary = buff.get_state_snapshot()
	var restored: GFBuff = GFBuff.new()
	restored.effects.append(RecordingEffect.new())
	restored.restore_state_snapshot(snapshot)
	var restored_effect: RecordingEffect = _recording_effect(restored.effects[0])

	assert_eq(restored.id, &"haste")
	assert_eq(restored.time_left, 2.0)
	assert_eq(restored.stacks, 3)
	assert_eq(restored.modifiers.size(), 1)
	assert_eq(restored.modifiers[0].type, GFModifier.Type.PERCENT_ADD)
	assert_true(restored.tags.has(&"state.fast"))
	assert_eq(GFVariantData.get_option_string(restored.metadata, "source"), "test")
	assert_eq(restored_effect.events, [&"apply"], "效果状态快照应恢复到对应 effect 索引。")


func test_modifier_dictionary_roundtrip_preserves_attribute_and_source() -> void:
	var modifier: GFModifier = GFModifier.create_final_add(7.0, &"hp", &"source.a")
	var data: Dictionary = modifier.to_dictionary()
	var restored: GFModifier = GFModifier.from_dictionary(data)

	assert_eq(restored.type, GFModifier.Type.FINAL_ADD)
	assert_eq(restored.value, 7.0)
	assert_eq(restored.attribute_id, &"hp")
	assert_eq(restored.source_id, &"source.a")


# --- 私有/辅助方法 ---

func _recording_effect(value: Variant) -> RecordingEffect:
	if value is RecordingEffect:
		var effect: RecordingEffect = value
		return effect
	return null


# --- 内部类 ---

class RecordingEffect:
	extends GFBuffEffect

	var events: Array[StringName] = []

	func _apply(_context: Dictionary) -> Dictionary:
		events.append(&"apply")
		return { "ok": true }

	func _remove(_context: Dictionary) -> Dictionary:
		events.append(&"remove")
		return { "ok": true }

	func _tick(_context: Dictionary) -> Dictionary:
		events.append(&"tick")
		return { "ok": true }

	func _get_state_snapshot() -> Dictionary:
		return {
			"events": events.duplicate(),
		}

	func _restore_state_snapshot(snapshot: Dictionary) -> void:
		events = GFVariantData.get_option_string_name_array(snapshot, "events")


class AllowCheck:
	extends GFBuffCheck

	func _can_apply(_context: Dictionary) -> Dictionary:
		return { "ok": true }


class BlockingCheck:
	extends GFBuffCheck

	func _can_apply(_context: Dictionary) -> Dictionary:
		return {
			"ok": false,
			"reason": &"blocked_by_check",
		}
