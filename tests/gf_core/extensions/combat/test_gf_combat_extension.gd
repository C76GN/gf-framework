extends GutTest


# --- 辅助类 (模拟战斗实体) ---

class MockEntity extends Object:
	var tag_component: GFTagComponent = GFTagComponent.new()
	var attributes: Dictionary = {}
	var buffs: Array[GFBuff] = []
	
	func get_tag_component() -> GFTagComponent:
		return tag_component
		
	func get_attribute(p_id: StringName) -> GFModifiedAttribute:
		var attribute: Variant = GFVariantData.get_option_value(attributes, p_id)
		if attribute is GFModifiedAttribute:
			return attribute
		return null
		
	func add_attr(p_id: StringName, p_val: float) -> void:
		attributes[p_id] = GFModifiedAttribute.new(p_val)


class RejectingSkill extends GFSkill:
	func _custom_can_execute() -> bool:
		return false


class FailingExecuteSkill extends GFSkill:
	var executed: bool = false

	func _try_execute(_targets: Array[Object]) -> bool:
		executed = true
		return false


class ContextRecordingSkill extends GFSkill:
	var activation_context: GFSkillActivationContext = null
	var execute_count: int = 0

	func _try_activate(context: RefCounted) -> bool:
		if context is GFSkillActivationContext:
			activation_context = context
		execute_count += 1
		return true


class UnregisterOtherBuff extends GFBuff:
	var system: GFCombatSystem = null
	var target: Object = null

	func on_tick(_p_delta: float) -> void:
		if system != null:
			system.unregister_entity(target)


class TickRecordingBuff extends GFBuff:
	var tick_deltas: Array[float] = []

	func on_tick(p_delta: float) -> void:
		tick_deltas.append(p_delta)


class RefreshTrackingBuff extends GFBuff:
	var refreshed_from: GFBuff = null

	func refresh_from(source_buff: GFBuff) -> void:
		refreshed_from = source_buff
		super.refresh_from(source_buff)


class RecordingHurtBox2D extends GFHurtBox2D:
	var received_context: GFCombatHitContext = null
	var validate_count: int = 0

	func _init() -> void:
		validation_callback = Callable(self, "_validate_hit")

	func _validate_hit(context: GFCombatHitContext, _report: Dictionary) -> Dictionary:
		received_context = context
		validate_count += 1
		return {
			"ok": true,
			"metadata": {
				"validated": true,
			},
		}


class BusinessHitReceiver extends Node:
	var received_context: GFCombatHitContext = null

	func receive_hit(context: GFCombatHitContext) -> Dictionary:
		received_context = context
		return {
			"ok": true,
			"hit_id": context.hit_id,
			"receiver": self,
			"reason": "handled",
			"message": "",
			"metadata": {
				"business": true,
			},
		}


class SideEffectHitReceiver extends Node:
	var received_context: GFCombatHitContext = null

	func receive_hit(context: GFCombatHitContext) -> void:
		received_context = context


class PlainHitTarget extends Node:
	pass


class RecordingHitSender extends Node:
	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_hit_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_hit_id = hit_id_override
		return {
			"ok": true,
			"hit_id": hit_id_override,
			"receiver": receiver,
			"reason": "sender_override",
			"message": "",
			"metadata": {},
		}


