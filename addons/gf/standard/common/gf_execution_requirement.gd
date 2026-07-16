## GFExecutionRequirement: 通用执行条件集合。
##
## 用于在任务、系统、工具按钮或资源流程执行前统一评估一组声明式条件。
## 它只读取调用方传入的 context 字典和可选谓词，不绑定具体调度器或业务系统。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 7.0.0
class_name GFExecutionRequirement
extends RefCounted


# --- 常量 ---

## 条件必须满足。
## [br]
## @api public
## [br]
## @since 7.0.0
const MODE_ALL: StringName = &"all"

## 同组条件至少满足一个。
## [br]
## @api public
## [br]
## @since 7.0.0
const MODE_ANY: StringName = &"any"

## 条件必须不满足。
## [br]
## @api public
## [br]
## @since 7.0.0
const MODE_NONE: StringName = &"none"

## Callable 谓词条件。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_PREDICATE: StringName = &"predicate"

## context 值比较条件。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_VALUE: StringName = &"value"

## context key 存在性条件。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_PRESENT: StringName = &"present"


# --- 公共变量 ---

## 条件集合稳定标识。
## [br]
## @api public
## [br]
## @since 7.0.0
var requirement_id: StringName = &""

## 条件集合显示名称。
## [br]
## @api public
## [br]
## @since 7.0.0
var label: String = ""

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary for caller-defined requirement metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _conditions: Array[Dictionary] = []


# --- 公共方法 ---

## 配置条件集合。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_requirement_id: 条件集合稳定标识。
## [br]
## @param p_label: 显示名称。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into metadata.
## [br]
## @return 当前条件集合。
func configure(
	p_requirement_id: StringName,
	p_label: String = "",
	p_metadata: Dictionary = {}
) -> GFExecutionRequirement:
	requirement_id = p_requirement_id
	label = p_label
	metadata = p_metadata.duplicate(true)
	return self


## 添加 Callable 谓词条件。谓词签名为 `(context: Dictionary) -> bool|Dictionary`。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param condition_id: 条件稳定标识。
## [br]
## @param predicate: 条件谓词。
## [br]
## @param options: 条件选项，支持 mode、label、negate 和 metadata。
## [br]
## @schema options: Dictionary，可包含 mode: StringName、label: String、negate: bool、metadata: Dictionary。
## [br]
## @return 条件快照；predicate 无效时为空字典。
## [br]
## @schema return: Dictionary，包含 condition_id、kind、mode、label、negate、metadata 和 has_predicate。
func add_predicate(condition_id: StringName, predicate: Callable, options: Dictionary = {}) -> Dictionary:
	if condition_id == &"" or not predicate.is_valid():
		return {}

	var condition: Dictionary = _make_condition(condition_id, KIND_PREDICATE, options)
	condition["predicate"] = predicate
	_conditions.append(condition)
	return _condition_to_snapshot(condition)


## 添加 context 值比较条件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param condition_id: 条件稳定标识。
## [br]
## @param key: 要从 context 读取的 key。
## [br]
## @schema key: Variant context key，通常为 String 或 StringName。
## [br]
## @param expected_value: 期望值。
## [br]
## @schema expected_value: Variant expected context value.
## [br]
## @param options: 条件选项，支持 mode、label、negate、metadata 和 equals_options。
## [br]
## @schema options: Dictionary，可包含 mode: StringName、label: String、negate: bool、metadata: Dictionary、equals_options: Dictionary。
## [br]
## @return 条件快照。
## [br]
## @schema return: Dictionary，包含 condition_id、kind、mode、label、key、expected、negate 和 metadata。
func add_value(
	condition_id: StringName,
	key: Variant,
	expected_value: Variant,
	options: Dictionary = {}
) -> Dictionary:
	if condition_id == &"":
		return {}

	var condition: Dictionary = _make_condition(condition_id, KIND_VALUE, options)
	condition["key"] = GFVariantData.duplicate_variant(key, true)
	condition["expected"] = GFVariantData.duplicate_variant(expected_value, true)
	condition["equals_options"] = GFVariantData.get_option_dictionary(options, "equals_options").duplicate(true)
	_conditions.append(condition)
	return _condition_to_snapshot(condition)


