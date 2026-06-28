## GFDeterministicRandom: 固定 xorshift32 算法的确定性随机源。
##
## 该类型使用 GF 自有的 32-bit 状态转换，不依赖 Godot 全局随机状态或
## RandomNumberGenerator 的内部算法。它适合锁步、回放、黄金测试和需要固定序列的
## 纯算法工具；不提供密码学安全随机。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 5.0.0
class_name GFDeterministicRandom
extends RefCounted


# --- 常量 ---

const _ALGORITHM: String = "xorshift32"
const _DEFAULT_SEED: int = 0x6d2b79f5
const _MASK_U32: int = 0xffffffff
const _MOD_U32: int = 0x100000000
const _STREAM_SALT: int = 0x9e3779b9
const _STATE_VERSION: int = 1


# --- 私有变量 ---

var _initial_seed: int = _DEFAULT_SEED
var _state: int = _DEFAULT_SEED


# --- Godot 生命周期方法 ---

func _init(seed_value: int = _DEFAULT_SEED) -> void:
	set_seed(seed_value)


# --- 公共方法 ---

## 从种子创建确定性随机源。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param seed_value: 初始种子；0 会映射到稳定默认种子，避免 xorshift32 零状态。
## [br]
## @return 新随机源实例。
static func from_seed(seed_value: int) -> GFDeterministicRandom:
	return GFDeterministicRandom.new(seed_value)


## 使用字典创建确定性随机源。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_dict()` 输出的状态字典。
## [br]
## @schema data: Dictionary with `algorithm: String`, `version: int`, `seed: int`, and `state: int` fields.
## [br]
## @return 新随机源实例。
static func from_dict(data: Dictionary) -> GFDeterministicRandom:
	var rng: GFDeterministicRandom = GFDeterministicRandom.new()
	var _applied: bool = rng.apply_dict(data)
	return rng


## 重置种子和当前状态。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param seed_value: 初始种子；0 会映射到稳定默认种子。
func set_seed(seed_value: int) -> void:
	_initial_seed = _normalize_state(seed_value)
	_state = _initial_seed


## 获取初始种子。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 当前随机源最近一次设置的非零 u32 种子。
func get_initial_seed() -> int:
	return _initial_seed


## 获取当前内部状态。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 非零 u32 状态值。
func get_state() -> int:
	return _state


## 覆盖当前内部状态。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param state_value: 非零 u32 状态值。
## [br]
## @return 状态有效并已应用时返回 true。
func set_state(state_value: int) -> bool:
	var normalized_state: int = _to_u32(state_value)
	if normalized_state == 0:
		push_error("[GFDeterministicRandom] xorshift32 状态不能为 0。")
		return false

	_state = normalized_state
	return true


## 生成下一个 u32。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 范围为 0 到 4294967295 的整数。
func next_u32() -> int:
	_state = _step(_state)
	return _state


## 生成闭区间内的整数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param min_value: 闭区间下界。
## [br]
## @param max_value: 闭区间上界；小于 `min_value` 时会自动交换。
## [br]
## @return 位于闭区间内的整数；区间跨度超过 u32 时返回下界并报错。
func next_int_range(min_value: int, max_value: int) -> int:
	var lower: int = min_value
	var upper: int = max_value
	if upper < lower:
		var old_lower: int = lower
		lower = upper
		upper = old_lower

	var span: int = upper - lower + 1
	if span <= 0 or span > _MOD_U32:
		push_error("[GFDeterministicRandom] next_int_range 只支持跨度不超过 u32 的闭区间。")
		return lower

	var rejection_limit: int = _MOD_U32 - (_MOD_U32 % span)
	var sample: int = next_u32()
	while sample >= rejection_limit:
		sample = next_u32()

	return lower + sample % span


## 生成 0.0 到 1.0 之间的浮点数，包含 0.0 但不包含 1.0。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 基于固定 u32 输出缩放得到的浮点数。浮点几何算法仍不应作为定点锁步真值。
func next_float_unit() -> float:
	return float(next_u32()) / float(_MOD_U32)


