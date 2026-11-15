# GFC canonical v2: 单次遍历的内部二进制执行器。
# [br]
# @api framework_internal
# [br]
# @layer standard/foundation/deterministic
extends RefCounted


# --- 常量 ---

## 独立于 Godot Variant 枚举编号的固定协议标签。
## [br]
## @api private
const _TAGS: Dictionary = {
	TYPE_NIL: 0,
	TYPE_BOOL: 1,
	TYPE_INT: 2,
	TYPE_FLOAT: 3,
	TYPE_STRING: 4,
	TYPE_STRING_NAME: 5,
	TYPE_NODE_PATH: 6,
	TYPE_VECTOR2I: 10,
	TYPE_VECTOR3I: 11,
	TYPE_VECTOR4I: 12,
	TYPE_RECT2I: 13,
	TYPE_VECTOR2: 20,
	TYPE_VECTOR3: 21,
	TYPE_VECTOR4: 22,
	TYPE_RECT2: 23,
	TYPE_TRANSFORM2D: 24,
	TYPE_PLANE: 25,
	TYPE_QUATERNION: 26,
	TYPE_AABB: 27,
	TYPE_BASIS: 28,
	TYPE_TRANSFORM3D: 29,
	TYPE_PROJECTION: 30,
	TYPE_COLOR: 31,
	TYPE_ARRAY: 40,
	TYPE_DICTIONARY: 41,
	TYPE_PACKED_BYTE_ARRAY: 50,
	TYPE_PACKED_INT32_ARRAY: 51,
	TYPE_PACKED_INT64_ARRAY: 52,
	TYPE_PACKED_FLOAT32_ARRAY: 53,
	TYPE_PACKED_FLOAT64_ARRAY: 54,
	TYPE_PACKED_STRING_ARRAY: 55,
	TYPE_PACKED_VECTOR2_ARRAY: 56,
	TYPE_PACKED_VECTOR3_ARRAY: 57,
	TYPE_PACKED_VECTOR4_ARRAY: 58,
	TYPE_PACKED_COLOR_ARRAY: 59,
}

## 每个数值分块及哈希缓冲的字节上界。
## [br]
## @api private
const _CHUNK_BYTES: int = 65536


# --- 私有变量 ---

## 固定的操作限额。
## [br]
## @api private
var _limits: Dictionary = {
	"max_depth": 64,
	"max_items": 100000,
	"max_string_length": 1048576,
	"max_output_bytes": 16777216,
	"max_sort_bytes": 16777216,
	"max_elapsed_msec": 30000,
}

## 对外报告仅包含计量与已完成输出。
## [br]
## @api private
var _report: Dictionary = {
	"ok": true,
	"canonical_version": 2,
	"hash": "",
	"bytes": PackedByteArray(),
	"counts_complete": false,
	"items": 0,
	"packed_items": 0,
	"output_bytes": 0,
	"maximum_depth": 0,
	"peak_sort_bytes": 0,
	"error": "",
	"error_kind": "",
	"error_path": "",
	"failure_kind": "",
	"limit_kind": "",
	"limit": 0,
	"observed": 0,
	"observed_is_lower_bound": false,
}

## 输出方式。
## [br]
## @api private
var _mode: StringName

## 是否接受有限浮点。
## [br]
## @api private
var _allow_floats: bool = false

## 可选取消令牌。
## [br]
## @api private
var _cancel_token: GFCancellationToken = null

## 当前递归路径的容器；不维护全图 visited 集合。
## [br]
## @api private
var _active: Array = []

## 字典键编码的嵌套字节接收器。
## [br]
## @api private
var _key_sinks: Array[_ByteSink] = []

## 当前仍持有的排序工作区逻辑字节数。
## [br]
## @api private
var _sort_bytes: int = 0

## 哈希上下文，仅 hash 模式创建。
## [br]
## @api private
var _hashing: HashingContext = null

## bytes 模式的完整结果，或 hash 模式的分块缓冲。
## [br]
## @api private
var _buffer: PackedByteArray = PackedByteArray()

## 操作开始时间。
## [br]
## @api private
var _started: int = Time.get_ticks_msec()

