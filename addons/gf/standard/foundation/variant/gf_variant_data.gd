## GFVariantData: 通用 Variant 数据复制与默认值合并。
##
## 提供不依赖 GFArchitecture 的集合复制、Resource 可选复制、差异报告和默认值递归补齐。
## JSON 兼容编码由 GFVariantJsonCodec 负责。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFVariantData
extends RefCounted

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _MAX_SAFE_JSON_INTEGER: float = 9_007_199_254_740_991.0
const _DEFAULT_MAX_DIFF_DIAGNOSTICS: int = 1024
const _DEFAULT_MAX_DIFF_DEPTH: int = 64
const _DEFAULT_MAX_DIFF_NODES: int = 16_384
const _DEFAULT_MAX_DIFF_COLLECTION_ITEMS: int = 65_536


# --- 公共方法 ---

## 深拷贝 Dictionary 或 Array；其他 Variant 原样返回。
## [br]
## @api public
## [br]
## @param value: 待复制的值。
## [br]
## @schema value: 待复制的 Variant 值。
## [br]
## @param deep: 是否深拷贝集合或 Resource。
## [br]
## @param duplicate_resources: 是否复制 Resource；默认为 false 以保留引用语义。
## [br]
## @return 复制后的值。
## [br]
## @schema return: 复制后的 Variant 值。
static func duplicate_variant(value: Variant, deep: bool = true, duplicate_resources: bool = false) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(value, deep, duplicate_resources)


## 深拷贝集合值；语义同 duplicate_variant()，便于集合字段调用处表达意图。
## [br]
## @api public
## [br]
## @param value: 待复制的值。
## [br]
## @schema value: 待复制的 Variant 集合值。
## [br]
## @param deep: 是否深拷贝集合。
## [br]
## @return 复制后的值。
## [br]
## @schema return: 复制后的 Variant 集合值。
static func duplicate_collection(value: Variant, deep: bool = true) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_collection(value, deep)


## 将 Variant 归一为 Dictionary 副本。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望为 Dictionary 的 Variant 值。
## [br]
## @param default_value: value 不是 Dictionary 时使用的默认值。
## [br]
## @schema default_value: value 不是 Dictionary 时复制的默认 Dictionary。
## [br]
## @param deep: 是否深拷贝集合。
## [br]
## @return Dictionary 副本。
## [br]
## @schema return: 复制后的 Dictionary 结果。
static func to_dictionary(value: Variant, default_value: Dictionary = {}, deep: bool = true) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.to_dictionary(value, default_value, deep)


## 将 Variant 收窄为 Dictionary 引用；value 不是 Dictionary 时返回 default_value 引用。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望为 Dictionary 的 Variant 值。
## [br]
## @param default_value: value 不是 Dictionary 时使用的默认值；不是 Dictionary 时忽略。
## [br]
## @schema default_value: 为 Dictionary 时按引用返回的 Variant 兜底值。
## [br]
## @return Dictionary 引用。
## [br]
## @schema return: 收窄后的 Dictionary 结果。
static func as_dictionary(value: Variant, default_value: Variant = null) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(value, default_value)


## 将 Variant 归一为 Array 副本。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望为 Array 的 Variant 值。
## [br]
## @param default_value: value 不是 Array 时使用的默认值。
## [br]
## @schema default_value: value 不是 Array 时复制的默认 Array。
## [br]
## @param deep: 是否深拷贝集合。
## [br]
## @return Array 副本。
## [br]
## @schema return: 复制后的 Array 结果。
static func to_array(value: Variant, default_value: Array = [], deep: bool = true) -> Array:
	return _GF_VARIANT_ACCESS_SCRIPT.to_array(value, default_value, deep)


## 将 Variant 收窄为 Array 引用；value 不是 Array 时返回 default_value 引用。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望为 Array 的 Variant 值。
## [br]
## @param default_value: value 不是 Array 时使用的默认值；不是 Array 时忽略。
## [br]
## @schema default_value: 为 Array 时按引用返回的 Variant 兜底值。
## [br]
## @return Array 引用。
## [br]
## @schema return: 收窄后的 Array 结果。
static func as_array(value: Variant, default_value: Variant = null) -> Array:
	return _GF_VARIANT_ACCESS_SCRIPT.as_array(value, default_value)


