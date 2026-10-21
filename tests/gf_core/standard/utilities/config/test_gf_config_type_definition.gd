@tool

# 验证配置类型图的公共准入、规范化、隔离和有限工作边界。
extends GutTest


# --- 公共方法 ---

## 继承字段在前且通过同一列标量转换，默认值与结果均为副本。
func test_struct_inheritance_normalizes_fields_and_defaults() -> void:
	var base: GFConfigTypeDefinition = _structure(&"Base")
	base.fields.append(_column(&"id", GFConfigTableColumn.ValueType.INT))
	var derived: GFConfigTypeDefinition = _structure(&"Derived")
	derived.base_type = base
	var amount: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.FLOAT)
	amount.default_value = "2.5"
	derived.fields.append(amount)
	var report: Dictionary = derived.try_normalize({ "id": "7" })
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == true
	assert_true(
		report_ok_matches,
		str(report["issues"])
	)
	var report_value: Variant = report["value"]
	var report_value_matches: bool = typeof(report_value) == TYPE_DICTIONARY and report_value == { "id": 7, "amount": 2.5 }
	assert_true(report_value_matches)
	var amount_default_value: Variant = amount.default_value
	var amount_default_value_matches: bool = typeof(amount_default_value) == TYPE_STRING and amount_default_value == "2.5"
	assert_true(amount_default_value_matches)
	var description: Dictionary = derived.describe()
	var description_ok: Variant = description["ok"]
	var description_ok_matches: bool = typeof(description_ok) == TYPE_BOOL and description_ok == true
	assert_true(description_ok_matches)
	var definition: Dictionary = description["definition"]
	var definition_field_name: Variant = definition["fields"][0]["field_name"]
	var definition_field_name_matches: bool = typeof(definition_field_name) == TYPE_STRING_NAME and definition_field_name == &"id"
	assert_true(definition_field_name_matches)
	var definition_field_name_2: Variant = definition["fields"][1]["field_name"]
	var definition_field_name_2_matches: bool = typeof(definition_field_name_2) == TYPE_STRING_NAME and definition_field_name_2 == &"amount"
	assert_true(definition_field_name_2_matches)
	var definition_type_name: Variant = definition["base_type"]["type_name"]
	var definition_type_name_matches: bool = typeof(definition_type_name) == TYPE_STRING_NAME and definition_type_name == &"Base"
	assert_true(definition_type_name_matches)


## 未知字段与被覆盖的继承字段必须拒绝，不能产生部分成功值。
func test_struct_rejects_unknown_fields_and_inherited_override() -> void:
	var base: GFConfigTypeDefinition = _structure(&"Base")
	base.fields.append(_column(&"id", GFConfigTableColumn.ValueType.INT))
	var report: Dictionary = base.try_normalize({ "id": "2", "typo": 3 })
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	var report_value: Variant = report["value"]
	assert_true(report_value == null)
	assert_true(_has_kind(report, "extra_field"))
	var child: GFConfigTypeDefinition = _structure(&"Child")
	child.base_type = base
	child.fields.append(_column(&"id", GFConfigTableColumn.ValueType.STRING))
	var invalid: Dictionary = child.describe()
	var invalid_ok: Variant = invalid["ok"]
	var invalid_ok_matches: bool = typeof(invalid_ok) == TYPE_BOOL and invalid_ok == false
	assert_true(invalid_ok_matches)
	assert_true(_has_kind(invalid, "duplicate_struct_field"))
	var invalid_definition: Variant = invalid["definition"]
	var invalid_definition_matches: bool = typeof(invalid_definition) == TYPE_DICTIONARY and invalid_definition == {}
	assert_true(invalid_definition_matches)


## 嵌套数组中的失败保留完整文本路径和无歧义片段。
func test_nested_failure_preserves_field_path_and_source() -> void:
	var item: GFConfigTypeDefinition = _structure(&"Effect")
	item.fields.append(_column(&"amount", GFConfigTableColumn.ValueType.INT))
	var array_type: GFConfigTypeDefinition = _array(item)
	var report: Dictionary = array_type.try_normalize(
		[
			{ "amount": "bad" },
		],
		{
			"field": &"effects",
			"source": "effects.csv",
			"line": 9,
			"sheet_name": "Effects",
			"cell": "C9",
		}
	)
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	var report_value: Variant = report["value"]
	assert_true(report_value == null)
	var issue: Dictionary = _first_issue(report, "coerce_failed")
	var issue_field_path: Variant = issue["field_path"]
	var issue_field_path_matches: bool = typeof(issue_field_path) == TYPE_STRING and issue_field_path == "effects[0].amount"
	assert_true(issue_field_path_matches)
	var issue_field_segments: Variant = issue["field_segments"]
	var issue_field_segments_matches: bool = typeof(issue_field_segments) == TYPE_ARRAY and issue_field_segments == [
		"effects",
		0,
		"amount",
	]
	assert_true(issue_field_segments_matches)
	var issue_source: Variant = issue["source"]
	var issue_source_matches: bool = typeof(issue_source) == TYPE_STRING and issue_source == "effects.csv"
	assert_true(issue_source_matches)
	var issue_cell: Variant = issue["cell"]
	var issue_cell_matches: bool = typeof(issue_cell) == TYPE_STRING and issue_cell == "C9"
	assert_true(issue_cell_matches)


## 映射键转换必须拒绝碰撞，而非后一个值覆盖前一个值。
func test_map_key_normalization_rejects_collisions() -> void:
	var map_type: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	map_type.kind = GFConfigTypeDefinition.Kind.MAP
	map_type.map_key_type = GFConfigTableColumn.ValueType.INT
	map_type.map_value_type = _scalar(GFConfigTableColumn.ValueType.FLOAT)
	var valid: Dictionary = map_type.try_normalize({ "2": "3.5" })
	var valid_ok: Variant = valid["ok"]
	var valid_ok_matches: bool = typeof(valid_ok) == TYPE_BOOL and valid_ok == true
	assert_true(valid_ok_matches)
	var valid_value: Variant = valid["value"]
	var valid_value_matches: bool = typeof(valid_value) == TYPE_DICTIONARY and valid_value == { 2: 3.5 }
	assert_true(valid_value_matches)
	var collision: Dictionary = map_type.try_normalize({ "01": 2, "1": 3 })
	var collision_ok: Variant = collision["ok"]
	var collision_ok_matches: bool = typeof(collision_ok) == TYPE_BOOL and collision_ok == false
	assert_true(collision_ok_matches)
	var collision_value: Variant = collision["value"]
	assert_true(collision_value == null)
	assert_true(_has_kind(collision, "duplicate_map_key"))


## 枚举只接受明确整数值，不能借截断浮点或未知数值进入已知分支。
func test_enum_rejects_unknown_and_fractional_values() -> void:
	var definition: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	definition.kind = GFConfigTypeDefinition.Kind.ENUM
	definition.symbols = { "IDLE": 0, "ACTIVE": 1 }
	var definition_normalize_value: Variant = definition.try_normalize("1")["value"]
	var definition_normalize_value_matches: bool = typeof(definition_normalize_value) == TYPE_INT and definition_normalize_value == 1
	assert_true(definition_normalize_value_matches)
	var definition_normalize_ok: Variant = definition.try_normalize(1.5)["ok"]
	var definition_normalize_ok_matches: bool = typeof(definition_normalize_ok) == TYPE_BOOL and definition_normalize_ok == false
	assert_true(definition_normalize_ok_matches)
	var definition_normalize_ok_2: Variant = definition.try_normalize(2)["ok"]
	var definition_normalize_ok_2_matches: bool = typeof(definition_normalize_ok_2) == TYPE_BOOL and definition_normalize_ok_2 == false
	assert_true(definition_normalize_ok_2_matches)
	definition.symbols["ALIAS"] = 1
	var definition_validate_definition_ok: Variant = definition.validate_definition()["ok"]
	var definition_validate_definition_ok_matches: bool = typeof(definition_validate_definition_ok) == TYPE_BOOL and definition_validate_definition_ok == false
	assert_true(definition_validate_definition_ok_matches)


