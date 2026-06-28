## GFSeedUtility: 全局随机数种子管理器。
##
## 内部维护一个主 RandomNumberGenerator，并支持基于字符串标签派生
## 出独立的 Godot RNG 或 GF 固定算法随机源。Godot RNG 分支只承诺
## 同一 Godot 运行时随机算法下的复现；需要长期、跨运行时强确定性时，
## 使用 deterministic 分支。
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
	_rng.seed = _global_seed
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
	var parsed_state: Dictionary = _parse_full_state(state)
	if not GFVariantData.get_option_bool(parsed_state, &"ok", false):
		return

	_global_seed = GFVariantData.get_option_int(parsed_state, &"global_seed")
	_rng.seed = _global_seed
	_rng.state = GFVariantData.get_option_int(parsed_state, &"rng_state")
	_branch_counters = GFVariantData.get_option_dictionary(parsed_state, &"branch_counters")
	_deterministic_branch_counters = GFVariantData.get_option_dictionary(parsed_state, &"deterministic_branch_counters")


## 基于主 RNG 当前状态与字符串标签，派生出一个独立的 Godot 子 RNG。
## 每次调用只推进当前标签的分支计数，不推进主 RNG 的随机序列。
## 同一主状态、同一标签和同一调用序号会在同一 Godot 随机算法下产生可复现的子随机序列。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @deprecated 5.2.0 Use get_branched_godot_rng() when a Godot RandomNumberGenerator stream is required; use get_branched_deterministic_random() for long-term deterministic simulation.
## [br]
## @param string_seed: 用于标识子随机流用途的字符串（如 "loot_table"、"enemy_ai"）。
## [br]
## @return 一个已完成种子初始化的独立 RandomNumberGenerator 实例。
func get_branched_rng(string_seed: String) -> RandomNumberGenerator:
	return get_branched_godot_rng(string_seed)


## 基于主 RNG 当前状态与字符串标签，派生出一个独立的 Godot 子 RNG。
## 每次调用只推进当前标签的 Godot RNG 分支计数，不推进主 RNG 的随机序列。
## 该入口返回 Godot `RandomNumberGenerator`，适合非锁步玩法、编辑器工具和同一 Godot 版本内复现；不作为跨 Godot 版本固定序列契约。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param string_seed: 用于标识子随机流用途的字符串。
## [br]
## @return 一个已完成种子初始化的独立 RandomNumberGenerator 实例。
func get_branched_godot_rng(string_seed: String) -> RandomNumberGenerator:
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
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var _append_result: bool = keys.append(str(key))

	keys.sort()
	for key_text: String in keys:
		var counter_value: Variant = _get_branch_counter_value(source, key_text)
		result[key_text] = _int_to_state_text(GFVariantData.to_int(counter_value))
	return result


func _try_decode_branch_counters(value: Variant, field_name: String) -> Dictionary:
	if not (value is Dictionary):
		return _make_parse_error("字段 %s 必须是 Dictionary" % field_name)

	var result: Dictionary = {}
	var dictionary: Dictionary = value
	for key: Variant in dictionary.keys():
		var key_text: String = str(key)
		var value_result: Dictionary = _try_state_value_to_int(dictionary[key], "%s.%s" % [field_name, key_text])
		if not GFVariantData.get_option_bool(value_result, &"ok", false):
			return value_result

		var counter: int = GFVariantData.get_option_int(value_result, &"value")
		if counter < 0:
			return _make_parse_error("字段 %s.%s 必须是非负整数" % [field_name, key_text])

		result[key_text] = counter
	return _make_parse_value(result)


func _get_branch_counter_value(source: Dictionary, key_text: String) -> Variant:
	if source.has(key_text):
		return source[key_text]

	var string_name_key: StringName = StringName(key_text)
	if source.has(string_name_key):
		return source[string_name_key]

	for key: Variant in source.keys():
		if str(key) == key_text:
			return source[key]

	return 0


