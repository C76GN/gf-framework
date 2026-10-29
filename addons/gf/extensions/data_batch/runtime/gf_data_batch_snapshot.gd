## GFDataBatchSnapshot: 固定元数据和数值列的独立发布快照。
##
## 发布者替换或关闭后仍可读取。copy 方法提供修改隔离；borrow 方法返回共享
## PackedArray，只能按合作约定读取。Godot 不提供此类数组的强制只读或 move 保证。
## count 是有效前缀长度，capacity 是列数组长度，容量尾部不属于有效数据。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFDataBatchSnapshot
extends RefCounted


# --- 私有变量 ---

## 固定布局对象，不复制也不修改 schema。
## [br]
## @api private
var _schema: GFDataBatchSchema = null

## 按 schema 索引排列的已隔离或已合作移交的 PackedArray。
## [br]
## @api private
var _columns: Array = []

## 项目提供的生产者标识，不授予项目数据权限。
## [br]
## @api private
var _producer_id: StringName = &""

## 生产者生命期代次，由项目显式递增并重建发布者。
## [br]
## @api private
var _producer_generation: int = 0

## 此发布者中的成功发布序号，不以项目 tick 作为缓存键。
## [br]
## @api private
var _publication_sequence: int = 0

## 项目声明的行身份、顺序或布局变化版本。
## [br]
## @api private
var _structural_revision: int = 0

## 项目声明的值变化版本，可保守递增。
## [br]
## @api private
var _value_revision: int = 0

## 有效数据前缀行数。
## [br]
## @api private
var _count: int = 0

## 每列数组的实际长度；尾部不属于有效行。
## [br]
## @api private
var _capacity: int = 0


# --- 公共方法 ---

## 返回构造此批次时使用的固定 schema。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: schema；直接 new 的未发布对象为 null。
func get_schema() -> GFDataBatchSchema:
	return _schema


## 返回项目生产者标识。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 固定的生产者标识。
func get_producer_id() -> StringName:
	return _producer_id


## 返回生产者生命期代次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 固定的正代次。
func get_producer_generation() -> int:
	return _producer_generation


## 返回此发布者内单调递增的成功发布序号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 正发布序号；不代表此快照仍是当前发布。
func get_publication_sequence() -> int:
	return _publication_sequence


## 返回项目声明的结构版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 行身份、顺序和布局的版本。
func get_structural_revision() -> int:
	return _structural_revision


## 返回项目声明的数值版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 数值版本，不依赖帧或 tick。
func get_value_revision() -> int:
	return _value_revision


## 返回有效数据前缀行数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 不超过 capacity 的行数。
func get_count() -> int:
	return _count


## 返回每列数组的长度，可能大于有效行数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 列容量。
func get_capacity() -> int:
	return _capacity


## 返回本批列 payload 字节；不包含元数据、容器头和外部副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: capacity 乘以 schema 每行字节数。
func get_payload_bytes() -> int:
	if _schema == null:
		return 0
	return _capacity * _schema.get_bytes_per_row()


## 复制指定 Int32 列的完整容量，调用者修改副本不会改变快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_index: 初始化时绑定的 Int32 列索引。
## [br]
## @return: 独立 PackedInt32Array；索引或类型不匹配返回空数组。
func copy_int32_column(column_index: int) -> PackedInt32Array:
	return borrow_int32_column(column_index).duplicate()


## 复制指定 Int64 列的完整容量，调用者修改副本不会改变快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_index: 初始化时绑定的 Int64 列索引。
## [br]
## @return: 独立 PackedInt64Array；索引或类型不匹配返回空数组。
func copy_int64_column(column_index: int) -> PackedInt64Array:
	return borrow_int64_column(column_index).duplicate()


## 借用 Int32 列，调用者必须保持只读；修改会破坏所有共享者的快照契约。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_index: 初始化时绑定的 Int32 列索引。
## [br]
## @return: 共享 PackedInt32Array；索引或类型不匹配返回空数组。
func borrow_int32_column(column_index: int) -> PackedInt32Array:
	if column_index < 0 or column_index >= _columns.size():
		return PackedInt32Array()
	var value: Variant = _columns[column_index]
	if value is PackedInt32Array:
		var column: PackedInt32Array = value
		return column
	return PackedInt32Array()


## 借用 Int64 列，调用者必须保持只读；修改会破坏所有共享者的快照契约。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_index: 初始化时绑定的 Int64 列索引。
## [br]
## @return: 共享 PackedInt64Array；索引或类型不匹配返回空数组。
func borrow_int64_column(column_index: int) -> PackedInt64Array:
	if column_index < 0 or column_index >= _columns.size():
		return PackedInt64Array()
	var value: Variant = _columns[column_index]
	if value is PackedInt64Array:
		var column: PackedInt64Array = value
		return column
	return PackedInt64Array()


# --- 框架内部方法 ---

## 仅由完成边界验证的发布者调用；接收列容器和 PackedArray 的所有权。
## [br]
## @api framework_internal
## [br]
## @param schema: 已验证的固定布局。
## [br]
## @param columns: 按 schema 排序的独立列容器。
## [br]
## @param producer_id: 项目生产者标识。
## [br]
## @param producer_generation: 正生命期代次。
## [br]
## @param publication_sequence: 发布者内成功序号。
## [br]
## @param count: 有效前缀长度。
## [br]
## @param capacity: 每列长度。
## [br]
## @param structural_revision: 非负结构版本。
## [br]
## @param value_revision: 非负数值版本。
## [br]
## @return: 完整快照，不再修改其元数据或列容器。
## [br]
## @schema columns: Array，逐项为与 schema 数值类型匹配的 PackedInt32Array 或 PackedInt64Array。
static func create_owned(
	schema: GFDataBatchSchema,
	columns: Array,
	producer_id: StringName,
	producer_generation: int,
	publication_sequence: int,
	count: int,
	capacity: int,
	structural_revision: int,
	value_revision: int
) -> GFDataBatchSnapshot:
	var snapshot: GFDataBatchSnapshot = GFDataBatchSnapshot.new()
	snapshot._schema = schema
	snapshot._columns = columns
	snapshot._producer_id = producer_id
	snapshot._producer_generation = producer_generation
	snapshot._publication_sequence = publication_sequence
	snapshot._count = count
	snapshot._capacity = capacity
	snapshot._structural_revision = structural_revision
	snapshot._value_revision = value_revision
	return snapshot