## 多态只允许声明分支及其字段，判别键不能丢失或被强制转换。
func test_polymorphic_selection_rejects_unknown_and_foreign_fields() -> void:
	var circle: GFConfigTypeDefinition = _structure(&"circle")
	circle.fields.append(_column(&"radius", GFConfigTableColumn.ValueType.FLOAT))
	var rectangle: GFConfigTypeDefinition = _structure(&"rectangle")
	rectangle.fields.append(_column(&"width", GFConfigTableColumn.ValueType.FLOAT))
	var definition: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	definition.kind = GFConfigTypeDefinition.Kind.POLYMORPHIC
	definition.variants = [circle, rectangle]
	var valid: Dictionary = definition.try_normalize({ "type": "circle", "radius": "2.5" })
	var valid_ok: Variant = valid["ok"]
	var valid_ok_matches: bool = typeof(valid_ok) == TYPE_BOOL and valid_ok == true
	assert_true(
		valid_ok_matches,
		str(valid["issues"])
	)
	var valid_value: Variant = valid["value"]
	var valid_value_matches: bool = typeof(valid_value) == TYPE_DICTIONARY and valid_value == { "type": "circle", "radius": 2.5 }
	assert_true(valid_value_matches)
	var definition_normalize_ok: Variant = definition.try_normalize({ "radius": 1.0 })["ok"]
	var definition_normalize_ok_matches: bool = typeof(definition_normalize_ok) == TYPE_BOOL and definition_normalize_ok == false
	assert_true(definition_normalize_ok_matches)
	var definition_normalize_ok_2: Variant = definition.try_normalize({ "type": "unknown" })["ok"]
	var definition_normalize_ok_2_matches: bool = typeof(definition_normalize_ok_2) == TYPE_BOOL and definition_normalize_ok_2 == false
	assert_true(definition_normalize_ok_2_matches)
	var definition_normalize_ok_3: Variant = definition.try_normalize({ "type": "circle", "width": 1.0 })["ok"]
	var definition_normalize_ok_3_matches: bool = typeof(definition_normalize_ok_3) == TYPE_BOOL and definition_normalize_ok_3 == false
	assert_true(definition_normalize_ok_3_matches)


## required 的原始存在性不会被默认值掩盖，null 继续遵守字段约束。
func test_required_and_null_constraints_remain_field_owned() -> void:
	var definition: GFConfigTypeDefinition = _structure(&"Value")
	var field: GFConfigTableColumn = _column(&"count", GFConfigTableColumn.ValueType.INT)
	field.required = true
	field.default_value = 2
	field.allow_null = false
	definition.fields.append(field)
	assert_true(
		_has_kind(
			definition.try_normalize({}),
			"missing_required"
		)
	)
	assert_true(
		_has_kind(
			definition.try_normalize({ "count": null }),
			"null_value"
		)
	)
	field.required = false
	field.allow_null = true
	var definition_normalize_ok: Variant = definition.try_normalize({ "count": null })["ok"]
	var definition_normalize_ok_matches: bool = typeof(definition_normalize_ok) == TYPE_BOOL and definition_normalize_ok == true
	assert_true(definition_normalize_ok_matches)


## 循环 schema、循环数据和低深度预算均失败，不能递归复制输入。
func test_cycles_and_depth_budget_fail_closed() -> void:
	var definition: GFConfigTypeDefinition = _array(null)
	definition.element_type = definition
	assert_true(
		_has_kind(
			definition.validate_definition(),
			"cyclic_type_definition"
		)
	)
	assert_null(definition.duplicate_definition())
	definition.element_type = _scalar(GFConfigTableColumn.ValueType.INT)
	var data: Array = []
	data.append(data)
	var report: Dictionary = definition.try_normalize(data)
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	var report_value: Variant = report["value"]
	assert_true(report_value == null)
	data.clear()
	var nested: GFConfigTypeDefinition = _array(definition)
	var nested_validate_definition_ok: Variant = nested.validate_definition(
		{
			"work_limits": { "max_depth": 1 },
		}
	)["ok"]
	var nested_validate_definition_ok_matches: bool = typeof(nested_validate_definition_ok) == TYPE_BOOL and nested_validate_definition_ok == false
	assert_true(nested_validate_definition_ok_matches)
	var definition_normalize_ok: Variant = definition.try_normalize(
		[
			1,
			2,
			3,
		],
		{
			"work_limits": { "max_work_units": 3 },
		}
	)["ok"]
	var definition_normalize_ok_matches: bool = typeof(definition_normalize_ok) == TYPE_BOOL and definition_normalize_ok == false
	assert_true(definition_normalize_ok_matches)


## 同一类型先从浅路径缓存后，较深路径仍检查完整子树；遍历顺序不能改变准入。
func test_shared_type_depth_is_checked_at_every_path() -> void:
	for reverse_fields: bool in [false, true]:
		var shared: GFConfigTypeDefinition = _array(_scalar(GFConfigTableColumn.ValueType.INT))
		var shallow: GFConfigTableColumn = _column(&"shallow", GFConfigTableColumn.ValueType.ANY)
		shallow.type_definition = shared
		var deep: GFConfigTableColumn = _column(&"deep", GFConfigTableColumn.ValueType.ANY)
		deep.type_definition = _array(shared)
		var definition: GFConfigTypeDefinition = _structure(&"SharedType")
		definition.fields = [shallow, deep]
		if reverse_fields:
			definition.fields.reverse()
		_assert_shared_depth_boundary(definition, 4)
		var copied: GFConfigTypeDefinition = definition.duplicate_definition()
		assert_not_null(copied)
		if copied != null:
			var shallow_copy: GFConfigTypeDefinition = copied.fields[1 if reverse_fields else 0].type_definition
			var deep_copy: GFConfigTypeDefinition = copied.fields[0 if reverse_fields else 1].type_definition
			assert_same(shallow_copy, deep_copy.element_type)
			assert_not_same(shallow_copy, shared)


## 共享字段缓存也包含其类型后代深度，不能只检查再次遇到字段时的当前层数。
func test_shared_column_depth_is_checked_at_every_path() -> void:
	for reverse_fields: bool in [false, true]:
		var shared: GFConfigTableColumn = _column(&"shared", GFConfigTableColumn.ValueType.ANY)
		shared.type_definition = _scalar(GFConfigTableColumn.ValueType.INT)
		var holder: GFConfigTypeDefinition = _structure(&"Holder")
		holder.fields = [shared]
		var nested: GFConfigTableColumn = _column(&"nested", GFConfigTableColumn.ValueType.ANY)
		nested.type_definition = holder
		var definition: GFConfigTypeDefinition = _structure(&"SharedColumn")
		definition.fields = [shared, nested]
		if reverse_fields:
			definition.fields.reverse()
		_assert_shared_depth_boundary(definition, 4)
		var copied: GFConfigTypeDefinition = definition.duplicate_definition()
		assert_not_null(copied)
		if copied != null:
			var shared_copy: GFConfigTableColumn = copied.fields[1 if reverse_fields else 0]
			var nested_copy: GFConfigTableColumn = copied.fields[0 if reverse_fields else 1]
			assert_same(
				shared_copy,
				nested_copy.type_definition.fields[0]
			)
			assert_not_same(shared_copy, shared)


