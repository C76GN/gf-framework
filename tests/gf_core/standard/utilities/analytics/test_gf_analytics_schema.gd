## 测试版本化 Analytics Schema 的严格性、预算和注册表隔离边界。
extends GutTest


# --- 测试类型 ---

class UnsupportedValidationRule:
	extends GFValidationRule


class ImpureEventSchema:
	extends GFAnalyticsEventSchema

	var validate_calls: int = 0

	func validate_definition(options: Dictionary = {}) -> GFValidationReport:
		validate_calls += 1
		return GFValidationReport.new("impure", options)


class ImpureDictionarySchema:
	extends GFDictionarySchema

	var validate_calls: int = 0

	func validate_definition(options: Dictionary = {}) -> GFValidationReport:
		validate_calls += 1
		return GFValidationReport.new("impure", options)


class ImpureSchemaField:
	extends GFSchemaField


# --- 测试方法 ---

func test_schema_rejects_c0_and_del_event_name_controls() -> void:
	for event_name: StringName in [
		StringName("opened\u0001hidden"),
		StringName("opened\u007fhidden"),
	]:
		var event_schema: GFAnalyticsEventSchema = _make_event_schema(
			event_name,
			1,
			_make_strict_dictionary_schema(&"analytics_control_name")
		)
		var report: GFValidationReport = event_schema.validate_definition()

		assert_true(
			_report_has_kind(report, &"invalid_event_name"),
			"版本化事件名必须拒绝 C0 与 DEL 控制字符。"
		)


func test_valid_strict_schema_accepts_declared_nested_properties() -> void:
	var nested_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_context")
	var label_field: GFSchemaField = _make_field(&"label", GFSchemaField.ValueType.STRING, true)
	assert_true(nested_schema.add_field(label_field), "测试嵌套 Schema 应接受唯一字段。")
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_opened")
	var count_field: GFSchemaField = _make_field(&"count", GFSchemaField.ValueType.INT, true)
	var context_field: GFSchemaField = _make_field(&"context", GFSchemaField.ValueType.DICTIONARY, true)
	context_field.dictionary_schema = nested_schema
	assert_true(root_schema.add_field(count_field), "测试根 Schema 应接受 count 字段。")
	assert_true(root_schema.add_field(context_field), "测试根 Schema 应接受 context 字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"opened", 1, root_schema)

	var report: GFValidationReport = event_schema.validate_properties({
		"count": 2,
		"context": {
			"label": "menu",
		},
	})

	assert_true(report.is_ok(), "严格且完整的嵌套属性应通过校验。")


func test_nested_schema_must_reject_extra_fields_and_coercion() -> void:
	var nested_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_nested")
	nested_schema.allow_extra_fields = true
	nested_schema.coerce_values = true
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_root")
	var nested_field: GFSchemaField = _make_field(&"nested", GFSchemaField.ValueType.DICTIONARY, true)
	nested_field.dictionary_schema = nested_schema
	assert_true(root_schema.add_field(nested_field), "测试根 Schema 应接受嵌套字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"strictness", 1, root_schema)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"extra_fields_allowed"), "所有嵌套 Dictionary 都必须关闭额外字段。")
	assert_true(_report_has_kind(report, &"coercion_enabled"), "所有嵌套 Dictionary 都必须关闭类型转换。")


func test_container_fields_require_explicit_nested_schemas() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_container_contract")
	var dictionary_field: GFSchemaField = _make_field(
		&"dictionary_value",
		GFSchemaField.ValueType.DICTIONARY,
		false
	)
	var array_field: GFSchemaField = _make_field(
		&"array_value",
		GFSchemaField.ValueType.ARRAY,
		false
	)
	assert_true(root_schema.add_field(dictionary_field), "测试根 Schema 应接受 Dictionary 字段。")
	assert_true(root_schema.add_field(array_field), "测试根 Schema 应接受 Array 字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(
		&"container_contract",
		1,
		root_schema
	)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"missing_dictionary_schema"), "Dictionary 字段必须显式声明严格子 Schema。")
	assert_true(_report_has_kind(report, &"missing_array_item_schema"), "Array 字段必须显式声明元素 Schema。")


