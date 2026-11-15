# GF 确定性 JSON 的内部预算、类型表与数值转换。
# 本文件不注册公开类型；二进制 canonical 编码不依赖此协议。
extends RefCounted


# --- 常量 ---

## 文本协议身份，与普通 JSON codec 及二进制协议分别版本化。
## [br]
## @api framework_internal
const FORMAT_ID: String = "gf.variant-json-deterministic"

## 唯一可写版本。
## [br]
## @api framework_internal
const FORMAT_VERSION: int = 1

## 稳定标签不依赖 Variant 枚举的数值。
## [br]
## @api framework_internal
## [br]
## @schema TAGS: Dictionary mapping supported built-in Variant type IDs to fixed text tags.
const TAGS: Dictionary = {
	TYPE_NIL: "Nil",
	TYPE_BOOL: "Bool",
	TYPE_INT: "Int64",
	TYPE_FLOAT: "Float64",
	TYPE_STRING: "String",
	TYPE_STRING_NAME: "StringName",
	TYPE_NODE_PATH: "NodePath",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_RECT2: "Rect2",
	TYPE_RECT2I: "Rect2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_TRANSFORM2D: "Transform2D",
	TYPE_VECTOR4: "Vector4",
	TYPE_VECTOR4I: "Vector4i",
	TYPE_PLANE: "Plane",
	TYPE_QUATERNION: "Quaternion",
	TYPE_AABB: "AABB",
	TYPE_BASIS: "Basis",
	TYPE_TRANSFORM3D: "Transform3D",
	TYPE_PROJECTION: "Projection",
	TYPE_COLOR: "Color",
	TYPE_ARRAY: "Array",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray",
	TYPE_PACKED_VECTOR4_ARRAY: "PackedVector4Array",
}

## 数学值的固定分量数；分量采用 Godot 的列顺序。
## [br]
## @api framework_internal
## [br]
## @schema COMPONENTS: Dictionary mapping mathematical Variant types to fixed scalar counts.
const COMPONENTS: Dictionary = {
	TYPE_VECTOR2: 2,
	TYPE_VECTOR2I: 2,
	TYPE_VECTOR3: 3,
	TYPE_VECTOR3I: 3,
	TYPE_VECTOR4: 4,
	TYPE_VECTOR4I: 4,
	TYPE_RECT2: 4,
	TYPE_RECT2I: 4,
	TYPE_COLOR: 4,
	TYPE_PLANE: 4,
	TYPE_QUATERNION: 4,
	TYPE_AABB: 6,
	TYPE_TRANSFORM2D: 6,
	TYPE_BASIS: 9,
	TYPE_TRANSFORM3D: 12,
	TYPE_PROJECTION: 16,
}


# --- 公共变量 ---

## 一次操作的有限数值上限，只在入口验证后读取。
## [br]
## @api framework_internal
## [br]
## @schema limits: Positive integer limits for items, logical depth, string characters, UTF-8 input/output, logical sorting bytes and elapsed milliseconds.
var limits: Dictionary = {
	"max_items": 100000,
	"max_depth": 64,
	"max_key_depth": 64,
	"max_string_length": 1048576,
	"max_input_bytes": 16777216,
	"max_output_bytes": 16777216,
	"max_sort_bytes": 16777216,
	"max_elapsed_msec": 30000,
}

## 共享首次失败与计量；键规范化复用同一次操作，不重置截止时间。
## [br]
## @api framework_internal
## [br]
## @schema report: Dictionary with ok, protocol identity, counts, byte totals, current/peak sorting work, and structured first-failure diagnostics.
var report: Dictionary = {
	"ok": true,
	"format_id": FORMAT_ID,
	"format_version": FORMAT_VERSION,
	"counts_complete": false,
	"items": 0,
	"packed_items": 0,
	"input_bytes": 0,
	"output_bytes": 0,
	"maximum_depth": 0,
	"peak_sort_bytes": 0,
	"error_kind": "",
	"error_path": "",
	"limit_kind": "",
	"limit": 0,
	"observed": 0,
}

## 共享的执行身份，不发布为结果。
## [br]
## @api framework_internal
## [br]
## @schema control: Dictionary with started tick, optional token, decode mode and live logical sort bytes.
var control: Dictionary = {
	"started": Time.get_ticks_msec(),
	"token": null,
	"decode": false,
	"sort_bytes": 0,
}


# --- 框架内部方法 ---

