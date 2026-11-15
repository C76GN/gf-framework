# GF 确定性 JSON 的内部有界读取器；不构建完整通用 JSON 中间树。
extends "res://addons/gf/standard/foundation/variant/gf_deterministic_json_support.gd"


# --- 常量 ---

## 键的规范文本与写入路径共用实现，避免排序规则漂移。
## [br]
## @api private
const _WRITER_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_deterministic_json_writer.gd")


# --- 私有变量 ---

## 本次只读输入；运行结束后释放。
## [br]
## @api private
var _text: String = ""

## Unicode 字符游标。
## [br]
## @api private
var _position: int = 0

## 最外层键的逻辑根深度；在构造可被原生哈希的集合前检查。
## [br]
## @api private
var _key_root: int = -1


# --- 框架内部方法 ---

## 校验版本后逐步恢复原始值，每次分配受节点、字符及输入预算约束。
## [br]
## @api framework_internal
## [br]
## @param text: GF 确定性 JSON。
## [br]
## @param options: 本次预算。
## [br]
## @schema options: Deterministic JSON decoding limits and optional cancellation token.
## [br]
## @return 完整值或结构化失败。
## [br]
## @schema return: Dictionary with ok, value, format identity, counters and failure details.
func run(text: String, options: Dictionary) -> Dictionary:
	configure(options, true)
	_text = text
	_measure_input()
	var _opened: bool = _expect("{", "$")
	_field("format")
	if _read_string("$", false) != FORMAT_ID:
		fail("unsupported_format", "$")
	var _comma_format: bool = _expect(",", "$")
	_field("version")
	_skip_space("$")
	var version: String = ""
	while (
		report["ok"]
		and _peek() >= 48
		and _peek() <= 57
		and version.length() < 20
	):
		version += String.chr(_peek())
		_position += 1
	if version != "1":
		fail("unsupported_version", "$")
	var _comma_version: bool = _expect(",", "$")
	_field("value")
	var result: Variant = _read_node(0, "$")
	var _closed: bool = _expect("}", "$")
	_skip_space("$")
	if _position != _text.length():
		fail("invalid_json", "$")
	var _completed: bool = check("$")
	report["counts_complete"] = report["ok"]
	report["value"] = result if report["ok"] else null
	_text = ""
	return report


# --- 私有/辅助方法 ---

## 先用字符下界拒绝明显超限，再分块计算 UTF-8；避免一次复制全部输入。
## [br]
## @api private
func _measure_input() -> void:
	var maximum: int = limits["max_input_bytes"]
	if _text.length() > maximum:
		exceed(
			"max_input_bytes",
			_text.length(),
			"$"
		)
		return
	for offset: int in range(
		0,
		_text.length(),
		4096
	):
		if not check("$"):
			return
		var fragment: String = _text.substr(offset, 4096)
		for index: int in fragment.length():
			var code: int = fragment.unicode_at(index)
			if (
				code > 0x10ffff
				or (
					code >= 0xd800
					and code <= 0xdfff
				)
			):
				fail("invalid_unicode", "$")
				return
		if not consume(
			"input_bytes",
			fragment.to_utf8_buffer().size(),
			"max_input_bytes",
			"$"
		):
			return


## 只接受固定根字段顺序，不猜测未知包裹格式。
## [br]
## @api private
func _field(field: String) -> void:
	if _read_string("$", false) != field:
		fail("invalid_envelope", "$")
	var _colon: bool = _expect(":", "$")


## 文件结束返回 -1，避免越界访问触发引擎诊断。
## [br]
## @api private
func _peek() -> int:
	return _text.unicode_at(_position) if _position < _text.length() else -1


## 仅接受 JSON 的四种空白；每 256 个字符检查执行预算。
## [br]
## @api private
func _skip_space(path: String) -> void:
	while report["ok"] and _peek() in [
		32,
		9,
		10,
		13,
	]:
		if _position % 256 == 0 and not check(path):
			return
		_position += 1


## 标点与短字面量的有界读取；失败后所有调用保持无副作用。
## [br]
## @api private
func _expect(token: String, path: String) -> bool:
	if not check(path):
		return false
	_skip_space(path)
	if _text.substr(
		_position,
		token.length()
	) != token:
		fail("invalid_json", path)
		return false
	_position += token.length()
	return true


