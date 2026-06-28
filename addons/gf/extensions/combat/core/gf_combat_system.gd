## GFCombatSystem: 战斗核心系统。
##
## 负责驱动所有注册实体的 Buff 计时、周期触发以及技能 CD 更新。
## 继承自 GFSystem，可通过架构的 tick 自动运行。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFCombatSystem
extends GFSystem


# --- 私有变量 ---

# 存储所有当前受系统管理的战斗实体元数据。
# 格式：{ entity_id: { "buffs": [GFBuff], "skills": [GFSkill] } }
var _entities: Dictionary = {}

# 活跃实体集合。键为实体 ID，值固定为 true。
var _active_entities: Dictionary = {}


# --- GF 生命周期方法 ---

## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param p_delta: 本帧时间增量（秒）。
func tick(p_delta: float) -> void:
	_cleanup_invalid_entities()
	var ids: Array = _active_entities.keys()
	for entity_id: int in ids:
		if not _active_entities.has(entity_id):
			continue

		var entity: Object = instance_from_id(entity_id)
		if not is_instance_valid(entity) or not _entities.has(entity_id):
			_erase_dictionary_key(_active_entities, entity_id)
			continue

		_process_entity(entity, p_delta)


## 释放系统持有的实体、Buff 与技能连接。
## [br]
## @api public
func dispose() -> void:
	for entity_id: int in _entities.keys():
		_remove_entity_record_by_id(entity_id, true, GFBuff.REMOVAL_REASON_DISPOSED)

	_entities.clear()
	_active_entities.clear()


# --- 公共方法 ---

## 注册战斗实体。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
func register_entity(p_entity: Object) -> void:
	if p_entity == null:
		return

	var entity_id: int = p_entity.get_instance_id()
	if _entities.has(entity_id):
		return
		
	_entities[entity_id] = {
		"buffs": [],
		"skills": [],
	}
	_update_active_status(p_entity)


## 注销战斗实体。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
func unregister_entity(p_entity: Object) -> void:
	_remove_entity_record(p_entity, true, GFBuff.REMOVAL_REASON_ENTITY_UNREGISTERED)


## 给实体添加一个 Buff。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_buff: Buff 实例。
func add_buff(p_entity: Object, p_buff: GFBuff) -> void:
	if p_buff == null or p_entity == null:
		return

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return

	p_buff.owner = p_entity
	var apply_report: Dictionary = p_buff.get_apply_report({
		"entity": p_entity,
		"system": self,
	})
	if not GFVariantData.get_option_bool(apply_report, "ok", true):
		return

	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	
	# 检查重叠逻辑 (简单的 ID 排斥/刷新)
	for existing_value: Variant in buffs:
		var existing: GFBuff = _variant_to_buff(existing_value)
		if _should_refresh_existing_buff(existing, p_buff):
			existing.owner = p_entity
			existing.refresh_from(p_buff)
			_send_combat_event(GFCombatPayloads.GFBuffRefreshedPayload.new(p_entity, existing))
			return
			
	buffs.append(p_buff)
	p_buff.on_apply()
	_send_combat_event(GFCombatPayloads.GFBuffAppliedPayload.new(p_entity, p_buff))
	
	_update_active_status(p_entity)


## 为实体添加技能。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_skill: 技能实例。
func add_skill(p_entity: Object, p_skill: GFSkill) -> void:
	if p_skill == null or p_entity == null:
		return

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return

	p_skill.owner = p_entity

	var data: Dictionary = _get_entity_data(entity_id)
	var skills: Array = _get_entity_skills(data)
	
	if not skills.has(p_skill):
		skills.append(p_skill)
		if p_skill.has_method("inject_dependencies"):
			p_skill.inject_dependencies(_get_architecture_or_null())
		_connect_skill_cooldown(p_skill)
		
	_update_active_status(p_entity)


## 获取实体上的指定 Buff。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_buff_id: Buff 标识。
## [br]
## @return 找到时返回正在系统中生效的 Buff 实例，否则返回 null。
func get_buff(p_entity: Object, p_buff_id: StringName) -> GFBuff:
	if p_entity == null:
		return null

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return null

	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	for buff_value: Variant in buffs:
		var buff: GFBuff = _variant_to_buff(buff_value)
		if buff != null and buff.id == p_buff_id:
			return buff
	return null


