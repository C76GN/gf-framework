## GFConfigPipelineIR: Config Pipeline 的版本化数据库中间表示。
##
## 聚合已经通过单表语义校验的 GFConfigPipelineTableIR，并作为 Target 阶段的唯一输入。
## IR 不持有导出路径或文件事务策略，确保同一编译结果可以交给多个目标实现。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineIR
extends RefCounted


# --- 常量 ---

## 数据库 IR 的稳定格式标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT: String = "gf.config_pipeline.ir"

## 数据库 IR 的格式版本。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT_VERSION: int = 1


# --- 私有变量 ---

var _database_id: StringName = &""
var _version: String = ""
var _metadata: Dictionary = {}
var _tables: Array[GFConfigPipelineTableIR] = []
var _table_lookup: Dictionary = {}
var _sealed: bool = false


# --- 公共方法 ---

## 创建空数据库 IR，并取得元数据的副本所有权。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param database_id: 数据库标识；可为空。
## [br]
## @param version: 项目侧配置版本；可为空。
## [br]
## @param metadata: 与目标无关的数据库元数据。
## [br]
## @schema metadata: Dictionary，保存构建上下文或项目侧附加元数据。
## [br]
## @return: 新建的数据库 IR。
static func create(
	database_id: StringName = &"",
	version: String = "",
	metadata: Dictionary = {}
) -> GFConfigPipelineIR:
	var compilation_ir: GFConfigPipelineIR = GFConfigPipelineIR.new()
	compilation_ir._database_id = database_id
	compilation_ir._version = version
	compilation_ir._metadata = metadata.duplicate(true)
	return compilation_ir


## 注册不可变单表 IR。重复表名和损坏契约会 fail closed，且不会污染当前 IR。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param table_ir: 已完成语义校验的单表 IR。
## [br]
## @return: 注册结果。
## [br]
## @schema return: Dictionary，包含 success、error_code、error_kind、error 和 table_name。
func add_table(table_ir: GFConfigPipelineTableIR) -> Dictionary:
	if _sealed:
		return _make_add_failure(&"", "ir_sealed", "数据库 IR 已封存，不能继续注册表。")
	if table_ir == null:
		return _make_add_failure(&"", "invalid_table_ir", "待注册的 Table IR 为空。")
	var contract: Dictionary = table_ir.validate_contract()
	if not GFVariantData.get_option_bool(contract, "success"):
		return _make_add_failure(
			table_ir.get_table_name(),
			"invalid_table_ir",
			GFVariantData.get_option_string(contract, "error")
		)
	var table_name: StringName = table_ir.get_table_name()
	if _table_lookup.has(table_name):
		return _make_add_failure(
			table_name,
			"duplicate_table_ir",
			"数据库 IR 中存在重复表：%s。" % String(table_name)
		)

	_table_lookup[table_name] = table_ir
	_tables.append(table_ir)
	return {
		"success": true,
		"error_code": OK,
		"error_kind": "",
		"error": "",
		"table_name": table_name,
	}


## 封存数据库 IR。封存成功后不能再注册表，且 IR 才能交给 Target。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 封存结果。
## [br]
## @schema return: Dictionary，包含 success、error_code、error_kind、error 和 table_name。
func seal() -> Dictionary:
	if _sealed:
		return validate_contract()
	var structure_result: Dictionary = _validate_structure()
	if not GFVariantData.get_option_bool(structure_result, "success"):
		return structure_result
	_sealed = true
	return structure_result


## 返回 IR 是否已封存。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 已封存时为 true。
func is_sealed() -> bool:
	return _sealed


## 校验数据库 IR 已封存，且自身及全部单表 IR 满足结构契约。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 契约校验结果。
## [br]
## @schema return: Dictionary，包含 success、error_code、error_kind、error 和 table_name。
func validate_contract() -> Dictionary:
	var structure_result: Dictionary = _validate_structure()
	if not GFVariantData.get_option_bool(structure_result, "success"):
		return structure_result
	if not _sealed:
		return _make_add_failure(&"", "unsealed_pipeline_ir", "数据库 IR 尚未封存，不能交给 Target。")
	return structure_result


## 获取数据库标识。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 数据库标识。
func get_database_id() -> StringName:
	return _database_id


## 获取项目侧配置版本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 配置版本。
func get_version() -> String:
	return _version


## 获取数据库元数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 数据库元数据的深拷贝。
## [br]
## @schema return: Dictionary，保存构建上下文或项目侧附加元数据。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取不可变单表 IR。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param table_name: 稳定表名。
## [br]
## @return: 找到时返回不可变单表 IR，否则返回 null。
func get_table(table_name: StringName) -> GFConfigPipelineTableIR:
	var table_value: Variant = _table_lookup.get(table_name)
	if not (table_value is GFConfigPipelineTableIR):
		return null
	return table_value


## 获取按注册顺序排列的不可变单表 IR。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 单表 IR 列表；数组容器是副本，元素是不可变 IR。
## [br]
## @schema return: Array[GFConfigPipelineTableIR]，按注册顺序排列。
func get_tables() -> Array[GFConfigPipelineTableIR]:
	return _tables.duplicate()


## 创建内容等价且不共享可变载荷的数据库 IR。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 数据库 IR 副本；原 IR 已封存时，副本也会封存。
func duplicate_ir() -> GFConfigPipelineIR:
	var result: GFConfigPipelineIR = create(_database_id, _version, _metadata)
	for table_ir: GFConfigPipelineTableIR in _tables:
		var _add_result: Dictionary = result.add_table(table_ir)
	if _sealed:
		var _seal_result: Dictionary = result.seal()
	return result


## 导出不包含完整记录载荷的稳定摘要。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: IR 摘要。
## [br]
## @schema return: Dictionary，包含 format、format_version、database_id、version、sealed、metadata、table_count 和 tables。
func describe() -> Dictionary:
	var table_descriptions: Array[Dictionary] = []
	for table_ir: GFConfigPipelineTableIR in _tables:
		table_descriptions.append(table_ir.describe())
	return {
		"format": FORMAT,
		"format_version": FORMAT_VERSION,
		"database_id": _database_id,
		"version": _version,
		"sealed": _sealed,
		"metadata": _metadata.duplicate(true),
		"table_count": _tables.size(),
		"tables": table_descriptions,
	}


# --- 私有/辅助方法 ---

func _validate_structure() -> Dictionary:
	var seen_tables: Dictionary = {}
	for table_ir: GFConfigPipelineTableIR in _tables:
		if table_ir == null:
			return _make_add_failure(&"", "invalid_table_ir", "数据库 IR 包含空 Table IR。")
		var table_name: StringName = table_ir.get_table_name()
		if seen_tables.has(table_name):
			return _make_add_failure(table_name, "duplicate_table_ir", "数据库 IR 包含重复表：%s。" % String(table_name))
		seen_tables[table_name] = true
		var contract: Dictionary = table_ir.validate_contract()
		if not GFVariantData.get_option_bool(contract, "success"):
			return _make_add_failure(
				table_name,
				"invalid_table_ir",
				GFVariantData.get_option_string(contract, "error")
			)
	return {
		"success": true,
		"error_code": OK,
		"error_kind": "",
		"error": "",
		"table_name": &"",
	}

func _make_add_failure(table_name: StringName, error_kind: String, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": ERR_INVALID_DATA,
		"error_kind": error_kind,
		"error": message,
		"table_name": table_name,
	}