## 将 Variant 安全归一为 bool。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 bool 的 Variant 值。
## [br]
## @param default_value: 无法安全归一时返回的默认值。
## [br]
## @return bool 值。
static func to_bool(value: Variant, default_value: bool = false) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(value, default_value)


## 将 Variant 安全归一为 int。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 int 的 Variant 值。
## [br]
## @param default_value: 无法安全归一时返回的默认值。
## [br]
## @return int 值。
static func to_int(value: Variant, default_value: int = 0) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.to_int(value, default_value)


## 检查 Variant 是否为可无损解释为整数的数值。
##
## 接受 int，以及 JSON 解析产生的有限、无小数且位于安全整数范围内的 float。
## 不接受 bool、字符串、NaN、Infinity 或带小数的 float。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param value: 待检查的值。
## [br]
## @schema value: Variant expected to be an int or an exact JSON integer number.
## [br]
## @return 可无损解释为整数时返回 true。
static func is_exact_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return (
		is_finite(float_value)
		and absf(float_value) <= _MAX_SAFE_JSON_INTEGER
		and float_value == floorf(float_value)
	)


## 将精确整数 Number 转为 int。
##
## 与宽松 to_int() 不同，该方法不会接受 bool 或文本，也不会截断小数。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param value: 待转换的精确整数 Number。
## [br]
## @schema value: Variant accepted by is_exact_integer().
## [br]
## @param default_value: 输入不满足精确整数约束时返回的值。
## [br]
## @return 精确整数或 default_value。
static func to_exact_int(value: Variant, default_value: int = 0) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		if is_exact_integer(float_value):
			return int(float_value)
	return default_value


## 将 Variant 安全归一为 float。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 float 的 Variant 值。
## [br]
## @param default_value: 无法安全归一时返回的默认值。
## [br]
## @return float 值。
static func to_float(value: Variant, default_value: float = 0.0) -> float:
	return _GF_VARIANT_ACCESS_SCRIPT.to_float(value, default_value)


## 将 Variant 归一为 String。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示文本的 Variant 值。
## [br]
## @param default_value: value 为 null 时返回的默认值。
## [br]
## @return String 值。
static func to_text(value: Variant, default_value: String = "") -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(value, default_value)


## 将 Variant 归一为 StringName。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 StringName 的 Variant 值。
## [br]
## @param default_value: value 为 null 时返回的默认值。
## [br]
## @return StringName 值。
static func to_string_name(value: Variant, default_value: StringName = &"") -> StringName:
	return _GF_VARIANT_ACCESS_SCRIPT.to_string_name(value, default_value)


