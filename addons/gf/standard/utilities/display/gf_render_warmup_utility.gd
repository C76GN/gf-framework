## GFRenderWarmupUtility: 通用渲染资源预热工具。
##
## 通过清单或节点树收集 Mesh、Material、Texture 等渲染资源，并按帧预算提前加载和触碰 RID。
## 它不决定项目何时预热、预热哪些场景或如何展示加载进度。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFRenderWarmupUtility
extends GFUtility


# --- 信号 ---

## 清单加入预热队列时发出。
## [br]
## @api public
## [br]
## @param queue_id: 预热队列标识。
## [br]
## @param manifest_id: 清单标识。
## [br]
## @param entry_count: 清单条目数量。
signal warmup_queued(queue_id: int, manifest_id: StringName, entry_count: int)

## 单个条目预热完成后发出。
## [br]
## @api public
## [br]
## @param queue_id: 预热队列标识。
## [br]
## @param entry_index: 清单条目索引。
## [br]
## @param result: 单个条目的预热结果。
## [br]
## @schema result: Dictionary，包含 ok、resource_path、kind、resource_class、touched_count、error、metadata 和 entry_index。
signal warmup_entry_processed(queue_id: int, entry_index: int, result: Dictionary)

## 单个清单预热完成后发出。
## [br]
## @api public
## [br]
## @param queue_id: 预热队列标识。
## [br]
## @param summary: 清单预热摘要。
## [br]
## @schema summary: Dictionary，包含 queue_id、manifest_id、total_count、processed_count、failed_count、ok、elapsed_seconds、stopped_by_budget、completed_at_unix 和 results。
signal warmup_completed(queue_id: int, summary: Dictionary)


# --- 枚举 ---

## 预热触碰模式。
## [br]
## @api public
enum TouchMode {
	## 只加载资源并触碰 RID。
	RID_ONLY,
	## 使用离屏临时渲染节点让材质或 Mesh 参与一次渲染。
	TEMPORARY_RENDER_NODES,
}


# --- 公共变量 ---

## 每次 tick 默认处理的最大条目数。
## [br]
## @api public
var default_entries_per_tick: int = 4

## 默认预热时间预算，单位秒。小于等于 0 表示不限制。
## [br]
## @api public
var default_max_seconds: float = 0.0

## 默认触碰模式。
## [br]
## @api public
var default_touch_mode: TouchMode = TouchMode.RID_ONLY

## 是否保留已加载资源引用，避免预热后立刻被释放。默认关闭，项目应在明确需要资源 pinning 时显式启用。
## [br]
## @api public
## [br]
## @since 8.0.0
var keep_resources_cached: bool = false

## 默认缓存分组。按组释放可避免不同预热流程互相持有资源。
## [br]
## @api public
## [br]
## @since 8.0.0
var default_cache_group: StringName = &"default"

## 最多保留的预热缓存资源数量。小于 1 时按 1 处理。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_cached_resources: int = 128:
	set(value):
		max_cached_resources = maxi(value, 1)
		_trim_cached_resources()

## 从 PackedScene 条目预热时是否允许实例化场景并扫描其渲染资源。该行为仍需要 options.allow_scene_instantiation 为 true，避免无意触发项目脚本副作用。
## [br]
## @api public
## [br]
## @since 8.0.0
var instantiate_packed_scenes: bool = false


# --- 私有变量 ---

var _queue: Array[Dictionary] = []
var _cached_resources: Dictionary = {}
var _cached_resource_order: Array[String] = []
var _next_queue_id: int = 1
var _processed_entry_count: int = 0
var _failed_entry_count: int = 0
var _temporary_render_nodes: Array[Node] = []


# --- GF 生命周期方法 ---

## 推进预热队列。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量。
func tick(_delta: float) -> void:
	release_temporary_render_nodes()
	var _processed_count: int = process_queue(default_entries_per_tick)


## 清空预热队列、缓存资源和临时渲染节点。
## [br]
## @api public
func dispose() -> void:
	clear_queue()
	release_cached_resources()
	release_temporary_render_nodes()
	_processed_entry_count = 0
	_failed_entry_count = 0


