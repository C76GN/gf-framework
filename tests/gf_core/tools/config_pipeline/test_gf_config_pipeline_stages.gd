## 测试 Config Pipeline 的版本化 IR 与独立编译阶段契约。
extends GutTest


# --- 私有变量 ---

var _temporary_paths: Array[String] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_temporary_paths.clear()


func after_each() -> void:
	for path: String in _temporary_paths:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			var _remove_result: Error = DirAccess.remove_absolute(absolute_path)
	_temporary_paths.clear()


# --- 测试 ---

func test_pipeline_ir_has_versioned_contract_and_rejects_duplicate_tables() -> void:
	var table_ir: GFConfigPipelineTableIR = GFConfigPipelineTableIR.create(
		&"items",
		"res://data/items.csv",
		&"csv",
		[
			{ &"id": 1, &"name": "Potion" },
		],
		_make_item_schema(),
		{
			"header": PackedStringArray(["id", "name"]),
		},
		{ "owner": "test" }
	)
	var contract: Dictionary = table_ir.validate_contract()
	var compilation_ir: GFConfigPipelineIR = GFConfigPipelineIR.create(
		&"main",
		"dev",
		{ "target": "test" }
	)
	var first_add: Dictionary = compilation_ir.add_table(table_ir)
	var duplicate_add: Dictionary = compilation_ir.add_table(table_ir)
	var unsealed_contract: Dictionary = compilation_ir.validate_contract()
	var seal_result: Dictionary = compilation_ir.seal()
	var sealed_add: Dictionary = compilation_ir.add_table(table_ir)
	var records_copy: Array[Dictionary] = table_ir.get_records()
	records_copy[0][&"name"] = "Changed"
	var description: Dictionary = compilation_ir.describe()

	assert_true(
		GFVariantData.get_option_bool(contract, "success"),
		"合法 Table IR 应通过契约校验。"
	)
	assert_eq(
		GFConfigPipelineTableIR.FORMAT_VERSION,
		1,
		"首版 Table IR 契约版本应固定为 1。"
	)
	assert_eq(
		GFConfigPipelineIR.FORMAT_VERSION,
		1,
		"首版 Database IR 契约版本应固定为 1。"
	)
	assert_true(
		GFVariantData.get_option_bool(first_add, "success"),
		"首张表应能加入编译 IR。"
	)
	assert_false(
		GFVariantData.get_option_bool(duplicate_add, "success"),
		"重复表名必须 fail closed。"
	)
	assert_eq(
		GFVariantData.get_option_string(duplicate_add, "error_kind"),
		"duplicate_table_ir",
		"重复表应返回稳定错误类型。"
	)
	assert_false(
		GFVariantData.get_option_bool(unsealed_contract, "success"),
		"未封存数据库 IR 不得满足 Target 契约。"
	)
	assert_eq(
		GFVariantData.get_option_string(unsealed_contract, "error_kind"),
		"unsealed_pipeline_ir",
		"未封存 IR 应返回稳定错误类型。"
	)
	assert_true(
		GFVariantData.get_option_bool(seal_result, "success"),
		"结构合法的数据库 IR 应能封存。"
	)
	assert_true(
		compilation_ir.is_sealed(),
		"可交给 Target 的数据库 IR 必须处于 sealed 状态。"
	)
	assert_false(
		GFVariantData.get_option_bool(sealed_add, "success"),
		"封存后的数据库 IR 必须拒绝修改。"
	)
	assert_eq(
		GFVariantData.get_option_string(sealed_add, "error_kind"),
		"ir_sealed",
		"封存写入应返回稳定错误类型。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			table_ir.get_records()[0],
			"name"
		),
		"Potion",
		"Table IR getter 不得暴露内部可变记录。"
	)
	assert_eq(
		GFVariantData.get_option_string(description, "format"),
		GFConfigPipelineIR.FORMAT,
		"IR 摘要应带稳定格式。"
	)
	assert_eq(
		GFVariantData.get_option_int(description, "format_version"),
		GFConfigPipelineIR.FORMAT_VERSION,
		"IR 摘要应带格式版本。"
	)
	assert_eq(
		GFVariantData.get_option_int(description, "table_count"),
		1,
		"重复表不得污染 IR。"
	)


