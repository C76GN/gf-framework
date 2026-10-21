@tool

## GFConfigTableSchema: 通用导表结构声明与校验器。
##
## 用于在导入期或运行时校验表数据结构，保持数据工具链可替换且不绑定业务表。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigTableSchema
extends Resource


# --- 常量 ---

## 创建配置 schema 校验报告的类脚本引用。
## [br]
## @api private
## [br]
const _CONFIG_VALIDATION_REPORT = preload("res://addons/gf/standard/utilities/config/gf_config_validation_report.gd")

## 执行资源路径元素校验的规则类脚本引用。
## [br]
## @api private
## [br]
const _RESOURCE_PATH_VALIDATION_RULE = preload("res://addons/gf/standard/utilities/config/validation/gf_config_resource_path_validation_rule.gd")

## 资源路径校验共享会话在选项字典中的键。
## [br]
## @api private
## [br]
const _RESOURCE_PATH_VALIDATION_SESSION_KEY: StringName = &"__gf_config_resource_path_validation_session"

## 元素规则校验共享预算会话在选项字典中的键。
## [br]
## @api private
## [br]
const _ELEMENT_VALIDATION_SESSION_KEY: StringName = &"__gf_config_element_validation_session"

## 一次 schema 验证可检查的元素数量上限。
## [br]
## @api private
## [br]
const _MAX_ELEMENTS_PER_VALIDATION: int = GFConfigElementValidation.MAX_ELEMENTS

## 一次 schema 验证可执行的元素规则检查总数上限。
## [br]
## @api private
## [br]
const _MAX_ELEMENT_RULE_CHECKS_PER_VALIDATION: int = GFConfigElementValidation.MAX_RULE_CHECKS


# --- 导出变量 ---

## 表名。为空时可由调用方自行决定表标识。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var table_name: StringName = &""

## 记录 ID 字段。为空时不检查记录 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var id_field: StringName = &"id"

## 字段声明列表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema columns: Array[GFConfigTableColumn]，定义当前表允许的字段和字段级校验规则。
@export var columns: Array[GFConfigTableColumn] = []

## 是否允许记录包含 schema 未声明的字段。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var allow_extra_fields: bool = true

## 是否在校验前按字段声明尝试类型转换。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var coerce_values: bool = false

## 启用 coerce_values 时，转换失败是否作为校验错误。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var fail_on_coerce_error: bool = true

## 校验整表时是否要求 id_field 唯一。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var require_unique_id: bool = false

## 单次记录或整表校验最多执行的唯一资源路径存在性探测数。
##
## 同一路径及同一探测策略在一次校验内共享结果，不重复消耗预算。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 65536, 1) var max_resource_path_checks_per_validation: int = 1024

## 单次记录或整表校验可准入的数组元素总数，跨字段及记录共享。
##
## 仅统计存在启用元素规则的 Array；每个字段在元素检查及回调前整批预留。
## coerce_values 为 true 时，预算失败在复制前拒绝整条记录；否则只跳过该字段的元素校验，整值规则仍执行。
## 程序写入不在 1 至 65536 内的值时，定义与运行校验均失败，不钳制。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(1, 65536, 1) var max_elements_per_validation: int = 4096

## 单次记录或整表校验可准入的元素规则调用数，按数组长度乘以启用规则数预留。
##
## 与元素数预算共享同次操作的生命周期；null 或被拒绝类型的元素也计入预留，不退还预算。
## 允许范围为 1 至 262144；非法值失败关闭。仅限制调用次数，不抢占自定义规则的同步执行。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(1, 262144, 1) var max_element_rule_checks_per_validation: int = 16384

## 可选复合索引声明。唯一索引会参与表级校验。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema indexes: Array[GFConfigTableIndexDefinition]，定义当前表的复合索引和唯一性约束。
@export var indexes: Array[GFConfigTableIndexDefinition] = []

## 可选跨表引用声明。引用目标由 `GFConfigReferenceResolver` 在多表上下文中校验。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema references: Array[GFConfigTableReference]，定义当前表到其他表的引用关系。
@export var references: Array[GFConfigTableReference] = []

## 可选记录级校验规则。规则会在字段结构校验后作用于整条记录。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema record_validation_rules: Array[GFConfigValidationRule]，包含作用于单条记录的校验规则。
@export var record_validation_rules: Array[GFConfigValidationRule] = []

## 可选表级校验规则。规则会在行结构、唯一 ID 和索引校验后作用于整表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema table_validation_rules: Array[GFConfigValidationRule]，包含作用于整张表的校验规则。
@export var table_validation_rules: Array[GFConfigValidationRule] = []

## 可选元数据，供导入器、编辑器或项目层扩展使用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: Dictionary，保存导入器、编辑器或项目层附加到当前 schema 的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 从记录样本推导通用 schema。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param inferred_table_name: 推导出的表名。
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param options: 可选参数，支持 id_field、required_if_present_in_all_rows、allow_extra_fields、coerce_values。
## [br]
## @schema options: Dictionary，可包含 id_field、required_if_present_in_all_rows、allow_extra_fields 和 coerce_values。
## [br]
## @return 推导出的 schema；数据无效时返回空 schema。
static func infer_from_records(
	inferred_table_name: StringName,
	table_data: Variant,
	options: Dictionary = {}
) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = inferred_table_name
	schema.id_field = GFVariantData.get_option_string_name(
		options,
		"id_field",
		&"id"
	)
	schema.allow_extra_fields = GFVariantData.get_option_bool(
		options,
		"allow_extra_fields",
		true
	)
	schema.coerce_values = GFVariantData.get_option_bool(
		options,
		"coerce_values",
		false
	)

	var rows: Array[Dictionary] = _normalize_inference_rows(table_data)
	if rows.is_empty():
		return schema

	var field_presence: Dictionary = {}
	var field_values: Dictionary = {}
	for row: Dictionary in rows:
		for key: Variant in row.keys():
			var field_name: StringName = GFVariantData.to_string_name(key)
			field_presence[field_name] = GFVariantData.get_option_int(
				field_presence,
				field_name,
				0
			) + 1
			_append_field_value(
				field_values,
				field_name,
				row[key]
			)

	var field_names: PackedStringArray = PackedStringArray()
	for field_name: StringName in field_values.keys():
		_append_packed_string(
			field_names,
			String(field_name)
		)
	field_names.sort()

	var require_if_present_all: bool = GFVariantData.get_option_bool(
		options,
		"required_if_present_in_all_rows",
		false
	)
	for field_text: String in field_names:
		var field_name: StringName = StringName(field_text)
		var column: GFConfigTableColumn = GFConfigTableColumn.new()
		var values: Array = _get_field_values(field_values, field_name)
		column.field_name = field_name
		column.value_type = _infer_column_value_type(values)
		column.required = (
			require_if_present_all
			and GFVariantData.get_option_int(
				field_presence,
				field_name,
				0
			) == rows.size()
		)
		column.allow_null = _values_allow_null(values)
		schema.columns.append(column)

	return schema


## 获取稳定表键。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 表名。
func get_table_key() -> StringName:
	return table_name


## 获取字段声明。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param field_name: 字段名。
## [br]
## @return 找到时返回字段声明，否则返回 null。
func get_column(field_name: StringName) -> GFConfigTableColumn:
	for column: GFConfigTableColumn in columns:
		if column != null and column.get_field_key() == field_name:
			return column
	return null


## 检查字段声明是否存在。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param field_name: 字段名。
## [br]
## @return 存在返回 true。
func has_column(field_name: StringName) -> bool:
	return get_column(field_name) != null