# --- 公共方法 ---

## 将预热清单加入队列。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifest: 预热清单。
## [br]
## @param options: 可选参数，支持 entries_per_tick、max_seconds、touch_mode、keep_cached、cache_group、max_cached_resources、instantiate_packed_scenes、allow_scene_instantiation。
## [br]
## @return 队列标识；失败返回 -1。
## [br]
## @schema options: Dictionary，包含 entries_per_tick、max_seconds、touch_mode、keep_cached、cache_group、max_cached_resources、instantiate_packed_scenes、allow_scene_instantiation、temporary_parent 和 temporary_viewport_size。
func queue_manifest(manifest: GFRenderWarmupManifest, options: Dictionary = {}) -> int:
	if manifest == null or manifest.is_empty():
		return -1

	var queue_id: int = _next_queue_id
	_next_queue_id += 1
	var entry_list: Array[Dictionary] = manifest.get_entries()
	_queue.append({
		"queue_id": queue_id,
		"manifest_id": manifest.manifest_id,
		"entries": entry_list,
		"index": 0,
		"processed": 0,
		"failed": 0,
		"options": options.duplicate(true),
		"started_at_unix": Time.get_unix_time_from_system(),
		"started_at_msec": Time.get_ticks_msec(),
	})
	warmup_queued.emit(queue_id, manifest.manifest_id, entry_list.size())
	return queue_id


## 立即预热整个清单。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifest: 预热清单。
## [br]
## @param options: 可选参数，支持 max_seconds、touch_mode、keep_cached、cache_group、max_cached_resources、instantiate_packed_scenes、allow_scene_instantiation。
## [br]
## @return 预热摘要。
## [br]
## @schema options: Dictionary，包含 max_seconds、touch_mode、keep_cached、cache_group、max_cached_resources、instantiate_packed_scenes、allow_scene_instantiation、temporary_parent 和 temporary_viewport_size。
## [br]
## @schema return: Dictionary，包含 queue_id、manifest_id、total_count、processed_count、failed_count、ok、elapsed_seconds、stopped_by_budget、completed_at_unix 和 results。
func warmup_manifest_now(manifest: GFRenderWarmupManifest, options: Dictionary = {}) -> Dictionary:
	if manifest == null:
		return _make_summary(-1, &"", 0, 0, 0, [], 0.0, false)

	var queue_id: int = _next_queue_id
	_next_queue_id += 1
	var results: Array[Dictionary] = []
	var failed_count: int = 0
	var entries: Array[Dictionary] = manifest.get_entries()
	var started_at_msec: int = Time.get_ticks_msec()
	var stopped_by_budget: bool = false
	for index: int in range(entries.size()):
		if _is_budget_exhausted(started_at_msec, options):
			stopped_by_budget = true
			break

		var result: Dictionary = _process_entry(entries[index], options)
		result["entry_index"] = index
		results.append(result)
		if not GFVariantData.get_option_bool(result, "ok"):
			failed_count += 1
		warmup_entry_processed.emit(queue_id, index, result)

	var summary: Dictionary = _make_summary(
		queue_id,
		manifest.manifest_id,
		entries.size(),
		results.size(),
		failed_count,
		results,
		_get_elapsed_seconds(started_at_msec),
		stopped_by_budget
	)
	warmup_completed.emit(queue_id, summary)
	return summary


