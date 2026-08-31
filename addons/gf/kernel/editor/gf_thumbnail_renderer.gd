@tool

## GFThumbnailRenderer: 编辑器缩略图渲染辅助节点。
##
## 使用独立 SubViewport 渲染 CanvasItem、Node3D 或 Mesh，供项目自定义编辑器工具复用。
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


# --- 常量 ---

## 单边允许的最大渲染像素数。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_TARGET_DIMENSION: int = 1024

## 单个缩略图允许的最大总像素数。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_TARGET_PIXELS: int = 1_048_576

## 等待执行的最大任务数；超出后新任务立即失败。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_PENDING_TASKS: int = 256


# --- 私有变量 ---

var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _canvas_root: Node2D
var _camera_2d: Camera2D
var _pending_tasks: Array[GFThumbnailRenderTask] = []
var _active_task: GFThumbnailRenderTask = null
var _processing_task_queue: bool = false
var _next_task_id: int = 1


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_ensure_viewport()


func _exit_tree() -> void:
	_cancel_all_tasks(&"renderer_exited")
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_world_root = null
	_camera = null
	_key_light = null
	_fill_light = null
	_canvas_root = null
	_camera_2d = null


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
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_node3d_image(source, size, transparent)
	)
	var result: Variant = await task.wait_completed()
	return _variant_to_image(result)


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
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_node3d_texture(source, size, transparent)
	)
	var result: Variant = await task.wait_completed()
	return _variant_to_image_texture(result)


## 渲染一个 CanvasItem 缩略图。
##
## `source` 可以是 Node2D 或 Control。自定义 `_draw()` 等无法可靠估算
## 几何范围的节点应传入显式 `content_bounds`。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param source: 要渲染的 2D 画布节点，会被复制后放入内部 Viewport。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @param content_bounds: 来源局部坐标中的显式内容边界；非正尺寸表示自动估算。
## [br]
## @param margin_ratio: 内容边界四周的相对留白，钳制到 0.0 至 1.0。
## [br]
## @return 渲染出的 Image；失败时返回 null。
func render_canvas_item(
	source: CanvasItem,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true,
	content_bounds: Rect2 = Rect2(),
	margin_ratio: float = 0.08
) -> Image:
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_canvas_item_image(
			source,
			size,
			transparent,
			content_bounds,
			margin_ratio
		)
	)
	var result: Variant = await task.wait_completed()
	return _variant_to_image(result)


## 渲染一个 CanvasItem 缩略图纹理。
##
## `source` 可以是 Node2D 或 Control。自定义 `_draw()` 等无法可靠估算
## 几何范围的节点应传入显式 `content_bounds`。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param source: 要渲染的 2D 画布节点。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @param content_bounds: 来源局部坐标中的显式内容边界；非正尺寸表示自动估算。
## [br]
## @param margin_ratio: 内容边界四周的相对留白，钳制到 0.0 至 1.0。
## [br]
## @return 渲染出的 ImageTexture；失败时返回 null。
func render_canvas_item_texture(
	source: CanvasItem,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true,
	content_bounds: Rect2 = Rect2(),
	margin_ratio: float = 0.08
) -> ImageTexture:
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_canvas_item_texture(
			source,
			size,
			transparent,
			content_bounds,
			margin_ratio
		)
	)
	var result: Variant = await task.wait_completed()
	return _variant_to_image_texture(result)


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
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_mesh_image(mesh, size, transparent)
	)
	var result: Variant = await task.wait_completed()
	return _variant_to_image(result)


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
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_mesh_texture(mesh, size, transparent)
	)
	var result: Variant = await task.wait_completed()
	return _variant_to_image_texture(result)


## 提交一个缩略图渲染请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param request: 缩略图渲染请求。
## [br]
## @return 可取消、可等待的渲染任务。
func submit_render_request(request: GFThumbnailRenderRequest) -> GFThumbnailRenderTask:
	var task: GFThumbnailRenderTask = GFThumbnailRenderTask.new(request, _take_task_id())
	var validation_error: String = _get_request_validation_error(request)
	if not validation_error.is_empty():
		var _failed_request: bool = task.fail(validation_error)
		return task
	if _pending_tasks.size() >= MAX_PENDING_TASKS:
		var _failed_queue: bool = task.fail(
			"Thumbnail render queue reached its %d-task limit." % MAX_PENDING_TASKS
		)
		return task
	_pending_tasks.append(task)
	_schedule_task_queue()
	return task


