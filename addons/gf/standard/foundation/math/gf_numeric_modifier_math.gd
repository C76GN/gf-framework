## GFNumericModifierMath: 通用数值修饰计算工具。
##
## 按 priority 顺序把 add / multiply / divide 修饰应用到基础数值上，并返回结构化报告。
## 该类只处理纯数值计算，不绑定属性、装备、Buff、经济或任意项目业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFNumericModifierMath
extends RefCounted


# --- 枚举 ---

## 支持的数值修饰操作。
## [br]
## @api public
## [br]
## @since 7.0.0
enum Operation {
	## 把修饰值加到当前值上。
	ADD,
	## 把当前值乘以修饰值。
	MULTIPLY,
	## 把当前值除以修饰值；除零会被报告并跳过。
	DIVIDE,
}


# --- 公共方法 ---

## 创建通用数值修饰字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 修饰数值。
## [br]
## @param operation: 修饰操作。
## [br]
## @param priority: 应用优先级；数值越小越早应用。
## [br]
## @param enabled: 是否启用该修饰。
## [br]
## @param modifier_id: 可选修饰标识，用于报告和项目侧去重。
## [br]
## @param metadata: 项目层元数据，框架不解释其含义。
## [br]
## @schema metadata: Dictionary extension metadata copied into the modifier payload.
## [br]
## @return 通用数值修饰字典。
## [br]
## @schema return: Dictionary with `id: StringName`, `value: float`, `operation: Operation`, `priority: int`, `enabled: bool`, and `metadata: Dictionary`.
static func make_modifier(
	value: float,
	operation: Operation = Operation.ADD,
	priority: int = 0,
	enabled: bool = true,
	modifier_id: StringName = &"",
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"id": modifier_id,
		"value": value,
		"operation": operation,
		"priority": priority,
		"enabled": enabled,
		"metadata": metadata.duplicate(true),
	}


## 规范化通用数值修饰字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param raw_modifier: 支持 `id/modifier_id/value/operation/priority/enabled/metadata` 的修饰字典。
## [br]
## @schema raw_modifier: Dictionary numeric modifier payload.
## [br]
## @return 规范化后的修饰字典。
## [br]
## @schema return: Dictionary with `id: StringName`, `value: float`, `operation: Operation`, `priority: int`, `enabled: bool`, and `metadata: Dictionary`.
static func normalize_modifier(raw_modifier: Dictionary) -> Dictionary:
	return {
		"id": _get_modifier_id(raw_modifier),
		"value": GFVariantData.get_option_float(raw_modifier, "value", 0.0),
		"operation": _operation_from_variant(
			GFVariantData.get_option_value(raw_modifier, "operation", Operation.ADD)
		),
		"priority": GFVariantData.get_option_int(raw_modifier, "priority", 0),
		"enabled": GFVariantData.get_option_bool(raw_modifier, "enabled", true),
		"metadata": _get_modifier_metadata(raw_modifier),
	}


