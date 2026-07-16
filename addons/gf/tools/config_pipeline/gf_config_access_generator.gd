@tool

## GFConfigAccessGenerator: 生成静态导表访问器脚本。
##
## 默认生成结果只封装 provider 的 `get_record()` / `get_table()` 调用，
## 也可按 schema 字段声明生成可选记录包装类；生成器本身不规定项目表结构语义。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 3.17.0
## [br]
class_name GFConfigAccessGenerator
extends RefCounted


# --- 常量 ---

## 默认生成输出路径。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_OUTPUT_PATH: String = "res://gf/generated/gf_config_access.gd"

## 默认生成 class_name。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_CLASS_NAME: String = "GFConfigAccess"

## 默认 provider 获取表达式。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_PROVIDER_ACCESSOR: String = "null"
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")
const _RECORD_ACCESS_BASE_CLASS_NAME: String = "GFConfigRecordAccessBase"
const _VALUE_TYPE_ANY: String = "any"
const _VALUE_TYPE_BOOL: String = "bool"
const _VALUE_TYPE_INT: String = "int"
const _VALUE_TYPE_FLOAT: String = "float"
const _VALUE_TYPE_STRING: String = "string"
const _VALUE_TYPE_STRING_NAME: String = "string_name"
const _VALUE_TYPE_VECTOR2: String = "vector2"
const _VALUE_TYPE_VECTOR2I: String = "vector2i"
const _VALUE_TYPE_COLOR: String = "color"
const _VALUE_TYPE_DICTIONARY: String = "dictionary"
const _VALUE_TYPE_ARRAY: String = "array"


# --- 公共方法 ---

## 根据 schema 列表生成访问器并写入文件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param schemas: 带有 `table_name` 或 `table_key` 属性的 schema 列表。
## [br]
## @schema schemas: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @param access_class_name: 生成脚本的 class_name。
## [br]
## @param provider_accessor: 无显式 provider 参数时用于获取 provider 的表达式。
## [br]
## @param options: 可选生成选项，支持 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix。
## [br]
## @schema options: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.
## [br]
## @return 写入结果错误码。
func generate(
	schemas: Array,
	output_path: String = DEFAULT_OUTPUT_PATH,
	overwrite_existing: bool = true,
	access_class_name: String = DEFAULT_CLASS_NAME,
	provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR,
	options: Dictionary = {}
) -> Error:
	var report: Dictionary = generate_with_report(
		schemas,
		output_path,
		access_class_name,
		provider_accessor,
		_merge_generation_save_options(options, overwrite_existing)
	)
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 根据 schema 列表生成访问器并返回生成产物报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param schemas: 带有 `table_name` 或 `table_key` 属性的 schema 列表。
## [br]
## @schema schemas: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param access_class_name: 生成脚本的 class_name。
## [br]
## @param provider_accessor: 无显式 provider 参数时用于获取 provider 的表达式。
## [br]
## @param options: 可选生成与保存选项，支持 build_source 选项、overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix、overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func generate_with_report(
	schemas: Array,
	output_path: String = DEFAULT_OUTPUT_PATH,
	access_class_name: String = DEFAULT_CLASS_NAME,
	provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR,
	options: Dictionary = {}
) -> Dictionary:
	return save_source_with_report(output_path, build_source(schemas, access_class_name, provider_accessor, options), options)