## 检查点之间的有界工作步数。
## [br]
## @api private
var _steps: int = 0

## Packed 数值块的本机端序；协议固定为小端。
## [br]
## @api private
var _native_little_endian: bool = PackedInt32Array([0x01020304]).to_byte_array()[0] == 4


# --- Godot 生命周期方法 ---

## 在读取输入前验证选项。
## [br]
## @api framework_internal
## [br]
## @param options: 有限预算和浮点政策。
## [br]
## @schema options: Same options as GFDeterministicVariantSerializer.hash_result.
## [br]
## @param mode: hash、bytes 或 measure。
func _init(options: Dictionary, mode: StringName) -> void:
	_mode = mode
	for key: Variant in options:
		if not (key is String or key is StringName):
			_fail("invalid_options", "$")
			return
		if key == "allow_floats" and options[key] is bool:
			_allow_floats = options[key]
		elif (
			key == "cancel_token"
			and (
				options[key] == null
				or options[key] is GFCancellationToken
			)
		):
			_cancel_token = options[key]
		elif (
			_limits.has(key)
			and options[key] is int
			and options[key] > 0
		):
			_limits[key] = options[key]
		else:
			_fail("invalid_options", "$")
			return
	if _limits["max_depth"] > 256:
		_fail("invalid_options", "$")


# --- 框架内部方法 ---

## 运行唯一编码管线；失败只返回计量。
## [br]
## @api framework_internal
## [br]
## @param value: 稳定的纯数据树。
## [br]
## @schema value: Canonical v2 input without snapshot wrappers.
## [br]
## @return 已闭合的结构化结果。
## [br]
## @schema return: Same report as GFDeterministicVariantSerializer.hash_result.
func encode(value: Variant) -> Dictionary:
	if not _check("$", true):
		return _report
	if _mode == &"hash":
		_hashing = HashingContext.new()
		if _hashing.start(HashingContext.HASH_SHA256) != OK:
			_fail("hash_failed", "$")
			return _report
	_emit(
		PackedByteArray(
			[
				71,
				70,
				67,
				2,
			]
		),
		"$"
	)
	_value(
		value,
		"$",
		0
	)
	if _check("$", true):
		if _mode == &"hash":
			_flush()
			if _report["ok"]:
				_report["hash"] = _hashing.finish().hex_encode()
		elif _mode == &"bytes":
			_report["bytes"] = _buffer
	_report["counts_complete"] = _report["ok"]
	return _report


## 拒绝尚未构造完成的快照。
## [br]
## @api framework_internal
## [br]
## @return 不包含部分输出的失败报告。
## [br]
## @schema return: Same canonical report with error_kind snapshot_unavailable.
func reject_snapshot() -> Dictionary:
	_fail("snapshot_unavailable", "$")
	return _report


# --- 私有/辅助方法 ---

## 每个值只按出现次数访问一次，键的编码在排序后直接复用。
## [br]
## @api private
func _value(
	value: Variant,
	path: String,
	depth: int
) -> void:
	if not _check(path) or not _consume_items(1, path):
		return
	if depth > _limits["max_depth"]:
		_limit(
			"max_depth",
			depth,
			path
		)
		return
	var maximum_depth: int = _report["maximum_depth"]
	_report["maximum_depth"] = maxi(maximum_depth, depth)
	var type: int = typeof(value)
	var tag: int = _TAGS.get(type, -1)
	if tag < 0:
		_fail("unsupported_type", path)
		return
	if value is Array or value is Dictionary:
		for ancestor: Variant in _active:
			if is_same(ancestor, value):
				_fail("cycle", path)
				return
		_active.append(value)
		if value is Array:
			var array_value: Array = value
			_array(
				array_value,
				path,
				depth
			)
		else:
			var dictionary_value: Dictionary = value
			_dictionary(
				dictionary_value,
				path,
				depth
			)
		var _removed: Variant = _active.pop_back()
		return
	if (
		value is String
		or value is StringName
		or value is NodePath
	):
		_emit(
			PackedByteArray([tag]),
			path
		)
		_string(
			str(value),
			path
		)
		return
	if type >= TYPE_PACKED_BYTE_ARRAY and type <= TYPE_PACKED_VECTOR4_ARRAY:
		_packed(
			value,
			tag,
			path
		)
		return
	var payload: PackedByteArray = PackedByteArray([tag])
	match type:
		TYPE_NIL:
			pass
		TYPE_BOOL:
			var _appended: bool = payload.append(1 if value else 0)
		TYPE_INT:
			var integer_value: int = value
			var _resized: int = payload.resize(9)
			payload.encode_s64(1, integer_value)
		TYPE_FLOAT:
			var float_value: float = value
			if not _float_ok(float_value, path):
				return
			var _resized: int = payload.resize(9)
			payload.encode_double(
				1,
				0.0 if float_value == 0.0 else float_value
			)
		_:
			var integers: bool = type in [
				TYPE_VECTOR2I,
				TYPE_VECTOR3I,
				TYPE_VECTOR4I,
				TYPE_RECT2I,
			]
			var components: Array = _math_components(value)
			var _resized: int = payload.resize(1 + components.size() * 8)
			for index: int in components.size():
				if integers:
					var integer_component: int = components[index]
					payload.encode_s64(
						1 + index * 8,
						integer_component
					)
				else:
					var component: float = components[index]
					if not _float_ok(component, path):
						return
					payload.encode_double(
						1 + index * 8,
						0.0 if component == 0.0 else component
					)
	_emit(payload, path)


