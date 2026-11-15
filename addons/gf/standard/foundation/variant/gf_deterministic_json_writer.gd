# GF 确定性 JSON 的内部文本写入器；只在成功时发布完整输出。
extends "res://addons/gf/standard/foundation/variant/gf_deterministic_json_support.gd"


# --- 公共变量 ---

## 解码后的键已计过节点，只规范化排序文本时关闭重复计数。
## [br]
## @api framework_internal
var count_items: bool = true


# --- 私有变量 ---

## 当前路径上的容器身份；别名按值展开，循环立即失败。
## [br]
## @api private
var _active: Array = []

## 输出和嵌套键的独立接收器。
## [br]
## @api private
var _sinks: Array[_Sink] = []

## 最外层键的逻辑根深度；限制整个键树以避开 Godot 原生哈希递归上限。
## [br]
## @api private
var _key_root: int = -1


# --- 框架内部方法 ---

## 一次编码完成预算检查与输出；快照只借用，不导出可变副本。
## [br]
## @api framework_internal
## [br]
## @param value: 源数据或快照。
## [br]
## @schema value: Pure Variant or ready GFDataSnapshot.
## [br]
## @param options: 本次预算。
## [br]
## @schema options: Deterministic JSON encoding limits.
## [br]
## @return 仅成功时带完整文本的报告。
## [br]
## @schema return: Deterministic JSON report with text, identity, counters and failure details.
func run(value: Variant, options: Dictionary) -> Dictionary:
	configure(options, false)
	var source: Variant = value
	if value is GFDataSnapshot:
		var snapshot: GFDataSnapshot = value
		if not snapshot.is_ready():
			fail("snapshot_unavailable", "$")
		else:
			source = snapshot.get_value_for_framework()
	_sinks.append(_Sink.new(false))
	_emit("{\n  \"format\": \"gf.variant-json-deterministic\",\n  \"version\": 1,\n  \"value\": ", "$")
	_write_node(
		source,
		0,
		"$",
		true,
		1
	)
	_emit("\n}\n", "$")
	var output: String = _sinks[0]._finish() if check("$") else ""
	if not check("$"):
		output = ""
	report["text"] = output
	report["counts_complete"] = report["ok"]
	_sinks.clear()
	_active.clear()
	return report


## 生成无缩进的完整键文本并保留其排序预算，供调用者消费后释放。
## [br]
## @api framework_internal
## [br]
## @param value: 键值。
## [br]
## @schema value: Pure Variant dictionary key.
## [br]
## @param depth: 原始逻辑深度。
## [br]
## @param path: 键路径。
## [br]
## @return 完整键文本；失败为空。成功占用字符数乘 8 的逻辑排序字节。
func make_key(
	value: Variant,
	depth: int,
	path: String
) -> String:
	var sink: _Sink = _Sink.new(true)
	_sinks.append(sink)
	var previous_key_root: int = _key_root
	if _key_root < 0:
		_key_root = depth
	_write_node(
		value,
		depth,
		path,
		false,
		0
	)
	var output: String = sink._finish() if check(path) else ""
	var _removed: _Sink = _sinks.pop_back()
	_key_root = previous_key_root
	if not check(path):
		release_sort(sink._sort_cost)
		return ""
	return output


# --- 私有/辅助方法 ---

## 分块写入前验证 UTF-8 输出或键工作区预算。
## [br]
## @api private
func _emit(text: String, path: String) -> void:
	if not check(path):
		return
	var sink: _Sink = _sinks.back()
	for offset: int in range(
		0,
		text.length(),
		4096
	):
		var fragment: String = text.substr(offset, 4096)
		var byte_count: int = fragment.to_utf8_buffer().size()
		if sink._key:
			var option: String = "max_input_bytes" if control["decode"] else "max_output_bytes"
			var maximum: int = limits[option]
			if byte_count > maximum - sink._bytes_count:
				exceed(
					option,
					maximum + 1 if maximum < 9223372036854775807 else maximum,
					path
				)
				return
			var cost: int = fragment.length() * 8
			if not reserve_sort(cost, path):
				return
			sink._sort_cost += cost
		elif not consume(
			"output_bytes",
			byte_count,
			"max_output_bytes",
			path
		):
			return
		sink._bytes_count += byte_count
		sink._append_text(fragment)