## 生成指定范围内的浮点数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param min_value: 范围下界。
## [br]
## @param max_value: 范围上界；小于 `min_value` 时会自动交换。
## [br]
## @return 基于固定 u32 输出缩放得到的范围内浮点数。
func next_float_range(min_value: float, max_value: float) -> float:
	if is_nan(min_value) or is_nan(max_value) or is_inf(min_value) or is_inf(max_value):
		push_error("[GFDeterministicRandom] next_float_range 只支持有限浮点边界。")
		return 0.0

	var lower: float = min_value
	var upper: float = max_value
	if upper < lower:
		var old_lower: float = lower
		lower = upper
		upper = old_lower

	var span: float = upper - lower
	if is_nan(span) or is_inf(span):
		push_error("[GFDeterministicRandom] next_float_range 只支持有限浮点范围。")
		return 0.0

	var result: float = lower + next_float_unit() * span
	if is_nan(result) or is_inf(result):
		push_error("[GFDeterministicRandom] next_float_range 结果超出有限浮点范围。")
		return 0.0
	return result


## 生成布尔值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 随机布尔值。
func next_bool() -> bool:
	return (next_u32() & 1) == 1


## 跳过若干次输出。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param count: 要跳过的输出数量；小于等于 0 时不改变状态。
func skip(count: int) -> void:
	for _index: int in range(maxi(count, 0)):
		var _discarded: int = next_u32()


## 派生子随机源。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param stream_id: 子流标识；同一父状态和同一标识会得到同一种子。
## [br]
## @return 派生随机源。
func fork(stream_id: int) -> GFDeterministicRandom:
	var child_seed: int = _normalize_state(_step(_state ^ _to_u32(stream_id) ^ _STREAM_SALT))
	return GFDeterministicRandom.new(child_seed)


## 导出当前状态字典。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 可稳定恢复随机源的字典。
## [br]
## @schema return: Dictionary with `algorithm: String`, `version: int`, `seed: int`, and `state: int` fields.
func to_dict() -> Dictionary:
	return {
		"algorithm": _ALGORITHM,
		"version": _STATE_VERSION,
		"seed": _initial_seed,
		"state": _state,
	}


## 应用状态字典。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_dict()` 输出的状态字典。
## [br]
## @schema data: Dictionary with `algorithm: String`, `version: int`, `seed: int`, and `state: int` fields.
## [br]
## @return 状态有效并已应用时返回 true。
func apply_dict(data: Dictionary) -> bool:
	var algorithm: String = GFVariantData.get_option_string(data, "algorithm", _ALGORITHM)
	var version: int = GFVariantData.get_option_int(data, "version", _STATE_VERSION)
	var seed_data: Variant = GFVariantData.get_option_value(data, "seed")
	var state_data: Variant = GFVariantData.get_option_value(data, "state")
	if (
		algorithm != _ALGORITHM
		or version != _STATE_VERSION
		or not _state_value_is_u32(seed_data)
		or not _state_value_is_u32(state_data)
	):
		push_error("[GFDeterministicRandom] 不支持的状态字典格式。")
		set_seed(_DEFAULT_SEED)
		return false

	_initial_seed = _normalize_state(_state_value_to_int(seed_data))
	var state_value: int = _to_u32(_state_value_to_int(state_data))
	if state_value == 0:
		push_error("[GFDeterministicRandom] xorshift32 状态不能为 0。")
		set_seed(_DEFAULT_SEED)
		return false

	_state = state_value
	return true


# --- 私有/辅助方法 ---

static func _normalize_state(value: int) -> int:
	var result: int = _to_u32(value)
	return _DEFAULT_SEED if result == 0 else result


static func _to_u32(value: int) -> int:
	var result: int = value % _MOD_U32
	if result < 0:
		result += _MOD_U32
	return result


static func _step(state_value: int) -> int:
	var next_state: int = _to_u32(state_value)
	next_state = _to_u32(next_state ^ ((next_state << 13) & _MASK_U32))
	next_state = _to_u32(next_state ^ (next_state >> 17))
	next_state = _to_u32(next_state ^ ((next_state << 5) & _MASK_U32))
	return _normalize_state(next_state)


static func _state_value_is_u32(value: Variant) -> bool:
	if value is int:
		var int_value: int = value
		return int_value >= 0 and int_value <= _MASK_U32
	if value is String or value is StringName:
		return _u32_text_is_valid(str(value))
	return false


static func _state_value_to_int(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	return str(value).strip_edges().to_int()


static func _u32_text_is_valid(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty() or trimmed.begins_with("-") or trimmed.begins_with("+"):
		return false

	for i: int in range(trimmed.length()):
		var character: String = trimmed.substr(i, 1)
		if character < "0" or character > "9":
			return false

	var significant_digits: String = trimmed
	while significant_digits.length() > 1 and significant_digits.begins_with("0"):
		significant_digits = significant_digits.substr(1)
	if significant_digits.length() > 10:
		return false
	if significant_digits.length() == 10 and significant_digits > str(_MASK_U32):
		return false
	return true