class ForwardingHitSender extends RecordingHitSender:
	func send_to(receiver: Object, payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_hit_id = hit_id_override
		if receiver == null or not receiver.has_method(&"receive_hit"):
			return {
				"ok": false,
				"hit_id": hit_id_override,
				"receiver": receiver,
				"reason": "invalid_receiver",
				"message": "",
				"metadata": {},
			}
		var context: GFCombatHitContext = GFCombatHitContext.new(self, receiver, payload_override, hit_id_override)
		return GFVariantData.as_dictionary(receiver.call("receive_hit", context))


# --- 测试方法 ---

## 测试 GFModifiedAttribute 的修饰器计算。
func test_attribute_calculation() -> void:
	var attr: GFModifiedAttribute = GFModifiedAttribute.new(100.0) # Base = 100
	
	# 添加基础加值: +20
	attr.add_modifier(GFModifier.create_base_add(20.0))
	assert_eq(_attribute_value(attr), 120.0, "Base add should work")
	
	# 添加百分比加值: +50% (0.5)
	# Formula: (100 + 20) * (1.0 + 0.5) = 120 * 1.5 = 180
	attr.add_modifier(GFModifier.create_percent_add(0.5))
	assert_eq(_attribute_value(attr), 180.0, "Percent add should apply to base+base_add")
	
	# 添加最终加值: +10
	# Formula: 180 + 10 = 190
	attr.add_modifier(GFModifier.create_final_add(10.0))
	assert_eq(_attribute_value(attr), 190.0, "Final add should work")
	
	# 移除百分比加值
	# Formula: (100 + 20) * 1.0 + 10 = 130
	attr.remove_modifiers_by_source(&"")
	# 移除所有后再手动测试移除单个
	attr.set_base_value(100.0)
	var mod: GFModifier = GFModifier.create_percent_add(1.0)
	attr.add_modifier(mod)
	assert_eq(_attribute_value(attr), 200.0)
	attr.remove_modifier(mod)
	assert_eq(_attribute_value(attr), 100.0)


func test_modifier_separates_attribute_and_source() -> void:
	var attr: GFModifiedAttribute = GFModifiedAttribute.new(10.0)
	var mod: GFModifier = GFModifier.create_base_add(5.0, &"ATK", &"Ring")

	attr.add_modifier(mod)
	attr.remove_modifiers_by_source(&"ATK")
	assert_eq(_attribute_value(attr), 15.0, "按属性 ID 移除不应误删来源为 Ring 的修饰器。")

	attr.remove_modifiers_by_source(&"Ring")
	assert_eq(_attribute_value(attr), 10.0, "按来源 ID 移除应清理匹配修饰器。")


func test_modified_attribute_set_manages_runtime_attributes() -> void:
	var attribute_set: GFModifiedAttributeSet = GFModifiedAttributeSet.new()
	watch_signals(attribute_set)

	var move_speed: GFModifiedAttribute = attribute_set.define_attribute(&"MoveSpeed", 100.0)
	var modifier: GFModifier = GFModifier.create_base_add(25.0, &"MoveSpeed", &"Boots")
	var added: bool = attribute_set.add_modifier(&"MoveSpeed", modifier)

	assert_not_null(move_speed, "属性集合应能定义运行时属性。")
	assert_true(added, "属性存在时应能添加修饰器。")
	assert_eq(attribute_set.get_attribute(&"MoveSpeed"), move_speed, "应能按 ID 取回属性。")
	assert_eq(attribute_set.get_value(&"MoveSpeed"), 125.0, "集合应暴露属性当前值。")
	assert_signal_emitted_with_parameters(attribute_set, "attribute_changed", [&"MoveSpeed", 125.0, 100.0])

	attribute_set.remove_modifiers_by_source(&"Boots")
	assert_eq(attribute_set.get_value(&"MoveSpeed"), 100.0, "按来源移除修饰器应更新属性值。")

	var snapshot: Dictionary = attribute_set.get_base_value_snapshot()
	var _set_base_value_result_217: Variant = attribute_set.set_base_value(&"MoveSpeed", 80.0)
	attribute_set.restore_base_value_snapshot(snapshot)

	assert_eq(attribute_set.get_base_value(&"MoveSpeed"), 100.0, "基础值快照应能恢复属性基础值。")

	var removed: bool = attribute_set.remove_attribute(&"MoveSpeed")

	assert_true(removed, "应能移除属性。")
	assert_false(attribute_set.has_attribute(&"MoveSpeed"), "移除后属性不应继续存在。")
	assert_signal_emitted_with_parameters(attribute_set, "attribute_removed", [&"MoveSpeed"])


func test_modified_attribute_set_can_define_defaults_and_create_missing_attribute() -> void:
	var attribute_set: GFModifiedAttributeSet = GFModifiedAttributeSet.new()
	attribute_set.define_defaults({
		&"Attack": 10.0,
		&"Defense": 2.0,
	})

	var created: bool = attribute_set.add_modifier(&"Critical", GFModifier.create_final_add(5.0, &"Critical"), true)

	assert_eq(attribute_set.get_attribute_ids().size(), 3, "默认属性和自动创建属性都应进入集合。")
	assert_eq(attribute_set.get_value(&"Attack"), 10.0, "默认属性应写入基础值。")
	assert_true(created, "define_if_missing 为 true 时应自动创建属性。")
	assert_eq(attribute_set.get_value(&"Critical"), 5.0, "自动创建属性后应应用修饰器。")


## 测试 GFBindableProperty 的响应式。
func test_attribute_reactivity() -> void:
	var attr: GFModifiedAttribute = GFModifiedAttribute.new(10.0)
	var changed_count: Array[int] = [0]
	var _connect_result_248: Variant = attr.current_value.value_changed.connect(func(_old: Variant, _new: Variant) -> void: changed_count[0] += 1)
	
	attr.add_modifier(GFModifier.create_base_add(5.0))
	assert_eq(changed_count[0], 1, "Signal should emit on modification")

	attr.set_base_value(20.0)
	assert_eq(changed_count[0], 2, "Signal should emit on base value change")


## 测试 GFModifiedAttribute 对外暴露的是只读响应式视图。
func test_attribute_current_value_is_read_only() -> void:
	var attr: GFModifiedAttribute = GFModifiedAttribute.new(10.0)
	watch_signals(attr.current_value)

	attr.current_value.set_value(999.0)

	assert_push_error("[GFReadOnlyBindableProperty] 当前属性为只读视图，请通过宿主对象修改其值。")
	assert_eq(_attribute_value(attr), 10.0, "外部不应绕过 GFModifiedAttribute 直接改写 current_value。")
	assert_signal_not_emitted(attr.current_value, "value_changed", "只读视图拒绝直接写入时不应发出变化信号。")


## 测试 GFTagComponent。
func test_tag_component() -> void:
	var tc: GFTagComponent = GFTagComponent.new()
	assert_false(tc.has_tag(&"Stun"), "Should not have tag initially")
	
	tc.add_tag(&"Stun", 2)
	assert_true(tc.has_tag(&"Stun"), "Should have tag after adding")
	assert_eq(tc.get_tag_count(&"Stun"), 2, "Stack count should be correct")
	
	tc.remove_tag(&"Stun", 1)
	assert_eq(tc.get_tag_count(&"Stun"), 1)
	
	tc.remove_tag(&"Stun", 1)
	assert_false(tc.has_tag(&"Stun"), "Tag should be removed when stack reaches 0")


func test_tag_component_rejects_invalid_remove_count() -> void:
	var tc: GFTagComponent = GFTagComponent.new()
	tc.add_tag(&"Stun", 2)

	tc.remove_tag(&"Stun", -2)

	assert_push_warning("[GFTagComponent] remove_tag 收到无效层数，请传入正数或 -1。")
	assert_eq(tc.get_tag_count(&"Stun"), 2, "无效移除层数不应反向增加标签层数。")


func test_skill_requires_tags_when_owner_has_no_tag_component() -> void:
	var plain_owner: Object = Object.new()
	var skill: GFSkill = GFSkill.new(plain_owner)
	skill.require_tags.append(&"Armed")

	assert_false(skill.can_execute(), "存在必需标签但 owner 无标签组件时，技能不应允许施放。")


func test_skill_custom_can_execute_runs_without_tag_component() -> void:
	var plain_owner: Object = Object.new()
	var skill: RejectingSkill = RejectingSkill.new()
	skill.owner = plain_owner

	assert_false(skill.can_execute(), "owner 无标签组件且无必需标签时，仍应执行自定义施放检查。")


func test_skill_activation_report_uses_tag_query_and_callbacks() -> void:
	var entity: MockEntity = MockEntity.new()
	entity.tag_component.add_tag(&"state.ready")
	var skill: GFSkill = GFSkill.new(entity)
	var query: GFTagQuery = GFTagQuery.new()
	query.all_tags = [&"state.ready"]
	skill.activation_query = query
	skill.activation_checks.append(func(context: RefCounted) -> Dictionary:
		var activation_context: GFSkillActivationContext = _activation_context(context)
		assert_same(activation_context.owner, entity, "激活检查应收到上下文 owner。")
		return {
			"ok": true,
			"metadata": {
				"checked": true,
			},
		}
	)

	var report: Dictionary = skill.get_activation_report()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(_report_ok(report), "满足标签查询和检查回调时应允许激活。")
	assert_true(GFVariantData.get_option_bool(metadata, "checked"), "检查回调 metadata 应写入报告。")


func test_skill_activation_check_failure_blocks_execute() -> void:
	var entity: MockEntity = MockEntity.new()
	var skill: ContextRecordingSkill = ContextRecordingSkill.new(entity)
	skill.activation_checks.append(func(_context: RefCounted) -> Dictionary:
		return {
			"ok": false,
			"reason": &"no_budget",
			"metadata": {
				"cost": 3,
			},
		}
	)
	watch_signals(skill)

	var executed: bool = skill.execute()

	assert_false(executed, "激活检查失败时 execute 应返回 false。")
	assert_eq(skill.execute_count, 0, "激活检查失败不应进入执行钩子。")
	assert_eq(skill.cooldown_left, 0.0, "激活检查失败不应进入冷却。")
	assert_signal_emitted(skill, "activation_failed", "激活失败应发出信号。")


func test_skill_activation_context_commit_and_cooldown_flow() -> void:
	var entity: MockEntity = MockEntity.new()
	var target: MockEntity = MockEntity.new()
	var skill: ContextRecordingSkill = ContextRecordingSkill.new(entity)
	skill.cooldown_max = 2.0
	var committed_targets: Array[Object] = []
	skill.activation_commit_callbacks.append(func(commit_context: RefCounted) -> Dictionary:
		var commit_activation_context: GFSkillActivationContext = _activation_context(commit_context)
		committed_targets.append(commit_activation_context.manual_target)
		return {
			"ok": true,
			"metadata": {
				"committed": true,
			},
		}
	)
	watch_signals(skill)

	var executed: bool = skill.execute(target, Vector2(4.0, 5.0), { "request": "primary" })
	var activation_context: GFSkillActivationContext = skill.activation_context
	var context_metadata: Dictionary = activation_context.metadata
	var context_targets: Array[Object] = activation_context.targets

	assert_true(executed, "激活提交和执行成功时 execute 应返回 true。")
	assert_eq(committed_targets, [target], "提交回调应在执行成功后收到激活上下文。")
	assert_eq(skill.cooldown_left, 2.0, "执行成功后应进入冷却。")
	assert_same(activation_context.manual_target, target, "上下文应保留手动目标。")
	assert_eq(activation_context.resolved_center, Vector2(4.0, 5.0), "上下文应保留解析后的施放中心。")
	assert_eq(context_targets, [target], "上下文应保留最终目标。")
	assert_true(GFVariantData.get_option_bool(context_metadata, "committed"), "提交回调 metadata 应合并到上下文。")
	assert_eq(GFVariantData.get_option_string(context_metadata, "request"), "primary", "调用方 metadata 应保留。")
	assert_signal_emitted(skill, "activation_committed", "执行成功应发出提交信号。")


func test_skill_rejects_freed_owner() -> void:
	var skill_owner: Object = Object.new()
	var skill: GFSkill = GFSkill.new(skill_owner)
	skill_owner.free()

	assert_false(skill.can_execute(), "owner 已释放时技能不应允许施放。")


func test_attribute_ignores_null_modifier() -> void:
	var attr: GFModifiedAttribute = GFModifiedAttribute.new(10.0)

	attr.add_modifier(null)

	assert_eq(_attribute_value(attr), 10.0, "空修饰器不应影响属性计算。")


func test_buff_modifier_requires_explicit_attribute_id() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	system.register_entity(entity)

	var buff: GFBuff = GFBuff.new()
	var mod: GFModifier = GFModifier.new()
	mod.value = 5.0
	mod.source_id = &"ATK"
	buff.modifiers.append(mod)
	buff.setup(&"InvalidPowerUp", 1.0, entity)

	system.add_buff(entity, buff)

	assert_eq(_entity_attribute_value(entity, &"ATK"), 10.0, "2.0 不应再把 source_id 当作目标属性回退。")


func test_buff_ignores_freed_owner() -> void:
	var entity: MockEntity = MockEntity.new()
	var buff: GFBuff = GFBuff.new()
	buff.tags.append(&"Buffed")
	buff.setup(&"Detached", 1.0, entity)
	entity.free()

	buff.on_apply()
	buff.on_remove()

	assert_true(true, "owner 已释放时 Buff 应安全跳过效果应用与移除。")


## 测试 GFCombatSystem 的 Buff 驱动。
func test_combat_system_buff_lifecycle() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	
	system.register_entity(entity)
	
	var buff: GFBuff = GFBuff.new()
	var atk_mod: GFModifier = GFModifier.create_base_add(5.0, &"ATK")
	buff.modifiers.append(atk_mod)
	buff.tags.append(&"Buffed")
	buff.setup(&"PowerUp", 2.0, entity) # 持续 2 秒
	
	system.add_buff(entity, buff)
	
	assert_true(entity.tag_component.has_tag(&"Buffed"), "Buff tags should be applied")
	assert_eq(_entity_attribute_value(entity, &"ATK"), 15.0, "Buff modifiers should be applied")
	
	# Tick 1 秒
	system.tick(1.0)
	assert_eq(_entity_attribute_value(entity, &"ATK"), 15.0, "Buff should still be active")
	
	# Tick 1.5 秒 (总共 2.5，超过 2)
	system.tick(1.5)
	assert_false(entity.tag_component.has_tag(&"Buffed"), "Buff tags should be removed after expiration")
	assert_eq(_entity_attribute_value(entity, &"ATK"), 10.0, "Buff modifiers should be removed after expiration")


## 测试注销实体时会同步移除活跃实体索引。
func test_unregister_entity_removes_active_status() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	
	system.register_entity(entity)
	
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"PowerUp", 2.0, entity)
	system.add_buff(entity, buff)
	
	assert_true(system._active_entities.has(entity.get_instance_id()), "添加 Buff 后实体应进入活跃集合。")
	
	system.unregister_entity(entity)
	
	assert_false(system._active_entities.has(entity.get_instance_id()), "注销实体后活跃索引应被清理。")
	system.tick(1.0)


