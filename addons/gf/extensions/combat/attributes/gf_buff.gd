## GFBuff: 状态效果基类。
##
## 管理 Buff 的生命周期、层数以及对属性/标签的影响。
## 在 GFCombatSystem 的 tick 中驱动 update。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFBuff
extends RefCounted


# --- 枚举 ---

## 重复添加同 ID Buff 时的层数策略。
## [br]
## @api public
enum StackMode {
	## 只刷新持续时间，不改变层数。
	REFRESH_ONLY,
	## 刷新持续时间，并在 max_stacks 允许时增加层数。
	ADD_STACK,
	## 忽略重复添加，不刷新持续时间或层数。
	IGNORE,
}

## 重复添加同 ID Buff 时的持续时间刷新策略。
## [br]
## @api public
enum DurationRefreshPolicy {
	## 保持当前剩余时间。
	KEEP_CURRENT,
	## 使用新的持续时间重置剩余时间。
	RESET_TO_NEW_DURATION,
	## 将新的持续时间追加到当前剩余时间。
	EXTEND_BY_NEW_DURATION,
	## 保留当前剩余时间与新持续时间中较长者。
	KEEP_LONGER_REMAINING,
}


# --- 常量 ---

## Buff 因持续时间耗尽而移除。
## [br]
## @api public
## [br]
## @since 6.0.0
const REMOVAL_REASON_EXPIRED: StringName = &"expired"

## Buff 被显式移除。
## [br]
## @api public
## [br]
## @since 6.0.0
const REMOVAL_REASON_REMOVED: StringName = &"removed"

## Buff 被批量清理。
## [br]
## @api public
## [br]
## @since 6.0.0
const REMOVAL_REASON_CLEARED: StringName = &"cleared"

## Buff 随实体注销而移除。
## [br]
## @api public
## [br]
## @since 6.0.0
const REMOVAL_REASON_ENTITY_UNREGISTERED: StringName = &"entity_unregistered"

## Buff 随系统释放而移除。
## [br]
## @api public
## [br]
## @since 6.0.0
const REMOVAL_REASON_DISPOSED: StringName = &"disposed"


# --- 公共变量 ---

## Buff 的唯一标识名（通常用于排斥逻辑）。
## [br]
## @api public
var id: StringName = &""

## Buff 的总持续时间（秒）。如果为 -1 则视为永久 Buff。
## [br]
## @api public
var duration: float = 0.0

## 当前剩余剩余时间。
## [br]
## @api public
var time_left: float = 0.0

## 当前层数。
## [br]
## @api public
var stacks: int = 1

## 最大层数。
## [br]
## @api public
var max_stacks: int = 1

## 重复添加同 ID Buff 时的层数策略。
## [br]
## @api public
var stack_mode: StackMode = StackMode.ADD_STACK

## 重复添加同 ID Buff 时的持续时间刷新策略。
## [br]
## @api public
var duration_refresh_policy: DurationRefreshPolicy = DurationRefreshPolicy.RESET_TO_NEW_DURATION

## 周期 Tick 间隔。小于等于 0 时保持每帧调用 on_tick() 的旧行为。
## [br]
## @api public
var tick_interval_seconds: float = 0.0

## 单次 update 允许补偿触发的最大周期 Tick 次数。小于等于 0 时不限制。
## [br]
## @api public
var max_periodic_ticks_per_update: int = 8

## 持续时间耗尽时是否由 CombatSystem 移除。
## [br]
## @api public
var remove_on_expire: bool = true

## Buff 携带的属性修饰器列表。应用时会自动挂载到宿主的 Attribute 上。
## [br]
## @api public
var modifiers: Array[GFModifier] = []

## Buff 携带的标签列表。应用时会自动挂载到宿主的 TagComponent 上。
## [br]
## @api public
var tags: Array[StringName] = []

## Buff 的拥有者（通常是一个持有 Combat 数据的 Object）。
## [br]
## @api public
var owner: Object = null