## 结构问题沿用统一报告清洗，包括叶来源替换；报告不保留对象或借用调用者集合。
func test_structured_issue_context_uses_report_sanitizer() -> void:
	var diagnostic_object: RefCounted = RefCounted.new()
	var row_key: Dictionary = {
		"owner": diagnostic_object,
		"values": [7],
		"non_finite": INF,
	}
	var location: Dictionary = {
		"source": [diagnostic_object],
		"cell": RID(),
		"line": INF,
	}
	var options: Dictionary = {
		"field": &"amount",
		"row_key": row_key,
		"row_index": 0,
		"row_locations": [
			{
				"fields": { "amount": location },
			},
		],
	}
	var report: Dictionary = _scalar(GFConfigTableColumn.ValueType.INT).try_normalize("bad", options)
	var issue: Dictionary = _first_issue(report, "coerce_failed")
	var field: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.INT)
	var range_rule: GFConfigRangeValidationRule = GFConfigRangeValidationRule.new()
	range_rule.has_minimum = true
	range_rule.minimum = 1.0
	field.validation_rules.append(range_rule)
	var definition: GFConfigTypeDefinition = _structure(&"Ranged")
	definition.fields = [field]
	var rule_options: Dictionary = options.duplicate()
	rule_options["field"] = &""
	var rule_report: Dictionary = definition.try_normalize(
		{ "amount": 0 },
		rule_options
	)
	var rule_issue: Dictionary = _first_issue(rule_report, "range_below_minimum")
	var expected_context: Dictionary = location.duplicate()
	expected_context["row_key"] = row_key
	var builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var expected_report: Dictionary = builder.make_report()
	builder.add_issue(
		expected_report,
		"error",
		"expected",
		&"",
		row_key,
		&"amount",
		"expected",
		expected_context
	)
	var expected_issue: Dictionary = _first_issue(expected_report, "expected")
	for actual_issue: Dictionary in [issue, rule_issue]:
		for key: String in [
			"row_key",
			"source",
			"cell",
			"line",
		]:
			var matches: bool = typeof(actual_issue.get(key)) == typeof(expected_issue.get(key)) and actual_issue.get(key) == expected_issue.get(key)
			assert_true(
				matches,
				"Structured context must use the existing report sanitizer: " + key
			)
	row_key.clear()
	location.clear()
	var isolated: bool = issue.get("row_key") == expected_issue.get("row_key")
	assert_true(isolated, "Returned issue must not borrow caller context.")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(report))
	assert_true(round_trip is Dictionary)
	var cycle: Array = []
	cycle.append(cycle)
	var expected_cycle: Variant = GFReportValueCodec.to_json_compatible(cycle)
	var cyclic_report: Dictionary = _scalar(GFConfigTableColumn.ValueType.INT).try_normalize(
		"bad",
		{ "row_key": cycle }
	)
	cycle.clear()
	var cyclic_issue: Dictionary = _first_issue(cyclic_report, "coerce_failed")
	var cycle_matches: bool = typeof(cyclic_issue.get("row_key")) == typeof(expected_cycle) and cyclic_issue.get("row_key") == expected_cycle
	assert_true(cycle_matches)


## 定义失败与值失败使用相同根路径；显式片段优先，显示路径不被猜测成结构片段。
func test_public_definition_entries_preserve_root_issue_path() -> void:
	var invalid: GFConfigTypeDefinition = _scalar(GFConfigTableColumn.ValueType.ANY)
	var nested: GFConfigTypeDefinition = _structure(&"Nested")
	var field: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.ANY)
	field.type_definition = invalid
	nested.fields = [field]
	var contexts: Array[Dictionary] = [
		{
			"field_segments": [
				"payload",
				"items",
				2,
			],
			"field_path": "ignored",
		},
		{ "field": &"payload" },
		{ "field_path": "payload.items[2]" },
	]
	var roots: Array[String] = [
		"payload.items[2]",
		"payload",
		"payload.items[2]",
	]
	var root_segments: Array[Array] = [
		[
			"payload",
			"items",
			2,
		],
		["payload"],
		[],
	]
	for index: int in contexts.size():
		for definition: GFConfigTypeDefinition in [invalid, nested]:
			var expected_path: String = roots[index]
			var expected_segments: Array = root_segments[index].duplicate()
			if definition == nested:
				expected_path += ".amount"
				expected_segments.append("amount")
			var reports: Array[Dictionary] = [
				definition.validate_definition(contexts[index]),
				definition.compile_definition(contexts[index]),
				definition.describe(contexts[index]),
				definition.try_normalize(
					{},
					contexts[index]
				),
			]
			for report: Dictionary in reports:
				var issue: Dictionary = _first_issue(report, "invalid_scalar_type")
				var path_matches: bool = issue.get("field_path") == expected_path
				var segments_match: bool = issue.get("field_segments") == expected_segments
				assert_true(path_matches)
				assert_true(segments_match)


## 描述阶段耗尽预算时仍保留根上下文，足额预算不能被修复路径提前拒绝。
func test_description_budget_failures_preserve_root_issue_path() -> void:
	var definition: GFConfigTypeDefinition = _scalar(GFConfigTableColumn.ValueType.INT)
	var contexts: Array[Dictionary] = [
		{
			"field_segments": ["payload", 2],
			"field": &"ignored",
			"field_path": "ignored",
		},
		{ "field": &"payload", "field_path": "ignored", },
		{ "field_path": "payload.items[2]" },
	]
	var roots: Array[String] = [
		"payload[2]",
		"payload",
		"payload.items[2]",
	]
	var root_segments: Array[Array] = [
		["payload", 2],
		["payload"],
		[],
	]
	for index: int in contexts.size():
		for limit: int in [1, 2]:
			var options: Dictionary = contexts[index].duplicate()
			options["work_limits"] = { "max_work_units": limit }
			var accepted: bool = limit == 2
			var described: Dictionary = definition.describe(options)
			var compiled: Dictionary = definition.compile_definition(options)
			for report: Dictionary in [described, compiled]:
				var ok_matches: bool = typeof(report.get("ok")) == TYPE_BOOL and report.get("ok") == accepted
				assert_true(ok_matches)
				var result_definition: Variant = report.get("definition")
				assert_true(result_definition is Dictionary)
				if result_definition is Dictionary:
					var description: Dictionary = result_definition
					assert_eq(
						description.is_empty(),
						not accepted
					)
				assert_eq(
					_has_kind(report, "config_work_limit_exceeded"),
					not accepted
				)
				if not accepted:
					var issue: Dictionary = _first_issue(report, "config_work_limit_exceeded")
					var path_matches: bool = issue.get("field_path") == roots[index]
					var segments_match: bool = issue.get("field_segments") == root_segments[index]
					assert_true(path_matches)
					assert_true(segments_match)


## 已有叶路径的预算问题不得被根上下文覆盖。
func test_budget_failure_preserves_existing_leaf_issue_path() -> void:
	var definition: GFConfigTypeDefinition = _structure(&"Nested")
	var field: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.ANY)
	field.type_definition = _scalar(GFConfigTableColumn.ValueType.INT)
	definition.fields = [field]
	var report: Dictionary = definition.validate_definition(
		{
			"field": &"payload",
			"work_limits": { "max_depth": 1 },
		}
	)
	var issue: Dictionary = _first_issue(report, "config_work_depth_exceeded")
	var path_matches: bool = issue.get("field_path") == "payload.amount"
	var segments_match: bool = issue.get("field_segments") == ["payload", "amount"]
	assert_true(path_matches)
	assert_true(segments_match)


