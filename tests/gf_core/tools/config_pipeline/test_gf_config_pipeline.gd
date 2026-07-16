## 测试配置导表工具包的 CSV / JSON / XLSX 到 Resource 构建流程。
extends GutTest


# --- 常量 ---

const GF_CONFIG_PIPELINE_COMMAND_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_command.gd")


# --- 私有变量 ---

var _temporary_paths: Array[String] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_temporary_paths.clear()


func after_each() -> void:
	for path: String in _temporary_paths:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			var _remove_file_result: Error = DirAccess.remove_absolute(absolute_path)
	_temporary_paths.clear()


# --- 测试 ---

func test_pipeline_builds_typed_database_from_csv_and_saves_resource() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n2,Ether,3\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema = _make_item_schema()
	source.metadata = { "owner": "test" }

	var build_result: Dictionary = _call_pipeline(&"build_database", [[source], { "database_id": &"main", "version": "test" }])
	var database: GFConfigDatabaseResource = _get_database_from_result(build_result)
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.from_database(database) if database != null else null
	var report: Dictionary = GFVariantData.get_option_dictionary(build_result, "report")
	var record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 1)) if provider != null else {}
	var output_path: String = _track_path("user://gf_config_pipeline_database_%d.tres" % Time.get_ticks_usec())
	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path])
	var loaded: GFConfigDatabaseResource = _load_database_resource(output_path)
	var loaded_provider: GFResourceConfigProvider = GFResourceConfigProvider.from_database(loaded) if loaded != null else null

	assert_true(GFVariantData.get_option_bool(build_result, "success"), "合法 CSV 来源应构建数据库成功。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "构建报告应通过校验。")
	assert_not_null(database, "构建结果应返回数据库资源。")
	assert_not_null(provider, "数据库资源应能接入 Resource Provider。")
	assert_eq(GFVariantData.get_option_int(record, "id"), 1, "CSV 字符串 ID 应按 schema 转为 int 后写入资源。")
	assert_eq(GFVariantData.get_option_float(record, "power"), 2.5, "CSV 字符串数值应按 schema 转为 float 后写入资源。")
	assert_eq(GFVariantData.get_option_string(database.get_table_resource(&"items").metadata, "owner"), "test", "来源 metadata 应写入表资源。")
	assert_true(GFVariantData.get_option_bool(save_result, "success"), "数据库资源应可保存为 .tres。")
	assert_not_null(loaded, "保存后的数据库资源应能重新加载。")
	assert_not_null(loaded_provider, "加载后的数据库资源应能接入 Resource Provider。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(loaded_provider.get_record(&"items", 2)), "name"), "Ether", "加载后的数据库资源应保留记录。")


func test_pipeline_saves_database_as_json_export() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("json_save")
	var output_path: String = _track_path("user://gf_config_pipeline_database_%d.json" % Time.get_ticks_usec())

	var export_data: Dictionary = _call_pipeline(&"make_database_export", [database])
	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path, {
		"indent": "",
		"sort_keys": true,
	}])
	var loaded_data: Dictionary = _load_json_dictionary(output_path)
	var tables: Array = GFVariantData.get_option_array(loaded_data, "tables")
	var first_table: Dictionary = GFVariantData.as_dictionary(tables[0]) if not tables.is_empty() else {}
	var records: Array = GFVariantData.get_option_array(first_table, "records")
	var first_record: Dictionary = GFVariantData.as_dictionary(records[0]) if not records.is_empty() else {}
	var table_metadata: Dictionary = GFVariantData.get_option_dictionary(first_table, "metadata")

	assert_eq(GFVariantData.get_option_string(export_data, "format"), "gf.config.database", "导出字典应带稳定格式标识。")
	assert_true(GFVariantData.get_option_bool(save_result, "success"), "数据库应能保存为 JSON 导出。")
	assert_eq(GFVariantData.get_option_string_name(save_result, "format"), &"json", "保存结果应报告 JSON 输出格式。")
	assert_eq(GFVariantData.get_option_string(loaded_data, "database_id"), "main", "JSON 导出应保留数据库 ID。")
	assert_eq(tables.size(), 1, "JSON 导出应包含表列表。")
	assert_eq(GFVariantData.get_option_string(first_table, "table_name"), "items", "JSON 导出应保留表名。")
	assert_true(first_table.has("schema"), "JSON 导出默认应包含 schema 摘要。")
	assert_false(first_table.has("records_by_index"), "JSON 导出默认不应写入可重建索引缓存。")
	assert_eq(GFVariantData.get_option_int(first_record, "id"), 1, "JSON 导出应保留转换后的记录数据。")
	assert_eq(GFVariantData.get_option_string(table_metadata, "source_format"), "csv", "JSON 导出应把 StringName metadata 转为 JSON 字符串。")