## 固定 JSON 转义，拒绝非 Unicode 标量；用户字符串在展开前检查长度。
## [br]
## @api private
func _quote(
	value: String,
	path: String,
	payload: bool = true
) -> void:
	var maximum: int = limits["max_string_length"]
	if payload and value.length() > maximum:
		exceed(
			"max_string_length",
			value.length(),
			path
		)
		return
	_emit("\"", path)
	var chunk: String = ""
	for index: int in value.length():
		if index % 256 == 0 and not check(path):
			return
		var code: int = value.unicode_at(index)
		if (
			code == 0
			or code > 0x10ffff
			or (
				code >= 0xd800
				and code <= 0xdfff
			)
		):
			fail("invalid_unicode", path)
			return
		match code:
			34:
				chunk += "\\\""
			92:
				chunk += "\\\\"
			8:
				chunk += "\\b"
			9:
				chunk += "\\t"
			10:
				chunk += "\\n"
			12:
				chunk += "\\f"
			13:
				chunk += "\\r"
			_:
				chunk += ("\\u%04x" % code) if code < 32 else String.chr(code)
		if chunk.length() >= 4096:
			_emit(chunk, path)
			chunk = ""
	_emit(
		chunk + "\"",
		path
	)


## 缩进仅由协议控制，键文本始终无空白。
## [br]
## @api private
func _comma(pretty: bool) -> String:
	return ", " if pretty else ","


## 容器列表项换行；空列表保持单行。
## [br]
## @api private
func _line(
	pretty: bool,
	level: int,
	path: String
) -> void:
	if pretty:
		_emit(
			"\n" + "  ".repeat(level),
			path
		)


## 每个源值只遍历一次；字典键的已完成文本会直接复用。
## [br]
## @api private
func _write_node(
	value: Variant,
	depth: int,
	path: String,
	pretty: bool,
	level: int
) -> void:
	if (
		not check(path)
		or (
			count_items
			and not visit(depth, path)
		)
	):
		return
	var kind: int = typeof(value)
	if not TAGS.has(kind):
		fail("unsupported_type", path)
		return
	if value is Array or value is Dictionary:
		var key_depth: int = depth - _key_root + 1
		var maximum_key_depth: int = limits["max_key_depth"]
		if _key_root >= 0 and key_depth > maximum_key_depth:
			exceed(
				"max_key_depth",
				key_depth,
				path
			)
			return
		for ancestor: Variant in _active:
			if is_same(ancestor, value):
				fail("cycle", path)
				return
		_active.append(value)
	var tag: String = TAGS[kind]
	_emit(
		"[" + JSON.stringify(tag),
		path
	)
	match kind:
		TYPE_NIL:
			pass
		TYPE_BOOL:
			_emit(
				_comma(pretty) + ("true" if value else "false"),
				path
			)
		TYPE_INT:
			var integer: int = value
			_emit(
				_comma(pretty),
				path
			)
			_quote(
				str(integer),
				path,
				false
			)
		TYPE_FLOAT:
			var number: float = value
			_emit(
				_comma(pretty),
				path
			)
			_quote(
				float_text(number),
				path,
				false
			)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			_emit(
				_comma(pretty),
				path
			)
			_quote(
				str(value),
				path
			)
		TYPE_ARRAY:
			var array: Array = value
			_write_array(
				array,
				depth,
				path,
				pretty,
				level
			)
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			_write_dictionary(
				dictionary,
				depth,
				path,
				pretty,
				level
			)
		_:
			_emit(
				_comma(pretty),
				path
			)
			if COMPONENTS.has(kind):
				_write_components(
					value,
					path,
					pretty
				)
			else:
				_write_packed(
					value,
					kind,
					depth,
					path,
					pretty,
					level
				)
	_emit("]", path)
	if value is Array or value is Dictionary:
		var _ancestor: Variant = _active.pop_back()