func test_pipeline_descriptors_and_freshness_fingerprint_share_stage_contracts() -> void:
	var descriptors: Array[Dictionary] = GFConfigPipeline.new().get_stage_descriptors()
	var descriptor_ids: PackedStringArray = PackedStringArray()
	for descriptor: Dictionary in descriptors:
		var _descriptor_appended: bool = descriptor_ids.append(GFVariantData.get_option_string(descriptor, "stage_id"))
	var expected_stage_ids: PackedStringArray = PackedStringArray(
		[
			GFConfigPipelineReaderStage.STAGE_ID,
			GFConfigPipelineLayoutStage.STAGE_ID,
			GFConfigPipelineValidationStage.STAGE_ID,
			GFConfigPipelineTargetStage.STAGE_ID,
			GFConfigPipelineCommitStage.STAGE_ID,
		]
	)
	assert_eq(
		descriptor_ids,
		expected_stage_ids,
		"Pipeline 应以稳定顺序公开实际阶段组合。"
	)

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var manifest: Dictionary = GFConfigPipelineArtifactManifest.new().make_manifest("", profile)
	var fingerprint: Dictionary = GFVariantData.get_option_dictionary(manifest, "compiler_fingerprint")
	var fingerprint_ids: PackedStringArray = PackedStringArray()
	for entry_value: Variant in GFVariantData.get_option_array(fingerprint, "stage_entries"):
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var _fingerprint_id_appended: bool = fingerprint_ids.append(GFVariantData.get_option_string(entry, "id"))
	for stage_id: String in expected_stage_ids:
		assert_has(
			fingerprint_ids,
			stage_id,
			"freshness 指纹必须覆盖阶段实现：%s。" % stage_id
		)
	assert_has(
		fingerprint_ids,
		GFConfigPipelineIR.FORMAT,
		"freshness 指纹必须覆盖数据库 IR 契约。"
	)
	assert_has(
		fingerprint_ids,
		GFConfigPipelineTableIR.FORMAT,
		"freshness 指纹必须覆盖单表 IR 契约。"
	)


func test_custom_stage_implementation_is_recorded_in_export_fingerprint() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_custom_stage_%d.csv" % Time.get_ticks_usec(),
		"id,name,power\n1,Potion,2.5\n"
	)
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"custom_stage"
	profile.database_id = &"main"
	profile.output_path = _track_path("user://gf_config_pipeline_custom_stage_%d.tres" % Time.get_ticks_usec())
	profile.sources = [
		_make_source(
			source_path,
			_make_item_schema()
		),
	]
	var pipeline: GFConfigPipeline = GFConfigPipeline.new().configure_stages(CustomReaderStage.new())
	var export_result: Dictionary = pipeline.export_profile(
		profile,
		{ "dry_run": true, "write_manifest": true, }
	)
	var manifest: Dictionary = GFVariantData.get_option_dictionary(export_result, "manifest")
	var fingerprint: Dictionary = GFVariantData.get_option_dictionary(manifest, "compiler_fingerprint")
	var custom_entry: Dictionary = {}
	for entry_value: Variant in GFVariantData.get_option_array(fingerprint, "stage_entries"):
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		if GFVariantData.get_option_string(entry, "id") == CustomReaderStage.CUSTOM_STAGE_ID:
			custom_entry = entry
			break

	assert_true(
		GFVariantData.get_option_bool(export_result, "success"),
		"自定义 Stage 的 dry-run 导出应成功。"
	)
	assert_false(
		custom_entry.is_empty(),
		"导出 manifest 必须记录实际自定义 Stage，而不是内置 Reader。"
	)
	assert_eq(
		GFVariantData.get_option_int(custom_entry, "implementation_version"),
		7,
		"manifest 应记录自定义 Stage 实现版本。"
	)
	assert_eq(
		GFVariantData.get_option_string(custom_entry, "path"),
		"res://tests/gf_core/tools/config_pipeline/test_gf_config_pipeline_stages.gd",
		"manifest 应哈希自定义 Stage 的真实脚本。"
	)


func test_compiler_fingerprint_tracks_declared_stage_dependencies() -> void:
	var dependency_path: String = _write_text(
		"user://gf_config_pipeline_stage_dependency_%d.gd" % Time.get_ticks_usec(),
		"extends RefCounted\nconst SEMANTIC_VALUE := 1\n"
	)
	var reader: DependencyReaderStage = DependencyReaderStage.new()
	reader.dependency_path = dependency_path
	var pipeline: GFConfigPipeline = GFConfigPipeline.new().configure_stages(reader)
	var manifest_helper: GFConfigPipelineArtifactManifest = GFConfigPipelineArtifactManifest.new()
	manifest_helper.configure_compiler_stages(pipeline.get_stage_descriptors())
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var first_manifest: Dictionary = manifest_helper.make_manifest("", profile)
	var _rewritten_dependency: String = _write_text(dependency_path, "extends RefCounted\nconst SEMANTIC_VALUE := 2\n")
	var second_manifest: Dictionary = manifest_helper.make_manifest("", profile)
	var first_fingerprint: Dictionary = GFVariantData.get_option_dictionary(first_manifest, "compiler_fingerprint")
	var dependency_recorded: bool = false
	for entry_value: Variant in GFVariantData.get_option_array(first_fingerprint, "stage_entries"):
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		if GFVariantData.get_option_string(entry, "id") != DependencyReaderStage.CUSTOM_STAGE_ID:
			continue
		for dependency_value: Variant in GFVariantData.get_option_array(entry, "implementation_dependencies"):
			var dependency: Dictionary = GFVariantData.as_dictionary(dependency_value)
			if GFVariantData.get_option_string(dependency, "path") == dependency_path:
				dependency_recorded = true

	assert_true(dependency_recorded, "自定义 Stage 声明的实现依赖必须进入 compiler fingerprint。")
	assert_ne(
		GFVariantData.get_option_string(first_manifest, "compiler_digest"),
		GFVariantData.get_option_string(second_manifest, "compiler_digest"),
		"只修改 Stage helper 也必须改变 compiler digest。"
	)
	var validation_descriptor: Dictionary = GFConfigPipelineValidationStage.new().get_stage_descriptor()
	var validation_dependencies: PackedStringArray = GFVariantData.get_option_packed_string_array(validation_descriptor, "implementation_dependencies")
	assert_has(
		validation_dependencies,
		"res://addons/gf/standard/utilities/config/gf_config_table_schema.gd",
		"Validation fingerprint 必须覆盖 schema 推断实现。"
	)
	assert_has(
		validation_dependencies,
		"res://addons/gf/standard/utilities/config/gf_config_table_column.gd",
		"Validation fingerprint 必须覆盖 typed column 实现。"
	)


