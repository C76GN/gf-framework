## GFConfigPipelineTableSource: 配置导表工具的单表来源声明。
##
## 描述一张配置表的输入路径、格式、schema、解析选项和导出元数据。
## 该资源属于可选 tool package，只表达制作期或 CI 期通用导入来源，不规定项目表名、业务字段、目录结构或发布策略。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 5.2.0
class_name GFConfigPipelineTableSource
extends Resource


# --- 常量 ---

## 根据 source_path 扩展名推断输入格式。
## [br]
## @api public
## [br]
## @since 5.2.0
const FORMAT_AUTO: StringName = &"auto"

## CSV 输入格式。
## [br]
## @api public
## [br]
## @since 5.2.0
const FORMAT_CSV: StringName = &"csv"

## JSON 输入格式。
## [br]
## @api public
## [br]
## @since 5.2.0
const FORMAT_JSON: StringName = &"json"

## Godot ConfigFile 输入格式。
## [br]
## @api public
## [br]
## @since 7.0.0
const FORMAT_CONFIG_FILE: StringName = &"config_file"

## XLSX 输入格式。
## [br]
## @api public
## [br]
## @since 5.2.0
const FORMAT_XLSX: StringName = &"xlsx"


# --- 导出变量 ---

## 表名。为空时会尝试使用 schema.table_name 或 source_path 文件名。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var table_name: StringName = &""

## 输入文件路径。支持 Godot 可读取的 res://、user:// 或绝对路径。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var source_path: String = ""

## 输入格式。使用 FORMAT_AUTO 时根据 source_path 扩展名推断。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var source_format: StringName = FORMAT_AUTO

## 可选 schema。为空且 infer_schema 为 true 时，会从记录样本推导通用 schema。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var schema: GFConfigTableSchema = null

## 是否在缺少 schema 时从导入记录推导通用 schema。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var infer_schema: bool = true

## 是否在 schema.coerce_values 为 true 时把保存进资源的记录也转换为 schema 类型。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var coerce_records: bool = true

## 传给解析器的选项，例如 CSV delimiter、trim_cells、skip_empty_lines、comment_prefixes、condition_symbols，ConfigFile section_field、include_empty_sections，或 XLSX sheet_name、sheet_index、header_row。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema parse_options: Dictionary，可包含 GFConfigTableImporter 支持的 CSV / JSON / ConfigFile 解析选项，以及 XLSX sheet_name、sheet_index、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、comment_prefixes、comment_row_prefixes、comment_column_prefixes、condition_symbols 和 enable_condition_directives。
@export var parse_options: Dictionary = {}

## schema 推导与表头声明选项，例如 id_field、allow_extra_fields、required_if_present_in_all_rows、typed_headers 或 typed_header_type_row。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema schema_options: Dictionary，可包含 GFConfigTableSchema.infer_from_records() 支持的选项，以及 typed_headers、typed_header_type_row、coerce_values、fail_on_coerce_error、require_unique_id。
@export var schema_options: Dictionary = {}

## 附加到生成表资源的元数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema metadata: Dictionary，保存项目工具、编辑器或 CI 附加的来源信息。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定表键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 表名；无法从 table_name、schema 或 source_path 推断时返回空 StringName。
func get_table_key() -> StringName:
	if table_name != &"":
		return table_name
	if schema != null and schema.get_table_key() != &"":
		return schema.get_table_key()
	return _table_name_from_path(source_path)


## 获取声明或推断出的来源格式。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: FORMAT_CSV、FORMAT_JSON、FORMAT_CONFIG_FILE、FORMAT_AUTO 或调用方设置的自定义格式名。
func get_resolved_format() -> StringName:
	if source_format != &"" and source_format != FORMAT_AUTO:
		return source_format
	return _format_from_path(source_path)


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新来源声明资源。
func duplicate_source() -> GFConfigPipelineTableSource:
	var script_value: Variant = get_script()
	var created_source: Variant = null
	if script_value is GDScript:
		var gdscript: GDScript = script_value
		created_source = gdscript.new()
	if not (created_source is GFConfigPipelineTableSource):
		return GFConfigPipelineTableSource.new()

	var source: GFConfigPipelineTableSource = created_source
	source.table_name = table_name
	source.source_path = source_path
	source.source_format = source_format
	source.schema = schema.duplicate_schema() if schema != null else null
	source.infer_schema = infer_schema
	source.coerce_records = coerce_records
	source.parse_options = parse_options.duplicate(true)
	source.schema_options = schema_options.duplicate(true)
	source.metadata = metadata.duplicate(true)
	return source


## 导出来源声明摘要。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 来源声明字典。
## [br]
## @schema return: Dictionary，包含 table_name、source_path、source_format、resolved_format、schema、schema_path、infer_schema、coerce_records、parse_options、schema_options 和 metadata。
func describe() -> Dictionary:
	return {
		"table_name": get_table_key(),
		"source_path": source_path,
		"source_format": source_format,
		"resolved_format": get_resolved_format(),
		"schema": schema.describe() if schema != null else {},
		"schema_path": schema.resource_path if schema != null else "",
		"infer_schema": infer_schema,
		"coerce_records": coerce_records,
		"parse_options": parse_options.duplicate(true),
		"schema_options": schema_options.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _format_from_path(path: String) -> StringName:
	var extension: String = path.get_extension().to_lower()
	if extension == "csv":
		return FORMAT_CSV
	if extension == "json":
		return FORMAT_JSON
	if extension == "cfg" or extension == "ini":
		return FORMAT_CONFIG_FILE
	if extension == "xlsx":
		return FORMAT_XLSX
	return FORMAT_AUTO


func _table_name_from_path(path: String) -> StringName:
	var file_name: String = path.get_file()
	if file_name.is_empty():
		return &""

	var extension: String = file_name.get_extension()
	if extension.is_empty():
		return StringName(file_name)
	return StringName(file_name.trim_suffix("." + extension))
