# GFVariantAccess: 内核内部 Variant 收窄和选项读取辅助。
# [br]
# @api framework_internal
# [br]
# @layer kernel/core
extends RefCounted

const _MERGE_DICTIONARY_MAX_DEPTH: int = 64

# --- 公共方法 ---

## 复制集合 Variant，并可按需复制 Resource。
## [br]
## @api framework_internal
## [br]
## @param value: 待复制的集合或 Resource 值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param deep: 是否复制嵌套集合内容。
## [br]
## @schema deep: bool，控制是否深复制。
## [br]
## @param duplicate_resources: 是否复制 Resource 值。
## [br]
## @schema duplicate_resources: bool，控制是否复制 Resource。
## [br]
## @return 支持复制时返回副本，否则返回原值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func duplicate_variant(value: Variant, deep: bool = true, duplicate_resources: bool = false) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if not deep:
			return dictionary.duplicate(false)
		return _duplicate_variant_safe(dictionary, duplicate_resources, [])
	if value is Array:
		var array: Array = value
		if not deep:
			return array.duplicate(false)
		return _duplicate_variant_safe(array, duplicate_resources, [])
	if duplicate_resources and value is Resource:
		var resource: Resource = value
		return resource.duplicate(deep)
	return value


## 复制 Dictionary 与 Array 值。
## [br]
## @api framework_internal
## [br]
## @param value: 待复制的集合值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param deep: 是否复制嵌套集合内容。
## [br]
## @schema deep: bool，控制是否深复制。
## [br]
## @return 集合副本，非集合值返回原值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func duplicate_collection(value: Variant, deep: bool = true) -> Variant:
	return duplicate_variant(value, deep)


## 转换为可交给 JSON.stringify 的值。
## [br]
## @api framework_internal
## [br]
## @param value: 待转换值。
## [br]
## @schema value: 任意 Variant。
## [br]
## @param max_depth: 集合递归深度上限。
## [br]
## @schema max_depth: int，防止异常循环或过深结构阻塞编辑器。
## [br]
## @return JSON 兼容值；非有限 float 使用稳定文本表示。
## [br]
## @schema return: JSON 兼容 Variant。
static func to_json_compatible(value: Variant, max_depth: int = 32) -> Variant:
	return _to_json_compatible(value, maxi(max_depth, 0), 0)


## 将 Variant 收窄为 Dictionary 副本。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 不是 Dictionary 时使用的兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @param deep: 是否深复制返回的 Dictionary。
## [br]
## @schema deep: bool，控制是否深复制。
## [br]
## @return Dictionary 副本或兜底值副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_dictionary(value: Variant, default_value: Dictionary = {}, deep: bool = true) -> Dictionary:
	return as_dictionary(value, default_value).duplicate(deep)


## 将 Variant 收窄为 Dictionary 引用。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 不是 Dictionary 时使用的兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Dictionary 引用或兜底值 引用。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func as_dictionary(value: Variant, default_value: Variant = null) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	if default_value is Dictionary:
		var fallback_dictionary: Dictionary = default_value
		return fallback_dictionary
	return {}


## 将 Variant 收窄为 Array 副本。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 不是 Array 时使用的兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @param deep: 是否深复制返回的 Array。
## [br]
## @schema deep: bool，控制是否深复制。
## [br]
## @return Array 副本或兜底值副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_array(value: Variant, default_value: Array = [], deep: bool = true) -> Array:
	return as_array(value, default_value).duplicate(deep)


## 将 Variant 收窄为 Array 引用。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 不是 Array 时使用的兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Array 引用或兜底值 引用。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func as_array(value: Variant, default_value: Variant = null) -> Array:
	if value is Array:
		var array: Array = value
		return array
	if default_value is Array:
		var fallback_array: Array = default_value
		return fallback_array
	return []

# --- 公共方法（类型收窄） ---

## 将常见标量 Variant 收窄为 bool。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的 bool 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 bool 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_bool(value: Variant, default_value: bool = false) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	if value is int:
		var int_value: int = value
		return int_value != 0
	if value is float:
		var float_value: float = value
		return not is_zero_approx(float_value)
	if value is String or value is StringName:
		var text: String = to_text(value).strip_edges().to_lower()
		if text == "false" or text == "0" or text == "no" or text == "off":
			return false
		if text == "true" or text == "1" or text == "yes" or text == "on":
			return true
	return default_value


