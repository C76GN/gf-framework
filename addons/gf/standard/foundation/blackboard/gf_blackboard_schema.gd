## GFBlackboardSchema: 通用黑板数据结构声明与校验器。
##
## 用于为行为树、状态机、任务系统或项目自定义运行时字典提供可复用字段契约。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFBlackboardSchema
extends Resource


# --- 导出变量 ---

## Schema 标识。为空时可由调用方自行决定命名。
## [br]
## @api public
@export var schema_id: StringName = &""

## 字段声明列表。
## [br]
## @api public
@export var entries: Array[GFBlackboardEntry] = []

## 是否允许包含 schema 未声明的字段。
## [br]
## @api public
@export var allow_extra_keys: bool = true

## 是否在校验前按字段声明尝试类型转换。
## [br]
## @api public
@export var coerce_values: bool = false

## 启用 coerce_values 时，转换失败是否作为校验错误。
## [br]
## @api public
@export var fail_on_coerce_error: bool = true

## 可选元数据，供编辑器、调试器或项目工具使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary metadata for editor, debugger, or project tooling.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定 schema 键。
## [br]
## @api public
## [br]
## @return Schema 标识。
func get_schema_key() -> StringName:
	return schema_id


## 获取字段声明。
## [br]
## @api public
## [br]
## @param entry_key: 字段键。
## [br]
## @return 找到时返回字段声明，否则返回 null。
func get_entry(entry_key: StringName) -> GFBlackboardEntry:
	for entry: GFBlackboardEntry in entries:
		if entry != null and entry.get_key() == entry_key:
			return entry
	return null


## 检查字段声明是否存在。
## [br]
## @api public
## [br]
## @param entry_key: 字段键。
## [br]
## @return 存在返回 true。
func has_entry(entry_key: StringName) -> bool:
	return get_entry(entry_key) != null


## 获取当前 schema 的字段键列表。
## [br]
## @api public
## [br]
## @return 排序后的字段键。
func get_entry_keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: GFBlackboardEntry in entries:
		if entry != null and entry.get_key() != &"":
			_append_packed_string(result, String(entry.get_key()))
	result.sort()
	return result