## 复制保留无效默认值但不触发校验，正式准入才拒绝它。
func test_copy_preserves_invalid_defaults_without_running_rules() -> void:
	_CountingRule.calls = 0
	var definition: GFConfigTypeDefinition = _structure(&"Value")
	var field: GFConfigTableColumn = _column(&"count", GFConfigTableColumn.ValueType.INT)
	field.default_value = "bad"
	field.validation_rules.append(_CountingRule.new())
	definition.fields.append(field)
	var copied: GFConfigTypeDefinition = definition.duplicate_definition()
	assert_not_null(copied)
	var copied_default_value: Variant = copied.fields[0].default_value
	var copied_default_value_matches: bool = typeof(copied_default_value) == TYPE_STRING and copied_default_value == "bad"
	assert_true(copied_default_value_matches)
	assert_eq(_CountingRule.calls, 0)
	var copied_validate_definition_ok: Variant = copied.validate_definition()["ok"]
	var copied_validate_definition_ok_matches: bool = typeof(copied_validate_definition_ok) == TYPE_BOOL and copied_validate_definition_ok == false
	assert_true(copied_validate_definition_ok_matches)
	copied.fields[0].default_value = 3
	var copied_validate_definition_ok_2: Variant = copied.validate_definition()["ok"]
	var copied_validate_definition_ok_2_matches: bool = typeof(copied_validate_definition_ok_2) == TYPE_BOOL and copied_validate_definition_ok_2 == true
	assert_true(copied_validate_definition_ok_2_matches)
	assert_eq(_CountingRule.calls, 1)
	var field_default_value: Variant = field.default_value
	var field_default_value_matches: bool = typeof(field_default_value) == TYPE_STRING and field_default_value == "bad"
	assert_true(field_default_value_matches)


## 同一调用编译后的节点不读取后改资源，而独立调用看到新声明。
func test_compilation_snapshot_isolated_from_later_resource_mutation() -> void:
	var definition: GFConfigTypeDefinition = _scalar(GFConfigTableColumn.ValueType.INT)
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new()
	var node: Dictionary = compiler.compile_type(definition)
	compiler.validate_defaults()
	definition.scalar_type = GFConfigTableColumn.ValueType.STRING
	var compiler_normalize_type_value: Variant = compiler.normalize_type(node, "8")["value"]
	var compiler_normalize_type_value_matches: bool = typeof(compiler_normalize_type_value) == TYPE_INT and compiler_normalize_type_value == 8
	assert_true(compiler_normalize_type_value_matches)
	var definition_normalize_value: Variant = definition.try_normalize(8)["value"]
	var definition_normalize_value_matches: bool = typeof(definition_normalize_value) == TYPE_STRING and definition_normalize_value == "8"
	assert_true(definition_normalize_value_matches)
	var output: Dictionary = compiler.describe_type(node)
	output["scalar_type"] = GFConfigTableColumn.ValueType.BOOL
	var compiler_describe_type_scalar_type: Variant = compiler.describe_type(node)["scalar_type"]
	var compiler_describe_type_scalar_type_matches: bool = typeof(compiler_describe_type_scalar_type) == TYPE_INT and compiler_describe_type_scalar_type == GFConfigTableColumn.ValueType.INT
	assert_true(compiler_describe_type_scalar_type_matches)


## Schema 表校验返回隔离规范化数据；任一行失败时整批 data 为 null。
func test_schema_normalizes_batch_and_never_returns_partial_data() -> void:
	var item: GFConfigTypeDefinition = _structure(&"Effect")
	item.fields.append(_column(&"amount", GFConfigTableColumn.ValueType.INT))
	var column: GFConfigTableColumn = _column(&"effects", GFConfigTableColumn.ValueType.ANY)
	column.type_definition = _array(item)
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(column)
	schema.coerce_values = true
	var rows: Array = [
		{
			"effects": [
				{ "amount": "4" },
			],
		},
	]
	var report: Dictionary = schema.validate_table(rows)
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == true
	assert_true(
		report_ok_matches,
		str(report["issues"])
	)
	var report_data: Variant = report["data"]
	var report_data_matches: bool = typeof(report_data) == TYPE_ARRAY and report_data == [
		{
			"effects": [
				{ "amount": 4 },
			],
		},
	]
	assert_true(report_data_matches)
	var normalized: Array = report["data"]
	normalized[0]["effects"][0]["amount"] = 12
	var rows_amount: Variant = rows[0]["effects"][0]["amount"]
	var rows_amount_matches: bool = typeof(rows_amount) == TYPE_STRING and rows_amount == "4"
	assert_true(rows_amount_matches)
	rows.append(
		{
			"effects": [
				{ "amount": "bad" },
			],
		}
	)
	var invalid: Dictionary = schema.validate_table(rows)
	var invalid_ok: Variant = invalid["ok"]
	var invalid_ok_matches: bool = typeof(invalid_ok) == TYPE_BOOL and invalid_ok == false
	assert_true(invalid_ok_matches)
	var invalid_data: Variant = invalid["data"]
	assert_true(invalid_data == null)
	var invalid_record: Dictionary = rows[1]
	assert_eq(
		schema.coerce_record(invalid_record),
		{}
	)


## 共享编译会话只验证一次默认值；某行值失败不把下一行误报为定义失败。
func test_shared_session_defaults_once_and_value_errors_do_not_poison_schema() -> void:
	_CountingRule.calls = 0
	var item: GFConfigTypeDefinition = _structure(&"Item")
	var field: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.INT)
	field.default_value = 2
	field.validation_rules.append(_CountingRule.new())
	item.fields.append(field)
	var column: GFConfigTableColumn = _column(&"payload", GFConfigTableColumn.ValueType.ANY)
	column.type_definition = item
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(column)
	schema.coerce_values = true
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new()
	var options: Dictionary = { "__gf_config_type_compiler": compiler }
	var schema_validate_definition_ok: Variant = schema.validate_definition(options)["ok"]
	var schema_validate_definition_ok_matches: bool = typeof(schema_validate_definition_ok) == TYPE_BOOL and schema_validate_definition_ok == true
	assert_true(schema_validate_definition_ok_matches)
	assert_eq(_CountingRule.calls, 1)
	var schema_validate_record_ok: Variant = schema.validate_record(
		{
			"payload": { "amount": "bad" },
		},
		null,
		options
	)["ok"]
	var schema_validate_record_ok_matches: bool = typeof(schema_validate_record_ok) == TYPE_BOOL and schema_validate_record_ok == false
	assert_true(schema_validate_record_ok_matches)
	var valid: Dictionary = schema.validate_record(
		{
			"payload": { "amount": "4" },
		},
		null,
		options
	)
	var valid_ok: Variant = valid["ok"]
	var valid_ok_matches: bool = typeof(valid_ok) == TYPE_BOOL and valid_ok == true
	assert_true(
		valid_ok_matches,
		str(valid["issues"])
	)
	assert_eq(_CountingRule.calls, 2)


## 描述只读取类型形状和原始默认值，不代替正式默认值准入或执行规则。
func test_describe_is_read_only_and_shared_schema_descriptions_are_isolated() -> void:
	_CountingRule.calls = 0
	var item: GFConfigTypeDefinition = _structure(&"Item")
	var field: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.INT)
	field.default_value = "2"
	field.validation_rules.append(_CountingRule.new())
	item.fields.append(field)
	var column: GFConfigTableColumn = _column(&"payload", GFConfigTableColumn.ValueType.ANY)
	column.type_definition = item
	var other: GFConfigTableColumn = _column(&"other", GFConfigTableColumn.ValueType.ANY)
	other.type_definition = item
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns = [column, other]
	var item_describe_ok: Variant = item.describe()["ok"]
	var item_describe_ok_matches: bool = typeof(item_describe_ok) == TYPE_BOOL and item_describe_ok == true
	assert_true(item_describe_ok_matches)
	var column_describe_ok: Variant = column.describe()["type_definition"]["ok"]
	var column_describe_ok_matches: bool = typeof(column_describe_ok) == TYPE_BOOL and column_describe_ok == true
	assert_true(column_describe_ok_matches)
	var description: Dictionary = schema.describe()
	assert_eq(_CountingRule.calls, 0)
	var first: Dictionary = description["columns"][0]["type_definition"]["definition"]
	var second: Dictionary = description["columns"][1]["type_definition"]["definition"]
	var first_default_value: Variant = first["fields"][0]["default_value"]
	var first_default_value_matches: bool = typeof(first_default_value) == TYPE_STRING and first_default_value == "2"
	assert_true(first_default_value_matches)
	first["fields"][0]["default_value"] = 99
	var second_default_value: Variant = second["fields"][0]["default_value"]
	var second_default_value_matches: bool = typeof(second_default_value) == TYPE_STRING and second_default_value == "2"
	assert_true(second_default_value_matches)
	var field_default_value: Variant = field.default_value
	var field_default_value_matches: bool = typeof(field_default_value) == TYPE_STRING and field_default_value == "2"
	assert_true(field_default_value_matches)
	var schema_validate_definition_ok: Variant = schema.validate_definition()["ok"]
	var schema_validate_definition_ok_matches: bool = typeof(schema_validate_definition_ok) == TYPE_BOOL and schema_validate_definition_ok == true
	assert_true(schema_validate_definition_ok_matches)
	assert_eq(_CountingRule.calls, 1)