## 在访问载荷前严格验证选项；两种方向只接受自身的字节预算。
## [br]
## @api framework_internal
## [br]
## @param options: 调用方选项。
## [br]
## @schema options: Closed Dictionary of positive limits and optional GFCancellationToken.
## [br]
## @param decoding: 是否解码。
func configure(options: Dictionary, decoding: bool) -> void:
	control["decode"] = decoding
	for raw_key: Variant in options:
		if not (raw_key is String or raw_key is StringName):
			fail("invalid_options", "$")
			return
		var option: String = str(raw_key)
		var setting: Variant = options[raw_key]
		if option == "cancel_token":
			if setting != null and not setting is GFCancellationToken:
				fail("invalid_options", "$")
				return
			control["token"] = setting
		elif (
			not limits.has(option)
			or option == ("max_output_bytes" if decoding else "max_input_bytes")
			or not setting is int
		):
			fail("invalid_options", "$")
			return
		else:
			var integer: int = setting
			if (
				integer <= 0
				or (
					option == "max_depth"
					and integer > 256
				)
			):
				fail("invalid_options", "$")
				return
			if option == "max_key_depth" and integer > 64:
				fail("invalid_options", "$")
				return
			limits[option] = integer
	var _ready: bool = check("$")


## 只记录首次失败，调用者可以安全地清理已有工作区。
## [br]
## @api framework_internal
## [br]
## @param kind: 稳定错误类型。
## [br]
## @param path: 有界的结构路径，不包含用户键文本。
func fail(kind: String, path: String) -> void:
	if report["ok"]:
		report["ok"] = false
		report["error_kind"] = kind
		report["error_path"] = path


## 记录预算失败，observed 可为避免溢出而饱和的下界。
## [br]
## @api framework_internal
## [br]
## @param option: 预算名称。
## [br]
## @param observed: 已知超限值或饱和下界。
## [br]
## @param path: 失败路径。
func exceed(
	option: String,
	observed: int,
	path: String
) -> void:
	if not report["ok"]:
		return
	fail("limit_exceeded", path)
	report["limit_kind"] = option
	report["limit"] = limits[option]
	report["observed"] = observed


## 在有界操作之间观察取消与单调时钟，不抢占单个原生调用。
## [br]
## @api framework_internal
## [br]
## @param path: 当前路径。
## [br]
## @return 可以继续时为 true。
func check(path: String) -> bool:
	if not report["ok"]:
		return false
	var token: Variant = control["token"]
	if token is GFCancellationToken:
		var cancellation: GFCancellationToken = token
		if cancellation.is_cancel_requested():
			fail("cancelled", path)
			return false
	var started: int = control["started"]
	var elapsed: int = Time.get_ticks_msec() - started
	var maximum: int = limits["max_elapsed_msec"]
	if elapsed > maximum:
		exceed(
			"max_elapsed_msec",
			elapsed,
			path
		)
	return report["ok"]


## 无溢出地累计工作量，分配相关缓冲前调用。
## [br]
## @api framework_internal
## [br]
## @param counter: 报告计数字段。
## [br]
## @param amount: 本次非负增量。
## [br]
## @param option: 对应上限。
## [br]
## @param path: 当前路径。
## [br]
## @return 增量已入账时为 true。
func consume(
	counter: String,
	amount: int,
	option: String,
	path: String
) -> bool:
	if not check(path):
		return false
	var current: int = report[counter]
	var maximum: int = limits[option]
	if amount > maximum - current:
		exceed(
			option,
			maximum + 1 if maximum < 9223372036854775807 else maximum,
			path
		)
		return false
	report[counter] = current + amount
	return true


## 每个原始值和 Packed 元素只计一次，数学分量不额外计节点。
## [br]
## @api framework_internal
## [br]
## @param depth: 原始值树深度。
## [br]
## @param path: 当前路径。
## [br]
## @param packed: 是否 Packed 元素。
## [br]
## @return 节点可处理时为 true。
func visit(
	depth: int,
	path: String,
	packed: bool = false
) -> bool:
	var maximum: int = limits["max_depth"]
	if depth > maximum:
		exceed(
			"max_depth",
			depth,
			path
		)
		return false
	if not consume(
		"items",
		1,
		"max_items",
		path
	):
		return false
	var previous: int = report["maximum_depth"]
	report["maximum_depth"] = maxi(previous, depth)
	if packed:
		var packed_items: int = report["packed_items"]
		report["packed_items"] = packed_items + 1
	return true