## 将常见标量 Variant 收窄为 int。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的 int 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 int 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_int(value: Variant, default_value: int = 0) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is bool:
		var bool_value: bool = value
		return 1 if bool_value else 0
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is String or value is StringName:
		var text: String = to_text(value).strip_edges()
		if text.is_valid_int():
			return text.to_int()
	return default_value


## 将常见标量 Variant 收窄为 float。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的 float 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 float 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_float(value: Variant, default_value: float = 0.0) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	if value is bool:
		var bool_value: bool = value
		return 1.0 if bool_value else 0.0
	if value is String or value is StringName:
		var text: String = to_text(value).strip_edges()
		if text.is_valid_float():
			return text.to_float()
	return default_value


## 将 Variant 收窄为文本。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 为 null 时使用的文本兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return String 表示或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_text(value: Variant, default_value: String = "") -> String:
	if value is String:
		var text_value: String = value
		return text_value
	if value is StringName:
		var name_value: StringName = value
		return String(name_value)
	if value is NodePath:
		var path_value: NodePath = value
		return String(path_value)
	if value == null:
		return default_value
	return str(value)


## 将 Variant 收窄为 StringName。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 为 null 时使用的 StringName 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return StringName 值或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_string_name(value: Variant, default_value: StringName = &"") -> StringName:
	if value is StringName:
		var name_value: StringName = value
		return name_value
	if value == null:
		return default_value
	return StringName(to_text(value))


## 将 Variant 收窄为 Vector2。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的 Vector2 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Vector2 值或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_vector2(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		var vector_2: Vector2 = value
		return vector_2
	if value is Vector2i:
		var vector_2i: Vector2i = value
		return Vector2(vector_2i.x, vector_2i.y)
	if value is Vector3:
		var vector_3: Vector3 = value
		return Vector2(vector_3.x, vector_3.y)
	if value is Vector3i:
		var vector_3i: Vector3i = value
		return Vector2(vector_3i.x, vector_3i.y)
	if value is Dictionary:
		var data: Dictionary = value
		if _has_any_key(data, ["x", "y"]):
			return Vector2(
				get_option_float(data, "x", default_value.x),
				get_option_float(data, "y", default_value.y)
			)
	if value is Array:
		var values: Array = value
		if values.size() >= 2:
			return Vector2(
				to_float(values[0], default_value.x),
				to_float(values[1], default_value.y)
			)
	return default_value


## 将 Variant 收窄为 Vector3。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的 Vector3 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Vector3 值或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_vector3(value: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		var vector_3: Vector3 = value
		return vector_3
	if value is Vector3i:
		var vector_3i: Vector3i = value
		return Vector3(vector_3i.x, vector_3i.y, vector_3i.z)
	if value is Vector2:
		var vector_2: Vector2 = value
		return Vector3(vector_2.x, vector_2.y, default_value.z)
	if value is Vector2i:
		var vector_2i: Vector2i = value
		return Vector3(vector_2i.x, vector_2i.y, default_value.z)
	if value is Dictionary:
		var data: Dictionary = value
		if _has_any_key(data, ["x", "y", "z"]):
			return Vector3(
				get_option_float(data, "x", default_value.x),
				get_option_float(data, "y", default_value.y),
				get_option_float(data, "z", default_value.z)
			)
	if value is Array:
		var values: Array = value
		if values.size() >= 3:
			return Vector3(
				to_float(values[0], default_value.x),
				to_float(values[1], default_value.y),
				to_float(values[2], default_value.z)
			)
		if values.size() >= 2:
			return Vector3(
				to_float(values[0], default_value.x),
				to_float(values[1], default_value.y),
				default_value.z
			)
	return default_value


## 将 Variant 收窄为 String 数组副本。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return String 数组副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_string_array(value: Variant, default_value: Array[String] = []) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item: String in value:
			result.append(item)
		return result
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			result.append(to_text(item))
		return result
	if value is String or value is StringName:
		var text: String = to_text(value)
		if not text.is_empty():
			result.append(text)
			return result
	return _copy_string_array(default_value)


## 将 Variant 收窄为 StringName 数组副本。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return StringName 数组副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_string_name_array(value: Variant, default_value: Array[StringName] = []) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is PackedStringArray:
		for item: String in value:
			result.append(StringName(item))
		return result
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			result.append(to_string_name(item))
		return result
	if value is String or value is StringName:
		var value_name: StringName = to_string_name(value)
		if value_name != &"":
			result.append(value_name)
			return result
	return _copy_string_name_array(default_value)