func test_pipeline_save_database_json_dry_run_reports_artifact_without_writing() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("json_dry_run")
	var output_path: String = _track_path("user://gf_config_pipeline_database_dry_run_%d.json" % Time.get_ticks_usec())

	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path, {
		"output_format": &"json",
		"dry_run": true,
	}])
	var artifact_report: Dictionary = GFVariantData.get_option_dictionary(save_result, "artifact_report")

	assert_true(GFVariantData.get_option_bool(save_result, "success"), "JSON dry-run 保存应报告成功。")
	assert_eq(GFVariantData.get_option_string_name(save_result, "status"), GFGeneratedArtifactReport.STATUS_NEW, "新文件 dry-run 应报告 new。")
	assert_true(GFVariantData.get_option_bool(save_result, "dry_run"), "保存结果应保留 dry_run 标记。")
	assert_false(GFVariantData.get_option_bool(save_result, "written"), "dry-run 不应写入文件。")
	assert_eq(GFVariantData.get_option_string_name(artifact_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "artifact_report 应保留产物状态。")
	assert_false(FileAccess.file_exists(output_path), "JSON dry-run 不应创建输出文件。")


func test_pipeline_generate_access_dry_run_reports_artifact_without_writing() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("access_dry_run")
	var output_path: String = _track_path("user://gf_config_pipeline_access_dry_run_%d.gd" % Time.get_ticks_usec())

	var access_result: Dictionary = _call_pipeline(&"generate_access", [
		database,
		output_path,
		"DryRunConfigAccess",
		"null",
		{
			"dry_run": true,
		},
	])
	var artifact_report: Dictionary = GFVariantData.get_option_dictionary(access_result, "artifact_report")

	assert_true(GFVariantData.get_option_bool(access_result, "success"), "访问器 dry-run 生成应报告成功。")
	assert_eq(GFVariantData.get_option_string_name(artifact_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "artifact_report 应报告 new。")
	assert_true(GFVariantData.get_option_bool(artifact_report, "dry_run"), "artifact_report 应保留 dry_run 标记。")
	assert_false(GFVariantData.get_option_bool(artifact_report, "written"), "dry-run 不应写入访问器。")
	assert_false(FileAccess.file_exists(output_path), "访问器 dry-run 不应创建输出文件。")


func test_pipeline_loads_json_source_with_auto_format() -> void:
	var json_path: String = _write_text("user://gf_config_pipeline_items_%d.json" % Time.get_ticks_usec(), "{\"b\":{\"id\":2,\"name\":\"Ether\",\"power\":3.0},\"a\":{\"id\":1,\"name\":\"Potion\",\"power\":2.5}}")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = json_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_AUTO
	source.schema = _make_item_schema()

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)

	assert_true(GFVariantData.get_option_bool(table_result, "success"), "JSON 来源应按扩展名自动解析。")
	assert_not_null(table, "JSON 来源应构建表资源。")
	assert_eq(table.get_table_key(), &"items", "表名应可从 schema 推断。")
	assert_eq(GFVariantData.get_option_int(table.records[0], "id"), 1, "Dictionary 形式 JSON 表应按键排序保持确定性。")


func test_pipeline_loads_config_file_source_with_auto_format() -> void:
	var cfg_path: String = _write_text("user://gf_config_pipeline_items_%d.cfg" % Time.get_ticks_usec(), "[1]\nname=\"Potion\"\npower=2.5\n\n[2]\nname=\"Ether\"\npower=3\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = cfg_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_AUTO
	source.schema = _make_item_schema()
	source.parse_options = {
		"section_field": &"id",
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var first_record: Dictionary = table.records[0] if table != null and not table.records.is_empty() else {}

	assert_eq(source.get_resolved_format(), GFConfigPipelineTableSource.FORMAT_CONFIG_FILE, "cfg 扩展名应被自动识别为 ConfigFile。")
	assert_true(GFVariantData.get_option_bool(table_result, "success"), "ConfigFile 来源应能构建表资源。")
	assert_not_null(table, "ConfigFile 来源应返回表资源。")
	assert_eq(GFVariantData.get_option_string_name(table.metadata, "source_format"), GFConfigPipelineTableSource.FORMAT_CONFIG_FILE, "表 metadata 应记录 ConfigFile 来源格式。")
	assert_eq(GFVariantData.get_option_int(first_record, "id"), 1, "section 名应按 schema 转为 id。")
	assert_eq(GFVariantData.get_option_float(first_record, "power"), 2.5, "ConfigFile 数值应按 schema 保留或转换。")


func test_pipeline_loads_xlsx_source_with_auto_format() -> void:
	var xlsx_path: String = _write_xlsx("user://gf_config_pipeline_items_%d.xlsx" % Time.get_ticks_usec(), "Items", [
		PackedStringArray(["id", "name", "power"]),
		PackedStringArray(["1", "Potion", "2.5"]),
		PackedStringArray(["2", "Ether", "3"]),
	])
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_AUTO
	source.schema = _make_item_schema()
	source.parse_options = { "sheet_name": "Items" }

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")
	var first_record: Dictionary = table.records[0] if table != null and not table.records.is_empty() else {}

	assert_eq(source.get_resolved_format(), GFConfigPipelineTableSource.FORMAT_XLSX, "xlsx 扩展名应被自动识别。")
	assert_true(GFVariantData.get_option_bool(table_result, "success"), "XLSX 来源应能构建表资源。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "XLSX 构建报告应通过校验。")
	assert_not_null(table, "XLSX 来源应返回表资源。")
	assert_eq(GFVariantData.get_option_string_name(table.metadata, "source_format"), GFConfigPipelineTableSource.FORMAT_XLSX, "表 metadata 应记录 xlsx 来源格式。")
	assert_eq(GFVariantData.get_option_int(first_record, "id"), 1, "XLSX 字符串 ID 应按 schema 转为 int。")
	assert_eq(GFVariantData.get_option_float(first_record, "power"), 2.5, "XLSX 字符串数值应按 schema 转为 float。")


func test_pipeline_xlsx_source_respects_comment_prefix_parse_options() -> void:
	var xlsx_path: String = _write_xlsx("user://gf_config_pipeline_comment_options_%d.xlsx" % Time.get_ticks_usec(), "Items", [
		PackedStringArray(["id", "#note", "name", "power"]),
		PackedStringArray(["# local", "", "", ""]),
		PackedStringArray(["1", "internal", "Potion", "2.5"]),
	])
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_XLSX
	source.schema = _make_item_schema()
	source.parse_options = {
		"sheet_name": "Items",
		"comment_prefixes": PackedStringArray(["#"]),
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var first_record: Dictionary = table.records[0] if table != null and not table.records.is_empty() else {}

	assert_true(GFVariantData.get_option_bool(table_result, "success"), "XLSX 注释行列选项不应破坏导表。")
	assert_not_null(table, "XLSX 来源应返回表资源。")
	assert_eq(table.records.size(), 1, "注释行不应进入表资源。")
	assert_eq(GFVariantData.get_option_string(first_record, "name"), "Potion", "非注释列应保留。")
	assert_false(first_record.has(&"#note"), "注释列不应写入表资源记录。")


func test_pipeline_reports_xlsx_row_limit_exceeded() -> void:
	var xlsx_path: String = _write_xlsx("user://gf_config_pipeline_row_limit_%d.xlsx" % Time.get_ticks_usec(), "Items", [
		PackedStringArray(["id", "name", "power"]),
		PackedStringArray(["1", "Potion", "2.5"]),
	])
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_XLSX
	source.schema = _make_item_schema()
	source.parse_options = {
		"sheet_name": "Items",
		"max_xlsx_rows": 1,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "超过 XLSX 行数上限时不应构建表资源。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "parse_failed"), "错误报告应包含 XLSX parse_failed。")
	assert_true(GFVariantData.get_option_string(table_result, "error").contains("max_xlsx_rows"), "错误应说明行数上限。")


func test_pipeline_reports_xlsx_entry_count_limit_before_reading_entries() -> void:
	var xlsx_path: String = _write_xlsx("user://gf_config_pipeline_entry_count_%d.xlsx" % Time.get_ticks_usec(), "Items", [
		PackedStringArray(["id", "name", "power"]),
		PackedStringArray(["1", "Potion", "2.5"]),
	])
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_XLSX
	source.schema = _make_item_schema()
	source.parse_options = {
		"max_xlsx_entry_count": 2,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "超过 XLSX entry 数量上限时不应构建表资源。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "parse_failed"), "错误报告应包含 XLSX parse_failed。")
	assert_true(GFVariantData.get_option_string(table_result, "error").contains("max_xlsx_entry_count"), "错误应说明 entry 数量上限。")


func test_pipeline_reports_xlsx_missing_header_row() -> void:
	var xlsx_path: String = _write_xlsx("user://gf_config_pipeline_missing_header_%d.xlsx" % Time.get_ticks_usec(), "Items", [
		PackedStringArray(["1", "Potion", "2.5"]),
	])
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_XLSX
	source.schema = _make_item_schema()
	source.parse_options = {
		"sheet_name": "Items",
		"header_row": 3,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "缺失指定 header row 的 XLSX 不应被当作空表成功导入。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "parse_failed"), "错误报告应包含 XLSX parse_failed。")
	assert_true(GFVariantData.get_option_string(table_result, "error").contains("header row is missing"), "错误应说明 header row 缺失。")


func test_pipeline_reports_xlsx_empty_header_row() -> void:
	var xlsx_path: String = _write_xlsx("user://gf_config_pipeline_empty_header_%d.xlsx" % Time.get_ticks_usec(), "Items", [
		PackedStringArray(["", ""]),
		PackedStringArray(["1", "Potion"]),
	])
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_XLSX
	source.schema = _make_item_schema()
	source.parse_options = { "sheet_name": "Items" }

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "空 header row 的 XLSX 不应生成无字段记录。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "parse_failed"), "错误报告应包含 XLSX parse_failed。")
	assert_true(GFVariantData.get_option_string(table_result, "error").contains("header row is empty"), "错误应说明 header row 为空。")


func test_pipeline_builds_schema_from_typed_csv_headers() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_typed_headers_%d.csv" % Time.get_ticks_usec(), "id:int!,name:string,power:float\n1,Potion,2.5\n2,Ether,3\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema_options = {
		"typed_headers": true,
		"id_field": &"id",
		"require_unique_id": true,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var schema: GFConfigTableSchema = table.schema if table != null else null
	var id_column: GFConfigTableColumn = schema.get_column(&"id") if schema != null else null
	var power_column: GFConfigTableColumn = schema.get_column(&"power") if schema != null else null
	var first_record: Dictionary = table.records[0] if table != null and not table.records.is_empty() else {}

	assert_true(GFVariantData.get_option_bool(table_result, "success"), "类型化 CSV 表头应能生成 schema 并构建表资源。")
	assert_not_null(schema, "类型化表头应生成表 schema。")
	assert_not_null(id_column, "类型化表头应生成 id 字段声明。")
	assert_not_null(power_column, "类型化表头应生成 power 字段声明。")
	assert_eq(id_column.value_type, GFConfigTableColumn.ValueType.INT, "id:int! 应声明为 int 字段。")
	assert_true(id_column.required, "id:int! 应声明为必填字段。")
	assert_false(id_column.allow_null, "id:int! 应禁止 null。")
	assert_eq(power_column.value_type, GFConfigTableColumn.ValueType.FLOAT, "power:float 应声明为 float 字段。")
	assert_eq(GFVariantData.get_option_int(first_record, "id"), 1, "类型化表头生成的 schema 应默认转换 CSV 字符串 ID。")
	assert_eq(GFVariantData.get_option_float(first_record, "power"), 2.5, "类型化表头生成的 schema 应默认转换 CSV 字符串数值。")
	assert_false(first_record.has(&"id:int!"), "写入资源的记录字段名应清理为稳定字段名。")


func test_pipeline_builds_schema_from_typed_csv_header_type_row() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_typed_header_type_row_%d.csv" % Time.get_ticks_usec(), "id,name,power\nint!,string,float\n1,Potion,2.5\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema_options = {
		"typed_headers": true,
		"typed_header_type_row": true,
		"require_unique_id": true,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var schema: GFConfigTableSchema = table.schema if table != null else null
	var id_column: GFConfigTableColumn = schema.get_column(&"id") if schema != null else null
	var power_column: GFConfigTableColumn = schema.get_column(&"power") if schema != null else null
	var first_record: Dictionary = table.records[0] if table != null and not table.records.is_empty() else {}

	assert_true(GFVariantData.get_option_bool(table_result, "success"), "独立类型行应能生成 schema 并构建表资源。")
	assert_not_null(id_column, "类型行应生成 id 字段声明。")
	assert_not_null(power_column, "类型行应生成 power 字段声明。")
	assert_eq(id_column.value_type, GFConfigTableColumn.ValueType.INT, "类型行 int! 应声明为 int 必填字段。")
	assert_true(id_column.required, "类型行 int! 应保留必填标记。")
	assert_eq(power_column.value_type, GFConfigTableColumn.ValueType.FLOAT, "类型行 float 应声明为 float 字段。")
	assert_eq(table.records.size(), 1, "类型行本身不应写入记录列表。")
	assert_eq(GFVariantData.get_option_int(first_record, "id"), 1, "类型行生成的 schema 应转换 CSV 字符串 ID。")
	assert_eq(GFVariantData.get_option_float(first_record, "power"), 2.5, "类型行生成的 schema 应转换 CSV 字符串数值。")
	assert_eq(GFVariantData.get_option_string(schema.metadata, "schema_source"), "typed_header_type_row", "schema metadata 应标记类型行来源。")


func test_pipeline_reports_missing_typed_csv_header_type_row() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_missing_typed_header_type_row_%d.csv" % Time.get_ticks_usec(), "id,name\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema_options = {
		"typed_headers": true,
		"typed_header_type_row": true,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "启用类型行但缺少类型行时应报告错误。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "missing_typed_header_type_row"), "错误报告应包含缺少类型行。")


func test_pipeline_builds_schema_from_typed_csv_header_type_row_without_data_rows() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_empty_typed_header_type_row_%d.csv" % Time.get_ticks_usec(), "id,name\nint!,string\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema_options = {
		"typed_headers": true,
		"typed_header_type_row": true,
	}

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var schema: GFConfigTableSchema = table.schema if table != null else null
	var id_column: GFConfigTableColumn = schema.get_column(&"id") if schema != null else null

	assert_true(GFVariantData.get_option_bool(table_result, "success"), "只有表头和类型行时也应能构建空表资源。")
	assert_not_null(id_column, "空表 schema 应包含类型行声明的字段。")
	assert_eq(id_column.value_type, GFConfigTableColumn.ValueType.INT, "空表 schema 应保留类型行字段类型。")
	assert_eq(table.records.size(), 0, "类型行空表不应生成数据记录。")


func test_pipeline_builds_schema_from_typed_csv_headers_without_rows() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_empty_typed_headers_%d.csv" % Time.get_ticks_usec(), "id:int!,name:string\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema_options = { "typed_headers": true }

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var table: GFConfigTableResource = _get_table_from_result(table_result)
	var schema: GFConfigTableSchema = table.schema if table != null else null
	var id_column: GFConfigTableColumn = schema.get_column(&"id") if schema != null else null
	var record_count: int = table.records.size() if table != null else -1

	assert_true(GFVariantData.get_option_bool(table_result, "success"), "只有类型化表头的 CSV 也应能构建空表资源。")
	assert_not_null(schema, "空表也应保留由表头声明生成的 schema。")
	assert_not_null(id_column, "空表 schema 应包含类型化表头字段。")
	assert_eq(id_column.value_type, GFConfigTableColumn.ValueType.INT, "空表 schema 应保留表头类型。")
	assert_eq(record_count, 0, "只有表头时记录列表应为空。")


func test_pipeline_reports_invalid_typed_header_type() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_bad_typed_headers_%d.csv" % Time.get_ticks_usec(), "id:uuid\n1\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema_options = { "typed_headers": true }

	var table_result: Dictionary = _call_pipeline(&"build_table", [source])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "未知类型化表头类型不应静默导入。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "unsupported_typed_header_type"), "错误报告应包含不支持的表头类型。")


func test_pipeline_profile_exports_database_resource() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_profile_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var output_path: String = _track_path("user://gf_config_pipeline_profile_database_%d.tres" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"dev"
	profile.database_id = &"main"
	profile.version = "profile-test"
	profile.output_path = output_path
	profile.sources = [source]
	profile.build_options = { "metadata": { "build": "profile" } }
	profile.metadata = { "owner": "test" }

	var export_result: Dictionary = _call_pipeline(&"export_profile", [profile])
	var database: GFConfigDatabaseResource = _get_database_from_result(export_result)
	var save_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "save_result")
	var loaded: GFConfigDatabaseResource = _load_database_resource(output_path)

	assert_true(GFVariantData.get_option_bool(export_result, "success"), "Profile 应能构建并保存数据库资源。")
	assert_not_null(database, "Profile 导出结果应返回数据库资源。")
	assert_true(GFVariantData.get_option_bool(save_result, "success"), "Profile 导出应包含保存成功结果。")
	assert_eq(database.database_id, &"main", "Profile database_id 应写入数据库资源。")
	assert_eq(database.version, "profile-test", "Profile version 应写入数据库资源。")
	assert_eq(GFVariantData.get_option_string(database.metadata, "build"), "profile", "build_options metadata 应写入数据库资源。")
	assert_eq(GFVariantData.get_option_string(database.metadata, "owner"), "test", "Profile metadata 应合并写入数据库资源。")
	assert_not_null(loaded, "Profile 保存后的数据库资源应能重新加载。")


func test_pipeline_profile_exports_database_json() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_profile_json_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var output_path: String = _track_path("user://gf_config_pipeline_profile_database_%d.json" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"json"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.sources = [source]
	profile.save_options = {
		"include_indexes": true,
		"indent": "",
	}

	var export_result: Dictionary = _call_pipeline(&"export_profile", [profile])
	var save_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "save_result")
	var loaded_data: Dictionary = _load_json_dictionary(output_path)
	var tables: Array = GFVariantData.get_option_array(loaded_data, "tables")
	var first_table: Dictionary = GFVariantData.as_dictionary(tables[0]) if not tables.is_empty() else {}

	assert_true(GFVariantData.get_option_bool(export_result, "success"), "Profile 应能导出 JSON 数据库。")
	assert_eq(GFVariantData.get_option_string_name(save_result, "format"), &"json", "Profile 保存结果应报告 JSON 输出格式。")
	assert_eq(GFVariantData.get_option_string(loaded_data, "format"), "gf.config.database", "Profile JSON 导出应带稳定格式标识。")
	assert_true(first_table.has("records_by_id"), "include_indexes 时 JSON 导出应包含 ID 索引。")


func test_pipeline_profile_exports_access_script() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_profile_access_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var output_path: String = _track_path("user://gf_config_pipeline_profile_access_database_%d.tres" % Time.get_ticks_usec())
	var access_path: String = _track_path("user://gf_config_pipeline_access_%d.gd" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"access"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.access_output_path = access_path
	profile.access_class_name = "ItemsConfigAccess"
	profile.access_options = {
		"include_typed_records": true,
	}
	profile.sources = [source]

	var export_result: Dictionary = _call_pipeline(&"export_profile", [profile])
	var access_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "access_result")
	var access_source: String = _read_text(access_path)

	assert_true(GFVariantData.get_option_bool(export_result, "success"), "Profile 应能导出数据库并生成访问器。")
	assert_true(GFVariantData.get_option_bool(access_result, "success"), "访问器生成结果应成功。")
	assert_false(GFVariantData.get_option_bool(access_result, "skipped", true), "配置访问器输出路径后不应跳过生成。")
	assert_eq(GFVariantData.get_option_string(access_result, "path"), access_path, "访问器结果应报告输出路径。")
	assert_eq(GFVariantData.get_option_int(access_result, "schema_count"), 1, "访问器结果应报告参与生成的 schema 数量。")
	assert_true(access_source.contains("class_name ItemsConfigAccess"), "访问器源码应使用 Profile 配置的 class_name。")
	assert_true(access_source.contains("static func get_items_typed_record(id: Variant, provider: Variant = null) -> ItemsRecord:"), "访问器源码应包含 typed record 方法。")
	assert_true(access_source.contains("func get_power() -> float:"), "访问器源码应根据 schema 字段生成 typed getter。")

	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = access_source.replace("class_name ItemsConfigAccess\n", "")
	assert_eq(runtime_script.reload(), OK, "Profile 生成的访问器源码应能编译。")


func test_pipeline_profile_and_source_duplicate_as_independent_resources() -> void:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = "res://data/items.csv"
	source.schema = _make_item_schema()
	source.parse_options = { "delimiter": "," }
	var source_copy: GFConfigPipelineTableSource = source.duplicate_source()
	source_copy.table_name = &"items_copy"
	source_copy.parse_options["delimiter"] = ";"
	source_copy.schema.table_name = &"items_copy"

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"dev"
	profile.sources = [source]
	profile.build_options = { "metadata": { "owner": "source" } }
	var profile_copy: GFConfigPipelineProfile = profile.duplicate_profile()
	profile_copy.profile_id = &"copy"
	profile_copy.build_options["metadata"]["owner"] = "copy"

	assert_eq(source.table_name, &"items", "duplicate_source 不应共享基础字段。")
	assert_eq(GFVariantData.get_option_string(source.parse_options, "delimiter"), ",", "duplicate_source 不应共享 parse_options。")
	assert_eq(source.schema.table_name, &"items", "duplicate_source 不应共享 schema。")
	assert_eq(profile.profile_id, &"dev", "duplicate_profile 不应共享基础字段。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(profile.build_options, "metadata"), "owner"), "source", "duplicate_profile 不应共享 build_options。")


func test_pipeline_profile_uses_export_output_override() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_profile_override_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var default_output_path: String = _track_path("user://gf_config_pipeline_profile_default_%d.tres" % Time.get_ticks_usec())
	var override_output_path: String = _track_path("user://gf_config_pipeline_profile_override_%d.tres" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"override"
	profile.database_id = &"main"
	profile.output_path = default_output_path
	profile.sources = [source]

	var export_result: Dictionary = _call_pipeline(&"export_profile", [profile, { "output_path": override_output_path }])
	var default_path_exists: bool = FileAccess.file_exists(ProjectSettings.globalize_path(default_output_path))
	var loaded_override: GFConfigDatabaseResource = _load_database_resource(override_output_path)

	assert_true(GFVariantData.get_option_bool(export_result, "success"), "Profile 应允许本次导出覆盖输出路径。")
	assert_eq(GFVariantData.get_option_string(export_result, "output_path"), override_output_path, "导出结果应报告覆盖后的输出路径。")
	assert_false(default_path_exists, "覆盖输出路径时不应写入 Profile 默认路径。")
	assert_not_null(loaded_override, "覆盖输出路径应保存数据库资源。")


func test_pipeline_profile_build_options_do_not_include_runner_options() -> void:
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.database_id = &"main"
	profile.build_options = { "metadata": { "owner": "profile" } }

	var build_options: Dictionary = profile.make_build_options({
		"changed_only": true,
		"manifest_path": "user://ignored.manifest.json",
		"manifest_options": { "indent": "" },
		"output_path": "user://ignored.tres",
		"database_id": &"override",
		"metadata": { "owner": "override" },
	})
	var metadata: Dictionary = GFVariantData.get_option_dictionary(build_options, "metadata")

	assert_eq(GFVariantData.get_option_string_name(build_options, "database_id"), &"override", "构建白名单选项仍应允许覆盖 database_id。")
	assert_eq(GFVariantData.get_option_string(metadata, "owner"), "override", "构建白名单选项仍应允许覆盖 metadata。")
	assert_false(build_options.has("changed_only"), "runner 选项不应进入 build options。")
	assert_false(build_options.has("manifest_path"), "manifest 输出路径不应进入 build options。")
	assert_false(build_options.has("manifest_options"), "manifest 选项不应进入 build options。")
	assert_false(build_options.has("output_path"), "保存输出路径不应进入 build options。")


func test_pipeline_profile_reports_empty_sources() -> void:
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"empty"

	var build_result: Dictionary = _call_pipeline(&"build_profile", [profile])
	var report: Dictionary = GFVariantData.get_option_dictionary(build_result, "report")

	assert_false(GFVariantData.get_option_bool(build_result, "success"), "空来源 Profile 不应被当作成功构建。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "empty_pipeline_sources"), "空来源 Profile 应返回明确问题类型。")


func test_pipeline_database_reports_empty_sources() -> void:
	var build_result: Dictionary = _call_pipeline(&"build_database", [[], { "database_id": &"empty" }])
	var report: Dictionary = GFVariantData.get_option_dictionary(build_result, "report")
	var database: GFConfigDatabaseResource = _get_database_from_result(build_result)

	assert_false(GFVariantData.get_option_bool(build_result, "success"), "空来源数据库不应被当作成功构建。")
	assert_not_null(database, "失败结果仍应返回数据库资源以便调用方检查上下文。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "empty_table_sources"), "空来源数据库应返回明确问题类型。")


func test_pipeline_database_rejects_duplicate_table_sources() -> void:
	var first_path: String = _write_text("user://gf_config_pipeline_dupe_a_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var second_path: String = _write_text("user://gf_config_pipeline_dupe_b_%d.csv" % Time.get_ticks_usec(), "id,name,power\n2,Ether,3\n")
	var first_source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	first_source.table_name = &"items"
	first_source.source_path = first_path
	first_source.schema = _make_item_schema()
	var second_source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	second_source.table_name = &"items"
	second_source.source_path = second_path
	second_source.schema = _make_item_schema()

	var build_result: Dictionary = _call_pipeline(&"build_database", [[first_source, second_source], { "database_id": &"main" }])
	var report: Dictionary = GFVariantData.get_option_dictionary(build_result, "report")
	var database: GFConfigDatabaseResource = _get_database_from_result(build_result)

	assert_false(GFVariantData.get_option_bool(build_result, "success"), "重复 table key 的来源不应静默覆盖前一个表。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "duplicate_table_source"), "报告应包含重复来源错误。")
	assert_eq(database.get_table_ids().size(), 1, "重复来源失败时数据库只应保留首个成功注册表，避免覆盖。")


func test_pipeline_save_database_rejects_gf_source_output_path_by_default() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("gf_source_output")
	var output_path: String = "res://addons/gf/tools/config_pipeline/should_not_write_config_pipeline_test.tres"

	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path])

	assert_false(GFVariantData.get_option_bool(save_result, "success"), "默认不应允许导表输出写入 GF 框架源码目录。")
	assert_eq(GFVariantData.get_option_int(save_result, "error_code"), ERR_INVALID_PARAMETER, "路径策略失败应报告参数错误。")
	assert_false(FileAccess.file_exists(output_path), "被路径策略拒绝的产物不应落盘。")


func test_pipeline_save_database_rejects_canonicalized_gf_source_output_path() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("gf_source_output_canonical")
	var output_path: String = "res://addons/./gf/tools/config_pipeline/should_not_write_config_pipeline_test.tres"

	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path])

	assert_false(GFVariantData.get_option_bool(save_result, "success"), "默认不应允许 canonicalize 后落入 GF 源码目录的输出路径。")
	assert_eq(GFVariantData.get_option_int(save_result, "error_code"), ERR_INVALID_PARAMETER, "路径策略失败应报告参数错误。")
	assert_false(FileAccess.file_exists("res://addons/gf/tools/config_pipeline/should_not_write_config_pipeline_test.tres"), "被路径策略拒绝的产物不应落盘。")


func test_pipeline_export_profile_preflights_access_before_writing_database() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_atomic_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var output_path: String = _track_path("user://gf_config_pipeline_atomic_database_%d.tres" % Time.get_ticks_usec())
	var access_path: String = _write_text("user://gf_config_pipeline_atomic_access_%d.gd" % Time.get_ticks_usec(), "# existing\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"atomic"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.access_output_path = access_path
	profile.access_class_name = "AtomicConfigAccess"
	profile.access_options = {
		"overwrite_existing": false,
	}
	profile.sources = [source]

	var export_result: Dictionary = _call_pipeline(&"export_profile", [profile])
	var save_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "save_result")
	var access_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "access_result")

	assert_push_warning("[GFConfigAccessGenerator] 目标文件已存在，已跳过：%s" % access_path)
	assert_false(GFVariantData.get_option_bool(export_result, "success"), "访问器预检失败应让 Profile 导出整体失败。")
	assert_true(GFVariantData.get_option_bool(save_result, "dry_run"), "导出失败时 save_result 应保留预检结果而非实际写入结果。")
	assert_false(FileAccess.file_exists(output_path), "访问器预检失败时数据库不应提前写入。")
	assert_false(GFVariantData.get_option_bool(access_result, "success"), "access_result 应报告预检失败。")
	assert_eq(_read_text(access_path), "# existing\n", "访问器预检失败不应改写已有文件。")


func test_pipeline_runner_exports_profile_from_resource_path() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_runner_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_runner_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_runner_database_%d.tres" % Time.get_ticks_usec())
	var access_path: String = _track_path("user://gf_config_pipeline_runner_access_%d.gd" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"runner"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.access_output_path = access_path
	profile.sources = [source]
	assert_eq(ResourceSaver.save(profile, profile_path), OK, "测试 Profile 应能保存为 .tres。")

	var run_result: Dictionary = _call_runner(&"export_profile_path", [profile_path])
	var database: GFConfigDatabaseResource = _get_database_from_result(run_result)
	var loaded: GFConfigDatabaseResource = _load_database_resource(output_path)
	var access_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "access_result")

	assert_true(GFVariantData.get_option_bool(run_result, "success"), "Runner 应能从 Profile 路径导出数据库资源。")
	assert_eq(GFVariantData.get_option_string_name(run_result, "operation"), &"export", "Runner 应报告执行操作。")
	assert_eq(GFVariantData.get_option_string(run_result, "profile_path"), profile_path, "Runner 应保留 Profile 路径。")
	assert_eq(GFVariantData.get_option_string_name(run_result, "profile_id"), &"runner", "Runner 应报告 Profile ID。")
	assert_not_null(database, "Runner 应返回导出的数据库资源。")
	assert_not_null(loaded, "Runner 应保存数据库资源到 Profile output_path。")
	assert_true(GFVariantData.get_option_bool(access_result, "success"), "Runner 应透传访问器生成结果。")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(access_path)), "Runner 应按 Profile 生成访问器脚本。")


func test_pipeline_runner_writes_manifest_for_changed_only_export() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _track_path("user://gf_config_pipeline_manifest_database_%d.manifest.json" % Time.get_ticks_usec())
	_save_runner_profile(&"manifest", csv_path, profile_path, output_path)

	var run_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, {
		"changed_only": true,
		"manifest_path": manifest_path,
	}])
	var manifest_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "manifest_result")
	var manifest_data: Dictionary = _load_json_dictionary(manifest_path)

	assert_true(GFVariantData.get_option_bool(run_result, "success"), "changed-only 首次导出应成功写入产物。")
	assert_false(GFVariantData.get_option_bool(run_result, "skipped"), "首次导出没有 fresh manifest，不应跳过。")
	assert_true(FileAccess.file_exists(output_path), "首次导出应写入数据库 JSON。")
	assert_true(FileAccess.file_exists(manifest_path), "首次导出应写入 manifest。")
	assert_true(GFVariantData.get_option_bool(manifest_result, "success"), "manifest 保存结果应成功。")
	assert_eq(GFVariantData.get_option_string(manifest_data, "format"), GFConfigPipelineArtifactManifest.FORMAT, "manifest 应包含稳定格式标识。")
	assert_false(GFVariantData.get_option_string(manifest_data, "input_digest").is_empty(), "manifest 应记录输入摘要。")


func test_pipeline_runner_rejects_manifest_path_inside_gf_source_by_default() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_reject_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_reject_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_reject_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = "res://addons/./gf/tools/config_pipeline/should_not_write_config_pipeline_test.manifest.json"
	_save_runner_profile(&"manifest_reject", csv_path, profile_path, output_path)

	var run_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, {
		"changed_only": true,
		"manifest_path": manifest_path,
	}])
	var manifest_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "manifest_result")

	assert_false(GFVariantData.get_option_bool(run_result, "success"), "manifest 路径写入 GF 源码目录时导出应失败。")
	assert_false(GFVariantData.get_option_bool(manifest_result, "success"), "manifest 保存结果应报告失败。")
	assert_eq(GFVariantData.get_option_int(manifest_result, "error_code"), ERR_INVALID_PARAMETER, "manifest 路径策略失败应报告参数错误。")
	assert_false(FileAccess.file_exists("res://addons/gf/tools/config_pipeline/should_not_write_config_pipeline_test.manifest.json"), "被路径策略拒绝的 manifest 不应落盘。")


func test_pipeline_runner_rejects_overwriting_unowned_manifest_before_commit() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_owner_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_owner_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_owner_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _write_text(
		"user://gf_config_pipeline_manifest_owner_%d.manifest.json" % Time.get_ticks_usec(),
		"{\"manual\":true}\n"
	)
	_save_runner_profile(&"manifest_owner", csv_path, profile_path, output_path)

	var run_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, {
		"changed_only": true,
		"manifest_path": manifest_path,
	}])
	var manifest_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "manifest_result")

	assert_false(GFVariantData.get_option_bool(run_result, "success"), "未拥有的 manifest 必须在提交任一产物前被拒绝。")
	assert_eq(GFVariantData.get_option_int(manifest_result, "error_code"), ERR_UNAUTHORIZED, "manifest ownership 失败应报告未授权。")
	assert_false(FileAccess.file_exists(output_path), "manifest ownership 预检失败不得留下数据库产物。")
	assert_eq(_read_text(manifest_path), "{\"manual\":true}\n", "拒绝覆盖时必须保留原 manifest。")


func test_pipeline_runner_rolls_back_all_outputs_when_manifest_commit_fails() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_tx_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_tx_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_tx_database_%d.json" % Time.get_ticks_usec())
	var access_path: String = _track_path("user://gf_config_pipeline_manifest_tx_access_%d.gd" % Time.get_ticks_usec())
	var blocking_parent: String = _write_text(
		"user://gf_config_pipeline_manifest_tx_parent_%d" % Time.get_ticks_usec(),
		"not a directory"
	)
	var manifest_path: String = blocking_parent.path_join("artifact.manifest.json")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"manifest_transaction"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.access_output_path = access_path
	profile.access_class_name = "ManifestTransactionAccess"
	profile.sources = [source]
	assert_eq(ResourceSaver.save(profile, profile_path), OK, "测试 Profile 应能保存为 .tres。")

	var run_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, {
		"write_manifest": true,
		"manifest_path": manifest_path,
	}])
	var manifest_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "manifest_result")

	assert_push_error("[GFConfigPipelineArtifactManifest] 无法写入文本产物临时文件")
	assert_false(GFVariantData.get_option_bool(run_result, "success"), "manifest commit 失败必须让同一 operation transaction 整体失败。")
	assert_false(GFVariantData.get_option_bool(manifest_result, "success"), "manifest_result 应保留最终写入失败。")
	assert_false(FileAccess.file_exists(output_path), "manifest commit 失败后必须回滚新数据库。")
	assert_false(FileAccess.file_exists(access_path), "manifest commit 失败后必须回滚新访问器。")
	assert_false(FileAccess.file_exists(manifest_path), "失败事务不得留下 manifest 半成品。")


