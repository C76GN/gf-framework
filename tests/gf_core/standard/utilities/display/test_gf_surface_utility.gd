## 测试 GFSurfaceUtility 的 face index 到 Mesh surface/材质映射。
extends GutTest

func test_surface_index_maps_across_mesh_surfaces() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)

	assert_eq(utility.get_surface_index(mesh_instance, 0), 0, "第一个三角面应映射到 surface 0。")
	assert_eq(utility.get_surface_index(mesh_instance, 1), 1, "第二个三角面应映射到 surface 1。")
	assert_eq(utility.get_surface_index(mesh_instance, 2), -1, "超出范围的 face index 应返回 -1。")


func test_surface_index_maps_unindexed_mesh_surfaces() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance(false)
	add_child_autofree(mesh_instance)

	assert_eq(utility.get_surface_index(mesh_instance, 0), 0, "无索引 surface 的第一个三角面应映射到 surface 0。")
	assert_eq(utility.get_surface_index(mesh_instance, 1), 1, "无索引 surface 的第二个三角面应映射到 surface 1。")
	assert_eq(utility.get_surface_index(mesh_instance, 2), -1, "无索引 surface 超出范围时应返回 -1。")


func test_surface_utility_returns_base_override_and_active_materials() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)
	var base_material: Material = mesh_instance.mesh.surface_get_material(1)
	var override_material: StandardMaterial3D = StandardMaterial3D.new()
	mesh_instance.set_surface_override_material(1, override_material)

	assert_eq(utility.get_base_material(mesh_instance, 1), base_material, "base material 应来自 Mesh surface。")
	assert_eq(utility.get_surface_override_material(mesh_instance, 1), override_material, "override material 应来自 MeshInstance3D。")
	assert_eq(utility.get_active_material(mesh_instance, 1), override_material, "active material 应返回最终渲染材质。")


func test_surface_utility_describes_surface_hit_report() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)
	var base_material: Material = mesh_instance.mesh.surface_get_material(1)
	var override_material: StandardMaterial3D = StandardMaterial3D.new()
	override_material.resource_name = "surface_override"
	mesh_instance.set_surface_override_material(1, override_material)

	var report: Dictionary = utility.describe_surface_hit(mesh_instance, 1)
	var reported_base_material: Material = _get_report_material(report, "base_material")
	var reported_override_material: Material = _get_report_material(report, "override_material")
	var reported_active_material: Material = _get_report_material(report, "active_material")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效命中报告应标记 ok。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "", "成功报告不应带失败原因。")
	assert_eq(GFVariantData.get_option_int(report, "face_index"), 1, "报告应保留输入 face index。")
	assert_eq(GFVariantData.get_option_int(report, "surface_index"), 1, "报告应保留 surface index。")
	assert_eq(reported_base_material, base_material, "报告应保留 base material 引用。")
	assert_eq(GFVariantData.get_option_string(report, "base_material_name"), "surface_blue", "报告应保留 base material 名称。")
	assert_true(GFVariantData.get_option_bool(report, "has_base_material"), "报告应标记 base material 存在。")
	assert_eq(reported_override_material, override_material, "报告应保留 override material 引用。")
	assert_eq(GFVariantData.get_option_string(report, "override_material_name"), "surface_override", "报告应保留 override material 名称。")
	assert_true(GFVariantData.get_option_bool(report, "has_override_material"), "报告应标记 override material 存在。")
	assert_eq(reported_active_material, override_material, "active material 应反映最终渲染材质。")
	assert_eq(GFVariantData.get_option_string(report, "active_material_name"), "surface_override", "报告应保留 active material 名称。")
	assert_true(GFVariantData.get_option_bool(report, "has_active_material"), "报告应标记 active material 存在。")


func test_surface_utility_describes_invalid_surface_hit_report() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)

	var report: Dictionary = utility.describe_surface_hit(mesh_instance, 2)
	var reported_active_material: Material = _get_report_material(report, "active_material")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效命中报告不应标记 ok。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "surface_not_found", "失败报告应说明 surface 未命中。")
	assert_eq(GFVariantData.get_option_int(report, "face_index"), 2, "失败报告应保留输入 face index。")
	assert_eq(GFVariantData.get_option_int(report, "surface_index"), -1, "无效命中 surface index 应为 -1。")
	assert_eq(reported_active_material, null, "失败报告不应携带 active material。")
	assert_false(GFVariantData.get_option_bool(report, "has_active_material"), "失败报告应标记 active material 不存在。")