## 添加 context key 存在性条件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param condition_id: 条件稳定标识。
## [br]
## @param key: 要检查的 context key。
## [br]
## @schema key: Variant context key，通常为 String 或 StringName。
## [br]
## @param options: 条件选项，支持 mode、label、negate 和 metadata。
## [br]
## @schema options: Dictionary，可包含 mode: StringName、label: String、negate: bool、metadata: Dictionary。
## [br]
## @return 条件快照。
## [br]
## @schema return: Dictionary，包含 condition_id、kind、mode、label、key、negate 和 metadata。
func add_presence(condition_id: StringName, key: Variant, options: Dictionary = {}) -> Dictionary:
	if condition_id == &"":
		return {}

	var condition: Dictionary = _make_condition(condition_id, KIND_PRESENT, options)
	condition["key"] = GFVariantData.duplicate_variant(key, true)
	_conditions.append(condition)
	return _condition_to_snapshot(condition)


## 评估条件集合。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 调用方上下文字典。
## [br]
## @schema context: Dictionary read by value and predicate conditions.
## [br]
## @return 条件评估报告。
## [br]
## @schema return: Dictionary，包含 ok、requirement_id、label、all_satisfied、any_satisfied、none_clear、satisfied_count、failed_count、raw_failed_count、blocking_count、none_matched_count、conditions 和 metadata。failed_count/raw_failed_count 记录原始谓词 false 数；blocking_count 记录导致 requirement 不通过的聚合阻塞数。
func evaluate(context: Dictionary = {}) -> Dictionary:
	var condition_reports: Array[Dictionary] = []
	var all_satisfied: bool = true
	var has_any: bool = false
	var any_satisfied: bool = false
	var none_clear: bool = true
	var satisfied_count: int = 0
	var failed_count: int = 0
	var blocking_count: int = 0
	var none_matched_count: int = 0

	for condition: Dictionary in _conditions:
		var condition_report: Dictionary = _evaluate_condition(condition, context)
		var condition_ok: bool = GFVariantData.get_option_bool(condition_report, "ok", false)
		var mode: StringName = GFVariantData.get_option_string_name(condition_report, "mode", MODE_ALL)

		match mode:
			MODE_ANY:
				has_any = true
				if condition_ok:
					any_satisfied = true
			MODE_NONE:
				if condition_ok:
					none_clear = false
					none_matched_count += 1
					blocking_count += 1
			_:
				if not condition_ok:
					all_satisfied = false
					blocking_count += 1

		if condition_ok:
			satisfied_count += 1
		else:
			failed_count += 1
		condition_reports.append(condition_report)

	var effective_any_satisfied: bool = any_satisfied if has_any else true
	if has_any and not any_satisfied:
		blocking_count += 1
	var ok: bool = all_satisfied and effective_any_satisfied and none_clear
	return {
		"ok": ok,
		"requirement_id": requirement_id,
		"label": label,
		"all_satisfied": all_satisfied,
		"any_satisfied": effective_any_satisfied,
		"none_clear": none_clear,
		"satisfied_count": satisfied_count,
		"failed_count": failed_count,
		"raw_failed_count": failed_count,
		"blocking_count": blocking_count,
		"none_matched_count": none_matched_count,
		"conditions": condition_reports,
		"metadata": metadata.duplicate(true),
	}


## 检查条件集合是否满足。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 调用方上下文字典。
## [br]
## @schema context: Dictionary read by value and predicate conditions.
## [br]
## @return 满足时返回 true。
func is_satisfied(context: Dictionary = {}) -> bool:
	return GFVariantData.get_option_bool(evaluate(context), "ok", false)


## 获取条件快照数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 条件快照数组，不包含 Callable 本体。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 condition_id、kind、mode、label、key、expected、negate、metadata 和 has_predicate。
func get_conditions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for condition: Dictionary in _conditions:
		result.append(_condition_to_snapshot(condition))
	return result


