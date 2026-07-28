## GFAnalyticsEventSchema: 版本化 Analytics 事件属性契约。
##
## 用不超过 4096 字符且不含 C0/DEL 控制字符的稳定事件名、1..2_147_483_647 范围内的
## 精确版本和严格 GFDictionarySchema 描述编码前的事件属性。
## 校验会先执行有界、无复制的集合遍历，再进入通用 Dictionary Schema，
## 避免不可信属性在深复制前消耗无界资源。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 10.0.0
class_name GFAnalyticsEventSchema
extends Resource


# --- 常量 ---

const _DEFAULT_MAX_DEPTH: int = 16
const _DEFAULT_MAX_PROPERTY_COUNT: int = 128
const _DEFAULT_MAX_STRING_LENGTH: int = 4096
const _DEFAULT_MAX_COLLECTION_ITEMS: int = 256
const _DEFAULT_MAX_TOTAL_NODES: int = 8192
const _DEFAULT_MAX_TOTAL_BYTES: int = 256 * 1024
const _HARD_MAX_DEPTH: int = 64
const _HARD_MAX_PROPERTY_COUNT: int = 4096
const _HARD_MAX_STRING_LENGTH: int = 65_536
const _HARD_MAX_COLLECTION_ITEMS: int = 4096
const _HARD_MAX_TOTAL_NODES: int = 1_000_000
const _HARD_MAX_TOTAL_BYTES: int = 16 * 1024 * 1024
const _MAX_EVENT_NAME_LENGTH: int = 4096
const _MAX_SCHEMA_VERSION: int = 2_147_483_647
const _MAX_SCHEMA_GRAPH_DEPTH: int = 64
const _MAX_SCHEMA_GRAPH_NODES: int = 4096
const _MAX_SCHEMA_CONTAINER_ITEMS: int = 4096
const _MAX_SCHEMA_RULES_PER_FIELD: int = 64
const _MAX_SCHEMA_AUXILIARY_DEPTH: int = 32
const _MAX_SCHEMA_AUXILIARY_NODES: int = 8192
const _MAX_SCHEMA_TOTAL_TEXT_BYTES: int = 4 * 1024 * 1024
const _GF_VALIDATION_CONSTRAINT_RULE_SCRIPT = preload(
	"res://addons/gf/standard/foundation/validation/gf_validation_constraint_rule.gd"
)
const _GF_DICTIONARY_SCHEMA_SCRIPT = preload(
	"res://addons/gf/standard/foundation/schema/gf_dictionary_schema.gd"
)
const _GF_SCHEMA_FIELD_SCRIPT = preload(
	"res://addons/gf/standard/foundation/schema/gf_schema_field.gd"
)


# --- 导出变量 ---

## 稳定事件名；不得为空、超过 4096 字符或包含 C0/DEL 控制字符。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var event_name: StringName = &""

## 事件属性 Schema 版本；必须位于 1..2_147_483_647。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var schema_version: int = 1

## 事件属性 Dictionary Schema。
## [br]
## Analytics 契约要求根与所有嵌套 Dictionary 禁止额外字段和类型转换。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var properties_schema: GFDictionarySchema = null


# --- 私有变量 ---

var _last_definition_footprint: Dictionary = {}


# --- 公共方法 ---

## 配置事件属性契约。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param p_event_name: 稳定事件名。
## [br]
## @param p_schema_version: 1..2_147_483_647 范围内的 Schema 版本。
## [br]
## @param p_properties_schema: 严格事件属性 Dictionary Schema。
## [br]
## @return 当前事件 Schema。
func configure(
	p_event_name: StringName,
	p_schema_version: int,
	p_properties_schema: GFDictionarySchema
) -> GFAnalyticsEventSchema:
	event_name = p_event_name
	schema_version = p_schema_version
	properties_schema = p_properties_schema
	return self


## 校验事件 Schema 定义、递归严格性、图预算和回调纯度边界。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param options: 可选上下文，支持 subject、path、source_path 和 source。
## [br]
## @return 校验报告。
## [br]
## @schema options: Dictionary validation context.
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
	_last_definition_footprint = {}
	var report: GFValidationReport = _make_report(options)
	if event_name == &"":
		_add_error(report, &"empty_event_name", "Analytics event name cannot be empty.", "event_name", options)
	elif String(event_name).length() > _MAX_EVENT_NAME_LENGTH:
		_add_error(
			report,
			&"event_name_too_long",
			"Analytics event name exceeds the supported length.",
			"event_name",
			options,
			{
				"max_length": _MAX_EVENT_NAME_LENGTH,
				"actual_length": String(event_name).length(),
			}
		)
	elif _contains_control_character(String(event_name)):
		_add_error(
			report,
			&"invalid_event_name",
			"Analytics event name cannot contain C0 or DEL control characters.",
			"event_name",
			options
		)
	if schema_version <= 0:
		_add_error(
			report,
			&"invalid_schema_version",
			"Analytics schema_version must be greater than zero.",
			"schema_version",
			options,
			{
				"actual_value": schema_version,
				"expected_value": "positive_integer",
			}
		)
	elif schema_version > _MAX_SCHEMA_VERSION:
		_add_error(
			report,
			&"schema_version_out_of_range",
			"Analytics schema_version exceeds the supported int32 range.",
			"schema_version",
			options,
			{
				"actual_value": schema_version,
				"maximum_value": _MAX_SCHEMA_VERSION,
			}
		)
	if properties_schema == null:
		_add_error(
			report,
			&"missing_properties_schema",
			"Analytics properties_schema is required.",
			"properties_schema",
			options
		)
		return report

	var graph_is_bounded: bool = _validate_schema_graph_into(report, options)
	if not graph_is_bounded:
		return report

	var definition_options: Dictionary = _make_properties_context(options)
	var definition_report: GFValidationReport = properties_schema.validate_definition(definition_options)
	var _merged_definition_report: RefCounted = report.merge(definition_report, false)
	return report