func test_reader_stage_enforces_source_budget_before_returning_payload() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_reader_stage_%d.csv" % Time.get_ticks_usec(),
		"id,name\n1,Potion\n"
	)
	var source: GFConfigPipelineTableSource = _make_source(source_path)
	var reader: GFConfigPipelineReaderStage = GFConfigPipelineReaderStage.new()
	var success_result: Dictionary = reader.read_source(source)
	var budget_result: Dictionary = reader.read_source(
		source,
		{ "max_source_file_bytes": 4 }
	)
	var descriptor: Dictionary = reader.get_stage_descriptor()
	var source_receipt: Dictionary = GFVariantData.get_option_dictionary(success_result, "source_receipt")

	assert_true(
		GFVariantData.get_option_bool(success_result, "success"),
		"Reader 应读取受支持的文本来源。"
	)
	assert_eq(
		GFVariantData.get_option_string(success_result, "payload_kind"),
		"text",
		"CSV 应产生文本载荷。"
	)
	assert_eq(
		GFVariantData.get_option_string(success_result, "text"),
		"id,name\n1,Potion\n",
		"Reader 不应改写来源文本。"
	)
	assert_eq(
		GFVariantData.get_option_int(source_receipt, "size_bytes"),
		17,
		"Reader receipt 应绑定实际读取字节数。"
	)
	assert_eq(
		GFVariantData.get_option_string(source_receipt, "sha256"),
		FileAccess.get_sha256(source_path),
		"Reader receipt 应绑定实际读取字节摘要。"
	)
	assert_false(
		GFVariantData.get_option_bool(budget_result, "success"),
		"超预算来源必须在读取载荷前失败。"
	)
	assert_eq(
		GFVariantData.get_option_string(budget_result, "error_kind"),
		"source_budget_exceeded",
		"Reader 应暴露稳定预算错误。"
	)
	assert_eq(
		GFVariantData.get_option_string(descriptor, "stage_id"),
		"gf.config.reader.builtin",
		"Reader 应声明稳定阶段 ID。"
	)


func test_layout_stage_decodes_reader_payload_and_preserves_source_locations() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_layout_stage_%d.csv" % Time.get_ticks_usec(),
		"id,name\n1,Potion\n"
	)
	var source: GFConfigPipelineTableSource = _make_source(source_path)
	var read_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source)
	var layout_result: Dictionary = GFConfigPipelineLayoutStage.new().decode_source(source, read_result)
	var rows: Array = GFVariantData.get_option_array(layout_result, "data")
	var row_locations: Array = GFVariantData.get_option_array(layout_result, "row_locations")

	assert_true(
		GFVariantData.get_option_bool(layout_result, "success"),
		"Layout 应解码 Reader 载荷。"
	)
	assert_eq(
		rows.size(),
		1,
		"Layout 应输出一条规范记录。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(rows[0]),
			"name"
		),
		"Potion",
		"Layout 不应丢失字段。"
	)
	assert_eq(
		row_locations.size(),
		1,
		"Layout 应保留记录来源位置。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.as_dictionary(row_locations[0]),
			"line"
		),
		2,
		"CSV 数据行应定位到源文件第二行。"
	)


