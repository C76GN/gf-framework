@tool

## GFThumbnailRenderer: 编辑器缩略图渲染辅助节点。
##
## 使用独立 SubViewport 渲染 Node3D 或 Mesh，供项目自定义编辑器工具复用。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFThumbnailRenderer
extends Node


# --- 公共变量 ---

## 请求取消正在进行的 MeshLibrary 批量预览生成。
## [br]
## @api public
var cancel_preview_generation: bool = false


# --- 私有变量 ---

var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_ensure_viewport()


func _exit_tree() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_world_root = null
	_camera = null
	_key_light = null
	_fill_light = null


# --- 公共方法 ---

## 渲染一个 3D 节点缩略图。
## [br]
## @api public
## [br]
## @param source: 要渲染的 3D 节点，会被复制后放入内部 Viewport。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return 渲染出的 Image；失败时返回 null。
func render_node3d(source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true) -> Image:
	if source == null:
		return null

	_ensure_viewport()
	_clear_world_root()

	var duplicated: Node = source.duplicate()
	if not (duplicated is Node3D):
		duplicated.free()
		return null
	var instance: Node3D = duplicated

	_world_root.add_child(instance)
	_prepare_instance(instance)
	_render_prepare(_normalize_render_size(size), transparent, _get_combined_aabb(instance))

	await RenderingServer.frame_post_draw
	var image: Image = null
	if is_instance_valid(_viewport) and _viewport.get_texture() != null:
		image = _viewport.get_texture().get_image()
	_free_render_instance(instance)
	return image


## 渲染一个 3D 节点缩略图纹理。
## [br]
## @api public
## [br]
## @param source: 要渲染的 3D 节点。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return 渲染出的 ImageTexture；失败时返回 null。
func render_node3d_texture(
	source: Node3D,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true
) -> ImageTexture:
	var image: Image = await render_node3d(source, size, transparent)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


## 渲染一个 Mesh 缩略图。
## [br]
## @api public
## [br]
## @param mesh: 要渲染的 Mesh。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return 渲染出的 Image；失败时返回 null。
func render_mesh(mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true) -> Image:
	if mesh == null:
		return null

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	var image: Image = await render_node3d(instance, size, transparent)
	instance.free()
	return image


## 渲染一个 Mesh 缩略图纹理。
## [br]
## @api public
## [br]
## @param mesh: 要渲染的 Mesh。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return 渲染出的 ImageTexture；失败时返回 null。
func render_mesh_texture(
	mesh: Mesh,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true
) -> ImageTexture:
	var image: Image = await render_mesh(mesh, size, transparent)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


## 为 MeshLibrary 批量生成条目预览。
## [br]
## @api public
## [br]
## @param mesh_library: 目标 MeshLibrary。
## [br]
## @param size: 预览尺寸。
## [br]
## @param overwrite_existing: 是否覆盖已有预览。
## [br]
## @return 成功生成的预览数量。
func render_mesh_library_previews(
	mesh_library: MeshLibrary,
	size: Vector2i = Vector2i(128, 128),
	overwrite_existing: bool = true
) -> int:
	var plan: Dictionary = await build_mesh_library_preview_plan(mesh_library, size, overwrite_existing)
	return apply_mesh_library_preview_plan(mesh_library, plan)


## 为 MeshLibrary 批量生成预览修改计划，不直接修改资源。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param mesh_library: 目标 MeshLibrary。
## [br]
## @param size: 预览尺寸。
## [br]
## @param overwrite_existing: 是否覆盖已有预览。
## [br]
## @return 包含 changes、generated_count 和 cancelled 的修改计划。
## [br]
## @schema return: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.
func build_mesh_library_preview_plan(
	mesh_library: MeshLibrary,
	size: Vector2i = Vector2i(128, 128),
	overwrite_existing: bool = true
) -> Dictionary:
	if mesh_library == null:
		return {
			"ok": false,
			"generated_count": 0,
			"cancelled": false,
			"changes": [],
		}

	cancel_preview_generation = false
	var safe_size: Vector2i = _normalize_render_size(size)
	var changes: Array[Dictionary] = []
	var cancelled: bool = false
	for item_id: int in mesh_library.get_item_list():
		if cancel_preview_generation:
			cancelled = true
			break
		if not overwrite_existing and mesh_library.get_item_preview(item_id) != null:
			continue

		var mesh: Mesh = mesh_library.get_item_mesh(item_id)
		if mesh == null:
			continue

		var texture: ImageTexture = await render_mesh_texture(mesh, safe_size, true)
		if texture != null:
			changes.append({
				"item_id": item_id,
				"old_preview": mesh_library.get_item_preview(item_id),
				"new_preview": texture,
			})

	cancel_preview_generation = false
	return {
		"ok": true,
		"generated_count": changes.size(),
		"cancelled": cancelled,
		"changes": changes,
	}


