extends GutTest


# --- 常量 ---

## 释放匿名生成脚本及其内部类，避免测试留下脚本引用环。
const _TRANSIENT_SCRIPT_SUPPORT = preload("res://tests/gf_core/support/gf_transient_gdscript_test_support.gd")


# --- 公共方法 ---

## 编译所有结构形状并执行继承、嵌套容器、枚举及多态 getter，验证快照之间互不借用。
func test_structured_wrappers_compile_and_preserve_types_inheritance_and_ownership() -> void:
	var schema: GFConfigTableSchema = _make_schema()
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var report: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var success: Variant = report["success"]
	var succeeded: bool = success is bool and success == true
	assert_true(
		succeeded,
		str(report["issues"])
	)
	var source: String = report["source"]
	assert_true(source.contains("extends ConfigTypeStats"))
	assert_true(source.contains("func get_hp() -> int:"))
	assert_true(source.contains("func get_ratio() -> float:"))
	assert_true(source.contains("func get_value(key: StringName) -> ConfigTypeEliteStats:"))
	assert_eq(
		source.count("class ConfigTypeEliteStats:"),
		1,
		"共享结构定义只生成一个类。"
	)
	var runtime_script: GDScript = _compile(source)
	if runtime_script == null:
		return
	var constants: Dictionary = runtime_script.get_script_constant_map()
	var rank_script: GDScript = constants["ConfigTypeRank"]
	var symbols: Dictionary = rank_script.get_script_constant_map()
	var normal_value: Variant = symbols["VALUE_NORMAL"]
	var elite_value: Variant = symbols["VALUE_ELITE"]
	var normal_matches: bool = normal_value is int and normal_value == 0
	assert_true(normal_matches)
	var elite_matches: bool = elite_value is int and elite_value == 5
	assert_true(elite_matches)
	symbols.clear()
	rank_script = null
	constants.clear()
	var provider: RecordingProvider = RecordingProvider.new()
	provider.record = {
		"id": 1,
		"stats": { "hp": 40, "ratio": 1.5 },
		"units": [
			{ "hp": 41, "ratio": 2.5 },
		],
		"by_name": {
			&"alpha": { "hp": 42, "ratio": 3.5 },
		},
		"matrix": [
			[7, null],
		],
		"rank": 5,
		"action": { "kind": "melee", "power": 9 },
		"optional": null,
	}
	var record: Object = runtime_script.call(
		&"get_units_typed_record",
		1,
		provider
	)
	assert_not_null(record)
	if record != null:
		_assert_record_values(record, provider)
	record = null
	provider = null
	_release(runtime_script)


## 多层继承即使字段名与基类帮助方法碰撞，也保留各字段及实际父类身份。
func test_inherited_getters_keep_collision_names_and_runtime_parent() -> void:
	var base_type: GFConfigTypeDefinition = _structure(
		&"base",
		[_column(&"value", GFConfigTableColumn.ValueType.INT)]
	)
	var derived_type: GFConfigTypeDefinition = _structure(
		&"derived",
		[_column(&"value!", GFConfigTableColumn.ValueType.STRING)]
	)
	derived_type.base_type = base_type
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"units"
	schema.columns = [_structured_column(&"payload", derived_type)]
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var report: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var success: Variant = report["success"]
	var succeeded: bool = success is bool and success == true
	assert_true(
		succeeded,
		str(report["issues"])
	)
	var source: String = report["source"]
	var runtime_script: GDScript = _compile(source)
	if runtime_script == null:
		return
	var constants: Dictionary = runtime_script.get_script_constant_map()
	var base_script: GDScript = constants["ConfigTypeBase"]
	var derived_script: GDScript = constants["ConfigTypeDerived"]
	assert_eq(
		derived_script.get_base_script(),
		base_script
	)
	var provider: RecordingProvider = RecordingProvider.new()
	provider.record = {
		"payload": { "value": 17, "value!": "child" },
	}
	var record: Object = runtime_script.call(
		&"get_units_typed_record",
		1,
		provider
	)
	var payload: Object = record.call(&"get_payload")
	var parent_value: Variant = payload.call(&"get_value_2")
	var child_value: Variant = payload.call(&"get_value_3")
	var parent_matches: bool = parent_value is int and parent_value == 17
	assert_true(parent_matches)
	var child_matches: bool = child_value is String and child_value == "child"
	assert_true(child_matches)
	payload = null
	record = null
	provider = null
	derived_script = null
	base_script = null
	constants.clear()
	_release(runtime_script)