## 将 Variant 归一为 Vector2。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 Vector2 的 Variant 值。
## [br]
## @param default_value: 无法安全归一时返回的默认值。
## [br]
## @return Vector2 值。
static func to_vector2(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	return _GF_VARIANT_ACCESS_SCRIPT.to_vector2(value, default_value)


## 将 Variant 归一为 Vector3。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 Vector3 的 Variant 值。
## [br]
## @param default_value: 无法安全归一时返回的默认值。
## [br]
## @return Vector3 值。
static func to_vector3(value: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
	return _GF_VARIANT_ACCESS_SCRIPT.to_vector3(value, default_value)


## 将 Variant 归一为 String 数组副本。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 String 值集合的 Variant。
## [br]
## @param default_value: 无法安全归一时返回的默认数组。
## [br]
## @schema default_value: value 无法收窄时复制的默认 Array[String]。
## [br]
## @return String 数组副本。
## [br]
## @schema return: 收窄后的 Array[String] 结果。
static func to_string_array(value: Variant, default_value: Array[String] = []) -> Array[String]:
	return _GF_VARIANT_ACCESS_SCRIPT.to_string_array(value, default_value)


## 将 Variant 归一为 StringName 数组副本。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 StringName 值集合的 Variant。
## [br]
## @param default_value: 无法安全归一时返回的默认数组。
## [br]
## @schema default_value: value 无法收窄时复制的默认 Array[StringName]。
## [br]
## @return StringName 数组副本。
## [br]
## @schema return: 收窄后的 Array[StringName] 结果。
static func to_string_name_array(value: Variant, default_value: Array[StringName] = []) -> Array[StringName]:
	return _GF_VARIANT_ACCESS_SCRIPT.to_string_name_array(value, default_value)


## 将 Variant 归一为 int 数组副本。
## [br]
## @api public
## [br]
## @param value: 待读取的值。
## [br]
## @schema value: 期望可表示 int 值集合的 Variant。
## [br]
## @param default_value: 无法安全归一时返回的默认数组。
## [br]
## @schema default_value: value 无法收窄时复制的默认 Array[int]。
## [br]
## @return int 数组副本。
## [br]
## @schema return: 收窄后的 Array[int] 结果。
static func to_int_array(value: Variant, default_value: Array[int] = []) -> Array[int]:
	return _GF_VARIANT_ACCESS_SCRIPT.to_int_array(value, default_value)


## 复制元数据字典。
## [br]
## @api public
## [br]
## @param metadata: 待复制的元数据。
## [br]
## @schema metadata: 调用方元数据 Dictionary。
## [br]
## @return 元数据副本。
## [br]
## @schema return: 复制后的元数据 Dictionary。
static func duplicate_metadata(metadata: Dictionary) -> Dictionary:
	return metadata.duplicate(true)


## 安全比较两个 Variant 值是否等价。
## [br]
## int/int 始终精确比较；int/float 仅在 float 有限、为整数且双向转换安全时等价。
## 需要容忍两个 float 之间的误差时可传入 numeric_epsilon。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param left: 左值。
## [br]
## @schema left: Variant comparison value.
## [br]
## @param right: 右值。
## [br]
## @schema right: Variant comparison value.
## [br]
## @param options: 比较选项。支持 numeric_epsilon 和 match_string_names。
## [br]
## @schema options: Dictionary，可选字段：numeric_epsilon 为 float/float 误差，默认 0；match_string_names 为 true 时 String 与 StringName 按文本比较。
## [br]
## @return 两个值按 GF 通用 Variant 语义等价时返回 true。
static func values_equal(left: Variant, right: Variant, options: Dictionary = {}) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.values_equal(left, right, options)


## 将 source 合并到 target。
## `String` 与 `StringName` 等价键会复用 target 中已有字段，避免重复键。
## 合并前会统一预检 source 图；超过默认深度、节点或集合元素预算时会报告错误并保持 target 原样。
## [br]
## @api public
## [br]
## @since 3.22.0
## [br]
## @param target: 会被原地修改的目标字典。
## [br]
## @schema target: 会被原地修改的目标 Dictionary。
## [br]
## @param source: 来源字典。
## [br]
## @schema source: 会复制到目标中的来源 Dictionary 值。
## [br]
## @param overwrite: 为 true 时覆盖已有字段。
## [br]
## @param recursive: 为 true 时递归合并嵌套 Dictionary。
## [br]
## @return 已合并的 target 字典；source 超出预算时返回未修改的 target。
## [br]
## @schema return: 合并后的目标 Dictionary，或预算拒绝时保持原样的目标 Dictionary。
static func merge_dictionary(
	target: Dictionary,
	source: Dictionary,
	overwrite: bool = true,
	recursive: bool = true
) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(target, source, overwrite, recursive)


## 将 source 元数据合并到 target 元数据。
## [br]
## @api public
## [br]
## @param target: 会被原地修改的目标元数据。
## [br]
## @schema target: 会被原地修改的元数据 Dictionary。
## [br]
## @param source: 来源元数据。
## [br]
## @schema source: 会复制到目标中的元数据 Dictionary。
## [br]
## @param overwrite: 为 true 时覆盖已有字段。
## [br]
## @param recursive: 为 true 时递归合并嵌套 Dictionary。
## [br]
## @return 已合并的 target 元数据。
## [br]
## @schema return: 合并后的元数据 Dictionary。
static func merge_metadata(
	target: Dictionary,
	source: Dictionary,
	overwrite: bool = true,
	recursive: bool = true
) -> Dictionary:
	return merge_dictionary(target, source, overwrite, recursive)


## 将 defaults 中缺失的字段递归合并到 base。
## [br]
## @api public
## [br]
## @param base: 会被原地补齐的目标字典。
## [br]
## @schema base: 会被原地修改的目标 Dictionary。
## [br]
## @param defaults: 默认值字典。
## [br]
## @schema defaults: 会合并到 base 中的默认 Dictionary 值。
## [br]
## @return 已补齐的 base 字典。
## [br]
## @schema return: 合并后的 base Dictionary。
static func deep_merge_defaults(base: Dictionary, defaults: Dictionary) -> Dictionary:
	return merge_dictionary(base, defaults, false, true)


## 对比两个 Variant 并返回结构化差异报告。
## [br]
## 该方法只比较纯 Variant 数据形状，不读取文件、不实例化脚本，也不解释业务字段。
## Array/Dictionary 按展开后的数据内容比较，不比较共享引用拓扑；活动引用 pair 重入只记录为 traversal diagnostic。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param before: 变更前的 Variant 值。
## [br]
## @schema before: 待比较的 Variant 值。
## [br]
## @param after: 变更后的 Variant 值。
## [br]
## @schema after: 待比较的 Variant 值。
## [br]
## @param options: 可选项。支持 max_changes、max_diagnostics、copy_values、max_depth、max_nodes 和 max_collection_items；所有资源预算 <=0 表示不限制。
## [br]
## @schema options: Dictionary，可选字段：max_changes 为最多记录差异数，默认 1024；max_diagnostics 为最多记录遍历诊断数，默认 1024；max_depth、max_nodes 和 max_collection_items 分别限制递归深度、访问节点数和集合元素工作量；所有预算 <=0 表示不限；copy_values 默认为 true。
## [br]
## @return 差异报告。内容差异与遍历诊断分别存放在 changes 和 diagnostics。
## [br]
## @schema return: Dictionary；changes 每项包含 kind、path、path_segments、old_value、new_value、old_type、new_type，kind 仅为 added、removed、changed 或 type_changed；diagnostics 每项包含 kind、path、path_segments，循环重入 kind 为 cycle_detected，资源预算耗尽 kind 为 traversal_budget_exceeded 并包含 reason；complete/traversal_truncated 独立描述遍历完整性，changed 不受 diagnostics 或不完整状态影响。
static func diff_variant(before: Variant, after: Variant, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _make_diff_state(options)
	_diff_variant_recursive(before, after, [], 0, state)
	var changes: Array = state["changes"]
	var diagnostics: Array = state["diagnostics"]
	var truncated: bool = state["truncated"]
	var diagnostics_truncated: bool = state["diagnostics_truncated"]
	var traversal_truncated: bool = state["traversal_truncated"]
	var max_changes: int = state["max_changes"]
	var max_diagnostics: int = state["max_diagnostics"]
	return {
		"changed": not changes.is_empty() or truncated,
		"complete": not traversal_truncated,
		"change_count": changes.size(),
		"truncated": truncated,
		"max_changes": max_changes,
		"changes": changes,
		"diagnostic_count": diagnostics.size(),
		"diagnostics_truncated": diagnostics_truncated,
		"max_diagnostics": max_diagnostics,
		"diagnostics": diagnostics,
		"traversal_truncated": traversal_truncated,
		"traversal_reason": state["traversal_reason"],
		"visited_node_count": state["visited_node_count"],
		"visited_collection_item_count": state["visited_collection_item_count"],
		"max_depth": state["max_depth"],
		"max_nodes": state["max_nodes"],
		"max_collection_items": state["max_collection_items"],
	}


## 读取 options 字典中的原始值，支持 String 与 StringName 键互查。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @schema default_value: Variant 默认值。
## [br]
## @return 读取到的值或默认值。
## [br]
## @schema return: Variant 选项值或默认值。
static func get_option_value(options: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, key, default_value)


## 读取 bool 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return bool 值。
static func get_option_bool(options: Dictionary, key: Variant, default_value: bool = false) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, key, default_value)


## 读取 int 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return int 值。
static func get_option_int(options: Dictionary, key: Variant, default_value: int = 0) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, key, default_value)


## 读取 float 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return float 值。
static func get_option_float(options: Dictionary, key: Variant, default_value: float = 0.0) -> float:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_float(options, key, default_value)


## 读取 String 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return String 值。
static func get_option_string(options: Dictionary, key: Variant, default_value: String = "") -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, key, default_value)