## Buff 应用前检查列表。全部通过后才会应用。
## [br]
## @api public
## [br]
## @since 6.0.0
var checks: Array[GFBuffCheck] = []

## Buff 生命周期效果列表。
## [br]
## @api public
## [br]
## @since 6.0.0
var effects: Array[GFBuffEffect] = []

## 项目自定义元数据。GF 不解释该字段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary project-defined buff metadata.
var metadata: Dictionary = {}

## 最近一次移除原因。
## [br]
## @api public
## [br]
## @since 6.0.0
var removal_reason: StringName = &""


# --- 私有变量 ---

var _tick_accumulator: float = 0.0
var _effects_applied: bool = false


# --- 公共方法 ---

## 初始化 Buff，由系统或工厂调用。
## [br]
## @api public
## [br]
## @param p_id: Buff 标识。
## [br]
## @param p_duration: Buff 持续时间（秒）。
## [br]
## @param p_owner: Buff 所属对象。
func setup(p_id: StringName, p_duration: float, p_owner: Object) -> void:
	id = p_id
	duration = p_duration
	time_left = duration
	owner = p_owner
	removal_reason = &""
	_tick_accumulator = 0.0


## 获取应用检查报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param context: 可选应用上下文。
## [br]
## @return 检查报告。
## [br]
## @schema context: Dictionary merged into the default buff apply context.
## [br]
## @schema return: Dictionary with ok, reason, buff_id, failed_check_id, metadata, and issues.
func get_apply_report(context: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_apply_report(context)
	for check: GFBuffCheck in checks:
		if check == null:
			continue
		var check_report: Dictionary = check.can_apply(_make_lifecycle_context(&"apply_check", context))
		if GFVariantData.get_option_bool(check_report, "ok", true):
			var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")
			var check_metadata: Dictionary = GFVariantData.get_option_dictionary(check_report, "metadata")
			var _metadata_merge: Dictionary = GFVariantData.merge_dictionary(report_metadata, check_metadata, true, true)
			report["metadata"] = report_metadata
			continue

		var failed_reason: StringName = GFVariantData.get_option_string_name(check_report, "reason", &"buff_check_failed")
		report["ok"] = false
		report["reason"] = failed_reason
		report["failed_check_id"] = GFVariantData.get_option_string_name(check_report, "check_id")
		var issue: Dictionary = {
			"severity": "error",
			"kind": String(failed_reason),
			"message": "buff check failed",
			"key": id,
			"row_key": report["failed_check_id"],
			"metadata": GFVariantData.get_option_dictionary(check_report, "metadata"),
		}
		var report_issues: Array = GFVariantData.get_option_array(report, "issues")
		report_issues.append(issue)
		report["issues"] = report_issues
		return report
	return report


## 当 Buff 首次应用时触发。
## [br]
## @api public
## [br]
## @return 生命周期报告；`ok=false` 时表示应用失败且内置效果已回滚。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.
func on_apply() -> Dictionary:
	if _effects_applied:
		_remove_effects()
		_effects_applied = false
	_apply_effects()
	_effects_applied = true
	var reports: Array[Dictionary] = _run_apply_effects()
	var report: Dictionary = _make_lifecycle_report(&"apply", reports)
	if not GFVariantData.get_option_bool(report, "ok", false):
		_remove_effects()
		_effects_applied = false
	return report


## 当 Buff 被移除时触发。
## [br]
## @api public
## [br]
## @return 生命周期报告；移除会尽力清理内置效果，即使自定义效果报告失败。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.
func on_remove() -> Dictionary:
	var reports: Array[Dictionary] = _run_effects(&"remove", { "reason": removal_reason })
	if _effects_applied:
		_remove_effects()
		_effects_applied = false
	return _make_lifecycle_report(&"remove", reports)


## 当 Buff 层数增加时触发（通常用于刷新持续时间）。
## [br]
## @api public
## [br]
## @param p_new_duration: 刷新后的持续时间（秒）。
## [br]
## @return 生命周期报告；`changed=false` 表示本次刷新未改变运行状态。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.
func on_refresh(p_new_duration: float) -> Dictionary:
	if stack_mode == StackMode.IGNORE:
		return _make_lifecycle_report(&"refresh", [], false)

	var previous_duration: float = duration
	var previous_time_left: float = time_left
	var previous_stacks: int = stacks
	_apply_refresh_duration(p_new_duration)
	if stack_mode == StackMode.ADD_STACK and max_stacks > 1:
		stacks = mini(stacks + 1, max_stacks)
	var stack_delta: int = maxi(0, stacks - previous_stacks)
	if _effects_applied and stack_delta > 0:
		_apply_effects(stack_delta)
	var reports: Array[Dictionary] = _run_effects(&"refresh", { "refresh_duration": p_new_duration })
	var report: Dictionary = _make_lifecycle_report(&"refresh", reports, _refresh_changed(previous_duration, previous_time_left, previous_stacks))
	if not GFVariantData.get_option_bool(report, "ok", false):
		if _effects_applied and stack_delta > 0:
			_remove_effects(stack_delta)
		duration = previous_duration
		time_left = previous_time_left
		stacks = previous_stacks
		report["changed"] = false
	return report


## 使用同 ID 的新 Buff 刷新当前运行中实例。
## [br]
## @api public
## [br]
## @param source_buff: 本次尝试添加的新 Buff。
## [br]
## @return 生命周期报告；`changed=false` 表示本次刷新被策略忽略。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.
func refresh_from(source_buff: GFBuff) -> Dictionary:
	if source_buff == null:
		return _make_lifecycle_report(&"refresh", [], false)
	return on_refresh(source_buff.duration)


## 周期性触发逻辑。
## [br]
## @api public
## [br]
## @param _p_delta: 帧间隔。
func on_tick(_p_delta: float) -> void:
	var _reports: Array[Dictionary] = _run_effects(&"tick", { "delta": _p_delta })


## 内部状态更新流程。
## [br]
## @api public
## [br]
## @param p_delta: 帧间隔。
## [br]
## @return 如果 Buff 已耗尽生命周期需要被移除，则返回 true。
func update(p_delta: float) -> bool:
	var step_delta: float = maxf(0.0, p_delta)
	if duration != -1.0:
		time_left -= step_delta

	_update_periodic_tick(step_delta)
	if duration != -1.0 and time_left <= 0.0:
		if remove_on_expire:
			return true
		time_left = 0.0
	return false


## 标记移除原因。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param reason: 移除原因。
func mark_removed(reason: StringName = REMOVAL_REASON_REMOVED) -> void:
	removal_reason = reason if reason != &"" else REMOVAL_REASON_REMOVED


## 获取运行时状态快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 状态快照。
## [br]
## @schema return: Dictionary with generic buff runtime state, modifiers, tags, metadata, and effect_states.
func get_state_snapshot() -> Dictionary:
	return {
		"id": id,
		"duration": duration,
		"time_left": time_left,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"stack_mode": stack_mode,
		"duration_refresh_policy": duration_refresh_policy,
		"tick_interval_seconds": tick_interval_seconds,
		"max_periodic_ticks_per_update": max_periodic_ticks_per_update,
		"remove_on_expire": remove_on_expire,
		"tick_accumulator": _tick_accumulator,
		"removal_reason": removal_reason,
		"tags": tags.duplicate(),
		"modifiers": _modifiers_to_dictionaries(),
		"metadata": metadata.duplicate(true),
		"effect_states": _get_effect_state_snapshots(),
	}


## 恢复运行时状态快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param snapshot: 状态快照。
## [br]
## @param owner_override: 可选 owner 覆盖；为空时保留当前 owner。
## [br]
## @schema snapshot: Dictionary returned by get_state_snapshot().
func restore_state_snapshot(snapshot: Dictionary, owner_override: Object = null) -> void:
	var was_applied: bool = _effects_applied
	if was_applied:
		_remove_effects()
		_effects_applied = false

	id = GFVariantData.get_option_string_name(snapshot, "id", id)
	duration = GFVariantData.get_option_float(snapshot, "duration", duration)
	time_left = GFVariantData.get_option_float(snapshot, "time_left", time_left)
	stacks = maxi(GFVariantData.get_option_int(snapshot, "stacks", stacks), 1)
	max_stacks = maxi(GFVariantData.get_option_int(snapshot, "max_stacks", max_stacks), 1)
	stack_mode = _int_to_stack_mode(GFVariantData.get_option_int(snapshot, "stack_mode", stack_mode))
	duration_refresh_policy = _int_to_duration_refresh_policy(
		GFVariantData.get_option_int(snapshot, "duration_refresh_policy", duration_refresh_policy)
	)
	tick_interval_seconds = GFVariantData.get_option_float(snapshot, "tick_interval_seconds", tick_interval_seconds)
	max_periodic_ticks_per_update = GFVariantData.get_option_int(
		snapshot,
		"max_periodic_ticks_per_update",
		max_periodic_ticks_per_update
	)
	remove_on_expire = GFVariantData.get_option_bool(snapshot, "remove_on_expire", remove_on_expire)
	_tick_accumulator = GFVariantData.get_option_float(snapshot, "tick_accumulator", _tick_accumulator)
	removal_reason = GFVariantData.get_option_string_name(snapshot, "removal_reason", removal_reason)
	tags = GFVariantData.get_option_string_name_array(snapshot, "tags", tags)
	modifiers = _dictionaries_to_modifiers(GFVariantData.get_option_array(snapshot, "modifiers"))
	metadata = GFVariantData.get_option_dictionary(snapshot, "metadata", metadata)
	if owner_override != null:
		owner = owner_override
	_restore_effect_state_snapshots(GFVariantData.get_option_array(snapshot, "effect_states"))
	if was_applied:
		_apply_effects()
		_effects_applied = true


# --- 私有/辅助方法 ---

func _make_apply_report(context: Dictionary) -> Dictionary:
	var report_metadata: Dictionary = metadata.duplicate(true)
	var context_metadata: Dictionary = GFVariantData.get_option_dictionary(context, "metadata")
	var _metadata_merge: Dictionary = GFVariantData.merge_dictionary(report_metadata, context_metadata, true, true)
	return {
		"ok": true,
		"reason": &"",
		"buff_id": id,
		"failed_check_id": &"",
		"metadata": report_metadata,
		"issues": [],
	}


func _make_lifecycle_context(event_name: StringName, extra: Dictionary = {}) -> Dictionary:
	var context: Dictionary = {
		"buff": self,
		"owner": _get_valid_owner(),
		"event": event_name,
		"buff_id": id,
		"stacks": stacks,
		"time_left": time_left,
		"duration": duration,
		"metadata": metadata.duplicate(true),
	}
	var _extra_merge: Dictionary = GFVariantData.merge_dictionary(context, extra, true, true)
	return context


func _run_apply_effects() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var context: Dictionary = _make_lifecycle_context(&"apply")
	var applied_effects: Array[GFBuffEffect] = []
	for effect: GFBuffEffect in effects:
		if effect == null:
			continue
		var report: Dictionary = effect.apply(context)
		reports.append(report)
		if GFVariantData.get_option_bool(report, "ok", true):
			applied_effects.append(effect)
			continue

		_rollback_applied_effects(applied_effects, report)
		break
	return reports


func _run_effects(event_name: StringName, extra: Dictionary = {}) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var context: Dictionary = _make_lifecycle_context(event_name, extra)
	for effect: GFBuffEffect in effects:
		if effect == null:
			continue
		var report: Dictionary = {}
		match event_name:
			&"apply":
				report = effect.apply(context)
			&"remove":
				report = effect.remove(context)
			&"refresh":
				report = effect.refresh(context)
			&"tick":
				report = effect.tick(context)
			_:
				report = { "ok": true }
		reports.append(report)
	return reports


func _rollback_applied_effects(applied_effects: Array[GFBuffEffect], failed_report: Dictionary) -> void:
	if applied_effects.is_empty():
		return
	var reason: StringName = GFVariantData.get_option_string_name(failed_report, "reason", &"apply_failed")
	var rollback_context: Dictionary = _make_lifecycle_context(&"remove", {
		"reason": reason,
		"rollback_event": &"apply",
	})
	for effect_index: int in range(applied_effects.size() - 1, -1, -1):
		var effect: GFBuffEffect = applied_effects[effect_index]
		if effect == null:
			continue
		var _rollback_report: Dictionary = effect.remove(rollback_context)


func _make_lifecycle_report(
	event_name: StringName,
	effect_reports: Array[Dictionary],
	changed: bool = true
) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"reason": &"",
		"event": event_name,
		"buff_id": id,
		"changed": changed,
		"failed_effect_id": &"",
		"metadata": metadata.duplicate(true),
		"effect_reports": effect_reports.duplicate(true),
	}
	for effect_report: Dictionary in effect_reports:
		if GFVariantData.get_option_bool(effect_report, "ok", true):
			continue
		result["ok"] = false
		result["reason"] = GFVariantData.get_option_string_name(effect_report, "reason", &"buff_effect_failed")
		result["failed_effect_id"] = GFVariantData.get_option_string_name(effect_report, "effect_id")
		return result
	return result


