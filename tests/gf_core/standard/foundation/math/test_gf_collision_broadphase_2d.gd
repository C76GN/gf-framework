## 测试 GFCollisionBroadphase2D 的 AABB body、SAP、Quadtree 和组合候选对。
extends GutTest


# --- 常量 ---

const GF_COLLISION_BROADPHASE_2D = preload("res://addons/gf/standard/foundation/math/gf_collision_broadphase_2d.gd")
const GF_DETERMINISTIC_RANDOM = preload("res://addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd")


# --- 测试 ---

func test_make_body_normalizes_negative_bounds_and_copies_metadata() -> void:
	var metadata: Dictionary = { "team": "red" }
	var body: Dictionary = GF_COLLISION_BROADPHASE_2D.make_body(
		"unit",
		Rect2(Vector2(10.0, 10.0), Vector2(-4.0, -6.0)),
		2,
		4,
		true,
		metadata
	)
	metadata["team"] = "blue"

	assert_eq(GFVariantData.get_option_string(body, "entity"), "unit")
	assert_eq(_body_bounds(body), Rect2(Vector2(6.0, 4.0), Vector2(4.0, 6.0)))
	assert_eq(GFVariantData.get_option_int(body, "collision_layer"), 2)
	assert_eq(GFVariantData.get_option_int(body, "collision_mask"), 4)
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(body, "metadata"), "team"), "red")


func test_bruteforce_filters_disabled_and_collision_masks() -> void:
	var bodies: Array = [
		GF_COLLISION_BROADPHASE_2D.make_body("a", Rect2(0, 0, 4, 4), 1, 2),
		GF_COLLISION_BROADPHASE_2D.make_body("b", Rect2(3, 0, 4, 4), 2, 1),
		GF_COLLISION_BROADPHASE_2D.make_body("masked", Rect2(2, 0, 4, 4), 4, 8),
		GF_COLLISION_BROADPHASE_2D.make_body("disabled", Rect2(1, 1, 2, 2), 1, 2, false),
	]

	var pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_2D.find_pairs_bruteforce(bodies)

	assert_eq(_pair_keys(pairs), ["a:b"], "候选对应同时满足 AABB 相交、启用状态和双向 layer/mask。")


func test_include_touching_controls_edge_contact_pairs() -> void:
	var bodies: Array = [
		GF_COLLISION_BROADPHASE_2D.make_body("left", Rect2(0, 0, 1, 1)),
		GF_COLLISION_BROADPHASE_2D.make_body("right", Rect2(1, 0, 1, 1)),
	]

	var default_pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_2D.find_pairs_bruteforce(bodies)
	var touching_pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_2D.find_pairs_bruteforce(
		bodies,
		{ "include_touching": true }
	)

	assert_true(default_pairs.is_empty(), "默认不把仅边界相切视为重叠候选对。")
	assert_eq(_pair_keys(touching_pairs), ["left:right"], "显式开启 include_touching 后应包含边界相切对。")


func test_sap_matches_bruteforce_pairs_in_stable_order() -> void:
	var bodies: Array = _make_overlap_fixture_2d()
	var brute_keys: Array[String] = _pair_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_bruteforce(bodies))
	var sap_keys: Array[String] = _pair_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_sap(bodies))

	assert_eq(sap_keys, brute_keys, "SAP 结果应与暴力枚举 oracle 一致。")


func test_quadtree_matches_bruteforce_and_deduplicates_spanning_bodies() -> void:
	var bodies: Array = [
		GF_COLLISION_BROADPHASE_2D.make_body("large", Rect2(0, 0, 60, 60)),
		GF_COLLISION_BROADPHASE_2D.make_body("corner", Rect2(50, 50, 20, 20)),
		GF_COLLISION_BROADPHASE_2D.make_body("far", Rect2(120, 120, 10, 10)),
		GF_COLLISION_BROADPHASE_2D.make_body("edge", Rect2(58, 5, 10, 10)),
	]
	var options: Dictionary = {
		"world_bounds": Rect2(0, 0, 160, 160),
		"quadtree_capacity": 1,
		"quadtree_max_depth": 5,
	}

	var brute_keys: Array[String] = _pair_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_bruteforce(bodies, options))
	var quadtree_keys: Array[String] = _pair_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_quadtree(bodies, options))

	assert_eq(quadtree_keys, brute_keys, "Quadtree broadphase 不应漏掉跨象限 body，也不应重复返回 pair。")