## 将 Variant 收窄为 int 数组副本。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: 内部 Variant 访问辅助值；可接受形态由当前函数契约定义。
## [br]
## @param default_value: value 无法收窄时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return int 数组副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func to_int_array(value: Variant, default_value: Array[int] = []) -> Array[int]:
	var result: Array[int] = []
	if value is PackedInt32Array:
		for item: int in value:
			result.append(item)
		return result
	if value is PackedInt64Array:
		for item: int in value:
			result.append(item)
		return result
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			result.append(to_int(item))
		return result
	if value is int or value is bool or value is float:
		result.append(to_int(value))
		return result
	if value is String or value is StringName:
		var text: String = to_text(value).strip_edges()
		if text.is_valid_int():
			result.append(text.to_int())
			return result
	return _copy_int_array(default_value)


## 将 source 字段合并到 target。
## `String` 与 `StringName` 等价键会复用 target 中已有字段，避免重复键。
## [br]
## @api framework_internal
## [br]
## @param target: 接收合并字段的 Dictionary。
## [br]
## @schema target: Dictionary 合并目标。
## [br]
## @param source: 提供合并字段的 Dictionary。
## [br]
## @schema source: Dictionary 合并来源。
## [br]
## @param overwrite: 是否覆盖 target 中已存在的字段。
## [br]
## @schema overwrite: bool，控制是否覆盖已有字段。
## [br]
## @param recursive: 是否递归合并嵌套 Dictionary。
## [br]
## @schema recursive: bool，控制是否递归合并。
## [br]
## @return 被原地修改后的 target Dictionary。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func merge_dictionary(
	target: Dictionary,
	source: Dictionary,
	overwrite: bool = true,
	recursive: bool = true
) -> Dictionary:
	return _merge_dictionary(target, source, overwrite, recursive, [], [], 0)


## 读取选项字段，并支持 String 与 StringName 等价键。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失时使用的兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 原始选项值或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_value(options: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	return _get_key_value(options, key, default_value)