func test_schema_rejects_callable_validation_rules() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_callback")
	var value_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.INT, true)
	var callback_rule: GFValidationRule = GFValidationRule.new().configure(
		&"runtime_callback",
		func(
			_target: Variant,
			_report: GFValidationReport,
			_context: Dictionary
		) -> bool:
			return true
	)
	assert_true(value_field.add_validation_rule(callback_rule), "测试字段应接受通用回调规则。")
	assert_true(root_schema.add_field(value_field), "测试根 Schema 应接受 value 字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"callback", 1, root_schema)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"impure_validation_callback"), "Analytics Schema 不得执行运行时 Callable。")


func test_schema_rejects_custom_rules_that_cannot_be_copied_safely() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_custom_rule")
	var value_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.INT, true)
	var custom_rule: UnsupportedValidationRule = UnsupportedValidationRule.new()
	custom_rule.rule_id = &"custom"
	assert_true(value_field.add_validation_rule(custom_rule), "测试字段应接受自定义规则以验证 Analytics 边界。")
	assert_true(root_schema.add_field(value_field), "测试根 Schema 应接受 value 字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"custom_rule", 1, root_schema)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"unsupported_validation_rule"), "Analytics Schema 只能接受可安全复制的内置声明式规则。")


func test_registry_rejects_scripted_schema_subclasses_before_dynamic_callbacks() -> void:
	var exact_properties: GFDictionarySchema = _make_strict_dictionary_schema(
		&"analytics_impure_event"
	)
	var impure_event: ImpureEventSchema = ImpureEventSchema.new()
	impure_event.event_name = &"impure_event"
	impure_event.schema_version = 1
	impure_event.properties_schema = exact_properties
	var registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()

	var event_registration: Dictionary = registry.register_schema(impure_event)

	assert_false(GFVariantData.get_option_bool(event_registration, "ok"), "Registry 不得接纳脚本化 EventSchema 子类。")
	assert_eq(impure_event.validate_calls, 0, "拒绝必须发生在调用可覆写定义校验之前。")
	var event_validation: Dictionary = GFVariantData.get_option_dictionary(
		event_registration,
		"validation"
	)
	assert_true(
		JSON.stringify(event_validation).contains("unsupported_schema_definition_type"),
		"脚本化 EventSchema 应返回稳定定义类型错误。"
	)

	var impure_dictionary: ImpureDictionarySchema = ImpureDictionarySchema.new()
	var _configured_impure_dictionary: GFDictionarySchema = impure_dictionary.configure(
		&"analytics_impure_dictionary",
		[],
		{
			"allow_extra_fields": false,
			"coerce_values": false,
		}
	)
	var dictionary_event: GFAnalyticsEventSchema = _make_event_schema(
		&"impure_dictionary",
		1,
		impure_dictionary
	)
	var dictionary_report: GFValidationReport = dictionary_event.validate_definition()
	assert_true(
		_report_has_kind(dictionary_report, &"unsupported_schema_definition_type"),
		"脚本化 DictionarySchema 子类必须在基础校验回调前拒绝。"
	)
	assert_eq(impure_dictionary.validate_calls, 0, "不得调用脚本化 DictionarySchema 的覆写校验。")

	var exact_dictionary: GFDictionarySchema = _make_strict_dictionary_schema(
		&"analytics_impure_field"
	)
	var impure_field: ImpureSchemaField = ImpureSchemaField.new()
	impure_field.field_name = &"value"
	impure_field.value_type = GFSchemaField.ValueType.INT
	assert_true(exact_dictionary.add_field(impure_field), "测试根 Schema 应接受待审计字段子类。")
	var field_report: GFValidationReport = _make_event_schema(
		&"impure_field",
		1,
		exact_dictionary
	).validate_definition()
	assert_true(
		_report_has_kind(field_report, &"unsupported_schema_definition_type"),
		"脚本化 SchemaField 子类必须失败关闭。"
	)


func test_schema_rejects_invalid_field_enums_null_rules_and_advisory_constraints() -> void:
	var invalid_type_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_invalid_type")
	var invalid_type_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.INT, true)
	invalid_type_field.set("value_type", 999)
	assert_true(invalid_type_schema.add_field(invalid_type_field), "测试根 Schema 应接受待审计字段。")
	var invalid_type_event: GFAnalyticsEventSchema = _make_event_schema(
		&"invalid_type",
		1,
		invalid_type_schema
	)

	var null_rule_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_null_rule")
	var null_rule_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.INT, true)
	null_rule_field.validation_rules.append(null)
	assert_true(null_rule_schema.add_field(null_rule_field), "测试根 Schema 应接受含空规则的字段。")
	var null_rule_event: GFAnalyticsEventSchema = _make_event_schema(&"null_rule", 1, null_rule_schema)

	var advisory_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_advisory")
	var advisory_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.INT, true)
	var advisory_rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_range(
		0.0,
		10.0,
		{
			"severity": GFValidationIssue.Severity.WARNING,
		}
	)
	advisory_field.validation_rules.append(advisory_rule)
	assert_true(advisory_schema.add_field(advisory_field), "测试根 Schema 应接受 advisory 规则字段。")
	var advisory_event: GFAnalyticsEventSchema = _make_event_schema(&"advisory", 1, advisory_schema)

	assert_true(
		_report_has_kind(invalid_type_event.validate_definition(), &"invalid_field_value_type"),
		"越界 value_type 不得退化为 ANY。"
	)
	assert_true(
		_report_has_kind(null_rule_event.validate_definition(), &"missing_validation_rule"),
		"null 规则不得被静默忽略。"
	)
	assert_true(
		_report_has_kind(advisory_event.validate_definition(), &"non_error_validation_rule"),
		"WARNING/INFO 规则不得成为可被 is_ok 忽略的 Analytics 强契约。"
	)