## 错误分支 Resource 与循环默认值都显式失败，描述及复制不降级成普通字段。
func test_type_admission_rejects_wrong_branch_resource_and_cyclic_default() -> void:
	var polymorphic: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	polymorphic.kind = GFConfigTypeDefinition.Kind.POLYMORPHIC
	polymorphic.variants.append(Resource.new())
	assert_true(
		_has_kind(
			polymorphic.validate_definition(),
			"invalid_polymorphic_branch"
		)
	)
	var polymorphic_describe_ok: Variant = polymorphic.describe()["ok"]
	var polymorphic_describe_ok_matches: bool = typeof(polymorphic_describe_ok) == TYPE_BOOL and polymorphic_describe_ok == false
	assert_true(polymorphic_describe_ok_matches)
	assert_null(polymorphic.duplicate_definition())
	var column: GFConfigTableColumn = _column(&"payload", GFConfigTableColumn.ValueType.ANY)
	column.type_definition = _structure(&"Value")
	var cyclic: Dictionary = {}
	cyclic["self"] = cyclic
	column.default_value = cyclic
	var description: Dictionary = column.describe()
	var description_ok: Variant = description["type_definition"]["ok"]
	var description_ok_matches: bool = typeof(description_ok) == TYPE_BOOL and description_ok == false
	assert_true(description_ok_matches)
	var description_default_value: Variant = description["default_value"]
	assert_true(description_default_value == null)
	assert_null(column.duplicate_column())
	cyclic.clear()


## 共享预算一旦耗尽，后续调用仍失败，不能因错误已记录而返回空的成功值。
func test_exhausted_shared_budget_remains_failed_for_later_values() -> void:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_work_units": 16 })
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new({ "work_budget": budget })
	var node: Dictionary = compiler.compile_type(_scalar(GFConfigTableColumn.ValueType.INT))
	compiler.validate_defaults()
	var compiler_normalize_type_ok: Variant = compiler.normalize_type(node, "3")["ok"]
	var compiler_normalize_type_ok_matches: bool = typeof(compiler_normalize_type_ok) == TYPE_BOOL and compiler_normalize_type_ok == true
	assert_true(compiler_normalize_type_ok_matches)
	assert_false(budget.consume_work(100))
	var first: Dictionary = compiler.normalize_type(node, "4")
	var second: Dictionary = compiler.normalize_type(node, "5")
	var first_ok: Variant = first["ok"]
	var first_ok_matches: bool = typeof(first_ok) == TYPE_BOOL and first_ok == false
	assert_true(first_ok_matches)
	var second_ok: Variant = second["ok"]
	var second_ok_matches: bool = typeof(second_ok) == TYPE_BOOL and second_ok == false
	assert_true(second_ok_matches)
	var first_value: Variant = first["value"]
	assert_true(first_value == null)
	var second_value: Variant = second["value"]
	assert_true(second_value == null)


## 失败 schema 副本不能替换既有 Provider 状态，也不能伪装成成功的空数据库。
func test_copy_failure_preserves_provider_state_and_rejects_database_factory() -> void:
	var good_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	good_schema.table_name = &"items"
	var good: GFConfigTableResource = GFConfigTableResource.new()
	good.table_name = &"items"
	good.schema = good_schema
	good.records = [
		{ "id": 1 },
	]
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(good))
	var cyclic: GFConfigTypeDefinition = _array(null)
	cyclic.element_type = cyclic
	var column: GFConfigTableColumn = _column(&"payload", GFConfigTableColumn.ValueType.ANY)
	column.type_definition = cyclic
	var bad_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	bad_schema.table_name = &"items"
	bad_schema.columns.append(column)
	var bad: GFConfigTableResource = GFConfigTableResource.new()
	bad.table_name = &"items"
	bad.schema = bad_schema
	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	database.tables.append(bad)
	assert_false(provider.register_table(bad))
	assert_same(
		provider.get_table_resource(&"items", false),
		good
	)
	assert_not_null(provider.get_schema(&"items"))
	assert_null(bad.duplicate_table())
	assert_null(database.duplicate_database())
	assert_null(GFResourceConfigProvider.from_database(database))
	assert_null(GFResourceConfigProvider.from_database(database, false))
	assert_null(GFResourceConfigProvider.from_database(database, true))
	bad.table_name = &"broken"
	bad_schema.table_name = &"broken"
	database.tables = [good, bad]
	assert_null(GFResourceConfigProvider.from_database(database))
	assert_null(GFResourceConfigProvider.from_database(database, false))
	assert_null(GFResourceConfigProvider.from_database(database, true))
	assert_eq(
		database.tables.size(),
		2,
		"Factory failure must not mutate the source database."
	)
	cyclic.element_type = null


## 未转换的旧数组字段先沿用元素准入，不为失败表提前递归复制循环或超额内容。
func test_legacy_element_rejection_precedes_new_report_data_copy() -> void:
	var column: GFConfigTableColumn = _column(&"values", GFConfigTableColumn.ValueType.ARRAY)
	column.element_validation_rules.append(_CountingRule.new())
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(column)
	schema.max_elements_per_validation = 1
	_CountingRule.calls = 0
	var cycle: Array = []
	cycle.append(cycle)
	var cyclic_reports: Array[Dictionary] = _validate_all_shapes(
		schema,
		{ "values": cycle }
	)
	cycle.clear()
	for report: Dictionary in cyclic_reports:
		var report_ok: Variant = report["ok"]
		var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
		assert_true(report_ok_matches)
		var report_data: Variant = report["data"]
		assert_true(report_data == null)
		assert_true(_has_kind(report, "invalid_element_validation_value"))
	var oversized_reports: Array[Dictionary] = _validate_all_shapes(
		schema,
		{
			"values": [1, 2],
		}
	)
	for report: Dictionary in oversized_reports:
		var report_ok_2: Variant = report["ok"]
		var report_ok_2_matches: bool = typeof(report_ok_2) == TYPE_BOOL and report_ok_2 == false
		assert_true(report_ok_2_matches)
		var report_data_2: Variant = report["data"]
		assert_true(report_data_2 == null)
		assert_true(_has_kind(report, "element_validation_budget_exhausted"))
	assert_eq(
		_CountingRule.calls,
		0,
		"Unadmitted elements must not reach element rules."
	)


## 没有元素规则的旧字段也必须在新 data 副本前拒绝循环及超出调用方预算的数据。
func test_legacy_report_data_copy_obeys_cycle_and_value_budget() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(_column(&"values", GFConfigTableColumn.ValueType.ARRAY))
	var cycle: Array = []
	cycle.append(cycle)
	var cyclic_reports: Array[Dictionary] = _validate_all_shapes(
		schema,
		{ "values": cycle }
	)
	cycle.clear()
	for report: Dictionary in cyclic_reports:
		var report_ok: Variant = report["ok"]
		var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
		assert_true(report_ok_matches)
		var report_data: Variant = report["data"]
		assert_true(report_data == null)
		assert_true(_has_kind(report, "config_work_cycle"))
	var budget_reports: Array[Dictionary] = _validate_all_shapes(
		schema,
		{
			"values": ["x".repeat(128)],
		},
		{
			"work_limits": { "max_value_bytes": 32 },
		}
	)
	for report: Dictionary in budget_reports:
		var report_ok_2: Variant = report["ok"]
		var report_ok_2_matches: bool = typeof(report_ok_2) == TYPE_BOOL and report_ok_2 == false
		assert_true(report_ok_2_matches)
		var report_data_2: Variant = report["data"]
		assert_true(report_data_2 == null)
		assert_true(_has_kind(report, "config_work_value_bytes_exceeded"))