## 读取并收窄 bool 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 bool 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 bool 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_bool(options: Dictionary, key: Variant, default_value: bool = false) -> bool:
	return to_bool(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 int 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 int 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 int 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_int(options: Dictionary, key: Variant, default_value: int = 0) -> int:
	return to_int(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 float 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 float 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 float 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_float(options: Dictionary, key: Variant, default_value: float = 0.0) -> float:
	return to_float(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 String 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 String 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 String 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_string(options: Dictionary, key: Variant, default_value: String = "") -> String:
	return to_text(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 StringName 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 StringName 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return 收窄后的 StringName 或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_string_name(options: Dictionary, key: Variant, default_value: StringName = &"") -> StringName:
	return to_string_name(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 Vector2 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 Vector2 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Vector2 选项值或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_vector2(options: Dictionary, key: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	return to_vector2(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 Vector3 选项。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 Vector3 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Vector3 选项值或兜底值。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_vector3(options: Dictionary, key: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
	return to_vector3(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 Dictionary 选项副本。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 Dictionary 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Dictionary 选项副本或兜底值副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_dictionary(options: Dictionary, key: Variant, default_value: Dictionary = {}) -> Dictionary:
	return to_dictionary(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 Array 选项副本。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return Array 选项副本或兜底值副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_array(options: Dictionary, key: Variant, default_value: Array = []) -> Array:
	return to_array(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 String 数组选项副本。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return String 数组副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_string_array(
	options: Dictionary,
	key: Variant,
	default_value: Array[String] = []
) -> Array[String]:
	return to_string_array(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 StringName 数组选项副本。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return StringName 数组副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_string_name_array(
	options: Dictionary,
	key: Variant,
	default_value: Array[StringName] = []
) -> Array[StringName]:
	return to_string_name_array(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 int 数组选项副本。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的数组兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return int 数组副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_int_array(
	options: Dictionary,
	key: Variant,
	default_value: Array[int] = []
) -> Array[int]:
	return to_int_array(_get_key_value(options, key, default_value), default_value)


## 读取并收窄 PackedStringArray 选项副本。
## [br]
## @api framework_internal
## [br]
## @param options: 待读取的选项 Dictionary。
## [br]
## @schema options: Dictionary 选项载荷。
## [br]
## @param key: 选项键，可为 String 或 StringName。
## [br]
## @schema key: String、StringName 或其他 Dictionary key。
## [br]
## @param default_value: 选项缺失或非法时使用的 PackedStringArray 兜底值。
## [br]
## @schema default_value: 内部 Variant 访问辅助兜底值；可接受形态由当前函数契约定义。
## [br]
## @return PackedStringArray 选项副本或兜底值副本。
## [br]
## @schema return: 内部 Variant 访问辅助结果；返回形态由当前函数契约定义。
static func get_option_packed_string_array(
	options: Dictionary,
	key: Variant,
	default_value: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	var value: Variant = _get_key_value(options, key, default_value)
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return packed_strings.duplicate()
	var result: PackedStringArray = PackedStringArray()
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			var _appended_item: bool = result.append(to_text(item))
	elif value is String or value is StringName:
		var text: String = to_text(value)
		if not text.is_empty():
			var _appended_text: bool = result.append(text)
	else:
		result = default_value.duplicate()
	return result

# --- 私有/辅助方法 ---

static func _merge_dictionary(
	target: Dictionary,
	source: Dictionary,
	overwrite: bool,
	recursive: bool,
	visited_targets: Array,
	visited_sources: Array,
	depth: int
) -> Dictionary:
	if recursive:
		if depth >= _MERGE_DICTIONARY_MAX_DEPTH:
			return target
		if _has_visited_dictionary_pair(visited_targets, visited_sources, target, source):
			return target
		visited_targets.append(target)
		visited_sources.append(source)
	for source_key: Variant in source.keys():
		var source_value: Variant = source[source_key]
		var target_has_key: bool = _has_equivalent_key(target, source_key)
		var target_key: Variant = _get_equivalent_key(target, source_key)
		if (
			recursive
			and target_has_key
			and get_option_value(target, source_key) is Dictionary
			and source_value is Dictionary
		):
			var target_dictionary: Dictionary = as_dictionary(target[target_key])
			var source_dictionary: Dictionary = as_dictionary(source_value)
			var _ignored_nested_merge: Dictionary = _merge_dictionary(
				target_dictionary,
				source_dictionary,
				overwrite,
				recursive,
				visited_targets,
				visited_sources,
				depth + 1
			)
			continue
		if overwrite or not target_has_key:
			target[target_key] = duplicate_variant(source_value)
	return target


static func _has_visited_dictionary_pair(
	visited_targets: Array,
	visited_sources: Array,
	target: Dictionary,
	source: Dictionary
) -> bool:
	for index: int in range(mini(visited_targets.size(), visited_sources.size())):
		if is_same(visited_targets[index], target) and is_same(visited_sources[index], source):
			return true
	return false


static func _duplicate_variant_safe(value: Variant, duplicate_resources: bool, visited: Array) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var existing_dictionary: Variant = _get_visited_duplicate(visited, dictionary)
		if existing_dictionary is Dictionary:
			return existing_dictionary
		var dictionary_copy: Dictionary = {}
		visited.append({
			"source": dictionary,
			"copy": dictionary_copy,
		})
		for key: Variant in dictionary.keys():
			var copied_key: Variant = _duplicate_variant_safe(key, duplicate_resources, visited)
			dictionary_copy[copied_key] = _duplicate_variant_safe(dictionary[key], duplicate_resources, visited)
		return dictionary_copy
	if value is Array:
		var array: Array = value
		var existing_array: Variant = _get_visited_duplicate(visited, array)
		if existing_array is Array:
			return existing_array
		var array_copy: Array = []
		visited.append({
			"source": array,
			"copy": array_copy,
		})
		for item: Variant in array:
			array_copy.append(_duplicate_variant_safe(item, duplicate_resources, visited))
		return array_copy
	if duplicate_resources and value is Resource:
		var resource: Resource = value
		return resource.duplicate(true)
	return value


static func _get_visited_duplicate(visited: Array, source: Variant) -> Variant:
	for record_value: Variant in visited:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if is_same(_get_key_value(record, "source"), source):
			return _get_key_value(record, "copy")
	return null


static func _to_json_compatible(value: Variant, max_depth: int, depth: int) -> Variant:
	if depth > max_depth:
		return "<max_depth>"

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			var float_value: float = value
			return _to_json_compatible_float(float_value)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			return {
				"x": _to_json_compatible_float(vector2_value.x),
				"y": _to_json_compatible_float(vector2_value.y),
			}
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			return {
				"x": _to_json_compatible_float(vector3_value.x),
				"y": _to_json_compatible_float(vector3_value.y),
				"z": _to_json_compatible_float(vector3_value.z),
			}
		TYPE_VECTOR4:
			var vector4_value: Vector4 = value
			return {
				"x": _to_json_compatible_float(vector4_value.x),
				"y": _to_json_compatible_float(vector4_value.y),
				"z": _to_json_compatible_float(vector4_value.z),
				"w": _to_json_compatible_float(vector4_value.w),
			}
		TYPE_COLOR:
			var color_value: Color = value
			return {
				"r": _to_json_compatible_float(color_value.r),
				"g": _to_json_compatible_float(color_value.g),
				"b": _to_json_compatible_float(color_value.b),
				"a": _to_json_compatible_float(color_value.a),
			}
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var result: Dictionary = {}
			for key: Variant in dictionary.keys():
				var key_text: String = str(_to_json_compatible(key, max_depth, depth + 1))
				result[key_text] = _to_json_compatible(dictionary[key], max_depth, depth + 1)
			return result
		TYPE_ARRAY:
			var array: Array = value
			var result: Array = []
			for item: Variant in array:
				result.append(_to_json_compatible(item, max_depth, depth + 1))
			return result
		TYPE_PACKED_BYTE_ARRAY:
			var packed_bytes: PackedByteArray = value
			return Array(packed_bytes)
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return Array(packed_int32)
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return Array(packed_int64)
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return Array(packed_strings)
		TYPE_PACKED_FLOAT32_ARRAY:
			var float32_values: Array = []
			var packed_float32: PackedFloat32Array = value
			for item: float in packed_float32:
				float32_values.append(_to_json_compatible_float(item))
			return float32_values
		TYPE_PACKED_FLOAT64_ARRAY:
			var float64_values: Array = []
			var packed_float64: PackedFloat64Array = value
			for item: float in packed_float64:
				float64_values.append(_to_json_compatible_float(item))
			return float64_values
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector2_values: Array = []
			var packed_vector2: PackedVector2Array = value
			for item: Vector2 in packed_vector2:
				vector2_values.append(_to_json_compatible(item, max_depth, depth + 1))
			return vector2_values
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector3_values: Array = []
			var packed_vector3: PackedVector3Array = value
			for item: Vector3 in packed_vector3:
				vector3_values.append(_to_json_compatible(item, max_depth, depth + 1))
			return vector3_values
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector4_values: Array = []
			var packed_vector4: PackedVector4Array = value
			for item: Vector4 in packed_vector4:
				vector4_values.append(_to_json_compatible(item, max_depth, depth + 1))
			return vector4_values
		TYPE_PACKED_COLOR_ARRAY:
			var color_values: Array = []
			var packed_colors: PackedColorArray = value
			for item: Color in packed_colors:
				color_values.append(_to_json_compatible(item, max_depth, depth + 1))
			return color_values
	return str(value)


static func _to_json_compatible_float(value: float) -> Variant:
	if is_nan(value):
		return "NaN"
	if is_inf(value):
		return "INF" if value > 0.0 else "-INF"
	return value


static func _get_key_value(data: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	if data.has(key):
		return data[key]
	if key is StringName:
		var key_name: StringName = key
		var text_key: String = String(key_name)
		if data.has(text_key):
			return data[text_key]
	elif key is String:
		var key_text: String = key
		var name_key: StringName = StringName(key_text)
		if data.has(name_key):
			return data[name_key]
	return default_value


static func _has_equivalent_key(data: Dictionary, key: Variant) -> bool:
	if data.has(key):
		return true
	if key is StringName:
		var key_name: StringName = key
		return data.has(String(key_name))
	if key is String:
		var key_text: String = key
		return data.has(StringName(key_text))
	return false


static func _get_equivalent_key(data: Dictionary, key: Variant) -> Variant:
	if data.has(key):
		return key
	if key is StringName:
		var key_name: StringName = key
		var text_key: String = String(key_name)
		if data.has(text_key):
			return text_key
	if key is String:
		var key_text: String = key
		var name_key: StringName = StringName(key_text)
		if data.has(name_key):
			return name_key
	return key


static func _has_any_key(data: Dictionary, keys: Array) -> bool:
	for key: Variant in keys:
		if _has_equivalent_key(data, key):
			return true
	return false


static func _copy_string_array(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		result.append(value)
	return result


static func _copy_string_name_array(values: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in values:
		result.append(value)
	return result


static func _copy_int_array(values: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in values:
		result.append(value)
	return result
