## GFSeedUtility: 全局随机数种子管理器。
##
## 内部维护一个主 RandomNumberGenerator，并支持基于字符串标签派生
## 出独立的 Godot RNG 或 GF 固定算法随机源。Godot RNG 分支适合
## 同一 Godot 环境内的运行时复现；需要跨 GF 版本固定序列时使用
## deterministic 分支。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSeedUtility
extends GFUtility


# --- 常量 ---

const _STATE_SCHEMA_VERSION: int = 3
const _FNV_32_OFFSET: int = 2_166_136_261
const _FNV_32_PRIME: int = 16_777_619
const _UINT_32_MASK: int = 0xffffffff


# --- 私有变量 ---

var _rng: RandomNumberGenerator
var _global_seed: int
var _branch_counters: Dictionary = {}
var _deterministic_branch_counters: Dictionary = {}


# --- GF 生命周期方法 ---

## 第一阶段初始化：创建主 RNG 实例。
## [br]
## @api public
func init() -> void:
	_rng = RandomNumberGenerator.new()
	_global_seed = 0
	_branch_counters.clear()
	_deterministic_branch_counters.clear()


# --- 公共方法 ---

## 设置全局主种子，并同步应用到主 RNG。
## [br]
## @api public
## [br]
## @param seed_hash: 用于驱动主随机数序列的整数种子。
func set_global_seed(seed_hash: int) -> void:
	_ensure_rng()
	_global_seed = seed_hash
	_rng.seed = seed_hash
	_branch_counters.clear()
	_deterministic_branch_counters.clear()


## 获取当前全局主种子。
## [br]
## @api public
## [br]
## @return 当前全局主种子。
func get_global_seed() -> int:
	_ensure_rng()
	return _global_seed


## 获取主随机数生成器。
##
## 调用方可以直接使用该实例生成随机数；生成行为会推进主 RNG 状态。
## [br]
## @api public
## [br]
## @return 主随机数生成器实例。
func get_rng() -> RandomNumberGenerator:
	_ensure_rng()
	return _rng


## 获取当前主 RNG 的内部精确状态。
## [br]
## @api public
## [br]
## @return 当前的内部状态值。
func get_state() -> int:
	_ensure_rng()
	return _rng.state


## 恢复主 RNG 的内部精确状态。
## [br]
## @api public
## [br]
## @param state: 要恢复的内部状态值。
func set_state(state: int) -> void:
	_ensure_rng()
	_rng.state = state


## 获取包含主种子、主 RNG 状态与分支计数的完整随机状态。
## 返回的 64 位整数状态会以十进制字符串保存，确保默认 JSON 存储可精确往返。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return JSON 安全的完整随机状态。
## [br]
## @schema return: Dictionary with `state_schema_version: int`, `global_seed: String`, `rng_state: String`, `branch_counters: Dictionary[String, String]`, and `deterministic_branch_counters: Dictionary[String, String]`.
func get_full_state() -> Dictionary:
	_ensure_rng()
	return {
		&"state_schema_version": _STATE_SCHEMA_VERSION,
		&"global_seed": _int_to_state_text(_global_seed),
		&"rng_state": _int_to_state_text(_rng.state),
		&"branch_counters": _encode_branch_counters(_branch_counters),
		&"deterministic_branch_counters": _encode_branch_counters(_deterministic_branch_counters),
	}