## 应用 MeshLibrary 预览修改计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param mesh_library: 目标 MeshLibrary。
## [br]
## @param plan: build_mesh_library_preview_plan() 返回的计划。
## [br]
## @schema plan: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.
## [br]
## @return 实际应用的变更数量。
func apply_mesh_library_preview_plan(mesh_library: MeshLibrary, plan: Dictionary) -> int:
	if mesh_library == null:
		return 0
	var changes: Array = _read_plan_changes(plan)
	if changes.is_empty():
		return 0
	var applied_count: int = 0
	var was_blocking: bool = mesh_library.is_blocking_signals()
	mesh_library.set_block_signals(true)
	for change_variant: Variant in changes:
		var change: Dictionary = _as_dictionary(change_variant)
		var item_id: int = _read_int(change, "item_id", -1)
		if item_id < 0:
			continue
		var preview: Texture2D = _variant_to_texture(_read_value(change, "new_preview"))
		mesh_library.set_item_preview(item_id, preview)
		applied_count += 1
	mesh_library.set_block_signals(was_blocking)
	if applied_count > 0:
		mesh_library.emit_changed()
	return applied_count


## 撤销 MeshLibrary 预览修改计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param mesh_library: 目标 MeshLibrary。
## [br]
## @param plan: build_mesh_library_preview_plan() 返回的计划。
## [br]
## @schema plan: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.
## [br]
## @return 实际还原的变更数量。
func revert_mesh_library_preview_plan(mesh_library: MeshLibrary, plan: Dictionary) -> int:
	if mesh_library == null:
		return 0
	var changes: Array = _read_plan_changes(plan)
	if changes.is_empty():
		return 0
	var reverted_count: int = 0
	var was_blocking: bool = mesh_library.is_blocking_signals()
	mesh_library.set_block_signals(true)
	for index: int in range(changes.size() - 1, -1, -1):
		var change: Dictionary = _as_dictionary(changes[index])
		var item_id: int = _read_int(change, "item_id", -1)
		if item_id < 0:
			continue
		var preview: Texture2D = _variant_to_texture(_read_value(change, "old_preview"))
		mesh_library.set_item_preview(item_id, preview)
		reverted_count += 1
	mesh_library.set_block_signals(was_blocking)
	if reverted_count > 0:
		mesh_library.emit_changed()
	return reverted_count


## 将 MeshLibrary 预览修改计划注册到 UndoRedo 管理器。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param mesh_library: 目标 MeshLibrary。
## [br]
## @param plan: build_mesh_library_preview_plan() 返回的计划。
## [br]
## @schema plan: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.
## [br]
## @param undo_manager: EditorUndoRedoManager 或兼容对象。
## [br]
## @param action_name: UndoRedo 动作名。
## [br]
## @return Godot 错误码。
func add_mesh_library_preview_plan_to_undo_manager(
	mesh_library: MeshLibrary,
	plan: Dictionary,
	undo_manager: Object,
	action_name: String = "Generate MeshLibrary Previews"
) -> Error:
	if mesh_library == null or undo_manager == null:
		return ERR_INVALID_PARAMETER
	if (
		not undo_manager.has_method("create_action")
		or not undo_manager.has_method("add_do_method")
		or not undo_manager.has_method("add_undo_method")
		or not undo_manager.has_method("commit_action")
	):
		return ERR_INVALID_PARAMETER
	var changes: Array = _read_plan_changes(plan)
	if changes.is_empty():
		return ERR_SKIP
	var _create_action_result: Variant = undo_manager.call("create_action", action_name)
	for change_variant: Variant in changes:
		var change: Dictionary = _as_dictionary(change_variant)
		var item_id: int = _read_int(change, "item_id", -1)
		if item_id < 0:
			continue
		var _add_do_preview_result: Variant = undo_manager.call(
			"add_do_method",
			mesh_library,
			"set_item_preview",
			item_id,
			_variant_to_texture(_read_value(change, "new_preview"))
		)
		var _add_undo_preview_result: Variant = undo_manager.call(
			"add_undo_method",
			mesh_library,
			"set_item_preview",
			item_id,
			_variant_to_texture(_read_value(change, "old_preview"))
		)
	var _add_do_changed_result: Variant = undo_manager.call("add_do_method", mesh_library, "emit_changed")
	var _add_undo_changed_result: Variant = undo_manager.call("add_undo_method", mesh_library, "emit_changed")
	var _commit_action_result: Variant = undo_manager.call("commit_action", true)
	return OK


# --- 私有/辅助方法 ---

func _read_plan_changes(plan: Dictionary) -> Array:
	var changes_value: Variant = plan.get("changes", [])
	if changes_value is Array:
		var changes: Array = changes_value
		return changes
	return []


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var data: Dictionary = value
		return data
	return {}


func _read_value(data: Dictionary, key: String, fallback: Variant = null) -> Variant:
	if data.has(key):
		return data[key]
	return fallback