## 空值、索引越界及不匹配的多态投影返回公开默认值，不读取相邻元素。
func test_nullable_container_elements_and_unknown_branch_have_explicit_boundaries() -> void:
	var schema: GFConfigTableSchema = _make_schema()
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var report: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var success: Variant = report["success"]
	var succeeded: bool = success is bool and success == true
	assert_true(
		succeeded,
		str(report["issues"])
	)
	var source: String = report["source"]
	var runtime_script: GDScript = _compile(source)
	if runtime_script == null:
		return
	var provider: RecordingProvider = RecordingProvider.new()
	provider.record = {
		"matrix": [
			[7, null],
		],
		"action": { "kind": "unknown" },
		"optional": null,
	}
	var record: Object = runtime_script.call(
		&"get_units_typed_record",
		1,
		provider
	)
	var matrix: Object = record.call(&"get_matrix")
	var row: Object = matrix.call(&"get_at", 0)
	var first_value: Variant = row.call(&"get_at", 0)
	var first_matches: bool = first_value is int and first_value == 7
	assert_true(first_matches)
	var has_null_element: Variant = row.call(&"has", 1)
	var has_null_matches: bool = has_null_element is bool and has_null_element == true
	assert_true(has_null_matches)
	var null_element: Variant = row.call(&"is_null", 1)
	var null_element_matches: bool = null_element is bool and null_element == true
	assert_true(null_element_matches)
	var null_value: Variant = row.call(&"get_at", 1)
	var null_value_matches: bool = null_value is int and null_value == 0
	assert_true(null_value_matches)
	var has_negative_index: Variant = row.call(&"has", -1)
	var negative_index_matches: bool = has_negative_index is bool and has_negative_index == false
	assert_true(negative_index_matches)
	var negative_value: Variant = row.call(&"get_at", -1)
	var negative_value_matches: bool = negative_value is int and negative_value == 0
	assert_true(negative_value_matches)
	assert_true(matrix.call(&"get_at", 9) == null)
	var action: Object = record.call(&"get_action")
	assert_true(action.call(&"as_melee") == null)
	assert_true(action.call(&"as_spell") == null)
	var has_optional: Variant = record.call(&"has_field", &"optional")
	var has_optional_matches: bool = has_optional is bool and has_optional == true
	assert_true(has_optional_matches)
	var optional_is_null: Variant = record.call(&"is_null", &"optional")
	var optional_null_matches: bool = optional_is_null is bool and optional_is_null == true
	assert_true(optional_null_matches)
	var optional_value: Variant = record.call(&"get_optional")
	var optional_value_matches: bool = optional_value is float and optional_value == 0.0
	assert_true(optional_value_matches)
	var has_stats: Variant = record.call(&"has_field", &"stats")
	var has_stats_matches: bool = has_stats is bool and has_stats == false
	assert_true(has_stats_matches)
	assert_true(record.call(&"get_stats") == null)
	action = null
	row = null
	matrix = null
	record = null
	provider = null
	_release(runtime_script)


## 描述报告不能重新充当类型声明；原有无结构字段的 Dictionary schema 仍可生成。
func test_dictionary_descriptors_are_rejected_without_breaking_legacy_schemas() -> void:
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var legacy: Dictionary = {
		"table_name": "units",
		"columns": [
			{ "field_name": "id", "value_type": "int" },
		],
	}
	var accepted: Dictionary = generator.build_source_with_report([legacy])
	var accepted_success: Variant = accepted["success"]
	var accepted_matches: bool = accepted_success is bool and accepted_success == true
	assert_true(accepted_matches)
	var forged: Dictionary = legacy.duplicate(true)
	var columns: Array = forged["columns"]
	var column: Dictionary = columns[0]
	column["type_definition"] = {
		"ok": true,
		"definition": { "kind": "scalar", "scalar_type": 2 },
	}
	for options: Dictionary in [
		{},
		{ "include_typed_records": true },
	]:
		var rejected: Dictionary = generator.build_source_with_report(
			[forged],
			"StructuredAccess",
			"null",
			options
		)
		var rejected_success: Variant = rejected["success"]
		var rejected_source: Variant = rejected["source"]
		var rejected_matches: bool = rejected_success is bool and rejected_success == false
		assert_true(rejected_matches)
		var rejected_source_matches: bool = rejected_source is String and rejected_source == ""
		assert_true(rejected_source_matches)
		assert_eq(
			generator.build_source(
				[forged],
				"StructuredAccess",
				"null",
				options
			),
			""
		)