func test_dispose_removes_buff_effects_and_clears_indices() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	system.register_entity(entity)

	var buff: GFBuff = GFBuff.new()
	buff.modifiers.append(GFModifier.create_base_add(5.0, &"ATK"))
	buff.tags.append(&"Buffed")
	buff.setup(&"PowerUp", 2.0, entity)
	system.add_buff(entity, buff)

	assert_eq(_entity_attribute_value(entity, &"ATK"), 15.0, "dispose 前 Buff 修饰器应已生效。")
	assert_true(entity.tag_component.has_tag(&"Buffed"), "dispose 前 Buff 标签应已生效。")

	system.dispose()

	assert_eq(_entity_attribute_value(entity, &"ATK"), 10.0, "dispose 应移除仍存活实体上的 Buff 修饰器。")
	assert_false(entity.tag_component.has_tag(&"Buffed"), "dispose 应移除仍存活实体上的 Buff 标签。")
	assert_eq(system._entities.size(), 0, "dispose 后主索引应清空。")
	assert_eq(system._active_entities.size(), 0, "dispose 后活跃索引应清空。")


## 测试技能 CD 更新。
func test_skill_cooldown() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)
	
	var skill: GFSkill = GFSkill.new(entity)
	skill.cooldown_max = 5.0
	system.add_skill(entity, skill)
	
	var _execute_result_521: Variant = skill.execute() # 消耗 CD
	assert_eq(skill.cooldown_left, 5.0)
	
	system.tick(2.0)
	assert_eq(skill.cooldown_left, 3.0, "Skill CD should be updated by system tick")


func test_skill_does_not_start_cooldown_when_execute_hook_fails() -> void:
	var entity: MockEntity = MockEntity.new()
	var skill: FailingExecuteSkill = FailingExecuteSkill.new(entity)
	skill.cooldown_max = 5.0
	var committed: Array[bool] = []
	skill.activation_commit_callbacks.append(func(_context: RefCounted) -> bool:
		committed.append(true)
		return true
	)

	var executed: bool = skill.execute()

	assert_false(executed, "执行钩子显式失败时 execute() 应返回 false。")
	assert_true(skill.executed, "技能应已经进入执行钩子。")
	assert_true(committed.is_empty(), "执行钩子失败时不应运行提交回调。")
	assert_eq(skill.cooldown_left, 0.0, "执行钩子失败时不应进入冷却。")


func test_add_skill_rebinds_existing_owner_to_registered_entity() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var old_entity: MockEntity = MockEntity.new()
	var new_entity: MockEntity = MockEntity.new()
	system.register_entity(new_entity)

	var skill: GFSkill = GFSkill.new(old_entity)
	skill.cooldown_max = 1.0
	system.add_skill(new_entity, skill)
	var _execute_result: Variant = skill.execute()

	assert_eq(skill.owner, new_entity, "添加技能时应以系统实体作为唯一 owner。")
	assert_eq(skill.cooldown_left, 1.0, "重绑 owner 后技能应基于新实体正常执行。")


func test_add_skill_assigns_owner_when_missing() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)

	var skill: GFSkill = GFSkill.new()
	skill.cooldown_max = 1.0
	system.add_skill(entity, skill)
	var _execute_result_548: Variant = skill.execute()

	assert_eq(skill.owner, entity, "未设置 owner 的技能在加入实体时应自动回填所属者。")
	assert_eq(skill.cooldown_left, 1.0, "自动回填 owner 后，技能应可正常进入冷却。")


func test_add_buff_assigns_owner_when_missing() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	system.register_entity(entity)

	var buff: GFBuff = GFBuff.new()
	buff.modifiers.append(GFModifier.create_base_add(5.0, &"ATK"))
	buff.setup(&"PowerUp", 1.0, null)
	system.add_buff(entity, buff)

	assert_eq(buff.owner, entity, "未设置 owner 的 Buff 在加入实体时应自动回填所属者。")
	assert_eq(_entity_attribute_value(entity, &"ATK"), 15.0, "自动回填 owner 后，Buff 效果应能正常生效。")


func test_add_buff_rebinds_existing_owner_to_registered_entity() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var old_entity: MockEntity = MockEntity.new()
	var new_entity: MockEntity = MockEntity.new()
	old_entity.add_attr(&"ATK", 10.0)
	new_entity.add_attr(&"ATK", 10.0)
	system.register_entity(new_entity)

	var buff: GFBuff = GFBuff.new()
	buff.modifiers.append(GFModifier.create_base_add(5.0, &"ATK"))
	buff.setup(&"PowerUp", 1.0, old_entity)
	system.add_buff(new_entity, buff)

	assert_eq(buff.owner, new_entity, "添加 Buff 时应以系统实体作为唯一 owner。")
	assert_eq(_entity_attribute_value(old_entity, &"ATK"), 10.0, "旧 owner 不应收到 Buff 效果。")
	assert_eq(_entity_attribute_value(new_entity, &"ATK"), 15.0, "新 owner 应收到 Buff 效果。")


func test_get_buff_has_buff_and_get_buffs_are_safe_queries() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)

	var power_buff: GFBuff = GFBuff.new()
	power_buff.setup(&"PowerUp", 3.0, entity)
	var shield_buff: GFBuff = GFBuff.new()
	shield_buff.setup(&"Shield", 5.0, entity)
	system.add_buff(entity, power_buff)
	system.add_buff(entity, shield_buff)

	var found_buff: GFBuff = system.get_buff(entity, &"PowerUp")
	var buffs: Array[GFBuff] = system.get_buffs(entity)
	buffs.clear()
	found_buff.time_left = 8.0

	assert_same(found_buff, power_buff, "get_buff 应返回系统中正在生效的 Buff 实例。")
	assert_true(system.has_buff(entity, &"PowerUp"), "has_buff 应报告已存在的 Buff。")
	assert_false(system.has_buff(entity, &"Missing"), "has_buff 未命中时应返回 false。")
	assert_eq(system.get_buffs(entity).size(), 2, "get_buffs 返回的数组副本不应暴露内部列表。")
	assert_eq(power_buff.time_left, 8.0, "get_buff 返回的 Buff 应是可修改的运行中实例。")
	assert_eq(system.get_buff(entity, &"Missing"), null, "get_buff 未命中时应返回 null。")


