## GFConfigPipelineTableIR: Config Pipeline 的版本化单表中间表示。
##
## 保存布局解析与语义校验后的规范记录、schema、来源映射和元数据。
## IR 只描述可物化的数据，不负责读取来源、生成 Resource 或提交文件。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineTableIR
extends RefCounted


# --- 常量 ---

## 单表 IR 的稳定格式标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT: String = "gf.config_pipeline.table_ir"

## 单表 IR 的格式版本。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT_VERSION: int = 1


# --- 私有变量 ---

var _table_name: StringName = &""
var _source_path: String = ""
var _source_format: StringName = &""
var _records: Array[Dictionary] = []
var _schema: GFConfigTableSchema = null
var _source_map: Dictionary = {}
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 创建单表 IR，并取得所有可变输入的副本所有权。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param table_name: 稳定表名。
## [br]
## @param source_path: 原始来源路径；内存来源可为空。
## [br]
## @param source_format: 已解析的来源格式。
## [br]
## @param records: 已规范化并完成类型转换的记录。
## [br]
## @schema records: Array[Dictionary]，每个 Dictionary 是一条规范配置记录。
## [br]
## @param schema: 已解析的表结构；可为空。
## [br]
## @param source_map: 来源定位信息。
## [br]
## @schema source_map: Dictionary，可包含 header、row_locations、source 和格式专属定位数据。
## [br]
## @param metadata: 与目标无关的表元数据。
## [br]
## @schema metadata: Dictionary，保存来源摘要和调用方附加元数据。
## [br]
## @return: 新建的单表 IR。
static func create(
	table_name: StringName,
	source_path: String,
	source_format: StringName,
	records: Array[Dictionary],
	schema: GFConfigTableSchema = null,
	source_map: Dictionary = {},
	metadata: Dictionary = {}
) -> GFConfigPipelineTableIR:
	var table_ir: GFConfigPipelineTableIR = GFConfigPipelineTableIR.new()
	table_ir._table_name = table_name
	table_ir._source_path = source_path
	table_ir._source_format = source_format
	table_ir._records = _duplicate_records(records)
	table_ir._schema = schema.duplicate_schema() if schema != null else null
	table_ir._source_map = source_map.duplicate(true)
	table_ir._metadata = metadata.duplicate(true)
	return table_ir


## 校验 IR 自身的版本和结构契约。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 契约校验结果。
## [br]
## @schema return: Dictionary，包含 success、error_code、error_kind 和 error。
func validate_contract() -> Dictionary:
	if _table_name == &"":
		return _make_contract_failure("empty_table_name", "Table IR 的表名为空。")
	if _source_format == &"":
		return _make_contract_failure("empty_source_format", "Table IR 的来源格式为空。")
	if _schema != null and _schema.get_table_key() != &"" and _schema.get_table_key() != _table_name:
		return _make_contract_failure(
			"schema_table_mismatch",
			"Table IR 的 schema 表名与 IR 表名不一致：%s != %s。" % [
				String(_schema.get_table_key()),
				String(_table_name),
			]
		)
	return {
		"success": true,
		"error_code": OK,
		"error_kind": "",
		"error": "",
	}


## 获取表名。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 稳定表名。
func get_table_name() -> StringName:
	return _table_name


## 获取来源路径。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 原始来源路径。
func get_source_path() -> String:
	return _source_path


## 获取已解析的来源格式。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 来源格式。
func get_source_format() -> StringName:
	return _source_format


## 获取规范记录。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 规范记录列表。
## [br]
## @schema return: Array[Dictionary]，每个 Dictionary 是一条规范配置记录。
func get_records() -> Array[Dictionary]:
	return _duplicate_records(_records)


## 获取表结构。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 表结构；未声明时返回 null。
func get_schema() -> GFConfigTableSchema:
	if _schema == null:
		return null
	return _schema.duplicate_schema()


## 获取来源定位映射。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 来源定位映射的深拷贝。
## [br]
## @schema return: Dictionary，可包含 header、row_locations、source 和格式专属定位数据。
func get_source_map() -> Dictionary:
	return _source_map.duplicate(true)


## 获取表元数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 表元数据的深拷贝。
## [br]
## @schema return: Dictionary，保存来源摘要和调用方附加元数据。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 创建内容等价且不共享可变状态的 IR。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 单表 IR 副本。
func duplicate_ir() -> GFConfigPipelineTableIR:
	return create(_table_name, _source_path, _source_format, _records, _schema, _source_map, _metadata)


## 导出不包含完整记录载荷的稳定摘要。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: IR 摘要。
## [br]
## @schema return: Dictionary，包含 format、format_version、table_name、source_path、source_format、record_count、schema、source_map 和 metadata。
func describe() -> Dictionary:
	return {
		"format": FORMAT,
		"format_version": FORMAT_VERSION,
		"table_name": _table_name,
		"source_path": _source_path,
		"source_format": _source_format,
		"record_count": _records.size(),
		"schema": _schema.describe() if _schema != null else {},
		"source_map": _source_map.duplicate(true),
		"metadata": _metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

static func _duplicate_records(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		result.append(record.duplicate(true))
	return result


func _make_contract_failure(error_kind: String, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": ERR_INVALID_DATA,
		"error_kind": error_kind,
		"error": message,
	}