## 根据 schema 列表生成访问器源码。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param schemas: 带有 `table_name` 或 `table_key` 属性的 schema 列表。
## [br]
## @schema schemas: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
## [br]
## @param access_class_name: 生成脚本的 class_name。
## [br]
## @param provider_accessor: 无显式 provider 参数时用于获取 provider 的表达式。
## [br]
## @param options: 可选生成选项。
## [br]
## @schema options: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.
## [br]
## @return GDScript 源码。
func build_source(
	schemas: Array,
	access_class_name: String = DEFAULT_CLASS_NAME,
	provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR,
	options: Dictionary = {}
) -> String:
	var generation_options: Dictionary = _normalize_generation_options(options)
	var records: Array[Dictionary] = _collect_schema_records(schemas, generation_options)
	var safe_access_class_name: String = _sanitize_class_name(access_class_name, DEFAULT_CLASS_NAME)
	var builder: GFSourceBuilder = GFSourceBuilder.new()
	builder.doc("%s: 自动生成的静态导表访问器。" % safe_access_class_name)
	builder.doc()
	builder.doc("该文件由 GFConfigAccessGenerator 生成，可以提交到版本库；请不要手动编辑。")
	builder.line("class_name %s" % safe_access_class_name)
	builder.line("extends RefCounted")
	builder.blank(2)
	builder.section("常量")
	for record: Dictionary in records:
		builder.line("const %s: StringName = &\"%s\"" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "constant_name"),
			_escape_string(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "table_name")),
		])

	builder.blank(2)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(generation_options, "include_typed_records", false):
		_append_typed_record_classes(builder, records)
		builder.blank()
	builder.section("公共方法")
	var used_methods: Dictionary = {}
	for record: Dictionary in records:
		_append_table_accessors(builder, record, used_methods, generation_options)

	builder.blank()
	builder.section("私有/辅助方法")
	builder.line("static func _provider_or_null(provider: Variant = null) -> Variant:")
	builder.indent()
	builder.line("if provider != null:")
	builder.indent()
	builder.line("return provider")
	builder.dedent()
	builder.line("return %s" % provider_accessor)
	builder.dedent()
	builder.blank(2)
	builder.line("static func _get_provider_record(provider: Variant, table_name: StringName, id: Variant) -> Variant:")
	builder.indent()
	builder.line("var resolved_provider: Variant = _provider_or_null(provider)")
	builder.line("if not (resolved_provider is Object):")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("var provider_object: Object = resolved_provider")
	builder.line("if not provider_object.has_method(\"get_record\"):")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("return provider_object.call(\"get_record\", table_name, id)")
	builder.dedent()
	builder.blank(2)
	builder.line("static func _get_provider_table(provider: Variant, table_name: StringName) -> Variant:")
	builder.indent()
	builder.line("var resolved_provider: Variant = _provider_or_null(provider)")
	builder.line("if not (resolved_provider is Object):")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("var provider_object: Object = resolved_provider")
	builder.line("if not provider_object.has_method(\"get_table\"):")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("return provider_object.call(\"get_table\", table_name)")
	builder.dedent()
	return builder.build()


## 保存生成源码到指定路径。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param source: GDScript 源码。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @return 写入结果错误码。
func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:
	var report: Dictionary = save_source_with_report(output_path, source, {
		"overwrite_existing": overwrite_existing,
	})
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 保存生成源码到指定路径并返回生成产物报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param source: GDScript 源码。
## [br]
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:
	var save_options: Dictionary = options.duplicate(true)
	save_options["label"] = "GFConfigAccessGenerator"
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(output_path, source, save_options)


# --- 私有/辅助方法 ---

func _merge_generation_save_options(options: Dictionary, overwrite_existing: bool) -> Dictionary:
	var save_options: Dictionary = options.duplicate(true)
	save_options["overwrite_existing"] = overwrite_existing
	return save_options


func _collect_schema_records(schemas: Array, options: Dictionary) -> Array[Dictionary]:
	var raw_records: Array[Dictionary] = []
	for schema_variant: Variant in schemas:
		var table_name: String = _get_schema_table_name(schema_variant)
		if table_name.is_empty():
			continue

		var table_identifier: String = _sanitize_identifier(table_name)
		if table_identifier.is_empty():
			push_warning("[GFConfigAccessGenerator] 表名无法生成有效访问器，已跳过：%s" % table_name)
			continue

		var metadata: Dictionary = _get_schema_metadata(schema_variant)
		raw_records.append({
			"table_name": table_name,
			"table_identifier": table_identifier,
			"columns": _collect_column_records(schema_variant),
			"comment": _get_schema_comment(metadata),
		})

	raw_records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "table_name") < _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "table_name")
	)

	var records: Array[Dictionary] = []
	var used_constant_names: Dictionary = {}
	var used_record_class_names: Dictionary = {
		_RECORD_ACCESS_BASE_CLASS_NAME: true,
	}
	for raw_record: Dictionary in raw_records:
		var record_identifier: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "table_identifier")
		var class_suffix: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "typed_record_class_suffix", "Record")
		var method_prefix: String = _format_identifier(record_identifier, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "method_name_style", "snake"))
		var constant_name: String = _make_unique_name(
			"%s%s" % [_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "constant_prefix"), _to_constant_name(record_identifier)],
			used_constant_names
		)
		var record_class_name: String = _make_unique_name(
			_sanitize_class_name("%s%s" % [_to_pascal_case(record_identifier), class_suffix], "ConfigRecord"),
			used_record_class_names
		)
		records.append({
			"table_name": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "table_name"),
			"method_prefix": method_prefix,
			"constant_name": constant_name,
			"typed_record_class_name": record_class_name,
			"columns": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(raw_record, "columns"),
			"comment": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "comment"),
		})
	return records