## 检查实体上是否存在指定 Buff。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_buff_id: Buff 标识。
## [br]
## @return 存在返回 true。
func has_buff(p_entity: Object, p_buff_id: StringName) -> bool:
	return get_buff(p_entity, p_buff_id) != null


## 获取实体当前持有的 Buff 列表副本。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @return Buff 实例数组副本；数组本身可安全修改，但元素仍是运行中的 Buff 引用。
func get_buffs(p_entity: Object) -> Array[GFBuff]:
	var result: Array[GFBuff] = []
	if p_entity == null:
		return result

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return result

	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	for buff_value: Variant in buffs:
		var buff: GFBuff = _variant_to_buff(buff_value)
		if buff != null:
			result.append(buff)
	return result


## 强制刷新指定 Buff 已挂载修饰器影响到的属性。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_buff_id: Buff 标识。
## [br]
## @return 至少刷新了一个属性时返回 true。
func refresh_buff_modifiers(p_entity: Object, p_buff_id: StringName) -> bool:
	var buff: GFBuff = get_buff(p_entity, p_buff_id)
	if buff == null:
		return false
	return _refresh_buff_modifier_attributes(buff)


## 移除实体上的指定 Buff。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_buff_id: Buff 标识。
## [br]
## @return 找到并移除 Buff 时返回 true。
func remove_buff(p_entity: Object, p_buff_id: StringName) -> bool:
	return remove_buff_with_reason(p_entity, p_buff_id, GFBuff.REMOVAL_REASON_REMOVED)


## 移除实体上的指定 Buff，并记录移除原因。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_buff_id: Buff 标识。
## [br]
## @param reason: 移除原因。
## [br]
## @return 找到并移除 Buff 时返回 true。
func remove_buff_with_reason(
	p_entity: Object,
	p_buff_id: StringName,
	reason: StringName = GFBuff.REMOVAL_REASON_REMOVED
) -> bool:
	if p_entity == null:
		return false

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return false

	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	for index: int in range(buffs.size() - 1, -1, -1):
		var buff: GFBuff = _get_buff_at(buffs, index)
		if buff != null and buff.id == p_buff_id:
			_remove_buff_at(p_entity, buffs, index, true, reason)
			_update_active_status(p_entity)
			return true
	return false


## 清理实体上的 Buff。predicate 为空时清理全部；否则仅清理返回 true 的 Buff。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param predicate: 可选过滤回调，签名为 `func(buff: GFBuff) -> bool`。
## [br]
## @return 被清理的 Buff 数量。
func clear_buffs(p_entity: Object, predicate: Callable = Callable()) -> int:
	return clear_buffs_with_reason(p_entity, predicate, GFBuff.REMOVAL_REASON_CLEARED)


## 清理实体上的 Buff，并记录移除原因。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_entity: 实体对象。
## [br]
## @param predicate: 可选过滤回调，签名为 `func(buff: GFBuff) -> bool`。
## [br]
## @param reason: 移除原因。
## [br]
## @return 被清理的 Buff 数量。
func clear_buffs_with_reason(
	p_entity: Object,
	predicate: Callable = Callable(),
	reason: StringName = GFBuff.REMOVAL_REASON_CLEARED
) -> int:
	if p_entity == null:
		return 0

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return 0

	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	var removed_count: int = 0
	for index: int in range(buffs.size() - 1, -1, -1):
		var buff: GFBuff = _get_buff_at(buffs, index)
		if buff == null:
			buffs.remove_at(index)
			continue
		if not _predicate_accepts_buff(predicate, buff):
			continue
		_remove_buff_at(p_entity, buffs, index, true, reason)
		removed_count += 1

	if removed_count > 0:
		_update_active_status(p_entity)
	return removed_count


## 移除实体上的指定技能。
## [br]
## @api public
## [br]
## @param p_entity: 实体对象。
## [br]
## @param p_skill: 技能实例。
## [br]
## @return 找到并移除技能时返回 true。
func remove_skill(p_entity: Object, p_skill: GFSkill) -> bool:
	if p_skill == null or p_entity == null:
		return false

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return false

	var data: Dictionary = _get_entity_data(entity_id)
	var skills: Array = _get_entity_skills(data)
	if not skills.has(p_skill):
		return false

	if p_skill.is_connected(&"cooldown_started", _on_skill_cooldown_started):
		p_skill.cooldown_started.disconnect(_on_skill_cooldown_started)
	skills.erase(p_skill)
	_update_active_status(p_entity)
	return true


# --- 私有/辅助方法 ---