## 恢复完整随机状态。
## [br]
## @api public
## [br]
## @param state: get_full_state() 产生的字典。
## [br]
## @schema state: Dictionary produced by get_full_state().
func set_full_state(state: Dictionary) -> void:
	_ensure_rng()
	var schema_version: int = _state_value_to_int(_get_state_value(state, &"state_schema_version", 1), 1)
	if not _state_schema_version_is_supported(schema_version):
		push_error("[GFSeedUtility] 不支持的完整随机状态 schema 版本：%d。" % schema_version)
		return

	_global_seed = _state_value_to_int(_get_state_value(state, &"global_seed", _global_seed), _global_seed)
	_rng.seed = _global_seed
	_rng.state = _state_value_to_int(_get_state_value(state, &"rng_state", _rng.state), _rng.state)

	var branch_counters: Variant = _get_state_value(state, &"branch_counters", {})
	_branch_counters = _decode_branch_counters(branch_counters)

	var deterministic_branch_counters: Variant = _get_state_value(state, &"deterministic_branch_counters", {})
	_deterministic_branch_counters = _decode_branch_counters(deterministic_branch_counters)


## 基于主 RNG 当前状态与字符串标签，派生出一个独立的子 RNG。
## 每次调用只推进当前标签的分支计数，不推进主 RNG 的随机序列。
## 同一主状态、同一标签和同一调用序号会产生确定的子随机序列。
## [br]
## @api public
## [br]
## @param string_seed: 用于标识子随机流用途的字符串（如 "loot_table"、"enemy_ai"）。
## [br]
## @return 一个已完成种子初始化的独立 RandomNumberGenerator 实例。
func get_branched_rng(string_seed: String) -> RandomNumberGenerator:
	_ensure_rng()
	var branched: RandomNumberGenerator = RandomNumberGenerator.new()
	var branch_index: int = _next_branch_index(_branch_counters, string_seed)

	var branch_seed: int = _stable_hash("%d:%d:%s:%d" % [
		_global_seed,
		_rng.state,
		string_seed,
		branch_index,
	])
	branched.seed = branch_seed
	return branched


## 基于主 RNG 当前状态与字符串标签，派生 GF 固定算法随机源。
## 每次调用只推进 deterministic 分支计数，不推进主 RNG 的随机序列，
## 也不影响 `get_branched_rng()` 的 Godot RNG 分支计数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param string_seed: 用于标识确定性子随机流用途的字符串。
## [br]
## @return 一个已完成种子初始化的独立 GFDeterministicRandom 实例。
func get_branched_deterministic_random(string_seed: String) -> GFDeterministicRandom:
	_ensure_rng()
	var branch_index: int = _next_branch_index(_deterministic_branch_counters, string_seed)
	var branch_seed: int = _stable_hash("%d:%d:deterministic:%s:%d" % [
		_global_seed,
		_rng.state,
		string_seed,
		branch_index,
	])
	return GFDeterministicRandom.from_seed(branch_seed)


# --- 私有/辅助方法 ---

func _stable_hash(text: String) -> int:
	var hash_value: int = _FNV_32_OFFSET
	var bytes: PackedByteArray = text.to_utf8_buffer()
	for value: int in bytes:
		hash_value = ((hash_value ^ value) * _FNV_32_PRIME) & _UINT_32_MASK
	return hash_value


func _next_branch_index(counter_map: Dictionary, string_seed: String) -> int:
	var branch_index: int = GFVariantData.get_option_int(counter_map, string_seed)
	counter_map[string_seed] = branch_index + 1
	return branch_index


func _encode_branch_counters(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		result[str(key)] = _int_to_state_text(GFVariantData.to_int(source[key]))
	return result


func _decode_branch_counters(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}

	var result: Dictionary = {}
	var dictionary: Dictionary = value
	for key: Variant in dictionary.keys():
		result[str(key)] = _state_value_to_int(dictionary[key], 0)
	return result


func _get_state_value(state: Dictionary, key: StringName, fallback: Variant) -> Variant:
	if state.has(key):
		return state[key]

	var string_key: String = String(key)
	if state.has(string_key):
		return state[string_key]
	return fallback


func _state_value_to_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	return GFVariantData.to_int(value)


func _state_schema_version_is_supported(version: int) -> bool:
	return version >= 1 and version <= _STATE_SCHEMA_VERSION


func _int_to_state_text(value: int) -> String:
	return str(value)


func _ensure_rng() -> void:
	if _rng == null:
		init()
