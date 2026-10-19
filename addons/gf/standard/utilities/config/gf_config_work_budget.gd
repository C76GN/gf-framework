## GFConfigWorkBudget: 单次配置操作及批次共享的有限工作预算。
##
## 句柄只累计、不重置；首次失败锁存。它约束受信任配置代码的协作工作量，
## 不隔离自定义代码，也不统计 Resource 属性或引擎内部全部内存。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFConfigWorkBudget
extends RefCounted


# --- 常量 ---

## 默认容量；工作单元按访问节点、调用方显式工作及每 1024 字符扫描块累计。
## [br]
## @api private
const _DEFAULT_LIMITS: Dictionary = {
	"max_input_bytes": 67_108_864,
	"max_depth": 64,
	"max_work_units": 1_000_000,
	"max_value_bytes": 268_435_456,
	"max_output_bytes": 67_108_864,
}


# --- 私有变量 ---

## 已规范化的有限容量，不向调用方暴露可变引用。
## [br]
## @api private
var _limits: Dictionary = {}

## 复用通用执行预算累计工作单元。
## [br]
## @api private
var _execution: GFExecutionBudget = null

## 已接受的累计字节数与观察到的最大深度。
## [br]
## @api private
var _usage: Dictionary = {
	"input_bytes": 0,
	"value_bytes": 0,
	"output_bytes": 0,
	"peak_depth": 0,
}

## 首次失败的稳定分类。
## [br]
## @api private
var _error_kind: String = ""

## 首次失败的开发诊断。
## [br]
## @api private
var _error: String = ""

## 首次失败的调用位置。
## [br]
## @api private
var _context: String = ""


# --- Godot 生命周期方法 ---

## 创建不可重置的操作预算；非法限额创建失败句柄。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param limits: 覆盖默认容量的字段。
## [br]
## @schema limits: Dictionary，仅接受 max_input_bytes、max_depth、max_work_units、max_value_bytes、max_output_bytes 的正整数；max_depth 最大为 256。
func _init(limits: Dictionary = {}) -> void:
	_limits = _DEFAULT_LIMITS.duplicate()
	if limits.size() > _DEFAULT_LIMITS.size():
		var _failed: bool = _fail(
			"config_work_invalid_limits",
			"Unknown configuration work limit.",
			"limits"
		)
		return
	for key: Variant in limits:
		if not _DEFAULT_LIMITS.has(key):
			var _failed: bool = _fail(
				"config_work_invalid_limits",
				"Unknown configuration work limit.",
				"limits"
			)
			return
		var limit_value: Variant = limits[key]
		if not (limit_value is int) or limit_value <= 0:
			var _failed: bool = _fail(
				"config_work_invalid_limits",
				"Configuration work limits must be positive integers.",
				str(key)
			)
			return
		if key == "max_depth" and limit_value > 256:
			var _failed: bool = _fail(
				"config_work_invalid_limits",
				"Configuration depth limit must not exceed 256.",
				"max_depth"
			)
			return
		_limits[key] = limit_value
	_execution = GFExecutionBudget.new({ "max_steps": _limits["max_work_units"] })


# --- 公共方法 ---

## 从入口选项取得共享句柄；不得同时声明限额与句柄。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 调用入口选项，其他业务选项不参与预算解析。
## [br]
## @schema options: Dictionary，work_limits 为构造函数限额字典，work_budget 为 GFConfigWorkBudget；两字段互斥，省略时创建默认有限句柄。
## [br]
## @return 新建或原有句柄；非法选项返回失败句柄，并锁存可识别的原句柄。
static func from_options(options: Dictionary = {}) -> GFConfigWorkBudget:
	if options.has("work_budget"):
		var supplied: Variant = options["work_budget"]
		var budget: GFConfigWorkBudget = null
		if supplied is GFConfigWorkBudget:
			budget = supplied
		else:
			budget = GFConfigWorkBudget.new()
		if not (supplied is GFConfigWorkBudget) or options.has("work_limits"):
			var _failed: bool = budget._fail(
				"config_work_invalid_options",
				"work_budget must be a budget handle and cannot accompany work_limits.",
				"options"
			)
		return budget
	if options.has("work_limits"):
		var supplied: Variant = options["work_limits"]
		if supplied is Dictionary:
			var supplied_limits: Dictionary = supplied
			return GFConfigWorkBudget.new(supplied_limits)
		var failed_budget: GFConfigWorkBudget = GFConfigWorkBudget.new()
		var _failed: bool = failed_budget._fail(
			"config_work_invalid_options",
			"work_limits must be a Dictionary.",
			"options"
		)
		return failed_budget
	return GFConfigWorkBudget.new()