## 直接调用 Layout 时，循环或超额解析覆盖必须在深复制前由原共享预算拒绝。
func test_layout_stage_admits_parse_overrides_before_copying() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_layout_options_%d.csv" % Time.get_ticks_usec(),
		"id,name\n1,Potion\n"
	)
	var source: GFConfigPipelineTableSource = _make_source(source_path)
	var reader_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source)
	assert_true(GFVariantData.get_option_bool(reader_result, "success"))
	var reader_snapshot: Dictionary = reader_result.duplicate(true)
	for cyclic: bool in [true, false]:
		var parse_options: Dictionary = {}
		if cyclic:
			parse_options["self"] = parse_options
		else:
			parse_options["payload"] = "x".repeat(16384)
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": 4096 })
		var result: Dictionary = GFConfigPipelineLayoutStage.new().decode_source(
			source,
			reader_result,
			{ "parse_options": parse_options, "work_budget": budget }
		)
		parse_options.clear()
		assert_false(
			GFVariantData.get_option_bool(result, "success"),
			"阶段入口不能先复制未准入的解析选项。"
		)
		var expected_kind: String = "config_work_cycle" if cyclic else "config_work_value_bytes_exceeded"
		assert_eq(
			GFVariantData.get_option_string(result, "error_kind"),
			expected_kind
		)
		assert_false(
			budget.is_ok(),
			"必须锁存调用方传入的同一个预算句柄。"
		)
		var budget_report: Dictionary = GFVariantData.get_option_dictionary(result, "budget_report")
		assert_eq(
			GFVariantData.get_option_string(budget_report, "context"),
			"layout.parse_options"
		)
		var rejected_data: Variant = result.get("data")
		assert_true(rejected_data == null)
		assert_true(GFVariantData.get_option_array(result, "row_locations").is_empty())
		assert_eq(
			reader_result,
			reader_snapshot,
			"拒绝解析覆盖不得修改已读取的正常载荷。"
		)


func test_xlsx_layout_xml_depth_counts_document_root_as_zero() -> void:
	var source_path: String = _write_xlsx_budget_fixture(
		"user://gf_config_pipeline_xlsx_depth_%d.xlsx" % Time.get_ticks_usec(),
		"<worksheet><sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>name</t></is></c></row><row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>Cat</t></is></c></row></sheetData></worksheet>"
	)
	var source: GFConfigPipelineTableSource = _make_source(source_path)
	var accepted_budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_depth": 5 })
	var accepted: Dictionary = _decode_xlsx_with_budget(source, accepted_budget)
	assert_true(
		GFVariantData.get_option_bool(accepted, "success"),
		"worksheet 根深度为零，最深的 t 元素深度五应在边界内成功。"
	)
	var accepted_usage: Dictionary = GFVariantData.get_option_dictionary(
		accepted_budget.get_report(),
		"usage"
	)
	assert_eq(
		GFVariantData.get_option_int(accepted_usage, "peak_depth"),
		5
	)
	var accepted_rows: Array = GFVariantData.get_option_array(accepted, "data")
	assert_eq(
		accepted_rows.size(),
		1
	)
	var rejected_budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_depth": 4 })
	var rejected: Dictionary = _decode_xlsx_with_budget(source, rejected_budget)
	assert_false(GFVariantData.get_option_bool(rejected, "success"))
	assert_eq(
		GFVariantData.get_option_string(rejected, "error_kind"),
		"config_work_depth_exceeded"
	)
	var no_partial_rows: bool = GFVariantData.get_option_value(rejected, "data") == null
	assert_true(no_partial_rows)


func test_xlsx_layout_input_budget_counts_resolved_cells_before_trim_or_overwrite() -> void:
	var repeated_text: String = " 猫 ".repeat(128)
	var duplicate_count: int = 8
	var repeated_cell: String = "<c r=\"A2\" t=\"s\"><v>1</v></c>"
	var worksheet: String = "<worksheet><sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row><row r=\"2\">"
	worksheet += repeated_cell.repeat(duplicate_count)
	worksheet += "<c r=\"A2\" t=\"s\"><v>2</v></c></row><row r=\"3\"><c r=\"A3\" t=\"s\"><v>1</v></c></row></sheetData></worksheet>"
	var shared_strings: String = "<sst><si><t>name</t></si><si><t>%s</t></si><si><t>Cat</t></si></sst>" % repeated_text
	var source_path: String = _write_xlsx_budget_fixture(
		"user://gf_config_pipeline_xlsx_input_%d.xlsx" % Time.get_ticks_usec(),
		worksheet,
		shared_strings
	)
	var source: GFConfigPipelineTableSource = _make_source(source_path)
	var archive_bytes: int = FileAccess.get_file_as_bytes(source_path).size()
	var resolved_bytes: int = "name".to_utf8_buffer().size() + "Cat".to_utf8_buffer().size() + repeated_text.to_utf8_buffer().size() * (duplicate_count + 1)
	assert_gt(
		resolved_bytes,
		archive_bytes,
		"共享字符串重复展开的文本应大于压缩归档，才能覆盖解压后的输入预算。"
	)
	var accepted_budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_input_bytes": archive_bytes + resolved_bytes })
	var accepted: Dictionary = _decode_xlsx_with_budget(source, accepted_budget)
	assert_true(
		GFVariantData.get_option_bool(accepted, "success"),
		"归档与每次实际解析的单元格文本恰好达到上限时应成功，最终行映射不得重复计费。"
	)
	var usage: Dictionary = GFVariantData.get_option_dictionary(
		accepted_budget.get_report(),
		"usage"
	)
	assert_eq(
		GFVariantData.get_option_int(usage, "input_bytes"),
		archive_bytes + resolved_bytes,
		"重复共享字符串引用、被覆盖单元格和裁剪前空白均属于已解析输入。"
	)
	var rows: Array = GFVariantData.get_option_array(accepted, "data")
	assert_eq(
		rows.size(),
		2
	)
	if rows.size() == 2:
		assert_eq(
			GFVariantData.get_option_string(
				GFVariantData.as_dictionary(rows[0]),
				"name"
			),
			"Cat"
		)
		assert_eq(
			GFVariantData.get_option_string(
				GFVariantData.as_dictionary(rows[1]),
				"name"
			),
			repeated_text.strip_edges()
		)
	var rejected_budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_input_bytes": archive_bytes + resolved_bytes - 1 })
	var rejected: Dictionary = _decode_xlsx_with_budget(source, rejected_budget)
	assert_false(GFVariantData.get_option_bool(rejected, "success"))
	assert_eq(
		GFVariantData.get_option_string(rejected, "error_kind"),
		"config_work_input_bytes_exceeded"
	)
	var no_partial_rows: bool = GFVariantData.get_option_value(rejected, "data") == null
	assert_true(no_partial_rows)