## 创建默认黑板数据。
## [br]
## @api public
## [br]
## @param include_optional: 为 true 时包含非必填字段。
## [br]
## @return 默认数据字典。
## [br]
## @schema return: Dictionary default blackboard values.
func build_defaults(include_optional: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for entry: GFBlackboardEntry in entries:
		if entry == null or entry.get_key() == &"":
			continue
		if entry.required or include_optional:
			result[entry.get_key()] = entry.coerce_value(entry.default_value)
	return result


## 为输入数据补齐默认值。
## [br]
## @api public
## [br]
## @param values: 输入黑板数据。
## [br]
## @param include_optional: 为 true 时补齐非必填字段。
## [br]
## @param should_coerce: 为 true 时按字段声明转换已有值与默认值。
## [br]
## @return 补齐后的新字典。
## [br]
## @schema values: Dictionary source blackboard values.
## [br]
## @schema return: Dictionary normalized blackboard values.
func apply_defaults(values: Dictionary, include_optional: bool = true, should_coerce: bool = true) -> Dictionary:
	var result: Dictionary = _normalize_keys(values)
	for entry: GFBlackboardEntry in entries:
		if entry == null or entry.get_key() == &"":
			continue

		var entry_key: StringName = entry.get_key()
		if result.has(entry_key):
			if should_coerce:
				result[entry_key] = entry.coerce_value(result[entry_key])
			continue
		if entry.required or include_optional:
			result[entry_key] = entry.coerce_value(entry.default_value) if should_coerce else GFVariantData.duplicate_variant(entry.default_value)
	return result


## 按字段声明转换黑板数据。
## [br]
## @api public
## [br]
## @param values: 输入黑板数据。
## [br]
## @param include_defaults: 为 true 时同时补默认值。
## [br]
## @return 转换后的新字典。
## [br]
## @schema values: Dictionary source blackboard values.
## [br]
## @schema return: Dictionary coerced blackboard values.
func coerce_dictionary(values: Dictionary, include_defaults: bool = true) -> Dictionary:
	var result: Dictionary = apply_defaults(values, include_defaults, false) if include_defaults else _normalize_keys(values)
	for entry: GFBlackboardEntry in entries:
		if entry == null or entry.get_key() == &"" or not result.has(entry.get_key()):
			continue
		result[entry.get_key()] = entry.coerce_value(result[entry.get_key()])
	return result


## 校验黑板数据。
## [br]
## @api public
## [br]
## @param values: 输入黑板数据。
## [br]
## @return 校验报告字典。
## [br]
## @schema values: Dictionary source blackboard values.
## [br]
## @schema return: Dictionary validation report.
func validate_values(values: Dictionary) -> Dictionary:
	var report: Dictionary = _make_report()
	var working_values: Dictionary = _coerce_values_for_validation(values, report) if coerce_values else _normalize_keys(values)
	var declared_keys: Dictionary = {}

	for entry: GFBlackboardEntry in entries:
		if entry == null:
			_append_issue(report, "error", "null_entry", &"", "字段声明为空。")
			continue

		var entry_key: StringName = entry.get_key()
		if entry_key == &"":
			_append_issue(report, "error", "empty_key", &"", "字段键为空。")
			continue

		if declared_keys.has(entry_key):
			_append_issue(report, "error", "duplicate_entry_key", entry_key, "字段键重复：%s。" % String(entry_key))
			continue

		declared_keys[entry_key] = true
		if not working_values.has(entry_key):
			if entry.required:
				_append_issue(report, "error", "missing_required", entry_key, "缺少必填字段：%s。" % String(entry_key))
			continue

		var value: Variant = working_values[entry_key]
		if value == null and not entry.allow_null:
			_append_issue(report, "error", "null_value", entry_key, "字段不允许为空：%s。" % String(entry_key))
		elif not entry.is_value_valid(value):
			_append_issue(report, "error", "invalid_type", entry_key, "字段类型不匹配：%s。" % String(entry_key))

	if not allow_extra_keys:
		for key_variant: Variant in working_values.keys():
			var entry_key: StringName = GFVariantData.to_string_name(key_variant)
			if not declared_keys.has(entry_key):
				_append_issue(report, "error", "extra_key", entry_key, "存在未声明字段：%s。" % String(entry_key))

	return GFValidationReportDictionary.finalize_report(report, "Blackboard schema", {
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first reported blackboard schema issue.",
	})


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @return 新 schema。
func duplicate_schema() -> GFBlackboardSchema:
	var schema: GFBlackboardSchema = GFBlackboardSchema.new()
	schema.schema_id = schema_id
	schema.allow_extra_keys = allow_extra_keys
	schema.coerce_values = coerce_values
	schema.fail_on_coerce_error = fail_on_coerce_error
	schema.metadata = metadata.duplicate(true)
	for entry: GFBlackboardEntry in entries:
		schema.entries.append(entry.duplicate_entry() if entry != null else null)
	return schema


## 导出 schema 摘要。
## [br]
## @api public
## [br]
## @return schema 字典。
## [br]
## @schema return: Dictionary schema description.
func describe() -> Dictionary:
	var entry_descriptions: Array[Dictionary] = []
	for entry: GFBlackboardEntry in entries:
		if entry != null:
			entry_descriptions.append(entry.describe())
	return {
		"schema_id": schema_id,
		"entries": entry_descriptions,
		"allow_extra_keys": allow_extra_keys,
		"coerce_values": coerce_values,
		"fail_on_coerce_error": fail_on_coerce_error,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_report() -> Dictionary:
	return {
		"ok": true,
		"healthy": true,
		"schema_id": schema_id,
		"entry_count": entries.size(),
		"error_count": 0,
		"warning_count": 0,
		"issue_counts_by_kind": {},
		"summary": "",
		"next_action": "",
		"issues": [],
	}


func _coerce_values_for_validation(values: Dictionary, report: Dictionary) -> Dictionary:
	var result: Dictionary = _normalize_keys(values)
	for entry: GFBlackboardEntry in entries:
		if entry == null or entry.get_key() == &"":
			continue

		var entry_key: StringName = entry.get_key()
		var has_value: bool = result.has(entry_key)
		if not has_value:
			continue

		var source_value: Variant = result[entry_key]
		var coerce_result: Dictionary = entry.try_coerce_value(source_value)
		result[entry_key] = GFVariantData.get_option_value(coerce_result, "value")
		if GFVariantData.get_option_bool(coerce_result, "ok", false):
			continue

		var severity: String = "error" if fail_on_coerce_error else "warning"
		_append_issue(
			report,
			severity,
			"coerce_failed",
			entry_key,
			GFVariantData.get_option_string(coerce_result, "message", "字段类型转换失败：%s。" % String(entry_key))
		)
	return result


func _normalize_keys(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in values.keys():
		result[GFVariantData.to_string_name(key_variant)] = GFVariantData.duplicate_variant(values[key_variant])
	return result


func _append_issue(report: Dictionary, severity: String, kind: String, entry_key: StringName, message: String) -> void:
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(report, severity, StringName(kind), message, {
		"key": String(entry_key),
		"schema_id": schema_id,
	})


func _get_validation_next_actions() -> Dictionary:
	return {
		"null_entry": "Remove the null entry or replace it with a valid GFBlackboardEntry resource.",
		"empty_key": "Assign a stable key to every blackboard entry.",
		"missing_required": "Provide the required key or apply defaults before validation.",
		"null_value": "Provide a non-null value or allow null for this entry.",
		"invalid_type": "Update the value type or coerce the value before writing it to the blackboard.",
		"duplicate_entry_key": "Keep one GFBlackboardEntry per stable key.",
		"extra_key": "Remove the undeclared key or enable allow_extra_keys.",
		"coerce_failed": "Fix the source value so it can be converted to the declared blackboard entry type.",
	}


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