func test_schema_rejects_invalid_constraint_configuration_at_registration_time() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_invalid_constraint")
	var value_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.STRING, true)
	var invalid_regex: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_regex(
		"",
		{
			"rule_id": &"invalid_regex",
		}
	)
	value_field.validation_rules.append(invalid_regex)
	assert_true(root_schema.add_field(value_field), "测试根 Schema 应接受待审计正则规则。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(
		&"invalid_constraint",
		1,
		root_schema
	)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"invalid_validation_rule_configuration"), "无效正则必须在注册时失败，而不是等首个事件触发。")


func test_schema_definition_rejects_invalid_event_identity_bounds() -> void:
	var invalid_name_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(
		StringName("invalid\nname")
	)
	var invalid_version_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(
		&"invalid_version",
		2_147_483_648
	)

	var invalid_name_report: GFValidationReport = invalid_name_schema.validate_definition()
	var invalid_version_report: GFValidationReport = invalid_version_schema.validate_definition()
	var maximum_version_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(
		&"maximum_version",
		2_147_483_647
	)
	var registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()
	var maximum_registration: Dictionary = registry.register_schema(maximum_version_schema)

	assert_true(_report_has_kind(invalid_name_report, &"invalid_event_name"), "事件名不得包含换行符。")
	assert_true(_report_has_kind(invalid_version_report, &"schema_version_out_of_range"), "Schema 版本必须保持在 PackedInt32 可表达范围内。")
	assert_true(
		GFVariantData.get_option_bool(maximum_registration, "ok"),
		"PackedInt32 正上界应仍可注册。"
	)
	assert_eq(
		registry.get_versions(&"maximum_version"),
		PackedInt32Array([2_147_483_647]),
		"Registry 应保留正上界版本。"
	)


func test_schema_definition_budgets_rules_and_circular_auxiliary_values() -> void:
	var rule_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_rule_budget")
	var value_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.INT, true)
	for index: int in range(65):
		var rule: GFValidationConstraintRule = GFValidationConstraintRule.new()
		rule.rule_id = StringName("rule_%d" % index)
		value_field.validation_rules.append(rule)
	assert_true(rule_schema.add_field(value_field), "测试根 Schema 应接受规则预算字段。")
	var rule_event_schema: GFAnalyticsEventSchema = _make_event_schema(&"rule_budget", 1, rule_schema)

	var circular_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_metadata_cycle")
	circular_schema.metadata["self"] = circular_schema.metadata
	var circular_event_schema: GFAnalyticsEventSchema = _make_event_schema(
		&"metadata_cycle",
		1,
		circular_schema
	)

	var rule_report: GFValidationReport = rule_event_schema.validate_definition()
	var circular_report: GFValidationReport = circular_event_schema.validate_definition()

	assert_true(_report_has_kind(rule_report, &"schema_definition_budget_exceeded"), "单字段规则数量必须受硬预算限制。")
	assert_true(_report_has_kind(circular_report, &"circular_schema_auxiliary_value"), "Schema metadata 循环必须在复制前被拒绝。")
	var _cycle_removed: bool = circular_schema.metadata.erase("self")


func test_schema_definition_enforces_cumulative_text_budget_before_copy_in() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_text_budget")
	var metadata_text: PackedStringArray = PackedStringArray()
	for _index: int in range(65):
		var _text_appended: bool = metadata_text.append("x".repeat(65_536))
	root_schema.metadata["text"] = metadata_text
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"text_budget", 1, root_schema)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"schema_definition_budget_exceeded"), "Schema 的累计文本预算必须在注册表深复制前拒绝超大定义。")


