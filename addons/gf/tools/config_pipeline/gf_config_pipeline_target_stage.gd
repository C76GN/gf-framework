## GFConfigPipelineTargetStage: Config Pipeline 的内置目标物化阶段。
##
## 只接受版本化 IR，并将其物化为 GFConfigTableResource、GFConfigDatabaseResource 或 JSON 兼容数据。
## Target 不读取来源，也不重新推导 schema 或解释项目业务语义。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineTargetStage
extends RefCounted


# --- 常量 ---

## Target 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.target.godot_resource"

## Target 阶段的实现版本；改变 Resource 或 JSON 物化语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 1

const _JSON_EXPORT_FORMAT: String = "gf.config.database"
const _JSON_EXPORT_VERSION: int = 1
const _ARTIFACT_OWNER: String = "gf.tool.config_pipeline"
const _JSON_VARIANT_TYPE_KEY: String = "__gf_variant_type"
const _JSON_VARIANT_VALUE_KEY: String = "value"
const _DEFAULT_JSON_INDENT: String = "\t"


# --- 公共方法 ---

## 将单表 IR 物化为 Godot Resource。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param table_ir: 已通过 Validation 的版本化单表 IR。
## [br]
## @param options: 目标选项。
## [br]
## @schema options: Dictionary，可包含 rebuild_indexes。
## [br]
## @return: 单表物化结果。
## [br]
## @schema return: Dictionary，包含 success、phase、table、ir、error_kind 和 error。
func materialize_table(
	table_ir: GFConfigPipelineTableIR,
	options: Dictionary = {}
) -> Dictionary:
	if table_ir == null:
		return _make_table_failure("invalid_table_ir", "待物化的 Table IR 为空。")
	var contract: Dictionary = table_ir.validate_contract()
	if not GFVariantData.get_option_bool(contract, "success"):
		return _make_table_failure("invalid_table_ir", GFVariantData.get_option_string(contract, "error"))

	var table: GFConfigTableResource = GFConfigTableResource.new()
	table.table_name = table_ir.get_table_name()
	table.schema = table_ir.get_schema()
	table.records = table_ir.get_records()
	table.metadata = table_ir.get_metadata()
	if GFVariantData.get_option_bool(options, "rebuild_indexes", true):
		var _id_index_count: int = table.rebuild_index()
		var _named_index_count: int = table.rebuild_indexes()
	return {
		"success": true,
		"phase": "target",
		"table": table,
		"ir": table_ir,
		"error_kind": "",
		"error": "",
	}


## 将数据库 IR 物化为 Godot Resource，并可执行数据库级引用校验。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param compilation_ir: 已完成单表校验的版本化数据库 IR。
## [br]
## @param options: 目标选项。
## [br]
## @schema options: Dictionary，可包含 rebuild_indexes、validate_database 和 validate_schema。
## [br]
## @return: 数据库物化结果。
## [br]
## @schema return: Dictionary，包含 success、phase、database、report、ir、error_kind 和 error。
func materialize_database(
	compilation_ir: GFConfigPipelineIR,
	options: Dictionary = {}
) -> Dictionary:
	if compilation_ir == null:
		return _make_database_failure("invalid_pipeline_ir", "待物化的数据库 IR 为空。")
	var contract: Dictionary = compilation_ir.validate_contract()
	if not GFVariantData.get_option_bool(contract, "success"):
		return _make_database_failure("invalid_pipeline_ir", GFVariantData.get_option_string(contract, "error"), compilation_ir)

	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	database.database_id = compilation_ir.get_database_id()
	database.version = compilation_ir.get_version()
	database.metadata = compilation_ir.get_metadata()
	for table_ir: GFConfigPipelineTableIR in compilation_ir.get_tables():
		var table_result: Dictionary = materialize_table(table_ir, options)
		if not GFVariantData.get_option_bool(table_result, "success"):
			return _make_database_failure(
				GFVariantData.get_option_string(table_result, "error_kind", "table_target_failed"),
				GFVariantData.get_option_string(table_result, "error"),
				compilation_ir,
				database
			)
		var table_value: Variant = GFVariantData.get_option_value(table_result, "table")
		if not (table_value is GFConfigTableResource):
			return _make_database_failure("invalid_table_target", "Target 没有返回 GFConfigTableResource。", compilation_ir, database)
		var table: GFConfigTableResource = table_value
		if not database.register_table(table):
			return _make_database_failure(
				"table_registration_failed",
				"无法注册配置表：%s。" % String(table.get_table_key()),
				compilation_ir,
				database
			)

	var report: Dictionary = GFConfigValidationReport.new().make_report(database.database_id)
	if GFVariantData.get_option_bool(options, "validate_database", true):
		report = database.validate_database({
			"validate_schema": GFVariantData.get_option_bool(options, "validate_schema", false),
		})
	else:
		GFConfigValidationReport.new().finalize_report(report)
	var success: bool = GFVariantData.get_option_bool(report, "ok", true)
	return {
		"success": success,
		"phase": "target",
		"database": database,
		"report": report,
		"ir": compilation_ir,
		"error_kind": "" if success else "database_validation_failed",
		"error": "" if success else "配置数据库目标校验失败。",
	}