func test_refresh_buff_modifiers_recalculates_changed_modifier_values() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	system.register_entity(entity)

	var modifier: GFModifier = GFModifier.create_base_add(5.0, &"ATK", &"PowerUp")
	var buff: GFBuff = GFBuff.new()
	buff.modifiers.append(modifier)
	buff.setup(&"PowerUp", -1.0, entity)
	system.add_buff(entity, buff)

	modifier.value = 8.0
	var refreshed: bool = system.refresh_buff_modifiers(entity, &"PowerUp")
	var missing: bool = system.refresh_buff_modifiers(entity, &"Missing")

	assert_true(refreshed, "修改已挂载 Modifier 数值后应可通过 refresh_buff_modifiers 刷新属性。")
	assert_false(missing, "刷新不存在的 Buff 应返回 false。")
	assert_almost_eq(_entity_attribute_value(entity, &"ATK"), 18.0, 0.001, "刷新后属性应使用新的 Modifier 数值。")


func test_refresh_buff_modifiers_reports_false_without_refreshed_attributes() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"EmptyBuff", -1.0, entity)
	system.add_buff(entity, buff)

	assert_false(system.refresh_buff_modifiers(entity, &"EmptyBuff"), "没有任何属性被刷新时应返回 false。")


func test_duplicate_buff_refresh_updates_duration_and_stacks() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)

	var buff: GFBuff = GFBuff.new()
	buff.max_stacks = 3
	buff.setup(&"StackingBuff", 1.0, entity)
	system.add_buff(entity, buff)

	var refreshed_buff: GFBuff = GFBuff.new()
	refreshed_buff.setup(&"StackingBuff", -1.0, entity)
	system.add_buff(entity, refreshed_buff)

	assert_eq(buff.stacks, 2, "重复 Buff 应在 max_stacks 允许时增加层数。")
	assert_eq(buff.duration, -1.0, "重复 Buff 刷新应同步新的 duration。")
	assert_eq(buff.time_left, -1.0, "重复 Buff 刷新应同步新的剩余时间。")


func test_empty_buff_ids_do_not_refresh_each_other() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)
	var first: GFBuff = GFBuff.new()
	first.setup(&"", -1.0, entity)
	var second: GFBuff = GFBuff.new()
	second.setup(&"", -1.0, entity)

	system.add_buff(entity, first)
	system.add_buff(entity, second)

	assert_eq(system.get_buffs(entity).size(), 2, "匿名 Buff 不应因为空 id 被当成同一 Buff 刷新。")


func test_duplicate_buff_refresh_uses_refresh_from_hook() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)
	var buff: RefreshTrackingBuff = RefreshTrackingBuff.new()
	buff.setup(&"Refreshable", 1.0, entity)
	system.add_buff(entity, buff)
	var refreshed_buff: GFBuff = GFBuff.new()
	refreshed_buff.setup(&"Refreshable", 2.0, entity)

	system.add_buff(entity, refreshed_buff)

	assert_eq(buff.refreshed_from, refreshed_buff, "重复 Buff 应通过 refresh_from() 暴露项目可覆写刷新入口。")
	assert_eq(buff.duration, 2.0, "默认 refresh_from() 应保持旧的 duration 刷新语义。")


func test_buff_refresh_can_ignore_duplicate_stack() -> void:
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"Guard", 3.0, null)
	buff.time_left = 1.5
	buff.max_stacks = 3
	buff.stack_mode = GFBuff.StackMode.IGNORE

	buff.on_refresh(10.0)

	assert_eq(buff.stacks, 1, "IGNORE 策略不应增加层数。")
	assert_almost_eq(buff.time_left, 1.5, 0.001, "IGNORE 策略不应刷新剩余时间。")


func test_buff_refresh_duration_can_extend_or_keep_longer() -> void:
	var extend_buff: GFBuff = GFBuff.new()
	extend_buff.setup(&"Extend", 3.0, null)
	extend_buff.time_left = 1.0
	extend_buff.duration_refresh_policy = GFBuff.DurationRefreshPolicy.EXTEND_BY_NEW_DURATION
	extend_buff.on_refresh(2.0)

	var keep_buff: GFBuff = GFBuff.new()
	keep_buff.setup(&"KeepLonger", 5.0, null)
	keep_buff.time_left = 4.0
	keep_buff.duration_refresh_policy = GFBuff.DurationRefreshPolicy.KEEP_LONGER_REMAINING
	keep_buff.on_refresh(2.0)

	assert_almost_eq(extend_buff.time_left, 3.0, 0.001, "EXTEND 策略应追加新的持续时间。")
	assert_almost_eq(keep_buff.time_left, 4.0, 0.001, "KEEP_LONGER 策略应保留更长剩余时间。")


func test_buff_periodic_tick_uses_interval() -> void:
	var buff: TickRecordingBuff = TickRecordingBuff.new()
	buff.setup(&"Pulse", -1.0, null)
	buff.tick_interval_seconds = 0.5

	var _update_result_711: Variant = buff.update(0.2)
	var _update_result_712: Variant = buff.update(0.3)
	var _update_result_713: Variant = buff.update(1.1)

	assert_eq(buff.tick_deltas.size(), 3, "周期 Tick 应按间隔触发，而不是每帧触发。")
	assert_almost_eq(buff.tick_deltas[0], 0.5, 0.001, "Tick 回调应收到配置的周期长度。")


func test_buff_expiration_still_runs_final_tick() -> void:
	var buff: TickRecordingBuff = TickRecordingBuff.new()
	buff.setup(&"Pulse", 1.0, null)

	var should_remove: bool = buff.update(1.0)

	assert_true(should_remove, "持续时间耗尽时 Buff 应报告需要移除。")
	assert_eq(buff.tick_deltas, [1.0], "过期帧仍应先触发最终 tick。")


func test_buff_periodic_tick_limits_catchup_budget() -> void:
	var buff: TickRecordingBuff = TickRecordingBuff.new()
	buff.setup(&"Pulse", -1.0, null)
	buff.tick_interval_seconds = 0.01
	buff.max_periodic_ticks_per_update = 4

	var _update_result_725: Variant = buff.update(1.0)

	assert_eq(buff.tick_deltas.size(), 4, "单次 update 不应无限补偿周期 Tick。")


func test_buff_can_remain_after_expire() -> void:
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"PersistentShell", 0.1, null)
	buff.remove_on_expire = false

	var should_remove: bool = buff.update(0.2)

	assert_false(should_remove, "remove_on_expire 为 false 时过期不应要求移除。")
	assert_almost_eq(buff.time_left, 0.0, 0.001, "保留过期 Buff 时剩余时间应夹到 0。")


func test_remove_buff_removes_effects_and_reports_result() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	system.register_entity(entity)

	var buff: GFBuff = GFBuff.new()
	buff.modifiers.append(GFModifier.create_base_add(5.0, &"ATK", &"PowerUp"))
	buff.tags.append(&"Buffed")
	buff.setup(&"PowerUp", -1.0, entity)
	system.add_buff(entity, buff)

	var removed: bool = system.remove_buff(entity, &"PowerUp")
	var missing: bool = system.remove_buff(entity, &"Missing")

	assert_true(removed, "remove_buff 应报告成功移除。")
	assert_false(missing, "remove_buff 未命中时应返回 false。")
	assert_eq(_entity_attribute_value(entity, &"ATK"), 10.0, "remove_buff 应移除属性修饰器。")
	assert_false(entity.tag_component.has_tag(&"Buffed"), "remove_buff 应移除标签。")