func test_schema_graph_budget_counts_shared_dag_expansion_paths() -> void:
	var shared_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_dag_leaf")
	for level: int in range(14):
		var parent_schema: GFDictionarySchema = _make_strict_dictionary_schema(
			StringName("analytics_dag_%d" % level)
		)
		for branch: String in ["left", "right"]:
			var field: GFSchemaField = _make_field(
				StringName("%s_%d" % [branch, level]),
				GFSchemaField.ValueType.DICTIONARY,
				true
			)
			field.dictionary_schema = shared_schema
			assert_true(parent_schema.add_field(field), "共享 DAG 测试字段应成功加入。")
		shared_schema = parent_schema
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"shared_dag", 1, shared_schema)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"schema_definition_budget_exceeded"), "预检必须按展开路径计费，阻止基础定义校验指数级重复遍历。")


func test_circular_schema_definition_is_reported_without_recursing_forever() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_circular")
	var recursive_field: GFSchemaField = _make_field(&"child", GFSchemaField.ValueType.DICTIONARY, false)
	recursive_field.dictionary_schema = root_schema
	assert_true(root_schema.add_field(recursive_field), "测试根 Schema 应接受循环引用字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"circular_schema", 1, root_schema)

	var report: GFValidationReport = event_schema.validate_definition()

	assert_true(_report_has_kind(report, &"circular_schema"), "循环 Schema 应由基础定义校验报告。")
	recursive_field.dictionary_schema = null


func test_property_budget_rejects_wide_collection_before_schema_validation() -> void:
	var event_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"bounded_collection")
	var values: Array[int] = [1, 2, 3]

	var report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": values,
		},
		{
			"max_collection_items": 2,
		}
	)

	assert_true(_report_has_kind(report, &"property_collection_too_large"), "集合预算应在通用深复制校验前拒绝超限数据。")


func test_property_budget_rejects_depth_nodes_strings_and_invalid_keys() -> void:
	var event_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"bounded_values")
	var depth_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": [[1]],
		},
		{
			"max_depth": 2,
		}
	)
	var node_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": [1, 2],
		},
		{
			"max_total_nodes": 3,
		}
	)
	var string_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": "abcd",
		},
		{
			"max_string_length": 3,
		}
	)
	var invalid_key_report: GFValidationReport = event_schema.validate_properties({
		"payload": {
			1: "invalid",
		},
	})
	var byte_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": "x".repeat(1024),
		},
		{
			"max_total_bytes": 1024,
		}
	)

	assert_true(_report_has_kind(depth_report, &"property_depth_exceeded"), "深度预算必须限制嵌套属性。")
	assert_true(_report_has_kind(node_report, &"property_node_budget_exceeded"), "节点预算必须限制完整属性图。")
	assert_true(_report_has_kind(string_report, &"property_string_too_long"), "字符串预算必须限制属性值。")
	assert_true(_report_has_kind(invalid_key_report, &"invalid_property_key_type"), "属性 Dictionary 键必须是 String 或 StringName。")
	assert_true(_report_has_kind(byte_report, &"property_byte_budget_exceeded"), "累计 UTF-8 工作字节必须在报告编码前受 payload 预算限制。")


func test_property_budget_counts_packed_items_and_validates_packed_text_and_keys() -> void:
	var event_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"packed_budget")
	var long_key_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": {
				"123456789": true,
			},
		},
		{
			"max_string_length": 8,
		}
	)
	var packed_string_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": PackedStringArray(["123456789"]),
		},
		{
			"max_string_length": 8,
		}
	)
	var packed_node_report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": PackedInt32Array([1, 2]),
		},
		{
			"max_total_nodes": 4,
		}
	)

	assert_true(_report_has_kind(long_key_report, &"property_string_too_long"), "Dictionary 键必须在构造路径前受字符串预算限制。")
	assert_true(_report_has_kind(packed_string_report, &"property_string_too_long"), "PackedStringArray 元素必须受字符串预算限制。")
	assert_true(_report_has_kind(packed_node_report, &"property_node_budget_exceeded"), "PackedArray 元素必须计入完整属性图节点预算。")


func test_property_budget_rejects_circular_collections_before_deep_copy() -> void:
	var event_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"circular_properties")
	var circular_value: Dictionary = {}
	circular_value["self"] = circular_value

	var report: GFValidationReport = event_schema.validate_properties({
		"payload": circular_value,
	})

	assert_true(_report_has_kind(report, &"circular_property_value"), "循环属性必须在通用深复制前被拒绝。")
	var _cycle_removed: bool = circular_value.erase("self")