## 把数据库 Resource 转换为稳定、JSON 兼容的导出数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param database: 待导出的数据库资源。
## [br]
## @param options: JSON 目标选项。
## [br]
## @schema options: Dictionary，可包含 include_schema、include_indexes 和 max_depth。
## [br]
## @return: JSON 兼容导出结果。
## [br]
## @schema return: Dictionary，包含 success、data 和 error。
func make_database_export(
	database: GFConfigDatabaseResource,
	options: Dictionary = {}
) -> Dictionary:
	if database == null:
		return _make_export_failure("配置数据库资源为空。")

	var state: Dictionary = _make_json_state(options)
	var tables: Array[Dictionary] = []
	var table_ids: PackedStringArray = database.get_table_ids()
	for table_id: String in table_ids:
		var table_resource: GFConfigTableResource = database.get_table_resource(StringName(table_id), false)
		if table_resource == null:
			continue
		var table_data: Dictionary = _make_table_export(table_resource, state, options)
		if not GFVariantData.get_option_bool(state, "success", true):
			return _make_export_failure(GFVariantData.get_option_string(state, "error"))
		tables.append(table_data)

	var export_data: Dictionary = {
		"format": _JSON_EXPORT_FORMAT,
		"format_version": _JSON_EXPORT_VERSION,
		"artifact_owner": _ARTIFACT_OWNER,
		"database_id": String(database.database_id),
		"version": database.version,
		"metadata": _to_json_compatible(database.metadata, state, 0),
		"tables": tables,
	}
	if not GFVariantData.get_option_bool(state, "success", true):
		return _make_export_failure(GFVariantData.get_option_string(state, "error"))
	return {
		"success": true,
		"data": export_data,
		"error": "",
	}


## 把数据库 Resource 序列化为稳定 JSON 文本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param database: 待导出的数据库资源。
## [br]
## @param options: JSON 目标选项。
## [br]
## @schema options: Dictionary，可包含 include_schema、include_indexes、max_depth、indent 和 sort_keys。
## [br]
## @return: JSON 目标结果。
## [br]
## @schema return: Dictionary，包含 success、data、text 和 error。
func make_database_json(
	database: GFConfigDatabaseResource,
	options: Dictionary = {}
) -> Dictionary:
	var export_result: Dictionary = make_database_export(database, options)
	if not GFVariantData.get_option_bool(export_result, "success"):
		return {
			"success": false,
			"data": {},
			"text": "",
			"error": GFVariantData.get_option_string(export_result, "error"),
		}
	var export_data: Dictionary = GFVariantData.get_option_dictionary(export_result, "data")
	return {
		"success": true,
		"data": export_data,
		"text": JSON.stringify(
			export_data,
			GFVariantData.get_option_string(options, "indent", _DEFAULT_JSON_INDENT),
			GFVariantData.get_option_bool(options, "sort_keys", true)
		),
		"error": "",
	}


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、input_contracts 和 output_contracts。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"input_contracts": [
			"%s@%d" % [GFConfigPipelineTableIR.FORMAT, GFConfigPipelineTableIR.FORMAT_VERSION],
			"%s@%d" % [GFConfigPipelineIR.FORMAT, GFConfigPipelineIR.FORMAT_VERSION],
			"GFConfigDatabaseResource",
		],
		"output_contracts": ["GFConfigTableResource", "GFConfigDatabaseResource", "gf.config.database@1", "String"],
	}