## 校验编码前的 Analytics 事件属性。
## [br]
## 该入口不会返回转换后的值，也不会把 Schema 描述为最终 JSON wire schema。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param properties: 待校验事件属性。
## [br]
## @param options: 可选上下文与预算，支持 subject、path、source_path、source、max_depth、max_property_count、max_string_length、max_collection_items、max_total_nodes 和 max_total_bytes。
## [br]
## @return 校验报告。
## [br]
## @schema properties: Dictionary analytics event properties before report encoding.
## [br]
## @schema options: Dictionary validation context and bounded traversal options.
func validate_properties(properties: Dictionary, options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = validate_definition(options)
	if not report.is_ok():
		return report
	return validate_registered_properties_for_framework(properties, options, report)


## 创建隔离的事件 Schema 副本。
## [br]
## 嵌套 Dictionary Schema、字段和规则通过 GFDictionarySchema.duplicate_schema() 复制；
## 规则中的 Callable 仍遵循原规则的引用语义，但有效 callback 会被定义校验拒绝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新事件 Schema。
func duplicate_schema() -> GFAnalyticsEventSchema:
	var result: GFAnalyticsEventSchema = GFAnalyticsEventSchema.new()
	result.event_name = event_name
	result.schema_version = schema_version
	if properties_schema != null:
		result.properties_schema = properties_schema.duplicate_schema()
	return result


## 导出事件 Schema 摘要。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 事件 Schema 描述。
## [br]
## @schema return: Dictionary with event_name, schema_version, and properties_schema.
func describe() -> Dictionary:
	return {
		"event_name": String(event_name),
		"schema_version": schema_version,
		"properties_schema": properties_schema.describe() if properties_schema != null else {},
	}


# --- 框架内部方法 ---

## 对已经完成定义校验并由 Registry 隔离保存的 Schema 校验属性。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param properties: 待校验事件属性。
## [br]
## @param options: 校验上下文与遍历预算。
## [br]
## @param report: 已包含定义校验结果的报告；为 null 时创建新报告。
## [br]
## @return 属性校验报告。
## [br]
## @schema properties: Dictionary analytics event properties before report encoding.
## [br]
## @schema options: Dictionary validation context and bounded traversal options.
func validate_registered_properties_for_framework(
	properties: Dictionary,
	options: Dictionary = {},
	report: GFValidationReport = null
) -> GFValidationReport:
	var result_report: GFValidationReport = report
	if result_report == null:
		result_report = _make_report(options)

	_validate_properties_budget_into(properties, result_report, options)
	if not result_report.is_ok():
		return result_report

	var properties_options: Dictionary = _make_properties_context(options)
	var properties_report: GFValidationReport = properties_schema.validate_dictionary(
		properties,
		properties_options
	)
	var _merged_properties_report: RefCounted = result_report.merge(properties_report, false)
	return result_report


## 返回最近一次成功完成图遍历后记录的定义预算。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return Registry 累计容量使用的定义预算副本。
## [br]
## @schema return: Dictionary with graph_nodes, auxiliary_nodes, and text_bytes.
func get_validated_definition_footprint_for_framework() -> Dictionary:
	return _last_definition_footprint.duplicate(true)


# --- 私有/辅助方法 ---

func _validate_schema_graph_into(report: GFValidationReport, options: Dictionary) -> bool:
	var stack: Array[Dictionary] = [{
		"kind": "schema",
		"value": properties_schema,
		"path": _get_properties_path(options),
		"depth": 0,
		"exiting": false,
	}]
	var active_ids: Dictionary = {}
	var scheduled_work_count: int = 1
	var auxiliary_state: Dictionary = {
		"nodes": 0,
		"text_bytes": String(event_name).to_utf8_buffer().size(),
	}

	while not stack.is_empty():
		var record: Dictionary = stack.pop_back()
		var record_kind: String = GFVariantData.get_option_string(record, "kind")
		var record_path: String = GFVariantData.get_option_string(record, "path")
		var record_depth: int = GFVariantData.get_option_int(record, "depth")
		var record_value: Variant = GFVariantData.get_option_value(record, "value")
		var identity: String = _make_graph_identity(record_kind, record_value)
		if GFVariantData.get_option_bool(record, "exiting"):
			var _active_erased: bool = active_ids.erase(identity)
			continue
		if active_ids.has(identity):
			continue
		if record_depth > _MAX_SCHEMA_GRAPH_DEPTH:
			_add_error(
				report,
				&"schema_definition_depth_exceeded",
				"Analytics schema definition exceeds the supported depth.",
				record_path,
				options,
				{
					"max_depth": _MAX_SCHEMA_GRAPH_DEPTH,
					"actual_depth": record_depth,
				}
			)
			return false
		active_ids[identity] = true
		stack.append({
			"kind": record_kind,
			"value": record_value,
			"path": record_path,
			"depth": record_depth,
			"exiting": true,
		})

		if record_kind == "schema" and record_value is GFDictionarySchema:
			var dictionary_schema: GFDictionarySchema = record_value
			if dictionary_schema.get_script() != _GF_DICTIONARY_SCHEMA_SCRIPT:
				_add_error(
					report,
					&"unsupported_schema_definition_type",
					"Analytics schemas only accept the built-in GFDictionarySchema script.",
					record_path,
					options
				)
				return false
			if not _validate_dictionary_schema_contract(
				dictionary_schema,
				record_path,
				report,
				options,
				auxiliary_state
			):
				return false
			if (
				dictionary_schema.fields.size() > _MAX_SCHEMA_CONTAINER_ITEMS
				or scheduled_work_count + dictionary_schema.fields.size() > _MAX_SCHEMA_GRAPH_NODES
			):
				_add_schema_budget_error(
					report,
					record_path,
					options,
					"fields",
					dictionary_schema.fields.size()
				)
				return false
			scheduled_work_count += dictionary_schema.fields.size()
			for index: int in range(dictionary_schema.fields.size() - 1, -1, -1):
				var field: GFSchemaField = dictionary_schema.fields[index]
				if field == null:
					continue
				var field_name_text: String = String(field.field_name)
				if field_name_text.length() > _MAX_EVENT_NAME_LENGTH:
					_add_error(
						report,
						&"field_name_too_long",
						"Analytics field name exceeds the supported length.",
						record_path,
						options
					)
					return false
				stack.append({
					"kind": "field",
					"value": field,
					"path": _join_path(record_path, field_name_text),
					"depth": record_depth + 1,
					"exiting": false,
				})
		elif record_kind == "field" and record_value is GFSchemaField:
			var schema_field: GFSchemaField = record_value
			if schema_field.get_script() != _GF_SCHEMA_FIELD_SCRIPT:
				_add_error(
					report,
					&"unsupported_schema_definition_type",
					"Analytics schemas only accept the built-in GFSchemaField script.",
					record_path,
					options
				)
				return false
			if (
				schema_field.validation_rules.size() > _MAX_SCHEMA_RULES_PER_FIELD
				or scheduled_work_count + schema_field.validation_rules.size() > _MAX_SCHEMA_GRAPH_NODES
			):
				_add_schema_budget_error(
					report,
					record_path,
					options,
					"validation_rules",
					schema_field.validation_rules.size()
				)
				return false
			scheduled_work_count += schema_field.validation_rules.size()
			if not _validate_field_contract(
				schema_field,
				record_path,
				report,
				options,
				auxiliary_state
			):
				return false
			if (
				schema_field.value_type == GFSchemaField.ValueType.DICTIONARY
				and schema_field.dictionary_schema != null
			):
				if scheduled_work_count >= _MAX_SCHEMA_GRAPH_NODES:
					_add_schema_budget_error(report, record_path, options, "schema_edges", 1)
					return false
				scheduled_work_count += 1
				stack.append({
					"kind": "schema",
					"value": schema_field.dictionary_schema,
					"path": record_path,
					"depth": record_depth + 1,
					"exiting": false,
				})
			elif (
				schema_field.value_type == GFSchemaField.ValueType.ARRAY
				and schema_field.array_item_schema != null
			):
				if scheduled_work_count >= _MAX_SCHEMA_GRAPH_NODES:
					_add_schema_budget_error(report, record_path, options, "schema_edges", 1)
					return false
				scheduled_work_count += 1
				stack.append({
					"kind": "field",
					"value": schema_field.array_item_schema,
					"path": "%s[]" % record_path,
					"depth": record_depth + 1,
					"exiting": false,
				})
	_last_definition_footprint = {
		"graph_nodes": scheduled_work_count,
		"auxiliary_nodes": GFVariantData.get_option_int(auxiliary_state, "nodes"),
		"text_bytes": GFVariantData.get_option_int(auxiliary_state, "text_bytes"),
	}
	return true


func _validate_dictionary_schema_contract(
	dictionary_schema: GFDictionarySchema,
	schema_path: String,
	report: GFValidationReport,
	options: Dictionary,
	auxiliary_state: Dictionary
) -> bool:
	if dictionary_schema.allow_extra_fields:
		_add_error(
			report,
			&"extra_fields_allowed",
			"Analytics Dictionary schemas must reject undeclared fields.",
			schema_path,
			options
		)
	if dictionary_schema.coerce_values:
		_add_error(
			report,
			&"coercion_enabled",
			"Analytics Dictionary schemas must not coerce property values.",
			schema_path,
			options
		)
	if String(dictionary_schema.schema_id).length() > _MAX_EVENT_NAME_LENGTH:
		_add_error(
			report,
			&"schema_id_too_long",
			"Analytics Dictionary schema_id exceeds the supported length.",
			schema_path,
			options
		)
		return false
	if not _reserve_schema_text(
		String(dictionary_schema.schema_id),
		schema_path,
		report,
		options,
		auxiliary_state
	):
		return false
	if not _validate_schema_auxiliary_value(
		dictionary_schema.metadata,
		_join_path(schema_path, "metadata"),
		report,
		options,
		auxiliary_state
	):
		return false
	return true


func _validate_field_contract(
	field: GFSchemaField,
	field_path: String,
	report: GFValidationReport,
	options: Dictionary,
	auxiliary_state: Dictionary
) -> bool:
	var value_type: int = int(field.value_type)
	if value_type < GFSchemaField.ValueType.ANY or value_type > GFSchemaField.ValueType.NODE_PATH:
		_add_error(
			report,
			&"invalid_field_value_type",
			"Analytics field value_type is outside the supported enum range.",
			field_path,
			options,
			{
				"actual_value": value_type,
			}
		)
		return false
	if String(field.field_name).length() > _MAX_EVENT_NAME_LENGTH:
		_add_error(
			report,
			&"field_name_too_long",
			"Analytics field name exceeds the supported length.",
			field_path,
			options
		)
		return false
	if not _reserve_schema_text(
		String(field.field_name),
		field_path,
		report,
		options,
		auxiliary_state
	):
		return false
	if field.value_type != GFSchemaField.ValueType.DICTIONARY and field.dictionary_schema != null:
		_add_error(
			report,
			&"unused_dictionary_schema",
			"dictionary_schema is only valid for Dictionary fields.",
			field_path,
			options
		)
	if field.value_type == GFSchemaField.ValueType.DICTIONARY and field.dictionary_schema == null:
		_add_error(
			report,
			&"missing_dictionary_schema",
			"Analytics Dictionary fields require an explicit strict dictionary_schema.",
			field_path,
			options
		)
	if field.value_type != GFSchemaField.ValueType.ARRAY and field.array_item_schema != null:
		_add_error(
			report,
			&"unused_array_item_schema",
			"array_item_schema is only valid for Array fields.",
			field_path,
			options
		)
	if field.value_type == GFSchemaField.ValueType.ARRAY and field.array_item_schema == null:
		_add_error(
			report,
			&"missing_array_item_schema",
			"Analytics Array fields require an explicit array_item_schema.",
			field_path,
			options
		)
	if not _validate_schema_auxiliary_value(
		field.metadata,
		_join_path(field_path, "metadata"),
		report,
		options,
		auxiliary_state
	):
		return false
	if not _validate_schema_auxiliary_value(
		field.default_value,
		_join_path(field_path, "default_value"),
		report,
		options,
		auxiliary_state
	):
		return false
	for rule: GFValidationRule in field.validation_rules:
		if rule == null:
			_add_error(
				report,
				&"missing_validation_rule",
				"Analytics validation rule entries cannot be null.",
				field_path,
				options
			)
			return false
		if rule.callback.is_valid():
			_add_error(
				report,
				&"impure_validation_callback",
				"Analytics schema rules cannot use runtime Callable callbacks.",
				field_path,
				options,
				{
					"rule_id": String(rule.rule_id),
				}
			)
			return false
		if rule.get_script() != _GF_VALIDATION_CONSTRAINT_RULE_SCRIPT:
			_add_error(
				report,
				&"unsupported_validation_rule",
				"Analytics schemas only accept built-in declarative constraint rules.",
				field_path,
				options,
				{
					"rule_id": String(rule.rule_id),
				}
			)
			return false
		if String(rule.rule_id).length() > _MAX_EVENT_NAME_LENGTH:
			_add_error(
				report,
				&"rule_id_too_long",
				"Analytics validation rule id exceeds the supported length.",
				field_path,
				options
			)
			return false
		if not _reserve_schema_text(
			String(rule.rule_id),
			field_path,
			report,
			options,
			auxiliary_state
		):
			return false
		if rule.description.length() > _HARD_MAX_STRING_LENGTH:
			_add_error(
				report,
				&"rule_description_too_long",
				"Analytics validation rule description exceeds the supported length.",
				field_path,
				options
			)
			return false
		if not _reserve_schema_text(
			rule.description,
			field_path,
			report,
			options,
			auxiliary_state
		):
			return false
		if not _validate_schema_auxiliary_value(
			rule.metadata,
			_join_path(field_path, "rule_metadata"),
			report,
			options,
			auxiliary_state
		):
			return false
		if not (rule is GFValidationConstraintRule):
			_add_error(
				report,
				&"unsupported_validation_rule",
				"Analytics schemas only accept built-in declarative constraint rules.",
				field_path,
				options
			)
			return false
		var constraint_rule: GFValidationConstraintRule = rule
		if constraint_rule.pattern.length() > _HARD_MAX_STRING_LENGTH:
			_add_error(
				report,
				&"rule_pattern_too_long",
				"Analytics validation regex exceeds the supported length.",
				field_path,
				options
			)
			return false
		if not _reserve_schema_text(
			constraint_rule.pattern,
			field_path,
			report,
			options,
			auxiliary_state
		):
			return false
		if not _validate_schema_auxiliary_value(
			constraint_rule.allowed_values,
			_join_path(field_path, "allowed_values"),
			report,
			options,
			auxiliary_state
		):
			return false
		if not _validate_constraint_rule_definition(
			constraint_rule,
			field,
			field_path,
			report,
			options
		):
			return false
	return true


func _validate_constraint_rule_definition(
	rule: GFValidationConstraintRule,
	field: GFSchemaField,
	field_path: String,
	report: GFValidationReport,
	options: Dictionary
) -> bool:
	if not rule.enabled:
		_add_error(
			report,
			&"disabled_validation_rule",
			"Analytics validation rules must be enabled.",
			field_path,
			options,
			{
				"rule_id": String(rule.rule_id),
			}
		)
		return false
	if rule.severity != GFValidationIssue.Severity.ERROR:
		_add_error(
			report,
			&"non_error_validation_rule",
			"Analytics validation rules must report errors so invalid events cannot be accepted.",
			field_path,
			options,
			{
				"rule_id": String(rule.rule_id),
			}
		)
		return false
	if rule.target_kind != GFValidationRule.TargetKind.ANY:
		_add_error(
			report,
			&"conditional_validation_rule",
			"Analytics validation rules must target ANY; field types already define applicability.",
			field_path,
			options,
			{
				"rule_id": String(rule.rule_id),
			}
		)
		return false
	var constraint_kind: int = int(rule.constraint_kind)
	if (
		constraint_kind < GFValidationConstraintRule.ConstraintKind.RANGE
		or constraint_kind > GFValidationConstraintRule.ConstraintKind.SIZE
	):
		return _reject_constraint_configuration(rule, field_path, report, options)
	match rule.constraint_kind:
		GFValidationConstraintRule.ConstraintKind.RANGE:
			if field.value_type not in [
				GFSchemaField.ValueType.ANY,
				GFSchemaField.ValueType.INT,
				GFSchemaField.ValueType.FLOAT,
			]:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if not rule.has_minimum and not rule.has_maximum:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if (
				(rule.has_minimum and (is_nan(rule.minimum) or is_inf(rule.minimum)))
				or (rule.has_maximum and (is_nan(rule.maximum) or is_inf(rule.maximum)))
			):
				return _reject_constraint_configuration(rule, field_path, report, options)
			if rule.has_minimum and rule.has_maximum:
				if rule.minimum > rule.maximum:
					return _reject_constraint_configuration(rule, field_path, report, options)
				if (
					rule.minimum == rule.maximum
					and (not rule.inclusive_minimum or not rule.inclusive_maximum)
				):
					return _reject_constraint_configuration(rule, field_path, report, options)
		GFValidationConstraintRule.ConstraintKind.SET:
			if field.value_type in [
				GFSchemaField.ValueType.DICTIONARY,
				GFSchemaField.ValueType.ARRAY,
			]:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if rule.allowed_values.is_empty():
				return _reject_constraint_configuration(rule, field_path, report, options)
			for allowed_value: Variant in rule.allowed_values:
				if not field.is_value_valid(allowed_value):
					return _reject_constraint_configuration(rule, field_path, report, options)
		GFValidationConstraintRule.ConstraintKind.REGEX:
			if field.value_type not in [
				GFSchemaField.ValueType.ANY,
				GFSchemaField.ValueType.STRING,
				GFSchemaField.ValueType.STRING_NAME,
			]:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if rule.pattern.is_empty():
				return _reject_constraint_configuration(rule, field_path, report, options)
			var regex: RegEx = RegEx.new()
			if regex.compile(rule.pattern) != OK:
				return _reject_constraint_configuration(rule, field_path, report, options)
		GFValidationConstraintRule.ConstraintKind.SIZE:
			if field.value_type not in [
				GFSchemaField.ValueType.ANY,
				GFSchemaField.ValueType.STRING,
				GFSchemaField.ValueType.STRING_NAME,
				GFSchemaField.ValueType.DICTIONARY,
				GFSchemaField.ValueType.ARRAY,
			]:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if not rule.has_minimum_size and not rule.has_maximum_size:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if rule.minimum_size < 0 or rule.maximum_size < 0:
				return _reject_constraint_configuration(rule, field_path, report, options)
			if (
				rule.has_minimum_size
				and rule.has_maximum_size
				and rule.minimum_size > rule.maximum_size
			):
				return _reject_constraint_configuration(rule, field_path, report, options)
	return true


func _reject_constraint_configuration(
	rule: GFValidationConstraintRule,
	field_path: String,
	report: GFValidationReport,
	options: Dictionary
) -> bool:
	_add_error(
		report,
		&"invalid_validation_rule_configuration",
		"Analytics validation rule configuration is invalid.",
		field_path,
		options,
		{
			"rule_id": String(rule.rule_id),
			"constraint_kind": int(rule.constraint_kind),
		}
	)
	return false


func _validate_schema_auxiliary_value(
	value: Variant,
	value_path: String,
	report: GFValidationReport,
	options: Dictionary,
	state: Dictionary
) -> bool:
	var scheduled_nodes: int = GFVariantData.get_option_int(state, "nodes")
	if scheduled_nodes >= _MAX_SCHEMA_AUXILIARY_NODES:
		_add_error(
			report,
			&"schema_auxiliary_budget_exceeded",
			"Analytics schema metadata/default values exceed the supported node budget.",
			value_path,
			options,
			{
				"max_total_nodes": _MAX_SCHEMA_AUXILIARY_NODES,
			}
		)
		return false
	state["nodes"] = scheduled_nodes + 1
	var stack: Array[Dictionary] = [{
		"value": value,
		"path": value_path,
		"depth": 0,
		"exiting": false,
	}]
	var active_collections: Array = []
	while not stack.is_empty():
		var record: Dictionary = stack.pop_back()
		var current_value: Variant = GFVariantData.get_option_value(record, "value")
		if GFVariantData.get_option_bool(record, "exiting"):
			if not active_collections.is_empty():
				var _removed_collection: Variant = active_collections.pop_back()
			continue

		var current_path: String = GFVariantData.get_option_string(record, "path")
		var depth: int = GFVariantData.get_option_int(record, "depth")
		if depth > _MAX_SCHEMA_AUXILIARY_DEPTH:
			_add_error(
				report,
				&"schema_auxiliary_depth_exceeded",
				"Analytics schema metadata/default values exceed the supported depth.",
				current_path,
				options
			)
			return false
		if current_value is String or current_value is StringName or current_value is NodePath:
			var text_value: String = GFVariantData.to_text(current_value)
			if text_value.length() > _HARD_MAX_STRING_LENGTH:
				_add_error(
					report,
					&"schema_auxiliary_string_too_long",
					"Analytics schema metadata/default text exceeds the supported length.",
					current_path,
					options
				)
				return false
			if not _reserve_schema_text(
				text_value,
				current_path,
				report,
				options,
				state
			):
				return false

		if current_value is Dictionary:
			var dictionary_value: Dictionary = current_value
			if dictionary_value.size() > _MAX_SCHEMA_CONTAINER_ITEMS:
				_add_schema_budget_error(
					report,
					current_path,
					options,
					"auxiliary_dictionary_items",
					dictionary_value.size()
				)
				return false
			if _contains_same_reference(active_collections, dictionary_value):
				_add_error(
					report,
					&"circular_schema_auxiliary_value",
					"Analytics schema metadata/default values cannot contain circular collections.",
					current_path,
					options
				)
				return false
			if (
				GFVariantData.get_option_int(state, "nodes") + dictionary_value.size() * 2
				> _MAX_SCHEMA_AUXILIARY_NODES
			):
				_add_schema_budget_error(
					report,
					current_path,
					options,
					"auxiliary_nodes",
					dictionary_value.size() * 2
				)
				return false
			state["nodes"] = (
				GFVariantData.get_option_int(state, "nodes")
				+ dictionary_value.size() * 2
			)
			active_collections.append(dictionary_value)
			stack.append({
				"value": dictionary_value,
				"path": current_path,
				"depth": depth,
				"exiting": true,
			})
			var keys: Array = dictionary_value.keys()
			for index: int in range(keys.size() - 1, -1, -1):
				var key: Variant = keys[index]
				if not (key is String or key is StringName):
					_add_error(
						report,
						&"invalid_schema_auxiliary_key",
						"Analytics schema metadata/default Dictionary keys must be text.",
						current_path,
						options
					)
					return false
				var key_text: String = GFVariantData.to_text(key)
				if key_text.length() > _HARD_MAX_STRING_LENGTH:
					_add_error(
						report,
						&"schema_auxiliary_string_too_long",
						"Analytics schema metadata/default key exceeds the supported length.",
						current_path,
						options
					)
					return false
				var child_path: String = _join_path(current_path, key_text)
				stack.append({
					"value": dictionary_value[key],
					"path": child_path,
					"depth": depth + 1,
					"exiting": false,
				})
				stack.append({
					"value": key,
					"path": child_path,
					"depth": depth + 1,
					"exiting": false,
				})
		elif current_value is Array:
			var array_value: Array = current_value
			if array_value.size() > _MAX_SCHEMA_CONTAINER_ITEMS:
				_add_schema_budget_error(
					report,
					current_path,
					options,
					"auxiliary_array_items",
					array_value.size()
				)
				return false
			if _contains_same_reference(active_collections, array_value):
				_add_error(
					report,
					&"circular_schema_auxiliary_value",
					"Analytics schema metadata/default values cannot contain circular collections.",
					current_path,
					options
				)
				return false
			if (
				GFVariantData.get_option_int(state, "nodes") + array_value.size()
				> _MAX_SCHEMA_AUXILIARY_NODES
			):
				_add_schema_budget_error(
					report,
					current_path,
					options,
					"auxiliary_nodes",
					array_value.size()
				)
				return false
			state["nodes"] = (
				GFVariantData.get_option_int(state, "nodes")
				+ array_value.size()
			)
			active_collections.append(array_value)
			stack.append({
				"value": array_value,
				"path": current_path,
				"depth": depth,
				"exiting": true,
			})
			for index: int in range(array_value.size() - 1, -1, -1):
				stack.append({
					"value": array_value[index],
					"path": "%s[%d]" % [current_path, index],
					"depth": depth + 1,
					"exiting": false,
				})
		else:
			var packed_size: int = _get_packed_array_size(current_value)
			if packed_size >= 0:
				if packed_size > _MAX_SCHEMA_CONTAINER_ITEMS:
					_add_schema_budget_error(
						report,
						current_path,
						options,
						"auxiliary_packed_items",
						packed_size
					)
					return false
				if (
					GFVariantData.get_option_int(state, "nodes") + packed_size
					> _MAX_SCHEMA_AUXILIARY_NODES
				):
					_add_schema_budget_error(
						report,
						current_path,
						options,
						"auxiliary_nodes",
						packed_size
					)
					return false
				state["nodes"] = GFVariantData.get_option_int(state, "nodes") + packed_size
				if current_value is PackedStringArray:
					var packed_strings: PackedStringArray = current_value
					for item: String in packed_strings:
						if item.length() > _HARD_MAX_STRING_LENGTH:
							_add_error(
								report,
								&"schema_auxiliary_string_too_long",
								"Analytics schema packed text exceeds the supported length.",
								current_path,
								options
							)
							return false
						if not _reserve_schema_text(
							item,
							current_path,
							report,
							options,
							state
						):
							return false
			elif (
				typeof(current_value) == TYPE_OBJECT
				or typeof(current_value) == TYPE_CALLABLE
				or typeof(current_value) == TYPE_SIGNAL
				or typeof(current_value) == TYPE_RID
			):
				_add_error(
					report,
					&"unsupported_schema_auxiliary_value",
					"Analytics schema metadata/default values cannot retain runtime objects or callables.",
					current_path,
					options,
					{
						"actual_type": type_string(typeof(current_value)),
					}
				)
				return false
	return true


func _reserve_schema_text(
	text_value: String,
	value_path: String,
	report: GFValidationReport,
	options: Dictionary,
	state: Dictionary
) -> bool:
	var current_bytes: int = GFVariantData.get_option_int(state, "text_bytes")
	var added_bytes: int = text_value.to_utf8_buffer().size()
	if current_bytes + added_bytes > _MAX_SCHEMA_TOTAL_TEXT_BYTES:
		_add_error(
			report,
			&"schema_definition_budget_exceeded",
			"Analytics schema definition exceeds the supported total text budget.",
			value_path,
			options,
			{
				"budget": "text_bytes",
				"budget_value": _MAX_SCHEMA_TOTAL_TEXT_BYTES,
				"actual_value": current_bytes + added_bytes,
			}
		)
		return false
	state["text_bytes"] = current_bytes + added_bytes
	return true


func _add_schema_budget_error(
	report: GFValidationReport,
	value_path: String,
	options: Dictionary,
	budget_name: String,
	actual_value: int
) -> void:
	_add_error(
		report,
		&"schema_definition_budget_exceeded",
		"Analytics schema definition exceeds a supported hard budget.",
		value_path,
		options,
		{
			"budget": budget_name,
			"max_total_nodes": _MAX_SCHEMA_GRAPH_NODES,
			"actual_value": actual_value,
		}
	)


func _validate_properties_budget_into(
	properties: Dictionary,
	report: GFValidationReport,
	options: Dictionary
) -> void:
	var max_depth: int = _read_bounded_option(
		options,
		"max_depth",
		_DEFAULT_MAX_DEPTH,
		_HARD_MAX_DEPTH
	)
	var max_property_count: int = _read_bounded_option(
		options,
		"max_property_count",
		_DEFAULT_MAX_PROPERTY_COUNT,
		_HARD_MAX_PROPERTY_COUNT
	)
	var max_string_length: int = _read_bounded_option(
		options,
		"max_string_length",
		_DEFAULT_MAX_STRING_LENGTH,
		_HARD_MAX_STRING_LENGTH
	)
	var max_collection_items: int = _read_bounded_option(
		options,
		"max_collection_items",
		_DEFAULT_MAX_COLLECTION_ITEMS,
		_HARD_MAX_COLLECTION_ITEMS
	)
	var max_total_nodes: int = _read_bounded_option(
		options,
		"max_total_nodes",
		_DEFAULT_MAX_TOTAL_NODES,
		_HARD_MAX_TOTAL_NODES
	)
	var max_total_bytes: int = _read_bounded_option(
		options,
		"max_total_bytes",
		_DEFAULT_MAX_TOTAL_BYTES,
		_HARD_MAX_TOTAL_BYTES
	)
	var root_path: String = _get_properties_path(options)
	if properties.size() > max_property_count:
		_add_error(
			report,
			&"properties_too_wide",
			"Analytics properties exceed the top-level property budget.",
			root_path,
			options,
			{
				"max_property_count": max_property_count,
				"actual_count": properties.size(),
			}
		)
		return

	var stack: Array[Dictionary] = [{
		"value": properties,
		"path": root_path,
		"depth": 0,
		"root": true,
		"exiting": false,
	}]
	var active_collections: Array = []
	var scheduled_node_count: int = 1
	var scheduled_work_bytes: int = _estimate_property_scheduled_bytes(properties)
	if scheduled_work_bytes > max_total_bytes:
		_add_budget_error(
			report,
			&"property_byte_budget_exceeded",
			"Analytics properties exceed the traversal byte budget.",
			root_path,
			options,
			"max_total_bytes",
			max_total_bytes,
			scheduled_work_bytes
		)
		return
	while not stack.is_empty():
		var record: Dictionary = stack.pop_back()
		var value: Variant = GFVariantData.get_option_value(record, "value")
		if GFVariantData.get_option_bool(record, "exiting"):
			if not active_collections.is_empty():
				var _removed_collection: Variant = active_collections.pop_back()
			continue

		var value_path: String = GFVariantData.get_option_string(record, "path")
		var depth: int = GFVariantData.get_option_int(record, "depth")
		if depth > max_depth:
			_add_budget_error(
				report,
				&"property_depth_exceeded",
				"Analytics properties exceed the traversal depth budget.",
				value_path,
				options,
				"max_depth",
				max_depth,
				depth
			)
			return
		if value is String or value is StringName or value is NodePath:
			var text_value: String = GFVariantData.to_text(value)
			if text_value.length() > max_string_length:
				_add_budget_error(
					report,
					&"property_string_too_long",
					"Analytics property text exceeds the string budget.",
					value_path,
					options,
					"max_string_length",
					max_string_length,
					text_value.length()
				)
				return
			var added_text_bytes: int = text_value.to_utf8_buffer().size()
			if scheduled_work_bytes + added_text_bytes > max_total_bytes:
				_add_budget_error(
					report,
					&"property_byte_budget_exceeded",
					"Analytics properties exceed the traversal byte budget.",
					value_path,
					options,
					"max_total_bytes",
					max_total_bytes,
					scheduled_work_bytes + added_text_bytes
				)
				return
			scheduled_work_bytes += added_text_bytes

		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if _contains_same_reference(active_collections, dictionary_value):
				_add_error(
					report,
					&"circular_property_value",
					"Analytics properties cannot contain circular collections.",
					value_path,
					options
				)
				return
			var is_root: bool = GFVariantData.get_option_bool(record, "root")
			if not is_root and dictionary_value.size() > max_collection_items:
				_add_collection_budget_error(
					report,
					value_path,
					dictionary_value.size(),
					max_collection_items,
					options
				)
				return
			var dictionary_child_count: int = dictionary_value.size() * 2
			if scheduled_node_count + dictionary_child_count > max_total_nodes:
				_add_budget_error(
					report,
					&"property_node_budget_exceeded",
					"Analytics properties exceed the traversal node budget.",
					value_path,
					options,
					"max_total_nodes",
					max_total_nodes,
					scheduled_node_count + dictionary_child_count
				)
				return
			scheduled_node_count += dictionary_child_count
			active_collections.append(dictionary_value)
			stack.append({
				"value": dictionary_value,
				"path": value_path,
				"depth": depth,
				"root": is_root,
				"exiting": true,
			})
			var keys: Array = dictionary_value.keys()
			for index: int in range(keys.size() - 1, -1, -1):
				var key: Variant = keys[index]
				if not (key is String or key is StringName):
					_add_error(
						report,
						&"invalid_property_key_type",
						"Analytics property keys must be String or StringName.",
						value_path,
						options,
						{
							"actual_type": type_string(typeof(key)),
						}
					)
					return
				var key_text: String = GFVariantData.to_text(key)
				if key_text.length() > max_string_length:
					_add_budget_error(
						report,
						&"property_string_too_long",
						"Analytics property key exceeds the string budget.",
						value_path,
						options,
						"max_string_length",
						max_string_length,
						key_text.length()
					)
					return
				var added_work_bytes: int = (
					key_text.to_utf8_buffer().size()
					+ 2
					+ _estimate_property_scheduled_bytes(dictionary_value[key])
				)
				if scheduled_work_bytes + added_work_bytes > max_total_bytes:
					_add_budget_error(
						report,
						&"property_byte_budget_exceeded",
						"Analytics properties exceed the traversal byte budget.",
						value_path,
						options,
						"max_total_bytes",
						max_total_bytes,
						scheduled_work_bytes + added_work_bytes
					)
					return
				scheduled_work_bytes += added_work_bytes
				var child_path: String = _join_path(value_path, key_text)
				stack.append({
					"value": dictionary_value[key],
					"path": child_path,
					"depth": depth + 1,
					"root": false,
					"exiting": false,
				})
		elif value is Array:
			var array_value: Array = value
			if _contains_same_reference(active_collections, array_value):
				_add_error(
					report,
					&"circular_property_value",
					"Analytics properties cannot contain circular collections.",
					value_path,
					options
				)
				return
			if array_value.size() > max_collection_items:
				_add_collection_budget_error(
					report,
					value_path,
					array_value.size(),
					max_collection_items,
					options
				)
				return
			if scheduled_node_count + array_value.size() > max_total_nodes:
				_add_budget_error(
					report,
					&"property_node_budget_exceeded",
					"Analytics properties exceed the traversal node budget.",
					value_path,
					options,
					"max_total_nodes",
					max_total_nodes,
					scheduled_node_count + array_value.size()
				)
				return
			scheduled_node_count += array_value.size()
			active_collections.append(array_value)
			stack.append({
				"value": array_value,
				"path": value_path,
				"depth": depth,
				"root": false,
				"exiting": true,
			})
			for index: int in range(array_value.size() - 1, -1, -1):
				var added_work_bytes: int = _estimate_property_scheduled_bytes(array_value[index])
				if scheduled_work_bytes + added_work_bytes > max_total_bytes:
					_add_budget_error(
						report,
						&"property_byte_budget_exceeded",
						"Analytics properties exceed the traversal byte budget.",
						value_path,
						options,
						"max_total_bytes",
						max_total_bytes,
						scheduled_work_bytes + added_work_bytes
					)
					return
				scheduled_work_bytes += added_work_bytes
				stack.append({
					"value": array_value[index],
					"path": "%s[%d]" % [value_path, index],
					"depth": depth + 1,
					"root": false,
					"exiting": false,
				})
		else:
			var packed_size: int = _get_packed_array_size(value)
			if packed_size < 0:
				continue
			if packed_size > max_collection_items:
				_add_collection_budget_error(
					report,
					value_path,
					packed_size,
					max_collection_items,
					options
				)
				return
			if scheduled_node_count + packed_size > max_total_nodes:
				_add_budget_error(
					report,
					&"property_node_budget_exceeded",
					"Analytics properties exceed the traversal node budget.",
					value_path,
					options,
					"max_total_nodes",
					max_total_nodes,
					scheduled_node_count + packed_size
				)
				return
			scheduled_node_count += packed_size
			if value is PackedStringArray:
				var packed_strings: PackedStringArray = value
				var packed_text_bytes: int = 0
				for item: String in packed_strings:
					if item.length() > max_string_length:
						_add_budget_error(
							report,
							&"property_string_too_long",
							"Analytics packed text exceeds the string budget.",
							value_path,
							options,
							"max_string_length",
							max_string_length,
							item.length()
						)
						return
					packed_text_bytes += item.to_utf8_buffer().size() + 3
				if scheduled_work_bytes + packed_text_bytes > max_total_bytes:
					_add_budget_error(
						report,
						&"property_byte_budget_exceeded",
						"Analytics properties exceed the traversal byte budget.",
						value_path,
						options,
						"max_total_bytes",
						max_total_bytes,
						scheduled_work_bytes + packed_text_bytes
					)
					return
				scheduled_work_bytes += packed_text_bytes
			else:
				var packed_work_bytes: int = packed_size * 16
				if scheduled_work_bytes + packed_work_bytes > max_total_bytes:
					_add_budget_error(
						report,
						&"property_byte_budget_exceeded",
						"Analytics properties exceed the traversal byte budget.",
						value_path,
						options,
						"max_total_bytes",
						max_total_bytes,
						scheduled_work_bytes + packed_work_bytes
					)
					return
				scheduled_work_bytes += packed_work_bytes


func _make_report(options: Dictionary) -> GFValidationReport:
	var subject: String = _read_context_text(options, "subject")
	if subject.is_empty():
		subject = "analytics:%s@%d" % [String(event_name), schema_version]
	return GFValidationReport.new(subject, {
		"event_name": String(event_name),
		"schema_version": schema_version,
	})


func _make_properties_context(options: Dictionary) -> Dictionary:
	var context: Dictionary = {}
	context["subject"] = _read_context_text(
		options,
		"subject",
		"analytics:%s@%d" % [String(event_name), schema_version]
	)
	context["path"] = _get_properties_path(options)
	var source_path: String = _read_context_text(options, "source_path")
	if not source_path.is_empty():
		context["source_path"] = source_path
	var source: String = _read_context_text(options, "source")
	if not source.is_empty():
		context["source"] = source
	if options.has("line"):
		context["line"] = GFVariantData.get_option_int(options, "line")
	if options.has("column"):
		context["column"] = GFVariantData.get_option_int(options, "column")
	return context


func _get_properties_path(options: Dictionary) -> String:
	return _read_context_text(options, "path", "properties")


func _read_context_text(
	options: Dictionary,
	key: String,
	fallback: String = ""
) -> String:
	var value: String = GFVariantData.get_option_string(options, key, fallback)
	if value.length() <= _HARD_MAX_STRING_LENGTH:
		return value
	return value.left(_HARD_MAX_STRING_LENGTH)


func _read_bounded_option(
	options: Dictionary,
	key: String,
	default_value: int,
	hard_maximum: int
) -> int:
	return clampi(GFVariantData.get_option_int(options, key, default_value), 1, hard_maximum)


func _make_graph_identity(record_kind: String, value: Variant) -> String:
	if value is Object:
		var object_value: Object = value
		return "%s:%d" % [record_kind, object_value.get_instance_id()]
	return "%s:null" % record_kind


func _contains_same_reference(active_collections: Array, value: Variant) -> bool:
	for active_value: Variant in active_collections:
		if is_same(active_value, value):
			return true
	return false


func _get_packed_array_size(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var packed_bytes: PackedByteArray = value
			return packed_bytes.size()
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return packed_int32.size()
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return packed_int64.size()
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			return packed_float32.size()
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			return packed_float64.size()
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return packed_strings.size()
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector2: PackedVector2Array = value
			return packed_vector2.size()
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector3: PackedVector3Array = value
			return packed_vector3.size()
		TYPE_PACKED_COLOR_ARRAY:
			var packed_colors: PackedColorArray = value
			return packed_colors.size()
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector4: PackedVector4Array = value
			return packed_vector4.size()
	return -1


func _estimate_property_scheduled_bytes(value: Variant) -> int:
	if value is String or value is StringName or value is NodePath:
		return 2
	if value is Dictionary or value is Array:
		return 2
	var packed_size: int = _get_packed_array_size(value)
	if packed_size >= 0:
		return 2
	match typeof(value):
		TYPE_NIL:
			return 4
		TYPE_BOOL:
			return 5
		TYPE_INT, TYPE_FLOAT:
			return 32
		_:
			return 256


func _add_collection_budget_error(
	report: GFValidationReport,
	value_path: String,
	actual_count: int,
	maximum_count: int,
	options: Dictionary
) -> void:
	_add_budget_error(
		report,
		&"property_collection_too_large",
		"Analytics property collection exceeds the item budget.",
		value_path,
		options,
		"max_collection_items",
		maximum_count,
		actual_count
	)


func _contains_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint < 0x20 or codepoint == 0x7f:
			return true
	return false


func _add_budget_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	value_path: String,
	options: Dictionary,
	budget_name: String,
	budget_value: int,
	actual_value: int
) -> void:
	_add_error(report, kind, message, value_path, options, {
		"budget": budget_name,
		"budget_value": budget_value,
		"actual_value": actual_value,
	})


func _add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	issue_path: String,
	options: Dictionary,
	issue_metadata: Dictionary = {}
) -> void:
	var metadata: Dictionary = issue_metadata.duplicate(true)
	metadata["event_name"] = String(event_name)
	metadata["schema_version"] = schema_version
	var issue: RefCounted = report.add_error(kind, message, issue_path, issue_path, metadata)
	if issue is GFValidationIssue:
		var validation_issue: GFValidationIssue = issue
		validation_issue.source_path = _read_context_text(options, "source_path")
		if validation_issue.source_path.is_empty():
			validation_issue.source_path = _read_context_text(options, "source")
		validation_issue.subject = report.subject


func _join_path(base_path: String, child_path: String) -> String:
	if base_path.is_empty():
		return child_path
	if child_path.is_empty():
		return base_path
	return base_path.path_join(child_path)