func test_validation_stage_compiles_layout_result_into_typed_table_ir() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_validation_stage_%d.csv" % Time.get_ticks_usec(),
		"id,name,power\n1,Potion,2.5\n"
	)
	var source: GFConfigPipelineTableSource = _make_source(
		source_path,
		_make_item_schema()
	)
	var reader_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source)
	var layout_result: Dictionary = GFConfigPipelineLayoutStage.new().decode_source(source, reader_result)
	var layout_snapshot: Dictionary = layout_result.duplicate(true)
	var compile_result: Dictionary = GFConfigPipelineValidationStage.new().compile_table(source, layout_result)
	var ir_value: Variant = GFVariantData.get_option_value(compile_result, "ir")

	assert_true(
		GFVariantData.get_option_bool(compile_result, "success"),
		"Validation 应接受合法记录。"
	)
	assert_eq(
		layout_result,
		layout_snapshot,
		"Validation 不应修改调用方持有的 Layout 结果。"
	)
	assert_true(
		ir_value is GFConfigPipelineTableIR,
		"Validation 成功结果必须交付 Table IR。"
	)
	if ir_value is GFConfigPipelineTableIR:
		var table_ir: GFConfigPipelineTableIR = ir_value
		var records: Array[Dictionary] = table_ir.get_records()
		assert_eq(
			GFVariantData.get_option_int(
				records[0],
				"id"
			),
			1,
			"IR 应保存 schema 转换后的整数。"
		)
		assert_eq(
			GFVariantData.get_option_float(
				records[0],
				"power"
			),
			2.5,
			"IR 应保存 schema 转换后的浮点数。"
		)
		assert_eq(
			GFVariantData.get_option_string(
				table_ir.get_metadata(),
				"source_format"
			),
			"csv",
			"IR 应保留通用来源元数据。"
		)


## 直接调用 Validation 时先准入解析覆盖，循环或超额失败不产生 IR，也不改原布局。
func test_validation_stage_admits_parse_overrides_before_copying() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_validation_options_%d.csv" % Time.get_ticks_usec(),
		"id,name,power\n1,Potion,2.5\n"
	)
	var source: GFConfigPipelineTableSource = _make_source(
		source_path,
		_make_item_schema()
	)
	var reader_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source)
	var layout_result: Dictionary = GFConfigPipelineLayoutStage.new().decode_source(source, reader_result)
	assert_true(GFVariantData.get_option_bool(layout_result, "success"))
	var layout_snapshot: Dictionary = layout_result.duplicate(true)
	for cyclic: bool in [true, false]:
		var parse_options: Dictionary = {}
		if cyclic:
			parse_options["self"] = parse_options
		else:
			parse_options["payload"] = "x".repeat(16384)
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": 4096 })
		var result: Dictionary = GFConfigPipelineValidationStage.new().compile_table(
			source,
			layout_result,
			{ "parse_options": parse_options, "work_budget": budget }
		)
		parse_options.clear()
		assert_false(
			GFVariantData.get_option_bool(result, "success"),
			"阶段入口不能先复制未准入的解析选项。"
		)
		var expected_kind: String = "config_work_cycle" if cyclic else "config_work_value_bytes_exceeded"
		assert_eq(
			GFVariantData.get_option_string(result, "error_kind"),
			expected_kind
		)
		assert_false(
			budget.is_ok(),
			"必须锁存调用方传入的同一个预算句柄。"
		)
		var budget_report: Dictionary = GFVariantData.get_option_dictionary(result, "budget_report")
		assert_eq(
			GFVariantData.get_option_string(budget_report, "context"),
			"validation.copy_inputs"
		)
		var rejected_ir: Variant = result.get("ir")
		assert_true(rejected_ir == null)
		assert_eq(
			layout_result,
			layout_snapshot,
			"拒绝解析覆盖不得修改已接纳的正常布局。"
		)