# --- 私有/辅助方法 ---

func _make_table_export(
	table_resource: GFConfigTableResource,
	state: Dictionary,
	options: Dictionary
) -> Dictionary:
	var include_schema: bool = GFVariantData.get_option_bool(options, "include_schema", true)
	var include_indexes: bool = GFVariantData.get_option_bool(options, "include_indexes", false)
	var result: Dictionary = {
		"table_name": String(table_resource.get_table_key()),
		"metadata": _to_json_compatible(table_resource.metadata, state, 0),
		"records": _to_json_compatible(table_resource.records, state, 0),
	}
	if include_schema and table_resource.schema != null:
		result["schema"] = _to_json_compatible(table_resource.schema.describe(), state, 0)
	if include_indexes:
		result["records_by_id"] = _to_json_compatible(table_resource.records_by_id, state, 0)
		result["records_by_index"] = _to_json_compatible(table_resource.records_by_index, state, 0)
	return result


func _make_table_failure(error_kind: String, message: String) -> Dictionary:
	return {
		"success": false,
		"phase": "target",
		"table": null,
		"ir": null,
		"error_kind": error_kind,
		"error": message,
	}


func _make_database_failure(
	error_kind: String,
	message: String,
	compilation_ir: GFConfigPipelineIR = null,
	database: GFConfigDatabaseResource = null
) -> Dictionary:
	return {
		"success": false,
		"phase": "target",
		"database": database,
		"report": GFConfigValidationReport.new().make_error_report(&"", error_kind, message),
		"ir": compilation_ir,
		"error_kind": error_kind,
		"error": message,
	}


func _make_export_failure(message: String) -> Dictionary:
	return {
		"success": false,
		"data": {},
		"error": message,
	}


func _make_json_state(options: Dictionary) -> Dictionary:
	return {
		"success": true,
		"error": "",
		"max_depth": maxi(GFVariantData.get_option_int(options, "max_depth", 256), 1),
	}


func _to_json_compatible(value: Variant, state: Dictionary, depth: int) -> Variant:
	if not GFVariantData.get_option_bool(state, "success", true):
		return null
	if depth > GFVariantData.get_option_int(state, "max_depth", 256):
		return _fail_json_export(state, "配置数据库 JSON 导出结构超过 max_depth。")

	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			var bool_value: bool = value
			return bool_value
		TYPE_INT:
			var int_value: int = value
			return int_value
		TYPE_FLOAT:
			var float_value: float = value
			if is_nan(float_value) or is_inf(float_value):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持 NaN 或 Inf。")
			return float_value
		TYPE_STRING:
			var string_value: String = value
			return string_value
		TYPE_STRING_NAME:
			var string_name_value: StringName = value
			return String(string_name_value)
		TYPE_NODE_PATH:
			var node_path_value: NodePath = value
			return String(node_path_value)
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			if not _are_finite_floats([vector_2.x, vector_2.y]):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持包含 NaN 或 Inf 的 Vector2。")
			return _make_json_variant("Vector2", [vector_2.x, vector_2.y])
		TYPE_VECTOR2I:
			var vector_2i: Vector2i = value
			return _make_json_variant("Vector2i", [vector_2i.x, vector_2i.y])
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			if not _are_finite_floats([vector_3.x, vector_3.y, vector_3.z]):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持包含 NaN 或 Inf 的 Vector3。")
			return _make_json_variant("Vector3", [vector_3.x, vector_3.y, vector_3.z])
		TYPE_VECTOR3I:
			var vector_3i: Vector3i = value
			return _make_json_variant("Vector3i", [vector_3i.x, vector_3i.y, vector_3i.z])
		TYPE_COLOR:
			var color_value: Color = value
			if not _are_finite_floats([color_value.r, color_value.g, color_value.b, color_value.a]):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持包含 NaN 或 Inf 的 Color。")
			return _make_json_variant("Color", [color_value.r, color_value.g, color_value.b, color_value.a])
		TYPE_ARRAY:
			return _array_to_json_compatible(value, state, depth)
		TYPE_DICTIONARY:
			return _dictionary_to_json_compatible(value, state, depth)
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return _packed_string_array_to_json(packed_strings)
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return _packed_int32_array_to_json(packed_int32)
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return _packed_int64_array_to_json(packed_int64)
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			return _packed_float32_array_to_json(packed_float32, state)
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			return _packed_float64_array_to_json(packed_float64, state)

	return _fail_json_export(state, "配置数据库 JSON 导出不支持 Variant 类型：%s。" % type_string(typeof(value)))