func test_pipeline_runner_fails_freshness_before_hashing_over_budget_source() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_freshness_budget_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_freshness_budget_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_freshness_budget_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _track_path("user://gf_config_pipeline_freshness_budget_%d.manifest.json" % Time.get_ticks_usec())
	_save_runner_profile(&"freshness_budget", csv_path, profile_path, output_path)

	var run_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, {
		"changed_only": true,
		"manifest_path": manifest_path,
		"max_freshness_file_bytes": 8,
	}])
	var freshness_report: Dictionary = GFVariantData.get_option_dictionary(run_result, "freshness_report")
	var scan_report: Dictionary = GFVariantData.get_option_dictionary(freshness_report, "scan_report")

	assert_false(GFVariantData.get_option_bool(run_result, "success"), "freshness 单文件预算超限必须直接失败。")
	assert_eq(GFVariantData.get_option_string(scan_report, "error_code"), "freshness_file_budget_exceeded", "失败应暴露稳定预算错误码。")
	assert_eq(GFVariantData.get_option_int(scan_report, "hashed_bytes"), 0, "单文件预算应在进入哈希循环前拒绝。")
	assert_false(FileAccess.file_exists(output_path), "freshness 预算失败不得继续导出数据库。")
	assert_false(FileAccess.file_exists(manifest_path), "freshness 预算失败不得写入 manifest。")


