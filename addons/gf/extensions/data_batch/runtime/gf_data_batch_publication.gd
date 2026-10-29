## GFDataBatchPublication: 同步验证、复制或合作移交并原子替换当前数值批次。
##
## 只持有当前快照；消费者可以自行跨帧保留历史快照。预算限制发布者当前与
## 待构造批次的 PackedArray payload 峰值，不限制外部保留、读取副本或源数据。
## 项目负责字段语义、实体身份、权限和结构/值版本，不提供线程同步或异步调度。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFDataBatchPublication
extends RefCounted


# --- 枚举 ---

## 最近一次发布的结构化拒绝原因；无需解析自然语言日志。
## [br]
## @api public
## [br]
## @since unreleased
enum Failure {
	## 发布成功，或尚未尝试发布。
	NONE,
	## 发布者已关闭或未通过 create 构造。
	CLOSED,
	## count/capacity 非法。
	INVALID_SHAPE,
	## 列集合、PackedArray 类型或长度不符合 schema。
	INVALID_COLUMN,
	## 行索引不属于本次调用提供的源有效前缀。
	INVALID_SELECTION,
	## 版本为负、倒退、未推进，或形状改变却未推进结构版本。
	INVALID_REVISION,
	## 源容量或输出行数超过配置的有限行预算。
	ROW_BUDGET,
	## 当前与待构造 payload 之和超过字节预算。
	BYTE_BUDGET,
	## 只读字典无法通过清空内容完成合作移交。
	READ_ONLY_TRANSFER,
	## 已通过预算验证，但引擎未能构造完整长度的列。
	ALLOCATION_FAILED,
}


## 内部列构造方式；不会向调用者暴露通用策略参数。
## [br]
## @api private
enum _ColumnMode {
	COPY,
	TRANSFER,
	GATHER,
}


# --- 私有变量 ---

## 单个发布者固定使用的 schema。
## [br]
## @api private
var _schema: GFDataBatchSchema = null

## 构造时固定的列名顺序，发布期间不再逐列查询 schema。
## [br]
## @api private
var _column_names: Array[StringName] = []

## 与固定列名逐项对应的数值类型，只在构造时写入。
## [br]
## @api private
var _column_types: PackedInt32Array = PackedInt32Array()

## 固定布局的每行 payload 字节数，用于发布前的重叠预算检查。
## [br]
## @api private
var _bytes_per_row: int = 0

## 项目声明的生产者身份。
## [br]
## @api private
var _producer_id: StringName = &""

## 固定生命期代次；更换代次时创建新的发布者。
## [br]
## @api private
var _producer_generation: int = 0

## 源容量和输出行数上限，必须为正且可由 Int32 行索引表达。
## [br]
## @api private
var _max_rows: int = 0

## 当前与构造中候选批次 payload 的峰值上限。
## [br]
## @api private
var _max_owned_bytes: int = 0

## 显式关闭后不可恢复，直接 new 的对象默认关闭。
## [br]
## @api private
var _open: bool = false

## 发布者唯一持有的成功快照；不保留历史队列。
## [br]
## @api private
var _current: GFDataBatchSnapshot = null

## 只在完整提交后推进；失败不消耗序号。
## [br]
## @api private
var _publication_sequence: int = 0

## 仅诊断最近一次尝试，不参与快照身份。
## [br]
## @api private
var _last_failure: Failure = Failure.NONE

## 最近进入字节预算检查的尝试所需的当前加候选 payload；更早拒绝时保留前值。
## [br]
## @api private
var _last_required_payload_bytes: int = 0

## 最近成功提交的构造峰值，不计外部历史快照和副本。
## [br]
## @api private
var _last_peak_payload_bytes: int = 0

## 最近成功提交实际复制的 PackedArray payload 字节。
## [br]
## @api private
var _last_copied_payload_bytes: int = 0

## 最近成功提交通过合作移交接收的 payload 字节。
## [br]
## @api private
var _last_transferred_payload_bytes: int = 0


# --- 公共方法 ---