func test_target_stage_materializes_ir_without_reinterpreting_source() -> void:
	var table_ir: GFConfigPipelineTableIR = GFConfigPipelineTableIR.create(
		&"items",
		"res://data/items.csv",
		&"csv",
		[
			{
				&"id": 1,
				&"name": "Potion",
				&"power": 2.5,
			},
		],
		_make_item_schema(),
		{},
		{ "source_path": "res://data/items.csv", "source_format": &"csv" }
	)
	var compilation_ir: GFConfigPipelineIR = GFConfigPipelineIR.create(&"main", "dev")
	assert_true(
		GFVariantData.get_option_bool(
			compilation_ir.add_table(table_ir),
			"success"
		),
		"测试 IR 应能注册表。"
	)
	assert_true(
		GFVariantData.get_option_bool(
			compilation_ir.seal(),
			"success"
		),
		"Target 测试 IR 应先完成封存。"
	)
	var target: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	var target_result: Dictionary = target.materialize_database(compilation_ir)
	var database_value: Variant = GFVariantData.get_option_value(target_result, "database")
	assert_true(
		database_value is GFConfigDatabaseResource,
		"Target 应物化数据库 Resource。"
	)
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		var export_result: Dictionary = target.make_database_export(database)
		var json_result: Dictionary = target.make_database_json(database)
		var export_data: Dictionary = GFVariantData.get_option_dictionary(export_result, "data")
		assert_true(
			GFVariantData.get_option_bool(target_result, "success"),
			"合法 IR 应物化成功。"
		)
		assert_eq(
			GFVariantData.get_option_string(export_data, "format"),
			"gf.config.database",
			"JSON 目标应保留稳定格式。"
		)
		assert_true(
			GFVariantData.get_option_string(json_result, "text").contains("\"format\": \"gf.config.database\""),
			"Target 应完整拥有稳定 JSON 文本序列化。"
		)
		assert_eq(
			database.get_table_ids(),
			PackedStringArray(["items"]),
			"Target 不应重解释或重命名表。"
		)


func test_commit_stage_rolls_back_existing_and_new_artifacts() -> void:
	var existing_path: String = _write_text(
		"user://gf_config_pipeline_commit_existing_%d.txt" % Time.get_ticks_usec(),
		"before"
	)
	var new_path: String = _track_path("user://gf_config_pipeline_commit_new_%d.txt" % Time.get_ticks_usec())
	var commit_stage: GFConfigPipelineCommitStage = GFConfigPipelineCommitStage.new()
	var transaction: Dictionary = commit_stage.begin(
		PackedStringArray([existing_path, new_path]),
		{
			"allowed_roots": PackedStringArray([existing_path.get_base_dir()]),
		}
	)
	assert_true(
		GFVariantData.get_option_bool(transaction, "ok"),
		"Commit 应成功捕获事务前状态。"
	)
	var _existing_rewrite_path: String = _write_text(existing_path, "after")
	var _new_write_path: String = _write_text(new_path, "new")
	var rollback_result: Dictionary = commit_stage.rollback(transaction)

	assert_true(
		GFVariantData.get_option_bool(rollback_result, "ok"),
		"Rollback 应恢复全部路径。"
	)
	assert_eq(
		_read_text(existing_path),
		"before",
		"Rollback 应恢复已有文件。"
	)
	assert_false(
		FileAccess.file_exists(new_path),
		"Rollback 应删除事务中新建的文件。"
	)


func test_commit_stage_rejects_canonical_duplicate_targets() -> void:
	var target_path: String = _track_path("user://gf_config_pipeline_duplicate_target_%d.txt" % Time.get_ticks_usec())
	var equivalent_path: String = (target_path.get_base_dir().path_join("./%s" % target_path.get_file()))
	var transaction: Dictionary = (
		GFConfigPipelineCommitStage.new().begin(
			PackedStringArray([target_path, equivalent_path]),
			{
				"allowed_roots": PackedStringArray([target_path.get_base_dir()]),
			}
		)
	)

	assert_false(
		GFVariantData.get_option_bool(transaction, "ok"),
		"规范化后相同的产物目标必须在事务 begin 阶段被拒绝。"
	)
	assert_true(
		"; ".join(GFVariantData.get_option_packed_string_array(transaction, "issues")).contains("duplicated"),
		"重复目标应返回可诊断的事务问题。"
	)
	assert_false(
		FileAccess.file_exists(target_path),
		"重复目标 preflight 不得产生任何文件。"
	)