func _append_table_accessors(
	builder: GFSourceBuilder,
	record: Dictionary,
	used_methods: Dictionary,
	options: Dictionary
) -> void:
	var method_prefix: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "method_prefix")
	var constant_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "constant_name")
	var record_method: String = _make_unique_name(
		_format_method_pattern(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "record_method_pattern", "get_{table}_record"), method_prefix),
		used_methods
	)
	var table_method: String = _make_unique_name(
		_format_method_pattern(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "table_method_pattern", "get_{table}_table"), method_prefix),
		used_methods
	)
	var include_typed_records: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_typed_records", false)
	var typed_record_method: String = ""
	if include_typed_records:
		typed_record_method = _make_unique_name(
			_format_method_pattern(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "typed_record_method_pattern", "get_{table}_typed_record"), method_prefix),
			used_methods
		)

	var comment: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "comment")
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_schema_comments", true) and not comment.is_empty():
		builder.doc(comment)
	builder.doc("获取 `%s` 表中的单条记录。" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "table_name"))
	builder.line("static func %s(id: Variant, provider: Variant = null) -> Variant:" % record_method)
	builder.indent()
	builder.line("return _get_provider_record(provider, %s, id)" % constant_name)
	builder.dedent()
	builder.blank(2)
	builder.doc("获取 `%s` 整张表数据。" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "table_name"))
	builder.line("static func %s(provider: Variant = null) -> Variant:" % table_method)
	builder.indent()
	builder.line("return _get_provider_table(provider, %s)" % constant_name)
	builder.dedent()
	builder.blank(2)
	if include_typed_records:
		var class_name_value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "typed_record_class_name")
		builder.doc("获取 `%s` 表中的单条记录包装；记录不存在或不是 Dictionary 时返回 null。" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "table_name"))
		builder.line("static func %s(id: Variant, provider: Variant = null) -> %s:" % [typed_record_method, class_name_value])
		builder.indent()
		builder.line("return %s.from_variant(_get_provider_record(provider, %s, id))" % [class_name_value, constant_name])
		builder.dedent()
		builder.blank(2)


func _append_typed_record_classes(builder: GFSourceBuilder, records: Array[Dictionary]) -> void:
	builder.section("内部类")
	_append_typed_record_base_class(builder)
	for record: Dictionary in records:
		_append_typed_record_class(builder, record)


