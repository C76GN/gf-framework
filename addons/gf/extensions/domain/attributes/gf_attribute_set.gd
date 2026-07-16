## GFAttributeSet: 通用数值属性集合。
##
## 用 StringName 管理一组可保存、可恢复、可限制范围的数值属性。它不规定
## 属性含义，生命值、耐久、温度、声望或任意项目数值都由项目层命名和解释。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFAttributeSet
extends Resource


# --- 信号 ---

## 属性被定义时发出。
## [br]
## @api public
## [br]
## @param attribute_id: 被定义或替换的属性 ID。
signal attribute_defined(attribute_id: StringName)

## 当前值变化时发出。
## [br]
## @api public
## [br]
## @param attribute_id: 发生变化的属性 ID。
## [br]
## @param current_value: 新当前值。
## [br]
## @param previous_value: 旧当前值。
signal attribute_changed(attribute_id: StringName, current_value: float, previous_value: float)


# --- 常量 ---

## 默认属性最小值。
## [br]
## @api public
const DEFAULT_MIN_VALUE: float = -1.0e20

## 默认属性最大值。
## [br]
## @api public
const DEFAULT_MAX_VALUE: float = 1.0e20


# --- 导出变量 ---

## 属性记录。结构为 attribute_id -> { base, current, min, max, metadata }。
## [br]
## @api public
## [br]
## @schema attributes: Dictionary，键为 StringName 属性 ID，值为包含 base: float、current: float、min: float、max: float、metadata: Dictionary 的记录。
@export var attributes: Dictionary = {}

## 派生属性规则列表。规则只计算属性值，不改变属性命名含义。
## [br]
## @api public
## [br]
## @schema derived_rules: Array[GFDerivedAttributeRule]，按顺序保存的派生属性规则资源。
@export var derived_rules: Array[GFDerivedAttributeRule] = []


# --- 私有变量 ---

var _suspend_derived_recalculation: bool = false
var _is_evaluating_derived_rule: bool = false


# --- 公共方法 ---

## 定义或替换属性。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param base_value: 基础值。
## [br]
## @param current_value: 当前值；为 null 或 NAN 时使用 base_value。
## [br]
## @param min_value: 最小值。
## [br]
## @param max_value: 最大值。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @schema current_value: Variant，null 或 NAN 表示使用 base_value，数字值会转换为 float。
## [br]
## @schema metadata: Dictionary，项目自定义属性元数据；GF 会深拷贝保存。
func define_attribute(
	attribute_id: StringName,
	base_value: float = 0.0,
	current_value: Variant = null,
	min_value: float = DEFAULT_MIN_VALUE,
	max_value: float = DEFAULT_MAX_VALUE,
	metadata: Dictionary = {}
) -> void:
	if _reject_derived_mutation("define_attribute"):
		return
	if attribute_id == &"":
		return

	var finite_min: float = _finite_or_default(min_value, DEFAULT_MIN_VALUE)
	var finite_max: float = _finite_or_default(max_value, DEFAULT_MAX_VALUE)
	var safe_min: float = minf(finite_min, finite_max)
	var safe_max: float = maxf(finite_min, finite_max)
	var safe_base: float = _finite_or_default(base_value, 0.0)
	var resolved_current: float = safe_base
	if current_value != null:
		var parsed_current: float = GFVariantData.to_float(current_value, NAN)
		resolved_current = safe_base if not _is_finite_number(parsed_current) else parsed_current
	attributes[attribute_id] = {
		"base": clampf(safe_base, safe_min, safe_max),
		"current": clampf(resolved_current, safe_min, safe_max),
		"min": safe_min,
		"max": safe_max,
		"metadata": metadata.duplicate(true),
	}
	attribute_defined.emit(attribute_id)
	_recalculate_derived_dependents(attribute_id)


## 检查属性是否存在。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @return: 存在返回 true。
func has_attribute(attribute_id: StringName) -> bool:
	return attributes.has(attribute_id)


## 移除属性。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
func remove_attribute(attribute_id: StringName) -> void:
	if _reject_derived_mutation("remove_attribute"):
		return
	var _removed_attribute: bool = attributes.erase(attribute_id)
	_recalculate_derived_dependents(attribute_id)