## 取消一个渲染任务。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task: 要取消的任务。
## [br]
## @param reason: 取消原因。
## [br]
## @return 本次调用是否发出新的取消请求。
func cancel_render_task(task: GFThumbnailRenderTask, reason: StringName = &"cancelled") -> bool:
	if task == null:
		return false
	return task.cancel(reason)


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
	var task: GFThumbnailRenderTask = submit_render_request(
		GFThumbnailRenderRequest.for_mesh_library_preview_plan(mesh_library, size, overwrite_existing)
	)
	var result: Variant = await task.wait_completed()
	if result is Dictionary:
		var plan: Dictionary = result
		return plan
	return {
		"ok": false,
		"generated_count": 0,
		"cancelled": task.is_cancelled(),
		"changes": [],
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

func _schedule_task_queue() -> void:
	if _processing_task_queue:
		return
	_processing_task_queue = true
	var _deferred_call_result: Variant = call_deferred("_process_task_queue_async")


func _process_task_queue_async() -> void:
	while not _pending_tasks.is_empty():
		var task: GFThumbnailRenderTask = _pending_tasks.pop_front()
		if task == null or task.is_finished():
			continue
		_active_task = task
		if task.mark_running():
			await _execute_render_task_async(task)
		_active_task = null
	_processing_task_queue = false
	if not _pending_tasks.is_empty():
		_schedule_task_queue()


func _execute_render_task_async(task: GFThumbnailRenderTask) -> void:
	var request: GFThumbnailRenderRequest = task.get_request()
	if request == null or not request.is_valid():
		var _failed_invalid: bool = task.fail("Invalid thumbnail render request.")
		return

	match request.get_kind():
		GFThumbnailRenderRequest.Kind.NODE3D_IMAGE:
			var node_image: Image = await _render_node3d_direct(
				request.get_source_node3d(),
				request.get_size(),
				request.is_transparent()
			)
			_finish_render_task_with_result(task, node_image)
		GFThumbnailRenderRequest.Kind.NODE3D_TEXTURE:
			var node_texture: ImageTexture = await _render_node3d_texture_direct(
				request.get_source_node3d(),
				request.get_size(),
				request.is_transparent()
			)
			_finish_render_task_with_result(task, node_texture)
		GFThumbnailRenderRequest.Kind.CANVAS_ITEM_IMAGE:
			var canvas_image: Image = await _render_canvas_item_direct(
				request.get_source_canvas_item(),
				request.get_size(),
				request.is_transparent(),
				request.get_content_bounds(),
				request.has_content_bounds(),
				request.get_margin_ratio()
			)
			_finish_render_task_with_result(task, canvas_image)
		GFThumbnailRenderRequest.Kind.CANVAS_ITEM_TEXTURE:
			var canvas_texture: ImageTexture = await _render_canvas_item_texture_direct(
				request.get_source_canvas_item(),
				request.get_size(),
				request.is_transparent(),
				request.get_content_bounds(),
				request.has_content_bounds(),
				request.get_margin_ratio()
			)
			_finish_render_task_with_result(task, canvas_texture)
		GFThumbnailRenderRequest.Kind.MESH_IMAGE:
			var mesh_image: Image = await _render_mesh_direct(
				request.get_mesh(),
				request.get_size(),
				request.is_transparent()
			)
			_finish_render_task_with_result(task, mesh_image)
		GFThumbnailRenderRequest.Kind.MESH_TEXTURE:
			var mesh_texture: ImageTexture = await _render_mesh_texture_direct(
				request.get_mesh(),
				request.get_size(),
				request.is_transparent()
			)
			_finish_render_task_with_result(task, mesh_texture)
		GFThumbnailRenderRequest.Kind.MESH_LIBRARY_PREVIEW_PLAN:
			var plan: Dictionary = await _build_mesh_library_preview_plan_direct(
				request.get_mesh_library(),
				request.get_size(),
				request.should_overwrite_existing(),
				task.get_cancel_token()
			)
			if task.is_cancel_requested() or _read_bool(plan, "cancelled", false):
				var _cancelled_plan: bool = task.finish_cancelled(task.get_cancel_reason(), plan)
			elif not _read_bool(plan, "ok", false):
				var _failed_plan: bool = task.fail("Invalid MeshLibrary preview request.")
			else:
				var _succeeded_plan: bool = task.succeed(plan)
		_:
			var _failed_kind: bool = task.fail("Unsupported thumbnail render request.")


func _finish_render_task_with_result(task: GFThumbnailRenderTask, result: Variant) -> void:
	if task.is_cancel_requested():
		var _cancelled_result: bool = task.finish_cancelled(task.get_cancel_reason(), result)
		return
	if result == null:
		var _failed_result: bool = task.fail("Thumbnail render returned no result.")
		return
	var _succeeded_result: bool = task.succeed(result)


func _render_node3d_direct(source: Node3D, size: Vector2i, transparent: bool) -> Image:
	if source == null or not is_inside_tree():
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

	await get_tree().process_frame
	RenderingServer.force_draw()
	var image: Image = _capture_viewport_image()
	_free_render_instance(instance)
	return image


func _render_node3d_texture_direct(source: Node3D, size: Vector2i, transparent: bool) -> ImageTexture:
	var image: Image = await _render_node3d_direct(source, size, transparent)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _render_canvas_item_direct(
	source: CanvasItem,
	size: Vector2i,
	transparent: bool,
	content_bounds: Rect2,
	has_content_bounds: bool,
	margin_ratio: float
) -> Image:
	if source == null or not is_inside_tree():
		return null

	_ensure_viewport()
	_clear_canvas_root()
	var safe_size: Vector2i = _normalize_render_size(size)
	_viewport.size = safe_size

	var duplicated: Node = source.duplicate()
	if not (duplicated is CanvasItem):
		duplicated.free()
		return null
	var instance: CanvasItem = duplicated
	_canvas_root.add_child(instance)
	_prepare_canvas_item_instance(instance)
	var bounds: Rect2 = content_bounds if has_content_bounds else _get_combined_canvas_rect(instance)
	if not _is_usable_canvas_rect(bounds):
		bounds = Rect2(Vector2(-0.5, -0.5), Vector2.ONE)
	_render_canvas_prepare(safe_size, transparent, bounds, margin_ratio)

	await get_tree().process_frame
	RenderingServer.force_draw()
	var image: Image = _capture_viewport_image()
	_free_render_instance(instance)
	return image


func _render_canvas_item_texture_direct(
	source: CanvasItem,
	size: Vector2i,
	transparent: bool,
	content_bounds: Rect2,
	has_content_bounds: bool,
	margin_ratio: float
) -> ImageTexture:
	var image: Image = await _render_canvas_item_direct(
		source,
		size,
		transparent,
		content_bounds,
		has_content_bounds,
		margin_ratio
	)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _render_mesh_direct(mesh: Mesh, size: Vector2i, transparent: bool) -> Image:
	if mesh == null:
		return null

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	var image: Image = await _render_node3d_direct(instance, size, transparent)
	instance.free()
	return image


func _render_mesh_texture_direct(mesh: Mesh, size: Vector2i, transparent: bool) -> ImageTexture:
	var image: Image = await _render_mesh_direct(mesh, size, transparent)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _build_mesh_library_preview_plan_direct(
	mesh_library: MeshLibrary,
	size: Vector2i,
	overwrite_existing: bool,
	cancel_token: GFCancellationToken
) -> Dictionary:
	if mesh_library == null:
		return {
			"ok": false,
			"generated_count": 0,
			"cancelled": false,
			"changes": [],
		}

	var safe_size: Vector2i = _normalize_render_size(size)
	var changes: Array[Dictionary] = []
	var cancelled: bool = false
	for item_id: int in mesh_library.get_item_list():
		if cancel_token != null and cancel_token.is_cancel_requested():
			cancelled = true
			break
		if not overwrite_existing and mesh_library.get_item_preview(item_id) != null:
			continue

		var mesh: Mesh = mesh_library.get_item_mesh(item_id)
		if mesh == null:
			continue

		var texture: ImageTexture = await _render_mesh_texture_direct(mesh, safe_size, true)
		if cancel_token != null and cancel_token.is_cancel_requested():
			cancelled = true
			break
		if texture != null:
			changes.append({
				"item_id": item_id,
				"old_preview": mesh_library.get_item_preview(item_id),
				"new_preview": texture,
			})

	return {
		"ok": true,
		"generated_count": changes.size(),
		"cancelled": cancelled,
		"changes": changes,
	}


func _cancel_all_tasks(reason: StringName) -> void:
	for task: GFThumbnailRenderTask in _pending_tasks:
		var _cancelled_pending: bool = task.cancel(reason)
	_pending_tasks.clear()
	if _active_task != null:
		var active_task: GFThumbnailRenderTask = _active_task
		_active_task = null
		var _cancelled_active: bool = active_task.cancel(reason)
		var _finished_active: bool = active_task.finish_cancelled(reason)


func _get_request_validation_error(request: GFThumbnailRenderRequest) -> String:
	if request == null or not request.is_valid():
		return "Invalid thumbnail render request."
	var size: Vector2i = _normalize_render_size(request.get_size())
	if size.x > MAX_TARGET_DIMENSION or size.y > MAX_TARGET_DIMENSION:
		return (
			"Thumbnail target exceeds the %d-pixel dimension limit."
			% MAX_TARGET_DIMENSION
		)
	if size.x * size.y > MAX_TARGET_PIXELS:
		return (
			"Thumbnail target exceeds the %d-pixel area limit."
			% MAX_TARGET_PIXELS
		)
	return ""


func _take_task_id() -> int:
	var task_id: int = _next_task_id
	_next_task_id += 1
	return task_id


func _variant_to_image(value: Variant) -> Image:
	if value is Image:
		var image: Image = value
		return image
	return null


func _variant_to_image_texture(value: Variant) -> ImageTexture:
	if value is ImageTexture:
		var texture: ImageTexture = value
		return texture
	return null


func _read_bool(data: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = _read_value(data, key, fallback)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return fallback


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


func _capture_viewport_image() -> Image:
	if not is_instance_valid(_viewport):
		return null
	if RenderingServer.get_video_adapter_name().strip_edges().is_empty():
		return null
	var viewport_texture: ViewportTexture = _viewport.get_texture()
	if viewport_texture == null:
		return null
	return viewport_texture.get_image()


func _ensure_viewport() -> void:
	if is_instance_valid(_viewport):
		return

	_viewport = SubViewport.new()
	_viewport.name = "GFThumbnailViewport"
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_2d = Viewport.MSAA_4X
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

	_canvas_root = Node2D.new()
	_canvas_root.name = "CanvasRoot"
	_viewport.add_child(_canvas_root)

	_camera_2d = Camera2D.new()
	_camera_2d.name = "Camera2D"
	_camera_2d.enabled = true
	_camera_2d.position_smoothing_enabled = false
	_canvas_root.add_child(_camera_2d)


func _clear_world_root() -> void:
	for child: Node in _world_root.get_children():
		if child != _camera and child != _key_light and child != _fill_light:
			_world_root.remove_child(child)
			child.free()


func _clear_canvas_root() -> void:
	for child: Node in _canvas_root.get_children():
		if child != _camera_2d:
			_canvas_root.remove_child(child)
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


func _prepare_canvas_item_instance(instance: CanvasItem) -> void:
	if instance is Node2D:
		var node_2d: Node2D = instance
		node_2d.transform = Transform2D.IDENTITY
	elif instance is Control:
		var control: Control = instance
		control.position = Vector2.ZERO
		control.rotation = 0.0
		control.scale = Vector2.ONE


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


func _render_canvas_prepare(
	size: Vector2i,
	transparent: bool,
	bounds: Rect2,
	margin_ratio: float
) -> void:
	_viewport.size = size
	_viewport.transparent_bg = transparent
	var safe_margin: float = clampf(margin_ratio, 0.0, 1.0)
	var padded_size: Vector2 = bounds.size * (1.0 + safe_margin * 2.0)
	padded_size.x = maxf(padded_size.x, 0.0001)
	padded_size.y = maxf(padded_size.y, 0.0001)
	var zoom_factor: float = minf(
		float(size.x) / padded_size.x,
		float(size.y) / padded_size.y
	)
	_camera_2d.position = bounds.get_center()
	_camera_2d.zoom = Vector2.ONE * maxf(zoom_factor, 0.0001)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _normalize_render_size(size: Vector2i) -> Vector2i:
	return Vector2i(maxi(size.x, 1), maxi(size.y, 1))


func _get_combined_aabb(root: Node) -> AABB:
	var combined: AABB = AABB()
	var has_bounds: bool = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current_variant: Variant = stack.pop_back()
		if not (current_variant is Node):
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


func _get_combined_canvas_rect(root: CanvasItem) -> Rect2:
	var combined: Rect2 = Rect2()
	var has_bounds: bool = false
	var root_inverse: Transform2D = root.get_global_transform().affine_inverse()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current_value: Variant = stack.pop_back()
		if not (current_value is Node):
			continue
		var current: Node = current_value
		if current is CanvasItem:
			var canvas_item: CanvasItem = current
			if canvas_item.is_visible_in_tree():
				var local_rect: Rect2 = _get_canvas_item_local_rect(canvas_item)
				if _is_usable_canvas_rect(local_rect):
					var relative_transform: Transform2D = root_inverse * canvas_item.get_global_transform()
					var transformed_rect: Rect2 = _transform_canvas_rect(local_rect, relative_transform)
					if not has_bounds:
						combined = transformed_rect
						has_bounds = true
					else:
						combined = combined.merge(transformed_rect)
		for child: Node in current.get_children():
			stack.append(child)

	if not has_bounds:
		return Rect2()
	return combined


func _get_canvas_item_local_rect(canvas_item: CanvasItem) -> Rect2:
	if canvas_item is Sprite2D:
		var sprite: Sprite2D = canvas_item
		return sprite.get_rect()
	if canvas_item is AnimatedSprite2D:
		var animated_sprite: AnimatedSprite2D = canvas_item
		return _get_animated_sprite_rect(animated_sprite)
	if canvas_item is Control:
		var control: Control = canvas_item
		return Rect2(Vector2.ZERO, control.size)
	if canvas_item is Polygon2D:
		var polygon: Polygon2D = canvas_item
		var polygon_rect: Rect2 = _get_points_rect(polygon.polygon)
		return Rect2(polygon_rect.position + polygon.offset, polygon_rect.size)
	if canvas_item is Line2D:
		var line: Line2D = canvas_item
		var line_rect: Rect2 = _get_points_rect(line.points)
		return line_rect.grow(maxf(line.width * 0.5, 0.0)) if _is_usable_canvas_rect(line_rect) else line_rect
	if canvas_item is GPUParticles2D:
		var particles: GPUParticles2D = canvas_item
		return particles.visibility_rect
	return Rect2()


func _get_animated_sprite_rect(animated_sprite: AnimatedSprite2D) -> Rect2:
	var sprite_frames: SpriteFrames = animated_sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(animated_sprite.animation):
		return Rect2()
	var frame_count: int = sprite_frames.get_frame_count(animated_sprite.animation)
	if frame_count <= 0:
		return Rect2()
	var frame_index: int = clampi(animated_sprite.frame, 0, frame_count - 1)
	var texture: Texture2D = sprite_frames.get_frame_texture(animated_sprite.animation, frame_index)
	if texture == null:
		return Rect2()
	var texture_size: Vector2 = Vector2(texture.get_size())
	var rect_position: Vector2 = animated_sprite.offset
	if animated_sprite.centered:
		rect_position -= texture_size * 0.5
	return Rect2(rect_position, texture_size)


func _get_points_rect(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _transform_canvas_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var corners: Array[Vector2] = [
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * Vector2(rect.position.x, rect.end.y),
		transform * rect.end,
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for point: Vector2 in corners:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _is_usable_canvas_rect(rect: Rect2) -> bool:
	return (
		is_finite(rect.position.x)
		and is_finite(rect.position.y)
		and is_finite(rect.size.x)
		and is_finite(rect.size.y)
		and rect.size.x > 0.0001
		and rect.size.y > 0.0001
	)


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
