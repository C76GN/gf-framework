## 测试 GFCollisionBroadphase3D 的 AABB body、SAP 和组合候选对。
extends GutTest


# --- 常量 ---

const GF_COLLISION_BROADPHASE_3D = preload("res://addons/gf/standard/foundation/math/gf_collision_broadphase_3d.gd")


# --- 测试 ---

func test_make_body_normalizes_negative_bounds_and_copies_metadata() -> void:
	var metadata: Dictionary = { "team": "red" }
	var body: Dictionary = GF_COLLISION_BROADPHASE_3D.make_body(
		"unit",
		AABB(Vector3(10.0, 10.0, 10.0), Vector3(-4.0, -6.0, -8.0)),
		2,
		4,
		true,
		metadata
	)
	metadata["team"] = "blue"

	assert_eq(GFVariantData.get_option_string(body, "entity"), "unit")
	assert_eq(_body_bounds(body), AABB(Vector3(6.0, 4.0, 2.0), Vector3(4.0, 6.0, 8.0)))
	assert_eq(GFVariantData.get_option_int(body, "collision_layer"), 2)
	assert_eq(GFVariantData.get_option_int(body, "collision_mask"), 4)
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(body, "metadata"), "team"), "red")


func test_bruteforce_filters_disabled_and_collision_masks() -> void:
	var bodies: Array = [
		GF_COLLISION_BROADPHASE_3D.make_body("a", AABB(Vector3.ZERO, Vector3(4.0, 4.0, 4.0)), 1, 2),
		GF_COLLISION_BROADPHASE_3D.make_body("b", AABB(Vector3(3.0, 0.0, 0.0), Vector3(4.0, 4.0, 4.0)), 2, 1),
		GF_COLLISION_BROADPHASE_3D.make_body("masked", AABB(Vector3(2.0, 0.0, 0.0), Vector3(4.0, 4.0, 4.0)), 4, 8),
		GF_COLLISION_BROADPHASE_3D.make_body("disabled", AABB(Vector3.ONE, Vector3.ONE), 1, 2, false),
	]

	var pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_3D.find_pairs_bruteforce(bodies)

	assert_eq(_pair_keys(pairs), ["a:b"], "候选对应同时满足 AABB 相交、启用状态和双向 layer/mask。")


func test_include_touching_controls_face_contact_pairs() -> void:
	var bodies: Array = [
		GF_COLLISION_BROADPHASE_3D.make_body("left", AABB(Vector3.ZERO, Vector3.ONE)),
		GF_COLLISION_BROADPHASE_3D.make_body("right", AABB(Vector3(1.0, 0.0, 0.0), Vector3.ONE)),
	]

	var default_pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_3D.find_pairs_bruteforce(bodies)
	var touching_pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_3D.find_pairs_bruteforce(
		bodies,
		{ "include_touching": true }
	)

	assert_true(default_pairs.is_empty(), "默认不把仅面相切视为重叠候选对。")
	assert_eq(_pair_keys(touching_pairs), ["left:right"], "显式开启 include_touching 后应包含面相切对。")


func test_sap_matches_bruteforce_pairs_in_stable_order() -> void:
	var bodies: Array = _make_overlap_fixture_3d()
	var brute_keys: Array[String] = _pair_keys(GF_COLLISION_BROADPHASE_3D.find_pairs_bruteforce(bodies))
	var sap_keys: Array[String] = _pair_keys(GF_COLLISION_BROADPHASE_3D.find_pairs_sap(bodies))

	assert_eq(sap_keys, brute_keys, "3D SAP 结果应与暴力枚举 oracle 一致。")


func test_combined_report_can_force_algorithm_and_limits_pairs() -> void:
	var bodies: Array = _make_overlap_fixture_3d()
	var report: Dictionary = GF_COLLISION_BROADPHASE_3D.build_pair_report(
		bodies,
		{
			"algorithm": GF_COLLISION_BROADPHASE_3D.ALGORITHM_SAP,
			"max_pairs": 1,
		}
	)
	var pairs: Array = GFVariantData.get_option_array(report, "pairs")

	assert_eq(GFVariantData.get_option_string_name(report, "algorithm"), GF_COLLISION_BROADPHASE_3D.ALGORITHM_SAP)
	assert_eq(GFVariantData.get_option_int(report, "body_count"), bodies.size())
	assert_eq(GFVariantData.get_option_int(report, "pair_count"), 1)
	assert_eq(pairs.size(), 1, "max_pairs 应限制报告中的候选对数量。")