## 读取 StringName 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return StringName 值。
static func get_option_string_name(options: Dictionary, key: Variant, default_value: StringName = &"") -> StringName:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, key, default_value)


## 读取 Vector2 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return Vector2 值。
static func get_option_vector2(options: Dictionary, key: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_vector2(options, key, default_value)


## 读取 Vector3 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return Vector3 值。
static func get_option_vector3(options: Dictionary, key: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_vector3(options, key, default_value)


## 读取 Dictionary 选项副本。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @schema default_value: 选项不是 Dictionary 时复制的默认 Dictionary。
## [br]
## @return Dictionary 副本。
## [br]
## @schema return: Dictionary 选项值。
static func get_option_dictionary(options: Dictionary, key: Variant, default_value: Dictionary = {}) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, key, default_value)


## 读取 Array 选项副本。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @schema default_value: 选项不是 Array 时复制的默认 Array。
## [br]
## @return Array 副本。
## [br]
## @schema return: Array 选项值。
static func get_option_array(options: Dictionary, key: Variant, default_value: Array = []) -> Array:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_array(options, key, default_value)


## 读取 String 数组选项副本。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认数组。
## [br]
## @schema default_value: 选项无法收窄时复制的默认 Array[String]。
## [br]
## @return String 数组副本。
## [br]
## @schema return: Array[String] 选项值。
static func get_option_string_array(
	options: Dictionary,
	key: Variant,
	default_value: Array[String] = []
) -> Array[String]:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, key, default_value)