## 真实执行八种结构标量 getter，并保留 Unicode/控制字符字段的原始查找身份。
func test_all_structured_scalar_getters_and_non_ascii_field_identity() -> void:
	var names: Array[StringName] = [
		&"boolean",
		&"integer",
		&"fraction",
		&"text",
		&"symbol",
		&"point",
		&"grid",
		&"tint",
	]
	var types: Array[GFConfigTableColumn.ValueType] = [
		GFConfigTableColumn.ValueType.BOOL,
		GFConfigTableColumn.ValueType.INT,
		GFConfigTableColumn.ValueType.FLOAT,
		GFConfigTableColumn.ValueType.STRING,
		GFConfigTableColumn.ValueType.STRING_NAME,
		GFConfigTableColumn.ValueType.VECTOR2,
		GFConfigTableColumn.ValueType.VECTOR2I,
		GFConfigTableColumn.ValueType.COLOR,
	]
	var values: Array = [
		true,
		23,
		2.75,
		"line\ntext",
		&"tag",
		Vector2(1, 2),
		Vector2i(3, 4),
		Color(
			0.1,
			0.2,
			0.3
		),
	]
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"units"
	var provider: RecordingProvider = RecordingProvider.new()
	for index: int in range(names.size()):
		var scalar: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
		scalar.scalar_type = types[index]
		schema.columns.append(
			_structured_column(
				names[index],
				scalar
			)
		)
		provider.record[names[index]] = values[index]
	var raw_field: StringName = StringName("value\n\"\\id")
	var nested: GFConfigTypeDefinition = _structure(
		&"玩家",
		[_column(raw_field, GFConfigTableColumn.ValueType.INT)]
	)
	schema.columns.append(_structured_column(&"详情", nested))
	provider.record[&"详情"] = { raw_field: 29 }
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var report: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var success: Variant = report["success"]
	var succeeded: bool = success is bool and success == true
	assert_true(
		succeeded,
		str(report["issues"])
	)
	var source: String = report["source"]
	var runtime_script: GDScript = _compile(source)
	if runtime_script == null:
		return
	var record: Object = runtime_script.call(
		&"get_units_typed_record",
		1,
		provider
	)
	for index: int in range(names.size()):
		var value: Variant = record.call(StringName("get_%s" % names[index]))
		var expected_value: Variant = values[index]
		assert_eq(
			typeof(value),
			typeof(expected_value)
		)
		var value_matches: bool = typeof(value) == typeof(expected_value) and value == expected_value
		assert_true(value_matches)
	var getter_name: StringName = StringName("get_field_%s" % "详情".sha256_text().substr(0, 12))
	var payload: Object = record.call(getter_name)
	var field_value: Variant = payload.call(&"get_value_id")
	var field_matches: bool = field_value is int and field_value == 29
	assert_true(field_matches)
	payload = null
	record = null
	provider = null
	_release(runtime_script)