func test_export_rolls_back_when_source_changes_after_compilation() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_receipt_source_%d.csv" % Time.get_ticks_usec(),
		"id,name,power\n1,Potion,2.5\n"
	)
	var output_path: String = _track_path("user://gf_config_pipeline_receipt_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _track_path("user://gf_config_pipeline_receipt_manifest_%d.json" % Time.get_ticks_usec())
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"source_receipt"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.sources = [
		_make_source(
			source_path,
			_make_item_schema()
		),
	]
	var commit_stage: MutatingSourceCommitStage = MutatingSourceCommitStage.new()
	commit_stage.source_path = source_path
	commit_stage.replacement_text = "id,name,power\n2,Elixir,7.5\n"
	var pipeline: GFConfigPipeline = (
		GFConfigPipeline.new().configure_stages(
			null,
			null,
			null,
			null,
			commit_stage
		)
	)
	var export_result: Dictionary = pipeline.export_profile(
		profile,
		{
			"manifest_path": manifest_path,
			"write_manifest": true,
			"scan_filesystem": false,
		}
	)
	var source_validation: Dictionary = GFVariantData.get_option_dictionary(export_result, "source_validation_report")

	assert_false(
		GFVariantData.get_option_bool(export_result, "success"),
		"来源在 build 后漂移时，整批导出必须失败。"
	)
	assert_true(
		GFVariantData.get_option_bool(source_validation, "success"),
		"来源漂移比较本身应成功完成。"
	)
	assert_false(
		GFVariantData.get_option_bool(source_validation, "stable"),
		"来源漂移报告必须区分不稳定状态。"
	)
	assert_eq(
		GFVariantData.get_option_string(source_validation, "error_code"),
		"source_changed_during_export",
		"来源漂移应返回稳定错误码。"
	)
	assert_false(
		FileAccess.file_exists(output_path),
		"来源漂移后数据库产物必须回滚。"
	)
	assert_false(
		FileAccess.file_exists(manifest_path),
		"来源漂移后 manifest 产物必须回滚。"
	)
	assert_eq(
		_read_text(source_path),
		commit_stage.replacement_text,
		"事务只能回滚产物，不应改写外部来源文件。"
	)


func test_target_json_export_enforces_cycle_depth_node_and_byte_budgets() -> void:
	var target: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	database.metadata = cyclic_metadata
	var cycle_result: Dictionary = target.make_database_export(database)
	cyclic_metadata.clear()
	database.metadata = {}

	var deep_metadata: Dictionary = {}
	var cursor: Dictionary = deep_metadata
	for depth_index: int in range(300):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	database.metadata = deep_metadata
	var depth_result: Dictionary = target.make_database_export(
		database,
		{ "max_depth": 1000000 }
	)
	database.metadata = { "values": range(16) }
	var node_result: Dictionary = target.make_database_export(
		database,
		{ "max_nodes": 8 }
	)
	database.metadata = { "text": "x".repeat(256) }
	var byte_result: Dictionary = target.make_database_json(
		database,
		{ "max_output_bytes": 64 }
	)

	assert_false(
		GFVariantData.get_option_bool(cycle_result, "success"),
		"循环 metadata 必须 fail-closed。"
	)
	assert_true(
		GFVariantData.get_option_string(cycle_result, "error").contains("循环"),
		"循环失败应明确报告 cycle 原因。"
	)
	assert_false(
		GFVariantData.get_option_bool(depth_result, "success"),
		"调用方不得用超大 max_depth 取消框架硬上限。"
	)
	assert_true(
		GFVariantData.get_option_string(depth_result, "error").contains("max_depth"),
		"深度失败应报告 max_depth。"
	)
	assert_false(
		GFVariantData.get_option_bool(node_result, "success"),
		"JSON 转换必须执行 max_nodes 预算。"
	)
	assert_true(
		GFVariantData.get_option_string(node_result, "error").contains("max_nodes"),
		"节点失败应报告 max_nodes。"
	)
	assert_false(
		GFVariantData.get_option_bool(byte_result, "success"),
		"JSON 文本必须执行 max_output_bytes 预算。"
	)
	assert_true(
		GFVariantData.get_option_string(byte_result, "error").contains("max_output_bytes"),
		"字节失败应报告 max_output_bytes。"
	)


func test_pipeline_build_result_exposes_the_ir_used_by_target_stage() -> void:
	var source_path: String = _write_text(
		"user://gf_config_pipeline_ir_result_%d.csv" % Time.get_ticks_usec(),
		"id,name,power\n1,Potion,2.5\n"
	)
	var source: GFConfigPipelineTableSource = _make_source(
		source_path,
		_make_item_schema()
	)
	var result: Dictionary = GFConfigPipeline.new().build_table(source)

	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		"Pipeline 应通过阶段链构建合法表。"
	)
	assert_true(
		GFVariantData.get_option_value(result, "ir") is GFConfigPipelineTableIR,
		"构建结果应暴露实际物化的版本化 IR。"
	)
	assert_true(
		GFVariantData.get_option_value(result, "table") is GFConfigTableResource,
		"既有表资源结果应继续由 Target 交付。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(result, "source_receipt"),
			"sha256"
		),
		FileAccess.get_sha256(source_path),
		"构建结果必须携带实际 Reader 编译收据。"
	)


# --- 私有/辅助方法 ---

func _make_source(path: String, schema: GFConfigTableSchema = null) -> GFConfigPipelineTableSource:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = path
	source.source_format = GFConfigPipelineTableSource.FORMAT_AUTO
	source.schema = schema
	return source