## 数组声明类型不进入值编码；对象类型容器即使为空也拒绝。
## [br]
## @api private
func _array(
	value: Array,
	path: String,
	depth: int
) -> void:
	if value.get_typed_builtin() == TYPE_OBJECT:
		_fail("unsupported_type", path)
		return
	if not _admit_items(
		value.size(),
		path
	):
		return
	_emit(
		_header(
			40,
			value.size()
		),
		path
	)
	for index: int in value.size():
		_value(
			value[index],
			"%s[%d]"
			% [path, index],
			depth + 1
		)
		if not _report["ok"]:
			return


## 对键的完整 canonical 字节按无符号字节字典序排序，值随后编码。
## [br]
## @api private
func _dictionary(
	value: Dictionary,
	path: String,
	depth: int
) -> void:
	if value.get_typed_key_builtin() == TYPE_OBJECT or value.get_typed_value_builtin() == TYPE_OBJECT:
		_fail("unsupported_type", path)
		return
	if not _admit_items(
		value.size() * 2,
		path
	):
		return
	_emit(
		_header(
			41,
			value.size()
		),
		path
	)
	var entries: Array[Dictionary] = []
	var index: int = 0
	for key: Variant in value:
		var entry_path: String = (
			"%s[%d]"
			% [path, index]
		)
		if not _reserve_sort(128, entry_path):
			return
		var sink: _ByteSink = _ByteSink.new()
		_key_sinks.append(sink)
		_value(
			key,
			entry_path + ".key",
			depth + 1
		)
		var _removed_sink: _ByteSink = _key_sinks.pop_back()
		if not _report["ok"] or not _reserve_sort(
			sink._buffer.size() * 8,
			entry_path
		):
			return
		entries.append(
			{
				"key": key,
				"bytes": sink._buffer,
				"order": sink._buffer.hex_encode(),
				"workspace": sink._buffer.size() * 9 + 128,
				"path": entry_path,
			}
		)
		index += 1
	entries.sort_custom(_key_less)
	if not _check(path, true):
		return
	for sorted_index: int in range(
		1,
		entries.size()
	):
		if entries[sorted_index - 1]["order"] == entries[sorted_index]["order"]:
			var duplicate_path: String = entries[sorted_index]["path"]
			_fail("ambiguous_dictionary_key", duplicate_path)
			return
	for entry: Dictionary in entries:
		var key_bytes: PackedByteArray = entry["bytes"]
		var entry_path: String = entry["path"]
		var workspace: int = entry["workspace"]
		_forward(key_bytes, entry_path)
		_sort_bytes -= workspace - 128
		key_bytes = PackedByteArray()
		entry["bytes"] = PackedByteArray()
		entry["order"] = ""
		_value(
			value[entry["key"]],
			entry_path + ".value",
			depth + 1
		)
		if not _report["ok"]:
			return
	_sort_bytes -= entries.size() * 128