func _read_int(data: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = _read_value(data, key, fallback)
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is String:
		var text: String = value
		if text.is_valid_int():
			return text.to_int()
	return fallback


func _variant_to_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


func _ensure_viewport() -> void:
	if is_instance_valid(_viewport):
		return

	_viewport = SubViewport.new()
	_viewport.name = "GFThumbnailViewport"
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.world_3d = World3D.new()
	_viewport.world_3d.environment = Environment.new()
	add_child(_viewport)

	_world_root = Node3D.new()
	_viewport.add_child(_world_root)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.01
	_camera.far = 1000.0
	_world_root.add_child(_camera)

	_key_light = DirectionalLight3D.new()
	_key_light.light_energy = 2.0
	_key_light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	_world_root.add_child(_key_light)

	_fill_light = DirectionalLight3D.new()
	_fill_light.light_energy = 0.75
	_fill_light.rotation_degrees = Vector3(35.0, 145.0, 0.0)
	_world_root.add_child(_fill_light)


func _clear_world_root() -> void:
	for child: Node in _world_root.get_children():
		if child != _camera and child != _key_light and child != _fill_light:
			_world_root.remove_child(child)
			child.free()


func _free_render_instance(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	var parent: Node = instance.get_parent()
	if parent != null:
		parent.remove_child(instance)
	instance.free()


func _prepare_instance(instance: Node3D) -> void:
	instance.transform = Transform3D.IDENTITY
	var bounds: AABB = _get_combined_aabb(instance)
	var largest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest > 0.0001:
		instance.scale *= 2.0 / largest
	bounds = _get_combined_aabb(instance)
	var center: Vector3 = bounds.position + bounds.size * 0.5
	instance.global_position -= center


func _render_prepare(size: Vector2i, transparent: bool, bounds: AABB) -> void:
	_viewport.size = size
	_viewport.transparent_bg = transparent
	var environment: Environment = _viewport.world_3d.environment
	environment.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR

	var center: Vector3 = bounds.position + bounds.size * 0.5
	var largest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest < 0.01:
		largest = 1.0
	var camera_direction: Vector3 = Vector3(0.45, 0.4, 1.0).normalized()
	_camera.position = center + camera_direction * largest * 4.0
	_camera.look_at(center, Vector3.UP)
	_camera.size = _calculate_orthographic_size_for_aabb(bounds, _camera) * 1.08
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw()


func _normalize_render_size(size: Vector2i) -> Vector2i:
	return Vector2i(maxi(size.x, 1), maxi(size.y, 1))


func _get_combined_aabb(root: Node) -> AABB:
	var combined: AABB = AABB()
	var has_bounds: bool = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current_variant: Variant = stack.pop_back()
		if not current_variant is Node:
			continue
		var current: Node = current_variant
		if current is MeshInstance3D:
			var mesh_instance: MeshInstance3D = current
			if mesh_instance.mesh != null:
				var aabb: AABB = mesh_instance.get_aabb()
				var transform: Transform3D = mesh_instance.global_transform
				var corners: Array[Vector3] = [
					transform * aabb.position,
					transform * (aabb.position + Vector3(aabb.size.x, 0.0, 0.0)),
					transform * (aabb.position + Vector3(0.0, aabb.size.y, 0.0)),
					transform * (aabb.position + Vector3(0.0, 0.0, aabb.size.z)),
					transform * (aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0)),
					transform * (aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z)),
					transform * (aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z)),
					transform * (aabb.position + aabb.size),
				]
				for point: Vector3 in corners:
					if not has_bounds:
						combined = AABB(point, Vector3.ZERO)
						has_bounds = true
					else:
						combined = combined.expand(point)
		for child: Node in current.get_children():
			stack.append(child)

	if not has_bounds:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	return combined


func _calculate_orthographic_size_for_aabb(bounds: AABB, camera: Camera3D) -> float:
	var camera_transform: Transform3D = camera.global_transform
	var camera_right: Vector3 = camera_transform.basis.x.normalized()
	var camera_up: Vector3 = camera_transform.basis.y.normalized()
	var corners: Array[Vector3] = [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
		bounds.position + Vector3(0.0, bounds.size.y, 0.0),
		bounds.position + Vector3(0.0, 0.0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, bounds.size.y, 0.0),
		bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
		bounds.position + Vector3(0.0, bounds.size.y, bounds.size.z),
		bounds.position + bounds.size,
	]

	var min_u: float = INF
	var max_u: float = -INF
	var min_v: float = INF
	var max_v: float = -INF
	for corner: Vector3 in corners:
		var offset: Vector3 = corner - camera.global_position
		var u: float = offset.dot(camera_right)
		var v: float = offset.dot(camera_up)
		min_u = minf(min_u, u)
		max_u = maxf(max_u, u)
		min_v = minf(min_v, v)
		max_v = maxf(max_v, v)

	return maxf(max_u - min_u, max_v - min_v)