func _append_typed_record_base_class(builder: GFSourceBuilder) -> void:
	builder.doc("配置记录包装基类。")
	builder.line("class %s:" % _RECORD_ACCESS_BASE_CLASS_NAME)
	builder.indent()
	builder.line("extends RefCounted")
	builder.blank()
	builder.line("var data: Dictionary = {}")
	builder.blank(2)
	builder.line("func get_value(field_name: StringName, default_value: Variant = null) -> Variant:")
	builder.indent()
	builder.line("return _get_dictionary_value(data, field_name, default_value)")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_bool(field_name: StringName, default_value: bool = false) -> bool:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is bool:")
	builder.indent()
	builder.line("var bool_value: bool = value")
	builder.line("return bool_value")
	builder.dedent()
	builder.line("if value is int:")
	builder.indent()
	builder.line("var int_value: int = value")
	builder.line("return int_value != 0")
	builder.dedent()
	builder.line("if value is float:")
	builder.indent()
	builder.line("var float_value: float = value")
	builder.line("return not is_zero_approx(float_value)")
	builder.dedent()
	builder.line("if value is String or value is StringName:")
	builder.indent()
	builder.line("var text: String = str(value).strip_edges().to_lower()")
	builder.line("if text == \"true\" or text == \"1\" or text == \"yes\" or text == \"on\":")
	builder.indent()
	builder.line("return true")
	builder.dedent()
	builder.line("if text == \"false\" or text == \"0\" or text == \"no\" or text == \"off\":")
	builder.indent()
	builder.line("return false")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_int(field_name: StringName, default_value: int = 0) -> int:")
	builder.indent()
	builder.line("return _to_int(get_value(field_name, default_value), default_value)")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_float(field_name: StringName, default_value: float = 0.0) -> float:")
	builder.indent()
	builder.line("return _to_float(get_value(field_name, default_value), default_value)")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_string(field_name: StringName, default_value: String = \"\") -> String:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is String:")
	builder.indent()
	builder.line("var text_value: String = value")
	builder.line("return text_value")
	builder.dedent()
	builder.line("if value is StringName:")
	builder.indent()
	builder.line("var name_value: StringName = value")
	builder.line("return String(name_value)")
	builder.dedent()
	builder.line("if value == null:")
	builder.indent()
	builder.line("return default_value")
	builder.dedent()
	builder.line("return str(value)")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_string_name(field_name: StringName, default_value: StringName = &\"\") -> StringName:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is StringName:")
	builder.indent()
	builder.line("var name_value: StringName = value")
	builder.line("return name_value")
	builder.dedent()
	builder.line("if value is String:")
	builder.indent()
	builder.line("var text_value: String = value")
	builder.line("return StringName(text_value)")
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_vector2(field_name: StringName, default_value: Vector2 = Vector2.ZERO) -> Vector2:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is Vector2:")
	builder.indent()
	builder.line("var vector_value: Vector2 = value")
	builder.line("return vector_value")
	builder.dedent()
	builder.line("if value is Vector2i:")
	builder.indent()
	builder.line("var vector_2i_value: Vector2i = value")
	builder.line("return Vector2(vector_2i_value.x, vector_2i_value.y)")
	builder.dedent()
	builder.line("if value is Dictionary:")
	builder.indent()
	builder.line("var dictionary_value: Dictionary = value")
	builder.line("return Vector2(")
	builder.indent()
	builder.line("_get_dictionary_float(dictionary_value, \"x\", default_value.x),")
	builder.line("_get_dictionary_float(dictionary_value, \"y\", default_value.y)")
	builder.dedent()
	builder.line(")")
	builder.dedent()
	builder.line("if value is Array:")
	builder.indent()
	builder.line("var array_value: Array = value")
	builder.line("if array_value.size() >= 2:")
	builder.indent()
	builder.line("return Vector2(_to_float(array_value[0], default_value.x), _to_float(array_value[1], default_value.y))")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_vector2i(field_name: StringName, default_value: Vector2i = Vector2i.ZERO) -> Vector2i:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is Vector2i:")
	builder.indent()
	builder.line("var vector_2i_value: Vector2i = value")
	builder.line("return vector_2i_value")
	builder.dedent()
	builder.line("if value is Vector2:")
	builder.indent()
	builder.line("var vector_value: Vector2 = value")
	builder.line("return Vector2i(roundi(vector_value.x), roundi(vector_value.y))")
	builder.dedent()
	builder.line("if value is Dictionary:")
	builder.indent()
	builder.line("var dictionary_value: Dictionary = value")
	builder.line("return Vector2i(")
	builder.indent()
	builder.line("_get_dictionary_int(dictionary_value, \"x\", default_value.x),")
	builder.line("_get_dictionary_int(dictionary_value, \"y\", default_value.y)")
	builder.dedent()
	builder.line(")")
	builder.dedent()
	builder.line("if value is Array:")
	builder.indent()
	builder.line("var array_value: Array = value")
	builder.line("if array_value.size() >= 2:")
	builder.indent()
	builder.line("return Vector2i(_to_int(array_value[0], default_value.x), _to_int(array_value[1], default_value.y))")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_color(field_name: StringName, default_value: Color = Color.WHITE) -> Color:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is Color:")
	builder.indent()
	builder.line("var color_value: Color = value")
	builder.line("return color_value")
	builder.dedent()
	builder.line("if value is Dictionary:")
	builder.indent()
	builder.line("var dictionary_value: Dictionary = value")
	builder.line("return Color(")
	builder.indent()
	builder.line("_get_dictionary_float(dictionary_value, \"r\", default_value.r),")
	builder.line("_get_dictionary_float(dictionary_value, \"g\", default_value.g),")
	builder.line("_get_dictionary_float(dictionary_value, \"b\", default_value.b),")
	builder.line("_get_dictionary_float(dictionary_value, \"a\", default_value.a)")
	builder.dedent()
	builder.line(")")
	builder.dedent()
	builder.line("if value is Array:")
	builder.indent()
	builder.line("var array_value: Array = value")
	builder.line("if array_value.size() >= 3:")
	builder.indent()
	builder.line("var alpha: float = _to_float(array_value[3], default_value.a) if array_value.size() >= 4 else default_value.a")
	builder.line("return Color(")
	builder.indent()
	builder.line("_to_float(array_value[0], default_value.r),")
	builder.line("_to_float(array_value[1], default_value.g),")
	builder.line("_to_float(array_value[2], default_value.b),")
	builder.line("alpha")
	builder.dedent()
	builder.line(")")
	builder.dedent()
	builder.dedent()
	builder.line("if value is String or value is StringName:")
	builder.indent()
	builder.line("var text: String = str(value).strip_edges()")
	builder.line("if not text.is_empty():")
	builder.indent()
	builder.line("return Color(text)")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_dictionary(field_name: StringName, default_value: Dictionary = {}) -> Dictionary:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is Dictionary:")
	builder.indent()
	builder.line("var dictionary_value: Dictionary = value")
	builder.line("return dictionary_value.duplicate(true)")
	builder.dedent()
	builder.line("return default_value.duplicate(true)")
	builder.dedent()
	builder.blank(2)
	builder.line("func get_array(field_name: StringName, default_value: Array = []) -> Array:")
	builder.indent()
	builder.line("var value: Variant = get_value(field_name, default_value)")
	builder.line("if value is Array:")
	builder.indent()
	builder.line("var array_value: Array = value")
	builder.line("return array_value.duplicate(true)")
	builder.dedent()
	builder.line("return default_value.duplicate(true)")
	builder.dedent()
	builder.blank(2)
	builder.line("func _get_dictionary_value(source: Dictionary, key: Variant, default_value: Variant = null) -> Variant:")
	builder.indent()
	builder.line("if source.has(key):")
	builder.indent()
	builder.line("return source[key]")
	builder.dedent()
	builder.line("if key is StringName:")
	builder.indent()
	builder.line("var key_name: StringName = key")
	builder.line("var text_key: String = String(key_name)")
	builder.line("if source.has(text_key):")
	builder.indent()
	builder.line("return source[text_key]")
	builder.dedent()
	builder.dedent()
	builder.line("elif key is String:")
	builder.indent()
	builder.line("var key_text: String = key")
	builder.line("var name_key: StringName = StringName(key_text)")
	builder.line("if source.has(name_key):")
	builder.indent()
	builder.line("return source[name_key]")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func _get_dictionary_float(source: Dictionary, key: Variant, default_value: float = 0.0) -> float:")
	builder.indent()
	builder.line("return _to_float(_get_dictionary_value(source, key, default_value), default_value)")
	builder.dedent()
	builder.blank(2)
	builder.line("func _get_dictionary_int(source: Dictionary, key: Variant, default_value: int = 0) -> int:")
	builder.indent()
	builder.line("return _to_int(_get_dictionary_value(source, key, default_value), default_value)")
	builder.dedent()
	builder.blank(2)
	builder.line("func _to_int(value: Variant, default_value: int = 0) -> int:")
	builder.indent()
	builder.line("if value is int:")
	builder.indent()
	builder.line("var int_value: int = value")
	builder.line("return int_value")
	builder.dedent()
	builder.line("if value is bool:")
	builder.indent()
	builder.line("var bool_value: bool = value")
	builder.line("return 1 if bool_value else 0")
	builder.dedent()
	builder.line("if value is float:")
	builder.indent()
	builder.line("var float_value: float = value")
	builder.line("return int(float_value)")
	builder.dedent()
	builder.line("if value is String or value is StringName:")
	builder.indent()
	builder.line("var text: String = str(value).strip_edges()")
	builder.line("if text.is_valid_int():")
	builder.indent()
	builder.line("return text.to_int()")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)
	builder.line("func _to_float(value: Variant, default_value: float = 0.0) -> float:")
	builder.indent()
	builder.line("if value is float:")
	builder.indent()
	builder.line("var float_value: float = value")
	builder.line("return float_value if not is_nan(float_value) and not is_inf(float_value) else default_value")
	builder.dedent()
	builder.line("if value is int:")
	builder.indent()
	builder.line("var int_value: int = value")
	builder.line("return float(int_value)")
	builder.dedent()
	builder.line("if value is bool:")
	builder.indent()
	builder.line("var bool_value: bool = value")
	builder.line("return 1.0 if bool_value else 0.0")
	builder.dedent()
	builder.line("if value is String or value is StringName:")
	builder.indent()
	builder.line("var text: String = str(value).strip_edges()")
	builder.line("if text.is_valid_float():")
	builder.indent()
	builder.line("return text.to_float()")
	builder.dedent()
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.dedent()
	builder.blank(2)