func test_live_buff_restore_replaces_previously_applied_effects() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	entity.add_attr(&"ATK", 10.0)
	system.register_entity(entity)

	var buff: GFBuff = GFBuff.new()
	buff.modifiers.append(GFModifier.create_base_add(5.0, &"ATK", &"OldBuff"))
	buff.tags.append(&"OldTag")
	buff.setup(&"OldBuff", -1.0, entity)
	system.add_buff(entity, buff)

	var snapshot_source: GFBuff = GFBuff.new()
	snapshot_source.modifiers.append(GFModifier.create_base_add(3.0, &"ATK", &"NewBuff"))
	snapshot_source.tags.append(&"NewTag")
	snapshot_source.setup(&"NewBuff", -1.0, entity)

	buff.restore_state_snapshot(snapshot_source.get_state_snapshot(), entity)

	assert_false(entity.tag_component.has_tag(&"OldTag"), "恢复 live Buff 快照时应移除旧标签。")
	assert_true(entity.tag_component.has_tag(&"NewTag"), "恢复 live Buff 快照时应应用新标签。")
	assert_eq(_entity_attribute_value(entity, &"ATK"), 13.0, "恢复 live Buff 快照时不应叠加旧修饰器。")


func test_clear_buffs_supports_optional_predicate() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)

	var keep_buff: GFBuff = GFBuff.new()
	keep_buff.setup(&"Keep", -1.0, entity)
	var remove_buff: GFBuff = GFBuff.new()
	remove_buff.setup(&"Remove", -1.0, entity)
	system.add_buff(entity, keep_buff)
	system.add_buff(entity, remove_buff)

	var removed_count: int = system.clear_buffs(entity, func(buff: GFBuff) -> bool:
		return buff.id == &"Remove"
	)

	assert_eq(removed_count, 1, "clear_buffs 应只移除 predicate 匹配的 Buff。")
	var entity_buffs: Array = _entity_buffs(system, entity)
	assert_true(entity_buffs.has(keep_buff), "未匹配的 Buff 应保留。")
	assert_false(entity_buffs.has(remove_buff), "匹配的 Buff 应移除。")


func test_remove_skill_disconnects_cooldown_tracking() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)
	var skill: GFSkill = GFSkill.new(entity)
	skill.cooldown_max = 1.0
	system.add_skill(entity, skill)

	var removed: bool = system.remove_skill(entity, skill)
	var _execute_result_792: Variant = skill.execute()

	assert_true(removed, "remove_skill 应报告成功移除。")
	assert_false(skill.is_connected(&"cooldown_started", Callable(system, "_on_skill_cooldown_started")), "remove_skill 应断开冷却信号。")
	assert_false(system._active_entities.has(entity.get_instance_id()), "移除技能后冷却信号不应重新激活实体。")


## 测试 GFModifiedAttribute 的强制重算。
func test_attribute_force_recalculate() -> void:
	var attr: GFModifiedAttribute = GFModifiedAttribute.new(100.0)
	var mod: GFModifier = GFModifier.create_base_add(10.0)
	attr.add_modifier(mod)
	assert_eq(_attribute_value(attr), 110.0)
	
	# 直接修改修饰器数值而不通过 add/remove
	mod.value = 50.0
	assert_eq(_attribute_value(attr), 110.0, "Value should not change automatically")
	
	attr.force_recalculate()
	assert_eq(_attribute_value(attr), 150.0, "Force recalculate should update final value")


## 测试战斗事件派发。
func test_update_active_status_cleans_orphaned_active_entry() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()

	system._active_entities[entity.get_instance_id()] = true
	system._update_active_status(entity)

	assert_false(system._active_entities.has(entity.get_instance_id()), "未注册实体的活跃索引应被移除。")


func test_tick_cleans_freed_entities_from_internal_indices() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()

	system._entities[entity.get_instance_id()] = {
		"buffs": [],
		"skills": [],
	}
	system._active_entities[entity.get_instance_id()] = true

	entity.free()
	system.tick(0.0)

	assert_eq(system._entities.size(), 0, "已释放实体应从主索引中清理。")
	assert_eq(system._active_entities.size(), 0, "已释放实体应从活跃索引中清理。")


func test_tick_skips_entity_removed_by_earlier_entity_callback() -> void:
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity_a: MockEntity = MockEntity.new()
	var entity_b: MockEntity = MockEntity.new()
	system.register_entity(entity_a)
	system.register_entity(entity_b)

	var remover: UnregisterOtherBuff = UnregisterOtherBuff.new()
	remover.setup(&"Remover", -1.0, entity_a)
	remover.system = system
	remover.target = entity_b
	system.add_buff(entity_a, remover)

	var buff_b: GFBuff = GFBuff.new()
	buff_b.setup(&"TargetBuff", -1.0, entity_b)
	system.add_buff(entity_b, buff_b)

	system.tick(0.1)

	assert_false(system._entities.has(entity_b.get_instance_id()), "tick 中被前一个实体注销的后续实体不应再被访问。")


func test_combat_event_dispatching() -> void:
	# 初始化架构以支持事件总线
	var arch: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(arch)
	
	var system: GFCombatSystem = GFCombatSystem.new()
	var entity: MockEntity = MockEntity.new()
	system.register_entity(entity)
	
	var events: Dictionary = {
		"applied": 0,
		"refreshed": 0,
		"removed": 0,
	}
	
	# 注册监听器
	Gf.listen(GFCombatPayloads.GFBuffAppliedPayload, func(_p: Variant) -> void: events["applied"] += 1)
	Gf.listen(GFCombatPayloads.GFBuffRefreshedPayload, func(_p: Variant) -> void: events["refreshed"] += 1)
	Gf.listen(GFCombatPayloads.GFBuffRemovedPayload, func(_p: Variant) -> void: events["removed"] += 1)
	
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"TestBuff", 1.0, entity)
	
	# 测试 Apply
	system.add_buff(entity, buff)
	assert_eq(GFVariantData.get_option_int(events, "applied"), 1)
	
	# 测试 Refresh
	system.add_buff(entity, buff)
	assert_eq(GFVariantData.get_option_int(events, "refreshed"), 1)
	
	# 测试 Remove
	system.tick(2.0)
	assert_eq(GFVariantData.get_option_int(events, "removed"), 1)
	
	# 清理架构
	arch.dispose()


func test_combat_events_use_injected_scoped_architecture() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(parent_arch)

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var system: GFCombatSystem = GFCombatSystem.new()
	await child_arch.register_system_instance(system)

	var parent_events: Dictionary = { "applied": 0 }
	var child_events: Dictionary = { "applied": 0 }
	parent_arch.register_event(GFCombatPayloads.GFBuffAppliedPayload, func(_p: Variant) -> void:
		parent_events["applied"] += 1
	)
	child_arch.register_event(GFCombatPayloads.GFBuffAppliedPayload, func(_p: Variant) -> void:
		child_events["applied"] += 1
	)

	var entity: MockEntity = MockEntity.new()
	var buff: GFBuff = GFBuff.new()
	buff.setup(&"ScopedBuff", 1.0, entity)

	system.register_entity(entity)
	system.add_buff(entity, buff)

	assert_eq(GFVariantData.get_option_int(child_events, "applied"), 1, "Scoped CombatSystem 应向自身架构派发事件。")
	assert_eq(GFVariantData.get_option_int(parent_events, "applied"), 0, "Scoped CombatSystem 不应绕到全局父架构派发事件。")

	child_arch.dispose()
	parent_arch.dispose()
	Gf._architecture = null