## 按预算处理队列。
## [br]
## @api public
## [br]
## @param max_entries: 最多处理条目数。
## [br]
## @return 实际处理条目数。
func process_queue(max_entries: int = 1) -> int:
	if max_entries <= 0:
		return 0

	var processed_now: int = 0
	while processed_now < max_entries and not _queue.is_empty():
		var item: Dictionary = GFVariantData.as_dictionary(_queue[0])
		if _is_queue_item_budget_exhausted(item):
			_finish_queue_item(item, true)
			_queue.remove_at(0)
			continue

		var entries: Array = GFVariantData.get_option_array(item, "entries")
		var index: int = GFVariantData.get_option_int(item, "index")
		if index >= entries.size():
			_finish_queue_item(item, false)
			_queue.remove_at(0)
			continue

		var options: Dictionary = GFVariantData.get_option_dictionary(item, "options")
		var result: Dictionary = _process_entry(GFVariantData.as_dictionary(entries[index]), options)
		result["entry_index"] = index
		item["index"] = index + 1
		item["processed"] = GFVariantData.get_option_int(item, "processed") + 1
		if not GFVariantData.get_option_bool(result, "ok"):
			item["failed"] = GFVariantData.get_option_int(item, "failed") + 1
		processed_now += 1
		warmup_entry_processed.emit(GFVariantData.get_option_int(item, "queue_id", -1), index, result)

		if GFVariantData.get_option_int(item, "index") >= entries.size():
			_finish_queue_item(item, false)
			_queue.remove_at(0)

	return processed_now


## 从节点树收集可预热的渲染资源。
## [br]
## @api public
## [br]
## @param root: 根节点。
## [br]
## @param options: 可选参数，支持 manifest_id、include_materials、include_meshes、include_textures。
## [br]
## @return 预热清单。
## [br]
## @schema options: Dictionary，包含 manifest_id、include_materials、include_meshes 和 include_textures。
func build_manifest_from_tree(root: Node, options: Dictionary = {}) -> GFRenderWarmupManifest:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	manifest.manifest_id = GFVariantData.get_option_string_name(options, "manifest_id")
	if root == null:
		return manifest

	var seen: Dictionary = {}
	_collect_node_resources(root, manifest, seen, options)
	return manifest


## 从场景资源收集可预热的渲染资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scene: 场景资源。
## [br]
## @param options: 可选参数，支持 manifest_id、include_materials、include_meshes、include_textures、allow_scene_instantiation。
## [br]
## @return 预热清单。
## [br]
## @schema options: Dictionary，包含 manifest_id、include_materials、include_meshes、include_textures 和 allow_scene_instantiation。
func build_manifest_from_scene(scene: PackedScene, options: Dictionary = {}) -> GFRenderWarmupManifest:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	manifest.manifest_id = GFVariantData.get_option_string_name(options, "manifest_id")
	if scene == null:
		return manifest
	if not GFVariantData.get_option_bool(options, "allow_scene_instantiation", false):
		return manifest

	var root: Node = scene.instantiate()
	if root == null:
		return manifest

	manifest = build_manifest_from_tree(root, options)
	root.free()
	return manifest


## 从场景路径收集可预热的渲染资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scene_path: 场景资源路径。
## [br]
## @param options: 可选参数，支持 manifest_id、include_materials、include_meshes、include_textures、allow_scene_instantiation。
## [br]
## @return 预热清单。
## [br]
## @schema options: Dictionary，包含 manifest_id、include_materials、include_meshes、include_textures 和 allow_scene_instantiation。
func build_manifest_from_scene_path(scene_path: String, options: Dictionary = {}) -> GFRenderWarmupManifest:
	var manifest: GFRenderWarmupManifest = GFRenderWarmupManifest.new()
	manifest.manifest_id = GFVariantData.get_option_string_name(options, "manifest_id")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return manifest

	var scene: PackedScene = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	return build_manifest_from_scene(scene, options)


## 清空尚未处理的预热队列。
## [br]
## @api public
func clear_queue() -> void:
	_queue.clear()


## 释放预热缓存的资源引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cache_group: 为空时释放全部缓存；非空时只释放指定分组。
func release_cached_resources(cache_group: StringName = &"") -> void:
	if cache_group == &"":
		_cached_resources.clear()
		_cached_resource_order.clear()
		return

	var keys_to_remove: PackedStringArray = PackedStringArray()
	for raw_key: Variant in _cached_resources.keys():
		var key: String = GFVariantData.to_text(raw_key)
		var entry: Dictionary = GFVariantData.as_dictionary(_cached_resources[raw_key])
		if GFVariantData.get_option_string_name(entry, "cache_group") == cache_group:
			var _append_result: bool = keys_to_remove.append(key)
	for key: String in keys_to_remove:
		var _erased: bool = _cached_resources.erase(key)
		_cached_resource_order.erase(key)