func _array_to_json_compatible(value: Variant, state: Dictionary, depth: int) -> Array:
	var source: Array = GFVariantData.as_array(value)
	var result: Array = []
	for item: Variant in source:
		result.append(_to_json_compatible(item, state, depth + 1))
		if not GFVariantData.get_option_bool(state, "success", true):
			return []
	return result


func _dictionary_to_json_compatible(value: Variant, state: Dictionary, depth: int) -> Dictionary:
	var source: Dictionary = GFVariantData.as_dictionary(value)
	var result: Dictionary = {}
	for key: Variant in source.keys():
		var key_text: String = _json_key_to_text(key, state)
		if not GFVariantData.get_option_bool(state, "success", true):
			return {}
		if result.has(key_text):
			var _failed_duplicate_key: Variant = _fail_json_export(state, "配置数据库 JSON 导出遇到重复 JSON key：%s。" % key_text)
			return {}
		result[key_text] = _to_json_compatible(source[key], state, depth + 1)
		if not GFVariantData.get_option_bool(state, "success", true):
			return {}
	return result


func _json_key_to_text(key: Variant, state: Dictionary) -> String:
	match typeof(key):
		TYPE_STRING:
			var string_key: String = key
			return string_key
		TYPE_STRING_NAME:
			var string_name_key: StringName = key
			return String(string_name_key)
		TYPE_INT:
			var int_key: int = key
			return str(int_key)
	var _failed_key_type: Variant = _fail_json_export(state, "配置数据库 JSON 导出不支持 Dictionary key 类型：%s。" % type_string(typeof(key)))
	return ""


func _packed_string_array_to_json(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result


func _packed_int32_array_to_json(values: PackedInt32Array) -> Array:
	var result: Array = []
	for value: int in values:
		result.append(value)
	return result


func _packed_int64_array_to_json(values: PackedInt64Array) -> Array:
	var result: Array = []
	for value: int in values:
		result.append(value)
	return result


func _packed_float32_array_to_json(values: PackedFloat32Array, state: Dictionary) -> Array:
	var result: Array = []
	for value: float in values:
		if is_nan(value) or is_inf(value):
			var _failed_non_finite: Variant = _fail_json_export(state, "配置数据库 JSON 导出不支持 NaN 或 Inf。")
			return []
		result.append(value)
	return result


func _packed_float64_array_to_json(values: PackedFloat64Array, state: Dictionary) -> Array:
	var result: Array = []
	for value: float in values:
		if is_nan(value) or is_inf(value):
			var _failed_non_finite: Variant = _fail_json_export(state, "配置数据库 JSON 导出不支持 NaN 或 Inf。")
			return []
		result.append(value)
	return result


func _make_json_variant(type_name: String, variant_value: Variant) -> Dictionary:
	return {
		_JSON_VARIANT_TYPE_KEY: type_name,
		_JSON_VARIANT_VALUE_KEY: variant_value,
	}


func _are_finite_floats(values: Array) -> bool:
	for value: Variant in values:
		if not (value is float):
			continue
		var float_value: float = value
		if is_nan(float_value) or is_inf(float_value):
			return false
	return true


func _fail_json_export(state: Dictionary, message: String) -> Variant:
	if GFVariantData.get_option_bool(state, "success", true):
		state["success"] = false
		state["error"] = message
	return null