## 成功的旧字段返回独立集合，整表预算不按记录重置。
func test_legacy_report_data_is_isolated_and_budget_is_shared_by_rows() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(_column(&"values", GFConfigTableColumn.ValueType.ARRAY))
	var record: Dictionary = {
		"values": [
			{ "amount": 2 },
		],
	}
	var reports: Array[Dictionary] = _validate_all_shapes(schema, record)
	for index: int in range(reports.size()):
		var report: Dictionary = reports[index]
		var report_ok: Variant = report["ok"]
		var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == true
		assert_true(report_ok_matches)
		var output: Dictionary = {}
		if index == 0:
			output = report["data"]
		elif index == 1:
			var rows: Array = report["data"]
			output = rows[0]
		else:
			var rows: Dictionary = report["data"]
			output = rows["row"]
		var values: Array = output["values"]
		var amount: Dictionary = values[0]
		amount["amount"] = 99
		var record_amount: Variant = record["values"][0]["amount"]
		var record_amount_matches: bool = typeof(record_amount) == TYPE_INT and record_amount == 2
		assert_true(record_amount_matches)
	var bounded_record: Dictionary = {
		"values": ["x".repeat(32)],
	}
	var options: Dictionary = {
		"work_limits": { "max_value_bytes": 48 },
	}
	var schema_validate_record_ok: Variant = schema.validate_record(
		bounded_record,
		null,
		options
	)["ok"]
	var schema_validate_record_ok_matches: bool = typeof(schema_validate_record_ok) == TYPE_BOOL and schema_validate_record_ok == true
	assert_true(schema_validate_record_ok_matches)
	var batch: Dictionary = schema.validate_table(
		[bounded_record, bounded_record],
		options
	)
	var batch_ok: Variant = batch["ok"]
	var batch_ok_matches: bool = typeof(batch_ok) == TYPE_BOOL and batch_ok == false
	assert_true(batch_ok_matches)
	var batch_data: Variant = batch["data"]
	assert_true(batch_data == null)
	assert_true(_has_kind(batch, "config_work_value_bytes_exceeded"))


## 唯一性比较直接使用规范 ID，不在每行另外执行结构字段规则。
func test_structured_unique_ids_are_normalized_once_per_row() -> void:
	var enumeration: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	enumeration.kind = GFConfigTypeDefinition.Kind.ENUM
	enumeration.symbols = { "FIRST": 1, "SECOND": 2 }
	for definition: GFConfigTypeDefinition in [_scalar(GFConfigTableColumn.ValueType.INT), enumeration]:
		var id: GFConfigTableColumn = _column(&"id", GFConfigTableColumn.ValueType.ANY)
		id.type_definition = definition
		id.validation_rules.append(_CountingRule.new())
		var schema: GFConfigTableSchema = GFConfigTableSchema.new()
		schema.columns.append(id)
		schema.coerce_values = true
		schema.require_unique_id = true
		for dictionary_table: bool in [false, true]:
			var rows: Variant = [
				{ "id": "1" },
				{ "id": "2" },
			]
			if dictionary_table:
				rows = {
					"first": { "id": "1" },
					"second": { "id": "2" },
				}
			_CountingRule.calls = 0
			var valid: Dictionary = schema.validate_table(rows)
			var valid_ok: Variant = valid["ok"]
			var valid_ok_matches: bool = typeof(valid_ok) == TYPE_BOOL and valid_ok == true
			assert_true(valid_ok_matches)
			assert_eq(_CountingRule.calls, 2)
			var duplicates: Variant = [
				{ "id": "1" },
				{ "id": 1 },
			]
			if dictionary_table:
				duplicates = {
					"first": { "id": "1" },
					"second": { "id": 1 },
				}
			_CountingRule.calls = 0
			var invalid: Dictionary = schema.validate_table(duplicates)
			var invalid_ok: Variant = invalid["ok"]
			var invalid_ok_matches: bool = typeof(invalid_ok) == TYPE_BOOL and invalid_ok == false
			assert_true(invalid_ok_matches)
			var invalid_data: Variant = invalid["data"]
			assert_true(invalid_data == null)
			assert_true(_has_kind(invalid, "duplicate_id"))
			assert_eq(
				_CountingRule.calls,
				2,
				"Duplicate detection must not revalidate either ID."
			)


## 唯一 ID 的规则与各行规范化共用一次资源路径会话，不另开默认预算的探测。
func test_structured_unique_ids_preserve_shared_resource_path_cache() -> void:
	var id: GFConfigTableColumn = _column(&"id", GFConfigTableColumn.ValueType.ANY)
	id.type_definition = _scalar(GFConfigTableColumn.ValueType.STRING)
	id.validation_rules.append(_CountingDefaultPathRule.new())
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(id)
	schema.coerce_values = true
	schema.require_unique_id = true
	schema.max_resource_path_checks_per_validation = 1
	_CountingDefaultPathRule.checks = 0
	var report: Dictionary = schema.validate_table(
		[
			{ "id": "res://same.gd" },
			{ "id": "res://same.gd" },
		]
	)
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	assert_true(_has_kind(report, "duplicate_id"))
	assert_false(_has_kind(report, "resource_path_check_budget_exhausted"))
	assert_eq(_CountingDefaultPathRule.checks, 1)


## 值规则只能改变自己的诊断上下文，不能拿到编译会话或整表来源映射。
func test_rule_context_hides_session_handles_and_copies_diagnostic_values() -> void:
	_ContextMutatingRule.exposed_internal_state = false
	var definition: GFConfigTypeDefinition = _structure(&"Item")
	var field: GFConfigTableColumn = _column(&"amount", GFConfigTableColumn.ValueType.INT)
	field.validation_rules.append(_ContextMutatingRule.new())
	definition.fields.append(field)
	var segments: Array = ["payload"]
	var row_key: Array = [7]
	var locations: Array = [
		{ "source": "original.csv" },
	]
	var options: Dictionary = {
		"field_segments": segments,
		"row_key": row_key,
		"row_locations": locations,
		"work_budget": GFConfigWorkBudget.new(),
	}
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new(options)
	var node: Dictionary = compiler.compile_type(definition)
	compiler.validate_defaults()
	options["__gf_config_type_compiler"] = compiler
	var compiler_normalize_type_ok: Variant = compiler.normalize_type(
		node,
		{ "amount": 3 },
		options
	)["ok"]
	var compiler_normalize_type_ok_matches: bool = typeof(compiler_normalize_type_ok) == TYPE_BOOL and compiler_normalize_type_ok == true
	assert_true(compiler_normalize_type_ok_matches)
	assert_false(_ContextMutatingRule.exposed_internal_state)
	assert_eq(
		segments,
		["payload"]
	)
	assert_eq(
		row_key,
		[7]
	)
	assert_eq(
		locations,
		[
			{ "source": "original.csv" },
		]
	)


## 即使输入为空，检查所有缺失结构字段仍消耗共享工作预算。
func test_missing_struct_fields_consume_shared_work_budget() -> void:
	var definition: GFConfigTypeDefinition = _structure(&"ManyFields")
	for index: int in range(16):
		definition.fields.append(
			_column(
				StringName("field_%d" % index),
				GFConfigTableColumn.ValueType.INT
			)
		)
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_work_units": 1000 })
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new({ "work_budget": budget })
	var node: Dictionary = compiler.compile_type(definition)
	compiler.validate_defaults()
	var usage: Dictionary = budget.get_report()["usage"]
	var consumed_work: int = usage["work_units"]
	assert_true(budget.consume_work(1000 - consumed_work - 8))
	var report: Dictionary = compiler.normalize_type(node, {})
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	var report_value: Variant = report["value"]
	assert_true(report_value == null)
	assert_true(_has_kind(report, "config_work_limit_exceeded"))