func test_unknown_validation_options_are_not_deep_copied_into_schema_contexts() -> void:
	var event_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"bounded_options")
	var circular_options: Dictionary = {}
	circular_options["unknown"] = circular_options

	var report: GFValidationReport = event_schema.validate_properties(
		{
			"payload": 1,
		},
		circular_options
	)

	assert_true(report.is_ok(), "未知循环 options 不应被透传到会深复制的基础 Schema 上下文。")
	var _cycle_removed: bool = circular_options.erase("unknown")


func test_event_schema_duplicate_is_deeply_isolated() -> void:
	var nested_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_nested_copy")
	nested_schema.metadata = {
		"owner": "original",
	}
	var nested_value_field: GFSchemaField = _make_field(&"value", GFSchemaField.ValueType.STRING, false)
	nested_value_field.default_value = {
		"marker": "original",
	}
	assert_true(nested_schema.add_field(nested_value_field), "测试嵌套 Schema 应接受 value 字段。")
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_root_copy")
	var nested_field: GFSchemaField = _make_field(&"nested", GFSchemaField.ValueType.DICTIONARY, true)
	nested_field.dictionary_schema = nested_schema
	assert_true(root_schema.add_field(nested_field), "测试根 Schema 应接受 nested 字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"copy", 1, root_schema)

	var copied_schema: GFAnalyticsEventSchema = event_schema.duplicate_schema()
	nested_schema.allow_extra_fields = true
	nested_schema.metadata["owner"] = "mutated"
	nested_value_field.default_value["marker"] = "mutated"

	var copied_nested_field: GFSchemaField = copied_schema.properties_schema.get_field(&"nested")
	var copied_nested_schema: GFDictionarySchema = copied_nested_field.dictionary_schema
	var copied_value_field: GFSchemaField = copied_nested_schema.get_field(&"value")
	assert_false(is_same(copied_schema.properties_schema, event_schema.properties_schema), "事件 Schema 副本必须隔离根 Dictionary Schema。")
	assert_false(is_same(copied_nested_schema, nested_schema), "事件 Schema 副本必须隔离嵌套 Dictionary Schema。")
	assert_false(copied_nested_schema.allow_extra_fields, "原 Schema 修改不得污染副本的严格性。")
	assert_eq(GFVariantData.get_option_string(copied_nested_schema.metadata, "owner"), "original", "嵌套 metadata 必须深复制。")
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.as_dictionary(copied_value_field.default_value), "marker"),
		"original",
		"字段默认值必须深复制。"
	)


func test_registry_uses_copy_in_and_copy_out_isolation() -> void:
	var event_schema: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"copy_boundary")
	var registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()

	var registration: Dictionary = registry.register_schema(event_schema)
	event_schema.event_name = &"mutated"
	event_schema.properties_schema.allow_extra_fields = true
	var first_copy: GFAnalyticsEventSchema = registry.get_schema(&"copy_boundary", 1)
	first_copy.properties_schema.allow_extra_fields = true
	var second_copy: GFAnalyticsEventSchema = registry.get_schema(&"copy_boundary", 1)

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "合法 Schema 应注册成功。")
	assert_not_null(first_copy, "注册表必须保留注册时的事件名。")
	assert_not_null(second_copy, "注册表应能重复返回隔离副本。")
	if first_copy == null or second_copy == null:
		return
	assert_false(second_copy.properties_schema.allow_extra_fields, "注册后的原对象与 getter 返回值都不得改写已存契约。")
	assert_false(is_same(first_copy, second_copy), "每次 getter 都必须返回新的事件 Schema 副本。")


func test_registry_requires_exact_version_and_sorts_versions() -> void:
	var registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()
	var version_three: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"versioned", 3)
	var version_one: GFAnalyticsEventSchema = _make_any_payload_event_schema(&"versioned", 1)
	var register_three: Dictionary = registry.register_schema(version_three)
	var register_one: Dictionary = registry.register_schema(version_one)

	var missing_report: GFValidationReport = registry.validate(&"versioned", 2, {
		"payload": "value",
	})

	assert_true(GFVariantData.get_option_bool(register_three, "ok"), "版本 3 应注册成功。")
	assert_true(GFVariantData.get_option_bool(register_one, "ok"), "版本 1 应注册成功。")
	assert_eq(registry.get_versions(&"versioned"), PackedInt32Array([1, 3]), "版本列表必须按升序稳定返回。")
	assert_true(_report_has_kind(missing_report, &"schema_not_registered"), "未注册版本不得隐式回退到其他版本。")