func test_hit_collision_shape_config_2d_generates_reusable_shapes() -> void:
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	add_child_autofree(hit_box)
	add_child_autofree(hurt_box)

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	var config: GFHitCollisionShapeConfig2D = GFHitCollisionShapeConfig2D.new()
	config.shape = circle
	config.position = Vector2(3.0, 4.0)
	config.rotation_degrees = 30.0
	config.scale = Vector2(2.0, 1.5)
	config.debug_color = Color(1.0, 0.2, 0.1, 0.8)
	config.disabled = true

	var auto_hit_box: GFHitBox2D = GFHitBox2D.new()
	auto_hit_box.collision_shape_config = config
	add_child_autofree(auto_hit_box)

	var generated: CollisionShape2D = hit_box.apply_collision_shape_config(config)
	var hurt_generated: CollisionShape2D = hurt_box.apply_collision_shape_config(config)
	var instantiated: CollisionShape2D = config.instantiate_collision_shape()

	assert_not_null(generated, "HitBox 应根据配置生成 CollisionShape2D。")
	assert_not_null(hurt_generated, "HurtBox 应根据配置生成 CollisionShape2D。")
	assert_not_null(instantiated, "配置应能独立创建 CollisionShape2D。")
	assert_same(generated.shape, circle, "生成的碰撞形状应使用配置中的 Shape2D。")
	assert_eq(generated.position, Vector2(3.0, 4.0), "生成的碰撞形状应应用位置。")
	assert_almost_eq(generated.rotation_degrees, 30.0, 0.001, "生成的碰撞形状应应用旋转。")
	assert_eq(generated.scale, Vector2(2.0, 1.5), "生成的碰撞形状应应用缩放。")
	assert_eq(generated.debug_color, Color(1.0, 0.2, 0.1, 0.8), "生成的碰撞形状应应用调试颜色。")
	assert_true(generated.disabled, "生成的碰撞形状应应用 disabled。")
	assert_same(hit_box.get_generated_collision_shape(), generated, "HitBox 应能返回框架管理的 CollisionShape2D。")
	assert_same(hurt_generated.shape, circle, "HurtBox 应复用同一套配置生成形状。")
	assert_same(auto_hit_box.get_generated_collision_shape().shape, circle, "配置属性应在节点进入场景树时自动生成形状。")

	var rectangle: RectangleShape2D = RectangleShape2D.new()
	var replacement: GFHitCollisionShapeConfig2D = GFHitCollisionShapeConfig2D.new()
	replacement.shape = rectangle
	replacement.position = Vector2(-2.0, 1.0)
	var reused: CollisionShape2D = hit_box.apply_collision_shape_config(replacement)

	assert_same(reused, generated, "重复应用配置应复用框架管理的 CollisionShape2D。")
	assert_same(reused.shape, rectangle, "复用节点时应更新 Shape2D。")
	assert_eq(reused.position, Vector2(-2.0, 1.0), "复用节点时应更新位置。")

	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	var second: GFHitCollisionShapeConfig2D = GFHitCollisionShapeConfig2D.new()
	second.shape = capsule
	second.position = Vector2(8.0, 0.0)
	var multi_configs: Array[GFHitCollisionShapeConfig2D] = [replacement, second]
	var generated_list: Array[CollisionShape2D] = hit_box.apply_collision_shape_configs(multi_configs)

	assert_eq(generated_list.size(), 2, "配置列表应生成多个 CollisionShape2D。")
	assert_same(generated_list[0], generated, "列表的第一个形状应复用既有框架节点。")
	assert_eq(hit_box.get_generated_collision_shapes().size(), 2, "HitBox 应能返回全部框架管理的形状节点。")
	assert_same(generated_list[1].shape, capsule, "第二个配置应生成第二个 CollisionShape2D。")

	var reduced_configs: Array[GFHitCollisionShapeConfig2D] = [replacement]
	var reduced_list: Array[CollisionShape2D] = hit_box.apply_collision_shape_configs(reduced_configs)
	assert_eq(reduced_list.size(), 1, "缩短配置列表后应只保留有效配置数量。")
	assert_eq(hit_box.get_generated_collision_shapes().size(), 1, "多余的框架管理形状应被清理。")

	auto_hit_box.collision_shape_config = null
	assert_null(auto_hit_box.get_generated_collision_shape(), "配置属性置空时应清理框架管理的形状节点。")
	hit_box.clear_generated_collision_shape()
	assert_null(hit_box.get_generated_collision_shape(), "clear_generated_collision_shape 应移除框架管理的形状节点。")
	instantiated.free()


func test_hit_collision_shape_config_3d_generates_reusable_shapes() -> void:
	var hit_box: GFHitBox3D = GFHitBox3D.new()
	var hurt_box: GFHurtBox3D = GFHurtBox3D.new()
	add_child_autofree(hit_box)
	add_child_autofree(hurt_box)

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 2.0
	var config: GFHitCollisionShapeConfig3D = GFHitCollisionShapeConfig3D.new()
	config.shape = sphere
	config.position = Vector3(1.0, 2.0, 3.0)
	config.rotation_degrees = Vector3(10.0, 20.0, 30.0)
	config.scale = Vector3(2.0, 2.0, 2.0)
	config.debug_color = Color(0.1, 0.8, 1.0, 0.75)
	config.disabled = true

	var auto_hit_box: GFHitBox3D = GFHitBox3D.new()
	auto_hit_box.collision_shape_config = config
	add_child_autofree(auto_hit_box)

	var generated: CollisionShape3D = hit_box.apply_collision_shape_config(config)
	var hurt_generated: CollisionShape3D = hurt_box.apply_collision_shape_config(config)
	var instantiated: CollisionShape3D = config.instantiate_collision_shape()

	assert_not_null(generated, "HitBox3D 应根据配置生成 CollisionShape3D。")
	assert_not_null(hurt_generated, "HurtBox3D 应根据配置生成 CollisionShape3D。")
	assert_not_null(instantiated, "配置应能独立创建 CollisionShape3D。")
	assert_same(generated.shape, sphere, "生成的碰撞形状应使用配置中的 Shape3D。")
	assert_eq(generated.position, Vector3(1.0, 2.0, 3.0), "生成的碰撞形状应应用位置。")
	assert_true(generated.rotation_degrees.is_equal_approx(Vector3(10.0, 20.0, 30.0)), "生成的碰撞形状应应用旋转。")
	assert_eq(generated.scale, Vector3(2.0, 2.0, 2.0), "生成的碰撞形状应应用缩放。")
	assert_eq(generated.debug_color, Color(0.1, 0.8, 1.0, 0.75), "生成的碰撞形状应应用调试颜色。")
	assert_true(generated.disabled, "生成的碰撞形状应应用 disabled。")
	assert_same(hit_box.get_generated_collision_shape(), generated, "HitBox3D 应能返回框架管理的 CollisionShape3D。")
	assert_same(hurt_generated.shape, sphere, "HurtBox3D 应复用同一套配置生成形状。")
	assert_same(auto_hit_box.get_generated_collision_shape().shape, sphere, "配置属性应在节点进入场景树时自动生成 3D 形状。")

	var box: BoxShape3D = BoxShape3D.new()
	var replacement: GFHitCollisionShapeConfig3D = GFHitCollisionShapeConfig3D.new()
	replacement.shape = box
	replacement.position = Vector3(-1.0, -2.0, -3.0)
	var reused: CollisionShape3D = hit_box.apply_collision_shape_config(replacement)

	assert_same(reused, generated, "重复应用配置应复用框架管理的 CollisionShape3D。")
	assert_same(reused.shape, box, "复用节点时应更新 Shape3D。")
	assert_eq(reused.position, Vector3(-1.0, -2.0, -3.0), "复用节点时应更新位置。")

	var cylinder: CylinderShape3D = CylinderShape3D.new()
	var second: GFHitCollisionShapeConfig3D = GFHitCollisionShapeConfig3D.new()
	second.shape = cylinder
	second.position = Vector3(0.0, 1.0, 0.0)
	var multi_configs: Array[GFHitCollisionShapeConfig3D] = [replacement, second]
	var generated_list: Array[CollisionShape3D] = hit_box.apply_collision_shape_configs(multi_configs)

	assert_eq(generated_list.size(), 2, "配置列表应生成多个 CollisionShape3D。")
	assert_same(generated_list[0], generated, "列表的第一个 3D 形状应复用既有框架节点。")
	assert_eq(hit_box.get_generated_collision_shapes().size(), 2, "HitBox3D 应能返回全部框架管理的形状节点。")
	assert_same(generated_list[1].shape, cylinder, "第二个配置应生成第二个 CollisionShape3D。")

	auto_hit_box.collision_shape_config = null
	assert_null(auto_hit_box.get_generated_collision_shape(), "配置属性置空时应清理框架管理的 3D 形状节点。")
	hit_box.clear_generated_collision_shape()
	assert_null(hit_box.get_generated_collision_shape(), "clear_generated_collision_shape 应移除框架管理的 3D 形状节点。")
	instantiated.free()