## 构造固定生产者和预算的发布边界。配置无效或布局缓存分配失败返回 null。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param schema: 通过 GFDataBatchSchema.create 构造的有效 schema。
## [br]
## @param producer_id: 非空项目生产者标识，不代表业务权限。
## [br]
## @param producer_generation: 大于零的生命期代次。
## [br]
## @param max_rows: 大于零且不超过 2147483647 的源容量及输出行数上限。
## [br]
## @param max_owned_bytes: 正 payload 字节预算，覆盖当前快照加候选批次。
## [br]
## @return: 开放的发布者；配置无效或布局缓存分配失败返回 null。
static func create(
	schema: GFDataBatchSchema,
	producer_id: StringName,
	producer_generation: int,
	max_rows: int,
	max_owned_bytes: int
) -> GFDataBatchPublication:
	if schema == null or not schema.is_valid():
		return null
	if producer_id == &"" or producer_generation <= 0:
		return null
	if (
		max_rows <= 0
		or max_rows > 2_147_483_647
		or max_owned_bytes <= 0
	):
		return null
	var publication: GFDataBatchPublication = GFDataBatchPublication.new()
	publication._schema = schema
	var column_count: int = schema.get_column_count()
	var names_resize_error: Error = publication._column_names.resize(column_count) as Error
	if names_resize_error != OK:
		return null
	var types_resize_error: Error = publication._column_types.resize(column_count) as Error
	if types_resize_error != OK:
		return null
	for column_index: int in range(column_count):
		publication._column_names[column_index] = schema.get_column_name(column_index)
		publication._column_types[column_index] = schema.get_column_type(column_index)
	publication._column_names.make_read_only()
	publication._bytes_per_row = schema.get_bytes_per_row()
	publication._producer_id = producer_id
	publication._producer_generation = producer_generation
	publication._max_rows = max_rows
	publication._max_owned_bytes = max_owned_bytes
	publication._open = true
	return publication


## 全量验证后复制列的完整 capacity，只进行一次 payload 复制并替换当前发布。
##
## 输入及其 PackedArray 别名可在返回后继续修改，不影响已发布快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param columns: 与 schema 完全相符的列集合。
## [br]
## @param count: 有效前缀行数，允许零。
## [br]
## @param capacity: 每列数组长度，不小于 count。
## [br]
## @param structural_revision: 非负结构版本，行身份或顺序改变必须由项目递增。
## [br]
## @param value_revision: 非负数值版本；两版本不得倒退且每次至少推进一种。
## [br]
## @return: OK 或拒绝错误；失败保留旧发布，具体原因见 get_last_failure。
## [br]
## @schema columns: Dictionary[StringName|String, PackedInt32Array|PackedInt64Array]，键是 schema 列名，所有数组长度必须精确等于 capacity。
func publish_copy(
	columns: Dictionary,
	count: int,
	capacity: int,
	structural_revision: int,
	value_revision: int
) -> Error:
	return _publish(
		columns,
		count,
		capacity,
		PackedInt32Array(),
		structural_revision,
		value_revision,
		_ColumnMode.COPY
	)


## 全量验证后接收已有隔离列，不再次复制 payload；成功清空输入字典。
##
## 调用者必须合作退休全部 PackedArray 别名，后续不能写入或复用它们。
## Godot 没有 move 语义，清空字典不能撤销外部别名。只读字典被拒绝；失败不消费输入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param columns: 可清空的完整列字典，成功后为空。
## [br]
## @param count: 有效前缀行数。
## [br]
## @param capacity: 每列数组长度，不小于 count。
## [br]
## @param structural_revision: 非负结构版本。
## [br]
## @param value_revision: 非负数值版本；版本推进规则同 publish_copy。
## [br]
## @return: OK 或拒绝错误；失败不改变当前快照和输入字典。
## [br]
## @schema columns: Dictionary[StringName|String, PackedInt32Array|PackedInt64Array]，精确匹配 schema，各列长度为 capacity，成功后消费全部键值。
func publish_transfer(
	columns: Dictionary,
	count: int,
	capacity: int,
	structural_revision: int,
	value_revision: int
) -> Error:
	return _publish(
		columns,
		count,
		capacity,
		PackedInt32Array(),
		structural_revision,
		value_revision,
		_ColumnMode.TRANSFER
	)


## 同步验证源列和原始行索引，只为选中行分配紧凑副本。
##
## 索引只在本次同步调用内解释，不能作为跨批次身份凭据；顺序和重复索引均保留。
## 输出 count 和 capacity 都等于索引数量，不复制未选中的历史行或源容量尾部。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param source_columns: 同一次捕获的完整源列集合。
## [br]
## @param source_count: 源有效前缀行数。
## [br]
## @param source_capacity: 每列实际长度，受 max_rows 限制。
## [br]
## @param row_indices: 每个索引必须位于零至 source_count 减一，数量受 max_rows 限制。
## [br]
## @param structural_revision: 输出行身份或顺序变化时须推进的非负版本。
## [br]
## @param value_revision: 非负数值版本；版本推进规则同 publish_copy。
## [br]
## @return: OK 或拒绝错误；失败不发布部分结果。
## [br]
## @schema source_columns: Dictionary[StringName|String, PackedInt32Array|PackedInt64Array]，精确匹配 schema，各列长度为 source_capacity。
func publish_gather_copy(
	source_columns: Dictionary,
	source_count: int,
	source_capacity: int,
	row_indices: PackedInt32Array,
	structural_revision: int,
	value_revision: int
) -> Error:
	return _publish(
		source_columns,
		source_count,
		source_capacity,
		row_indices,
		structural_revision,
		value_revision,
		_ColumnMode.GATHER
	)