## 内置类型声明使用固定类型名；对象类型声明即使为空也失败。
## [br]
## @api private
func _container_tag(kind: int, path: String) -> String:
	if kind == TYPE_NIL:
		return "Variant"
	if not TAGS.has(kind):
		fail("unsupported_type", path)
		return ""
	return TAGS[kind]


## 保留数组类型声明，逐项编码并观察预算。
## [br]
## @api private
func _write_array(
	value: Array,
	depth: int,
	path: String,
	pretty: bool,
	level: int
) -> void:
	_emit(
		_comma(pretty),
		path
	)
	_quote(
		_container_tag(
			value.get_typed_builtin(),
			path
		),
		path,
		false
	)
	_emit(
		_comma(pretty) + "[",
		path
	)
	for index: int in value.size():
		if not check(path):
			break
		if index > 0:
			_emit(",", path)
		_line(
			pretty,
			level + 1,
			path
		)
		_write_node(
			value[index],
			depth + 1,
			path + "[%d]" % index,
			pretty,
			level + 1
		)
	if not value.is_empty():
		_line(
			pretty,
			level,
			path
		)
	_emit("]", path)


## 完整键文本按 UTF-8 字节序排序；有效 Unicode 字符串的码点序与此相同。
## 保留全部条目头到父字典完成，键文本在写出后、递归值之前释放。
## [br]
## @api private
func _write_dictionary(
	value: Dictionary,
	depth: int,
	path: String,
	pretty: bool,
	level: int
) -> void:
	_emit(
		_comma(pretty),
		path
	)
	_quote(
		_container_tag(
			value.get_typed_key_builtin(),
			path
		),
		path,
		false
	)
	_emit(
		_comma(pretty),
		path
	)
	_quote(
		_container_tag(
			value.get_typed_value_builtin(),
			path
		),
		path,
		false
	)
	_emit(
		_comma(pretty) + "[",
		path
	)
	var headers: int = value.size() * 128
	if not reserve_sort(headers, path):
		return
	var entries: Array[Dictionary] = []
	var ordinal: int = 0
	for key: Variant in value:
		var key_text: String = make_key(
			key,
			depth + 1,
			path + "[%d].key" % ordinal
		)
		if not report["ok"]:
			break
		entries.append({ "text": key_text, "value": value[key] })
		ordinal += 1
	if check(path):
		entries.sort_custom(_entry_before)
	for index: int in range(
		1,
		entries.size()
	):
		if not check(path):
			break
		if entries[index]["text"] == entries[index - 1]["text"]:
			fail(
				"ambiguous_dictionary_key",
				path + "[%d].key" % index
			)
			break
	for index: int in entries.size():
		if not check(path):
			break
		var key_text: String = entries[index]["text"]
		if index > 0:
			_emit(",", path)
		_line(
			pretty,
			level + 1,
			path
		)
		_emit("[", path)
		_emit(key_text, path)
		_emit(
			_comma(pretty),
			path
		)
		var key_cost: int = key_text.length() * 8
		entries[index]["text"] = ""
		key_text = ""
		release_sort(key_cost)
		_write_node(
			entries[index]["value"],
			depth + 1,
			path + "[%d].value" % index,
			pretty,
			level + 1
		)
		_emit("]", path)
	for entry: Dictionary in entries:
		var key_text: String = entry["text"]
		release_sort(key_text.length() * 8)
	entries.clear()
	release_sort(headers)
	if not value.is_empty():
		_line(
			pretty,
			level,
			path
		)
	_emit("]", path)


## 排序比较不遍历源值，不以摘要代替完整编码。
## [br]
## @api private
func _entry_before(left: Dictionary, right: Dictionary) -> bool:
	var left_text: String = left["text"]
	var right_text: String = right["text"]
	return left_text < right_text