## 释放尚未清理的离屏临时渲染节点。
## [br]
## @api public
func release_temporary_render_nodes() -> void:
	for node: Node in _temporary_render_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_temporary_render_nodes.clear()


## 获取预热缓存资源数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cache_group: 为空时返回全部缓存数量；非空时只统计指定分组。
## [br]
## @return 缓存资源数量。
func get_cached_resource_count(cache_group: StringName = &"") -> int:
	if cache_group == &"":
		return _cached_resources.size()
	var count: int = 0
	for raw_entry: Variant in _cached_resources.values():
		var entry: Dictionary = GFVariantData.as_dictionary(raw_entry)
		if GFVariantData.get_option_string_name(entry, "cache_group") == cache_group:
			count += 1
	return count


## 获取待处理队列数量。
## [br]
## @api public
## [br]
## @return 队列数量。
func get_queue_size() -> int:
	return _queue.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 queue_size、cached_resource_count、processed_entry_count、failed_entry_count、default_entries_per_tick、default_max_seconds、default_touch_mode、keep_resources_cached、default_cache_group、max_cached_resources、instantiate_packed_scenes 和 temporary_render_node_count。
func get_debug_snapshot() -> Dictionary:
	return {
		"queue_size": _queue.size(),
		"cached_resource_count": _cached_resources.size(),
		"processed_entry_count": _processed_entry_count,
		"failed_entry_count": _failed_entry_count,
		"default_entries_per_tick": default_entries_per_tick,
		"default_max_seconds": default_max_seconds,
		"default_touch_mode": default_touch_mode,
		"keep_resources_cached": keep_resources_cached,
		"default_cache_group": default_cache_group,
		"max_cached_resources": max_cached_resources,
		"instantiate_packed_scenes": instantiate_packed_scenes,
		"temporary_render_node_count": _temporary_render_nodes.size(),
	}


# --- 私有/辅助方法 ---

func _process_entry(entry: Dictionary, options: Dictionary) -> Dictionary:
	var normalized: Dictionary = GFRenderWarmupManifest.normalize_entry(entry)
	var resource: Resource = _variant_to_resource(GFVariantData.get_option_value(normalized, "resource"))
	var resource_path: String = GFVariantData.get_option_string(normalized, "resource_path")
	if resource == null and not resource_path.is_empty():
		resource = _load_resource(resource_path, GFVariantData.get_option_string(normalized, "type_hint"))

	var result: Dictionary = {
		"ok": resource != null,
		"resource_path": resource_path if not resource_path.is_empty() else (resource.resource_path if resource != null else ""),
		"kind": GFVariantData.get_option_string_name(normalized, "kind"),
		"resource_class": resource.get_class() if resource != null else "",
		"touched_count": 0,
		"cache_retained": false,
		"cache_group": _get_cache_group(options),
		"error": "",
		"metadata": GFVariantData.get_option_dictionary(normalized, "metadata"),
	}
	if resource == null:
		result["error"] = "Resource could not be loaded."
		_failed_entry_count += 1
		return result

	result["touched_count"] = _touch_resource(resource, normalized, options)
	if GFVariantData.get_option_bool(options, "keep_cached", keep_resources_cached):
		_cache_resource(resource, GFVariantData.get_option_string(result, "resource_path"), options)
		result["cache_retained"] = true
	_processed_entry_count += 1
	return result


func _load_resource(resource_path: String, type_hint: String) -> Resource:
	if not ResourceLoader.exists(resource_path, type_hint):
		return null
	return ResourceLoader.load(resource_path, type_hint, ResourceLoader.CACHE_MODE_REUSE)


