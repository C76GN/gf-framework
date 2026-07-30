## 测试 GFRenderWarmupUtility 的清单预热与节点树资源收集。
extends GutTest


# --- 测试方法 ---

## 验证预热清单可以立即处理材质资源，默认不保留缓存。
func test_render_warmup_manifest_processes_material_resource() -> void:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	manifest.manifest_id = &"test"
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var _add_resource_result_12: Variant = manifest.add_resource(material, &"material", { "label": "red" })
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var summary: Dictionary = utility.warmup_manifest_now(manifest)

	assert_true(GFVariantData.get_option_bool(summary, "ok"), "材质资源预热应成功。")
	assert_eq(GFVariantData.get_option_int(summary, "processed_count"), 1, "应处理一个条目。")
	assert_eq(utility.get_cached_resource_count(), 0, "默认不应缓存已预热资源引用。")
	var results: Array = GFVariantData.get_option_array(summary, "results")
	var first_result: Dictionary = GFVariantData.as_dictionary(results[0])
	assert_false(GFVariantData.get_option_bool(first_result, "cache_retained"), "默认结果应标记未保留缓存。")


## 验证通过路径加载的预热资源也会保留缓存引用。
func test_render_warmup_caches_resource_loaded_from_path() -> void:
	var resource_path: String = "user://gf_render_warmup_cache_material.tres"
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var _save_result: Error = ResourceSaver.save(material, resource_path)
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_path_result: Variant = manifest.add_resource_path(resource_path, &"material", "StandardMaterial3D")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var summary: Dictionary = utility.warmup_manifest_now(manifest, {
		"keep_cached": true,
		"cache_group": &"path_cache",
	})

	if FileAccess.file_exists(resource_path):
		var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))

	assert_eq(_save_result, OK, "测试材质资源应可保存到 user://。")
	assert_true(GFVariantData.get_option_bool(summary, "ok"), "路径资源预热应成功。")
	assert_eq(utility.get_cached_resource_count(), 1, "显式 opt-in 后路径加载资源应进入预热缓存。")
	assert_eq(utility.get_cached_resource_count(&"path_cache"), 1, "缓存分组应可单独统计。")


func test_render_warmup_cache_respects_max_cached_resources() -> void:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_first_result: Variant = manifest.add_resource(StandardMaterial3D.new(), &"material")
	var _add_second_result: Variant = manifest.add_resource(StandardMaterial3D.new(), &"material")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var summary: Dictionary = utility.warmup_manifest_now(manifest, {
		"keep_cached": true,
		"max_cached_resources": 1,
	})

	assert_true(GFVariantData.get_option_bool(summary, "ok"), "缓存上限不应阻断预热。")
	assert_eq(utility.get_cached_resource_count(), 1, "预热缓存应按 max_cached_resources 裁剪。")


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
	var tail_manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_tail_resource_result: Variant = tail_manifest.add_resource(StandardMaterial3D.new(), &"material")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()
	var _queue_manifest_result_41: Variant = utility.queue_manifest(manifest, { "entries_per_tick": 1 })
	var _queue_tail_manifest_result: Variant = utility.queue_manifest(tail_manifest, { "entries_per_tick": 1 })

	var first_count: int = utility.process_queue(1)
	var second_count: int = utility.process_queue(2)

	assert_eq(first_count, 1, "第一次只应处理一个条目。")
	assert_eq(second_count, 2, "显式全局预算应可处理队首剩余条目和后续清单。")
	assert_eq(utility.get_queue_size(), 0, "全部处理后队列应为空。")