## 清空全部条件。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_conditions.clear()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 requirement_id、label、condition_count、conditions 和 metadata。
func get_debug_snapshot() -> Dictionary:
	return {
		"requirement_id": requirement_id,
		"label": label,
		"condition_count": _conditions.size(),
		"conditions": get_conditions(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_condition(condition_id: StringName, kind: StringName, options: Dictionary) -> Dictionary:
	return {
		"condition_id": condition_id,
		"kind": kind,
		"mode": _normalize_mode(GFVariantData.get_option_string_name(options, "mode", MODE_ALL)),
		"label": GFVariantData.get_option_string(options, "label", String(condition_id)),
		"negate": GFVariantData.get_option_bool(options, "negate", false),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata").duplicate(true),
	}


func _evaluate_condition(condition: Dictionary, context: Dictionary) -> Dictionary:
	var report: Dictionary = _condition_to_snapshot(condition)
	var passed: bool = false
	var error: String = ""
	var kind: StringName = GFVariantData.get_option_string_name(condition, "kind", KIND_VALUE)

	match kind:
		KIND_PREDICATE:
			var predicate_result: Dictionary = _evaluate_predicate(condition, context)
			passed = GFVariantData.get_option_bool(predicate_result, "ok", false)
			error = GFVariantData.get_option_string(predicate_result, "error")
			report["result"] = GFVariantData.get_option_value(predicate_result, "result")
		KIND_PRESENT:
			var present_key: Variant = GFVariantData.get_option_value(condition, "key")
			passed = _context_has_key(context, present_key)
			report["present"] = passed
		_:
			var value_key: Variant = GFVariantData.get_option_value(condition, "key")
			var actual_value: Variant = _get_context_value(context, value_key)
			var expected_value: Variant = GFVariantData.get_option_value(condition, "expected")
			var equals_options: Dictionary = GFVariantData.get_option_dictionary(condition, "equals_options")
			passed = _context_has_key(context, value_key) and GFVariantData.values_equal(actual_value, expected_value, equals_options)
			report["present"] = _context_has_key(context, value_key)
			report["actual"] = GFVariantData.duplicate_variant(actual_value, true)

	if GFVariantData.get_option_bool(condition, "negate", false):
		passed = not passed
	report["ok"] = passed
	report["error"] = error
	return report


func _evaluate_predicate(condition: Dictionary, context: Dictionary) -> Dictionary:
	var predicate: Callable = _get_condition_predicate(condition)
	if not predicate.is_valid():
		return { "ok": false, "error": "predicate_invalid" }

	var result: Variant = predicate.call(context.duplicate(true))
	if result is Dictionary:
		var result_dictionary: Dictionary = result
		return {
			"ok": GFVariantData.get_option_bool(result_dictionary, "ok", false),
			"error": GFVariantData.get_option_string(result_dictionary, "error"),
			"result": result_dictionary.duplicate(true),
		}

	return {
		"ok": GFVariantData.to_bool(result, false),
		"error": "",
		"result": GFVariantData.duplicate_variant(result, true),
	}


func _condition_to_snapshot(condition: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {
		"condition_id": GFVariantData.get_option_string_name(condition, "condition_id"),
		"kind": GFVariantData.get_option_string_name(condition, "kind", KIND_VALUE),
		"mode": GFVariantData.get_option_string_name(condition, "mode", MODE_ALL),
		"label": GFVariantData.get_option_string(condition, "label"),
		"negate": GFVariantData.get_option_bool(condition, "negate", false),
		"metadata": GFVariantData.get_option_dictionary(condition, "metadata").duplicate(true),
		"has_predicate": _get_condition_predicate(condition).is_valid(),
	}
	if condition.has("key"):
		snapshot["key"] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(condition, "key"), true)
	if condition.has("expected"):
		snapshot["expected"] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(condition, "expected"), true)
	return snapshot


func _context_has_key(context: Dictionary, key: Variant) -> bool:
	if context.has(key):
		return true

	var text_key: String = GFVariantData.to_text(key)
	if not text_key.is_empty() and context.has(text_key):
		return true

	var string_name_key: StringName = GFVariantData.to_string_name(key)
	return string_name_key != &"" and context.has(string_name_key)


func _get_context_value(context: Dictionary, key: Variant) -> Variant:
	if context.has(key):
		return GFVariantData.duplicate_variant(context[key], true)

	var text_key: String = GFVariantData.to_text(key)
	if not text_key.is_empty() and context.has(text_key):
		return GFVariantData.duplicate_variant(context[text_key], true)

	var string_name_key: StringName = GFVariantData.to_string_name(key)
	if string_name_key != &"" and context.has(string_name_key):
		return GFVariantData.duplicate_variant(context[string_name_key], true)

	return null


func _normalize_mode(mode: StringName) -> StringName:
	match mode:
		MODE_ANY, MODE_NONE:
			return mode
		_:
			return MODE_ALL


func _get_condition_predicate(condition: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(condition, "predicate", Callable())
	if value is Callable:
		var predicate: Callable = value
		return predicate
	return Callable()