func _make_item_schema() -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	schema.id_field = &"id"
	schema.allow_extra_fields = false
	schema.coerce_values = true
	schema.require_unique_id = true
	var id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	id_column.field_name = &"id"
	id_column.value_type = GFConfigTableColumn.ValueType.INT
	id_column.required = true
	id_column.allow_null = false
	var name_column: GFConfigTableColumn = GFConfigTableColumn.new()
	name_column.field_name = &"name"
	name_column.value_type = GFConfigTableColumn.ValueType.STRING
	name_column.required = true
	name_column.allow_null = false
	var power_column: GFConfigTableColumn = GFConfigTableColumn.new()
	power_column.field_name = &"power"
	power_column.value_type = GFConfigTableColumn.ValueType.FLOAT
	schema.columns = [
		id_column,
		name_column,
		power_column,
	]
	return schema


## 通过公开 Reader 与 Layout 入口复用同一个预算，保证归档和展开文本属于同一次操作。
## [br]
## @api private
func _decode_xlsx_with_budget(source: GFConfigPipelineTableSource, budget: GFConfigWorkBudget) -> Dictionary:
	var options: Dictionary = { "work_budget": budget }
	var read_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source, options)
	assert_true(
		GFVariantData.get_option_bool(read_result, "success"),
		"测试预算应足以读取归档，目标失败必须发生在 Layout。"
	)
	return GFConfigPipelineLayoutStage.new().decode_source(
		source,
		read_result,
		options
	)


## 创建具有单张工作表和可选共享字符串的 XLSX，使预算边界测试经过真实 ZIP 和 XML 解析。
## [br]
## @api private
func _write_xlsx_budget_fixture(
	path: String,
	worksheet: String,
	shared_strings: String = ""
) -> String:
	var entries: Dictionary[String, String] = {
		"[Content_Types].xml": "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
		"_rels/.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
		"xl/workbook.xml": "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"items\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
		"xl/_rels/workbook.xml.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
		"xl/worksheets/sheet1.xml": worksheet,
	}
	if not shared_strings.is_empty():
		entries["xl/sharedStrings.xml"] = shared_strings
	var _tracked_path: String = _track_path(path)
	var packer: ZIPPacker = ZIPPacker.new()
	var open_result: Error = packer.open(path)
	assert_eq(open_result, OK)
	if open_result != OK:
		return path
	for entry_path: String in entries:
		var entry_text: String = entries[entry_path]
		var start_result: Error = packer.start_file(entry_path)
		assert_eq(start_result, OK)
		var write_result: Error = packer.write_file(entry_text.to_utf8_buffer())
		assert_eq(write_result, OK)
		var close_file_result: Error = packer.close_file()
		assert_eq(close_file_result, OK)
	var close_result: Error = packer.close()
	assert_eq(close_result, OK)
	return path


func _write_text(path: String, content: String) -> String:
	var _tracked_path: String = _track_path(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试文件应能写入。")
	if file != null:
		var _store_string_result: bool = file.store_string(content)
		file.close()
	return path


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试文件应能读取。")
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _track_path(path: String) -> String:
	if not _temporary_paths.has(path):
		_temporary_paths.append(path)
	return path


# --- 内部类 ---

class CustomReaderStage extends GFConfigPipelineReaderStage:
	const CUSTOM_STAGE_ID: String = "test.config.reader"

	func get_stage_descriptor() -> Dictionary:
		var descriptor: Dictionary = super.get_stage_descriptor()
		descriptor["stage_id"] = CUSTOM_STAGE_ID
		descriptor["implementation_version"] = 7
		descriptor["implementation_path"] = ("res://tests/gf_core/tools/config_pipeline/test_gf_config_pipeline_stages.gd")
		return descriptor


class DependencyReaderStage extends GFConfigPipelineReaderStage:
	const CUSTOM_STAGE_ID: String = "test.config.reader.dependency"
	var dependency_path: String = ""

	func get_stage_descriptor() -> Dictionary:
		var descriptor: Dictionary = super.get_stage_descriptor()
		descriptor["stage_id"] = CUSTOM_STAGE_ID
		descriptor["implementation_version"] = 1
		descriptor["implementation_path"] = ("res://tests/gf_core/tools/config_pipeline/test_gf_config_pipeline_stages.gd")
		descriptor["implementation_dependencies"] = PackedStringArray([dependency_path])
		return descriptor


class MutatingSourceCommitStage extends GFConfigPipelineCommitStage:
	var source_path: String = ""
	var replacement_text: String = ""

	func get_stage_descriptor() -> Dictionary:
		var descriptor: Dictionary = super.get_stage_descriptor()
		descriptor["stage_id"] = "test.config.commit.mutating_source"
		descriptor["implementation_version"] = 1
		descriptor["implementation_path"] = ("res://tests/gf_core/tools/config_pipeline/test_gf_config_pipeline_stages.gd")
		return descriptor


	func begin(paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
		var transaction: Dictionary = super.begin(paths, options)
		if not GFVariantData.get_option_bool(transaction, "ok"):
			return transaction
		var source_file: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
		if source_file != null:
			var _store_result: bool = source_file.store_string(replacement_text)
			source_file.close()
		return transaction