## 十六进制键排序等价于无符号字节序；使用引擎字符串比较。
## [br]
## @api private
func _key_less(left: Dictionary, right: Dictionary) -> bool:
	return left["order"] < right["order"]


## 先按本机块测量 UTF-8 长度，再输出同样的受限分块，不构建完整字符串字节。
## [br]
## @api private
func _string(value: String, path: String) -> void:
	if value.length() > _limits["max_string_length"]:
		_limit(
			"max_string_length",
			value.length(),
			path
		)
		return
	if not _can_output(
		8 + value.length(),
		path
	):
		return
	var size: int = 0
	for offset: int in range(
		0,
		value.length(),
		4096
	):
		if not _check(path):
			return
		size += value.substr(offset, 4096).to_utf8_buffer().size()
		if not _can_output(
			8 + size,
			path
		):
			return
	var length_bytes: PackedByteArray = PackedByteArray()
	var _resized: int = length_bytes.resize(8)
	length_bytes.encode_u64(0, size)
	_emit(length_bytes, path)
	for offset: int in range(
		0,
		value.length(),
		4096
	):
		_emit(
			value.substr(offset, 4096).to_utf8_buffer(),
			path
		)
		if not _report["ok"]:
			return


## Packed 整数块直接使用本机字节，再统一端序；浮点块校验后归一负零。
## [br]
## @api private
func _packed(
	value: Variant,
	tag: int,
	path: String
) -> void:
	var count: int = _packed_count(value)
	if not _consume_items(count, path):
		return
	_report["packed_items"] += count
	if value is PackedStringArray:
		var strings: PackedStringArray = value
		_emit(
			_header(tag, count),
			path
		)
		for index: int in count:
			_string(
				strings[index],
				"%s[%d]"
				% [path, index]
			)
			if not _report["ok"]:
				return
		return
	var width: int = _packed_width(typeof(value))
	var maximum_bytes: int = _limits["max_output_bytes"]
	var output_bytes: int = _report["output_bytes"]
	# Int64 budgets require exact truncation before the multiplication overflow check.
	@warning_ignore("integer_division")
	var maximum_elements: int = (maximum_bytes - output_bytes) / width
	if count > maximum_elements:
		_limit(
			"max_output_bytes",
			_over_limit("max_output_bytes"),
			path
		)
		return
	if not _can_output(
		9 + count * width,
		path
	):
		return
	if tag >= 53 and not _allow_floats:
		_fail("float_disabled", path)
		return
	_emit(
		_header(tag, count),
		path
	)
	var block_items: int = maxi(
		1,
		floori(float(_CHUNK_BYTES) / float(width))
	)
	for offset: int in range(
		0,
		count,
		block_items
	):
		if not _check(path, true):
			return
		var chunk: PackedByteArray = _packed_chunk(
			value,
			offset,
			mini(
				offset + block_items,
				count
			),
			path
		)
		if not _report["ok"]:
			return
		var scalar_width: int = width if tag <= 54 else 8
		if not _native_little_endian and scalar_width > 1:
			for index: int in range(
				0,
				chunk.size(),
				scalar_width
			):
				for byte_index: int in scalar_width >> 1:
					var opposite: int = index + scalar_width - 1 - byte_index
					var temporary: int = chunk[index + byte_index]
					chunk[index + byte_index] = chunk[opposite]
					chunk[opposite] = temporary
		_emit(chunk, path)


## 校验浮点政策、有限性；-0 在写入时统一为 +0。
## [br]
## @api private
func _float_ok(value: float, path: String) -> bool:
	if not _allow_floats:
		_fail("float_disabled", path)
		return false
	if not is_finite(value):
		_fail("nonfinite_float", path)
		return false
	return true