## 获取索引声明。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param index_id: 索引标识。
## [br]
## @return 找到时返回索引声明，否则返回 null。
func get_index(index_id: StringName) -> GFConfigTableIndexDefinition:
	for index: GFConfigTableIndexDefinition in indexes:
		if index != null and index.get_index_id() == index_id:
			return index
	return null


## 检查索引声明是否存在。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param index_id: 索引标识。
## [br]
## @return 存在返回 true。
func has_index(index_id: StringName) -> bool:
	return get_index(index_id) != null


## 获取引用声明。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param reference_id: 引用标识。
## [br]
## @return 找到时返回引用声明，否则返回 null。
func get_reference(reference_id: StringName) -> GFConfigTableReference:
	for reference_definition: GFConfigTableReference in references:
		if reference_definition != null and reference_definition.get_reference_id() == reference_id:
			return reference_definition
	return null


## 检查引用声明是否存在。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param reference_id: 引用标识。
## [br]
## @return 存在返回 true。
func has_reference(reference_id: StringName) -> bool:
	return get_reference(reference_id) != null


## 获取当前 schema 的字段名列表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 字段名列表。
func get_column_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for column: GFConfigTableColumn in columns:
		if column != null and column.get_field_key() != &"":
			_append_packed_string(
				result,
				str(column.get_field_key())
			)
	result.sort()
	return result


## 校验 schema 自身声明是否完整、一致。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param options: 可选上下文，支持 source。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_definition(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(0)
	var runtime_options: Dictionary = _with_type_compilation_session(options)
	if runtime_options.has("__gf_config_type_compiler"):
		var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(runtime_options)
		_merge_report(
			report,
			compiler.get_definition_report()
		)
	var _limits_valid: bool = _validate_element_limits(report, options)
	_validate_column_definitions(report, options)
	_validate_index_definitions(report, options)
	_validate_reference_definitions(report, options)
	_validate_rule_definitions(report, options)
	_finalize_report(report)
	return report


## 校验单条记录。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param record: 记录字典。
## [br]
## @schema record: Dictionary，待校验的配置记录，键为字段名，值为字段数据。
## [br]
## @param row_key: 可选行标识，用于错误报告。
## [br]
## @schema row_key: Variant，写入校验报告 issue 的行标识。
## [br]
## @param options: 可选上下文，支持 source、line、row_index、row_locations。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_record(
	record: Dictionary,
	row_key: Variant = null,
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = _make_report(1)
	var runtime_options: Dictionary = _with_type_compilation_session(_with_element_validation_session(_with_resource_path_validation_session(options)))
	if not _admit_type_compilation(report, runtime_options):
		return report
	var prepared: _PreparedValidationRecord = _prepare_record_for_validation(
		record,
		row_key,
		report,
		runtime_options
	)
	if prepared._admitted:
		_validate_prepared_record(
			record,
			row_key,
			report,
			runtime_options,
			prepared
		)
	_finalize_report(report)
	report["data"] = _copy_validated_data(
		prepared._record,
		report,
		runtime_options
	) if report["ok"] and prepared._admitted else null
	return report


## 校验整张表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param options: 可选上下文，支持 source、row_locations。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_table(table_data: Variant, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(0)
	report["data"] = null
	if not _validate_element_limits(report, options) or not _validate_element_definitions(report, options):
		_finalize_report(report)
		return report
	var runtime_options: Dictionary = _with_type_compilation_session(_with_element_validation_session(_with_resource_path_validation_session(options)))
	if not _admit_type_compilation(report, runtime_options):
		return report
	if table_data is Array:
		_validate_array_table(
			GFVariantData.as_array(table_data),
			report,
			runtime_options
		)
	elif table_data is Dictionary:
		_validate_dictionary_table(
			GFVariantData.as_dictionary(table_data),
			report,
			runtime_options
		)
	else:
		_add_issue(
			report,
			"error",
			"invalid_table",
			null,
			&"",
			"表数据必须是 Array 或 Dictionary。",
			_make_record_context(null, runtime_options)
		)

	_finalize_report(report)
	if report["ok"]:
		report["data"] = _copy_validated_data(
			report["data"],
			report,
			runtime_options
		)
	else:
		report["data"] = null
	return report


## 按字段声明转换单条记录。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param record: 输入记录。
## [br]
## @schema record: Dictionary，待转换的配置记录，键为字段名，值为字段数据。
## [br]
## @param options: 结构化转换的调用期预算与来源选项。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
## [br]
## @return 转换后的新记录；结构化转换失败时为空，可用 try_coerce_record 获取原因。
## [br]
## @schema return: Dictionary，转换后的记录副本。
func coerce_record(record: Dictionary, options: Dictionary = {}) -> Dictionary:
	if _has_structured_columns():
		var report: Dictionary = try_coerce_record(record, options)
		var data: Variant = report.get("data")
		return data if data is Dictionary else {}
	var result: Dictionary = GFVariantData.as_dictionary(GFVariantData.duplicate_variant(record))
	for column: GFConfigTableColumn in columns:
		if column == null or column.get_field_key() == &"":
			continue

		var field_key: StringName = column.get_field_key()
		if result.has(field_key):
			result[field_key] = column.coerce_value(result[field_key])
		elif column.default_value != null:
			result[field_key] = column.coerce_value(column.default_value)
	return result