## 严格 Schema 保留合法整数输入，FLOAT 字段及容器 getter 仍返回同值浮点数。
func test_strict_float_values_survive_normalization_and_generated_getters() -> void:
	var number: GFConfigTypeDefinition = _scalar(GFConfigTableColumn.ValueType.FLOAT)
	var sequence: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	sequence.kind = GFConfigTypeDefinition.Kind.ARRAY
	sequence.element_type = number
	var mapping: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	mapping.kind = GFConfigTypeDefinition.Kind.MAP
	mapping.map_key_type = GFConfigTableColumn.ValueType.STRING
	mapping.map_value_type = number
	var details: GFConfigTypeDefinition = _structure(
		&"details",
		[_column(&"ratio", GFConfigTableColumn.ValueType.FLOAT)]
	)
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"units"
	schema.coerce_values = false
	schema.columns = [
		_structured_column(&"ratio", number),
		_structured_column(&"details", details),
		_structured_column(&"ratios", sequence),
		_structured_column(&"by_name", mapping),
	]
	var report: Dictionary = GFConfigAccessGenerator.new().build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var success: Variant = report["success"]
	var succeeded: bool = success is bool and success == true
	assert_true(
		succeeded,
		str(report["issues"])
	)
	var source: String = report["source"]
	var runtime_script: GDScript = _compile(source)
	if runtime_script == null:
		return
	var samples: Array = [7, 2.75]
	var expected: Array[float] = [7.0, 2.75]
	for index: int in range(samples.size()):
		var sample: Variant = samples[index]
		var normalized: Dictionary = schema.validate_record(
			{
				"ratio": sample,
				"details": { "ratio": sample },
				"ratios": [sample],
				"by_name": { "alpha": sample },
			}
		)
		var normalized_ok: Variant = normalized["ok"]
		var normalization_succeeded: bool = normalized_ok is bool and normalized_ok == true
		assert_true(
			normalization_succeeded,
			str(normalized["issues"])
		)
		if not normalization_succeeded:
			continue
		var provider: RecordingProvider = RecordingProvider.new()
		provider.record = normalized["data"]
		assert_eq(
			typeof(provider.record["ratio"]),
			typeof(sample),
			"严格模式不得靠隐式数据转换掩盖 getter 的合法输入范围。"
		)
		var record: Object = runtime_script.call(
			&"get_units_typed_record",
			1,
			provider
		)
		var nested: Object = record.call(&"get_details")
		var ratios: Object = record.call(&"get_ratios")
		var by_name: Object = record.call(&"get_by_name")
		for actual: Variant in [
			record.call(&"get_ratio"),
			nested.call(&"get_ratio"),
			ratios.call(&"get_at", 0),
			by_name.call(&"get_value", "alpha"),
		]:
			assert_eq(
				typeof(actual),
				TYPE_FLOAT
			)
			var value_matches: bool = actual is float and actual == expected[index]
			assert_true(value_matches)
		by_name = null
		ratios = null
		nested = null
		record = null
		provider = null
	_release(runtime_script)


## 类型定义失效或共享预算耗尽时整体失败，不返回看似可用的部分访问器。
func test_invalid_definition_and_exhausted_budget_fail_closed() -> void:
	var schema: GFConfigTableSchema = _make_schema()
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var broken: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	broken.kind = GFConfigTypeDefinition.Kind.ARRAY
	schema.columns.append(_structured_column(&"broken", broken))
	var invalid: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var invalid_success: Variant = invalid["success"]
	var invalid_source: Variant = invalid["source"]
	var invalid_matches: bool = invalid_success is bool and invalid_success == false
	assert_true(invalid_matches)
	var invalid_source_matches: bool = invalid_source is String and invalid_source == ""
	assert_true(invalid_source_matches)
	schema = _make_schema()
	var limited: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{
			"include_typed_records": true,
			"work_limits": { "max_depth": 1 },
		}
	)
	var limited_success: Variant = limited["success"]
	var limited_source: Variant = limited["source"]
	var limited_matches: bool = limited_success is bool and limited_success == false
	assert_true(limited_matches)
	var limited_source_matches: bool = limited_source is String and limited_source == ""
	assert_true(limited_source_matches)
	schema = _make_schema()
	var invalid_default: GFConfigTableColumn = schema.columns[2]
	invalid_default.default_value = "not an array"
	var default_report: Dictionary = generator.build_source_with_report(
		[schema],
		"StructuredAccess",
		"null",
		{ "include_typed_records": true }
	)
	var default_success: Variant = default_report["success"]
	var default_matches: bool = default_success is bool and default_success == false
	assert_true(default_matches, "外层 column 默认值仍由同一 compiler 校验。")
	var default_source: Variant = default_report["source"]
	var default_source_matches: bool = default_source is String and default_source == ""
	assert_true(default_source_matches)


