## GFDataBatchRowMatch: 保存按当前行顺序匹配得到的旧行号。
## 每次匹配只读取两列的有效前缀，结果由调用者独立持有。可用于对齐快照或比较修订。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFDataBatchRowMatch
extends RefCounted


# --- 公共变量 ---

## OK 表示匹配完成，含合法空结果。有效行数越界返回 ERR_INVALID_PARAMETER，
## 任一列内有重复 ID 返回 ERR_INVALID_DATA，输出分配失败返回 ERR_OUT_OF_MEMORY。
## 原生服务违反返回协议时为 FAILED。失败时行号数组为空。
## [br]
## @api public
## [br]
## @since unreleased
var error: Error = OK

## 每个当前 ID 对应的旧行号。新出现的 ID 对应 -1，调用者可独立修改该数组。
## [br]
## @api public
## [br]
## @since unreleased
var previous_rows: PackedInt32Array = PackedInt32Array()


# --- 公共方法 ---

## 按精确的有符号 64 位 ID 同步匹配两列。两侧的有效 ID 各自唯一，允许任意行序和负 ID。
## 输入在调用期间只读。主线程可自动选用已安装的原生能力，其他情况使用 GDScript。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param previous_ids: 上一批的身份列。
## [br]
## @param previous_count: 上一批的有效行数，范围为零至列长且可由有符号 32 位整数表示。
## [br]
## @param current_ids: 当前批次的身份列，与上一批使用同一身份空间。
## [br]
## @param current_count: 当前批次的有效行数，范围为零至列长且可由有符号 32 位整数表示。
## [br]
## @return: 独立结果。成功时 previous_rows 长度为 current_count，失败时由 error 给出原因。
static func match_ids(
	previous_ids: PackedInt64Array,
	previous_count: int,
	current_ids: PackedInt64Array,
	current_count: int
) -> GFDataBatchRowMatch:
	var result: GFDataBatchRowMatch = GFDataBatchRowMatch.new()
	if (
		previous_count < 0
		or previous_count > previous_ids.size()
		or previous_count > 2_147_483_647
		or current_count < 0
		or current_count > current_ids.size()
		or current_count > 2_147_483_647
	):
		result.error = ERR_INVALID_PARAMETER
		return result

	# 两侧都至多一行时，脚本最多比较一次 ID，直接完成即可。
	var native: Object = _native_service() if previous_count > 1 or current_count > 1 else null
	if native != null:
		var value: Variant = native.call(
			&"match_ids",
			previous_ids,
			previous_count,
			current_ids,
			current_count
		)
		if value is PackedInt32Array:
			var native_rows: PackedInt32Array = value
			if native_rows.size() == current_count:
				result.previous_rows = native_rows
				return result
		elif value is int and value in [ERR_INVALID_DATA, ERR_OUT_OF_MEMORY]:
			var error_code: int = value
			result.error = error_code as Error
			return result
		result.error = FAILED
		return result

	var rows: PackedInt32Array = PackedInt32Array()
	result.error = rows.resize(current_count) as Error
	if result.error != OK:
		return result
	if _strictly_increasing(previous_ids, previous_count) and _strictly_increasing(current_ids, current_count):
		var old_row: int = 0
		for row: int in range(current_count):
			var id: int = current_ids[row]
			while old_row < previous_count and previous_ids[old_row] < id:
				old_row += 1
			rows[row] = old_row if old_row < previous_count and previous_ids[old_row] == id else -1
	else:
		# 同一张表记录旧行号和已经访问的当前 ID，包括仅出现在当前列的 ID。
		const SEEN_CURRENT: int = -2
		var by_id: Dictionary[int, int] = {}
		for row: int in range(previous_count):
			var id: int = previous_ids[row]
			if by_id.has(id):
				result.error = ERR_INVALID_DATA
				return result
			by_id[id] = row
		for row: int in range(current_count):
			var id: int = current_ids[row]
			var old_row: int = by_id.get(id, -1)
			if old_row == SEEN_CURRENT:
				result.error = ERR_INVALID_DATA
				return result
			rows[row] = old_row
			by_id[id] = SEEN_CURRENT
	result.previous_rows = rows
	return result


# --- 私有/辅助方法 ---

## 严格递增同时证明该有效前缀没有重复，允许两列直接顺序合并。
## [br]
## @api private
static func _strictly_increasing(ids: PackedInt64Array, count: int) -> bool:
	for row: int in range(1, count):
		if ids[row - 1] >= ids[row]:
			return false
	return true


## 仅在主线程连接实现行匹配协议 1 的服务，工作线程可以独立使用脚本算法。
## [br]
## @api private
static func _native_service() -> Object:
	const SERVICE: StringName = &"GfDataBatchRowMatchBackend"
	if not Thread.is_main_thread() or not Engine.has_singleton(SERVICE):
		return null
	var native: Object = Engine.get_singleton(SERVICE)
	if (
		not is_instance_valid(native)
		or not native.is_class(SERVICE)
		or not native.has_method(&"protocol_version")
		or not native.has_method(&"match_ids")
	):
		return null
	var version: Variant = native.call(&"protocol_version")
	return native if version is int and version == 1 else null