## 清空所有属性。
## [br]
## @api public
func clear() -> void:
	if _reject_derived_mutation("clear"):
		return
	attributes.clear()


## 设置当前值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param value: 新值。
## [br]
## @return: 成功返回 true。
func set_value(attribute_id: StringName, value: float) -> bool:
	if _reject_derived_mutation("set_value"):
		return false
	if not attributes.has(attribute_id):
		return false
	if not _is_finite_number(value):
		return false

	var record: Dictionary = _get_attribute_record(attribute_id)
	var previous_value: float = GFVariantData.get_option_float(record, "current", 0.0)
	var next_value: float = clampf(
		value,
		GFVariantData.get_option_float(record, "min", DEFAULT_MIN_VALUE),
		GFVariantData.get_option_float(record, "max", DEFAULT_MAX_VALUE)
	)
	record["current"] = next_value
	if not is_equal_approx(previous_value, next_value):
		attribute_changed.emit(attribute_id, next_value, previous_value)
		_recalculate_derived_dependents(attribute_id)
	return true


## 增减当前值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param delta: 增量。
## [br]
## @return: 成功返回 true。
func adjust_value(attribute_id: StringName, delta: float) -> bool:
	return set_value(attribute_id, get_value(attribute_id) + delta)


## 设置基础值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param value: 新基础值。
## [br]
## @param sync_current: 是否同步当前值。
## [br]
## @return: 成功返回 true。
func set_base_value(attribute_id: StringName, value: float, sync_current: bool = false) -> bool:
	if _reject_derived_mutation("set_base_value"):
		return false
	if not attributes.has(attribute_id):
		return false
	if not _is_finite_number(value):
		return false

	var record: Dictionary = _get_attribute_record(attribute_id)
	var previous_base: float = GFVariantData.get_option_float(record, "base", 0.0)
	var previous_current: float = GFVariantData.get_option_float(record, "current", 0.0)
	var next_base: float = clampf(
		value,
		GFVariantData.get_option_float(record, "min", DEFAULT_MIN_VALUE),
		GFVariantData.get_option_float(record, "max", DEFAULT_MAX_VALUE)
	)
	record["base"] = next_base
	if sync_current:
		record["current"] = next_base
		if not is_equal_approx(previous_current, next_base):
			attribute_changed.emit(attribute_id, next_base, previous_current)
	if not is_equal_approx(previous_base, next_base) or (sync_current and not is_equal_approx(previous_current, next_base)):
		_recalculate_derived_dependents(attribute_id)
	return true


## 设置属性范围。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param min_value: 最小值。
## [br]
## @param max_value: 最大值。
## [br]
## @return: 成功返回 true。
func set_limits(attribute_id: StringName, min_value: float, max_value: float) -> bool:
	if _reject_derived_mutation("set_limits"):
		return false
	if not attributes.has(attribute_id):
		return false
	if not _is_finite_number(min_value) or not _is_finite_number(max_value):
		return false

	var record: Dictionary = _get_attribute_record(attribute_id)
	var previous_min: float = GFVariantData.get_option_float(record, "min", DEFAULT_MIN_VALUE)
	var previous_max: float = GFVariantData.get_option_float(record, "max", DEFAULT_MAX_VALUE)
	var previous_base: float = GFVariantData.get_option_float(record, "base", 0.0)
	var previous_current: float = GFVariantData.get_option_float(record, "current", 0.0)
	var next_min: float = minf(min_value, max_value)
	var next_max: float = maxf(min_value, max_value)
	var next_base: float = clampf(previous_base, next_min, next_max)
	var next_current: float = clampf(previous_current, next_min, next_max)
	record["min"] = next_min
	record["max"] = next_max
	record["base"] = next_base
	record["current"] = next_current
	if not is_equal_approx(previous_current, next_current):
		attribute_changed.emit(attribute_id, next_current, previous_current)
	if (
		not is_equal_approx(previous_min, next_min)
		or not is_equal_approx(previous_max, next_max)
		or not is_equal_approx(previous_base, next_base)
		or not is_equal_approx(previous_current, next_current)
	):
		_recalculate_derived_dependents(attribute_id)
	return true


