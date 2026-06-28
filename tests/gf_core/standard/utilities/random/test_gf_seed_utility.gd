extends GutTest


const GF_DETERMINISTIC_RANDOM = preload("res://addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd")


var _seed_util: GFSeedUtility


func before_each() -> void:
	_seed_util = GFSeedUtility.new()
	_seed_util.init()


func after_each() -> void:
	_seed_util = null


func test_state_save_and_restore() -> void:
	_seed_util.set_global_seed(12345)

	var _first_val: int = _seed_util.get_rng().randi()
	var state_to_save: int = _seed_util.get_state()

	var next_val1: int = _seed_util.get_rng().randi()
	var next_val2: int = _seed_util.get_rng().randi()

	_seed_util.set_state(state_to_save)

	var restored_val1: int = _seed_util.get_rng().randi()
	var restored_val2: int = _seed_util.get_rng().randi()

	assert_eq(restored_val1, next_val1, "恢复状态后，生成的第一个随机数应与之前一致。")
	assert_eq(restored_val2, next_val2, "恢复状态后，生成的第二个随机数应与之前一致。")


func test_get_global_seed() -> void:
	_seed_util.set_global_seed(98765)
	assert_eq(_seed_util.get_global_seed(), 98765, "get_global_seed 应返回正确的种子值。")


func test_direct_new_lazily_initializes_rng() -> void:
	var seed_util: GFSeedUtility = GFSeedUtility.new()

	seed_util.set_global_seed(123)
	var state: int = seed_util.get_state()
	var rng: RandomNumberGenerator = seed_util.get_branched_rng("lazy")

	assert_eq(seed_util.get_global_seed(), 123, "直接 new 后公共方法应能懒初始化 RNG。")
	assert_eq(typeof(state), TYPE_INT, "懒初始化后应能读取 RNG 状态。")
	assert_true(rng != null, "懒初始化后应能派生子 RNG。")


func test_default_init_seed_is_deterministic_without_explicit_seed() -> void:
	var first_seed_util: GFSeedUtility = GFSeedUtility.new()
	var second_seed_util: GFSeedUtility = GFSeedUtility.new()
	first_seed_util.init()
	second_seed_util.init()

	var first_rng: GF_DETERMINISTIC_RANDOM = first_seed_util.get_branched_deterministic_random("loot")
	var second_rng: GF_DETERMINISTIC_RANDOM = second_seed_util.get_branched_deterministic_random("loot")

	assert_eq(first_seed_util.get_global_seed(), 0, "默认全局种子应稳定为 0。")
	assert_eq(first_rng.get_initial_seed(), second_rng.get_initial_seed(), "未显式设置种子时，同名 deterministic 分支也应稳定。")


func test_get_branched_rng_uniqueness() -> void:
	_seed_util.set_global_seed(12345)
	var rng1: RandomNumberGenerator = _seed_util.get_branched_rng("test")
	var rng2: RandomNumberGenerator = _seed_util.get_branched_rng("test")

	assert_ne(rng1.seed, rng2.seed, "连续生成的基于相同标签的子 RNG 应该具有不同的种子。")
	assert_ne(rng1.randi(), rng2.randi(), "连续生成的子 RNG 随机序列应该是不同的。")


func test_get_branched_rng_determinism() -> void:
	_seed_util.set_global_seed(12345)
	var rng1: RandomNumberGenerator = _seed_util.get_branched_rng("module_a")
	var val1: int = rng1.randi()

	_seed_util.set_global_seed(12345)
	var rng2: RandomNumberGenerator = _seed_util.get_branched_rng("module_a")
	var val2: int = rng2.randi()

	assert_eq(val1, val2, "在完全相同的主状态和标签下，生成的子 RNG 序列应当是确定性的。")


func test_get_branched_godot_rng_matches_legacy_godot_rng_stream() -> void:
	_seed_util.set_global_seed(12345)
	var godot_rng: RandomNumberGenerator = _seed_util.get_branched_godot_rng("module_a")
	var godot_value: int = godot_rng.randi()

	_seed_util.set_global_seed(12345)
	var legacy_rng: RandomNumberGenerator = _seed_util.get_branched_rng("module_a")
	var legacy_value: int = legacy_rng.randi()

	assert_eq(godot_value, legacy_value, "明确命名的 Godot RNG 分支应保持旧入口的 Godot RNG 行为。")