## 取得当前快照的强引用，不复制 payload。调用者可以跨帧保留它。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前快照；尚未发布或已关闭返回 null。
func get_current() -> GFDataBatchSnapshot:
	return _current


## 检查精确快照对象是否仍是此发布者的当前发布，不仅比较元数据数值。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param snapshot: 要检查的快照，可以为历史快照或其他发布者的快照。
## [br]
## @return: 发布者开放且对象身份匹配时返回 true。
func is_current(snapshot: GFDataBatchSnapshot) -> bool:
	return (
		_open
		and snapshot != null
		and is_same(snapshot, _current)
	)


## 关闭并释放发布者持有的当前引用；已交付快照和独立副本仍可读取。
## [br]
## @api public
## [br]
## @since unreleased
func close() -> void:
	_open = false
	_current = null


## 返回最近一次发布尝试的结构化原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功后为 NONE；失败不改写已有快照的元数据。
func get_last_failure() -> Failure:
	return _last_failure


## 返回独立诊断字典。字节指标只计 PackedArray payload，不声称全局内存上界。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 发布者预算和最近成功构造的复制/移交字节。
## [br]
## @schema return: Dictionary，open:bool、max_rows:int、max_owned_bytes:int、current_payload_bytes:int、last_required_payload_bytes:int、last_peak_payload_bytes:int、last_copied_payload_bytes:int、last_transferred_payload_bytes:int、publication_sequence:int、last_failure:int、external_retention_tracked:bool（恒为 false）。
func get_debug_snapshot() -> Dictionary:
	return {
		"open": _open,
		"max_rows": _max_rows,
		"max_owned_bytes": _max_owned_bytes,
		"current_payload_bytes": _current_payload_bytes(),
		"last_required_payload_bytes": _last_required_payload_bytes,
		"last_peak_payload_bytes": _last_peak_payload_bytes,
		"last_copied_payload_bytes": _last_copied_payload_bytes,
		"last_transferred_payload_bytes": _last_transferred_payload_bytes,
		"publication_sequence": _publication_sequence,
		"last_failure": _last_failure,
		"external_retention_tracked": false,
	}


# --- 私有/辅助方法 ---

## 完成全部可拒绝检查后才构造或消费列；期间不调用用户代码，也不让出执行权。
## [br]
## @api private
func _publish(
	source_columns: Dictionary,
	source_count: int,
	source_capacity: int,
	row_indices: PackedInt32Array,
	structural_revision: int,
	value_revision: int,
	mode: _ColumnMode
) -> Error:
	if not _open:
		return _reject(Failure.CLOSED, ERR_UNAVAILABLE)
	if mode == _ColumnMode.TRANSFER and source_columns.is_read_only():
		return _reject(Failure.READ_ONLY_TRANSFER, ERR_INVALID_PARAMETER)
	var columns: Array = []
	var source_error: Error = _validate_and_bind_source(
		source_columns,
		source_count,
		source_capacity,
		columns
	)
	if source_error != OK:
		return source_error
	var count: int = source_count
	var capacity: int = source_capacity
	if mode == _ColumnMode.GATHER:
		if row_indices.size() > _max_rows:
			return _reject(Failure.ROW_BUDGET, ERR_OUT_OF_MEMORY)
		for source_row: int in row_indices:
			if source_row < 0 or source_row >= source_count:
				return _reject(Failure.INVALID_SELECTION, ERR_INVALID_PARAMETER)
		count = row_indices.size()
		capacity = count
	var revision_error: Error = _validate_revisions(
		count,
		capacity,
		structural_revision,
		value_revision
	)
	if revision_error != OK:
		return revision_error
	var candidate_bytes: int = capacity * _bytes_per_row
	_last_required_payload_bytes = _current_payload_bytes() + candidate_bytes
	if _last_required_payload_bytes > _max_owned_bytes:
		return _reject(Failure.BYTE_BUDGET, ERR_OUT_OF_MEMORY)
	if columns.size() != _column_names.size():
		return _reject(Failure.ALLOCATION_FAILED, ERR_OUT_OF_MEMORY)
	if not _materialize_columns(
		columns,
		row_indices,
		mode
	):
		return _reject(Failure.ALLOCATION_FAILED, ERR_OUT_OF_MEMORY)
	var candidate: GFDataBatchSnapshot = GFDataBatchSnapshot.create_owned(
		_schema,
		columns,
		_producer_id,
		_producer_generation,
		_publication_sequence + 1,
		count,
		capacity,
		structural_revision,
		value_revision
	)
	if mode == _ColumnMode.TRANSFER:
		source_columns.clear()
	_current = candidate
	_publication_sequence += 1
	_last_peak_payload_bytes = _last_required_payload_bytes
	_last_copied_payload_bytes = candidate_bytes if mode != _ColumnMode.TRANSFER else 0
	_last_transferred_payload_bytes = candidate_bytes if mode == _ColumnMode.TRANSFER else 0
	_last_failure = Failure.NONE
	return OK