func _get_entity_data(entity_id: int) -> Dictionary:
	if not _entities.has(entity_id):
		return {}

	var value: Variant = _entities[entity_id]
	if value is Dictionary:
		var data: Dictionary = value
		return data

	var repaired_data: Dictionary = {
		"buffs": [],
		"skills": [],
	}
	_entities[entity_id] = repaired_data
	return repaired_data


func _get_entity_buffs(data: Dictionary) -> Array:
	return _get_or_create_entity_array(data, "buffs")


func _get_entity_skills(data: Dictionary) -> Array:
	return _get_or_create_entity_array(data, "skills")


func _get_or_create_entity_array(data: Dictionary, key: String) -> Array:
	if data.has(key):
		var value: Variant = data[key]
		if value is Array:
			var array: Array = value
			return array

	var created: Array = []
	data[key] = created
	return created


func _get_buff_at(buffs: Array, index: int) -> GFBuff:
	if index < 0 or index >= buffs.size():
		return null
	return _variant_to_buff(buffs[index])


func _get_skill_at(skills: Array, index: int) -> GFSkill:
	if index < 0 or index >= skills.size():
		return null
	return _variant_to_skill(skills[index])


func _predicate_accepts_buff(predicate: Callable, buff: GFBuff) -> bool:
	if not predicate.is_valid():
		return true
	var accepted: Variant = predicate.call(buff)
	return accepted if accepted is bool else false


func _connect_skill_cooldown(skill: GFSkill) -> void:
	if skill == null or skill.is_connected(&"cooldown_started", _on_skill_cooldown_started):
		return
	var connect_result: int = skill.cooldown_started.connect(_on_skill_cooldown_started)
	if connect_result != OK:
		push_warning("[GFCombatSystem] 无法连接技能冷却信号，错误码：%s" % connect_result)


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var _removed: bool = target.erase(key)


func _variant_to_buff(value: Variant) -> GFBuff:
	if not is_instance_valid(value):
		return null
	if value is GFBuff:
		var buff: GFBuff = value
		return buff
	return null


func _variant_to_skill(value: Variant) -> GFSkill:
	if not is_instance_valid(value):
		return null
	if value is GFSkill:
		var skill: GFSkill = value
		return skill
	return null


func _variant_to_modified_attribute(value: Variant) -> GFModifiedAttribute:
	if not is_instance_valid(value):
		return null
	if value is GFModifiedAttribute:
		var attribute: GFModifiedAttribute = value
		return attribute
	return null


# 更新实体的活跃状态。
func _update_active_status(p_entity: Object) -> void:
	if not is_instance_valid(p_entity):
		return

	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		_erase_dictionary_key(_active_entities, entity_id)
		return
		
	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	var skills: Array = _get_entity_skills(data)
	
	var is_active: bool = not buffs.is_empty()
	
	if not is_active:
		for skill: GFSkill in skills:
			if skill.cooldown_left > 0.0: # 简化判定：正在 CD 中
				is_active = true
				break
				
	if is_active:
		_active_entities[entity_id] = true
	else:
		_erase_dictionary_key(_active_entities, entity_id)


func _cleanup_invalid_entities() -> void:
	for entity_id: int in _entities.keys():
		var entity: Object = instance_from_id(entity_id)
		if not is_instance_valid(entity):
			_remove_entity_record_by_id(entity_id, true, GFBuff.REMOVAL_REASON_ENTITY_UNREGISTERED)

	for entity_id: int in _active_entities.keys():
		var entity: Object = instance_from_id(entity_id)
		if not is_instance_valid(entity) or not _entities.has(entity_id):
			_erase_dictionary_key(_active_entities, entity_id)


func _remove_entity_record(
	p_entity: Object,
	remove_effects: bool,
	reason: StringName = GFBuff.REMOVAL_REASON_REMOVED
) -> void:
	if p_entity == null:
		return

	_remove_entity_record_by_id(p_entity.get_instance_id(), remove_effects, reason)


func _remove_entity_record_by_id(
	entity_id: int,
	remove_effects: bool,
	reason: StringName = GFBuff.REMOVAL_REASON_REMOVED
) -> void:
	if not _entities.has(entity_id):
		_erase_dictionary_key(_active_entities, entity_id)
		return

	var data: Dictionary = _get_entity_data(entity_id)
	_cleanup_entity_data(data, remove_effects, reason)
	_erase_dictionary_key(_entities, entity_id)
	_erase_dictionary_key(_active_entities, entity_id)


