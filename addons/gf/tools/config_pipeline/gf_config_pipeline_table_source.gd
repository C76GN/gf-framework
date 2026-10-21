@tool

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

## 传给解析器的选项。CSV/XLSX 可显式使用 layout 把物理单元格映射为嵌套记录；类型转换仍由 schema 统一执行。
##
## layout 默认 orientation=rows、header_rows=[1]、blank_rows=reject；columns 缺省时，
## 各表头行的非空标签原样组成对象路径，不拆分标签内的点号。显式 columns 的每项包含
## column（一基逻辑列）与 path（String 键或零基 int 数组下标）；数组下标必须顺序填充。
## collections 每项包含 kind=array|map、path、columns，map 另含 key_column。
## 集合 columns 的 path 相对元素；唯一空 path 表示标量元素。
## record_key_column 启用连续记录分组：相同键或空键续行，孤立空键及非连续重复键失败；
## 同组标量重复值必须一致。集合每个有值的物理行追加一个元素，map 重复键失败。
## 空单元格是缺失，不生成 null；可用 empty_string_token 显式表达空字符串。
## ignored_columns 必须明确列出忽略列，未绑定列的非空数据失败。
## orientation=columns 转置逻辑布局但保留物理来源；header_rows 使用转置后的坐标。
## 结构化模式不能混用旧 header_row、注释列/行或条件指令选项；XLSX 合并区域只允许表头内，
## sheet_names 可按明确顺序合并多工作表，不跨工作表续行，也不隐式合并同名记录。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema parse_options: Dictionary，可包含 GFConfigTableImporter 的平表选项；XLSX 另含 sheet_name、sheet_index 或互斥的 sheet_names:Array[String]。CSV/XLSX 的 layout:Dictionary 仅接受 orientation、header_rows、columns、collections、record_key_column、ignored_columns、blank_rows、empty_string_token，详见字段说明；所有嵌套工作量共用入口预算，解析选项不能声明 work_limits/work_budget。
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


## 创建同内容拷贝；显式 Schema 复制失败时拒绝整个来源，不转为自动推断。
## Schema 委托 duplicate_schema()；扩展 Schema 应覆盖该方法以保留自定义声明。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新来源声明资源；Schema 超出复制边界或资源实例创建失败时返回 null。
func duplicate_source() -> GFConfigPipelineTableSource:
	var copied_schema: GFConfigTableSchema = null
	if schema != null:
		copied_schema = schema.duplicate_schema()
		if copied_schema == null:
			return null
	# 仅在显式 Schema 准入后复制原生资源，保留子类导出字段及 Resource 元数据。
	var created_source: Variant = duplicate(true)
	if not (created_source is GFConfigPipelineTableSource):
		return null

	var source: GFConfigPipelineTableSource = created_source
	source.schema = copied_schema
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

## 根据路径扩展名推断 CSV、JSON、ConfigFile 或 XLSX；未知扩展名返回 FORMAT_AUTO。
## [br]
## @api private
## [br]
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


## 从路径文件名移除末尾扩展名作为表名；没有文件名时返回空 StringName。
## [br]
## @api private
## [br]
func _table_name_from_path(path: String) -> StringName:
	var file_name: String = path.get_file()
	if file_name.is_empty():
		return &""

	var extension: String = file_name.get_extension()
	if extension.is_empty():
		return StringName(file_name)
	return StringName(file_name.trim_suffix("." + extension))