func _append_typed_record_class(builder: GFSourceBuilder, record: Dictionary) -> void:
	var class_name_value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "typed_record_class_name")
	builder.doc("%s 表记录包装。" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "table_name"))
	builder.line("class %s:" % class_name_value)
	builder.indent()
	builder.line("extends %s" % _RECORD_ACCESS_BASE_CLASS_NAME)
	builder.blank(2)
	builder.line("static func from_variant(value: Variant) -> %s:" % class_name_value)
	builder.indent()
	builder.line("if not (value is Dictionary):")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("var record: %s = %s.new()" % [class_name_value, class_name_value])
	builder.line("var dictionary_value: Dictionary = value")
	builder.line("record.data = dictionary_value.duplicate(true)")
	builder.line("return record")
	builder.dedent()
	for column_record: Dictionary in _get_record_columns(record):
		_append_typed_record_getter(builder, column_record)
	builder.dedent()
	builder.blank(2)


func _append_typed_record_getter(builder: GFSourceBuilder, column_record: Dictionary) -> void:
	builder.blank(2)
	builder.doc("读取 `%s` 字段。" % String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(column_record, "field_name")))
	builder.line("func %s() -> %s:" % [
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(column_record, "getter_name"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(column_record, "return_type"),
	])
	builder.indent()
	builder.line("return %s(&\"%s\", %s)" % [
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(column_record, "helper_name"),
		_escape_string(String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(column_record, "field_name"))),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(column_record, "default_literal"),
	])
	builder.dedent()