## 获取当前值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param default_value: 默认值。
## [br]
## @return: 当前值。
func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:
	if not attributes.has(attribute_id):
		return default_value
	var record: Dictionary = _get_attribute_record(attribute_id)
	return GFVariantData.get_option_float(record, "current", default_value)


## 获取基础值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param default_value: 默认值。
## [br]
## @return: 基础值。
func get_base_value(attribute_id: StringName, default_value: float = 0.0) -> float:
	if not attributes.has(attribute_id):
		return default_value
	var record: Dictionary = _get_attribute_record(attribute_id)
	return GFVariantData.get_option_float(record, "base", default_value)


## 通过 TraitSet 计算属性值。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param trait_set: 特征集合。
## [br]
## @return: Trait 修饰后的值。
func get_value_with_traits(attribute_id: StringName, trait_set: GFTraitSet) -> float:
	var value: float = get_value(attribute_id)
	if trait_set == null:
		return value
	return trait_set.calculate_number(attribute_id, value)


## 获取属性元数据。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @return: 元数据副本。
## [br]
## @schema return: Dictionary，属性的项目自定义 metadata 副本；属性不存在时为空字典。
func get_metadata(attribute_id: StringName) -> Dictionary:
	if not attributes.has(attribute_id):
		return {}
	var record: Dictionary = _get_attribute_record(attribute_id)
	return GFVariantData.get_option_dictionary(record, "metadata")


## 设置属性元数据。
## [br]
## @api public
## [br]
## @param attribute_id: 属性标识。
## [br]
## @param metadata: 元数据。
## [br]
## @return: 成功返回 true。
## [br]
## @schema metadata: Dictionary，项目自定义属性元数据；GF 会深拷贝保存。
func set_metadata(attribute_id: StringName, metadata: Dictionary) -> bool:
	if _reject_derived_mutation("set_metadata"):
		return false
	if not attributes.has(attribute_id):
		return false
	var record: Dictionary = _get_attribute_record(attribute_id)
	record["metadata"] = metadata.duplicate(true)
	return true


## 添加或替换派生属性规则。
## [br]
## @api public
## [br]
## @param rule: 派生属性规则。
## [br]
## @return: 成功返回 true。
func add_derived_rule(rule: GFDerivedAttributeRule) -> bool:
	if _reject_derived_mutation("add_derived_rule"):
		return false
	if rule == null or rule.attribute_id == &"":
		return false

	var _removed_previous_rule: bool = remove_derived_rule(rule.attribute_id)
	derived_rules.append(rule)
	recalculate_derived(rule.attribute_id)
	return true


## 移除指定目标属性的派生规则。
## [br]
## @api public
## [br]
## @param attribute_id: 目标属性 ID。
## [br]
## @return: 至少移除一个规则时返回 true。
func remove_derived_rule(attribute_id: StringName) -> bool:
	if _reject_derived_mutation("remove_derived_rule"):
		return false
	var removed: bool = false
	for index: int in range(derived_rules.size() - 1, -1, -1):
		var rule: GFDerivedAttributeRule = derived_rules[index]
		if rule != null and rule.attribute_id == attribute_id:
			derived_rules.remove_at(index)
			removed = true
	return removed


## 获取指定目标属性的派生规则。
## [br]
## @api public
## [br]
## @param attribute_id: 目标属性 ID。
## [br]
## @return: 派生规则；不存在时返回 null。
func get_derived_rule(attribute_id: StringName) -> GFDerivedAttributeRule:
	for rule: GFDerivedAttributeRule in derived_rules:
		if rule != null and rule.attribute_id == attribute_id:
			return rule
	return null