func test_registry_rejects_duplicate_version_and_snapshot_excludes_schema_data() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_private")
	root_schema.metadata = {
		"secret": "private_metadata",
	}
	var private_field: GFSchemaField = _make_field(&"payload", GFSchemaField.ValueType.STRING, false)
	private_field.default_value = "private_default"
	assert_true(root_schema.add_field(private_field), "测试根 Schema 应接受 payload 字段。")
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(&"private_event", 1, root_schema)
	var registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()
	var first_result: Dictionary = registry.register_schema(event_schema)
	var duplicate_result: Dictionary = registry.register_schema(event_schema)

	var snapshot_text: String = JSON.stringify(registry.get_debug_snapshot())

	assert_true(GFVariantData.get_option_bool(first_result, "ok"), "首次注册应成功。")
	assert_false(GFVariantData.get_option_bool(duplicate_result, "ok"), "同事件同版本不得覆盖。")
	assert_eq(GFVariantData.get_option_string(duplicate_result, "reason"), "already_registered", "重复版本应返回稳定原因。")
	assert_false(snapshot_text.contains("private_metadata"), "调试快照不得导出 Schema metadata。")
	assert_false(snapshot_text.contains("private_default"), "调试快照不得导出默认值或业务属性。")


func test_registry_enforces_cumulative_definition_footprint() -> void:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(&"analytics_registry_budget")
	var metadata_text: PackedStringArray = PackedStringArray()
	for _index: int in range(16):
		var _text_appended: bool = metadata_text.append("x".repeat(65_536))
	root_schema.metadata["text"] = metadata_text
	var event_schema: GFAnalyticsEventSchema = _make_event_schema(
		&"registry_budget_0",
		1,
		root_schema
	)
	var registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()
	var failure: Dictionary = {}
	for index: int in range(20):
		event_schema.event_name = StringName("registry_budget_%d" % index)
		var registration: Dictionary = registry.register_schema(event_schema)
		if not GFVariantData.get_option_bool(registration, "ok"):
			failure = registration
			break

	assert_false(failure.is_empty(), "注册表应在累计定义 footprint 达到硬上限时 fail closed。")
	assert_eq(
		GFVariantData.get_option_string(failure, "reason"),
		"registry_budget_exceeded",
		"累计定义预算应返回稳定失败原因。"
	)
	var snapshot: Dictionary = registry.get_debug_snapshot()
	assert_true(
		GFVariantData.get_option_int(snapshot, "registered_text_bytes")
		<= GFVariantData.get_option_int(snapshot, "max_total_text_bytes"),
		"注册表调试计数不得超过声明的累计文本上限。"
	)


# --- 私有/辅助方法 ---

func _make_strict_dictionary_schema(schema_id: StringName) -> GFDictionarySchema:
	return GFDictionarySchema.new().configure(
		schema_id,
		[],
		{
			"allow_extra_fields": false,
			"coerce_values": false,
		}
	)


func _make_field(
	field_name: StringName,
	value_type: GFSchemaField.ValueType,
	required: bool
) -> GFSchemaField:
	return GFSchemaField.new().configure(
		field_name,
		value_type,
		{
			"required": required,
		}
	)


func _make_event_schema(
	event_name: StringName,
	schema_version: int,
	properties_schema: GFDictionarySchema
) -> GFAnalyticsEventSchema:
	return GFAnalyticsEventSchema.new().configure(
		event_name,
		schema_version,
		properties_schema
	)


func _make_any_payload_event_schema(
	event_name: StringName,
	schema_version: int = 1
) -> GFAnalyticsEventSchema:
	var root_schema: GFDictionarySchema = _make_strict_dictionary_schema(
		StringName("%s_properties" % String(event_name))
	)
	var payload_field: GFSchemaField = _make_field(&"payload", GFSchemaField.ValueType.ANY, true)
	var _field_added: bool = root_schema.add_field(payload_field)
	return _make_event_schema(event_name, schema_version, root_schema)


func _report_has_kind(report: GFValidationReport, expected_kind: StringName) -> bool:
	for issue: RefCounted in report.issues:
		if issue is GFValidationIssue:
			var validation_issue: GFValidationIssue = issue
			if validation_issue.kind == expected_kind:
				return true
	return false