func _refresh_changed(previous_duration: float, previous_time_left: float, previous_stacks: int) -> bool:
	if duration != previous_duration:
		return true
	if time_left != previous_time_left:
		return true
	return stacks != previous_stacks


func _modifiers_to_dictionaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier: GFModifier in modifiers:
		if modifier == null:
			continue
		result.append(modifier.to_dictionary())
	return result


func _dictionaries_to_modifiers(entries: Array) -> Array[GFModifier]:
	var result: Array[GFModifier] = []
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		result.append(GFModifier.from_dictionary(entry))
	return result


func _get_effect_state_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_index: int in range(effects.size()):
		var effect: GFBuffEffect = effects[effect_index]
		if effect == null:
			continue
		result.append({
			"index": effect_index,
			"effect_id": effect.effect_id,
			"state": effect.get_state_snapshot(),
		})
	return result


func _restore_effect_state_snapshots(effect_states: Array) -> void:
	for state_value: Variant in effect_states:
		if not state_value is Dictionary:
			continue
		var state_entry: Dictionary = state_value
		var effect_index: int = GFVariantData.get_option_int(state_entry, "index", -1)
		if effect_index < 0 or effect_index >= effects.size():
			continue
		var effect: GFBuffEffect = effects[effect_index]
		if effect == null:
			continue
		effect.restore_state_snapshot(GFVariantData.get_option_dictionary(state_entry, "state"))