## 重新计算派生属性。
## [br]
## @api public
## [br]
## @param attribute_id: 目标属性 ID；为空时重算全部规则。
func recalculate_derived(attribute_id: StringName = &"") -> void:
	if _reject_derived_mutation("recalculate_derived"):
		return
	if _suspend_derived_recalculation:
		return

	var cycle_targets: Dictionary = _get_derived_cycle_targets()
	if attribute_id != &"":
		var rule: GFDerivedAttributeRule = get_derived_rule(attribute_id)
		if rule != null:
			var _target_rule_applied: bool = _apply_derived_rule(rule, {}, cycle_targets)
		return

	for rule: GFDerivedAttributeRule in derived_rules:
		var _rule_applied: bool = _apply_derived_rule(rule, {}, cycle_targets)


## 导出快照。
## [br]
## @api public
## [br]
## @return: 可序列化字典。
## [br]
## @schema return: Dictionary，键为 String 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。
func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for attribute_id_variant: Variant in attributes.keys():
		var record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(attributes, attribute_id_variant, {}))
		if record.is_empty():
			continue
		snapshot[GFVariantData.to_text(attribute_id_variant)] = record.duplicate(true)
	return snapshot


## 从快照恢复。
## [br]
## @api public
## [br]
## @param snapshot: 由 get_snapshot() 或 to_dict() 返回的数据。
## [br]
## @schema snapshot: Dictionary，键为 String 或 StringName 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。
func restore_snapshot(snapshot: Dictionary) -> void:
	if _reject_derived_mutation("restore_snapshot"):
		return
	_suspend_derived_recalculation = true
	attributes.clear()
	for attribute_id_variant: Variant in snapshot.keys():
		var attribute_id: StringName = GFVariantData.to_string_name(attribute_id_variant)
		var record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, attribute_id_variant, {}))
		if attribute_id == &"" or record.is_empty():
			continue
		var metadata: Dictionary = GFVariantData.get_option_dictionary(record, "metadata")
		define_attribute(
			attribute_id,
			GFVariantData.get_option_float(record, "base", 0.0),
			GFVariantData.get_option_float(record, "current", GFVariantData.get_option_float(record, "base", 0.0)),
			GFVariantData.get_option_float(record, "min", DEFAULT_MIN_VALUE),
			GFVariantData.get_option_float(record, "max", DEFAULT_MAX_VALUE),
			metadata
		)
	_suspend_derived_recalculation = false
	recalculate_derived()


## 序列化为字典。
## [br]
## @api public
## [br]
## @return: 可序列化字典。
## [br]
## @schema return: Dictionary，键为 String 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。
func to_dict() -> Dictionary:
	return get_snapshot()


## 从字典恢复。
## [br]
## @api public
## [br]
## @param data: 属性数据。
## [br]
## @schema data: Dictionary，键为 String 或 StringName 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。
func from_dict(data: Dictionary) -> void:
	restore_snapshot(data)


# --- 私有/辅助方法 ---

func _get_attribute_record(attribute_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(attributes, attribute_id, {}))


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _finite_or_default(value: float, default_value: float) -> float:
	return value if _is_finite_number(value) else default_value


func _recalculate_derived_dependents(source_attribute_id: StringName, visited: Dictionary = {}) -> void:
	if _suspend_derived_recalculation:
		return

	var cycle_targets: Dictionary = _get_derived_cycle_targets()
	for rule: GFDerivedAttributeRule in derived_rules:
		if rule != null and rule.depends_on(source_attribute_id):
			var _dependent_rule_applied: bool = _apply_derived_rule(rule, visited, cycle_targets)


func _apply_derived_rule(
	rule: GFDerivedAttributeRule,
	visited: Dictionary,
	cycle_targets: Dictionary = {}
) -> bool:
	if rule == null or rule.attribute_id == &"":
		return false
	if cycle_targets.has(rule.attribute_id):
		push_warning("[GFAttributeSet] 检测到派生属性循环，已跳过：" + String(rule.attribute_id))
		return false
	if GFVariantData.get_option_bool(visited, rule.attribute_id, false):
		push_warning("[GFAttributeSet] 检测到派生属性循环，已跳过：" + String(rule.attribute_id))
		return false

	visited[rule.attribute_id] = true
	var was_evaluating: bool = _is_evaluating_derived_rule
	_is_evaluating_derived_rule = true
	var next_value: float = rule.calculate(self)
	_is_evaluating_derived_rule = was_evaluating
	var did_change: bool = _write_derived_value(rule, next_value)
	if did_change:
		_recalculate_derived_dependents(rule.attribute_id, visited)
	var _visited_removed: bool = visited.erase(rule.attribute_id)
	return did_change