## 读取或分配前检查剩余输入字节容量，不扣除额度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param amount: 本次准备读取的非负字节数。
## [br]
## @param context: 诊断位置。
## [br]
## @return 本次读取仍在剩余额度内时为 true。
func check_input_bytes(amount: int, context: String = "") -> bool:
	return _check_amount(
		"input_bytes",
		"max_input_bytes",
		amount,
		context
	)


## 累计原始输入字节；一个来源由读取者或解析者中的一方记账。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param amount: 本次新增的非负字节数。
## [br]
## @param context: 诊断位置。
## [br]
## @return 接受本次输入时为 true。
func consume_input_bytes(amount: int, context: String = "") -> bool:
	return _consume_bytes(
		"input_bytes",
		"max_input_bytes",
		amount,
		context
	)


## 累计序列化输出的 UTF-8 字节，供构造输出片段前预留容量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param amount: 本次新增的非负字节数。
## [br]
## @param context: 诊断位置。
## [br]
## @return 接受本次输出时为 true。
func consume_output_bytes(amount: int, context: String = "") -> bool:
	return _consume_bytes(
		"output_bytes",
		"max_output_bytes",
		amount,
		context
	)


## 累计显式工作单元，内部复用 GFExecutionBudget。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param amount: 本次执行的非负工作单元数。
## [br]
## @param context: 诊断位置。
## [br]
## @return 本次工作在剩余额度内时为 true。
func consume_work(amount: int = 1, context: String = "") -> bool:
	if not is_ok():
		return false
	if amount < 0:
		return _fail(
			"config_work_invalid_options",
			"Work amount must be nonnegative.",
			context
		)
	var limit: int = _limits["max_work_units"]
	if amount > limit - _execution.get_steps():
		return _fail(
			"config_work_limit_exceeded",
			"Configuration work unit limit exceeded.",
			context
		)
	return _execution.consume_steps(amount)


## 检查当前绝对嵌套深度；根值深度为 0。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param depth: 当前非负深度。
## [br]
## @param context: 诊断位置。
## [br]
## @return 深度合法且句柄未失败时为 true。
func check_depth(depth: int, context: String = "") -> bool:
	if not is_ok():
		return false
	if depth < 0:
		return _fail(
			"config_work_invalid_options",
			"Depth must be nonnegative.",
			context
		)
	var depth_limit: int = _limits["max_depth"]
	if depth > depth_limit:
		return _fail(
			"config_work_depth_exceeded",
			"Configuration nesting depth limit exceeded.",
			context
		)
	var peak_depth: int = _usage["peak_depth"]
	_usage["peak_depth"] = maxi(peak_depth, depth)
	return true


## 复制或遍历前准入数据图，重复调用按实际访问量累计，不缓存已检查身份。
##
## Dictionary 键和值及 Array 元素各计一个节点；Packed 元素与祖先身份比较也计工作量。
## PackedByteArray 按每 1024 字节一个工作块向上取整，完整字节仍计入载荷。
## String/StringName 计 UTF-8 载荷；NodePath 按名称、子名称及分隔符计 UTF-8 载荷，并累计组件访问与文字扫描工作。
## 数值 Packed 数组计保守存储字节。
## 仅拒绝当前祖先链循环，共享子容器合法。Resource 作为叶引用保留，不读取其属性；
## 其余 Object、Callable、Signal、RID 不属于可准入的配置值。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 要准入的配置值。
## [br]
## @schema value: Variant，支持无循环容器、原生值及 Resource 叶引用。
## [br]
## @param context: 诊断位置。
## [br]
## @return 完整数据图通过准入时为 true，失败不会复制输入。
func admit_value(value: Variant, context: String = "") -> bool:
	var ancestors: Array = []
	return _admit_value(
		value,
		0,
		ancestors,
		context
	)