## 保留当前所有嵌套排序工作区；逻辑成本包含键文本构建及最终存储。
## [br]
## @api framework_internal
## [br]
## @param amount: 非负逻辑字节增量。
## [br]
## @param path: 当前路径。
## [br]
## @return 工作区已保留时为 true。
func reserve_sort(amount: int, path: String) -> bool:
	if not check(path):
		return false
	var current: int = control["sort_bytes"]
	var maximum: int = limits["max_sort_bytes"]
	if amount > maximum - current:
		exceed(
			"max_sort_bytes",
			maximum + 1 if maximum < 9223372036854775807 else maximum,
			path
		)
		return false
	control["sort_bytes"] = current + amount
	var previous: int = report["peak_sort_bytes"]
	report["peak_sort_bytes"] = maxi(
		previous,
		current + amount
	)
	return true


## 释放已不再保留的键或条目头，不改变峰值记录。
## [br]
## @api framework_internal
## [br]
## @param amount: 已入账且已释放的逻辑字节。
func release_sort(amount: int) -> void:
	var current: int = control["sort_bytes"]
	control["sort_bytes"] = current - amount


## 将协议标签映射为内置类型，不接受对象或脚本类型。
## [br]
## @api framework_internal
## [br]
## @param tag: 固定标签。
## [br]
## @return 对应类型；未知为 -1。
static func kind_for_tag(tag: String) -> int:
	for kind: int in TAGS:
		if TAGS[kind] == tag:
			return kind
	return -1


## 数学整数分量均为有符号 32 位；其它数学值使用浮点分量。
## [br]
## @api framework_internal
## [br]
## @param kind: 数学类型。
## [br]
## @return 整数数学类型时为 true。
static func integer_math(kind: int) -> bool:
	return kind in [
		TYPE_VECTOR2I,
		TYPE_VECTOR3I,
		TYPE_VECTOR4I,
		TYPE_RECT2I,
	]


## 有限非零值携带可读十进制与小端 binary64 位文本，避免十进制解析舍入。
## [br]
## @api framework_internal
## [br]
## @param number: 浮点数。
## [br]
## @return 规范数值文本；数值格式变化需升级文本协议。
static func float_text(number: float) -> String:
	if is_nan(number):
		return "NaN"
	if is_inf(number):
		return "+Inf" if number > 0.0 else "-Inf"
	if number == 0.0:
		return "0.0"
	var bytes: PackedByteArray = PackedByteArray()
	var _resized: int = bytes.resize(8)
	bytes.encode_double(0, number)
	return JSON.stringify(
		number,
		"",
		false,
		true
	) + "@" + bytes.hex_encode()


## 转换前验证完整 int64 十进制边界，不依赖可能饱和的转换器。
## [br]
## @api framework_internal
## [br]
## @param value: 数值文本。
## [br]
## @param path: 当前路径。
## [br]
## @return 合法整数；失败时为 0 并标记操作失败。
func read_integer(value: String, path: String) -> int:
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	var boundary: String = "9223372036854775808" if negative else "9223372036854775807"
	if (
		digits.is_empty()
		or digits.length() > boundary.length()
		or (
			digits.length() > 1
			and digits.begins_with("0")
		)
		or (
			negative
			and digits == "0"
		)
		or (
			digits.length() == boundary.length()
			and digits > boundary
		)
	):
		fail("invalid_number", path)
		return 0
	for character: int in digits.length():
		var code: int = digits.unicode_at(character)
		if code < 48 or code > 57:
			fail("invalid_number", path)
			return 0
	return value.to_int()


## 只接受完整可往返数值或协议显式特殊值。
## [br]
## @api framework_internal
## [br]
## @param value: 数值文本。
## [br]
## @param path: 当前路径。
## [br]
## @return 浮点值；失败时为 0 并标记操作失败。
func read_float(value: String, path: String) -> float:
	match value:
		"0.0":
			return 0.0
		"NaN":
			return NAN
		"+Inf":
			return INF
		"-Inf":
			return -INF
	var separator: int = value.find("@")
	if (
		value.length() > 64
		or separator <= 0
		or value.length() - separator != 17
	):
		fail("invalid_number", path)
		return 0.0
	var bits: String = value.substr(separator + 1)
	for index: int in bits.length():
		var code: int = bits.unicode_at(index)
		if not (
			(
				code >= 48
				and code <= 57
			)
			or (
				code >= 97
				and code <= 102
			)
		):
			fail("invalid_number", path)
			return 0.0
	var number: float = bits.hex_decode().decode_double(0)
	if not is_finite(number) or float_text(number) != value:
		fail("invalid_number", path)
		return 0.0
	return number