func test_get_branched_rng_does_not_advance_main_rng() -> void:
	_seed_util.set_global_seed(24680)
	var state_before: int = _seed_util.get_state()

	var _get_branched_rng_result_76: Variant = _seed_util.get_branched_rng("loot")
	var _get_branched_rng_result_77: Variant = _seed_util.get_branched_rng("loot")

	assert_eq(_seed_util.get_state(), state_before, "派生子 RNG 不应推进主随机序列状态。")


func test_get_branched_deterministic_random_determinism() -> void:
	_seed_util.set_global_seed(12345)
	var rng1: GF_DETERMINISTIC_RANDOM = _seed_util.get_branched_deterministic_random("module_a")
	var val1: int = rng1.next_u32()

	_seed_util.set_global_seed(12345)
	var rng2: GF_DETERMINISTIC_RANDOM = _seed_util.get_branched_deterministic_random("module_a")
	var val2: int = rng2.next_u32()

	assert_eq(rng1.get_initial_seed(), rng2.get_initial_seed(), "相同主状态和标签应派生相同 deterministic 种子。")
	assert_eq(val1, val2, "相同主状态和标签应派生相同 deterministic 序列。")


func test_deterministic_branch_counter_is_separate_from_godot_branch_counter() -> void:
	_seed_util.set_global_seed(24680)
	var first_godot_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var deterministic_rng: GF_DETERMINISTIC_RANDOM = _seed_util.get_branched_deterministic_random("loot")
	var second_godot_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var deterministic_value: int = deterministic_rng.next_u32()

	_seed_util.set_global_seed(24680)
	var expected_first_godot_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var expected_second_godot_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")

	_seed_util.set_global_seed(24680)
	var _godot_rng_result: Variant = _seed_util.get_branched_rng("loot")
	var expected_deterministic_rng: GF_DETERMINISTIC_RANDOM = _seed_util.get_branched_deterministic_random("loot")

	assert_eq(first_godot_rng.seed, expected_first_godot_rng.seed, "deterministic 分支不应影响第一个 Godot 分支。")
	assert_eq(second_godot_rng.seed, expected_second_godot_rng.seed, "deterministic 分支不应消耗 Godot 分支计数。")
	assert_eq(deterministic_rng.get_initial_seed(), expected_deterministic_rng.get_initial_seed(), "Godot 分支不应消耗 deterministic 分支计数。")
	assert_eq(deterministic_value, expected_deterministic_rng.next_u32(), "分支计数隔离后 deterministic 序列应保持可复现。")


func test_full_state_restores_branch_counters() -> void:
	_seed_util.set_global_seed(13579)
	var _get_branched_rng_result_84: Variant = _seed_util.get_branched_rng("loot")
	var snapshot: Dictionary = _seed_util.get_full_state()
	var expected_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var expected_value: int = expected_rng.randi()

	var _get_branched_rng_result_89: Variant = _seed_util.get_branched_rng("loot")
	_seed_util.set_full_state(snapshot)
	var restored_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")

	assert_eq(restored_rng.seed, expected_rng.seed, "完整状态应恢复每个标签的分支计数。")
	assert_eq(restored_rng.randi(), expected_value, "恢复完整状态后，后续子 RNG 序列应保持一致。")


func test_full_state_restores_deterministic_branch_counters() -> void:
	_seed_util.set_global_seed(13579)
	var _first_deterministic_rng: Variant = _seed_util.get_branched_deterministic_random("loot")
	var snapshot: Dictionary = _seed_util.get_full_state()
	var expected_rng: GF_DETERMINISTIC_RANDOM = _seed_util.get_branched_deterministic_random("loot")
	var expected_seed: int = expected_rng.get_initial_seed()
	var expected_value: int = expected_rng.next_u32()

	var _extra_deterministic_rng: Variant = _seed_util.get_branched_deterministic_random("loot")
	_seed_util.set_full_state(snapshot)
	var restored_rng: GF_DETERMINISTIC_RANDOM = _seed_util.get_branched_deterministic_random("loot")

	assert_eq(restored_rng.get_initial_seed(), expected_seed, "完整状态应恢复 deterministic 分支计数。")
	assert_eq(restored_rng.next_u32(), expected_value, "恢复完整状态后，deterministic 分支序列应保持一致。")