## 分块还原字符串；协议标签和数值文本另受 64 字符固定上限约束。
## [br]
## @api private
func _read_string(path: String, payload: bool = true) -> String:
	if not _expect("\"", path):
		return ""
	var maximum: int = limits["max_string_length"] if payload else 64
	var characters: int = 0
	var chunks: PackedStringArray = PackedStringArray()
	var chunk: String = ""
	while check(path):
		var code: int = _peek()
		_position += 1
		if code == 34:
			var _tail: bool = chunks.append(chunk)
			return "".join(chunks)
		if code < 32:
			fail("invalid_json", path)
			return ""
		if code == 92:
			code = _escape(path)
		if not report["ok"]:
			return ""
		if characters >= maximum:
			if payload:
				exceed(
					"max_string_length",
					characters + 1,
					path
				)
			else:
				fail("invalid_payload", path)
			return ""
		characters += 1
		chunk += String.chr(code)
		if chunk.length() >= 4096:
			var _part: bool = chunks.append(chunk)
			chunk = ""
	return ""


## JSON 转义只接受标准形式，孤立 surrogate 明确失败。
## [br]
## @api private
func _escape(path: String) -> int:
	var code: int = _peek()
	_position += 1
	match code:
		34, 47, 92:
			return code
		98:
			return 8
		102:
			return 12
		110:
			return 10
		114:
			return 13
		116:
			return 9
		117:
			var first: int = _hex_quad(path)
			if first == 0:
				fail("invalid_unicode", path)
				return 0
			if first >= 0xdc00 and first <= 0xdfff:
				fail("invalid_unicode", path)
				return 0
			if first >= 0xd800 and first <= 0xdbff:
				if _text.substr(_position, 2) != "\\u":
					fail("invalid_unicode", path)
					return 0
				_position += 2
				var second: int = _hex_quad(path)
				if second < 0xdc00 or second > 0xdfff:
					fail("invalid_unicode", path)
					return 0
				return 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00
			return first
	fail("invalid_json", path)
	return 0


## 固定四个十六进制数字，不接受缺失或非法数字。
## [br]
## @api private
func _hex_quad(path: String) -> int:
	var result: int = 0
	for index: int in 4:
		var code: int = _peek()
		_position += 1
		var digit: int = -1
		if code >= 48 and code <= 57:
			digit = code - 48
		elif code >= 65 and code <= 70:
			digit = code - 65 + 10
		elif code >= 97 and code <= 102:
			digit = code - 97 + 10
		if digit < 0:
			fail("invalid_unicode", path)
			return 0
		result = (result << 4) | digit
	return result


## 按显式标签直接生成内置值，不将普通业务字典误认成标记。
## [br]
## @api private
func _read_node(depth: int, path: String) -> Variant:
	if not visit(depth, path) or not _expect("[", path):
		return null
	var tag: String = _read_string(path, false)
	var kind: int = kind_for_tag(tag)
	if kind < 0:
		fail("unsupported_type", path)
		return null
	if _key_root >= 0 and kind in [TYPE_ARRAY, TYPE_DICTIONARY]:
		var key_depth: int = depth - _key_root + 1
		var maximum_key_depth: int = limits["max_key_depth"]
		if key_depth > maximum_key_depth:
			exceed(
				"max_key_depth",
				key_depth,
				path
			)
			return null
	var value: Variant = null
	if kind != TYPE_NIL:
		var _comma: bool = _expect(",", path)
	match kind:
		TYPE_NIL:
			pass
		TYPE_BOOL:
			_skip_space(path)
			if _peek() == 116:
				value = _expect("true", path)
			else:
				var _false_read: bool = _expect("false", path)
				value = false
		TYPE_INT:
			value = read_integer(
				_read_string(path, false),
				path
			)
		TYPE_FLOAT:
			value = read_float(
				_read_string(path, false),
				path
			)
		TYPE_STRING:
			value = _read_string(path)
		TYPE_STRING_NAME:
			value = StringName(_read_string(path))
		TYPE_NODE_PATH:
			var node_path_text: String = _read_string(path)
			if node_path_text.contains("::"):
				fail("invalid_node_path", path)
			elif report["ok"]:
				value = NodePath(node_path_text)
		TYPE_ARRAY:
			value = _read_array(depth, path)
		TYPE_DICTIONARY:
			value = _read_dictionary(depth, path)
		_:
			if COMPONENTS.has(kind):
				value = _read_math(kind, path)
			else:
				value = _read_packed(
					kind,
					depth,
					path
				)
	var _closed: bool = _expect("]", path)
	return value


