## 测试 GFRenderWarmupUtility 的清单预热与节点树资源收集。
extends GutTest


# --- 测试方法 ---

## 验证预热清单可以立即处理材质资源并保留缓存。
func test_render_warmup_manifest_processes_material_resource() -> void:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	manifest.manifest_id = &"test"
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var _add_resource_result_12: Variant = manifest.add_resource(material, &"material", { "label": "red" })
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var summary: Dictionary = utility.warmup_manifest_now(manifest)

	assert_true(GFVariantData.get_option_bool(summary, "ok"), "材质资源预热应成功。")
	assert_eq(GFVariantData.get_option_int(summary, "processed_count"), 1, "应处理一个条目。")
	assert_eq(utility.get_cached_resource_count(), 1, "默认应缓存已预热资源引用。")


## 验证通过路径加载的预热资源也会保留缓存引用。
func test_render_warmup_caches_resource_loaded_from_path() -> void:
	var resource_path: String = "user://gf_render_warmup_cache_material.tres"
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var _save_result: Error = ResourceSaver.save(material, resource_path)
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_path_result: Variant = manifest.add_resource_path(resource_path, &"material", "StandardMaterial3D")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var summary: Dictionary = utility.warmup_manifest_now(manifest)

	if FileAccess.file_exists(resource_path):
		var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))

	assert_eq(_save_result, OK, "测试材质资源应可保存到 user://。")
	assert_true(GFVariantData.get_option_bool(summary, "ok"), "路径资源预热应成功。")
	assert_eq(utility.get_cached_resource_count(), 1, "路径加载资源应进入预热缓存。")


## 验证 Utility 可以从节点树收集 Mesh 与材质资源。
func test_render_warmup_builds_manifest_from_mesh_tree() -> void:
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()
	var mesh_instance: MeshInstance3D = _make_mesh_instance()
	add_child_autofree(mesh_instance)

	var manifest: GFRenderWarmupManifest = utility.build_manifest_from_tree(mesh_instance, { "manifest_id": &"tree" })
	var description: Dictionary = manifest.describe()

	assert_eq(GFVariantData.get_option_string_name(description, "manifest_id"), &"tree", "收集清单应保留 manifest_id。")
	assert_gt(GFVariantData.get_option_int(description, "entry_count"), 1, "MeshInstance3D 应贡献 Mesh 和材质资源。")


## 验证队列按预算分批处理。
func test_render_warmup_queue_respects_entry_budget() -> void:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_resource_result_38: Variant = manifest.add_resource(StandardMaterial3D.new(), &"material")
	var _add_resource_result_39: Variant = manifest.add_resource(StandardMaterial3D.new(), &"material")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()
	var _queue_manifest_result_41: Variant = utility.queue_manifest(manifest)

	var first_count: int = utility.process_queue(1)
	var second_count: int = utility.process_queue(1)

	assert_eq(first_count, 1, "第一次只应处理一个条目。")
	assert_eq(second_count, 1, "第二次处理剩余条目。")
	assert_eq(utility.get_queue_size(), 0, "全部处理后队列应为空。")


## 验证离屏临时渲染节点模式会创建并释放临时节点。
func test_render_warmup_temporary_render_nodes_can_be_released() -> void:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_resource_result_54: Variant = manifest.add_resource(StandardMaterial3D.new(), &"material")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var summary: Dictionary = utility.warmup_manifest_now(manifest, {
		"touch_mode": GFRenderWarmupUtility.TouchMode.TEMPORARY_RENDER_NODES,
		"temporary_parent": self,
	})

	assert_true(GFVariantData.get_option_bool(summary, "ok"), "临时渲染节点预热应完成。")
	assert_gt(GFVariantData.get_option_int(summary, "processed_count"), 0, "应处理至少一个条目。")
	assert_gt(_temporary_render_node_count(utility), 0, "应保留临时节点到下一次释放。")

	utility.release_temporary_render_nodes()

	assert_eq(_temporary_render_node_count(utility), 0, "释放后临时节点数量应归零。")

	await get_tree().process_frame


## 验证 Utility 可以从场景资源中收集渲染资源。
func test_render_warmup_builds_manifest_from_packed_scene() -> void:
	var root: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = _make_mesh_instance()
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(root), OK, "测试场景应能打包。")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var manifest: GFRenderWarmupManifest = utility.build_manifest_from_scene(scene, { "manifest_id": &"scene" })

	assert_eq(manifest.manifest_id, &"scene", "场景清单应保留 manifest_id。")
	assert_gt(manifest.get_entry_count(), 1, "场景内 MeshInstance3D 应贡献资源。")

	root.free()


## 验证预热条目规范化会生成隔离的元数据副本。
func test_render_warmup_manifest_normalizes_entries() -> void:
	var source_metadata: Dictionary = { "label": "preview" }
	var normalized: Dictionary = GFRenderWarmupManifest.normalize_entry({
		"resource_path": 123,
		"kind": "texture",
		"metadata": source_metadata,
	})
	source_metadata["label"] = "changed"

	assert_eq(GFVariantData.get_option_string(normalized, "resource_path"), "123", "资源路径应规范化为字符串。")
	assert_eq(GFVariantData.get_option_string_name(normalized, "kind"), &"texture", "kind 应规范化为 StringName。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(normalized, "metadata"), "label"), "preview", "元数据应深拷贝。")


# --- 私有/辅助方法 ---

func _make_mesh_instance() -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	var _resize_error: int = arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, StandardMaterial3D.new())

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = StandardMaterial3D.new()
	return mesh_instance


func _temporary_render_node_count(utility: GFRenderWarmupUtility) -> int:
	return GFVariantData.get_option_int(utility.get_debug_snapshot(), "temporary_render_node_count")