## 验证正常 tick 只推进 FIFO 队首，并采用该清单自己的条目预算。
func test_render_warmup_tick_respects_head_manifest_entry_budget() -> void:
	var head_manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_head_first_result: Variant = head_manifest.add_resource(StandardMaterial3D.new(), &"material")
	var _add_head_second_result: Variant = head_manifest.add_resource(StandardMaterial3D.new(), &"material")
	var tail_manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_tail_first_result: Variant = tail_manifest.add_resource(StandardMaterial3D.new(), &"material")
	var _add_tail_second_result: Variant = tail_manifest.add_resource(StandardMaterial3D.new(), &"material")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()
	utility.default_entries_per_tick = 4
	var head_queue_id: int = utility.queue_manifest(head_manifest, { "entries_per_tick": 1 })
	var tail_queue_id: int = utility.queue_manifest(tail_manifest, { "entries_per_tick": 2 })

	utility.tick(0.0)
	var first_snapshot: Dictionary = utility.get_debug_snapshot()
	utility.tick(0.0)
	var second_snapshot: Dictionary = utility.get_debug_snapshot()
	utility.tick(0.0)
	var third_snapshot: Dictionary = utility.get_debug_snapshot()

	assert_gt(head_queue_id, 0, "队首清单应成功入队。")
	assert_gt(tail_queue_id, head_queue_id, "队尾清单应在队首之后入队。")
	assert_eq(GFVariantData.get_option_int(first_snapshot, "processed_entry_count"), 1, "首个 tick 应采用队首清单的一条预算。")
	assert_eq(GFVariantData.get_option_int(first_snapshot, "queue_size"), 2, "首个 tick 后两个清单都应仍在队列中。")
	assert_eq(GFVariantData.get_option_int(second_snapshot, "processed_entry_count"), 2, "第二个 tick 应只完成队首清单。")
	assert_eq(GFVariantData.get_option_int(second_snapshot, "queue_size"), 1, "完成队首清单后应保留队尾清单。")
	assert_eq(GFVariantData.get_option_int(third_snapshot, "processed_entry_count"), 4, "第三个 tick 应采用队尾清单的两条预算。")
	assert_eq(GFVariantData.get_option_int(third_snapshot, "queue_size"), 0, "第三个 tick 后队列应处理完毕。")


func test_render_warmup_tick_does_not_spill_unused_head_budget_into_tail() -> void:
	var head_manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_head_result: Variant = head_manifest.add_resource(
		StandardMaterial3D.new(),
		&"material"
	)
	var tail_manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_tail_result: Variant = tail_manifest.add_resource(
		StandardMaterial3D.new(),
		&"material"
	)
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()
	var _head_queue_id: int = utility.queue_manifest(
		head_manifest,
		{ "entries_per_tick": 4 }
	)
	var _tail_queue_id: int = utility.queue_manifest(
		tail_manifest,
		{ "entries_per_tick": 1 }
	)

	utility.tick(0.0)
	var first_snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_int(first_snapshot, "processed_entry_count"),
		1,
		"队首提前完成时，其未使用预算不得流入队尾。"
	)
	assert_eq(
		GFVariantData.get_option_int(first_snapshot, "queue_size"),
		1,
		"同一 tick 应保留尚未开始的队尾清单。"
	)

	utility.tick(0.0)
	assert_eq(utility.get_queue_size(), 0, "下一个 tick 才应推进队尾清单。")


func test_render_warmup_tick_uses_live_default_without_manifest_override() -> void:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	var _add_result: Variant = manifest.add_resource(
		StandardMaterial3D.new(),
		&"material"
	)
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()
	utility.default_entries_per_tick = 0
	var _queue_id: int = utility.queue_manifest(manifest)

	utility.tick(0.0)
	var paused_snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_int(paused_snapshot, "processed_entry_count"),
		0,
		"未显式覆盖预算的清单应继续服从当前全局默认值。"
	)
	assert_eq(GFVariantData.get_option_int(paused_snapshot, "queue_size"), 1)

	utility.default_entries_per_tick = 1
	utility.tick(0.0)
	assert_eq(utility.get_queue_size(), 0, "恢复全局默认预算后清单应继续推进。")


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

	var manifest: GFRenderWarmupManifest = utility.build_manifest_from_scene(scene, {
		"manifest_id": &"scene",
		"allow_scene_instantiation": true,
	})

	assert_eq(manifest.manifest_id, &"scene", "场景清单应保留 manifest_id。")
	assert_gt(manifest.get_entry_count(), 1, "场景内 MeshInstance3D 应贡献资源。")

	root.free()


func test_render_warmup_packed_scene_manifest_requires_explicit_instantiation_opt_in() -> void:
	var root: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = _make_mesh_instance()
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(root), OK, "测试场景应能打包。")
	var utility: GFRenderWarmupUtility = GFRenderWarmupUtility.new()

	var manifest: GFRenderWarmupManifest = utility.build_manifest_from_scene(scene, { "manifest_id": &"scene" })

	assert_eq(manifest.manifest_id, &"scene", "场景清单应保留 manifest_id。")
	assert_eq(manifest.get_entry_count(), 0, "PackedScene 默认不应被实例化扫描。")

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