## 生成能力诚实说明 Resource 准入及容器表示，而且返回的可变字典不共享。
func test_capabilities_describe_backend_limits_and_are_isolated() -> void:
	var capabilities: Dictionary = GFConfigAccessGenerator.get_capabilities()
	var backend: Variant = capabilities["backend"]
	var descriptor_import: Variant = capabilities["descriptor_import"]
	var runtime_validation: Variant = capabilities["runtime_validation"]
	var backend_matches: bool = backend is String and backend == "gdscript"
	assert_true(backend_matches)
	var descriptor_matches: bool = descriptor_import is bool and descriptor_import == false
	assert_true(descriptor_matches)
	var validation_matches: bool = runtime_validation is bool and runtime_validation == false
	assert_true(validation_matches)
	var kinds: Array = capabilities["kinds"]
	kinds.clear()
	var second: Dictionary = GFConfigAccessGenerator.get_capabilities()
	var second_kinds: Array = second["kinds"]
	assert_eq(
		second_kinds.size(),
		6
	)


# --- 私有/辅助方法 ---

## 验证已编译记录及嵌套包装修改后不会改写 provider 或其他已生成快照。
func _assert_record_values(record: Object, provider: RecordingProvider) -> void:
	var stats: Object = record.call(&"get_stats")
	var hp: Variant = stats.call(&"get_hp")
	var hp_matches: bool = hp is int and hp == 40
	assert_true(hp_matches)
	var ratio: Variant = stats.call(&"get_ratio")
	var ratio_matches: bool = ratio is float and ratio == 1.5
	assert_true(ratio_matches)
	var stats_data: Dictionary = stats.get(&"data")
	stats_data["hp"] = 99
	var second_stats: Object = record.call(&"get_stats")
	var second_hp: Variant = second_stats.call(&"get_hp")
	var second_hp_matches: bool = second_hp is int and second_hp == 40
	assert_true(second_hp_matches)
	var provider_stats: Dictionary = provider.record["stats"]
	var provider_hp: Variant = provider_stats["hp"]
	var provider_hp_matches: bool = provider_hp is int and provider_hp == 40
	assert_true(provider_hp_matches)
	var units: Object = record.call(&"get_units")
	var unit: Object = units.call(&"get_at", 0)
	var unit_hp: Variant = unit.call(&"get_hp")
	var unit_hp_matches: bool = unit_hp is int and unit_hp == 41
	assert_true(unit_hp_matches)
	var exported: Array = units.call(&"to_array")
	var exported_unit: Dictionary = exported[0]
	exported_unit["hp"] = -1
	var second_unit: Object = units.call(&"get_at", 0)
	var second_unit_hp: Variant = second_unit.call(&"get_hp")
	var second_unit_hp_matches: bool = second_unit_hp is int and second_unit_hp == 41
	assert_true(second_unit_hp_matches)
	var by_name: Object = record.call(&"get_by_name")
	var named_unit: Object = by_name.call(&"get_value", &"alpha")
	var named_hp: Variant = named_unit.call(&"get_hp")
	var named_hp_matches: bool = named_hp is int and named_hp == 42
	assert_true(named_hp_matches)
	var exported_map: Dictionary = by_name.call(&"to_dictionary")
	var exported_named: Dictionary = exported_map[&"alpha"]
	exported_named["hp"] = -2
	var second_named: Object = by_name.call(&"get_value", &"alpha")
	var second_named_hp: Variant = second_named.call(&"get_hp")
	var second_named_hp_matches: bool = second_named_hp is int and second_named_hp == 42
	assert_true(second_named_hp_matches)
	assert_true(by_name.call(&"get_value", &"missing") == null)
	var rank: Variant = record.call(&"get_rank")
	var rank_matches: bool = rank is int and rank == 5
	assert_true(rank_matches)
	var action: Object = record.call(&"get_action")
	var melee: Object = action.call(&"as_melee")
	var power: Variant = melee.call(&"get_power")
	var power_matches: bool = power is int and power == 9
	assert_true(power_matches)
	assert_true(action.call(&"as_spell") == null)
	var snapshot_stats: Dictionary = record.call(&"get_value", &"stats")
	provider_stats["hp"] = 100
	var snapshot_hp: Variant = snapshot_stats["hp"]
	var snapshot_hp_matches: bool = snapshot_hp is int and snapshot_hp == 40
	assert_true(snapshot_hp_matches)