## 只恢复内置类型声明，Variant 明确表示无声明。
## [br]
## @api private
func _declaration(path: String) -> int:
	var tag: String = _read_string(path, false)
	if tag == "Variant":
		return TYPE_NIL
	var kind: int = kind_for_tag(tag)
	if kind <= TYPE_NIL:
		fail("unsupported_type", path)
		return TYPE_NIL
	return kind


## 验证类型再插入，避免依赖会隐式转换或输出错误的原生容器操作。
## [br]
## @api private
func _matches(
	value: Variant,
	declared: int,
	path: String
) -> bool:
	if declared != TYPE_NIL and typeof(value) != declared:
		fail("type_mismatch", path)
		return false
	return report["ok"]


## 每个元素恢复后直接进入最终数组，无通用 JSON 中间树。
## [br]
## @api private
func _read_array(depth: int, path: String) -> Array:
	var declared: int = _declaration(path)
	var result: Array = Array(
		[],
		declared,
		&"",
		null
	)
	var _comma: bool = _expect(",", path)
	var _opened: bool = _expect("[", path)
	_skip_space(path)
	var index: int = 0
	while report["ok"] and _peek() != 93:
		if index > 0 and not _expect(",", path):
			break
		var item_path: String = path + "[%d]" % index
		var item: Variant = _read_node(
			depth + 1,
			item_path
		)
		if not _matches(
			item,
			declared,
			item_path
		):
			break
		result.append(item)
		index += 1
		_skip_space(path)
	var _closed: bool = _expect("]", path)
	return result


## 同时拒绝规范键重复和 Godot 容器等值碰撞；全部键工作区保持到本字典结束。
## [br]
## @api private
func _read_dictionary(depth: int, path: String) -> Dictionary:
	var key_kind: int = _declaration(path)
	var _comma_type: bool = _expect(",", path)
	var value_kind: int = _declaration(path)
	var result: Dictionary = Dictionary(
		{},
		key_kind,
		&"",
		null,
		value_kind,
		&"",
		null
	)
	var _comma: bool = _expect(",", path)
	var _opened: bool = _expect("[", path)
	var seen: Dictionary[String, bool] = {}
	var headers: int = 0
	var key_cost: int = 0
	var writer: _WRITER_SCRIPT = _WRITER_SCRIPT.new()
	writer.report = report
	writer.limits = limits
	writer.control = control
	writer.count_items = false
	_skip_space(path)
	var index: int = 0
	while report["ok"] and _peek() != 93:
		if index > 0 and not _expect(",", path):
			break
		if not reserve_sort(128, path):
			break
		headers += 128
		var _entry_opened: bool = _expect("[", path)
		var key_path: String = path + "[%d].key" % index
		var previous_key_root: int = _key_root
		if _key_root < 0:
			_key_root = depth + 1
		var key: Variant = _read_node(
			depth + 1,
			key_path
		)
		_key_root = previous_key_root
		if not _matches(
			key,
			key_kind,
			key_path
		):
			break
		var key_text: String = writer.make_key(
			key,
			depth + 1,
			key_path
		)
		if not report["ok"]:
			break
		key_cost += key_text.length() * 8
		if seen.has(key_text) or result.has(key):
			fail("duplicate_dictionary_key", key_path)
			break
		seen[key_text] = true
		var _entry_comma: bool = _expect(",", path)
		var value_path: String = path + "[%d].value" % index
		var value: Variant = _read_node(
			depth + 1,
			value_path
		)
		if not _matches(
			value,
			value_kind,
			value_path
		):
			break
		var _entry_closed: bool = _expect("]", path)
		if report["ok"]:
			result[key] = value
		index += 1
		_skip_space(path)
	var _closed: bool = _expect("]", path)
	seen.clear()
	release_sort(headers + key_cost)
	return result