## 完整验证源列并绑定到调用局部容器；空 gather 仍检查每列类型和长度。
## [br]
## @api private
func _validate_and_bind_source(
	columns: Dictionary,
	count: int,
	capacity: int,
	ordered: Array
) -> Error:
	if (
		count < 0
		or capacity < 0
		or count > capacity
	):
		return _reject(Failure.INVALID_SHAPE, ERR_INVALID_PARAMETER)
	if capacity > _max_rows:
		return _reject(Failure.ROW_BUDGET, ERR_OUT_OF_MEMORY)
	if columns.size() != _column_names.size():
		return _reject(Failure.INVALID_COLUMN, ERR_INVALID_PARAMETER)
	for column_index: int in range(_column_names.size()):
		var value: Variant = columns.get(_column_names[column_index])
		match _column_types[column_index]:
			GFDataBatchSchema.NumericType.INT32:
				if not value is PackedInt32Array:
					return _reject(Failure.INVALID_COLUMN, ERR_INVALID_PARAMETER)
				var column: PackedInt32Array = value
				if column.size() != capacity:
					return _reject(Failure.INVALID_COLUMN, ERR_INVALID_PARAMETER)
			GFDataBatchSchema.NumericType.INT64:
				if not value is PackedInt64Array:
					return _reject(Failure.INVALID_COLUMN, ERR_INVALID_PARAMETER)
				var column: PackedInt64Array = value
				if column.size() != capacity:
					return _reject(Failure.INVALID_COLUMN, ERR_INVALID_PARAMETER)
		ordered.append(value)
	return OK


## 版本防止同一发布者内倒退；无法由整数列推断项目行身份，项目负责相应递增。
## [br]
## @api private
func _validate_revisions(
	count: int,
	capacity: int,
	structural_revision: int,
	value_revision: int
) -> Error:
	if (
		structural_revision < 0
		or value_revision < 0
		or _publication_sequence == 9_223_372_036_854_775_807
	):
		return _reject(Failure.INVALID_REVISION, ERR_INVALID_PARAMETER)
	if _current == null:
		return OK
	if structural_revision < _current.get_structural_revision() or value_revision < _current.get_value_revision():
		return _reject(Failure.INVALID_REVISION, ERR_INVALID_PARAMETER)
	if structural_revision == _current.get_structural_revision():
		if value_revision == _current.get_value_revision():
			return _reject(Failure.INVALID_REVISION, ERR_INVALID_PARAMETER)
		if count != _current.get_count() or capacity != _current.get_capacity():
			return _reject(Failure.INVALID_REVISION, ERR_INVALID_PARAMETER)
	return OK


## 在同一局部容器中替换已验证的源列；失败时由调用栈释放部分副本，不发布混合结果。
## [br]
## @api private
func _materialize_columns(
	columns: Array,
	rows: PackedInt32Array,
	mode: _ColumnMode
) -> bool:
	if mode == _ColumnMode.TRANSFER:
		return true
	for column_index: int in range(columns.size()):
		var value: Variant = columns[column_index]
		if value is PackedInt32Array:
			var input: PackedInt32Array = value
			var output: PackedInt32Array = input
			if mode == _ColumnMode.COPY:
				output = input.duplicate()
				if output.size() != input.size():
					return false
			elif mode == _ColumnMode.GATHER:
				output = PackedInt32Array()
				var resize_error: Error = output.resize(rows.size()) as Error
				if resize_error != OK:
					return false
				for index: int in range(rows.size()):
					output[index] = input[rows[index]]
			columns[column_index] = output
		elif value is PackedInt64Array:
			var input: PackedInt64Array = value
			var output: PackedInt64Array = input
			if mode == _ColumnMode.COPY:
				output = input.duplicate()
				if output.size() != input.size():
					return false
			elif mode == _ColumnMode.GATHER:
				output = PackedInt64Array()
				var resize_error: Error = output.resize(rows.size()) as Error
				if resize_error != OK:
					return false
				for index: int in range(rows.size()):
					output[index] = input[rows[index]]
			columns[column_index] = output
		else:
			return false
	return true


## 不把消费者仍然保留的历史引用或 copy 结果计入发布者持有量。
## [br]
## @api private
func _current_payload_bytes() -> int:
	return _current.get_payload_bytes() if _current != null else 0


## 记录拒绝原因但不修改当前快照、序号或源列。
## [br]
## @api private
func _reject(failure: Failure, error: Error) -> Error:
	_last_failure = failure
	return error