## 检查句柄是否仍可使用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次失败前为 true。
func is_ok() -> bool:
	return (
		_error_kind.is_empty()
		and _execution != null
		and _execution.check()
	)


## 取得独立报告；修改报告不会改变预算状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 预算状态及计数。
## [br]
## @schema return: Dictionary，含 ok、error_kind、error、context、limits 与 usage；usage 含 work_units、input_bytes、value_bytes、output_bytes、peak_depth。
func get_report() -> Dictionary:
	var usage: Dictionary = _usage.duplicate()
	usage["work_units"] = _execution.get_steps() if _execution != null else 0
	return {
		"ok": is_ok(),
		"error_kind": _error_kind,
		"error": _error,
		"context": _context,
		"limits": _limits.duplicate(),
		"usage": usage,
	}


# --- 私有/辅助方法 ---

## 锁存首次失败，后续失败保留最初诊断。
## [br]
## @api private
func _fail(
	kind: String,
	message: String,
	context: String
) -> bool:
	if _error_kind.is_empty():
		_error_kind = kind
		_error = message
		_context = context
	return false


## 用剩余额度比较，避免累计加法溢出。
## [br]
## @api private
func _check_amount(
	counter: String,
	limit_key: String,
	amount: int,
	context: String
) -> bool:
	if not is_ok():
		return false
	if amount < 0:
		return _fail(
			"config_work_invalid_options",
			"Byte amount must be nonnegative.",
			context
		)
	var limit: int = _limits[limit_key]
	var used: int = _usage[counter]
	if amount > limit - used:
		return _fail(
			"config_work_%s_exceeded" % counter,
			"Configuration %s limit exceeded." % counter,
			context
		)
	return true


## 检查后累计已接受的字节。
## [br]
## @api private
func _consume_bytes(
	counter: String,
	limit_key: String,
	amount: int,
	context: String
) -> bool:
	if not _check_amount(
		counter,
		limit_key,
		amount,
		context
	):
		return false
	var used: int = _usage[counter]
	_usage[counter] = used + amount
	return true


## 有界扫描 UTF-8 长度，不先分配完整编码缓冲区。
## [br]
## @api private
func _admit_string(value: String, context: String) -> bool:
	if not _check_amount(
		"value_bytes",
		"max_value_bytes",
		value.length(),
		context
	):
		return false
	var chunk_bytes: int = 0
	var index: int = 0
	while index < value.length():
		if index % 1024 == 0 and not consume_work(1, context):
			return false
		var codepoint: int = value.unicode_at(index)
		if codepoint < 128:
			chunk_bytes += 1
		elif codepoint < 2048:
			chunk_bytes += 2
		elif codepoint < 65536:
			chunk_bytes += 3
		else:
			chunk_bytes += 4
		if index % 1024 == 1023:
			if not _consume_bytes(
				"value_bytes",
				"max_value_bytes",
				chunk_bytes,
				context
			):
				return false
			chunk_bytes = 0
		index += 1
	return _consume_bytes(
		"value_bytes",
		"max_value_bytes",
		chunk_bytes,
		context
	)


## 按组件准入路径载荷，保留原生值且不先拼接完整路径文本。
## [br]
## @api private
func _admit_node_path(value: NodePath, context: String) -> bool:
	var name_count: int = value.get_name_count()
	var subname_count: int = value.get_subname_count()
	if not consume_work(
		name_count + subname_count,
		context
	):
		return false
	var separator_bytes: int = maxi(
		name_count - 1,
		0
	) + subname_count
	if value.is_absolute():
		separator_bytes += 1
	if not _consume_bytes(
		"value_bytes",
		"max_value_bytes",
		separator_bytes,
		context
	):
		return false
	for index: int in range(name_count):
		if not _admit_string(
			String(value.get_name(index)),
			context
		):
			return false
	for index: int in range(subname_count):
		if not _admit_string(
			String(value.get_subname(index)),
			context
		):
			return false
	return true