## 数学值按固定分量顺序拆开，返回最多 16 个标量。
## [br]
## @api framework_internal
## [br]
## @param value: 受支持数学值。
## [br]
## @schema value: Built-in vector, matrix, transform, rectangle, plane, quaternion, color or AABB.
## [br]
## @return 固定长度分量。
## [br]
## @schema return: Array containing only int or float components.
static func components(value: Variant) -> Array:
	match typeof(value):
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			return [vector2_value.x, vector2_value.y]
		TYPE_VECTOR2I:
			var vector2i_value: Vector2i = value
			return [vector2i_value.x, vector2i_value.y]
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			return [
				vector3_value.x,
				vector3_value.y,
				vector3_value.z,
			]
		TYPE_VECTOR3I:
			var vector3i_value: Vector3i = value
			return [
				vector3i_value.x,
				vector3i_value.y,
				vector3i_value.z,
			]
		TYPE_VECTOR4:
			var vector4_value: Vector4 = value
			return [
				vector4_value.x,
				vector4_value.y,
				vector4_value.z,
				vector4_value.w,
			]
		TYPE_VECTOR4I:
			var vector4i_value: Vector4i = value
			return [
				vector4i_value.x,
				vector4i_value.y,
				vector4i_value.z,
				vector4i_value.w,
			]
		TYPE_RECT2:
			var rect2_value: Rect2 = value
			return [
				rect2_value.position.x,
				rect2_value.position.y,
				rect2_value.size.x,
				rect2_value.size.y,
			]
		TYPE_RECT2I:
			var rect2i_value: Rect2i = value
			return [
				rect2i_value.position.x,
				rect2i_value.position.y,
				rect2i_value.size.x,
				rect2i_value.size.y,
			]
		TYPE_COLOR:
			var color_value: Color = value
			return [
				color_value.r,
				color_value.g,
				color_value.b,
				color_value.a,
			]
		TYPE_PLANE:
			var plane_value: Plane = value
			return [
				plane_value.normal.x,
				plane_value.normal.y,
				plane_value.normal.z,
				plane_value.d,
			]
		TYPE_QUATERNION:
			var quaternion_value: Quaternion = value
			return [
				quaternion_value.x,
				quaternion_value.y,
				quaternion_value.z,
				quaternion_value.w,
			]
		TYPE_AABB:
			var aabb_value: AABB = value
			return [
				aabb_value.position.x,
				aabb_value.position.y,
				aabb_value.position.z,
				aabb_value.size.x,
				aabb_value.size.y,
				aabb_value.size.z,
			]
		TYPE_TRANSFORM2D:
			var transform2d_value: Transform2D = value
			return [
				transform2d_value.x.x,
				transform2d_value.x.y,
				transform2d_value.y.x,
				transform2d_value.y.y,
				transform2d_value.origin.x,
				transform2d_value.origin.y,
			]
		TYPE_BASIS:
			var basis_value: Basis = value
			return [
				basis_value.x.x,
				basis_value.x.y,
				basis_value.x.z,
				basis_value.y.x,
				basis_value.y.y,
				basis_value.y.z,
				basis_value.z.x,
				basis_value.z.y,
				basis_value.z.z,
			]
		TYPE_TRANSFORM3D:
			var transform3d_value: Transform3D = value
			return [
				transform3d_value.basis.x.x,
				transform3d_value.basis.x.y,
				transform3d_value.basis.x.z,
				transform3d_value.basis.y.x,
				transform3d_value.basis.y.y,
				transform3d_value.basis.y.z,
				transform3d_value.basis.z.x,
				transform3d_value.basis.z.y,
				transform3d_value.basis.z.z,
				transform3d_value.origin.x,
				transform3d_value.origin.y,
				transform3d_value.origin.z,
			]
		TYPE_PROJECTION:
			var projection_value: Projection = value
			return [
				projection_value.x.x,
				projection_value.x.y,
				projection_value.x.z,
				projection_value.x.w,
				projection_value.y.x,
				projection_value.y.y,
				projection_value.y.z,
				projection_value.y.w,
				projection_value.z.x,
				projection_value.z.y,
				projection_value.z.z,
				projection_value.z.w,
				projection_value.w.x,
				projection_value.w.y,
				projection_value.w.z,
				projection_value.w.w,
			]
	return []