## 验证精确分量数、数值范围和当前引擎精度，拒绝静默舍入。
## [br]
## @api private
func _read_math(kind: int, path: String) -> Variant:
	var _opened: bool = _expect("[", path)
	var count: int = COMPONENTS[kind]
	var values: Array = []
	for index: int in count:
		if index > 0:
			var _comma: bool = _expect(",", path)
		var number_text: String = _read_string(path, false)
		if integer_math(kind):
			var integer: int = read_integer(number_text, path)
			if integer < -2147483648 or integer > 2147483647:
				fail("number_out_of_range", path)
			values.append(integer)
		else:
			values.append(read_float(number_text, path))
		if not report["ok"]:
			return null
	var _closed: bool = _expect("]", path)
	if not report["ok"]:
		return null
	var result: Variant = restore_components(kind, values)
	if not same_components(values, result):
		fail("precision_loss", path)
	return result


## Packed 恢复只缓存已解码的原生元素，最终一次转换以避免逐项 COW 复制。
## [br]
## @api private
func _read_packed(
	kind: int,
	depth: int,
	path: String
) -> Variant:
	var _opened: bool = _expect("[", path)
	var values: Array = []
	_skip_space(path)
	while report["ok"] and _peek() != 93:
		if not values.is_empty() and not _expect(",", path):
			break
		var item_path: String = path + "[%d]" % values.size()
		if not visit(
			depth,
			item_path,
			true
		):
			break
		var item: Variant = _packed_item(kind, item_path)
		if not report["ok"]:
			break
		values.append(item)
		_skip_space(path)
	var _closed: bool = _expect("]", path)
	if not check(path):
		return null
	match kind:
		TYPE_PACKED_BYTE_ARRAY:
			return PackedByteArray(values)
		TYPE_PACKED_INT32_ARRAY:
			return PackedInt32Array(values)
		TYPE_PACKED_INT64_ARRAY:
			return PackedInt64Array(values)
		TYPE_PACKED_FLOAT32_ARRAY:
			return PackedFloat32Array(values)
		TYPE_PACKED_FLOAT64_ARRAY:
			return PackedFloat64Array(values)
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(values)
		TYPE_PACKED_VECTOR2_ARRAY:
			return PackedVector2Array(values)
		TYPE_PACKED_VECTOR3_ARRAY:
			return PackedVector3Array(values)
		TYPE_PACKED_VECTOR4_ARRAY:
			return PackedVector4Array(values)
		TYPE_PACKED_COLOR_ARRAY:
			return PackedColorArray(values)
	return null


## 每个 Packed 元素在进入构造器前完成范围与精度校验。
## [br]
## @api private
func _packed_item(kind: int, path: String) -> Variant:
	match kind:
		TYPE_PACKED_STRING_ARRAY:
			return _read_string(path)
		TYPE_PACKED_VECTOR2_ARRAY:
			return _read_math(TYPE_VECTOR2, path)
		TYPE_PACKED_VECTOR3_ARRAY:
			return _read_math(TYPE_VECTOR3, path)
		TYPE_PACKED_VECTOR4_ARRAY:
			return _read_math(TYPE_VECTOR4, path)
		TYPE_PACKED_COLOR_ARRAY:
			return _read_math(TYPE_COLOR, path)
	var number_text: String = _read_string(path, false)
	if kind in [
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
	]:
		var integer: int = read_integer(number_text, path)
		if (
			kind == TYPE_PACKED_BYTE_ARRAY
			and (
				integer < 0
				or integer > 255
			)
		):
			fail("number_out_of_range", path)
		elif (
			kind == TYPE_PACKED_INT32_ARRAY
			and (
				integer < -2147483648
				or integer > 2147483647
			)
		):
			fail("number_out_of_range", path)
		return integer
	var number: float = read_float(number_text, path)
	if kind == TYPE_PACKED_FLOAT32_ARRAY:
		var restored: float = PackedFloat32Array([number])[0]
		if (
			not (
				is_nan(number)
				and is_nan(restored)
			)
			and number != restored
		):
			fail("precision_loss", path)
	return number