## 类型标签后紧跟小端 uint64 元素数量。
## [br]
## @api private
func _header(tag: int, count: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	var _resized: int = bytes.resize(9)
	bytes[0] = tag
	bytes.encode_u64(1, count)
	return bytes


## 编码字节只计量一次；已排序的键通过 _forward 复用。
## [br]
## @api private
func _emit(bytes: PackedByteArray, path: String) -> void:
	if not _check(path) or not _can_output(
		bytes.size(),
		path
	):
		return
	_report["output_bytes"] += bytes.size()
	_forward(bytes, path)


## 向键缓冲或最终 sink 写入已计量字节，哈希内存不随完整输出增长。
## [br]
## @api private
func _forward(bytes: PackedByteArray, path: String) -> void:
	if not _report["ok"]:
		return
	if not _key_sinks.is_empty():
		if _reserve_sort(
			bytes.size(),
			path
		):
			_key_sinks[-1]._buffer.append_array(bytes)
	elif _mode == &"bytes":
		_buffer.append_array(bytes)
	elif _mode == &"hash":
		if bytes.size() <= _CHUNK_BYTES:
			if _buffer.size() + bytes.size() > _CHUNK_BYTES:
				_flush()
			if _report["ok"]:
				_buffer.append_array(bytes)
			return
		for offset: int in range(
			0,
			bytes.size(),
			_CHUNK_BYTES
		):
			if not _check(path):
				return
			var size: int = mini(
				_CHUNK_BYTES,
				bytes.size() - offset
			)
			if _buffer.size() + size > _CHUNK_BYTES:
				_flush()
			if _report["ok"]:
				_buffer.append_array(
					bytes.slice(
						offset,
						offset + size
					)
				)


## 将有界块交给引擎哈希器。
## [br]
## @api private
func _flush() -> void:
	if not _buffer.is_empty() and _hashing.update(_buffer) != OK:
		_fail("hash_failed", "$")
	_buffer.clear()


## 输出预算以 canonical v2 字节为单位，预留检查避免溢出。
## [br]
## @api private
func _can_output(amount: int, path: String) -> bool:
	if not _report["ok"]:
		return false
	var maximum_bytes: int = _limits["max_output_bytes"]
	var output_bytes: int = _report["output_bytes"]
	if amount > maximum_bytes - output_bytes:
		_limit(
			"max_output_bytes",
			_over_limit("max_output_bytes"),
			path
		)
		return false
	return true


## 在分配容器工作区前检查至少需要访问的子项数。
## [br]
## @api private
func _admit_items(amount: int, path: String) -> bool:
	var maximum_items: int = _limits["max_items"]
	var current_items: int = _report["items"]
	if amount > maximum_items - current_items:
		_limit(
			"max_items",
			_over_limit("max_items"),
			path
		)
		return false
	return _report["ok"]


## 节点和 Packed 元素使用同一有限工作量预算。
## [br]
## @api private
func _consume_items(amount: int, path: String) -> bool:
	if not _admit_items(amount, path):
		return false
	_report["items"] += amount
	return true


## 排序预算包括键字节、UTF-32 十六进制字符串及每项 128 字节逻辑开销。
## [br]
## @api private
func _reserve_sort(amount: int, path: String) -> bool:
	var maximum_sort_bytes: int = _limits["max_sort_bytes"]
	if amount > maximum_sort_bytes - _sort_bytes:
		_limit(
			"max_sort_bytes",
			_over_limit("max_sort_bytes"),
			path
		)
		return false
	_sort_bytes += amount
	var peak_sort_bytes: int = _report["peak_sort_bytes"]
	_report["peak_sort_bytes"] = maxi(peak_sort_bytes, _sort_bytes)
	return true


## 每 256 个受控步骤或分块边界检查时间及取消；排序调用本身是有限原子步骤。
## [br]
## @api private
func _check(path: String, force: bool = false) -> bool:
	if not _report["ok"]:
		return false
	_steps += 1
	if not force and _steps % 256 != 0:
		return true
	if _cancel_token != null and _cancel_token.is_cancel_requested():
		_fail("cancelled", path)
		return false
	var elapsed: int = Time.get_ticks_msec() - _started
	if elapsed > _limits["max_elapsed_msec"]:
		_limit(
			"max_elapsed_msec",
			elapsed,
			path
		)
		return false
	return true


## 最大 int64 上限不会因诊断下界加一而溢出。
## [br]
## @api private
func _over_limit(name: String) -> int:
	var limit: int = _limits[name]
	return limit + 1 if limit < 9223372036854775807 else limit


## 首个失败锁存，后续不再执行或发布输出。
## [br]
## @api private
func _fail(kind: String, path: String) -> void:
	if _report["ok"]:
		_report["ok"] = false
		_report["error_kind"] = kind
		_report["error_path"] = path
		_report["failure_kind"] = "input_invalid"
		_report["error"] = (
			"Canonical v2 %s at %s."
			% [kind, path]
		)


## 限额报告的 observed 是下界，成功前不声称完整计量。
## [br]
## @api private
func _limit(
	name: String,
	observed: int,
	path: String
) -> void:
	if not _report["ok"]:
		return
	_fail("limit_exceeded", path)
	_report["limit_kind"] = name
	_report["limit"] = _limits[name]
	_report["observed"] = observed
	_report["observed_is_lower_bound"] = true
	if name == "max_output_bytes":
		_report["failure_kind"] = "output_limit"


## Packed 元素的协议宽度，不依赖 real_t 编译配置。
## [br]
## @api private
func _packed_width(type: int) -> int:
	match type:
		TYPE_PACKED_BYTE_ARRAY:
			return 1
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return 4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return 8
		TYPE_PACKED_VECTOR2_ARRAY:
			return 16
		TYPE_PACKED_VECTOR3_ARRAY:
			return 24
		TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return 32
	return 0


## 获取 Packed 长度而不展开为 Array。
## [br]
## @api private
func _packed_count(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var values: PackedByteArray = value
			return values.size()
		TYPE_PACKED_INT32_ARRAY:
			var values: PackedInt32Array = value
			return values.size()
		TYPE_PACKED_INT64_ARRAY:
			var values: PackedInt64Array = value
			return values.size()
		TYPE_PACKED_FLOAT32_ARRAY:
			var values: PackedFloat32Array = value
			return values.size()
		TYPE_PACKED_FLOAT64_ARRAY:
			var values: PackedFloat64Array = value
			return values.size()
		TYPE_PACKED_STRING_ARRAY:
			var values: PackedStringArray = value
			return values.size()
		TYPE_PACKED_VECTOR2_ARRAY:
			var values: PackedVector2Array = value
			return values.size()
		TYPE_PACKED_VECTOR3_ARRAY:
			var values: PackedVector3Array = value
			return values.size()
		TYPE_PACKED_VECTOR4_ARRAY:
			var values: PackedVector4Array = value
			return values.size()
		TYPE_PACKED_COLOR_ARRAY:
			var values: PackedColorArray = value
			return values.size()
	return 0


## 数值分块使用有界本机副本；数学 Packed 统一写 binary64 分量。
## [br]
## @api private
func _packed_chunk(
	value: Variant,
	start: int,
	end: int,
	path: String
) -> PackedByteArray:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var values: PackedByteArray = value
			return values.slice(start, end)
		TYPE_PACKED_INT32_ARRAY:
			var values: PackedInt32Array = value
			return values.slice(start, end).to_byte_array()
		TYPE_PACKED_INT64_ARRAY:
			var values: PackedInt64Array = value
			return values.slice(start, end).to_byte_array()
		TYPE_PACKED_FLOAT32_ARRAY:
			var values: PackedFloat32Array = value
			var chunk: PackedFloat32Array = values.slice(start, end)
			for index: int in chunk.size():
				if not _float_ok(
					chunk[index],
					path
				):
					return PackedByteArray()
				if chunk[index] == 0.0:
					chunk[index] = 0.0
			return chunk.to_byte_array()
		TYPE_PACKED_FLOAT64_ARRAY:
			var values: PackedFloat64Array = value
			var chunk: PackedFloat64Array = values.slice(start, end)
			for index: int in chunk.size():
				if not _float_ok(
					chunk[index],
					path
				):
					return PackedByteArray()
				if chunk[index] == 0.0:
					chunk[index] = 0.0
			return chunk.to_byte_array()
	var components: PackedFloat64Array = PackedFloat64Array()
	for index: int in range(start, end):
		for component: float in _math_components(_packed_math_item(value, index)):
			if not _float_ok(component, path):
				return PackedByteArray()
			var _appended: bool = components.append(0.0 if component == 0.0 else component)
	return components.to_byte_array()


## 仅索引当前数学 Packed 项，避免完整展开。
## [br]
## @api private
func _packed_math_item(value: Variant, index: int) -> Variant:
	match typeof(value):
		TYPE_PACKED_VECTOR2_ARRAY:
			var values: PackedVector2Array = value
			return values[index]
		TYPE_PACKED_VECTOR3_ARRAY:
			var values: PackedVector3Array = value
			return values[index]
		TYPE_PACKED_VECTOR4_ARRAY:
			var values: PackedVector4Array = value
			return values[index]
		TYPE_PACKED_COLOR_ARRAY:
			var values: PackedColorArray = value
			return values[index]
	return null


## 数学类型使用坐标顺序，矩阵按列，Transform3D 先 basis 后 origin。
## [br]
## @api private
func _math_components(value: Variant) -> Array:
	match typeof(value):
		TYPE_VECTOR2I:
			var item: Vector2i = value
			return [item.x, item.y]
		TYPE_VECTOR3I:
			var item: Vector3i = value
			return [
				item.x,
				item.y,
				item.z,
			]
		TYPE_VECTOR4I:
			var item: Vector4i = value
			return [
				item.x,
				item.y,
				item.z,
				item.w,
			]
		TYPE_RECT2I:
			var item: Rect2i = value
			return [
				item.position.x,
				item.position.y,
				item.size.x,
				item.size.y,
			]
		TYPE_VECTOR2:
			var item: Vector2 = value
			return [item.x, item.y]
		TYPE_VECTOR3:
			var item: Vector3 = value
			return [
				item.x,
				item.y,
				item.z,
			]
		TYPE_VECTOR4:
			var item: Vector4 = value
			return [
				item.x,
				item.y,
				item.z,
				item.w,
			]
		TYPE_RECT2:
			var item: Rect2 = value
			return [
				item.position.x,
				item.position.y,
				item.size.x,
				item.size.y,
			]
		TYPE_TRANSFORM2D:
			var item: Transform2D = value
			return [
				item.x.x,
				item.x.y,
				item.y.x,
				item.y.y,
				item.origin.x,
				item.origin.y,
			]
		TYPE_PLANE:
			var item: Plane = value
			return [
				item.normal.x,
				item.normal.y,
				item.normal.z,
				item.d,
			]
		TYPE_QUATERNION:
			var item: Quaternion = value
			return [
				item.x,
				item.y,
				item.z,
				item.w,
			]
		TYPE_AABB:
			var item: AABB = value
			return [
				item.position.x,
				item.position.y,
				item.position.z,
				item.size.x,
				item.size.y,
				item.size.z,
			]
		TYPE_BASIS:
			var item: Basis = value
			return [
				item.x.x,
				item.x.y,
				item.x.z,
				item.y.x,
				item.y.y,
				item.y.z,
				item.z.x,
				item.z.y,
				item.z.z,
			]
		TYPE_TRANSFORM3D:
			var item: Transform3D = value
			return [
				item.basis.x.x,
				item.basis.x.y,
				item.basis.x.z,
				item.basis.y.x,
				item.basis.y.y,
				item.basis.y.z,
				item.basis.z.x,
				item.basis.z.y,
				item.basis.z.z,
				item.origin.x,
				item.origin.y,
				item.origin.z,
			]
		TYPE_PROJECTION:
			var item: Projection = value
			return [
				item.x.x,
				item.x.y,
				item.x.z,
				item.x.w,
				item.y.x,
				item.y.y,
				item.y.z,
				item.y.w,
				item.z.x,
				item.z.y,
				item.z.z,
				item.z.w,
				item.w.x,
				item.w.y,
				item.w.z,
				item.w.w,
			]
		TYPE_COLOR:
			var item: Color = value
			return [
				item.r,
				item.g,
				item.b,
				item.a,
			]
	return []


# --- 内部类 ---

## 引用接收器避免 Packed 值在每次追加时触发 copy-on-write。
## [br]
## @api private
class _ByteSink extends RefCounted:


	# --- 私有变量 ---

	## 当前键的独占编码缓冲。
	## [br]
	## @api private
	var _buffer: PackedByteArray = PackedByteArray()