## 读取 StringName 数组选项副本。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认数组。
## [br]
## @schema default_value: 选项无法收窄时复制的默认 Array[StringName]。
## [br]
## @return StringName 数组副本。
## [br]
## @schema return: Array[StringName] 选项值。
static func get_option_string_name_array(
	options: Dictionary,
	key: Variant,
	default_value: Array[StringName] = []
) -> Array[StringName]:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name_array(options, key, default_value)


## 读取 int 数组选项副本。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认数组。
## [br]
## @schema default_value: 选项无法收窄时复制的默认 Array[int]。
## [br]
## @return int 数组副本。
## [br]
## @schema return: Array[int] 选项值。
static func get_option_int_array(
	options: Dictionary,
	key: Variant,
	default_value: Array[int] = []
) -> Array[int]:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int_array(options, key, default_value)


## 读取 PackedStringArray 选项。
## [br]
## @api public
## [br]
## @param options: 可选项字典。
## [br]
## @schema options: 选项载荷 Dictionary。
## [br]
## @param key: 字段名，可传 String 或 StringName。
## [br]
## @schema key: Variant 选项键。
## [br]
## @param default_value: 缺少字段时返回的默认值。
## [br]
## @return PackedStringArray 值。
static func get_option_packed_string_array(
	options: Dictionary,
	key: Variant,
	default_value: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, key, default_value)


# --- 私有/辅助方法 ---