func _parse_full_state(state: Dictionary) -> Dictionary:
	var schema_result: Dictionary = _try_get_required_state_int(state, &"state_schema_version")
	if not GFVariantData.get_option_bool(schema_result, &"ok", false):
		_report_invalid_full_state(schema_result)
		return schema_result

	var schema_version: int = GFVariantData.get_option_int(schema_result, &"value")
	if not _state_schema_version_is_supported(schema_version):
		push_error("[GFSeedUtility] 不支持的完整随机状态 schema 版本：%d。" % schema_version)
		return _make_parse_error("unsupported_schema")

	var global_seed_result: Dictionary = _try_get_required_state_int(state, &"global_seed")
	if not GFVariantData.get_option_bool(global_seed_result, &"ok", false):
		_report_invalid_full_state(global_seed_result)
		return global_seed_result

	var rng_state_result: Dictionary = _try_get_required_state_int(state, &"rng_state")
	if not GFVariantData.get_option_bool(rng_state_result, &"ok", false):
		_report_invalid_full_state(rng_state_result)
		return rng_state_result

	var branch_value_result: Dictionary = _try_get_required_state_value(state, &"branch_counters")
	if not GFVariantData.get_option_bool(branch_value_result, &"ok", false):
		_report_invalid_full_state(branch_value_result)
		return branch_value_result

	var branch_counters_result: Dictionary = _try_decode_branch_counters(
		GFVariantData.get_option_value(branch_value_result, &"value"),
		"branch_counters"
	)
	if not GFVariantData.get_option_bool(branch_counters_result, &"ok", false):
		_report_invalid_full_state(branch_counters_result)
		return branch_counters_result

	var deterministic_value_result: Dictionary = _try_get_required_state_value(state, &"deterministic_branch_counters")
	if not GFVariantData.get_option_bool(deterministic_value_result, &"ok", false):
		_report_invalid_full_state(deterministic_value_result)
		return deterministic_value_result

	var deterministic_branch_counters_result: Dictionary = _try_decode_branch_counters(
		GFVariantData.get_option_value(deterministic_value_result, &"value"),
		"deterministic_branch_counters"
	)
	if not GFVariantData.get_option_bool(deterministic_branch_counters_result, &"ok", false):
		_report_invalid_full_state(deterministic_branch_counters_result)
		return deterministic_branch_counters_result

	return {
		&"ok": true,
		&"global_seed": GFVariantData.get_option_int(global_seed_result, &"value"),
		&"rng_state": GFVariantData.get_option_int(rng_state_result, &"value"),
		&"branch_counters": GFVariantData.get_option_dictionary(branch_counters_result, &"value"),
		&"deterministic_branch_counters": GFVariantData.get_option_dictionary(deterministic_branch_counters_result, &"value"),
	}


func _try_get_required_state_int(state: Dictionary, key: StringName) -> Dictionary:
	var value_result: Dictionary = _try_get_required_state_value(state, key)
	if not GFVariantData.get_option_bool(value_result, &"ok", false):
		return value_result
	return _try_state_value_to_int(
		GFVariantData.get_option_value(value_result, &"value"),
		String(key)
	)


func _try_get_required_state_value(state: Dictionary, key: StringName) -> Dictionary:
	if state.has(key):
		return _make_parse_value(state[key])

	var string_key: String = String(key)
	if state.has(string_key):
		return _make_parse_value(state[string_key])

	return _make_parse_error("缺少字段 %s" % string_key)


func _try_state_value_to_int(value: Variant, field_name: String) -> Dictionary:
	if value is int:
		var int_value: int = value
		return _make_parse_value(int_value)

	if value is float:
		var float_value: float = value
		if _float_value_is_json_safe_integer(float_value):
			return _make_parse_value(int(float_value))

	if value is String or value is StringName:
		var text: String = str(value).strip_edges()
		if _signed_int_text_is_valid(text):
			return _make_parse_value(text.to_int())

	return _make_parse_error("字段 %s 必须是整数或十进制整数字符串" % field_name)


func _state_schema_version_is_supported(version: int) -> bool:
	return version >= 1 and version <= _STATE_SCHEMA_VERSION


func _int_to_state_text(value: int) -> String:
	return str(value)


func _report_invalid_full_state(error_result: Dictionary) -> void:
	var message: String = GFVariantData.get_option_string(error_result, &"error", "字段无效")
	push_error("[GFSeedUtility] 无效完整随机状态：%s。" % message)


func _make_parse_value(value: Variant) -> Dictionary:
	return {
		&"ok": true,
		&"value": value,
	}


func _make_parse_error(message: String) -> Dictionary:
	return {
		&"ok": false,
		&"error": message,
	}


func _signed_int_text_is_valid(text: String) -> bool:
	if text.is_empty():
		return false

	var digits: String = text
	var negative: bool = false
	if digits.begins_with("-") or digits.begins_with("+"):
		negative = digits.begins_with("-")
		digits = digits.substr(1)

	if digits.is_empty():
		return false

	for index: int in range(digits.length()):
		var character: String = digits.substr(index, 1)
		if character < "0" or character > "9":
			return false

	var significant_digits: String = digits
	while significant_digits.length() > 1 and significant_digits.begins_with("0"):
		significant_digits = significant_digits.substr(1)

	var max_text: String = "9223372036854775808" if negative else "9223372036854775807"
	if significant_digits.length() > max_text.length():
		return false
	if significant_digits.length() == max_text.length() and significant_digits > max_text:
		return false
	return true


func _float_value_is_json_safe_integer(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	if value != floor(value):
		return false
	return value >= -9_007_199_254_740_991.0 and value <= 9_007_199_254_740_991.0


func _ensure_rng() -> void:
	if _rng == null:
		init()