## 构造共享派生结构、嵌套数组、StringName 键 map、枚举与两个多态分支。
func _make_schema() -> GFConfigTableSchema:
	var stats: GFConfigTypeDefinition = _structure(
		&"stats",
		[_column(&"hp", GFConfigTableColumn.ValueType.INT)]
	)
	var elite: GFConfigTypeDefinition = _structure(
		&"elite_stats",
		[_column(&"ratio", GFConfigTableColumn.ValueType.FLOAT)]
	)
	elite.base_type = stats
	var units: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	units.kind = GFConfigTypeDefinition.Kind.ARRAY
	units.type_name = &"unit_list"
	units.element_type = elite
	var by_name: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	by_name.kind = GFConfigTypeDefinition.Kind.MAP
	by_name.type_name = &"named_units"
	by_name.map_key_type = GFConfigTableColumn.ValueType.STRING_NAME
	by_name.map_value_type = elite
	var number: GFConfigTypeDefinition = _scalar(GFConfigTableColumn.ValueType.INT)
	number.allow_null = true
	var row: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	row.kind = GFConfigTypeDefinition.Kind.ARRAY
	row.type_name = &"row"
	row.element_type = number
	var matrix: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	matrix.kind = GFConfigTypeDefinition.Kind.ARRAY
	matrix.type_name = &"matrix"
	matrix.element_type = row
	var rank: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	rank.kind = GFConfigTypeDefinition.Kind.ENUM
	rank.type_name = &"rank"
	rank.symbols = { "normal": 0, "elite": 5 }
	var action: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	action.kind = GFConfigTypeDefinition.Kind.POLYMORPHIC
	action.type_name = &"action"
	action.discriminator = &"kind"
	action.variants = [
		_structure(
			&"melee",
			[_column(&"power", GFConfigTableColumn.ValueType.INT)]
		),
		_structure(
			&"spell",
			[_column(&"name", GFConfigTableColumn.ValueType.STRING)]
		),
	]
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"units"
	schema.columns = [
		_column(&"id", GFConfigTableColumn.ValueType.INT),
		_structured_column(&"stats", elite),
		_structured_column(&"units", units),
		_structured_column(&"by_name", by_name),
		_structured_column(&"matrix", matrix),
		_structured_column(&"rank", rank),
		_structured_column(&"action", action),
		_structured_column(
			&"optional",
			_scalar(GFConfigTableColumn.ValueType.FLOAT)
		),
	]
	return schema


## 创建兼容列，用于确认结构内部仍能使用既有标量字段声明。
func _column(field_name: StringName, value_type: GFConfigTableColumn.ValueType) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = value_type
	return column


## 故意保留不匹配的旧 value_type，验证正式结构定义优先。
func _structured_column(field_name: StringName, definition: GFConfigTypeDefinition) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = _column(field_name, GFConfigTableColumn.ValueType.STRING)
	column.type_definition = definition
	return column


## 创建具名结构并保留字段声明顺序。
func _structure(type_name: StringName, fields: Array[GFConfigTableColumn]) -> GFConfigTypeDefinition:
	var definition: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	definition.kind = GFConfigTypeDefinition.Kind.STRUCT
	definition.type_name = type_name
	definition.fields = fields
	return definition


## 创建强类型标量定义。
func _scalar(value_type: GFConfigTableColumn.ValueType) -> GFConfigTypeDefinition:
	var definition: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	definition.scalar_type = value_type
	return definition


## 使用 Godot 真正编译匿名源码；编译失败时清理后返回 null。
func _compile(source: String) -> GDScript:
	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = source.replace("class_name StructuredAccess\n", "")
	var error: Error = runtime_script.reload(false)
	assert_eq(error, OK)
	if error != OK:
		_release(runtime_script)
		return null
	return runtime_script


## 断开匿名脚本内部类引用，并确认清理没有遗留错误。
func _release(runtime_script: GDScript) -> void:
	var errors: Array[int] = _TRANSIENT_SCRIPT_SUPPORT.release(runtime_script)
	assert_true(errors.is_empty())


# --- 内部类 ---

## 刻意返回借用字典，用来检测生成包装是否真正取得快照。
class RecordingProvider:
	extends RefCounted

	## 本次 provider 返回的权威原始集合。
	var record: Dictionary = {}

	## 保留 provider 的既有调用协议；此夹具始终返回同一字典。
	func get_record(_table_name: StringName, _id: Variant) -> Dictionary:
		return record