static func _make_diff_state(options: Dictionary) -> Dictionary:
	var max_changes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_changes", 1024)
	var max_diagnostics: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		"max_diagnostics",
		_DEFAULT_MAX_DIFF_DIAGNOSTICS
	)
	var copy_values: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "copy_values", true)
	return {
		"changes": [],
		"truncated": false,
		"max_changes": max_changes,
		"diagnostics": [],
		"diagnostics_truncated": false,
		"max_diagnostics": max_diagnostics,
		"copy_values": copy_values,
		"visited_pairs": [],
		"traversal_truncated": false,
		"traversal_reason": "",
		"visited_node_count": 0,
		"visited_collection_item_count": 0,
		"max_depth": maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				options,
				"max_depth",
				_DEFAULT_MAX_DIFF_DEPTH
			),
			0
		),
		"max_nodes": maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				options,
				"max_nodes",
				_DEFAULT_MAX_DIFF_NODES
			),
			0
		),
		"max_collection_items": maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				options,
				"max_collection_items",
				_DEFAULT_MAX_DIFF_COLLECTION_ITEMS
			),
			0
		),
	}


static func _diff_variant_recursive(
	before: Variant,
	after: Variant,
	path_segments: Array,
	depth: int,
	state: Dictionary
) -> void:
	if _is_diff_truncated(state) or _is_diff_traversal_truncated(state):
		return
	if not _consume_diff_node(depth, path_segments, state):
		return
	if _diff_values_are_identical(before, after):
		return

	var before_type: int = typeof(before)
	var after_type: int = typeof(after)
	if before_type != after_type:
		_append_diff_change("type_changed", path_segments, before, after, state)
		return

	if before is Dictionary and after is Dictionary:
		if _is_diff_pair_active(before, after, state):
			_append_diff_diagnostic("cycle_detected", path_segments, state)
			return
		_push_diff_pair(before, after, state)
		var before_dictionary: Dictionary = before
		var after_dictionary: Dictionary = after
		if _consume_diff_collection_items(
			before_dictionary.size() + after_dictionary.size(),
			path_segments,
			state
		):
			_diff_dictionary(before_dictionary, after_dictionary, path_segments, depth, state)
		_pop_diff_pair(state)
		return

	if before is Array and after is Array:
		if _is_diff_pair_active(before, after, state):
			_append_diff_diagnostic("cycle_detected", path_segments, state)
			return
		_push_diff_pair(before, after, state)
		var before_array: Array = before
		var after_array: Array = after
		if _consume_diff_collection_items(
			before_array.size() + after_array.size(),
			path_segments,
			state
		):
			_diff_array(before_array, after_array, path_segments, depth, state)
		_pop_diff_pair(state)
		return

	if not _variant_values_equal(before, after):
		_append_diff_change("changed", path_segments, before, after, state)


static func _diff_dictionary(
	before: Dictionary,
	after: Dictionary,
	path_segments: Array,
	depth: int,
	state: Dictionary
) -> void:
	var used_after_keys: Dictionary = {}
	var string_like_key_index: Dictionary = _make_string_like_key_index(after)

	for before_key: Variant in before.keys():
		if _is_diff_truncated(state) or _is_diff_traversal_truncated(state):
			return

		var match: Dictionary = _find_matching_dictionary_key(
			after,
			before_key,
			used_after_keys,
			string_like_key_index
		)
		path_segments.append(before_key)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(match, "found"):
			_append_diff_change("removed", path_segments, before[before_key], null, state)
			var _removed_missing_path_segment: Variant = path_segments.pop_back()
			continue

		var after_key: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(match, "key")
		used_after_keys[after_key] = true
		_diff_variant_recursive(
			before[before_key],
			after[after_key],
			path_segments,
			depth + 1,
			state
		)
		var _removed_matched_path_segment: Variant = path_segments.pop_back()

	for after_key: Variant in after.keys():
		if _is_diff_truncated(state) or _is_diff_traversal_truncated(state):
			return
		if used_after_keys.has(after_key):
			continue

		path_segments.append(after_key)
		_append_diff_change("added", path_segments, null, after[after_key], state)
		var _removed_added_path_segment: Variant = path_segments.pop_back()