func test_pipeline_runner_skips_changed_only_when_manifest_is_fresh() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_fresh_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_fresh_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_fresh_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _track_path("user://gf_config_pipeline_manifest_fresh_database_%d.manifest.json" % Time.get_ticks_usec())
	_save_runner_profile(&"manifest_fresh", csv_path, profile_path, output_path)
	var options: Dictionary = {
		"changed_only": true,
		"manifest_path": manifest_path,
	}
	var first_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, options])

	var second_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, options])
	var freshness_report: Dictionary = GFVariantData.get_option_dictionary(second_result, "freshness_report")

	assert_true(GFVariantData.get_option_bool(first_result, "success"), "首次导出应成功建立 manifest。")
	assert_true(GFVariantData.get_option_bool(second_result, "success"), "fresh manifest 命中时应返回成功。")
	assert_true(GFVariantData.get_option_bool(second_result, "skipped"), "fresh manifest 命中时应跳过导出。")
	assert_true(GFVariantData.get_option_bool(freshness_report, "fresh"), "freshness_report 应明确 fresh。")
	assert_eq(GFVariantData.get_option_string(second_result, "manifest_path"), manifest_path, "跳过结果应保留 manifest 路径。")


func test_pipeline_runner_rebuilds_changed_only_when_source_changes() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_changed_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_changed_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_changed_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _track_path("user://gf_config_pipeline_manifest_changed_database_%d.manifest.json" % Time.get_ticks_usec())
	_save_runner_profile(&"manifest_changed", csv_path, profile_path, output_path)
	var options: Dictionary = {
		"changed_only": true,
		"manifest_path": manifest_path,
	}
	var first_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, options])
	var changed_csv_path: String = _write_text(csv_path, "id,name,power\n1,Potion,4.0\n")

	var second_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, options])
	var freshness_report: Dictionary = GFVariantData.get_option_dictionary(second_result, "freshness_report")
	var reasons: Array = GFVariantData.get_option_array(freshness_report, "reasons")

	assert_eq(changed_csv_path, csv_path, "测试应覆盖同一个来源文件。")
	assert_true(GFVariantData.get_option_bool(first_result, "success"), "首次导出应成功建立 manifest。")
	assert_true(GFVariantData.get_option_bool(second_result, "success"), "来源变化后应重新导出成功。")
	assert_false(GFVariantData.get_option_bool(second_result, "skipped"), "来源变化后不应跳过导出。")
	assert_false(GFVariantData.get_option_bool(freshness_report, "fresh"), "来源变化后 freshness_report 应为 false。")
	assert_true(reasons.has("changed_input_digest"), "来源变化应由 input_digest 变化触发。")