func test_full_state_rejects_future_schema_version_without_mutating_state() -> void:
	_seed_util.set_global_seed(13579)
	var snapshot: Dictionary = _seed_util.get_full_state()
	var original_seed: int = _seed_util.get_global_seed()
	var original_state: int = _seed_util.get_state()
	snapshot[&"state_schema_version"] = 99
	snapshot[&"global_seed"] = "24680"
	snapshot[&"rng_state"] = "123"

	_seed_util.set_full_state(snapshot)

	assert_push_error("[GFSeedUtility] 不支持的完整随机状态 schema 版本：99。")
	assert_eq(_seed_util.get_global_seed(), original_seed, "未来 schema 不应覆盖当前主种子。")
	assert_eq(_seed_util.get_state(), original_state, "未来 schema 不应覆盖当前 RNG 状态。")


func test_full_state_rejects_malformed_rng_state_without_mutating_state() -> void:
	_seed_util.set_global_seed(13579)
	var _branched_rng_result: Variant = _seed_util.get_branched_rng("loot")
	var original_snapshot: Dictionary = _seed_util.get_full_state()
	var expected_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var expected_seed: int = expected_rng.seed
	_seed_util.set_full_state(original_snapshot)
	var invalid_snapshot: Dictionary = original_snapshot.duplicate(true)
	invalid_snapshot[&"global_seed"] = "24680"
	invalid_snapshot[&"rng_state"] = "not-an-int"

	_seed_util.set_full_state(invalid_snapshot)
	var restored_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")

	assert_push_error("[GFSeedUtility] 无效完整随机状态：字段 rng_state 必须是整数或十进制整数字符串。")
	assert_eq(_seed_util.get_global_seed(), GFVariantData.get_option_int(original_snapshot, &"global_seed"), "非法 rng_state 不应覆盖当前主种子。")
	assert_eq(_seed_util.get_state(), GFVariantData.get_option_int(original_snapshot, &"rng_state"), "非法 rng_state 不应覆盖当前 RNG 状态。")
	assert_eq(restored_rng.seed, expected_seed, "非法 rng_state 不应重置分支计数。")


func test_full_state_rejects_malformed_branch_counter_without_mutating_state() -> void:
	_seed_util.set_global_seed(24680)
	var _branched_rng_result: Variant = _seed_util.get_branched_rng("loot")
	var original_snapshot: Dictionary = _seed_util.get_full_state()
	var expected_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var expected_seed: int = expected_rng.seed
	_seed_util.set_full_state(original_snapshot)
	var invalid_snapshot: Dictionary = original_snapshot.duplicate(true)
	var branch_counters: Dictionary = GFVariantData.get_option_dictionary(invalid_snapshot, &"branch_counters")
	branch_counters["loot"] = "bad"
	invalid_snapshot[&"branch_counters"] = branch_counters

	_seed_util.set_full_state(invalid_snapshot)
	var restored_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")

	assert_push_error("[GFSeedUtility] 无效完整随机状态：字段 branch_counters.loot 必须是整数或十进制整数字符串。")
	assert_eq(_seed_util.get_global_seed(), GFVariantData.get_option_int(original_snapshot, &"global_seed"), "非法分支计数不应覆盖当前主种子。")
	assert_eq(_seed_util.get_state(), GFVariantData.get_option_int(original_snapshot, &"rng_state"), "非法分支计数不应覆盖当前 RNG 状态。")
	assert_eq(restored_rng.seed, expected_seed, "非法分支计数不应改变下一次分支序列。")