## 计算基础值叠加修饰后的结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param base_value: 基础数值；非有限值会被 `fallback_value` 或 0 替换并记录 issue。
## [br]
## @param modifiers: 修饰数组；每项支持 `id/modifier_id/value/operation/priority/enabled/metadata`。
## [br]
## @schema modifiers: Array[Dictionary] numeric modifier payloads. `operation` accepts Operation values or `add`, `multiply`, `divide` text.
## [br]
## @param options: 支持 `fallback_value`、`clamp_enabled`、`min_value` / `clamp_min`、`max_value` / `clamp_max`。
## [br]
## @schema options: Dictionary calculation options.
## [br]
## @return 结构化计算报告。
## [br]
## @schema return: Dictionary with `ok: bool`, finite `base_value`, finite `value`, finite `unclamped_value`, `clamped: bool`, `applied_count: int`, `skipped_count: int`, `issue_count: int`, `applied_modifiers: Array[Dictionary]`, `skipped_modifiers: Array[Dictionary]`, and `issues: Array[Dictionary]`.
static func calculate(base_value: float, modifiers: Array, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var skipped_modifiers: Array[Dictionary] = []
	var sortable_modifiers: Array[Dictionary] = _collect_sortable_modifiers(
		modifiers,
		issues,
		skipped_modifiers
	)
	sortable_modifiers.sort_custom(_compare_modifier_priority)

	var current_value: float = _sanitize_base_value(base_value, options, issues)
	var applied_modifiers: Array[Dictionary] = []
	for modifier: Dictionary in sortable_modifiers:
		current_value = _apply_modifier(
			current_value,
			modifier,
			applied_modifiers,
			skipped_modifiers,
			issues
		)

	var unclamped_value: float = current_value
	var clamp_report: Dictionary = _apply_clamp(current_value, options, issues)
	current_value = GFVariantData.get_option_float(clamp_report, "value", current_value)

	return {
		"ok": issues.is_empty(),
		"base_value": _sanitize_finite_float(base_value, GFVariantData.get_option_float(options, "fallback_value", 0.0)),
		"value": current_value,
		"unclamped_value": unclamped_value,
		"clamped": GFVariantData.get_option_bool(clamp_report, "clamped", false),
		"applied_count": applied_modifiers.size(),
		"skipped_count": skipped_modifiers.size(),
		"issue_count": issues.size(),
		"applied_modifiers": applied_modifiers,
		"skipped_modifiers": skipped_modifiers,
		"issues": issues,
	}


## 计算基础值叠加修饰后的数值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param base_value: 基础数值。
## [br]
## @param modifiers: 修饰数组；格式同 calculate()。
## [br]
## @schema modifiers: Array[Dictionary] numeric modifier payloads.
## [br]
## @param options: 计算选项；格式同 calculate()。
## [br]
## @schema options: Dictionary calculation options.
## [br]
## @return 计算后的有限数值。
static func calculate_value(base_value: float, modifiers: Array, options: Dictionary = {}) -> float:
	return GFVariantData.get_option_float(calculate(base_value, modifiers, options), "value", 0.0)


# --- 私有/辅助方法 ---

static func _collect_sortable_modifiers(
	modifiers: Array,
	issues: Array[Dictionary],
	skipped_modifiers: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(modifiers.size()):
		var raw_value: Variant = modifiers[index]
		if not (raw_value is Dictionary):
			issues.append(_make_issue("invalid_modifier", "modifier must be a Dictionary.", index))
			skipped_modifiers.append(_make_skipped_entry(index, "invalid_modifier"))
			continue

		var raw_modifier: Dictionary = raw_value
		var normalized_modifier: Dictionary = normalize_modifier(raw_modifier)
		normalized_modifier["_index"] = index

		if not raw_modifier.has("value"):
			issues.append(_make_issue("missing_value", "modifier value is required.", index, _modifier_id_string(normalized_modifier)))
			skipped_modifiers.append(_make_skipped_entry(index, "missing_value", normalized_modifier))
			continue

		var modifier_value: float = GFVariantData.get_option_float(normalized_modifier, "value", NAN)
		if not _is_finite_float(modifier_value):
			issues.append(_make_issue("non_finite_modifier_value", "modifier value must be finite.", index, _modifier_id_string(normalized_modifier)))
			skipped_modifiers.append(_make_skipped_entry(index, "non_finite_modifier_value", normalized_modifier))
			continue

		var raw_operation: Variant = GFVariantData.get_option_value(raw_modifier, "operation", Operation.ADD)
		if raw_modifier.has("operation") and not _is_valid_operation_value(raw_operation):
			issues.append(_make_issue("invalid_operation", "modifier operation is invalid.", index, _modifier_id_string(normalized_modifier)))
			skipped_modifiers.append(_make_skipped_entry(index, "invalid_operation", normalized_modifier))
			continue

		if not GFVariantData.get_option_bool(normalized_modifier, "enabled", true):
			skipped_modifiers.append(_make_skipped_entry(index, "disabled", normalized_modifier))
			continue

		result.append(normalized_modifier)

	return result


static func _apply_modifier(
	current_value: float,
	modifier: Dictionary,
	applied_modifiers: Array[Dictionary],
	skipped_modifiers: Array[Dictionary],
	issues: Array[Dictionary]
) -> float:
	var operation: int = GFVariantData.get_option_int(modifier, "operation", Operation.ADD)
	var modifier_value: float = GFVariantData.get_option_float(modifier, "value", 0.0)
	var modifier_index: int = GFVariantData.get_option_int(modifier, "_index", -1)
	var next_value: float = current_value

	match operation:
		Operation.ADD:
			next_value = current_value + modifier_value
		Operation.MULTIPLY:
			next_value = current_value * modifier_value
		Operation.DIVIDE:
			if is_zero_approx(modifier_value):
				issues.append(_make_issue("divide_by_zero", "divide modifier value must not be zero.", modifier_index, _modifier_id_string(modifier)))
				skipped_modifiers.append(_make_skipped_entry(modifier_index, "divide_by_zero", modifier))
				return current_value
			next_value = current_value / modifier_value
		_:
			issues.append(_make_issue("invalid_operation", "modifier operation is invalid.", modifier_index, _modifier_id_string(modifier)))
			skipped_modifiers.append(_make_skipped_entry(modifier_index, "invalid_operation", modifier))
			return current_value

	if not _is_finite_float(next_value):
		issues.append(_make_issue("non_finite_result", "modifier result must be finite.", modifier_index, _modifier_id_string(modifier)))
		skipped_modifiers.append(_make_skipped_entry(modifier_index, "non_finite_result", modifier))
		return current_value

	applied_modifiers.append({
		"index": modifier_index,
		"id": _modifier_id_string(modifier),
		"priority": GFVariantData.get_option_int(modifier, "priority", 0),
		"operation": _operation_to_text(operation),
		"value": modifier_value,
		"before": current_value,
		"after": next_value,
	})
	return next_value


static func _apply_clamp(value: float, options: Dictionary, issues: Array[Dictionary]) -> Dictionary:
	if not GFVariantData.get_option_bool(options, "clamp_enabled", false):
		return { "value": value, "clamped": false }

	var has_minimum: bool = options.has("min_value") or options.has("clamp_min")
	var has_maximum: bool = options.has("max_value") or options.has("clamp_max")
	var minimum: float = _get_option_float_alias(options, "min_value", "clamp_min", value)
	var maximum: float = _get_option_float_alias(options, "max_value", "clamp_max", value)

	if has_minimum and not _is_finite_float(minimum):
		issues.append(_make_issue("non_finite_clamp_min", "clamp minimum must be finite."))
		has_minimum = false
	if has_maximum and not _is_finite_float(maximum):
		issues.append(_make_issue("non_finite_clamp_max", "clamp maximum must be finite."))
		has_maximum = false
	if has_minimum and has_maximum and minimum > maximum:
		issues.append(_make_issue("invalid_clamp_range", "clamp minimum must be less than or equal to clamp maximum."))
		return { "value": value, "clamped": false }

	var clamped_value: float = value
	if has_minimum:
		clamped_value = maxf(clamped_value, minimum)
	if has_maximum:
		clamped_value = minf(clamped_value, maximum)

	return {
		"value": clamped_value,
		"clamped": not is_equal_approx(clamped_value, value),
	}


static func _sanitize_base_value(
	base_value: float,
	options: Dictionary,
	issues: Array[Dictionary]
) -> float:
	if _is_finite_float(base_value):
		return base_value

	var fallback_value: float = GFVariantData.get_option_float(options, "fallback_value", 0.0)
	if not _is_finite_float(fallback_value):
		issues.append(_make_issue("non_finite_fallback_value", "fallback value must be finite."))
		fallback_value = 0.0

	issues.append(_make_issue("non_finite_base_value", "base value must be finite."))
	return fallback_value


static func _sanitize_finite_float(value: float, fallback_value: float = 0.0) -> float:
	if _is_finite_float(value):
		return value
	if _is_finite_float(fallback_value):
		return fallback_value
	return 0.0


static func _get_modifier_id(raw_modifier: Dictionary) -> StringName:
	if raw_modifier.has("id"):
		return GFVariantData.get_option_string_name(raw_modifier, "id", &"")
	return GFVariantData.get_option_string_name(raw_modifier, "modifier_id", &"")


static func _get_modifier_metadata(raw_modifier: Dictionary) -> Dictionary:
	var raw_metadata: Variant = GFVariantData.get_option_value(raw_modifier, "metadata", {})
	return GFVariantData.as_dictionary(raw_metadata).duplicate(true)


static func _get_option_float_alias(
	options: Dictionary,
	primary_key: String,
	alias_key: String,
	default_value: float
) -> float:
	if options.has(primary_key):
		return GFVariantData.get_option_float(options, primary_key, default_value)
	return GFVariantData.get_option_float(options, alias_key, default_value)


static func _is_valid_operation_value(value: Variant) -> bool:
	if value is int:
		var int_value: int = value
		return int_value >= Operation.ADD and int_value <= Operation.DIVIDE

	if value is String or value is StringName:
		var text: String = _operation_text_from_variant(value)
		return [
			"add",
			"+",
			"multiply",
			"mul",
			"*",
			"divide",
			"div",
			"/",
		].has(text)

	return false


static func _operation_from_variant(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return clampi(int_value, Operation.ADD, Operation.DIVIDE)

	if value is String or value is StringName:
		var text: String = _operation_text_from_variant(value)
		match text:
			"multiply", "mul", "*":
				return Operation.MULTIPLY
			"divide", "div", "/":
				return Operation.DIVIDE

	return Operation.ADD


static func _operation_text_from_variant(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value.strip_edges().to_lower()
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value).strip_edges().to_lower()
	return ""


static func _operation_to_text(operation: int) -> String:
	match operation:
		Operation.MULTIPLY:
			return "multiply"
		Operation.DIVIDE:
			return "divide"
	return "add"


static func _compare_modifier_priority(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = GFVariantData.get_option_int(left, "priority", 0)
	var right_priority: int = GFVariantData.get_option_int(right, "priority", 0)
	if left_priority == right_priority:
		return GFVariantData.get_option_int(left, "_index", 0) < GFVariantData.get_option_int(right, "_index", 0)
	return left_priority < right_priority


static func _make_issue(
	kind: String,
	message: String,
	index: int = -1,
	modifier_id: String = ""
) -> Dictionary:
	var issue: Dictionary = {
		"kind": kind,
		"message": message,
	}
	if index >= 0:
		issue["index"] = index
	if not modifier_id.is_empty():
		issue["modifier_id"] = modifier_id
	return issue


static func _make_skipped_entry(index: int, reason: String, modifier: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"index": index,
		"reason": reason,
	}
	if not modifier.is_empty():
		entry["id"] = _modifier_id_string(modifier)
		entry["priority"] = GFVariantData.get_option_int(modifier, "priority", 0)
		entry["operation"] = _operation_to_text(GFVariantData.get_option_int(modifier, "operation", Operation.ADD))
		var modifier_value: float = GFVariantData.get_option_float(modifier, "value", NAN)
		if _is_finite_float(modifier_value):
			entry["value"] = modifier_value
	return entry


static func _modifier_id_string(modifier: Dictionary) -> String:
	return String(GFVariantData.get_option_string_name(modifier, "id", &""))


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
