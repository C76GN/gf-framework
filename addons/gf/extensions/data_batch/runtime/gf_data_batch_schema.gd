## GFDataBatchSchema: 一次构造后固定的数值列布局。
##
## 字段含义和版本迁移属于项目；列索引在此 schema 的整个生命周期内不变。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFDataBatchSchema
extends RefCounted


# --- 枚举 ---

## 支持的 PackedArray 数值列类型，不执行隐式数值转换。
## [br]
## @api public
## [br]
## @since unreleased
enum NumericType {
	## 查询索引无效时返回，不能用于构造列。
	INVALID,
	## PackedInt32Array，每个元素占四个 payload 字节。
	INT32,
	## PackedInt64Array，每个元素占八个 payload 字节。
	INT64,
}


# --- 常量 ---

## 单个 schema 的最大列数，限制边界验证和每批元数据工作量。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_COLUMNS: int = 256


# --- 私有变量 ---

## 项目声明的布局标识，不充当业务实体身份。
## [br]
## @api private
var _schema_id: StringName = &""

## 正版本号；零表示未经 create 构造的无效对象。
## [br]
## @api private
var _version: int = 0

## 构造时复制的有序列名。
## [br]
## @api private
var _column_names: Array[StringName] = []

## 与列名逐项对应的已验证 NumericType。
## [br]
## @api private
var _column_types: PackedInt32Array = PackedInt32Array()

## 只在初始化和字段绑定时使用的列名索引，不参与逐行读取。
## [br]
## @api private
var _column_indices: Dictionary[StringName, int] = {}

## 所有列每一行所占 payload 字节之和，不含容器和对象开销。
## [br]
## @api private
var _bytes_per_row: int = 0


# --- 公共方法 ---

## 校验并复制布局定义。无效输入返回 null，不保留输入数组别名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param schema_id: 非空的项目布局标识。
## [br]
## @param version: 大于零的项目布局版本。
## [br]
## @param column_names: 一至 MAX_COLUMNS 个非空、无重复的列名。
## [br]
## @param column_types: 与列名等长，只包含 INT32 或 INT64。
## [br]
## @return: 固定布局；验证失败返回 null。
static func create(
	schema_id: StringName,
	version: int,
	column_names: Array[StringName],
	column_types: PackedInt32Array
) -> GFDataBatchSchema:
	if schema_id == &"" or version <= 0:
		return null
	if column_names.is_empty() or column_names.size() > MAX_COLUMNS:
		return null
	if column_names.size() != column_types.size():
		return null
	var indices: Dictionary[StringName, int] = {}
	var bytes_per_row: int = 0
	for index: int in range(column_names.size()):
		var column_name: StringName = column_names[index]
		if column_name == &"" or indices.has(column_name):
			return null
		match column_types[index]:
			NumericType.INT32:
				bytes_per_row += 4
			NumericType.INT64:
				bytes_per_row += 8
			_:
				return null
		indices[column_name] = index
	var schema: GFDataBatchSchema = GFDataBatchSchema.new()
	schema._schema_id = schema_id
	schema._version = version
	schema._column_names = column_names.duplicate()
	schema._column_types = column_types.duplicate()
	schema._column_indices = indices
	schema._bytes_per_row = bytes_per_row
	return schema


## 检查此对象是否通过 create 完整构造。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 有效布局返回 true。
func is_valid() -> bool:
	return _version > 0


## 返回项目布局标识。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 构造时固定的标识。
func get_schema_id() -> StringName:
	return _schema_id


## 返回项目声明的布局版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 正版本号；无效对象为零。
func get_version() -> int:
	return _version


## 返回固定列数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 列数量。
func get_column_count() -> int:
	return _column_names.size()


## 在初始化消费者时将列名绑定到稳定索引。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_name: 项目定义的列名。
## [br]
## @return: 零起始列索引；不存在返回 -1。
func find_column(column_name: StringName) -> int:
	if not _column_indices.has(column_name):
		return -1
	return _column_indices[column_name]


## 按稳定索引返回列名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_index: 零起始列索引。
## [br]
## @return: 列名；越界返回空 StringName。
func get_column_name(column_index: int) -> StringName:
	if column_index < 0 or column_index >= _column_names.size():
		return &""
	return _column_names[column_index]


## 按稳定索引返回数值类型。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_index: 零起始列索引。
## [br]
## @return: 列类型；越界返回 INVALID。
func get_column_type(column_index: int) -> NumericType:
	if column_index < 0 or column_index >= _column_types.size():
		return NumericType.INVALID
	return _column_types[column_index] as NumericType


## 返回全部列每行占用的 payload 字节，不含对象、字典和数组头开销。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 每行四或八字节列宽之和。
func get_bytes_per_row() -> int:
	return _bytes_per_row