func test_surface_utility_resolves_mesh_from_collision_sibling() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var root: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	var collider: StaticBody3D = StaticBody3D.new()
	root.add_child(mesh_instance)
	root.add_child(collider)
	add_child_autofree(root)

	assert_eq(utility.get_surface_index(collider, 1), 1, "传入碰撞体时应能解析同级 MeshInstance3D。")


func test_surface_utility_cache_can_be_cleared() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)

	var _get_surface_index_result_54: Variant = utility.get_surface_index(mesh_instance, 0)
	assert_eq(_cached_meshes(utility), 1, "查询后应缓存 Mesh surface 面数。")

	utility.clear_cache()

	assert_eq(_cached_meshes(utility), 0, "clear_cache 后缓存应为空。")


func test_surface_utility_can_prewarm_manual_cache() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)
	utility.cache_mode = GFSurfaceUtility.CacheMode.MANUAL

	assert_true(utility.cache_mesh_surface(mesh_instance), "手动缓存模式应允许显式预热 Mesh surface。")
	assert_eq(_cached_meshes(utility), 1, "预热后应记录缓存 Mesh。")

	assert_true(utility.erase_cached_mesh(mesh_instance), "应能移除指定 Mesh 缓存。")
	assert_eq(_cached_meshes(utility), 0, "移除后缓存应为空。")


func test_surface_utility_auto_cache_respects_capacity() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	utility.set_auto_cache_size(1)
	var first_mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	var second_mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(first_mesh_instance)
	add_child_autofree(second_mesh_instance)

	var _get_surface_index_result_83: Variant = utility.get_surface_index(first_mesh_instance, 0)
	var _get_surface_index_result_84: Variant = utility.get_surface_index(second_mesh_instance, 0)

	assert_eq(_cached_meshes(utility), 1, "自动缓存应按容量裁剪旧 Mesh。")


func test_surface_utility_refreshes_cached_face_counts_when_mesh_surfaces_change() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)

	assert_eq(utility.get_surface_index(mesh_instance, 1), 1, "初始第二个三角面应映射到 surface 1。")
	assert_eq(_cached_meshes(utility), 1, "初次查询应建立缓存。")

	var array_mesh: ArrayMesh = _array_mesh(mesh_instance.mesh)
	_add_triangle_surface(array_mesh, Vector3(8.0, 0.0, 0.0), _make_material(Color.GREEN, "surface_green"))

	assert_eq(utility.get_surface_index(mesh_instance, 2), 2, "同一 Mesh RID 增加 surface 后应自动刷新缓存。")
	assert_eq(_cached_meshes(utility), 1, "刷新后仍应只保留同一个 Mesh 缓存项。")


func test_surface_utility_disabled_cache_does_not_store() -> void:
	var utility: GFSurfaceUtility = GFSurfaceUtility.new()
	var mesh_instance: MeshInstance3D = _make_two_surface_mesh_instance()
	add_child_autofree(mesh_instance)
	utility.cache_mode = GFSurfaceUtility.CacheMode.DISABLED

	var _get_surface_index_result_95: Variant = utility.get_surface_index(mesh_instance, 0)

	assert_eq(_cached_meshes(utility), 0, "禁用缓存时查询不应写入缓存。")
	assert_false(utility.cache_mesh_surface(mesh_instance), "禁用缓存时显式预热应返回 false。")


func _make_two_surface_mesh_instance(use_indices: bool = true) -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	_add_triangle_surface(mesh, Vector3.ZERO, _make_material(Color.RED, "surface_red"), use_indices)
	_add_triangle_surface(mesh, Vector3(4.0, 0.0, 0.0), _make_material(Color.BLUE, "surface_blue"), use_indices)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	return mesh_instance


func _add_triangle_surface(mesh: ArrayMesh, offset: Vector3, material: Material, use_indices: bool = true) -> void:
	var arrays: Array = []
	var _resize_error: int = arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		offset + Vector3(0.0, 0.0, 0.0),
		offset + Vector3(1.0, 0.0, 0.0),
		offset + Vector3(0.0, 1.0, 0.0),
	])
	if use_indices:
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func _make_material(color: Color, resource_name: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.resource_name = resource_name
	return material


func _cached_meshes(utility: GFSurfaceUtility) -> int:
	return GFVariantData.get_option_int(utility.get_debug_snapshot(), "cached_meshes")


func _array_mesh(mesh: Mesh) -> ArrayMesh:
	if mesh is ArrayMesh:
		var array_mesh: ArrayMesh = mesh
		return array_mesh
	return null


func _get_report_material(report: Dictionary, key: String) -> Material:
	var value: Variant = report.get(key)
	if value is Material:
		var material: Material = value
		return material
	return null