func _int_to_stack_mode(value: int) -> StackMode:
	match clampi(value, StackMode.REFRESH_ONLY, StackMode.IGNORE):
		StackMode.REFRESH_ONLY:
			return StackMode.REFRESH_ONLY
		StackMode.IGNORE:
			return StackMode.IGNORE
		_:
			return StackMode.ADD_STACK


func _int_to_duration_refresh_policy(value: int) -> DurationRefreshPolicy:
	match clampi(value, DurationRefreshPolicy.KEEP_CURRENT, DurationRefreshPolicy.KEEP_LONGER_REMAINING):
		DurationRefreshPolicy.KEEP_CURRENT:
			return DurationRefreshPolicy.KEEP_CURRENT
		DurationRefreshPolicy.EXTEND_BY_NEW_DURATION:
			return DurationRefreshPolicy.EXTEND_BY_NEW_DURATION
		DurationRefreshPolicy.KEEP_LONGER_REMAINING:
			return DurationRefreshPolicy.KEEP_LONGER_REMAINING
		_:
			return DurationRefreshPolicy.RESET_TO_NEW_DURATION

func _apply_refresh_duration(p_new_duration: float) -> void:
	match duration_refresh_policy:
		DurationRefreshPolicy.KEEP_CURRENT:
			return
		DurationRefreshPolicy.EXTEND_BY_NEW_DURATION:
			_extend_duration(p_new_duration)
		DurationRefreshPolicy.KEEP_LONGER_REMAINING:
			_keep_longer_duration(p_new_duration)
		_:
			duration = p_new_duration
			time_left = p_new_duration