func _touch_resource(resource: Resource, entry: Dictionary, options: Dictionary) -> int:
	if resource == null:
		return 0

	var touched_count: int = 0
	if resource is Texture2D:
		var texture: Texture2D = resource
		var _texture_rid: RID = texture.get_rid()
		touched_count += 1
	elif resource is Material:
		var material: Material = resource
		var _material_rid: RID = material.get_rid()
		touched_count += 1
		if _uses_temporary_render_nodes(options):
			touched_count += _touch_material_with_temporary_node(material, GFVariantData.get_option_string_name(entry, "kind"), options)
	elif resource is Shader:
		var shader: Shader = resource
		var _shader_rid: RID = shader.get_rid()
		touched_count += 1
	elif resource is Mesh:
		var mesh: Mesh = resource
		touched_count += _touch_mesh(mesh)
		if _uses_temporary_render_nodes(options):
			touched_count += _touch_mesh_with_temporary_node(mesh, options)
	elif resource is PackedScene and _can_instantiate_packed_scene(options):
		var packed_scene: PackedScene = resource
		touched_count += _touch_packed_scene(packed_scene, options)
	return touched_count


func _touch_mesh(mesh: Mesh) -> int:
	if mesh == null:
		return 0

	var touched_count: int = 1
	var _mesh_rid: RID = mesh.get_rid()
	for surface_index: int in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(surface_index)
		if material != null:
			var _surface_material_rid: RID = material.get_rid()
			touched_count += 1
	return touched_count


func _touch_packed_scene(scene: PackedScene, options: Dictionary) -> int:
	var root: Node = scene.instantiate()
	if root == null:
		return 0

	var manifest: GFRenderWarmupManifest = build_manifest_from_tree(root, options)
	var touched_count: int = 0
	for entry: Dictionary in manifest.get_entries():
		touched_count += GFVariantData.get_option_int(_process_entry(entry, options), "touched_count")
	root.free()
	return touched_count


func _touch_material_with_temporary_node(material: Material, kind: StringName, options: Dictionary) -> int:
	var parent: Node = _resolve_temporary_parent(options)
	if parent == null:
		return 0

	var viewport: SubViewport = _make_temporary_viewport(options)
	parent.add_child(viewport)
	if kind == &"particle_material":
		_add_particle_warmup_node(viewport, material)
	else:
		_add_mesh_warmup_node(viewport, _make_dummy_mesh(), material)
	_temporary_render_nodes.append(viewport)
	return 1


func _touch_mesh_with_temporary_node(mesh: Mesh, options: Dictionary) -> int:
	var parent: Node = _resolve_temporary_parent(options)
	if parent == null:
		return 0

	var viewport: SubViewport = _make_temporary_viewport(options)
	parent.add_child(viewport)
	_add_mesh_warmup_node(viewport, mesh, null)
	_temporary_render_nodes.append(viewport)
	return 1


func _make_temporary_viewport(options: Dictionary) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	var viewport_size: int = maxi(GFVariantData.get_option_int(options, "temporary_viewport_size", 16), 1)
	viewport.size = Vector2i(viewport_size, viewport_size)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	camera.look_at_from_position(Vector3(0.0, 0.0, 2.0), Vector3.ZERO, Vector3.UP)
	viewport.add_child(camera)
	return viewport


func _add_mesh_warmup_node(viewport: SubViewport, mesh: Mesh, material: Material) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material != null:
		mesh_instance.material_override = material
	viewport.add_child(mesh_instance)


func _add_particle_warmup_node(viewport: SubViewport, material: Material) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.25
	particles.one_shot = false
	particles.emitting = true
	particles.process_material = material
	particles.draw_pass_1 = _make_dummy_mesh()
	viewport.add_child(particles)


func _make_dummy_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	var _array_size: int = arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, -0.5, 0.0),
		Vector3(0.0, 0.5, 0.0),
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _resolve_temporary_parent(options: Dictionary) -> Node:
	var option_parent: Node = _variant_to_node(GFVariantData.get_option_value(options, "temporary_parent"))
	if option_parent != null:
		return option_parent

	var tree: SceneTree = _variant_to_scene_tree(Engine.get_main_loop())
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