static func _diff_array(
	before: Array,
	after: Array,
	path_segments: Array,
	depth: int,
	state: Dictionary
) -> void:
	var shared_size: int = mini(before.size(), after.size())
	for index: int in range(shared_size):
		if _is_diff_truncated(state) or _is_diff_traversal_truncated(state):
			return

		path_segments.append(index)
		_diff_variant_recursive(before[index], after[index], path_segments, depth + 1, state)
		var _removed_shared_path_segment: Variant = path_segments.pop_back()

	for index: int in range(shared_size, before.size()):
		if _is_diff_truncated(state) or _is_diff_traversal_truncated(state):
			return

		path_segments.append(index)
		_append_diff_change("removed", path_segments, before[index], null, state)
		var _removed_old_path_segment: Variant = path_segments.pop_back()

	for index: int in range(shared_size, after.size()):
		if _is_diff_truncated(state) or _is_diff_traversal_truncated(state):
			return

		path_segments.append(index)
		_append_diff_change("added", path_segments, null, after[index], state)
		var _removed_new_path_segment: Variant = path_segments.pop_back()


static func _find_matching_dictionary_key(
	dictionary: Dictionary,
	key: Variant,
	used_keys: Dictionary,
	string_like_key_index: Dictionary
) -> Dictionary:
	if dictionary.has(key) and not used_keys.has(key):
		return {
			"found": true,
			"key": key,
		}

	if not _is_string_like_key(key):
		return { "found": false }

	var key_text: String = to_text(key)
	var candidates: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		string_like_key_index,
		key_text
	)
	for candidate_key: Variant in candidates:
		if used_keys.has(candidate_key) or not _is_string_like_key(candidate_key):
			continue
		if to_text(candidate_key) == key_text:
			return {
				"found": true,
				"key": candidate_key,
			}

	return { "found": false }


static func _make_string_like_key_index(dictionary: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in dictionary.keys():
		if not _is_string_like_key(key):
			continue
		var key_text: String = to_text(key)
		var candidates: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, key_text)
		candidates.append(key)
		result[key_text] = candidates
	return result


static func _append_diff_change(
	kind: String,
	path_segments: Array,
	old_value: Variant,
	new_value: Variant,
	state: Dictionary
) -> void:
	var changes: Array = state["changes"]
	var max_changes: int = state["max_changes"]
	if max_changes > 0 and changes.size() >= max_changes:
		state["truncated"] = true
		return

	changes.append({
		"kind": kind,
		"path": _format_diff_path(path_segments),
		"path_segments": duplicate_variant(path_segments, true, false),
		"old_value": _copy_diff_value(old_value, state),
		"new_value": _copy_diff_value(new_value, state),
		"old_type": type_string(typeof(old_value)),
		"new_type": type_string(typeof(new_value)),
	})


static func _append_diff_diagnostic(
	kind: String,
	path_segments: Array,
	state: Dictionary,
	additional_fields: Dictionary = {}
) -> void:
	var diagnostics: Array = state["diagnostics"]
	var max_diagnostics: int = state["max_diagnostics"]
	if max_diagnostics > 0 and diagnostics.size() >= max_diagnostics:
		state["diagnostics_truncated"] = true
		return

	var diagnostic: Dictionary = {
		"kind": kind,
		"path": _format_diff_path(path_segments),
		"path_segments": duplicate_variant(path_segments, true, false),
	}
	for field_key: Variant in additional_fields.keys():
		diagnostic[field_key] = duplicate_variant(additional_fields[field_key], true, false)
	diagnostics.append(diagnostic)


static func _copy_diff_value(value: Variant, state: Dictionary) -> Variant:
	var copy_values: bool = state["copy_values"]
	if not copy_values:
		return value
	return duplicate_variant(value, true, false)


static func _variant_values_equal(left: Variant, right: Variant) -> bool:
	return values_equal(left, right)


static func _diff_values_are_identical(before: Variant, after: Variant) -> bool:
	if is_same(before, after):
		return true
	if before is float and after is float:
		var before_float: float = before
		var after_float: float = after
		return is_nan(before_float) and is_nan(after_float)
	return false


static func _is_diff_truncated(state: Dictionary) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(state, "truncated")


static func _is_diff_traversal_truncated(state: Dictionary) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(state, "traversal_truncated")