## 数学分量不额外消耗节点预算，特殊浮点由协议标记文本表达。
## [br]
## @api private
func _write_components(
	value: Variant,
	path: String,
	pretty: bool
) -> void:
	_emit("[", path)
	var values: Array = components(value)
	for index: int in values.size():
		if index > 0:
			_emit(
				_comma(pretty),
				path
			)
		var component: Variant = values[index]
		if component is int:
			_quote(
				str(component),
				path,
				false
			)
		elif component is float:
			var number: float = component
			_quote(
				float_text(number),
				path,
				false
			)
	_emit("]", path)


## 获取 Packed 容器长度而不转换为普通数组。
## [br]
## @api private
func _packed_count(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var packed_byte_array: PackedByteArray = value
			return packed_byte_array.size()
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32_array: PackedInt32Array = value
			return packed_int32_array.size()
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64_array: PackedInt64Array = value
			return packed_int64_array.size()
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32_array: PackedFloat32Array = value
			return packed_float32_array.size()
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64_array: PackedFloat64Array = value
			return packed_float64_array.size()
		TYPE_PACKED_STRING_ARRAY:
			var packed_string_array: PackedStringArray = value
			return packed_string_array.size()
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector2_array: PackedVector2Array = value
			return packed_vector2_array.size()
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector3_array: PackedVector3Array = value
			return packed_vector3_array.size()
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector4_array: PackedVector4Array = value
			return packed_vector4_array.size()
		TYPE_PACKED_COLOR_ARRAY:
			var packed_color_array: PackedColorArray = value
			return packed_color_array.size()
	return 0


## Packed 内容逐项输出，避免展开中间 JSON 树。
## [br]
## @api private
func _write_packed(
	value: Variant,
	kind: int,
	depth: int,
	path: String,
	pretty: bool,
	level: int
) -> void:
	_emit("[", path)
	var size: int = _packed_count(value)
	for index: int in size:
		var item_path: String = path + "[%d]" % index
		if (
			not check(item_path)
			or (
				count_items
				and not visit(
					depth,
					item_path,
					true
				)
			)
		):
			break
		if index > 0:
			_emit(",", path)
		_line(
			pretty,
			level + 1,
			path
		)
		var item: Variant = value[index]
		if kind == TYPE_PACKED_STRING_ARRAY:
			_quote(
				str(item),
				item_path
			)
		elif item is int:
			_quote(
				str(item),
				item_path,
				false
			)
		elif item is float:
			var number: float = item
			_quote(
				float_text(number),
				item_path,
				false
			)
		else:
			_write_components(
				item,
				item_path,
				pretty
			)
	if size > 0:
		_line(
			pretty,
			level,
			path
		)
	_emit("]", path)


# --- 内部类 ---

## 有界分块累积器；最终文本只连接一次，避免逐字扩展整个输出。
## [br]
## @api private
class _Sink:
	extends RefCounted


	# --- 私有变量 ---

	## 是否为暂存字典键。
	## [br]
	## @api private
	var _key: bool

	## 当前 UTF-8 字节数。
	## [br]
	## @api private
	var _bytes_count: int = 0

	## 当前已入账排序成本。
	## [br]
	## @api private
	var _sort_cost: int = 0

	## 完成的固定大小片段。
	## [br]
	## @api private
	var _parts: PackedStringArray = PackedStringArray()

	## 未满 4096 字符的尾部。
	## [br]
	## @api private
	var _tail: String = ""


	# --- Godot 生命周期方法 ---

	## 建立输出或排序接收器。
	## [br]
	## @api private
	func _init(for_key: bool) -> void:
		_key = for_key


	# --- 私有/辅助方法 ---

	## 上层先检查预算，这里只追加已准入片段。
	## [br]
	## @api private
	func _append_text(text: String) -> void:
		_tail += text
		if _tail.length() >= 4096:
			var _appended: bool = _parts.append(_tail)
			_tail = ""


	## 最终连接仅发生一次，输出大小已受上层预算限制。
	## [br]
	## @api private
	func _finish() -> String:
		if not _tail.is_empty():
			var _appended: bool = _parts.append(_tail)
			_tail = ""
		return "".join(_parts)