## 嵌套旧 Array 字段复用一维元素定义准入，不接受错误列类型、超量规则或集合元素。
func test_nested_legacy_element_rules_use_existing_definition_and_value_boundaries() -> void:
	_CountingRule.calls = 0
	var field: GFConfigTableColumn = _column(&"values", GFConfigTableColumn.ValueType.ARRAY)
	field.element_validation_rules.append(_CountingRule.new())
	var definition: GFConfigTypeDefinition = _structure(&"LegacyArray")
	definition.fields.append(field)
	var definition_normalize_ok: Variant = definition.try_normalize(
		{
			"values": [1, 2],
		}
	)["ok"]
	var definition_normalize_ok_matches: bool = typeof(definition_normalize_ok) == TYPE_BOOL and definition_normalize_ok == true
	assert_true(definition_normalize_ok_matches)
	assert_eq(_CountingRule.calls, 2)
	var invalid: Dictionary = definition.try_normalize(
		{
			"values": [
				[1],
			],
		}
	)
	var invalid_ok: Variant = invalid["ok"]
	var invalid_ok_matches: bool = typeof(invalid_ok) == TYPE_BOOL and invalid_ok == false
	assert_true(invalid_ok_matches)
	assert_true(_has_kind(invalid, "invalid_element_validation_value"))
	assert_eq(_CountingRule.calls, 2)
	var first_issue_field_path: Variant = _first_issue(invalid, "invalid_element_validation_value")["field_path"]
	var first_issue_field_path_matches: bool = typeof(first_issue_field_path) == TYPE_STRING and first_issue_field_path == "values[0]"
	assert_true(first_issue_field_path_matches)
	field.value_type = GFConfigTableColumn.ValueType.INT
	assert_true(
		_has_kind(
			definition.validate_definition(),
			"element_rules_require_array"
		)
	)
	field.value_type = GFConfigTableColumn.ValueType.ARRAY
	for index: int in range(64):
		field.element_validation_rules.append(_CountingRule.new())
	assert_true(
		_has_kind(
			definition.validate_definition(),
			"element_validation_rule_limit_exceeded"
		)
	)


## schema 的较低元素和调用限额由顶层与嵌套字段共享，不能从另一入口重置。
func test_nested_legacy_elements_share_schema_element_and_rule_budgets() -> void:
	var top: GFConfigTableColumn = _column(&"top", GFConfigTableColumn.ValueType.ARRAY)
	top.element_validation_rules.append(_CountingRule.new())
	var nested: GFConfigTableColumn = _column(&"nested", GFConfigTableColumn.ValueType.ARRAY)
	nested.element_validation_rules.append(_CountingRule.new())
	var item: GFConfigTypeDefinition = _structure(&"Item")
	item.fields.append(nested)
	var payload: GFConfigTableColumn = _column(&"payload", GFConfigTableColumn.ValueType.ANY)
	payload.type_definition = item
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns = [top, payload]
	schema.max_elements_per_validation = 2
	var report: Dictionary = schema.validate_table(
		[
			{
				"top": [1],
				"payload": {
					"nested": [2, 3],
				},
			},
		]
	)
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	var report_data: Variant = report["data"]
	assert_true(report_data == null)
	assert_true(_has_kind(report, "element_validation_budget_exhausted"))
	schema.max_elements_per_validation = 8
	schema.max_element_rule_checks_per_validation = 1
	var checks: Dictionary = schema.validate_table(
		[
			{
				"top": [1],
				"payload": {
					"nested": [2],
				},
			},
		]
	)
	var checks_ok: Variant = checks["ok"]
	var checks_ok_matches: bool = typeof(checks_ok) == TYPE_BOOL and checks_ok == false
	assert_true(checks_ok_matches)
	assert_true(_has_kind(checks, "element_validation_budget_exhausted"))


## 已知规则载荷在复制前接受预算和循环检查，不让 nested 规则绕过顶层保护。
func test_nested_builtin_rule_payload_is_admitted_before_duplicate() -> void:
	_CountingSetRule.duplicates = 0
	var rule: _CountingSetRule = _CountingSetRule.new()
	rule.allowed_values = ["x".repeat(1024)]
	var field: GFConfigTableColumn = _column(&"value", GFConfigTableColumn.ValueType.STRING)
	field.validation_rules.append(rule)
	var definition: GFConfigTypeDefinition = _structure(&"Value")
	definition.fields.append(field)
	var options: Dictionary = {
		"work_limits": { "max_value_bytes": 256 },
	}
	var definition_duplicate_definition_ok: Variant = definition.try_duplicate_definition(options)["ok"]
	var definition_duplicate_definition_ok_matches: bool = typeof(definition_duplicate_definition_ok) == TYPE_BOOL and definition_duplicate_definition_ok == false
	assert_true(definition_duplicate_definition_ok_matches)
	var definition_validate_definition_ok: Variant = definition.validate_definition(options)["ok"]
	var definition_validate_definition_ok_matches: bool = typeof(definition_validate_definition_ok) == TYPE_BOOL and definition_validate_definition_ok == false
	assert_true(definition_validate_definition_ok_matches)
	assert_eq(_CountingSetRule.duplicates, 0)
	var cyclic: Array = []
	cyclic.append(cyclic)
	rule.allowed_values = cyclic
	var definition_duplicate_definition_ok_2: Variant = definition.try_duplicate_definition()["ok"]
	var definition_duplicate_definition_ok_2_matches: bool = typeof(definition_duplicate_definition_ok_2) == TYPE_BOOL and definition_duplicate_definition_ok_2 == false
	assert_true(definition_duplicate_definition_ok_2_matches)
	var definition_validate_definition_ok_2: Variant = definition.validate_definition()["ok"]
	var definition_validate_definition_ok_2_matches: bool = typeof(definition_validate_definition_ok_2) == TYPE_BOOL and definition_validate_definition_ok_2 == false
	assert_true(definition_validate_definition_ok_2_matches)
	assert_eq(_CountingSetRule.duplicates, 0)
	cyclic.clear()


## 共享定义的描述输出逐份预留复制量，超预算整份失败而非返回嵌套成功空定义。
func test_describe_shared_graph_counts_output_copies_and_fails_whole_report() -> void:
	var shared: GFConfigTypeDefinition = _structure(&"Shared")
	var text: GFConfigTableColumn = _column(&"text", GFConfigTableColumn.ValueType.STRING)
	text.default_value = "x".repeat(1024)
	shared.fields.append(text)
	var root_type: GFConfigTypeDefinition = _structure(&"Pair")
	for field_name: StringName in [&"left", &"right"]:
		var column: GFConfigTableColumn = _column(field_name, GFConfigTableColumn.ValueType.ANY)
		column.type_definition = shared
		root_type.fields.append(column)
	var root_type_describe_ok: Variant = root_type.describe()["ok"]
	var root_type_describe_ok_matches: bool = typeof(root_type_describe_ok) == TYPE_BOOL and root_type_describe_ok == true
	assert_true(root_type_describe_ok_matches)
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new(
		{
			"work_limits": { "max_value_bytes": 1800 },
		}
	)
	var node: Dictionary = compiler.compile_type(root_type)
	var compiler_get_report_ok: Variant = compiler.get_report()["ok"]
	var compiler_get_report_ok_matches: bool = typeof(compiler_get_report_ok) == TYPE_BOOL and compiler_get_report_ok == true
	assert_true(compiler_get_report_ok_matches)
	assert_eq(
		compiler.describe_type(node),
		{}
	)
	var compiler_get_report_ok_2: Variant = compiler.get_report()["ok"]
	var compiler_get_report_ok_2_matches: bool = typeof(compiler_get_report_ok_2) == TYPE_BOOL and compiler_get_report_ok_2 == false
	assert_true(compiler_get_report_ok_2_matches)
	var limited: Dictionary = root_type.describe(
		{
			"work_limits": { "max_value_bytes": 1800 },
		}
	)
	var limited_ok: Variant = limited["ok"]
	var limited_ok_matches: bool = typeof(limited_ok) == TYPE_BOOL and limited_ok == false
	assert_true(limited_ok_matches)
	var limited_definition: Variant = limited["definition"]
	var limited_definition_matches: bool = typeof(limited_definition) == TYPE_DICTIONARY and limited_definition == {}
	assert_true(limited_definition_matches)
	assert_true(_has_kind(limited, "config_work_value_bytes_exceeded"))


