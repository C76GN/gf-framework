## 测试 GFDeterministicRandom 的 golden 序列、状态恢复和范围采样。
extends GutTest


# --- 常量 ---

const GF_DETERMINISTIC_RANDOM = preload("res://addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd")


# --- 测试 ---

func test_seed_42_matches_golden_u32_sequence() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	var values: Array[int] = []
	for _index: int in range(10):
		values.append(rng.next_u32())

	assert_eq(values, [
		11_355_432,
		2_836_018_348,
		476_557_059,
		3_648_046_016,
		3_759_983_556,
		1_441_438_134,
		3_713_466_840,
		2_431_644_334,
		3_120_216_979,
		1_067_267_639,
	])
	assert_eq(rng.get_state(), 1_067_267_639)


func test_seed_1_matches_golden_u32_sequence() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(1)
	var values: Array[int] = []
	for _index: int in range(10):
		values.append(rng.next_u32())

	assert_eq(values, [
		270_369,
		67_634_689,
		2_647_435_461,
		307_599_695,
		2_398_689_233,
		745_495_504,
		632_435_482,
		435_756_210,
		2_005_365_029,
		2_916_098_932,
	])


func test_zero_seed_maps_to_stable_default_seed() -> void:
	var zero_seed_rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(0)
	var default_seed_rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.new()

	assert_eq(zero_seed_rng.get_initial_seed(), default_seed_rng.get_initial_seed())
	assert_eq(zero_seed_rng.next_u32(), default_seed_rng.next_u32())


func test_state_roundtrip_continues_same_sequence() -> void:
	var source: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	for _index: int in range(5):
		var _discarded: int = source.next_u32()

	var restored: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_dict(source.to_dict())

	assert_eq(restored.get_initial_seed(), source.get_initial_seed())
	assert_eq(restored.get_state(), source.get_state())
	assert_eq(restored.next_u32(), source.next_u32())


func test_set_state_rejects_zero_state() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	var previous_state: int = rng.get_state()

	var changed: bool = rng.set_state(0)

	assert_false(changed)
	assert_push_error("[GFDeterministicRandom] xorshift32 状态不能为 0。")
	assert_eq(rng.get_state(), previous_state)


func test_int_range_matches_golden_sequence() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	var values: Array[int] = []
	for _index: int in range(12):
		values.append(rng.next_int_range(10, 20))

	assert_eq(values, [10, 19, 10, 20, 20, 14, 16, 19, 10, 19, 13, 16])


func test_float_unit_matches_scaled_u32_golden_sequence() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	assert_almost_eq(rng.next_float_unit(), 0.0026438925, 0.0000000001)
	assert_almost_eq(rng.next_float_unit(), 0.6603119774, 0.0000000001)
	assert_almost_eq(rng.next_float_unit(), 0.1109570868, 0.0000000001)


func test_float_range_uses_fixed_u32_sequence_and_swaps_bounds() -> void:
	var forward: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	var reversed: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	assert_almost_eq(forward.next_float_range(5.0, 8.0), 5.0079316776, 0.0000000001)
	assert_almost_eq(reversed.next_float_range(8.0, 5.0), 5.0079316776, 0.0000000001)


func test_float_range_rejects_non_finite_bounds() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	var value: float = rng.next_float_range(NAN, 1.0)

	assert_eq(value, 0.0)
	assert_push_error("[GFDeterministicRandom] next_float_range 只支持有限浮点边界。")


func test_skip_matches_manual_consumption() -> void:
	var skipped: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	var manual: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	skipped.skip(7)
	for _index: int in range(7):
		var _discarded: int = manual.next_u32()

	assert_eq(skipped.get_state(), manual.get_state())
	assert_eq(skipped.next_u32(), manual.next_u32())


func test_fork_is_stable_and_does_not_advance_parent() -> void:
	var parent_a: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)
	var parent_b: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	var child_a: GF_DETERMINISTIC_RANDOM = parent_a.fork(7)
	var child_b: GF_DETERMINISTIC_RANDOM = parent_b.fork(7)
	var other_child: GF_DETERMINISTIC_RANDOM = parent_b.fork(8)

	assert_eq(parent_a.get_state(), parent_b.get_state())
	assert_eq(child_a.get_initial_seed(), child_b.get_initial_seed())
	assert_eq(child_a.next_u32(), child_b.next_u32())
	assert_ne(child_a.get_initial_seed(), other_child.get_initial_seed())


func test_apply_dict_rejects_unknown_algorithm() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	var applied: bool = rng.apply_dict({
		"algorithm": "other",
		"version": 1,
		"seed": 42,
		"state": 42,
	})

	assert_false(applied)
	assert_push_error("[GFDeterministicRandom] 不支持的状态字典格式。")
	assert_eq(rng.get_initial_seed(), GF_DETERMINISTIC_RANDOM.new().get_initial_seed())
	assert_eq(rng.get_state(), GF_DETERMINISTIC_RANDOM.new().get_state())


func test_apply_dict_rejects_zero_state() -> void:
	var rng: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(42)

	var applied: bool = rng.apply_dict({
		"algorithm": "xorshift32",
		"version": 1,
		"seed": 42,
		"state": 0,
	})

	assert_false(applied)
	assert_push_error("[GFDeterministicRandom] xorshift32 状态不能为 0。")
	assert_eq(rng.get_initial_seed(), GF_DETERMINISTIC_RANDOM.new().get_initial_seed())
	assert_eq(rng.get_state(), GF_DETERMINISTIC_RANDOM.new().get_state())
