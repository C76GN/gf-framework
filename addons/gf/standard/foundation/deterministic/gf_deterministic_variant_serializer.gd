## GFDeterministicVariantSerializer: 有界纯数据的 canonical v2 二进制编码。
##
## 哈希、计量和字节导出使用同一遍历；成功报告计数精确，失败不发布部分摘要或字节。
## 输入可为调用期间稳定的纯 Variant 或 GFDataSnapshot。别名按值展开，循环和对象被拒绝。
## 浮点默认禁用；启用后拒绝非有限值并归一负零，不保证数值运算本身跨平台一致。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFDeterministicVariantSerializer
extends RefCounted


# --- 常量 ---

## 与哈希一同持久化的编码版本；v2 与旧 JSON 摘要不相同。
## [br]
## @api public
## [br]
## @since unreleased
const CANONICAL_VERSION: int = 2

## 唯一的编码执行器。
## [br]
## @api private
const _ENCODER_SCRIPT = preload("res://addons/gf/standard/foundation/deterministic/gf_canonical_encoder.gd")


# --- 公共方法 ---

## 单次遍历生成 SHA-256 及完整计量，不复制源树或构建完整输出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 稳定的纯数据或已捕获快照。
## [br]
## @schema value: Scalar, math, String, StringName, NodePath, Array, Dictionary, packed arrays, or GFDataSnapshot. Objects, executable values, RID and cycles are rejected.
## [br]
## @param options: 编码政策及有限预算。
## [br]
## @schema options: Dictionary with allow_floats: bool (false), positive max_depth (64, at most 256), max_items (100000), max_string_length (1048576 characters), max_output_bytes (16777216 canonical bytes), max_sort_bytes (16777216 logical sorting workspace bytes), max_elapsed_msec (30000), and optional cancel_token: GFCancellationToken.
## [br]
## @return 失败时 hash 为空且 counts_complete 为 false；所有入口均不输出错误日志。
## [br]
## @schema return: Dictionary with ok, canonical_version, hash, bytes, counts_complete, items, packed_items, output_bytes, maximum_depth, peak_sort_bytes, error, error_kind, error_path, failure_kind, limit_kind, limit, observed and observed_is_lower_bound. Failure counters describe processed input only. bytes is empty in hash and measurement modes.
static func hash_result(value: Variant, options: Dictionary = {}) -> Dictionary:
	return _encode(
		value,
		options,
		&"hash"
	)


## 单次遍历导出完整 canonical v2 字节及相同计量；受输出预算约束。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 纯数据或已捕获快照。
## [br]
## @schema value: Same input domain as hash_result.
## [br]
## @param options: 编码政策及预算。
## [br]
## @schema options: Same options as hash_result.
## [br]
## @return 成功时 bytes 包含完整编码，hash 为空。
## [br]
## @schema return: Same result fields as hash_result, with bytes: PackedByteArray.
static func encode_result(value: Variant, options: Dictionary = {}) -> Dictionary:
	return _encode(
		value,
		options,
		&"bytes"
	)


## 只计量规范编码，不生成摘要或完整字节，也不授予后续编码资格。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 调用期间稳定的纯数据或快照。
## [br]
## @schema value: Same input domain as hash_result.
## [br]
## @param options: 编码政策和预算。
## [br]
## @schema options: Same options as hash_result.
## [br]
## @return 成功时字节数精确，失败立即停止；字典排序仍使用有界工作区。
## [br]
## @schema return: Same result fields as hash_result, with empty hash and bytes.
static func measure_canonical(value: Variant, options: Dictionary = {}) -> Dictionary:
	return _encode(
		value,
		options,
		&"measure"
	)


## 返回 canonical v2 SHA-256；需要失败诊断时使用 hash_result。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 纯数据或快照。
## [br]
## @schema value: Same input domain as hash_result.
## [br]
## @param options: 编码政策和预算。
## [br]
## @schema options: Same options as hash_result.
## [br]
## @return 成功时返回摘要，失败返回空字符串。
static func sha256(value: Variant, options: Dictionary = {}) -> String:
	return hash_result(value, options)["hash"]


## 返回完整 canonical v2 字节；需要失败诊断时使用 encode_result。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 纯数据或快照。
## [br]
## @schema value: Same input domain as hash_result.
## [br]
## @param options: 编码政策和预算。
## [br]
## @schema options: Same options as hash_result.
## [br]
## @return 成功时返回二进制编码，失败返回空数组。
static func to_canonical_bytes(value: Variant, options: Dictionary = {}) -> PackedByteArray:
	return encode_result(value, options)["bytes"]


# --- 私有/辅助方法 ---

## 快照仅借用其独占树；执行器在同步调用内使用，不保留源引用。
## [br]
## @api private
static func _encode(
	value: Variant,
	options: Dictionary,
	mode: StringName
) -> Dictionary:
	var encoder: _ENCODER_SCRIPT = _ENCODER_SCRIPT.new(options, mode)
	if value is GFDataSnapshot:
		var snapshot: GFDataSnapshot = value
		if not snapshot.is_ready():
			return encoder.reject_snapshot()
		return encoder.encode(snapshot.get_value_for_framework())
	return encoder.encode(value)