## 在共享编译会话内转换记录，结构化字段失败时不返回部分结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record: 不会被修改的输入记录。
## [br]
## @param options: 预算与来源选项。
## [br]
## @return 报告附加 data；失败 data 为 null。
## [br]
## @schema record: Dictionary，字段名映射到配置值。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits 及来源上下文。
## [br]
## @schema return: Dictionary，包含 ok、issues、error_count、warning_count、data。
func try_coerce_record(record: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(1)
	report["data"] = null
	var runtime_options: Dictionary = _with_type_compilation_session(options)
	if not _admit_type_compilation(report, runtime_options):
		return report
	if runtime_options.has("__gf_config_type_compiler"):
		var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(runtime_options)
		if not compiler.admit_value(record):
			_merge_report(
				report,
				compiler.get_report()
			)
			return report
	var result: Dictionary = _coerce_record_for_validation(
		record,
		null,
		report,
		runtime_options,
		columns
	)
	_finalize_report(report)
	report["data"] = null
	if report["ok"]:
		report["data"] = result
	return report


## 创建空记录模板。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param include_optional: 为 true 时包含非必填字段。
## [br]
## @return 新记录字典。
## [br]
## @schema return: Dictionary，键为字段名，值为字段默认值转换后的结果。
func build_empty_record(include_optional: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for column: GFConfigTableColumn in columns:
		if column == null or column.get_field_key() == &"":
			continue
		if column.required or include_optional:
			result[column.get_field_key()] = column.coerce_value(column.default_value)
	return result


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param options: 调用期复制预算；不执行默认值或业务规则。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
## [br]
## @return 新 schema；字段图循环或复制预算失败时为 null，非循环的无效声明保留。
func duplicate_schema(options: Dictionary = {}) -> GFConfigTableSchema:
	var copy_options: Dictionary = options.duplicate()
	var copier: GFConfigTypeCopier = GFConfigTypeCopier.from_options(options)
	copy_options["__gf_config_type_copier"] = copier
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table_name
	schema.id_field = id_field
	schema.allow_extra_fields = allow_extra_fields
	schema.coerce_values = coerce_values
	schema.fail_on_coerce_error = fail_on_coerce_error
	schema.require_unique_id = require_unique_id
	schema.max_resource_path_checks_per_validation = max_resource_path_checks_per_validation
	schema.max_elements_per_validation = max_elements_per_validation
	schema.max_element_rule_checks_per_validation = max_element_rule_checks_per_validation
	for index: GFConfigTableIndexDefinition in indexes:
		schema.indexes.append(index.duplicate_index() if index != null else null)
	for reference_definition: GFConfigTableReference in references:
		schema.references.append(reference_definition.duplicate_reference() if reference_definition != null else null)
	for rule: GFConfigValidationRule in record_validation_rules:
		schema.record_validation_rules.append(rule.duplicate_rule() if rule != null else null)
	for rule: GFConfigValidationRule in table_validation_rules:
		schema.table_validation_rules.append(rule.duplicate_rule() if rule != null else null)
	schema.metadata = metadata.duplicate(true)
	for column: GFConfigTableColumn in columns:
		var copied: GFConfigTableColumn = column.duplicate_column(copy_options) if column != null else null
		if column != null and copied == null:
			return null
		schema.columns.append(copied)
	return schema


## 导出 schema 摘要；结构列在同一有限会话内描述，不执行默认值或业务规则。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param options: 结构化描述的调用期预算与来源选项。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
## [br]
## @return schema 字典；结构列的失败保留在各列 type_definition 报告中。
## [br]
## @schema return: Dictionary，包含 table_name、id_field、columns、allow_extra_fields、coerce_values、fail_on_coerce_error、require_unique_id、max_resource_path_checks_per_validation、max_elements_per_validation、max_element_rule_checks_per_validation、indexes、references、record_validation_rules、table_validation_rules 和 metadata。
func describe(options: Dictionary = {}) -> Dictionary:
	var description_options: Dictionary = options.duplicate()
	description_options["__gf_config_type_compiler"] = GFConfigTypeCompiler.from_options(options)
	var column_descriptions: Array[Dictionary] = []
	for column: GFConfigTableColumn in columns:
		if column != null:
			column_descriptions.append(column.describe(description_options))
	var index_descriptions: Array[Dictionary] = []
	for index: GFConfigTableIndexDefinition in indexes:
		if index != null:
			index_descriptions.append(index.describe())
	var reference_descriptions: Array[Dictionary] = []
	for reference_definition: GFConfigTableReference in references:
		if reference_definition != null:
			reference_descriptions.append(reference_definition.describe())
	var record_rule_descriptions: Array[Dictionary] = _describe_validation_rules(record_validation_rules)
	var table_rule_descriptions: Array[Dictionary] = _describe_validation_rules(table_validation_rules)
	return {
		"table_name": table_name,
		"id_field": id_field,
		"columns": column_descriptions,
		"allow_extra_fields": allow_extra_fields,
		"coerce_values": coerce_values,
		"fail_on_coerce_error": fail_on_coerce_error,
		"require_unique_id": require_unique_id,
		"max_resource_path_checks_per_validation": max_resource_path_checks_per_validation,
		"max_elements_per_validation": max_elements_per_validation,
		"max_element_rule_checks_per_validation": max_element_rule_checks_per_validation,
		"indexes": index_descriptions,
		"references": reference_descriptions,
		"record_validation_rules": record_rule_descriptions,
		"table_validation_rules": table_rule_descriptions,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 同次表操作先编译所有结构列，再执行默认值规则，后续各行只消费冻结节点。
## [br]
## @api private
func _with_type_compilation_session(options: Dictionary) -> Dictionary:
	if not _has_structured_columns():
		return options
	var result: Dictionary = _with_resource_path_validation_session(_with_element_validation_session(options))
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(options)
	result["__gf_config_type_compiler"] = compiler
	compiler.bind_validation_context(result)
	for column: GFConfigTableColumn in columns:
		if column != null and column.type_definition != null:
			var _field: Dictionary = compiler.compile_column(
				column,
				[str(column.field_name)]
			)
	compiler.validate_defaults()
	return result


## 没有结构类型的旧 schema 保持原有标量处理路径。
## [br]
## @api private
func _has_structured_columns() -> bool:
	for column: GFConfigTableColumn in columns:
		if column != null and column.type_definition != null:
			return true
	return false


## 定义失败直接阻止值复制和项目规则执行。
## [br]
## @api private
func _admit_type_compilation(report: Dictionary, options: Dictionary) -> bool:
	if not options.has("__gf_config_type_compiler"):
		return true
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(options)
	var definition_report: Dictionary = compiler.get_definition_report()
	if definition_report["ok"]:
		return true
	_merge_report(report, definition_report)
	report["data"] = null
	return false


## 仅在既有规则全部通过后准入报告副本；结构列沿用编译会话，旧列按整份结果共享预算。
##
## 失败不复制输入，不改变未准入元素与整值规则的既有执行顺序。
## [br]
## @api private
func _copy_validated_data(
	value: Variant,
	report: Dictionary,
	options: Dictionary
) -> Variant:
	if options.has("__gf_config_type_compiler"):
		var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(options)
		if not compiler.admit_value(value):
			_merge_report(
				report,
				compiler.get_report()
			)
			_finalize_report(report)
			return null
	else:
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
		if not budget.admit_value(value, "validation report data"):
			var budget_report: Dictionary = budget.get_report()
			_add_issue(
				report,
				"error",
				str(budget_report["error_kind"]),
				null,
				&"",
				str(budget_report["error"]),
				_make_record_context(null, options)
			)
			_finalize_report(report)
			return null
	if value is Dictionary:
		var record: Dictionary = value
		return record.duplicate(true)
	var rows: Array = value
	return rows.duplicate(true)


## 从记录的 ID 字段读取行键；无 ID 字段时返回默认值。
## [br]
## @api private
## [br]
func _get_record_row_key(record: Dictionary, default_value: Variant) -> Variant:
	if id_field == &"":
		return default_value
	return GFVariantData.get_option_value(
		record,
		id_field,
		default_value
	)


## 从行条目读取 record 字典。
## [br]
## @api private
## [br]
func _get_row_entry_record(row_entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(
		GFVariantData.get_option_value(
			row_entry,
			"record",
			{}
		)
	)


## 从行条目读取 row_key。
## [br]
## @api private
## [br]
func _get_row_entry_key(row_entry: Dictionary) -> Variant:
	return GFVariantData.get_option_value(row_entry, "row_key")


## 逐行验证数组表，并汇总有效行、重复 ID 和校验问题。
## [br]
## @api private
## [br]
func _validate_array_table(
	rows: Array,
	report: Dictionary,
	options: Dictionary
) -> void:
	report["row_count"] = rows.size()
	var seen_ids: Dictionary = {}
	var valid_rows: Array[Dictionary] = []
	var normalized_rows: Array[Dictionary] = []
	for index: int in range(rows.size()):
		var row: Variant = rows[index]
		if not (row is Dictionary):
			_add_issue(
				report,
				"error",
				"invalid_row",
				index,
				&"",
				"行数据必须是 Dictionary。",
				_make_record_context(
					index,
					_make_row_options(options, index)
				)
			)
			continue

		var record: Dictionary = GFVariantData.as_dictionary(row)
		var row_key: Variant = _get_record_row_key(record, index)
		var row_options: Dictionary = _make_row_options(options, index)
		var row_report: Dictionary = _make_report(1)
		var prepared: _PreparedValidationRecord = _prepare_record_for_validation(
			record,
			row_key,
			row_report,
			row_options
		)
		if not prepared._admitted:
			_finalize_report(row_report)
			_merge_report(report, row_report)
			continue
		var table_record: Dictionary = prepared._record.duplicate(true) if prepared._coerced else prepared._record
		normalized_rows.append(table_record)
		valid_rows.append(
			{
				"row_key": row_key,
				"row_index": index,
				"record": table_record,
			}
		)
		_validate_prepared_record(
			record,
			row_key,
			row_report,
			row_options,
			prepared
		)
		_finalize_report(row_report)
		_merge_report(report, row_report)
		_validate_unique_id(
			record,
			table_record,
			row_key,
			seen_ids,
			report,
			row_options
		)
	_validate_index_constraints(valid_rows, report)
	_validate_table_rules(
		valid_rows,
		report,
		options
	)
	report["data"] = null
	if report["ok"]:
		report["data"] = normalized_rows


## 验证字典表中的行记录及其键与 ID 关系。
## [br]
## @api private
## [br]
func _validate_dictionary_table(
	table: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> void:
	report["row_count"] = table.size()
	var seen_ids: Dictionary = {}
	var valid_rows: Array[Dictionary] = []
	var normalized_table: Dictionary = {}
	for key: Variant in table.keys():
		var row: Variant = table[key]
		if not (row is Dictionary):
			_add_issue(
				report,
				"error",
				"invalid_row",
				key,
				&"",
				"行数据必须是 Dictionary。",
				_make_record_context(key, options)
			)
			continue

		var record: Dictionary = GFVariantData.as_dictionary(row)
		var row_key: Variant = _get_record_row_key(record, key)
		var row_report: Dictionary = _make_report(1)
		var prepared: _PreparedValidationRecord = _prepare_record_for_validation(
			record,
			row_key,
			row_report,
			options
		)
		if not prepared._admitted:
			_finalize_report(row_report)
			_merge_report(report, row_report)
			continue
		var table_record: Dictionary = prepared._record.duplicate(true) if prepared._coerced else prepared._record
		normalized_table[key] = table_record
		valid_rows.append({ "row_key": row_key, "record": table_record, })
		_validate_prepared_record(
			record,
			row_key,
			row_report,
			options,
			prepared
		)
		_finalize_report(row_report)
		_merge_report(report, row_report)
		_validate_unique_id(
			record,
			table_record,
			row_key,
			seen_ids,
			report,
			options
		)
	_validate_index_constraints(valid_rows, report)
	_validate_table_rules(
		valid_rows,
		report,
		options
	)
	report["data"] = null
	if report["ok"]:
		report["data"] = normalized_table


## 创建包含表名和输入行数的验证报告。
## [br]
## @api private
## [br]
func _make_report(row_count: int) -> Dictionary:
	return _CONFIG_VALIDATION_REPORT.new().make_report(table_name, row_count)


## 校验列定义并检查字段标识、重复项和关联规则。
## [br]
## @api private
## [br]
func _validate_column_definitions(report: Dictionary, options: Dictionary) -> void:
	var seen_fields: Dictionary = {}
	for index: int in range(columns.size()):
		var column: GFConfigTableColumn = columns[index]
		var context: Dictionary = _make_definition_context(options, index)
		if column == null:
			_add_issue(
				report,
				"error",
				"null_column",
				null,
				&"",
				"字段声明为空。",
				context
			)
			continue

		var field_key: StringName = column.get_field_key()
		context["field"] = field_key
		if field_key == &"":
			_add_issue(
				report,
				"error",
				"empty_field",
				null,
				&"",
				"字段名为空。",
				context
			)
			continue
		if seen_fields.has(field_key):
			_add_issue(
				report,
				"error",
				"duplicate_column_field",
				null,
				field_key,
				"字段声明重复：%s。" % String(field_key),
				context
			)
		seen_fields[field_key] = true
		_validate_column_rule_definitions(
			column,
			report,
			context
		)


## 校验普通列的验证规则；结构列已由共享编译会话检查，避免重复报告同一声明错误。
## [br]
## @api private
## [br]
func _validate_column_rule_definitions(
	column: GFConfigTableColumn,
	report: Dictionary,
	context: Dictionary
) -> void:
	if column.type_definition != null:
		return
	var _elements_valid: bool = _validate_column_element_definition(
		column,
		report,
		context
	)
	for rule: GFConfigValidationRule in column.validation_rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_validation_rule",
				null,
				column.get_field_key(),
				"字段校验规则为空。",
				context
			)


## 校验索引定义、索引 ID 和字段引用。
## [br]
## @api private
## [br]
func _validate_index_definitions(report: Dictionary, options: Dictionary) -> void:
	var seen_index_ids: Dictionary = {}
	for index: GFConfigTableIndexDefinition in indexes:
		if index == null:
			_add_issue(
				report,
				"error",
				"null_index",
				null,
				&"",
				"索引声明为空。",
				_make_record_context(null, options)
			)
			continue
		if not index.is_valid_definition():
			_add_issue(
				report,
				"error",
				"invalid_index",
				null,
				&"",
				"索引声明无效。",
				_make_record_context(null, options)
			)
			continue

		var index_id: StringName = index.get_index_id()
		if seen_index_ids.has(index_id):
			_add_issue(
				report,
				"error",
				"duplicate_index_id",
				null,
				&"",
				"索引 ID 重复：%s。" % String(index_id),
				_make_record_context(null, options)
			)
		seen_index_ids[index_id] = true
		for field_name: String in index.field_names:
			if not has_column(StringName(field_name)):
				_add_issue(
					report,
					"error",
					"index_unknown_field",
					null,
					StringName(field_name),
					"索引字段未声明：%s。" % field_name,
					_make_field_context(
						null,
						StringName(field_name),
						options
					)
				)


## 校验表引用定义及其字段配置。
## [br]
## @api private
## [br]
func _validate_reference_definitions(report: Dictionary, options: Dictionary) -> void:
	var seen_reference_ids: Dictionary = {}
	for reference_definition: GFConfigTableReference in references:
		if reference_definition == null:
			_add_issue(
				report,
				"error",
				"null_reference",
				null,
				&"",
				"引用声明为空。",
				_make_record_context(null, options)
			)
			continue
		if not reference_definition.is_valid_definition():
			_add_issue(
				report,
				"error",
				"invalid_reference",
				null,
				&"",
				"引用声明无效。",
				_make_record_context(null, options)
			)
			continue

		var reference_id: StringName = reference_definition.get_reference_id()
		if seen_reference_ids.has(reference_id):
			_add_issue(
				report,
				"error",
				"duplicate_reference_id",
				null,
				&"",
				"引用 ID 重复：%s。" % String(reference_id),
				_make_record_context(null, options)
			)
		seen_reference_ids[reference_id] = true
		for field_name: String in reference_definition.source_fields:
			if not has_column(StringName(field_name)):
				_add_issue(
					report,
					"error",
					"reference_unknown_source_field",
					null,
					StringName(field_name),
					"引用来源字段未声明：%s。" % field_name,
					_make_field_context(
						null,
						StringName(field_name),
						options
					)
				)


## 校验记录级与表级验证规则定义。
## [br]
## @api private
## [br]
func _validate_rule_definitions(report: Dictionary, options: Dictionary) -> void:
	for rule: GFConfigValidationRule in record_validation_rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_record_validation_rule",
				null,
				&"",
				"记录校验规则为空。",
				_make_record_context(null, options)
			)
	for rule: GFConfigValidationRule in table_validation_rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_table_validation_rule",
				null,
				&"",
				"表校验规则为空。",
				_make_record_context(null, options)
			)


## 为单条记录准备可校验副本、列集合和元素批次。
## [br]
## @api private
## [br]
func _prepare_record_for_validation(
	record: Dictionary,
	row_key: Variant,
	report: Dictionary,
	options: Dictionary
) -> _PreparedValidationRecord:
	var prepared: _PreparedValidationRecord = _PreparedValidationRecord.new()
	if options.has("__gf_config_type_compiler"):
		var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(options)
		if not compiler.admit_value(record):
			_merge_report(
				report,
				compiler.get_report()
			)
			return prepared
	if not _validate_element_limits(report, options) or not _validate_element_definitions(report, options):
		return prepared
	prepared._columns = columns.duplicate()
	prepared._coerced = coerce_values
	if not prepared._coerced:
		prepared._record = record
		if options.has("__gf_config_type_compiler"):
			prepared._record = record.duplicate(true)
			var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(options)
			for column: GFConfigTableColumn in prepared._columns:
				if (
					column == null
					or column.type_definition == null
					or not record.has(column.field_name)
				):
					continue
				var field: Dictionary = compiler.compile_column(
					column,
					[str(column.field_name)]
				)
				var context: Dictionary = _make_field_context(
					row_key,
					column.field_name,
					options
				)
				context["coerce_values"] = false
				context["row_locations"] = options.get("row_locations", [])
				var value_report: Dictionary = compiler.normalize_column(
					field,
					record[column.field_name],
					context
				)
				_merge_report(report, value_report)
				prepared._record[column.field_name] = value_report["value"]
		prepared._admitted = true
		return prepared

	var _resized: int = prepared._element_batches.resize(prepared._columns.size())
	for column_index: int in range(prepared._columns.size()):
		var column: GFConfigTableColumn = prepared._columns[column_index]
		if column == null:
			continue
		var field_key: StringName = column.get_field_key()
		var value: Variant = record.get(field_key, column.default_value)
		var context: Dictionary = _make_field_context(
			row_key,
			field_key,
			options
		)
		var element_report: Dictionary = _make_report(0)
		# 预算拒绝不能触发元素遍历或记录深复制；成功预留也不因坏元素退还。
		var batch: _ElementValidationBatch = _prepare_element_batch(
			column,
			value,
			options,
			element_report,
			context
		)
		if batch != null:
			_validate_coerced_element_shapes(
				batch,
				row_key,
				field_key,
				element_report,
				context
			)
		_finalize_report(element_report)
		_merge_report(report, element_report)
		if not GFVariantData.get_option_bool(element_report, "ok"):
			return prepared
		prepared._element_batches[column_index] = batch

	prepared._record = _coerce_record_for_validation(
		record,
		row_key,
		report,
		options,
		prepared._columns
	)
	prepared._admitted = true
	return prepared


## 校验转换后的元素是否符合声明的元素形状。
## [br]
## @api private
## [br]
func _validate_coerced_element_shapes(
	batch: _ElementValidationBatch,
	row_key: Variant,
	field_key: StringName,
	report: Dictionary,
	context: Dictionary
) -> void:
	# 只访问已获预算的外层快照，不递归复制被拒绝的元素。
	for element_index: int in range(batch._elements.size()):
		var element: Variant = batch._elements[element_index]
		if _is_element_validation_value(element):
			continue
		var issue_context: Dictionary = context.duplicate(false)
		var _value_removed: bool = issue_context.erase("value")
		var _actual_removed: bool = issue_context.erase("actual_value")
		issue_context["element_index"] = element_index
		issue_context["actual_value"] = type_string(typeof(element))
		_add_issue(
			report,
			"error",
			"invalid_element_validation_value",
			row_key,
			field_key,
			"元素必须为单层值，不接受集合、对象或可执行引用。",
			issue_context
		)


## 对准备后的记录执行字段转换、字段规则和元素规则验证。
## [br]
## @api private
## [br]
func _validate_prepared_record(
	record: Dictionary,
	row_key: Variant,
	report: Dictionary,
	options: Dictionary,
	prepared: _PreparedValidationRecord
) -> void:
	var working_record: Dictionary = prepared._record
	var declared_fields: Dictionary = {}
	for column_index: int in range(prepared._columns.size()):
		var column: GFConfigTableColumn = prepared._columns[column_index]
		if column == null:
			_add_issue(
				report,
				"error",
				"null_column",
				row_key,
				&"",
				"字段声明为空。",
				_make_record_context(row_key, options)
			)
			continue

		var field_key: StringName = column.get_field_key()
		var field_context: Dictionary = _make_field_context(
			row_key,
			field_key,
			options
		)
		if field_key == &"":
			_add_issue(
				report,
				"error",
				"empty_field",
				row_key,
				&"",
				"字段名为空。",
				field_context
			)
			continue
		declared_fields[field_key] = true
		if column.required and not record.has(field_key):
			_add_issue(
				report,
				"error",
				"missing_required",
				row_key,
				field_key,
				"缺少必填字段：%s。" % str(field_key),
				_make_value_context(
					row_key,
					field_key,
					options,
					null,
					"present",
					"missing"
				)
			)
		if not working_record.has(field_key):
			continue

		var field_value: Variant = working_record[field_key]
		if column.type_definition != null:
			continue
		if field_value == null and not column.allow_null:
			_add_issue(
				report,
				"error",
				"null_value",
				row_key,
				field_key,
				"字段不允许为空：%s。" % str(field_key),
				_make_value_context(
					row_key,
					field_key,
					options,
					field_value,
					"non_null"
				)
			)
		elif not column.is_value_valid(field_value):
			_add_issue(
				report,
				"error",
				"invalid_type",
				row_key,
				field_key,
				"字段类型不匹配：%s。" % str(field_key),
				_make_value_context(
					row_key,
					field_key,
					options,
					field_value,
					_value_type_to_name(column.value_type)
				)
			)
		else:
			var batch: _ElementValidationBatch = null
			if prepared._coerced:
				batch = prepared._element_batches[column_index]
			_validate_column_rules(
				column,
				field_value,
				row_key,
				report,
				options,
				prepared._coerced,
				batch
			)

	if not allow_extra_fields:
		for field_variant: Variant in working_record.keys():
			var field_name: StringName = GFVariantData.to_string_name(field_variant)
			if not declared_fields.has(field_name):
				_add_issue(
					report,
					"error",
					"extra_field",
					row_key,
					field_name,
					"存在未声明字段：%s。" % str(field_name),
					_make_value_context(
						row_key,
						field_name,
						options,
						GFVariantData.get_option_value(working_record, field_name),
						"declared_field"
					)
				)
	_validate_record_rules(
		working_record,
		row_key,
		report,
		options
	)


## 按验证列将记录字段转换为声明的值类型并报告转换问题。
## [br]
## @api private
## [br]
func _coerce_record_for_validation(
	record: Dictionary,
	row_key: Variant,
	report: Dictionary,
	options: Dictionary,
	validation_columns: Array[GFConfigTableColumn]
) -> Dictionary:
	var result: Dictionary = GFVariantData.as_dictionary(GFVariantData.duplicate_variant(record))
	for column: GFConfigTableColumn in validation_columns:
		if column == null or column.get_field_key() == &"":
			continue

		var field_key: StringName = column.get_field_key()
		var has_value: bool = result.has(field_key)
		if not has_value and column.default_value == null:
			continue

		var source_value: Variant = result[field_key] if has_value else column.default_value
		var coerce_options: Dictionary = options.merged(
			_make_field_context(
				row_key,
				field_key,
				options
			),
			true
		)
		var coerce_result: Dictionary = column.try_coerce_value(source_value, coerce_options)
		result[field_key] = GFVariantData.get_option_value(coerce_result, "value")
		if column.type_definition != null:
			_merge_report(report, coerce_result)
			continue
		if fail_on_coerce_error and not GFVariantData.get_option_bool(
			coerce_result,
			"ok",
			false
		):
			_add_issue(
				report,
				"error",
				"coerce_failed",
				row_key,
				field_key,
				GFVariantData.get_option_string(
					coerce_result,
					"message",
					"字段类型转换失败：%s。" % str(field_key)
				),
				_make_value_context(
					row_key,
					field_key,
					options,
					source_value,
					_value_type_to_name(column.value_type)
				)
			)
	return result


## 检查原记录中已存在的 ID，复用本次准备结果，不重新转换或执行字段规则。
## [br]
## @api private
## [br]
func _validate_unique_id(
	record: Dictionary,
	prepared_record: Dictionary,
	row_key: Variant,
	seen_ids: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> void:
	if (
		not require_unique_id
		or id_field == &""
		or not record.has(id_field)
	):
		return

	var id_value: Variant = prepared_record.get(
		id_field,
		record[id_field]
	)

	var id_key: String = _make_variant_key(id_value)
	if seen_ids.has(id_key):
		_add_issue(
			report,
			"error",
			"duplicate_id",
			row_key,
			id_field,
			"记录 ID 重复：%s。" % str(id_value),
			_make_field_context(
				row_key,
				id_field,
				options
			)
		)
		return

	seen_ids[id_key] = row_key


## 按索引定义检查记录集合的唯一性等约束。
## [br]
## @api private
## [br]
func _validate_index_constraints(rows: Array[Dictionary], report: Dictionary) -> void:
	for index: GFConfigTableIndexDefinition in indexes:
		if index == null:
			_add_issue(
				report,
				"error",
				"null_index",
				null,
				&"",
				"索引声明为空。"
			)
			continue
		if not index.is_valid_definition():
			_add_issue(
				report,
				"error",
				"invalid_index",
				null,
				&"",
				"索引声明无效。"
			)
			continue
		for field_name: String in index.field_names:
			if not has_column(StringName(field_name)):
				_add_issue(
					report,
					"error",
					"index_unknown_field",
					null,
					StringName(field_name),
					"索引字段未声明：%s。" % field_name
				)
		if not index.unique:
			continue

		var seen_keys: Dictionary = {}
		for row_entry: Dictionary in rows:
			var record: Dictionary = _get_row_entry_record(row_entry)
			var key: String = index.make_key(record)
			if key.is_empty():
				continue
			if seen_keys.has(key):
				_add_issue(
					report,
					"error",
					"duplicate_index_key",
					_get_row_entry_key(row_entry),
					&"",
					"唯一索引重复：%s。" % String(index.get_index_id())
				)
				continue
			seen_keys[key] = _get_row_entry_key(row_entry)


## 将 Variant 的类型和值文本组合成稳定比较键。
## [br]
## @api private
## [br]
func _make_variant_key(value: Variant) -> String:
	return (
		"%d:%s"
		% [typeof(value), str(value)]
	)


## 使用指定列的规则验证单个字段值。
## [br]
## @api private
## [br]
func _validate_column_rules(
	column: GFConfigTableColumn,
	value: Variant,
	row_key: Variant,
	report: Dictionary,
	options: Dictionary,
	was_prepared: bool = false,
	prepared_batch: _ElementValidationBatch = null
) -> void:
	var context: Dictionary = _make_field_context(
		row_key,
		column.get_field_key(),
		options
	)
	var rules: Array[GFConfigValidationRule] = column.validation_rules.duplicate()
	var element_report: Dictionary = _make_report(0)
	# 在任意项目规则回调前固定当前字段的元素与规则边界，不深拷贝未经检查的集合。
	var batch: _ElementValidationBatch = prepared_batch
	if not was_prepared:
		batch = _prepare_element_batch(
			column,
			value,
			options,
			element_report,
			context
		)
	for rule: GFConfigValidationRule in rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_validation_rule",
				row_key,
				column.get_field_key(),
				"字段校验规则为空。",
				_make_field_context(
					row_key,
					column.get_field_key(),
					options
				)
			)
			continue
		_merge_report(
			report,
			rule.validate_value(
				value,
				GFVariantData.as_dictionary(GFVariantData.duplicate_variant(context))
			)
		)
	_finalize_report(element_report)
	_merge_report(report, element_report)
	if batch != null:
		_validate_element_batch(
			batch,
			report,
			context
		)


## 检查本次验证的元素数及规则检查预算是否在上限内。
## [br]
## @api private
## [br]
func _validate_element_limits(report: Dictionary, options: Dictionary) -> bool:
	if (
		max_elements_per_validation >= 1
		and max_elements_per_validation <= _MAX_ELEMENTS_PER_VALIDATION
		and max_element_rule_checks_per_validation >= 1
		and max_element_rule_checks_per_validation <= _MAX_ELEMENT_RULE_CHECKS_PER_VALIDATION
	):
		return true
	_add_issue(
		report,
		"error",
		"invalid_element_validation_limits",
		null,
		&"",
		"元素数或元素规则调用预算超出允许范围。",
		_make_record_context(null, options)
	)
	return false


## 校验列上声明的元素规则及其适用类型。
## [br]
## @api private
## [br]
func _validate_element_definitions(report: Dictionary, options: Dictionary) -> bool:
	var valid: bool = true
	for column: GFConfigTableColumn in columns:
		if column != null:
			var context: Dictionary = _make_field_context(
				null,
				column.get_field_key(),
				options
			)
			if not _validate_column_element_definition(
				column,
				report,
				context
			):
				valid = false
	return valid


## 检查单列元素规则仅配置在允许的数组列上。
## [br]
## @api private
## [br]
func _validate_column_element_definition(
	column: GFConfigTableColumn,
	report: Dictionary,
	context: Dictionary
) -> bool:
	var issue: Dictionary = GFConfigElementValidation.get_definition_issue(column.value_type, column.element_validation_rules)
	if issue.is_empty():
		return true
	var issue_kind: String = issue["kind"]
	var issue_message: String = issue["message"]
	_add_issue(
		report,
		"error",
		issue_kind,
		null,
		column.get_field_key(),
		issue_message,
		context
	)
	return false


## 复制选项并复用或创建共享元素规则预算会话。
## [br]
## @api private
## [br]
func _with_element_validation_session(options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(false)
	result[_ELEMENT_VALIDATION_SESSION_KEY] = GFConfigElementValidation.from_options(
		options,
		max_elements_per_validation,
		max_element_rule_checks_per_validation
	)
	return result


## 为数组字段整理待验证元素和适用规则，并预留预算。
## [br]
## @api private
## [br]
func _prepare_element_batch(
	column: GFConfigTableColumn,
	value: Variant,
	options: Dictionary,
	report: Dictionary,
	context: Dictionary
) -> _ElementValidationBatch:
	if not _validate_column_element_definition(
		column,
		report,
		context
	):
		return null
	if value == null or column.element_validation_rules.is_empty():
		return null
	var rules: Array[GFConfigValidationRule] = []
	for rule: GFConfigValidationRule in column.element_validation_rules:
		if rule.enabled:
			rules.append(rule)
	if rules.is_empty() or not value is Array:
		return null
	var elements: Array = value
	var session_value: Variant = GFVariantData.get_option_value(options, _ELEMENT_VALIDATION_SESSION_KEY)
	if not session_value is GFConfigElementValidation:
		return null
	var session: GFConfigElementValidation = session_value
	if not session.reserve(
		elements.size(),
		rules.size()
	):
		var issue_context: Dictionary = context.duplicate(false)
		issue_context["expected_value"] = "remaining element and rule-call budgets"
		_add_issue(
			report,
			"error",
			"element_validation_budget_exhausted",
			context.get("row_key"),
			column.get_field_key(),
			"数组字段超过本次剩余元素或规则调用预算，未执行该字段的元素规则。",
			issue_context
		)
		return null
	var batch: _ElementValidationBatch = _ElementValidationBatch.new()
	batch._elements = elements.duplicate(false)
	batch._rules = rules
	return batch


## 按元素批次运行规则并累积字段级诊断。
## [br]
## @api private
## [br]
func _validate_element_batch(
	batch: _ElementValidationBatch,
	report: Dictionary,
	context: Dictionary
) -> void:
	for element_index: int in range(batch._elements.size()):
		var value: Variant = batch._elements[element_index]
		var element_context: Dictionary = context.duplicate(false)
		element_context["element_index"] = element_index
		if not _is_element_validation_value(value):
			var _value_removed: bool = element_context.erase("value")
			var _actual_removed: bool = element_context.erase("actual_value")
			element_context["actual_value"] = type_string(typeof(value))
			_add_issue(
				report,
				"error",
				"invalid_element_validation_value",
				context.get("row_key"),
				GFVariantData.get_option_string_name(context, "field"),
				"元素必须为单层值，不接受集合、对象或可执行引用。",
				element_context
			)
			continue
		for rule: GFConfigValidationRule in batch._rules:
			_merge_report(
				report,
				rule.validate_value(
					value,
					GFVariantData.as_dictionary(GFVariantData.duplicate_variant(element_context))
				)
			)


## 判断 Variant 值是否属于允许传入元素规则验证的普通值。
## [br]
## @api private
## [br]
func _is_element_validation_value(value: Variant) -> bool:
	return GFConfigElementValidation.is_value_supported(value)


## 运行全部记录级规则并将结果写入报告。
## [br]
## @api private
## [br]
func _validate_record_rules(
	record: Dictionary,
	row_key: Variant,
	report: Dictionary,
	options: Dictionary
) -> void:
	for rule: GFConfigValidationRule in record_validation_rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_record_validation_rule",
				row_key,
				&"",
				"记录校验规则为空。",
				_make_record_context(row_key, options)
			)
			continue
		_merge_report(
			report,
			rule.validate_record(
				record,
				_make_record_context(row_key, options)
			)
		)


## 运行全部表级规则并将结果写入报告。
## [br]
## @api private
## [br]
func _validate_table_rules(
	rows: Array[Dictionary],
	report: Dictionary,
	options: Dictionary
) -> void:
	for rule: GFConfigValidationRule in table_validation_rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_table_validation_rule",
				null,
				&"",
				"表校验规则为空。",
				_make_record_context(null, options)
			)
			continue
		_merge_report(
			report,
			rule.validate_table(
				rows,
				_make_record_context(null, options)
			)
		)


## 将非空验证规则转换为描述字典数组。
## [br]
## @api private
## [br]
func _describe_validation_rules(rules: Array[GFConfigValidationRule]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule: GFConfigValidationRule in rules:
		if rule != null:
			result.append(rule.describe())
	return result


## 向报告追加带上下文的验证问题。
## [br]
## @api private
## [br]
func _add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	row_key: Variant,
	field_name: StringName,
	message: String,
	context: Dictionary = {}
) -> void:
	_CONFIG_VALIDATION_REPORT.new().add_issue(
		report,
		severity,
		kind,
		table_name,
		row_key,
		field_name,
		message,
		context
	)


## 合并来源验证报告及其问题。
## [br]
## @api private
## [br]
func _merge_report(target: Dictionary, source: Dictionary) -> void:
	_CONFIG_VALIDATION_REPORT.new().merge_report(target, source)


## 完成报告计数和汇总字段。
## [br]
## @api private
## [br]
func _finalize_report(report: Dictionary) -> void:
	_CONFIG_VALIDATION_REPORT.new().finalize_report(report)


## 复制选项并设置当前行索引。
## [br]
## @api private
## [br]
func _make_row_options(options: Dictionary, row_index: int) -> Dictionary:
	# 此内部视图只修改 row_index；全表 row_locations 只读共享，避免每行复制整表。
	# 规则收到的上下文仍由 _copy_context_fields 逐字段复制，不暴露此视图。
	var result: Dictionary = options.duplicate(false)
	result["row_index"] = row_index
	return result


## 为列定义校验构造带列索引的诊断上下文。
## [br]
## @api private
## [br]
func _make_definition_context(options: Dictionary, column_index: int) -> Dictionary:
	var context: Dictionary = _make_record_context(null, options)
	context["column_index"] = column_index
	return context


## 构造包含表名、行键和来源位置的记录上下文。
## [br]
## @api private
## [br]
func _make_record_context(row_key: Variant, options: Dictionary) -> Dictionary:
	var context: Dictionary = { "table_name": table_name, "row_key": row_key, }
	_copy_context_fields(context, options)
	_apply_row_location(
		context,
		&"",
		options
	)
	return context


## 构造包含表名、行键和字段名的诊断上下文。
## [br]
## @api private
## [br]
func _make_field_context(
	row_key: Variant,
	field_name: StringName,
	options: Dictionary
) -> Dictionary:
	var context: Dictionary = {
		"table_name": table_name,
		"row_key": row_key,
		"field": field_name,
	}
	_copy_context_fields(context, options)
	if options.has(_RESOURCE_PATH_VALIDATION_SESSION_KEY):
		context[_RESOURCE_PATH_VALIDATION_SESSION_KEY] = options[_RESOURCE_PATH_VALIDATION_SESSION_KEY]
	_apply_row_location(
		context,
		field_name,
		options
	)
	return context


## 复制选项并复用或创建资源路径校验共享会话。
## [br]
## @api private
## [br]
func _with_resource_path_validation_session(options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(false)
	var session_value: Variant = GFVariantData.get_option_value(result, _RESOURCE_PATH_VALIDATION_SESSION_KEY)
	if not _RESOURCE_PATH_VALIDATION_RULE._is_validation_session(session_value):
		result[_RESOURCE_PATH_VALIDATION_SESSION_KEY] = _RESOURCE_PATH_VALIDATION_RULE._make_validation_session(max_resource_path_checks_per_validation)
	return result


## 构造用于字段值校验的完整诊断上下文。
## [br]
## @api private
## [br]
func _make_value_context(
	row_key: Variant,
	field_name: StringName,
	options: Dictionary,
	field_value: Variant,
	expected_value: Variant,
	actual_value: Variant = null
) -> Dictionary:
	var context: Dictionary = _make_field_context(
		row_key,
		field_name,
		options
	)
	context["value"] = GFVariantData.duplicate_variant(field_value)
	context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	context["actual_value"] = GFVariantData.duplicate_variant(field_value if actual_value == null else actual_value)
	return context


## 将受支持的位置字段从来源上下文复制到目标上下文。
## [br]
## @api private
## [br]
func _copy_context_fields(target: Dictionary, source: Dictionary) -> void:
	for field_name: String in [
		"source",
		"field_path",
		"field_segments",
		"sheet_name",
		"sheet_path",
		"cell",
		"line",
		"column",
		"row_index",
		"column_index",
		"rule_id",
		"value",
		"expected_value",
		"actual_value",
		"supported_values",
		"supported_formats",
		"supported_content_types",
	]:
		if source.has(field_name):
			target[field_name] = GFVariantData.duplicate_variant(source[field_name])


## 将解析结果中的行号与源位置补入诊断上下文。
## [br]
## @api private
## [br]
func _apply_row_location(
	context: Dictionary,
	field_name: StringName,
	options: Dictionary
) -> void:
	var row_index: int = GFVariantData.get_option_int(
		options,
		"row_index",
		-1
	)
	var row_locations: Variant = GFVariantData.get_option_value(
		options,
		"row_locations",
		[]
	)
	if row_index < 0 or not (row_locations is Array):
		return
	var locations: Array = GFVariantData.as_array(row_locations)
	if row_index >= locations.size() or not (locations[row_index] is Dictionary):
		return

	var row_location: Dictionary = GFVariantData.as_dictionary(locations[row_index])
	_copy_context_fields(context, row_location)
	var field_locations: Variant = GFVariantData.get_option_value(
		row_location,
		"fields",
		{}
	)
	if not (field_locations is Dictionary) or field_name == &"":
		return
	var fields: Dictionary = GFVariantData.as_dictionary(field_locations)
	var field_location: Variant = GFVariantData.get_option_value(fields, field_name)
	if field_location is Dictionary:
		_copy_context_fields(
			context,
			GFVariantData.as_dictionary(field_location)
		)


## 把字段值追加到 field_name 对应的收集数组。
## [br]
## @api private
## [br]
static func _append_field_value(
	field_values: Dictionary,
	field_name: StringName,
	value: Variant
) -> void:
	var values: Array = _get_field_values(field_values, field_name)
	values.append(value)
	field_values[field_name] = values


## 读取字段对应的已收集值数组。
## [br]
## @api private
## [br]
static func _get_field_values(field_values: Dictionary, field_name: StringName) -> Array:
	return GFVariantData.as_array(
		GFVariantData.get_option_value(
			field_values,
			field_name,
			[]
		)
	)


## 向 PackedStringArray 追加一个字符串。
## [br]
## @api private
## [br]
static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


## 将数组表或字典表规范化为列类型推断用的记录行。
## [br]
## @api private
## [br]
static func _normalize_inference_rows(table_data: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		for row_variant: Variant in table_data:
			if row_variant is Dictionary:
				rows.append(GFVariantData.as_dictionary(row_variant).duplicate(true))
	elif table_data is Dictionary:
		var table: Dictionary = GFVariantData.as_dictionary(table_data)
		for key: Variant in table.keys():
			var row_variant: Variant = table[key]
			if row_variant is Dictionary:
				rows.append(GFVariantData.as_dictionary(row_variant).duplicate(true))
	return rows


## 根据一组非空值推断配置列值类型。
## [br]
## @api private
## [br]
static func _infer_column_value_type(values: Array) -> GFConfigTableColumn.ValueType:
	var inferred_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.ANY
	for value: Variant in values:
		if value == null:
			continue

		var value_type: GFConfigTableColumn.ValueType = _value_to_column_type(value)
		if inferred_type == GFConfigTableColumn.ValueType.ANY:
			inferred_type = value_type
		elif inferred_type == GFConfigTableColumn.ValueType.INT and value_type == GFConfigTableColumn.ValueType.FLOAT:
			inferred_type = GFConfigTableColumn.ValueType.FLOAT
		elif inferred_type == GFConfigTableColumn.ValueType.FLOAT and value_type == GFConfigTableColumn.ValueType.INT:
			continue
		elif inferred_type != value_type:
			return GFConfigTableColumn.ValueType.ANY
	return inferred_type


## 将单个 Variant 类型映射为配置列值类型。
## [br]
## @api private
## [br]
static func _value_to_column_type(value: Variant) -> GFConfigTableColumn.ValueType:
	match typeof(value):
		TYPE_BOOL:
			return GFConfigTableColumn.ValueType.BOOL
		TYPE_INT:
			return GFConfigTableColumn.ValueType.INT
		TYPE_FLOAT:
			return GFConfigTableColumn.ValueType.FLOAT
		TYPE_STRING:
			return GFConfigTableColumn.ValueType.STRING
		TYPE_STRING_NAME:
			return GFConfigTableColumn.ValueType.STRING_NAME
		TYPE_DICTIONARY:
			return GFConfigTableColumn.ValueType.DICTIONARY
		TYPE_ARRAY:
			return GFConfigTableColumn.ValueType.ARRAY
		_:
			if value is Vector2:
				return GFConfigTableColumn.ValueType.VECTOR2
			if value is Vector2i:
				return GFConfigTableColumn.ValueType.VECTOR2I
			if value is Color:
				return GFConfigTableColumn.ValueType.COLOR
	return GFConfigTableColumn.ValueType.ANY


## 将配置列值类型转换为显示用名称。
## [br]
## @api private
## [br]
static func _value_type_to_name(value_type: GFConfigTableColumn.ValueType) -> String:
	match value_type:
		GFConfigTableColumn.ValueType.BOOL:
			return "bool"
		GFConfigTableColumn.ValueType.INT:
			return "int"
		GFConfigTableColumn.ValueType.FLOAT:
			return "float"
		GFConfigTableColumn.ValueType.STRING:
			return "String"
		GFConfigTableColumn.ValueType.STRING_NAME:
			return "StringName"
		GFConfigTableColumn.ValueType.VECTOR2:
			return "Vector2"
		GFConfigTableColumn.ValueType.VECTOR2I:
			return "Vector2i"
		GFConfigTableColumn.ValueType.COLOR:
			return "Color"
		GFConfigTableColumn.ValueType.DICTIONARY:
			return "Dictionary"
		GFConfigTableColumn.ValueType.ARRAY:
			return "Array"
		_:
			return "any"


## 检查值集合中是否含有 null。
## [br]
## @api private
## [br]
static func _values_allow_null(values: Array) -> bool:
	for value: Variant in values:
		if value == null:
			return true
	return false


# --- 内部类 ---

## 保存一个字段待校验元素与对应规则的内部批次对象。
## [br]
## @api private
## [br]
class _ElementValidationBatch:
	extends RefCounted


	# --- 私有变量 ---

	## 获准校验的外层元素快照；拒绝的嵌套集合不会为此递归复制。
	## [br]
	## @api private
	var _elements: Array = []

	## 本批次筛选后的元素规则引用，按存储顺序对每个元素执行。
	## [br]
	## @api private
	var _rules: Array[GFConfigValidationRule] = []


## 保存单条记录验证过程中的副本、列和预处理状态。
## [br]
## @api private
## [br]
class _PreparedValidationRecord:
	extends RefCounted


	# --- 私有变量 ---

	## 预处理完成后才置为 true；为 false 时调用方跳过后续记录与表规则。
	## [br]
	## @api private
	var _admitted: bool = false

	## 本次是否启用转换；决定是否读取预先准备的元素批次。
	## [br]
	## @api private
	var _coerced: bool = false

	## 后续规则使用的记录；未转换时保留原记录引用，转换时使用转换结果副本。
	## [br]
	## @api private
	var _record: Dictionary = {}

	## 预处理时取得的列列表，用相同下标与元素批次对应。
	## [br]
	## @api private
	var _columns: Array[GFConfigTableColumn] = []

	## 转换模式下按列索引保存获预算的元素批次；无元素规则的列可为 null。
	## [br]
	## @api private
	var _element_batches: Array[_ElementValidationBatch] = []