func test_hit_box_2d_sends_generic_hit_context() -> void:
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var hurt_box: RecordingHurtBox2D = RecordingHurtBox2D.new()
	add_child_autofree(hit_box)
	add_child_autofree(hurt_box)
	hit_box.hit_id = &"impact"
	hit_box.payload = { "value": 3 }
	hit_box.magnitude = 2.5
	hit_box.tags = [&"melee"]
	hurt_box.accepted_hit_ids = [&"impact"]

	var report: Dictionary = hit_box.send_to(hurt_box)
	var payload: Dictionary = GFVariantData.as_dictionary(hurt_box.received_context.payload)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(_report_ok(report), "有效 HurtBox 应接受命中。")
	assert_same(hurt_box.received_context.source, hit_box, "默认 source 应为 HitBox 自身。")
	assert_same(hurt_box.received_context.target, hurt_box, "上下文 target 应指向接收器。")
	assert_eq(hurt_box.received_context.hit_id, &"impact", "hit_id 应写入上下文。")
	assert_eq(GFVariantData.get_option_int(payload, "value"), 3, "payload 应写入上下文。")
	assert_almost_eq(hurt_box.received_context.magnitude, 2.5, 0.001, "通用强度应写入上下文。")
	assert_eq(hurt_box.received_context.tags, [&"melee"], "标签应写入上下文。")
	assert_true(GFVariantData.get_option_bool(metadata, "validated"), "接收器校验结果应合并 metadata。")


func test_hurt_box_filters_hit_ids() -> void:
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	add_child_autofree(hurt_box)
	hurt_box.accepted_hit_ids = [&"allowed"]

	var rejected: Dictionary = hurt_box.receive_hit(GFCombatHitContext.new(null, null, null, &"blocked"))
	var accepted: Dictionary = hurt_box.receive_hit(GFCombatHitContext.new(null, null, null, &"allowed"))

	assert_false(_report_ok(rejected), "不在 accepted_hit_ids 内的命中应被拒绝。")
	assert_eq(GFVariantData.get_option_string(rejected, "reason"), "unaccepted_id")
	assert_true(_report_ok(accepted), "允许的命中 ID 应通过基础过滤。")


func test_hurt_box_2d_receiver_path_forwards_hit_to_business_receiver() -> void:
	var root: Node = Node.new()
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	var business_receiver: BusinessHitReceiver = BusinessHitReceiver.new()
	add_child_autofree(root)
	root.add_child(hit_box)
	root.add_child(hurt_box)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	hit_box.hit_id = &"impact"
	hurt_box.accepted_hit_ids = [&"impact"]
	hurt_box.receiver_path = NodePath("../BusinessReceiver")
	watch_signals(hurt_box)

	var report: Dictionary = hit_box.send_to(hurt_box)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(_report_ok(report), "通过本地过滤的 2D 命中应转发给业务接收器。")
	assert_same(business_receiver.received_context.target, business_receiver, "转发时命中 target 应更新为业务接收器。")
	assert_same(_report_receiver(report), business_receiver, "最终命中报告应来自业务接收器。")
	assert_true(GFVariantData.get_option_bool(metadata, "business"), "业务命中接收器返回的报告应成为最终报告。")
	assert_signal_emitted(hurt_box, "hit_received", "业务接收成功后 HurtBox 应发出接收信号。")


func test_hurt_box_2d_receiver_path_accepts_side_effect_receiver() -> void:
	var root: Node = Node.new()
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	var business_receiver: SideEffectHitReceiver = SideEffectHitReceiver.new()
	add_child_autofree(root)
	root.add_child(hit_box)
	root.add_child(hurt_box)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	hit_box.hit_id = &"impact"
	hurt_box.accepted_hit_ids = [&"impact"]
	hurt_box.receiver_path = NodePath("../BusinessReceiver")
	watch_signals(hurt_box)

	var report: Dictionary = hit_box.send_to(hurt_box)

	assert_true(_report_ok(report), "副作用式业务接收器不返回报告时仍应沿用 HurtBox 接收报告。")
	assert_same(business_receiver.received_context.target, business_receiver, "转发时命中 target 应更新为业务接收器。")
	assert_same(_report_receiver(report), business_receiver, "默认接收报告应指向业务接收器。")
	assert_signal_emitted(hurt_box, "hit_received", "业务接收器处理后 HurtBox 应发出接收信号。")


func test_hurt_box_2d_receiver_path_can_only_retarget_context() -> void:
	var root: Node = Node.new()
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	var business_target: PlainHitTarget = PlainHitTarget.new()
	add_child_autofree(root)
	root.add_child(hit_box)
	root.add_child(hurt_box)
	root.add_child(business_target)
	business_target.name = "BusinessTarget"
	hit_box.hit_id = &"impact"
	hurt_box.accepted_hit_ids = [&"impact"]
	hurt_box.receiver_path = NodePath("../BusinessTarget")
	watch_signals(hurt_box)

	var report: Dictionary = hit_box.send_to(hurt_box)

	assert_true(hurt_box.can_receive_hit(&"impact"), "receiver_path 指向普通业务节点时仍应允许 HurtBox 接收命中。")
	assert_true(_report_ok(report), "普通业务节点可只作为命中 target，不必实现 receive_hit()。")
	assert_same(_report_receiver(report), business_target, "默认接收报告应指向业务 target。")
	assert_signal_emitted(hurt_box, "hit_received", "HurtBox retarget 后仍应发出接收信号。")


func test_hurt_box_3d_receiver_path_forwards_hit_to_business_receiver() -> void:
	var root: Node = Node.new()
	var hit_box: GFHitBox3D = GFHitBox3D.new()
	var hurt_box: GFHurtBox3D = GFHurtBox3D.new()
	var business_receiver: BusinessHitReceiver = BusinessHitReceiver.new()
	add_child_autofree(root)
	root.add_child(hit_box)
	root.add_child(hurt_box)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	hit_box.hit_id = &"impact"
	hurt_box.accepted_hit_ids = [&"impact"]
	hurt_box.receiver_path = NodePath("../BusinessReceiver")

	var report: Dictionary = hit_box.send_to(hurt_box)

	assert_true(_report_ok(report), "通过本地过滤的 3D 命中应转发给业务接收器。")
	assert_same(business_receiver.received_context.target, business_receiver, "转发时 3D 命中 target 应更新为业务接收器。")
	assert_same(_report_receiver(report), business_receiver, "最终 3D 命中报告应来自业务接收器。")


func test_hit_box_2d_collision_dispatch_uses_sender_send_to_override() -> void:
	var root: Node = Node.new()
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var sender: RecordingHitSender = RecordingHitSender.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	add_child_autofree(root)
	root.add_child(hit_box)
	root.add_child(sender)
	root.add_child(hurt_box)
	sender.name = "Sender"
	hit_box.sender_path = NodePath("../Sender")
	watch_signals(hit_box)

	var reports: Array[Dictionary] = []
	reports.assign(preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")._send_to_collision_candidates(
		hit_box._resolve_collision_dispatch_host(),
		[hurt_box],
		0,
		{ "value": 3 },
		&"impact",
		&"receive_hit",
		Callable(hit_box, "_emit_collision_dispatch_result")
	))

	assert_eq(reports.size(), 1, "碰撞广播应通过可覆写发送者发送一次命中。")
	assert_same(sender.received_receiver, hurt_box, "sender_path 指向的发送者实现 send_to() 时应接管碰撞分发。")
	assert_eq(GFVariantData.as_dictionary(sender.received_payload), { "value": 3 }, "payload 覆盖值应透传给业务发送者。")
	assert_eq(sender.received_hit_id, &"impact", "命中 ID 覆盖值应透传给业务发送者。")
	assert_signal_emitted(hit_box, "hit_sent", "业务发送者接管碰撞分发时 HitBox 仍应发出 hit_sent。")
	assert_signal_emitted(hit_box, "hit_accepted", "业务发送者返回成功报告时 HitBox 仍应发出 hit_accepted。")