func test_pipeline_runner_reports_missing_profile_path() -> void:
	var run_result: Dictionary = _call_runner(&"export_profile_path", [""])
	var report: Dictionary = GFVariantData.get_option_dictionary(run_result, "report")

	assert_false(GFVariantData.get_option_bool(run_result, "success"), "空 Profile 路径不应导出成功。")
	assert_eq(GFVariantData.get_option_string_name(run_result, "operation"), &"export", "Runner 失败结果也应保留目标操作。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "missing_profile_path"), "空 Profile 路径应返回明确问题类型。")


func test_pipeline_runner_rejects_plain_filesystem_profile_path() -> void:
	var resource_path: String = _write_text("user://gf_config_pipeline_plain_profile_path_%d.tres" % Time.get_ticks_usec(), "")
	var plain_path: String = ProjectSettings.globalize_path(resource_path)

	var run_result: Dictionary = _call_runner(&"build_profile_path", [plain_path])
	var report: Dictionary = GFVariantData.get_option_dictionary(run_result, "report")

	assert_false(GFVariantData.get_option_bool(run_result, "success"), "Runner 不应接受普通文件系统 Profile 路径。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "invalid_profile_path"), "普通文件系统路径应返回明确问题类型。")


func test_pipeline_runner_rejects_non_profile_resource() -> void:
	var profile_path: String = _track_path("user://gf_config_pipeline_runner_plain_%d.tres" % Time.get_ticks_usec())
	assert_eq(ResourceSaver.save(Resource.new(), profile_path), OK, "测试 Resource 应能保存为 .tres。")

	var run_result: Dictionary = _call_runner(&"build_profile_path", [profile_path])
	var report: Dictionary = GFVariantData.get_option_dictionary(run_result, "report")

	assert_false(GFVariantData.get_option_bool(run_result, "success"), "普通 Resource 不应被当作导表 Profile。")
	assert_eq(GFVariantData.get_option_string_name(run_result, "operation"), &"build", "Runner 应保留目标构建操作。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "invalid_pipeline_profile_resource"), "无 sources 字段的 Resource 应返回明确问题类型。")


func test_pipeline_command_exports_profile_dry_run_as_json_report() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_command_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_command_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_command_database_%d.tres" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"command"
	profile.database_id = &"main"
	profile.output_path = "user://unused_profile_output.tres"
	profile.sources = [source]
	assert_eq(ResourceSaver.save(profile, profile_path), OK, "测试 Profile 应能保存为 .tres。")

	var command_result: Dictionary = _call_command(PackedStringArray([
		"--profile",
		profile_path,
		"--operation",
		"export",
		"--output",
		output_path,
		"--dry-run",
		"--json",
		"--compact",
	]))
	var runner_result: Dictionary = GFVariantData.get_option_dictionary(command_result, "runner_result")
	var save_result: Dictionary = GFVariantData.get_option_dictionary(runner_result, "save_result")
	var command: GF_CONFIG_PIPELINE_COMMAND_SCRIPT = GF_CONFIG_PIPELINE_COMMAND_SCRIPT.new()
	var output_text: String = command.make_output_text(command_result, false)
	var parsed_output: Variant = JSON.parse_string(output_text)

	assert_true(GFVariantData.get_option_bool(command_result, "success"), "Command 应能调用 Runner 导出 Profile。")
	assert_eq(GFVariantData.get_option_int(command_result, "exit_code"), 0, "成功命令应返回 0 exit_code。")
	assert_true(GFVariantData.get_option_bool(command_result, "dry_run"), "命令报告应保留 dry_run 标记。")
	assert_true(GFVariantData.get_option_bool(save_result, "dry_run"), "dry-run 应传递给 Profile 导出。")
	assert_false(FileAccess.file_exists(output_path), "命令 dry-run 不应写入数据库资源。")
	assert_true(parsed_output is Dictionary, "JSON report 输出必须可解析为 Dictionary。")


func test_pipeline_command_reports_missing_profile_argument() -> void:
	var command_result: Dictionary = _call_command(PackedStringArray([
		"--operation",
		"export",
		"--json",
	]))
	var command: GF_CONFIG_PIPELINE_COMMAND_SCRIPT = GF_CONFIG_PIPELINE_COMMAND_SCRIPT.new()
	var output_text: String = command.make_output_text(command_result, false)
	var parsed_output: Variant = JSON.parse_string(output_text)

	assert_false(GFVariantData.get_option_bool(command_result, "success"), "缺少 --profile 时命令不应成功。")
	assert_eq(GFVariantData.get_option_int(command_result, "exit_code"), 2, "参数错误应返回 2 exit_code。")
	assert_true(GFVariantData.get_option_string(command_result, "error").contains("--profile"), "错误信息应指出缺少 --profile。")
	assert_true(parsed_output is Dictionary, "参数错误也应能输出 JSON report。")


func test_pipeline_database_validates_cross_table_references() -> void:
	var items_path: String = _write_text("user://gf_config_pipeline_ref_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var owners_path: String = _write_text("user://gf_config_pipeline_ref_owners_%d.csv" % Time.get_ticks_usec(), "id,item_id\n10,999\n")
	var item_source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	item_source.table_name = &"items"
	item_source.source_path = items_path
	item_source.schema = _make_item_schema()
	var owner_source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	owner_source.table_name = &"owners"
	owner_source.source_path = owners_path
	owner_source.schema = _make_owner_schema()

	var build_result: Dictionary = _call_pipeline(&"build_database", [[item_source, owner_source], { "database_id": &"main" }])
	var report: Dictionary = GFVariantData.get_option_dictionary(build_result, "report")

	assert_false(GFVariantData.get_option_bool(build_result, "success"), "缺失跨表引用目标时数据库构建应失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "missing_reference"), "数据库报告应包含跨表引用缺失问题。")


func test_pipeline_reports_unsupported_auto_format() -> void:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = "user://items.toml"
	source.source_format = GFConfigPipelineTableSource.FORMAT_AUTO

	var table_result: Dictionary = _call_pipeline(&"build_table_from_text", [source, "id = 1"])
	var report: Dictionary = GFVariantData.get_option_dictionary(table_result, "report")

	assert_false(GFVariantData.get_option_bool(table_result, "success"), "未知扩展名不应被自动解析。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "unsupported_source_format"), "错误报告应说明来源格式不支持。")


func test_pipeline_save_database_rejects_unsupported_output_format() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("unsupported_output")
	var output_path: String = _track_path("user://gf_config_pipeline_database_%d.gfconfig" % Time.get_ticks_usec())

	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path, {
		"output_format": &"xml",
	}])

	assert_false(GFVariantData.get_option_bool(save_result, "success"), "未知输出格式不应静默按 Resource 保存。")
	assert_eq(GFVariantData.get_option_string_name(save_result, "format"), &"xml", "失败结果应保留调用方请求的格式。")
	assert_true(GFVariantData.get_option_string(save_result, "error").contains("不支持的配置数据库输出格式"), "失败结果应说明输出格式不支持。")


func test_pipeline_runner_rejects_tampered_manifest_digest() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_manifest_tamper_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var profile_path: String = _track_path("user://gf_config_pipeline_manifest_tamper_profile_%d.tres" % Time.get_ticks_usec())
	var output_path: String = _track_path("user://gf_config_pipeline_manifest_tamper_database_%d.json" % Time.get_ticks_usec())
	var manifest_path: String = _track_path("user://gf_config_pipeline_manifest_tamper_database_%d.manifest.json" % Time.get_ticks_usec())
	_save_runner_profile(&"manifest_tamper", csv_path, profile_path, output_path)
	var options: Dictionary = {
		"changed_only": true,
		"manifest_path": manifest_path,
	}
	var first_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, options])
	var manifest: Dictionary = _load_json_dictionary(manifest_path)
	manifest["input_digest"] = "tampered"
	var tampered_path: String = _write_text(manifest_path, JSON.stringify(manifest, "\t", true))

	var second_result: Dictionary = _call_runner(&"export_profile_path", [profile_path, options])
	var freshness_report: Dictionary = GFVariantData.get_option_dictionary(second_result, "freshness_report")
	var load_result: Dictionary = GFVariantData.get_option_dictionary(freshness_report, "load_result")

	assert_true(GFVariantData.get_option_bool(first_result, "success"), "测试前置导出应成功。")
	assert_eq(tampered_path, manifest_path, "测试应篡改同一个 manifest。")
	assert_false(GFVariantData.get_option_bool(second_result, "skipped"), "digest 被篡改的 manifest 不得命中 fresh 跳过。")
	assert_false(GFVariantData.get_option_bool(load_result, "success"), "manifest digest 不匹配必须在 load 边界失败。")
	assert_true(GFVariantData.get_option_string(load_result, "error").contains("manifest_digest"), "失败报告应明确指出 manifest_digest 不匹配。")


func test_pipeline_rejects_overwriting_unowned_outputs_by_default() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("unowned_output")
	var json_path: String = _write_text("user://gf_config_pipeline_unowned_%d.json" % Time.get_ticks_usec(), "{\"manual\":true}\n")
	var access_path: String = _write_text("user://gf_config_pipeline_unowned_%d.gd" % Time.get_ticks_usec(), "# manual script\n")

	var save_result: Dictionary = _call_pipeline(&"save_database", [database, json_path])
	var access_result: Dictionary = _call_pipeline(&"generate_access", [database, access_path, "UnownedConfigAccess"])

	assert_false(GFVariantData.get_option_bool(save_result, "success"), "默认不得覆盖不属于 Config Pipeline 的数据库文件。")
	assert_false(GFVariantData.get_option_bool(access_result, "success"), "默认不得覆盖不属于 Config Pipeline 的访问器脚本。")
	assert_eq(_read_text(json_path), "{\"manual\":true}\n", "拒绝覆盖时必须保留原数据库文件。")
	assert_eq(_read_text(access_path), "# manual script\n", "拒绝覆盖时必须保留原访问器脚本。")


func test_pipeline_export_profile_rolls_back_database_when_access_commit_fails() -> void:
	var csv_path: String = _write_text("user://gf_config_pipeline_transaction_items_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var output_path: String = _track_path("user://gf_config_pipeline_transaction_database_%d.json" % Time.get_ticks_usec())
	var access_path: String = _track_path("user://gf_config_pipeline_transaction_access_%d.gd" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"transaction"
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.access_output_path = access_path
	profile.access_class_name = "TransactionConfigAccess"
	profile.sources = [source]
	var pipeline: _FailingAccessCommitPipeline = _FailingAccessCommitPipeline.new()

	var export_result: Dictionary = pipeline.export_profile(profile)

	assert_false(GFVariantData.get_option_bool(export_result, "success"), "任一产物 commit 失败时整体导出必须失败。")
	assert_false(FileAccess.file_exists(output_path), "access commit 失败后必须删除本次新建的数据库产物。")
	assert_false(FileAccess.file_exists(access_path), "失败的 access commit 不应留下半成品。")


func test_pipeline_json_export_rejects_non_finite_vector_components() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("non_finite_vector")
	database.metadata["position"] = Vector2(NAN, 1.0)
	var output_path: String = _track_path("user://gf_config_pipeline_non_finite_%d.json" % Time.get_ticks_usec())

	var save_result: Dictionary = _call_pipeline(&"save_database", [database, output_path])

	assert_false(GFVariantData.get_option_bool(save_result, "success"), "Vector/Color 分量包含非有限值时 JSON 导出必须 fail-closed。")
	assert_true(GFVariantData.get_option_string(save_result, "error").contains("NaN") or GFVariantData.get_option_string(save_result, "error").contains("Inf"), "失败报告应指出非有限数。")
	assert_false(FileAccess.file_exists(output_path), "非有限数据不得产生 JSON 产物。")


func test_pipeline_xlsx_rejects_missing_shared_string_index() -> void:
	var xlsx_path: String = _write_xlsx_with_invalid_shared_string("user://gf_config_pipeline_bad_shared_%d.xlsx" % Time.get_ticks_usec())
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = xlsx_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_XLSX

	var result: Dictionary = _call_pipeline(&"build_table", [source])

	assert_false(GFVariantData.get_option_bool(result, "success"), "缺失 sharedStrings 或越界索引不得静默转为空字符串。")
	assert_true(GFVariantData.get_option_string(result, "error").contains("shared string"), "XLSX 报告应定位 shared string 索引错误。")


func test_pipeline_command_rejects_next_option_as_missing_value() -> void:
	var command_result: Dictionary = _call_command(PackedStringArray(["--profile", "--json"]))

	assert_false(GFVariantData.get_option_bool(command_result, "success"), "需要值的 option 不得吞掉后续 option token。")
	assert_true(GFVariantData.get_option_string(command_result, "error").contains("--profile"), "错误应指向缺少值的 option。")


func test_pipeline_rejects_source_over_configured_byte_budget() -> void:
	var source_path: String = _write_text("user://gf_config_pipeline_source_budget_%d.csv" % Time.get_ticks_usec(), "id,name,power\n1,Potion,2.5\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = source_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema = _make_item_schema()

	var result: Dictionary = _call_pipeline(&"build_table", [source, { "max_source_file_bytes": 8 }])

	assert_false(GFVariantData.get_option_bool(result, "success"), "超过读取预算的文本来源必须在整体读取前拒绝。")
	assert_true(GFVariantData.get_option_string(result, "error").contains("max_source_file_bytes"), "预算失败报告应包含稳定 option 名。")


func test_pipeline_rejects_statement_shaped_provider_accessor() -> void:
	var database: GFConfigDatabaseResource = _build_items_database_from_csv("provider_accessor")
	var output_path: String = _track_path("user://gf_config_pipeline_accessor_%d.gd" % Time.get_ticks_usec())

	var result: Dictionary = _call_pipeline(&"generate_access", [
		database,
		output_path,
		"UnsafeConfigAccess",
		"null; push_error(\"unexpected\")",
	])

	assert_false(GFVariantData.get_option_bool(result, "success"), "provider_accessor 必须收束为单一受信任表达式，不能包含语句分隔符。")
	assert_eq(GFVariantData.get_option_int(result, "error_code"), ERR_INVALID_PARAMETER, "非法 accessor 应报告参数错误。")
	assert_false(FileAccess.file_exists(output_path), "非法 accessor 不得生成脚本。")


func test_pipeline_command_json_uses_report_codec_markers() -> void:
	var command: GF_CONFIG_PIPELINE_COMMAND_SCRIPT = GF_CONFIG_PIPELINE_COMMAND_SCRIPT.new()
	var output_text: String = command.make_output_text({
		"json_report": true,
		"not_a_number": NAN,
	}, false)
	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(output_text))
	var encoded_float: Dictionary = GFVariantData.get_option_dictionary(parsed, "not_a_number")
	var marker: Dictionary = GFVariantData.get_option_dictionary(encoded_float, "__gf_variant__")

	assert_eq(GFVariantData.get_option_string(marker, "type"), "Float", "命令报告必须复用 GFReportValueCodec 的 typed marker，不能把 NaN 降级为 null。")


# --- 私有/辅助方法 ---

func _build_items_database_from_csv(label: String) -> GFConfigDatabaseResource:
	var csv_path: String = _write_text("user://gf_config_pipeline_%s_items_%d.csv" % [label, Time.get_ticks_usec()], "id,name,power\n1,Potion,2.5\n2,Ether,3\n")
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.source_format = GFConfigPipelineTableSource.FORMAT_CSV
	source.schema = _make_item_schema()
	var build_result: Dictionary = _call_pipeline(&"build_database", [[source], {
		"database_id": &"main",
		"version": "test",
	}])
	return _get_database_from_result(build_result)


func _make_item_schema() -> GFConfigTableSchema:
	var id_column: GFConfigTableColumn = _make_column(&"id", GFConfigTableColumn.ValueType.INT)
	var name_column: GFConfigTableColumn = _make_column(&"name", GFConfigTableColumn.ValueType.STRING)
	var power_column: GFConfigTableColumn = _make_column(&"power", GFConfigTableColumn.ValueType.FLOAT)

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	schema.id_field = &"id"
	schema.require_unique_id = true
	schema.coerce_values = true
	schema.columns = [id_column, name_column, power_column]
	return schema


func _make_owner_schema() -> GFConfigTableSchema:
	var id_column: GFConfigTableColumn = _make_column(&"id", GFConfigTableColumn.ValueType.INT)
	var item_id_column: GFConfigTableColumn = _make_column(&"item_id", GFConfigTableColumn.ValueType.INT)
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.reference_id = &"owner_item"
	reference.source_fields = PackedStringArray(["item_id"])
	reference.target_table_name = &"items"
	reference.target_fields = PackedStringArray(["id"])
	reference.required = true

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"owners"
	schema.id_field = &"id"
	schema.require_unique_id = true
	schema.coerce_values = true
	schema.columns = [id_column, item_id_column]
	schema.references.append(reference)
	return schema


func _save_runner_profile(profile_id: StringName, csv_path: String, profile_path: String, output_path: String) -> void:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = csv_path
	source.schema = _make_item_schema()

	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = profile_id
	profile.database_id = &"main"
	profile.output_path = output_path
	profile.sources = [source]
	assert_eq(ResourceSaver.save(profile, profile_path), OK, "测试 Profile 应能保存为 .tres。")


func _make_column(field_name: StringName, value_type: GFConfigTableColumn.ValueType) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = value_type
	column.required = true
	column.allow_null = false
	return column


func _write_text(path: String, text: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入临时配置源。")
	var _store_string_result: bool = file.store_string(text)
	_temporary_paths.append(path)
	return path


func _write_xlsx(path: String, sheet_name: String, rows: Array[PackedStringArray]) -> String:
	var packer: ZIPPacker = ZIPPacker.new()
	var open_result: Error = packer.open(path)
	assert_eq(open_result, OK, "测试应能创建 xlsx zip。")
	_zip_pack_text(packer, "[Content_Types].xml", _xlsx_content_types_xml())
	_zip_pack_text(packer, "_rels/.rels", _xlsx_root_relationships_xml())
	_zip_pack_text(packer, "xl/workbook.xml", _xlsx_workbook_xml(sheet_name))
	_zip_pack_text(packer, "xl/_rels/workbook.xml.rels", _xlsx_workbook_relationships_xml())
	_zip_pack_text(packer, "xl/worksheets/sheet1.xml", _xlsx_sheet_xml(rows))
	var close_result: Error = packer.close()
	assert_eq(close_result, OK, "测试应能关闭 xlsx zip。")
	_temporary_paths.append(path)
	return path


func _write_xlsx_with_invalid_shared_string(path: String) -> String:
	var packer: ZIPPacker = ZIPPacker.new()
	assert_eq(packer.open(path), OK, "测试应能创建损坏 shared string 的 xlsx zip。")
	_zip_pack_text(packer, "[Content_Types].xml", _xlsx_content_types_xml())
	_zip_pack_text(packer, "_rels/.rels", _xlsx_root_relationships_xml())
	_zip_pack_text(packer, "xl/workbook.xml", _xlsx_workbook_xml("items"))
	_zip_pack_text(packer, "xl/_rels/workbook.xml.rels", _xlsx_workbook_relationships_xml())
	_zip_pack_text(
		packer,
		"xl/worksheets/sheet1.xml",
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>1</v></c></row></sheetData></worksheet>"
	)
	assert_eq(packer.close(), OK, "测试应能关闭损坏 shared string 的 xlsx zip。")
	_temporary_paths.append(path)
	return path


func _zip_pack_text(packer: ZIPPacker, path: String, text: String) -> void:
	var start_result: Error = packer.start_file(path)
	assert_eq(start_result, OK, "测试应能写入 xlsx 条目。")
	var write_result: Error = packer.write_file(text.to_utf8_buffer())
	assert_eq(write_result, OK, "测试应能写入 xlsx 条目内容。")
	var close_file_result: Error = packer.close_file()
	assert_eq(close_file_result, OK, "测试应能关闭 xlsx 条目。")


func _xlsx_content_types_xml() -> String:
	return (
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
		+ "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
		+ "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
		+ "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
		+ "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
		+ "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
		+ "</Types>"
	)


func _xlsx_root_relationships_xml() -> String:
	return (
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
		+ "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
		+ "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>"
		+ "</Relationships>"
	)


func _xlsx_workbook_xml(sheet_name: String) -> String:
	return (
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
		+ "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
		+ "<sheets><sheet name=\"%s\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" % _xml_escape(sheet_name)
		+ "</workbook>"
	)


func _xlsx_workbook_relationships_xml() -> String:
	return (
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
		+ "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
		+ "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>"
		+ "</Relationships>"
	)


func _xlsx_sheet_xml(rows: Array[PackedStringArray]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var _header_appended: bool = lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	var _worksheet_appended: bool = lines.append("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>")
	for row_index: int in range(rows.size()):
		var row: PackedStringArray = rows[row_index]
		var row_number: int = row_index + 1
		var _row_start_appended: bool = lines.append("<row r=\"%d\">" % row_number)
		for column_index: int in range(row.size()):
			var cell_ref: String = "%s%d" % [_xlsx_column_name(column_index), row_number]
			var cell_text: String = _xml_escape(row[column_index])
			var _cell_appended: bool = lines.append("<c r=\"%s\" t=\"inlineStr\"><is><t>%s</t></is></c>" % [cell_ref, cell_text])
		var _row_end_appended: bool = lines.append("</row>")
	var _worksheet_end_appended: bool = lines.append("</sheetData></worksheet>")
	return "".join(lines)


func _xlsx_column_name(column_index: int) -> String:
	var value: int = column_index + 1
	var result: String = ""
	while value > 0:
		var remainder: int = (value - 1) % 26
		result = char(65 + remainder) + result
		value = floori(float(value - 1) / 26.0)
	return result


func _xml_escape(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")


func _get_database_from_result(result: Dictionary) -> GFConfigDatabaseResource:
	var database_value: Variant = GFVariantData.get_option_value(result, "database")
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		return database
	return null


func _get_table_from_result(result: Dictionary) -> GFConfigTableResource:
	var table_value: Variant = GFVariantData.get_option_value(result, "table")
	if table_value is GFConfigTableResource:
		var table: GFConfigTableResource = table_value
		return table
	return null


func _load_database_resource(path: String) -> GFConfigDatabaseResource:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = resource
		return database
	return null


func _load_json_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 JSON 导出文件。")
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取文本文件。")
	if file == null:
		return ""
	return file.get_as_text()


func _call_pipeline(method_name: StringName, arguments: Array) -> Dictionary:
	var pipeline: Object = GFConfigPipeline.new()
	assert_not_null(pipeline, "测试应能实例化 GFConfigPipeline。")
	var result: Variant = pipeline.callv(method_name, arguments)
	if result is Dictionary:
		var data: Dictionary = result
		return data
	return {}


func _call_runner(method_name: StringName, arguments: Array) -> Dictionary:
	var runner: Object = GFConfigPipelineRunner.new()
	assert_not_null(runner, "测试应能实例化 GFConfigPipelineRunner。")
	var result: Variant = runner.callv(method_name, arguments)
	if result is Dictionary:
		var data: Dictionary = result
		return data
	return {}


func _call_command(arguments: PackedStringArray) -> Dictionary:
	var command: GF_CONFIG_PIPELINE_COMMAND_SCRIPT = GF_CONFIG_PIPELINE_COMMAND_SCRIPT.new()
	return command.run(arguments)


func _track_path(path: String) -> String:
	_temporary_paths.append(path)
	return path


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			if GFVariantData.get_option_string(issue, "kind") == kind:
				return true
	return false


# --- 内部类 ---

class _FailingAccessCommitPipeline extends GFConfigPipeline:
	func generate_access(
		database: GFConfigDatabaseResource,
		output_path: String,
		access_class_name: String = "GFConfigAccess",
		provider_accessor: String = "null",
		options: Dictionary = {}
	) -> Dictionary:
		if GFVariantData.get_option_bool(options, "dry_run"):
			return super.generate_access(database, output_path, access_class_name, provider_accessor, options)
		return {
			"success": false,
			"path": output_path,
			"class_name": access_class_name,
			"error_code": ERR_CANT_CREATE,
			"error": "injected access commit failure",
		}