func test_auto_combined_uses_bruteforce_for_small_sets_and_sap_for_large_sets() -> void:
	var small_report: Dictionary = GF_COLLISION_BROADPHASE_3D.build_pair_report(_make_overlap_fixture_3d())
	var large_bodies: Array = []
	for index: int in range(32):
		large_bodies.append(GF_COLLISION_BROADPHASE_3D.make_body(
			"body_%d" % index,
			AABB(Vector3(float(index) * 4.0, 0.0, 0.0), Vector3.ONE)
		))
	var large_report: Dictionary = GF_COLLISION_BROADPHASE_3D.build_pair_report(large_bodies)

	assert_eq(
		GFVariantData.get_option_string_name(small_report, "algorithm"),
		GF_COLLISION_BROADPHASE_3D.ALGORITHM_BRUTE_FORCE
	)
	assert_eq(
		GFVariantData.get_option_string_name(large_report, "algorithm"),
		GF_COLLISION_BROADPHASE_3D.ALGORITHM_SAP
	)


func test_non_finite_bodies_are_rejected_before_sorting() -> void:
	var invalid_body: Dictionary = GF_COLLISION_BROADPHASE_3D.make_body(
		"invalid",
		AABB(Vector3(NAN, 0.0, 0.0), Vector3.ONE)
	)
	var bodies: Array = [
		{ "entity": "manual-invalid", "bounds": AABB(Vector3.ZERO, Vector3(INF, 1.0, 1.0)) },
		GF_COLLISION_BROADPHASE_3D.make_body("valid", AABB(Vector3.ZERO, Vector3.ONE)),
	]

	assert_true(invalid_body.is_empty(), "make_body 应显式拒绝非有限 bounds。")
	assert_true(GF_COLLISION_BROADPHASE_3D.find_pairs_sap(bodies).is_empty(), "手工构造的非法 body 也应在排序前被过滤。")


func test_pair_report_has_json_compatible_export() -> void:
	var report: Dictionary = GF_COLLISION_BROADPHASE_3D.build_pair_report(_make_overlap_fixture_3d())
	var safe_report: Dictionary = GF_COLLISION_BROADPHASE_3D.to_json_compatible_report(report)
	var json_text: String = JSON.stringify(safe_report)

	assert_false(json_text.is_empty())
	assert_false(json_text.contains(":null"), "JSON-safe broadphase 报告不得依赖 AABB 降级。")
	assert_false(json_text.contains("NaN"))
	assert_false(json_text.contains("Infinity"))


func _make_overlap_fixture_3d() -> Array:
	return [
		GF_COLLISION_BROADPHASE_3D.make_body("c", AABB(Vector3(10.0, 0.0, 0.0), Vector3(2.0, 2.0, 2.0))),
		GF_COLLISION_BROADPHASE_3D.make_body("a", AABB(Vector3.ZERO, Vector3(4.0, 4.0, 4.0))),
		GF_COLLISION_BROADPHASE_3D.make_body("b", AABB(Vector3(3.0, 1.0, 1.0), Vector3(4.0, 2.0, 2.0))),
		GF_COLLISION_BROADPHASE_3D.make_body("d", AABB(Vector3(12.0, 0.0, 0.0), Vector3(2.0, 2.0, 2.0))),
	]


func _pair_keys(pairs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for pair: Dictionary in pairs:
		result.append("%s:%s" % [
			GFVariantData.get_option_string(pair, "a"),
			GFVariantData.get_option_string(pair, "b"),
		])
	result.sort()
	return result


func _body_bounds(body: Dictionary) -> AABB:
	var value: Variant = GFVariantData.get_option_value(body, "bounds")
	if value is AABB:
		var bounds: AABB = value
		return bounds
	return AABB()