func _collect_column_records(schema: Variant) -> Array[Dictionary]:
	var columns: Variant = _get_schema_columns_value(schema)
	if not (columns is Array):
		return []

	var column_values: Array = columns
	var records: Array[Dictionary] = []
	var used_getter_names: Dictionary = _make_reserved_typed_record_getter_names()
	for column_value: Variant in column_values:
		var field_name: StringName = _get_column_field_name(column_value)
		if field_name == &"":
			continue

		var field_identifier: String = _sanitize_identifier(String(field_name))
		if field_identifier.is_empty():
			push_warning("[GFConfigAccessGenerator] 字段名无法生成有效 getter，已跳过：%s" % String(field_name))
			continue

		var value_type: String = _get_column_value_type(column_value)
		var type_info: Dictionary = _get_typed_record_type_info(value_type)
		records.append({
			"field_name": field_name,
			"getter_name": _make_unique_name("get_%s" % field_identifier, used_getter_names),
			"value_type": value_type,
			"return_type": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(type_info, "return_type", "Variant"),
			"helper_name": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(type_info, "helper_name", "get_value"),
			"default_literal": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(type_info, "default_literal", "null"),
		})
	return records


func _get_record_columns(record: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for column_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(record, "columns"):
		if column_value is Dictionary:
			var column_record: Dictionary = column_value
			result.append(column_record)
	return result


func _get_schema_columns_value(schema: Variant) -> Variant:
	if schema == null:
		return []
	if schema is Dictionary:
		var dictionary: Dictionary = schema
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "columns", [])
	if schema is Object:
		var object: Object = schema
		return _get_object_property_or_default(object, &"columns", [])
	return []


func _get_column_field_name(column: Variant) -> StringName:
	if column == null:
		return &""
	if column is Dictionary:
		var dictionary: Dictionary = column
		var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "field_name")
		if value == null:
			value = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "name")
		if value == null:
			value = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "field")
		return _GF_VARIANT_ACCESS_SCRIPT.to_string_name(value)
	if column is Object:
		var object: Object = column
		var field_name: Variant = _get_object_property_or_default(object, &"field_name", null)
		if field_name == null:
			field_name = _get_object_property_or_default(object, &"name", null)
		if field_name == null:
			field_name = _get_object_property_or_default(object, &"field", null)
		return _GF_VARIANT_ACCESS_SCRIPT.to_string_name(field_name)
	return &""


func _get_column_value_type(column: Variant) -> String:
	if column == null:
		return _VALUE_TYPE_ANY
	if column is Dictionary:
		var dictionary: Dictionary = column
		var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "value_type")
		if value == null:
			value = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "type")
		if value == null:
			value = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "gdscript_type")
		return _normalize_column_value_type(value)
	if column is Object:
		var object: Object = column
		var value_type: Variant = _get_object_property_or_default(object, &"value_type", null)
		if value_type == null:
			value_type = _get_object_property_or_default(object, &"type", null)
		return _normalize_column_value_type(value_type)
	return _VALUE_TYPE_ANY


func _normalize_column_value_type(value: Variant) -> String:
	if value is String or value is StringName:
		var text: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(value).strip_edges().to_lower()
		text = text.replace("-", "_").replace(" ", "_")
		match text:
			"", "any", "variant":
				return _VALUE_TYPE_ANY
			"bool", "boolean":
				return _VALUE_TYPE_BOOL
			"int", "integer":
				return _VALUE_TYPE_INT
			"float", "number", "double":
				return _VALUE_TYPE_FLOAT
			"string":
				return _VALUE_TYPE_STRING
			"stringname", "string_name":
				return _VALUE_TYPE_STRING_NAME
			"vector2":
				return _VALUE_TYPE_VECTOR2
			"vector2i":
				return _VALUE_TYPE_VECTOR2I
			"color", "colour":
				return _VALUE_TYPE_COLOR
			"dictionary", "dict":
				return _VALUE_TYPE_DICTIONARY
			"array":
				return _VALUE_TYPE_ARRAY
			_:
				return _VALUE_TYPE_ANY
	if value is int:
		var type_index: int = value
		match type_index:
			1:
				return _VALUE_TYPE_BOOL
			2:
				return _VALUE_TYPE_INT
			3:
				return _VALUE_TYPE_FLOAT
			4:
				return _VALUE_TYPE_STRING
			5:
				return _VALUE_TYPE_STRING_NAME
			6:
				return _VALUE_TYPE_VECTOR2
			7:
				return _VALUE_TYPE_VECTOR2I
			8:
				return _VALUE_TYPE_COLOR
			9:
				return _VALUE_TYPE_DICTIONARY
			10:
				return _VALUE_TYPE_ARRAY
			_:
				return _VALUE_TYPE_ANY
	return _VALUE_TYPE_ANY