## 递归访问前检查深度与节点，避免在准入前复制容器或 keys 数组。
## [br]
## @api private
func _admit_value(
	value: Variant,
	depth: int,
	ancestors: Array,
	context: String
) -> bool:
	if not check_depth(depth, context) or not consume_work(1, context):
		return false
	if value is Dictionary or value is Array:
		if not consume_work(
			ancestors.size(),
			context
		):
			return false
		for ancestor: Variant in ancestors:
			if is_same(ancestor, value):
				return _fail(
					"config_work_cycle",
					"Cyclic configuration container.",
					context
				)
		ancestors.append(value)
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			for key: Variant in dictionary_value:
				if not _admit_value(
					key,
					depth + 1,
					ancestors,
					context
				) or not _admit_value(
					dictionary_value[key],
					depth + 1,
					ancestors,
					context
				):
					return false
		else:
			var array_value: Array = value
			for item: Variant in array_value:
				if not _admit_value(
					item,
					depth + 1,
					ancestors,
					context
				):
					return false
		var _removed: Variant = ancestors.pop_back()
		return true
	if value is String or value is StringName:
		return _admit_string(
			str(value),
			context
		)
	if value is NodePath:
		var path_value: NodePath = value
		return _admit_node_path(path_value, context)
	if value is PackedStringArray:
		var string_values: PackedStringArray = value
		for item: String in string_values:
			if (
				not check_depth(
					depth + 1,
					context
				)
				or not consume_work(1, context)
				or not _admit_string(item, context)
			):
				return false
		return true
	var stride: int = _packed_stride(typeof(value))
	if stride > 0:
		var item_count: int = _packed_size(value)
		if item_count > 0 and not check_depth(
			depth + 1,
			context
		):
			return false
		var item_work: int = item_count
		if value is PackedByteArray:
			item_work = ceili(float(item_count) / 1024.0)
		if not consume_work(item_work, context):
			return false
		return _consume_bytes(
			"value_bytes",
			"max_value_bytes",
			item_count * stride,
			context
		)
	if value is Resource and is_instance_valid(value):
		return true
	if typeof(value) in [
		TYPE_OBJECT,
		TYPE_CALLABLE,
		TYPE_SIGNAL,
		TYPE_RID,
	]:
		return _fail(
			"config_work_unsupported_value",
			"Unsupported configuration value type.",
			context
		)
	return true


## 按原生数组元素类型返回保守字节宽度，兼容双精度向量构建。
## [br]
## @api private
func _packed_stride(value_type: int) -> int:
	match value_type:
		TYPE_PACKED_BYTE_ARRAY:
			return 1
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return 4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return 8
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return 16
		TYPE_PACKED_VECTOR3_ARRAY:
			return 24
		TYPE_PACKED_VECTOR4_ARRAY:
			return 32
	return 0


## 显式收窄原生数组类型，避免对 Variant 动态调用 size。
## [br]
## @api private
func _packed_size(value: Variant) -> int:
	if value is PackedByteArray:
		var items: PackedByteArray = value
		return items.size()
	if value is PackedInt32Array:
		var items: PackedInt32Array = value
		return items.size()
	if value is PackedInt64Array:
		var items: PackedInt64Array = value
		return items.size()
	if value is PackedFloat32Array:
		var items: PackedFloat32Array = value
		return items.size()
	if value is PackedFloat64Array:
		var items: PackedFloat64Array = value
		return items.size()
	if value is PackedVector2Array:
		var items: PackedVector2Array = value
		return items.size()
	if value is PackedVector3Array:
		var items: PackedVector3Array = value
		return items.size()
	if value is PackedVector4Array:
		var items: PackedVector4Array = value
		return items.size()
	if value is PackedColorArray:
		var items: PackedColorArray = value
		return items.size()
	return 0