static func _consume_diff_node(depth: int, path_segments: Array, state: Dictionary) -> bool:
	var max_depth: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(state, "max_depth")
	if max_depth > 0 and depth > max_depth:
		_mark_diff_traversal_truncated("max_depth", path_segments, state)
		return false
	var visited_node_count: int = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(state, "visited_node_count")
		+ 1
	)
	var max_nodes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(state, "max_nodes")
	if max_nodes > 0 and visited_node_count > max_nodes:
		_mark_diff_traversal_truncated("max_nodes", path_segments, state)
		return false
	state["visited_node_count"] = visited_node_count
	return true


static func _consume_diff_collection_items(
	item_count: int,
	path_segments: Array,
	state: Dictionary
) -> bool:
	var visited_item_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		state,
		"visited_collection_item_count"
	)
	var bounded_item_count: int = maxi(item_count, 0)
	var max_collection_items: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		state,
		"max_collection_items"
	)
	if (
		max_collection_items > 0
		and bounded_item_count > max_collection_items - mini(visited_item_count, max_collection_items)
	):
		_mark_diff_traversal_truncated("max_collection_items", path_segments, state)
		return false
	state["visited_collection_item_count"] = visited_item_count + bounded_item_count
	return true


static func _mark_diff_traversal_truncated(
	reason: String,
	path_segments: Array,
	state: Dictionary
) -> void:
	if _is_diff_traversal_truncated(state):
		return
	state["traversal_truncated"] = true
	state["traversal_reason"] = reason
	_append_diff_diagnostic(
		"traversal_budget_exceeded",
		path_segments,
		state,
		{ "reason": reason }
	)


static func _is_diff_pair_active(before: Variant, after: Variant, state: Dictionary) -> bool:
	var visited_pairs: Array = _get_diff_pair_stack(state)
	for pair_value: Variant in visited_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair: Dictionary = pair_value
		if (
			is_same(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(pair, "before"), before)
			and is_same(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(pair, "after"), after)
		):
			return true
	return false


static func _push_diff_pair(before: Variant, after: Variant, state: Dictionary) -> void:
	var visited_pairs: Array = _get_diff_pair_stack(state)
	visited_pairs.append({
		"before": before,
		"after": after,
	})
	state["visited_pairs"] = visited_pairs


static func _pop_diff_pair(state: Dictionary) -> void:
	var visited_pairs: Array = _get_diff_pair_stack(state)
	if not visited_pairs.is_empty():
		visited_pairs.remove_at(visited_pairs.size() - 1)
	state["visited_pairs"] = visited_pairs


static func _get_diff_pair_stack(state: Dictionary) -> Array:
	var value: Variant = state.get("visited_pairs", [])
	if value is Array:
		var pairs: Array = value
		return pairs
	var empty_pairs: Array = []
	state["visited_pairs"] = empty_pairs
	return empty_pairs


static func _is_string_like_key(key: Variant) -> bool:
	return key is String or key is StringName


static func _format_diff_path(path_segments: Array) -> String:
	var path_text: String = ""
	for segment: Variant in path_segments:
		if segment is int:
			var segment_index: int = segment
			path_text += "[%d]" % segment_index
			continue

		var key_text: String = to_text(segment)
		if _is_simple_path_key(key_text):
			if path_text.is_empty():
				path_text = key_text
			else:
				path_text += "." + key_text
			continue

		path_text += "[\"%s\"]" % _escape_diff_path_key(key_text)

	return path_text


static func _is_simple_path_key(text: String) -> bool:
	if text.is_empty():
		return false

	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		if index == 0:
			if not _is_ascii_letter_or_underscore(code):
				return false
			continue
		if not _is_ascii_letter_or_underscore(code) and not _is_ascii_digit(code):
			return false

	return true


static func _is_ascii_letter_or_underscore(code: int) -> bool:
	return code == 95 or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _is_ascii_digit(code: int) -> bool:
	return code >= 48 and code <= 57


static func _escape_diff_path_key(key_text: String) -> String:
	return key_text.replace("\\", "\\\\").replace("\"", "\\\"")