func _get_typed_record_type_info(value_type: String) -> Dictionary:
	match value_type:
		_VALUE_TYPE_BOOL:
			return { "return_type": "bool", "helper_name": "get_bool", "default_literal": "false" }
		_VALUE_TYPE_INT:
			return { "return_type": "int", "helper_name": "get_int", "default_literal": "0" }
		_VALUE_TYPE_FLOAT:
			return { "return_type": "float", "helper_name": "get_float", "default_literal": "0.0" }
		_VALUE_TYPE_STRING:
			return { "return_type": "String", "helper_name": "get_string", "default_literal": "\"\"" }
		_VALUE_TYPE_STRING_NAME:
			return { "return_type": "StringName", "helper_name": "get_string_name", "default_literal": "&\"\"" }
		_VALUE_TYPE_VECTOR2:
			return { "return_type": "Vector2", "helper_name": "get_vector2", "default_literal": "Vector2.ZERO" }
		_VALUE_TYPE_VECTOR2I:
			return { "return_type": "Vector2i", "helper_name": "get_vector2i", "default_literal": "Vector2i.ZERO" }
		_VALUE_TYPE_COLOR:
			return { "return_type": "Color", "helper_name": "get_color", "default_literal": "Color.WHITE" }
		_VALUE_TYPE_DICTIONARY:
			return { "return_type": "Dictionary", "helper_name": "get_dictionary", "default_literal": "{}" }
		_VALUE_TYPE_ARRAY:
			return { "return_type": "Array", "helper_name": "get_array", "default_literal": "[]" }
		_:
			return { "return_type": "Variant", "helper_name": "get_value", "default_literal": "null" }


func _sanitize_identifier(value: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var current: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1).to_lower()
		if _is_identifier_part(character):
			current += character
		elif not current.is_empty():
			_append_packed_string(parts, current)
			current = ""
	if not current.is_empty():
		_append_packed_string(parts, current)
	if parts.is_empty():
		return ""

	var result: String = "_".join(parts)
	if result.substr(0, 1).is_valid_int():
		result = "table_" + result
	return result


func _normalize_generation_options(options: Dictionary) -> Dictionary:
	var typed_record_class_suffix: String = _sanitize_record_class_suffix(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "typed_record_class_suffix", "Record"))
	var result: Dictionary = {
		"method_name_style": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "method_name_style", "snake").to_lower(),
		"constant_prefix": _sanitize_constant_prefix(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "constant_prefix")),
		"record_method_pattern": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "record_method_pattern", "get_{table}_record"),
		"table_method_pattern": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "table_method_pattern", "get_{table}_table"),
		"include_schema_comments": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_schema_comments", true),
		"include_typed_records": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_typed_records", false),
		"typed_record_method_pattern": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "typed_record_method_pattern", "get_{table}_typed_record"),
		"typed_record_class_suffix": typed_record_class_suffix,
	}
	if not (_GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "method_name_style") in ["snake", "camel", "pascal"]):
		result["method_name_style"] = "snake"
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "record_method_pattern").is_empty():
		result["record_method_pattern"] = "get_{table}_record"
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "table_method_pattern").is_empty():
		result["table_method_pattern"] = "get_{table}_table"
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "typed_record_method_pattern").is_empty():
		result["typed_record_method_pattern"] = "get_{table}_typed_record"
	return result


func _sanitize_record_class_suffix(value: String) -> String:
	var sanitized: String = _sanitize_identifier(value)
	if sanitized.is_empty():
		return "Record"
	return _to_pascal_case(sanitized)


func _sanitize_constant_prefix(value: String) -> String:
	if value.is_empty():
		return ""
	var sanitized: String = _sanitize_identifier(value).to_upper()
	return "%s_" % sanitized if not sanitized.is_empty() and not sanitized.ends_with("_") else sanitized


func _format_identifier(identifier: String, style: String) -> String:
	match style:
		"camel":
			return _to_camel_case(identifier)
		"pascal":
			return _to_pascal_case(identifier)
		_:
			return identifier


func _format_method_pattern(pattern: String, table_token: String) -> String:
	var method_name: String = pattern.replace("{table}", table_token)
	method_name = _sanitize_generated_method_name(method_name)
	if method_name.is_empty():
		return _sanitize_generated_method_name("get_%s" % table_token)
	return method_name


func _make_unique_name(base_name: String, used_names: Dictionary) -> String:
	var candidate: String = base_name
	var suffix_index: int = 2
	while used_names.has(candidate):
		candidate = "%s_%d" % [base_name, suffix_index]
		suffix_index += 1
	used_names[candidate] = true
	return candidate


func _sanitize_generated_method_name(value: String) -> String:
	var result: String = ""
	var previous_was_separator: bool = false
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if _is_identifier_part(character.to_lower()) or character == "_":
			result += character
			previous_was_separator = false
		elif not previous_was_separator:
			result += "_"
			previous_was_separator = true
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	if result.is_empty():
		return ""
	if result.substr(0, 1).is_valid_int():
		result = "method_" + result
	if _is_gdscript_reserved_word(result):
		result = "method_" + result
	return result