func test_hit_box_2d_collision_dispatch_keeps_hurt_box_signal_when_sender_forwards() -> void:
	var root: Node = Node.new()
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var sender: ForwardingHitSender = ForwardingHitSender.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	add_child_autofree(root)
	root.add_child(hit_box)
	root.add_child(sender)
	root.add_child(hurt_box)
	sender.name = "Sender"
	hit_box.sender_path = NodePath("../Sender")
	watch_signals(hit_box)
	watch_signals(hurt_box)

	var reports: Array[Dictionary] = []
	reports.assign(preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")._send_to_collision_candidates(
		hit_box._resolve_collision_dispatch_host(),
		[hurt_box],
		0,
		{ "value": 3 },
		&"impact",
		&"receive_hit",
		Callable(hit_box, "_emit_collision_dispatch_result")
	))

	assert_eq(reports.size(), 1, "业务发送者转发时应返回一次命中报告。")
	assert_signal_emitted(hit_box, "hit_sent", "sender_path 接管后 HitBox 信号仍归 HitBox 发出。")
	assert_signal_emitted(hurt_box, "hit_received", "业务发送者调用 receiver.receive_hit() 后 HurtBox 仍应发出 hit_received。")


func test_hit_and_hurt_boxes_emit_enabled_changed() -> void:
	var hit_box_2d: GFHitBox2D = GFHitBox2D.new()
	var hurt_box_2d: GFHurtBox2D = GFHurtBox2D.new()
	var hit_box_3d: GFHitBox3D = GFHitBox3D.new()
	var hurt_box_3d: GFHurtBox3D = GFHurtBox3D.new()
	add_child_autofree(hit_box_2d)
	add_child_autofree(hurt_box_2d)
	add_child_autofree(hit_box_3d)
	add_child_autofree(hurt_box_3d)
	watch_signals(hit_box_2d)
	watch_signals(hurt_box_2d)
	watch_signals(hit_box_3d)
	watch_signals(hurt_box_3d)

	hit_box_2d.enabled = false
	hurt_box_2d.enabled = false
	hit_box_3d.enabled = false
	hurt_box_3d.enabled = false
	hit_box_2d.enabled = false
	hurt_box_2d.enabled = false

	assert_signal_emitted_with_parameters(hit_box_2d, "enabled_changed", [false])
	assert_signal_emitted_with_parameters(hurt_box_2d, "enabled_changed", [false])
	assert_signal_emitted_with_parameters(hit_box_3d, "enabled_changed", [false])
	assert_signal_emitted_with_parameters(hurt_box_3d, "enabled_changed", [false])
	assert_signal_emit_count(hit_box_2d, "enabled_changed", 1)
	assert_signal_emit_count(hurt_box_2d, "enabled_changed", 1)


func test_combat_gauge_applies_generic_action_with_modifier() -> void:
	var gauge: GFCombatGauge = GFCombatGauge.new()
	add_child_autofree(gauge)
	gauge.configure(0.0, 100.0, 100.0)
	gauge.accepted_action_kinds = [&"impact"]
	var modifier: GFCombatActionModifier = GFCombatActionModifier.new()
	modifier.accepted_action_kinds = [&"impact"]
	modifier.amount_multiplier = 0.5
	gauge.add_modifier(modifier)
	var action: GFCombatAction = GFCombatAction.new()
	action.action_kind = &"impact"
	action.operation = GFCombatAction.Operation.SUBTRACT
	action.amount = 40.0

	var result: GFCombatActionResult = gauge.apply_action(action)

	assert_true(result.ok, "通用数值槽应接受允许的动作类别。")
	assert_almost_eq(gauge.current_value, 80.0, 0.001, "动作修正器应在应用前调整数值。")
	assert_almost_eq(result.action.amount, 20.0, 0.001, "结果应记录最终动作。")


func test_combat_gauge_rejects_unaccepted_action_kind() -> void:
	var gauge: GFCombatGauge = GFCombatGauge.new()
	add_child_autofree(gauge)
	gauge.configure(0.0, 10.0, 5.0)
	gauge.accepted_action_kinds = [&"allowed"]
	var action: GFCombatAction = GFCombatAction.new()
	action.action_kind = &"blocked"
	action.amount = 3.0

	var result: GFCombatActionResult = gauge.apply_action(action)

	assert_false(result.ok, "未接受的动作类别应被拒绝。")
	assert_eq(result.reason, &"unaccepted_kind", "拒绝原因应稳定。")
	assert_almost_eq(gauge.current_value, 5.0, 0.001, "被拒绝动作不应修改数值。")


func test_hit_scan_2d_reports_miss_without_collision() -> void:
	var hit_scan: GFHitScan2D = GFHitScan2D.new()
	add_child_autofree(hit_scan)
	watch_signals(hit_scan)

	var report: Dictionary = hit_scan.scan()

	assert_false(_report_ok(report), "没有碰撞时 HitScan 应返回失败报告。")
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"no_collision", "没有碰撞时原因应稳定。")
	assert_signal_emitted(hit_scan, "scan_missed", "没有碰撞时应发出 missed 信号。")


func test_hit_box_3d_builds_position_context() -> void:
	var hit_box: GFHitBox3D = GFHitBox3D.new()
	var hurt_box: GFHurtBox3D = GFHurtBox3D.new()
	add_child_autofree(hit_box)
	add_child_autofree(hurt_box)
	hit_box.global_position = Vector3(1.0, 2.0, 3.0)
	hit_box.hit_id = &"scan"

	var context: GFCombatHitContext = hit_box.build_hit_context(hurt_box)
	var report: Dictionary = hurt_box.receive_hit(context)

	assert_true(_report_ok(report), "3D HurtBox 应接收通用命中。")
	assert_eq(context.position_3d, Vector3(1.0, 2.0, 3.0), "3D 命中上下文应记录发送区域位置。")


func test_hit_box_state_2d_toggles_child_hit_and_hurt_boxes() -> void:
	var state: GFHitBoxState2D = GFHitBoxState2D.new()
	var nested: Node2D = Node2D.new()
	var hit_box: GFHitBox2D = GFHitBox2D.new()
	var hurt_box: GFHurtBox2D = GFHurtBox2D.new()
	state.add_child(nested)
	nested.add_child(hit_box)
	nested.add_child(hurt_box)
	add_child_autofree(state)

	state.deactivate()

	assert_false(hit_box.enabled, "状态组关闭时应关闭 HitBox enabled。")
	assert_false(hurt_box.enabled, "状态组关闭时应关闭 HurtBox enabled。")
	assert_false(hit_box.monitoring, "状态组关闭时应关闭 Area monitoring。")
	assert_false(hurt_box.monitorable, "状态组关闭时应关闭 Area monitorable。")

	state.activate()

	assert_true(hit_box.enabled, "状态组激活后应恢复 HitBox enabled。")
	assert_true(hurt_box.enabled, "状态组激活后应恢复 HurtBox enabled。")


func test_hit_box_state_3d_can_manage_visibility_optionally() -> void:
	var state: GFHitBoxState3D = GFHitBoxState3D.new()
	state.manage_visibility = true
	var hit_box: GFHitBox3D = GFHitBox3D.new()
	state.add_child(hit_box)
	add_child_autofree(state)

	state.deactivate()

	assert_false(hit_box.enabled, "3D 状态组关闭时应关闭 HitBox enabled。")
	assert_false(hit_box.visible, "启用可见性管理时应同步 Node3D visible。")


# --- 私有/辅助方法 ---

func _activation_context(context: RefCounted) -> GFSkillActivationContext:
	if context is GFSkillActivationContext:
		return context
	return null


func _attribute_value(attribute: GFModifiedAttribute) -> float:
	return GFVariantData.to_float(attribute.current_value.get_value())


func _entity_attribute_value(entity: MockEntity, attribute_id: StringName) -> float:
	var attribute: GFModifiedAttribute = entity.get_attribute(attribute_id)
	if attribute == null:
		return 0.0
	return _attribute_value(attribute)


func _entity_buffs(system: GFCombatSystem, entity: Object) -> Array:
	var entity_record: Dictionary = GFVariantData.get_option_dictionary(system._entities, entity.get_instance_id())
	return GFVariantData.get_option_array(entity_record, "buffs")


func _report_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok")


func _report_receiver(report: Dictionary) -> Object:
	var value: Variant = GFVariantData.get_option_value(report, "receiver")
	if value is Object:
		var receiver: Object = value
		return receiver
	return null