func _extend_duration(p_new_duration: float) -> void:
	duration = p_new_duration
	if time_left == -1.0 or p_new_duration == -1.0:
		duration = -1.0
		time_left = -1.0
		return

	time_left += maxf(0.0, p_new_duration)


func _keep_longer_duration(p_new_duration: float) -> void:
	if time_left == -1.0 or p_new_duration == -1.0:
		duration = -1.0
		time_left = -1.0
		return

	duration = maxf(duration, p_new_duration)
	time_left = maxf(time_left, p_new_duration)


func _update_periodic_tick(p_delta: float) -> void:
	if tick_interval_seconds <= 0.0:
		on_tick(p_delta)
		return

	_tick_accumulator += p_delta
	var tick_budget: int = max_periodic_ticks_per_update
	var tick_count: int = 0
	while _tick_accumulator >= tick_interval_seconds and (tick_budget <= 0 or tick_count < tick_budget):
		_tick_accumulator -= tick_interval_seconds
		on_tick(tick_interval_seconds)
		tick_count += 1
	if tick_budget > 0 and tick_count >= tick_budget and _tick_accumulator >= tick_interval_seconds:
		_tick_accumulator = minf(_tick_accumulator, tick_interval_seconds)


# 应用 Buff 携带的所有效果。
func _apply_effects(count: int = -1) -> void:
	var effect_count: int = _get_effect_stack_count(count)
	var valid_owner: Object = _get_valid_owner()
	if valid_owner == null:
		return

	if valid_owner.has_method("get_tag_component"):
		var tag_component: GFTagComponent = _get_tag_component_value(valid_owner.call("get_tag_component"))
		if tag_component != null:
			for tag: StringName in tags:
				tag_component.add_tag(tag, effect_count)

	if valid_owner.has_method("get_attribute"):
		for mod: GFModifier in modifiers:
			if mod == null or mod.attribute_id == &"":
				continue

			var attribute: GFModifiedAttribute = _get_modified_attribute_value(valid_owner.call("get_attribute", mod.attribute_id))
			if attribute != null:
				for _stack_index: int in range(effect_count):
					attribute.add_modifier(mod)


# 移除 Buff 携带的所有效果。
func _remove_effects(count: int = -1) -> void:
	var effect_count: int = _get_effect_stack_count(count)
	var valid_owner: Object = _get_valid_owner()
	if valid_owner == null:
		return

	if valid_owner.has_method("get_tag_component"):
		var tag_component: GFTagComponent = _get_tag_component_value(valid_owner.call("get_tag_component"))
		if tag_component != null:
			for tag: StringName in tags:
				tag_component.remove_tag(tag, effect_count)

	if valid_owner.has_method("get_attribute"):
		for mod: GFModifier in modifiers:
			if mod == null or mod.attribute_id == &"":
				continue

			var attribute: GFModifiedAttribute = _get_modified_attribute_value(valid_owner.call("get_attribute", mod.attribute_id))
			if attribute != null:
				for _stack_index: int in range(effect_count):
					attribute.remove_modifier(mod)


func _get_effect_stack_count(count: int) -> int:
	if count > 0:
		return count
	return maxi(1, stacks)


func _get_valid_owner() -> Object:
	if owner == null or not is_instance_valid(owner):
		return null
	return owner


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