func _sanitize_class_name(value: String, fallback: String) -> String:
	var trimmed: String = value.strip_edges()
	if _is_valid_identifier(trimmed) and not _is_gdscript_reserved_word(trimmed):
		return trimmed

	var sanitized: String = _sanitize_identifier(trimmed)
	if sanitized.is_empty():
		sanitized = _sanitize_identifier(fallback)
	var result: String = _to_pascal_case(sanitized)
	if result.is_empty():
		return fallback
	if _is_gdscript_reserved_word(result):
		result = "Generated%s" % result
	return result


func _to_pascal_case(identifier: String) -> String:
	var parts: PackedStringArray = identifier.split("_", false)
	var result: String = ""
	for part: String in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


func _to_camel_case(identifier: String) -> String:
	var pascal: String = _to_pascal_case(identifier)
	if pascal.is_empty():
		return identifier
	return pascal.substr(0, 1).to_lower() + pascal.substr(1)


func _get_schema_table_name(schema: Variant) -> String:
	if schema == null:
		return ""
	if schema is Dictionary:
		var dictionary: Dictionary = schema
		if dictionary.has("table_name"):
			return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(dictionary, "table_name")
		if dictionary.has("table_key"):
			return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(dictionary, "table_key")
		return ""
	if schema is Object:
		var object: Object = schema
		var table_name: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(_get_object_property_or_default(object, &"table_name", ""))
		if not table_name.is_empty():
			return table_name
		return _GF_VARIANT_ACCESS_SCRIPT.to_text(_get_object_property_or_default(object, &"table_key", ""))
	return ""


func _get_schema_metadata(schema: Variant) -> Dictionary:
	if schema == null:
		return {}
	if schema is Dictionary:
		var dictionary: Dictionary = schema
		var metadata: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, "metadata", {})
		if metadata is Dictionary:
			var metadata_dictionary: Dictionary = metadata
			return metadata_dictionary.duplicate(true)
		return {}
	if schema is Object:
		var object: Object = schema
		var metadata_variant: Variant = _get_object_property_or_default(object, &"metadata", {})
		if metadata_variant is Dictionary:
			var metadata_dictionary: Dictionary = metadata_variant
			return metadata_dictionary.duplicate(true)
		return {}
	return {}


func _get_schema_comment(metadata: Dictionary) -> String:
	if metadata.has("comment"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(metadata, "comment")
	if metadata.has("description"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(metadata, "description")
	return ""


func _get_object_property_or_default(object: Object, property_name: StringName, default_value: Variant) -> Variant:
	for property: Dictionary in object.get_property_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(property, "name") == property_name:
			return object.get_indexed(NodePath(String(property_name)))
	return default_value


func _to_constant_name(identifier: String) -> String:
	return identifier.to_upper()


func _is_identifier_part(character: String) -> bool:
	if character.length() != 1:
		return false

	var code: int = character.unicode_at(0)
	return (
		(code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
	)


func _is_valid_identifier(value: String) -> bool:
	if value.is_empty():
		return false

	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		var code: int = character.to_lower().unicode_at(0)
		var is_letter: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = character == "_"
		if index == 0:
			if not (is_letter or is_underscore):
				return false
		elif not (is_letter or is_digit or is_underscore):
			return false
	return true


func _is_gdscript_reserved_word(value: String) -> bool:
	match value.to_lower():
		"and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue", "elif", "else", "enum", "extends", "false", "for", "func", "if", "in", "is", "match", "not", "null", "or", "pass", "preload", "return", "self", "signal", "static", "super", "true", "var", "void", "while", "yield":
			return true
		_:
			return false


func _make_reserved_typed_record_getter_names() -> Dictionary:
	return {
		"call": true,
		"call_deferred": true,
		"callv": true,
		"connect": true,
		"disconnect": true,
		"emit_signal": true,
		"free": true,
		"get": true,
		"get_array": true,
		"get_bool": true,
		"get_class": true,
		"get_color": true,
		"get_dictionary": true,
		"get_float": true,
		"get_int": true,
		"get_instance_id": true,
		"get_meta": true,
		"get_property_list": true,
		"get_script": true,
		"get_signal_list": true,
		"get_string": true,
		"get_string_name": true,
		"get_value": true,
		"get_vector2": true,
		"get_vector2i": true,
		"has_method": true,
		"has_meta": true,
		"has_signal": true,
		"is_class": true,
		"is_connected": true,
		"is_queued_for_deletion": true,
		"notify_property_list_changed": true,
		"property_list_changed": true,
		"set": true,
		"set_deferred": true,
		"set_meta": true,
		"set_script": true,
		"to_string": true,
	}


func _escape_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


func _store_file_string(file: FileAccess, value: String) -> void:
	var _stored: bool = file.store_string(value)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _appended: bool = target.append(value)