func _cache_resource(resource: Resource, resource_path: String, options: Dictionary) -> void:
	var key: String = resource_path
	if key.is_empty():
		key = "instance:%d" % resource.get_instance_id()
	var cache_group: StringName = _get_cache_group(options)
	_cached_resources[key] = {
		"resource": resource,
		"resource_path": resource_path,
		"cache_group": cache_group,
		"cached_at_msec": Time.get_ticks_msec(),
	}
	_cached_resource_order.erase(key)
	_cached_resource_order.append(key)
	_trim_cached_resources(GFVariantData.get_option_int(options, "max_cached_resources", max_cached_resources))


func _finish_queue_item(item: Dictionary, stopped_by_budget: bool) -> void:
	var entries: Array = GFVariantData.get_option_array(item, "entries")
	var summary: Dictionary = _make_summary(
		GFVariantData.get_option_int(item, "queue_id", -1),
		GFVariantData.get_option_string_name(item, "manifest_id"),
		entries.size(),
		GFVariantData.get_option_int(item, "processed"),
		GFVariantData.get_option_int(item, "failed"),
		[],
		_get_elapsed_seconds(GFVariantData.get_option_int(item, "started_at_msec", Time.get_ticks_msec())),
		stopped_by_budget
	)
	warmup_completed.emit(GFVariantData.get_option_int(item, "queue_id", -1), summary)


func _make_summary(
	queue_id: int,
	manifest_id: StringName,
	total_count: int,
	processed_count: int,
	failed_count: int,
	results: Array[Dictionary],
	elapsed_seconds: float,
	stopped_by_budget: bool
) -> Dictionary:
	return {
		"queue_id": queue_id,
		"manifest_id": manifest_id,
		"total_count": total_count,
		"processed_count": processed_count,
		"failed_count": failed_count,
		"ok": failed_count == 0,
		"elapsed_seconds": elapsed_seconds,
		"stopped_by_budget": stopped_by_budget,
		"completed_at_unix": Time.get_unix_time_from_system(),
		"results": results.duplicate(true),
	}


func _collect_node_resources(
	node: Node,
	manifest: GFRenderWarmupManifest,
	seen: Dictionary,
	options: Dictionary
) -> void:
	if node == null:
		return

	if GFVariantData.get_option_bool(options, "include_materials", true) and node is CanvasItem:
		var canvas_item: CanvasItem = node
		_add_resource_once(manifest, canvas_item.material, &"material", seen)
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		_collect_mesh_instance_resources(mesh_instance, manifest, seen, options)
	elif node is MultiMeshInstance3D:
		var multimesh_instance: MultiMeshInstance3D = node
		_collect_multimesh_instance_resources(multimesh_instance, manifest, seen, options)
	elif node is GPUParticles3D:
		var particles: GPUParticles3D = node
		_collect_gpu_particles_resources(particles, manifest, seen, options)
	if GFVariantData.get_option_bool(options, "include_textures", true):
		if node is Sprite2D:
			var sprite: Sprite2D = node
			_add_resource_once(manifest, sprite.texture, &"texture", seen)
		elif node is TextureRect:
			var texture_rect: TextureRect = node
			_add_resource_once(manifest, texture_rect.texture, &"texture", seen)
		elif node is NinePatchRect:
			var nine_patch_rect: NinePatchRect = node
			_add_resource_once(manifest, nine_patch_rect.texture, &"texture", seen)

	for child: Node in node.get_children():
		_collect_node_resources(child, manifest, seen, options)