func test_full_state_uses_json_safe_text_numbers() -> void:
	_seed_util.set_global_seed(9_223_372_036_854_775_000)
	var _get_branched_rng_result_99: Variant = _seed_util.get_branched_rng("loot")
	var _deterministic_rng_result: Variant = _seed_util.get_branched_deterministic_random("loot")

	var snapshot: Dictionary = _seed_util.get_full_state()
	var branch_counters: Dictionary = GFVariantData.get_option_dictionary(snapshot, &"branch_counters")
	var deterministic_branch_counters: Dictionary = GFVariantData.get_option_dictionary(snapshot, &"deterministic_branch_counters")

	assert_eq(GFVariantData.get_option_int(snapshot, &"state_schema_version"), 3, "完整状态 schema 应标记当前版本。")
	assert_false(snapshot.has(&"version"), "完整状态不应使用含义模糊的 version 字段。")
	assert_eq(typeof(GFVariantData.get_option_value(snapshot, &"global_seed")), TYPE_STRING, "主种子应以文本保存，避免 JSON 精度丢失。")
	assert_eq(typeof(GFVariantData.get_option_value(snapshot, &"rng_state")), TYPE_STRING, "RNG 状态应以文本保存，避免 JSON 精度丢失。")
	assert_eq(typeof(GFVariantData.get_option_value(branch_counters, "loot")), TYPE_STRING, "分支计数应以文本保存，保证完整状态全量 JSON 安全。")
	assert_eq(typeof(GFVariantData.get_option_value(deterministic_branch_counters, "loot")), TYPE_STRING, "deterministic 分支计数应以文本保存，保证完整状态全量 JSON 安全。")
	assert_false(snapshot.has(&"rng_state_text"), "完整状态不应输出重复的兼容字段。")


func test_full_state_roundtrips_through_json_with_large_64_bit_values() -> void:
	var large_seed: int = 9_223_372_036_854_775_000
	_seed_util.set_global_seed(large_seed)
	var _randi_result_115: Variant = _seed_util.get_rng().randi()
	var _get_branched_rng_result_116: Variant = _seed_util.get_branched_rng("loot")
	var snapshot: Dictionary = _seed_util.get_full_state()
	var expected_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")
	var expected_rng_seed: int = expected_rng.seed
	var expected_rng_value: int = expected_rng.randi()
	var expected_next_main: int = _seed_util.get_rng().randi()
	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(JSON.stringify(snapshot)))

	_seed_util.set_global_seed(1)
	var _get_branched_rng_result_125: Variant = _seed_util.get_branched_rng("loot")
	_seed_util.set_full_state(parsed)
	var restored_rng: RandomNumberGenerator = _seed_util.get_branched_rng("loot")

	assert_eq(_seed_util.get_global_seed(), large_seed, "JSON 往返后应精确恢复 64 位主种子。")
	assert_eq(restored_rng.seed, expected_rng_seed, "JSON 往返后应精确恢复分支计数与分支种子。")
	assert_eq(restored_rng.randi(), expected_rng_value, "JSON 往返后分支 RNG 序列应保持一致。")
	assert_eq(_seed_util.get_rng().randi(), expected_next_main, "JSON 往返后主 RNG 序列应保持一致。")


func test_full_state_json_text_is_stable_for_equivalent_branch_counters() -> void:
	var first_seed_util: GFSeedUtility = GFSeedUtility.new()
	var second_seed_util: GFSeedUtility = GFSeedUtility.new()
	first_seed_util.init()
	second_seed_util.init()
	first_seed_util.set_global_seed(123)
	second_seed_util.set_global_seed(123)

	var _first_a: Variant = first_seed_util.get_branched_rng("a")
	var _first_b: Variant = first_seed_util.get_branched_rng("b")
	var _first_det_a: Variant = first_seed_util.get_branched_deterministic_random("a")
	var _first_det_b: Variant = first_seed_util.get_branched_deterministic_random("b")
	var _second_b: Variant = second_seed_util.get_branched_rng("b")
	var _second_a: Variant = second_seed_util.get_branched_rng("a")
	var _second_det_b: Variant = second_seed_util.get_branched_deterministic_random("b")
	var _second_det_a: Variant = second_seed_util.get_branched_deterministic_random("a")

	assert_eq(
		JSON.stringify(first_seed_util.get_full_state()),
		JSON.stringify(second_seed_util.get_full_state()),
		"分支计数导出应按 key 排序，语义相同的完整状态应得到稳定 JSON 文本。"
	)