## 从已验证的分量恢复数学值；调用方随后检查精度。
## [br]
## @api framework_internal
## [br]
## @param kind: 数学类型。
## [br]
## @param values: 固定长度的已验证分量。
## [br]
## @schema values: Array of int or float values with the exact COMPONENTS count.
## [br]
## @return 对应内置数学值。
## [br]
## @schema return: Supported mathematical Variant value.
static func restore_components(kind: int, values: Array) -> Variant:
	var numbers: Array[float] = []
	var integers: Array[int] = []
	for component: Variant in values:
		if component is int:
			var integer: int = component
			integers.append(integer)
			numbers.append(float(integer))
		elif component is float:
			numbers.append(component)
	match kind:
		TYPE_VECTOR2:
			return Vector2(
				numbers[0],
				numbers[1]
			)
		TYPE_VECTOR2I:
			return Vector2i(
				integers[0],
				integers[1]
			)
		TYPE_VECTOR3:
			return Vector3(
				numbers[0],
				numbers[1],
				numbers[2]
			)
		TYPE_VECTOR3I:
			return Vector3i(
				integers[0],
				integers[1],
				integers[2]
			)
		TYPE_VECTOR4:
			return Vector4(
				numbers[0],
				numbers[1],
				numbers[2],
				numbers[3]
			)
		TYPE_VECTOR4I:
			return Vector4i(
				integers[0],
				integers[1],
				integers[2],
				integers[3]
			)
		TYPE_RECT2:
			return Rect2(
				numbers[0],
				numbers[1],
				numbers[2],
				numbers[3]
			)
		TYPE_RECT2I:
			return Rect2i(
				integers[0],
				integers[1],
				integers[2],
				integers[3]
			)
		TYPE_COLOR:
			return Color(
				numbers[0],
				numbers[1],
				numbers[2],
				numbers[3]
			)
		TYPE_PLANE:
			return Plane(
				numbers[0],
				numbers[1],
				numbers[2],
				numbers[3]
			)
		TYPE_QUATERNION:
			return Quaternion(
				numbers[0],
				numbers[1],
				numbers[2],
				numbers[3]
			)
		TYPE_AABB:
			return AABB(
				Vector3(
					numbers[0],
					numbers[1],
					numbers[2]
				),
				Vector3(
					numbers[3],
					numbers[4],
					numbers[5]
				)
			)
		TYPE_TRANSFORM2D:
			return Transform2D(
				Vector2(
					numbers[0],
					numbers[1]
				),
				Vector2(
					numbers[2],
					numbers[3]
				),
				Vector2(
					numbers[4],
					numbers[5]
				)
			)
		TYPE_BASIS:
			return Basis(
				Vector3(
					numbers[0],
					numbers[1],
					numbers[2]
				),
				Vector3(
					numbers[3],
					numbers[4],
					numbers[5]
				),
				Vector3(
					numbers[6],
					numbers[7],
					numbers[8]
				)
			)
		TYPE_TRANSFORM3D:
			return Transform3D(
				Basis(
					Vector3(
						numbers[0],
						numbers[1],
						numbers[2]
					),
					Vector3(
						numbers[3],
						numbers[4],
						numbers[5]
					),
					Vector3(
						numbers[6],
						numbers[7],
						numbers[8]
					)
				),
				Vector3(
					numbers[9],
					numbers[10],
					numbers[11]
				)
			)
		TYPE_PROJECTION:
			return Projection(
				Vector4(
					numbers[0],
					numbers[1],
					numbers[2],
					numbers[3]
				),
				Vector4(
					numbers[4],
					numbers[5],
					numbers[6],
					numbers[7]
				),
				Vector4(
					numbers[8],
					numbers[9],
					numbers[10],
					numbers[11]
				),
				Vector4(
					numbers[12],
					numbers[13],
					numbers[14],
					numbers[15]
				)
			)
	return null


## 检查数学/float32 恢复是否丢失精度；NaN 与零采用协议等价关系。
## [br]
## @api framework_internal
## [br]
## @param original: 已解码数值分量。
## [br]
## @schema original: Array of validated numeric components.
## [br]
## @param restored: 重建数学值。
## [br]
## @schema restored: Supported mathematical Variant.
## [br]
## @return 所有分量可恢复时为 true。
static func same_components(original: Array, restored: Variant) -> bool:
	var actual: Array = components(restored)
	if actual.size() != original.size():
		return false
	for index: int in actual.size():
		var left: Variant = original[index]
		var right: Variant = actual[index]
		if left is float and right is float:
			var left_number: float = left
			var right_number: float = right
			if is_nan(left_number) and is_nan(right_number):
				continue
		if left != right:
			return false
	return true