func _cleanup_entity_data(data: Dictionary, remove_effects: bool, reason: StringName) -> void:
	var buffs: Array = _get_entity_buffs(data)
	for buff_value: Variant in buffs:
		var buff: GFBuff = _variant_to_buff(buff_value)
		if buff == null:
			continue
		if remove_effects:
			buff.mark_removed(reason)
			buff.on_remove()

	var skills: Array = _get_entity_skills(data)
	for skill_value: Variant in skills:
		var skill: GFSkill = _variant_to_skill(skill_value)
		if skill == null:
			continue
		if skill.is_connected(&"cooldown_started", _on_skill_cooldown_started):
			skill.cooldown_started.disconnect(_on_skill_cooldown_started)


func _on_skill_cooldown_started(p_skill: GFSkill) -> void:
	if is_instance_valid(p_skill) and is_instance_valid(p_skill.owner):
		_update_active_status(p_skill.owner)


func _send_combat_event(event_instance: Object) -> void:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch != null and arch.has_method("send_event"):
		arch.send_event(event_instance)


func _remove_buff_at(
	p_entity: Object,
	buffs: Array,
	index: int,
	remove_effects: bool,
	reason: StringName = GFBuff.REMOVAL_REASON_REMOVED
) -> void:
	var buff: GFBuff = _get_buff_at(buffs, index)
	buffs.remove_at(index)
	if buff == null:
		return

	var removed_id: StringName = buff.id
	if remove_effects:
		buff.mark_removed(reason)
		buff.on_remove()
	_send_combat_event(GFCombatPayloads.GFBuffRemovedPayload.new(p_entity, removed_id))


func _should_refresh_existing_buff(existing: GFBuff, incoming: GFBuff) -> bool:
	if existing == null or incoming == null:
		return false
	if incoming.id == &"":
		return false
	return existing.id == incoming.id


func _refresh_buff_modifier_attributes(buff: GFBuff) -> bool:
	if buff == null or buff.owner == null or not is_instance_valid(buff.owner):
		return false
	if not buff.owner.has_method("get_attribute"):
		return false

	var refreshed_attribute_ids: Dictionary = {}
	var refreshed: bool = false
	var get_attribute: Callable = Callable(buff.owner, "get_attribute")
	for modifier: GFModifier in buff.modifiers:
		if modifier == null or modifier.attribute_id == &"":
			continue
		if refreshed_attribute_ids.has(modifier.attribute_id):
			continue

		var attr: GFModifiedAttribute = _variant_to_modified_attribute(get_attribute.call(modifier.attribute_id))
		if attr == null:
			continue

		attr.force_recalculate()
		refreshed_attribute_ids[modifier.attribute_id] = true
		refreshed = true
	return refreshed


func _process_entity(p_entity: Object, p_delta: float) -> void:
	var entity_id: int = p_entity.get_instance_id()
	if not _entities.has(entity_id):
		return

	var data: Dictionary = _get_entity_data(entity_id)
	var buffs: Array = _get_entity_buffs(data)
	var buff_index: int = buffs.size() - 1
	while buff_index >= 0:
		if buff_index >= buffs.size():
			buff_index = buffs.size() - 1
			continue

		var buff: GFBuff = _get_buff_at(buffs, buff_index)
		if buff == null:
			buffs.remove_at(buff_index)
			buff_index -= 1
			continue
		if buff.update(p_delta):
			if buff_index < buffs.size() and buffs[buff_index] == buff:
				_remove_buff_at(p_entity, buffs, buff_index, true, GFBuff.REMOVAL_REASON_EXPIRED)
			else:
				buffs.erase(buff)
				buff.mark_removed(GFBuff.REMOVAL_REASON_EXPIRED)
				buff.on_remove()
				_send_combat_event(GFCombatPayloads.GFBuffRemovedPayload.new(p_entity, buff.id))
		buff_index -= 1

	if not _entities.has(entity_id):
		return

	var skills: Array = _get_entity_skills(data)
	var skill_index: int = skills.size() - 1
	while skill_index >= 0:
		if skill_index >= skills.size():
			skill_index = skills.size() - 1
			continue
		var skill: GFSkill = _get_skill_at(skills, skill_index)
		if skill == null:
			skills.remove_at(skill_index)
			skill_index -= 1
			continue
		skill.update(p_delta)
		skill_index -= 1

	if _entities.has(entity_id):
		_update_active_status(p_entity)