## 预创建编译器仍接入 schema 默认值的共享路径会话，相同路径只探测一次。
func test_default_path_rules_share_schema_cache_with_precreated_compiler() -> void:
	_CountingDefaultPathRule.checks = 0
	var schema: GFConfigTableSchema = _schema_with_path_defaults("res://same.gd")
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new()
	var report: Dictionary = schema.validate_definition({ "__gf_config_type_compiler": compiler })
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == true
	assert_true(report_ok_matches)
	assert_eq(_CountingDefaultPathRule.checks, 1)


## 默认值路径探测不能绕过 schema 指定的一次唯一探测限额。
func test_default_path_rules_obey_schema_lower_check_budget() -> void:
	_CountingDefaultPathRule.checks = 0
	var schema: GFConfigTableSchema = _schema_with_path_defaults("res://other.gd")
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new()
	var report: Dictionary = schema.validate_definition({ "__gf_config_type_compiler": compiler })
	var report_ok: Variant = report["ok"]
	var report_ok_matches: bool = typeof(report_ok) == TYPE_BOOL and report_ok == false
	assert_true(report_ok_matches)
	assert_true(_has_kind(report, "resource_path_check_budget_exhausted"))
	assert_eq(_CountingDefaultPathRule.checks, 1)


# --- 私有/辅助方法 ---

## 同一输入分别走单记录、数组表和字典表三个公开验证入口。
func _validate_all_shapes(
	schema: GFConfigTableSchema,
	record: Dictionary,
	options: Dictionary = {}
) -> Array[Dictionary]:
	return [
		schema.validate_record(
			record,
			null,
			options
		),
		schema.validate_table(
			[record],
			options
		),
		schema.validate_table(
			{ "row": record },
			options
		),
	]


## 校验与复制在相同绝对深度边界作出一致决定，拒绝时不交付部分图。
func _assert_shared_depth_boundary(definition: GFConfigTypeDefinition, required_depth: int) -> void:
	for limit: int in [required_depth - 1, required_depth]:
		var options: Dictionary = {
			"work_limits": { "max_depth": limit },
		}
		var accepted: bool = limit == required_depth
		var validation: Dictionary = definition.validate_definition(options)
		var duplication: Dictionary = definition.try_duplicate_definition(options)
		for report: Dictionary in [validation, duplication]:
			var ok_matches: bool = typeof(report.get("ok")) == TYPE_BOOL and report.get("ok") == accepted
			assert_true(ok_matches)
			assert_eq(
				_has_kind(report, "config_work_depth_exceeded"),
				not accepted
			)
		if accepted:
			assert_true(duplication.get("definition") is GFConfigTypeDefinition)
		else:
			var absent: bool = duplication.get("definition") == null
			assert_true(absent)


## 构造两个路径默认值字段，明确只允许一次唯一资源探测。
func _schema_with_path_defaults(second_path: String) -> GFConfigTableSchema:
	var item: GFConfigTypeDefinition = _structure(&"Paths")
	var first: GFConfigTableColumn = _column(&"first", GFConfigTableColumn.ValueType.STRING)
	first.default_value = "res://same.gd"
	first.validation_rules.append(_CountingDefaultPathRule.new())
	var second: GFConfigTableColumn = _column(&"second", GFConfigTableColumn.ValueType.STRING)
	second.default_value = second_path
	second.validation_rules.append(_CountingDefaultPathRule.new())
	item.fields = [first, second]
	var payload: GFConfigTableColumn = _column(&"payload", GFConfigTableColumn.ValueType.ANY)
	payload.type_definition = item
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns.append(payload)
	schema.max_resource_path_checks_per_validation = 1
	return schema


## 构造一个具有明确标量类型的叶节点。
func _scalar(value_type: GFConfigTableColumn.ValueType) -> GFConfigTypeDefinition:
	var result: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	result.scalar_type = value_type
	return result


## 构造只包含命名身份的结构，字段由用例显式指定。
func _structure(type_name: StringName) -> GFConfigTypeDefinition:
	var result: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	result.kind = GFConfigTypeDefinition.Kind.STRUCT
	result.type_name = type_name
	return result


## 构造数组；允许 null 参数以验证缺失和循环定义。
func _array(element: GFConfigTypeDefinition) -> GFConfigTypeDefinition:
	var result: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	result.kind = GFConfigTypeDefinition.Kind.ARRAY
	result.element_type = element
	return result


## 构造最小字段，保留已有 Column 的默认空值和必填策略。
func _column(field_name: StringName, value_type: GFConfigTableColumn.ValueType) -> GFConfigTableColumn:
	var result: GFConfigTableColumn = GFConfigTableColumn.new()
	result.field_name = field_name
	result.value_type = value_type
	return result


## 从公开报告查询特定问题，不依赖错误文案。
func _has_kind(report: Dictionary, kind: String) -> bool:
	return not _first_issue(report, kind).is_empty()


## 返回首个匹配问题，缺失时返回空字典以保持失败可定位。
func _first_issue(report: Dictionary, kind: String) -> Dictionary:
	for value: Variant in report.get("issues", []):
		if value is Dictionary:
			var issue: Dictionary = value
			if issue.get("kind") == kind:
				return issue
	return {}


# --- 内部类 ---

## 通过全实例共享计数观察复制与调用期默认值规则执行边界。
class _CountingRule:
	extends GFConfigValidationRule

	## 所有规则副本共享的可观察调用次数。
	static var calls: int = 0


	## 仅记录规则执行，不改变输入值或报告。
	func _validate_value(
		_value: Variant,
		_context: Dictionary,
		_report: Dictionary
	) -> void:
		calls += 1


## 尝试修改规则上下文，观察来源数据与内部会话是否被泄漏。
class _ContextMutatingRule:
	extends GFConfigValidationRule

	## 任一次调用暴露内部控制句柄时锁存，跨规则副本保留观察结果。
	static var exposed_internal_state: bool = false


	## 只修改传入上下文的集合，不应影响调用者保存的来源与行标识。
	func _validate_value(
		_value: Variant,
		context: Dictionary,
		_report: Dictionary
	) -> void:
		exposed_internal_state = (
			exposed_internal_state
			or context.has("work_budget")
			or context.has("__gf_config_type_compiler")
			or context.has("row_locations")
		)
		var segments: Array = context["field_segments"]
		segments.clear()
		var row_key: Array = context["row_key"]
		row_key.clear()


## 观察内置 Set 规则的复制边界，不执行额外业务校验。
class _CountingSetRule:
	extends GFConfigSetValidationRule

	## 只有载荷通过预算检查后才允许增长的复制次数。
	static var duplicates: int = 0


	## 沿用内置复制实现，并记录实际开始复制的次数。
	func duplicate_rule() -> GFConfigValidationRule:
		duplicates += 1
		return super.duplicate_rule()


## 用确定性探测结果观察默认值路径会话，不读取实际文件。
class _CountingDefaultPathRule:
	extends GFConfigResourcePathValidationRule

	## 所有规则副本共享的实际探测次数。
	static var checks: int = 0


	## 每次实际探测返回存在，让测试只观察缓存与限额行为。
	func _path_exists(_path: String) -> bool:
		checks += 1
		return true