func test_seeded_broadphase_algorithms_match_bruteforce_oracle() -> void:
	var bodies: Array = _make_seeded_broadphase_fixture_2d()
	var options: Dictionary = {
		"world_bounds": Rect2(0, 0, 128, 128),
		"quadtree_capacity": 4,
		"quadtree_max_depth": 6,
		"include_touching": true,
	}
	var auto_options: Dictionary = options.duplicate(true)
	auto_options["bruteforce_threshold"] = 4
	auto_options["quadtree_threshold"] = 16

	var brute_keys: Array[String] = _pair_index_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_bruteforce(bodies, options))
	var sap_keys: Array[String] = _pair_index_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_sap(bodies, options))
	var quadtree_keys: Array[String] = _pair_index_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_quadtree(bodies, options))
	var auto_keys: Array[String] = _pair_index_keys(GF_COLLISION_BROADPHASE_2D.find_pairs_combined(bodies, auto_options))

	assert_eq(sap_keys, brute_keys, "seeded fixture 中 SAP 应与暴力枚举 oracle 一致。")
	assert_eq(quadtree_keys, brute_keys, "seeded fixture 中 Quadtree 应与暴力枚举 oracle 一致。")
	assert_eq(auto_keys, brute_keys, "seeded fixture 中 auto 选择的算法应与暴力枚举 oracle 一致。")
	assert_true(brute_keys.has("70:71"), "include_touching 应让 world_bounds 外的相切 body pair 进入 oracle。")


func test_combined_report_can_force_algorithm_and_limits_pairs() -> void:
	var bodies: Array = _make_overlap_fixture_2d()
	var report: Dictionary = GF_COLLISION_BROADPHASE_2D.build_pair_report(
		bodies,
		{
			"algorithm": GF_COLLISION_BROADPHASE_2D.ALGORITHM_SAP,
			"max_pairs": 1,
		}
	)
	var pairs: Array = GFVariantData.get_option_array(report, "pairs")

	assert_eq(GFVariantData.get_option_string_name(report, "algorithm"), GF_COLLISION_BROADPHASE_2D.ALGORITHM_SAP)
	assert_eq(GFVariantData.get_option_int(report, "body_count"), bodies.size())
	assert_eq(GFVariantData.get_option_int(report, "pair_count"), 1)
	assert_eq(pairs.size(), 1, "max_pairs 应限制报告中的候选对数量。")


func _make_overlap_fixture_2d() -> Array:
	return [
		GF_COLLISION_BROADPHASE_2D.make_body("c", Rect2(10, 0, 2, 2)),
		GF_COLLISION_BROADPHASE_2D.make_body("a", Rect2(0, 0, 4, 4)),
		GF_COLLISION_BROADPHASE_2D.make_body("b", Rect2(3, 1, 4, 2)),
		GF_COLLISION_BROADPHASE_2D.make_body("d", Rect2(12, 0, 2, 2)),
	]


func _make_seeded_broadphase_fixture_2d() -> Array:
	var random: GF_DETERMINISTIC_RANDOM = GF_DETERMINISTIC_RANDOM.from_seed(2_026_060_9)
	var bodies: Array = []
	for index: int in range(70):
		var x: float = float(random.next_int_range(-8, 120))
		var y: float = float(random.next_int_range(-8, 120))
		var width: float = float(random.next_int_range(3, 18))
		var height: float = float(random.next_int_range(3, 18))
		var entity: String = "duplicate" if index % 17 == 0 else "body_%02d" % index
		bodies.append(GF_COLLISION_BROADPHASE_2D.make_body(entity, Rect2(x, y, width, height)))
	bodies.append(GF_COLLISION_BROADPHASE_2D.make_body("touch_a", Rect2(130, 0, 5, 5)))
	bodies.append(GF_COLLISION_BROADPHASE_2D.make_body("touch_b", Rect2(135, 0, 5, 5)))
	bodies.append(GF_COLLISION_BROADPHASE_2D.make_body("spanning", Rect2(40, 40, 70, 70)))
	bodies.append(GF_COLLISION_BROADPHASE_2D.make_body("inside_spanning", Rect2(60, 60, 6, 6)))
	return bodies


func _pair_keys(pairs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for pair: Dictionary in pairs:
		result.append("%s:%s" % [
			GFVariantData.get_option_string(pair, "a"),
			GFVariantData.get_option_string(pair, "b"),
		])
	result.sort()
	return result


func _pair_index_keys(pairs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for pair: Dictionary in pairs:
		result.append("%d:%d" % [
			GFVariantData.get_option_int(pair, "a_index"),
			GFVariantData.get_option_int(pair, "b_index"),
		])
	result.sort()
	return result


func _body_bounds(body: Dictionary) -> Rect2:
	var value: Variant = GFVariantData.get_option_value(body, "bounds")
	if value is Rect2:
		var bounds: Rect2 = value
		return bounds
	return Rect2()