func _collect_mesh_instance_resources(
	mesh_instance: MeshInstance3D,
	manifest: GFRenderWarmupManifest,
	seen: Dictionary,
	options: Dictionary
) -> void:
	if mesh_instance == null:
		return

	if GFVariantData.get_option_bool(options, "include_meshes", true):
		_add_resource_once(manifest, mesh_instance.mesh, &"mesh", seen)
	if GFVariantData.get_option_bool(options, "include_materials", true):
		_add_resource_once(manifest, mesh_instance.material_override, &"material", seen)
		var mesh: Mesh = mesh_instance.mesh
		if mesh != null:
			for surface_index: int in range(mesh.get_surface_count()):
				_add_resource_once(manifest, mesh.surface_get_material(surface_index), &"material", seen)
				_add_resource_once(manifest, mesh_instance.get_surface_override_material(surface_index), &"material", seen)


func _collect_multimesh_instance_resources(
	multimesh_instance: MultiMeshInstance3D,
	manifest: GFRenderWarmupManifest,
	seen: Dictionary,
	options: Dictionary
) -> void:
	if multimesh_instance == null:
		return

	var multimesh: MultiMesh = multimesh_instance.multimesh
	if multimesh != null and GFVariantData.get_option_bool(options, "include_meshes", true):
		_add_resource_once(manifest, multimesh.mesh, &"mesh", seen)
	if GFVariantData.get_option_bool(options, "include_materials", true):
		_add_resource_once(manifest, multimesh_instance.material_override, &"material", seen)


func _collect_gpu_particles_resources(
	particles: GPUParticles3D,
	manifest: GFRenderWarmupManifest,
	seen: Dictionary,
	options: Dictionary
) -> void:
	if particles == null:
		return

	if GFVariantData.get_option_bool(options, "include_materials", true):
		_add_resource_once(manifest, particles.process_material, &"particle_material", seen)
	if GFVariantData.get_option_bool(options, "include_meshes", true):
		for pass_index: int in range(particles.draw_passes):
			_add_resource_once(manifest, particles.get_draw_pass_mesh(pass_index), &"mesh", seen)


func _add_resource_once(
	manifest: GFRenderWarmupManifest,
	resource: Resource,
	kind: StringName,
	seen: Dictionary
) -> void:
	if resource == null:
		return

	var key: String = resource.resource_path
	if key.is_empty():
		key = "instance:%d" % resource.get_instance_id()
	if seen.has(key):
		return

	seen[key] = true
	var _entry_index: int = manifest.add_resource(resource, kind)


func _uses_temporary_render_nodes(options: Dictionary) -> bool:
	return GFVariantData.get_option_int(options, "touch_mode", default_touch_mode) == TouchMode.TEMPORARY_RENDER_NODES


func _can_instantiate_packed_scene(options: Dictionary) -> bool:
	return (
		GFVariantData.get_option_bool(options, "allow_scene_instantiation", false)
		and GFVariantData.get_option_bool(options, "instantiate_packed_scenes", instantiate_packed_scenes)
	)


func _get_cache_group(options: Dictionary) -> StringName:
	var cache_group: StringName = GFVariantData.get_option_string_name(options, "cache_group", default_cache_group)
	return default_cache_group if cache_group == &"" else cache_group


func _trim_cached_resources(limit: int = -1) -> void:
	var safe_limit: int = maxi(max_cached_resources if limit < 0 else limit, 1)
	while _cached_resource_order.size() > safe_limit:
		var oldest_key: String = GFVariantData.to_text(_cached_resource_order.pop_front())
		var _erased: bool = _cached_resources.erase(oldest_key)


func _is_queue_item_budget_exhausted(item: Dictionary) -> bool:
	var options: Dictionary = GFVariantData.get_option_dictionary(item, "options")
	return _is_budget_exhausted(GFVariantData.get_option_int(item, "started_at_msec", Time.get_ticks_msec()), options)


func _is_budget_exhausted(started_at_msec: int, options: Dictionary) -> bool:
	var max_seconds: float = GFVariantData.get_option_float(options, "max_seconds", default_max_seconds)
	return max_seconds > 0.0 and _get_elapsed_seconds(started_at_msec) >= max_seconds


func _get_elapsed_seconds(started_at_msec: int) -> float:
	return maxf(float(Time.get_ticks_msec() - started_at_msec) / 1000.0, 0.0)


static func _variant_to_resource(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _variant_to_scene_tree(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null