func _reject_derived_mutation(method_name: String) -> bool:
	if not _is_evaluating_derived_rule:
		return false
	push_warning("[GFAttributeSet] %s 失败：派生规则计算期间不允许修改同一个属性集合。" % method_name)
	return true


func _get_derived_cycle_targets() -> Dictionary:
	var rule_map: Dictionary = _get_derived_rule_map()
	var states: Dictionary = {}
	var cycle_targets: Dictionary = {}
	for target_id: StringName in _get_sorted_string_name_keys(rule_map):
		if GFVariantData.get_option_int(states, target_id, 0) == 0:
			_visit_derived_rule_for_cycles(target_id, rule_map, states, [], cycle_targets)
	return cycle_targets


func _get_derived_rule_map() -> Dictionary:
	var result: Dictionary = {}
	for rule: GFDerivedAttributeRule in derived_rules:
		if rule != null and rule.attribute_id != &"":
			result[rule.attribute_id] = rule
	return result


func _visit_derived_rule_for_cycles(
	attribute_id: StringName,
	rule_map: Dictionary,
	states: Dictionary,
	stack: Array[StringName],
	cycle_targets: Dictionary
) -> void:
	states[attribute_id] = 1
	stack.append(attribute_id)
	var rule: GFDerivedAttributeRule = _get_derived_rule_from_map(rule_map, attribute_id)
	if rule != null:
		for source_id: StringName in rule.get_source_attribute_ids():
			if not rule_map.has(source_id):
				continue
			var source_state: int = GFVariantData.get_option_int(states, source_id, 0)
			if source_state == 1:
				_mark_derived_cycle_targets(source_id, stack, cycle_targets)
				continue
			if source_state == 0:
				_visit_derived_rule_for_cycles(source_id, rule_map, states, stack, cycle_targets)
	stack.pop_back()
	states[attribute_id] = 2


func _mark_derived_cycle_targets(
	first_repeated_attribute_id: StringName,
	stack: Array[StringName],
	cycle_targets: Dictionary
) -> void:
	var include: bool = false
	for attribute_id: StringName in stack:
		if attribute_id == first_repeated_attribute_id:
			include = true
		if include:
			cycle_targets[attribute_id] = true


func _get_derived_rule_from_map(rule_map: Dictionary, attribute_id: StringName) -> GFDerivedAttributeRule:
	var value: Variant = GFVariantData.get_option_value(rule_map, attribute_id)
	if value is GFDerivedAttributeRule:
		var rule: GFDerivedAttributeRule = value
		return rule
	return null


func _get_sorted_string_name_keys(dictionary: Dictionary) -> Array[StringName]:
	var values: PackedStringArray = PackedStringArray()
	for key: Variant in dictionary.keys():
		var _append_result: Variant = values.append(GFVariantData.to_text(key))
	values.sort()
	var result: Array[StringName] = []
	for value: String in values:
		result.append(StringName(value))
	return result


func _write_derived_value(rule: GFDerivedAttributeRule, value: float) -> bool:
	if not _is_finite_number(value):
		return false

	if not attributes.has(rule.attribute_id):
		define_attribute(rule.attribute_id, value, value, rule.min_value, rule.max_value)
		return true

	var record: Dictionary = _get_attribute_record(rule.attribute_id)
	if record.is_empty():
		return false

	var previous_value: float = GFVariantData.get_option_float(record, "current", 0.0)
	var next_value: float = clampf(
		value,
		GFVariantData.get_option_float(record, "min", DEFAULT_MIN_VALUE),
		GFVariantData.get_option_float(record, "max", DEFAULT_MAX_VALUE)
	)
	if rule.sync_base_value:
		record["base"] = next_value
	record["current"] = next_value
	if not is_equal_approx(previous_value, next_value):
		attribute_changed.emit(rule.attribute_id, next_value, previous_value)
		return true
	return false
