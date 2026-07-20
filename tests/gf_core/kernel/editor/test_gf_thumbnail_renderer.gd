## 测试 GFThumbnailRenderer 的输入边界处理。
extends GutTest


# --- 测试方法 ---

func test_normalize_render_size_clamps_to_positive_pixels() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()

	assert_eq(renderer._normalize_render_size(Vector2i(0, -4)), Vector2i(1, 1), "渲染尺寸应钳制到至少 1 像素。")
	renderer.free()


func test_free_render_instance_removes_temporary_child() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var instance: Node3D = Node3D.new()
	renderer._world_root.add_child(instance)

	renderer._free_render_instance(instance)

	assert_eq(renderer._world_root.get_child_count(), 3, "清理临时渲染节点后应只保留 camera 与两盏灯。")
	renderer.queue_free()


func test_thumbnail_render_task_cancels_pending_task_through_kernel_token() -> void:
	var task: GFThumbnailRenderTask = GFThumbnailRenderTask.new(GFThumbnailRenderRequest.new(), 7)
	var completed_tasks: Array[GFThumbnailRenderTask] = []
	var _connected_completed: Error = task.completed.connect(func(completed_task: GFThumbnailRenderTask) -> void:
		completed_tasks.append(completed_task)
	) as Error

	assert_true(task.cancel(&"test_cancel"), "pending 任务应能立即取消。")

	var completion: GFAsyncCompletion = task.get_completion()
	assert_true(task.is_cancelled(), "任务应进入取消终态。")
	assert_true(task.get_cancel_token().is_cancel_requested(), "任务 token 应记录取消请求。")
	assert_true(completion.is_cancelled(), "任务完成源应进入取消终态。")
	assert_eq(task.get_cancel_reason(), &"test_cancel", "任务应保留取消原因。")
	assert_eq(completed_tasks, [task], "任务取消应发出 completed 信号。")


func test_thumbnail_renderer_submit_request_fails_invalid_request_via_task_queue() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)

	var task: GFThumbnailRenderTask = renderer.submit_render_request(GFThumbnailRenderRequest.new())
	var result: Variant = await task.wait_completed()

	assert_eq(task.get_task_id(), 1, "renderer 应分配稳定递增任务 ID。")
	assert_true(task.is_failed(), "无效 request 应失败完成。")
	assert_true(result == null, "失败任务不应返回结果。")
	assert_false(task.get_error().is_empty(), "失败任务应保留错误说明。")
	renderer.queue_free()


func test_canvas_item_request_preserves_explicit_bounds_and_margin() -> void:
	var source: Node2D = Node2D.new()
	var content_bounds: Rect2 = Rect2(Vector2(-12.0, -8.0), Vector2(24.0, 16.0))
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_canvas_item_image(
		source,
		Vector2i(96, 64),
		true,
		content_bounds,
		0.2
	)

	assert_true(request.is_valid(), "有效 CanvasItem 应形成可执行请求。")
	assert_eq(request.get_kind(), GFThumbnailRenderRequest.Kind.CANVAS_ITEM_IMAGE)
	assert_eq(request.get_source_canvas_item(), source)
	assert_true(request.has_content_bounds(), "正尺寸边界应被识别为显式边界。")
	assert_eq(request.get_content_bounds(), content_bounds)
	assert_eq(request.get_margin_ratio(), 0.2)
	source.free()
	assert_false(request.is_valid(), "来源释放后请求应失效。")


func test_canvas_item_bounds_include_transformed_sprite_geometry() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var root: Node2D = Node2D.new()
	var sprite: Sprite2D = Sprite2D.new()
	var image: Image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.position = Vector2(5.0, 7.0)
	root.add_child(sprite)
	renderer._canvas_root.add_child(root)

	var bounds: Rect2 = renderer._get_combined_canvas_rect(root)

	assert_eq(bounds, Rect2(Vector2(-5.0, 2.0), Vector2(20.0, 10.0)))
	renderer._free_render_instance(root)
	assert_eq(renderer._canvas_root.get_child_count(), 1, "清理 2D 实例后应只保留 Camera2D。")
	renderer.queue_free()


func test_canvas_item_bounds_include_control_geometry() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var root: Node2D = Node2D.new()
	var control: ColorRect = ColorRect.new()
	control.position = Vector2(4.0, 6.0)
	control.size = Vector2(30.0, 12.0)
	root.add_child(control)
	renderer._canvas_root.add_child(root)

	var bounds: Rect2 = renderer._get_combined_canvas_rect(root)

	assert_eq(bounds, Rect2(Vector2(4.0, 6.0), Vector2(30.0, 12.0)))
	renderer._free_render_instance(root)
	renderer.queue_free()


func test_canvas_item_bounds_include_polygon_offset() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	renderer._ensure_viewport()
	var root: Node2D = Node2D.new()
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-2.0, -1.0),
		Vector2(6.0, -1.0),
		Vector2(6.0, 3.0),
	])
	polygon.offset = Vector2(10.0, 20.0)
	root.add_child(polygon)
	renderer._canvas_root.add_child(root)

	var bounds: Rect2 = renderer._get_combined_canvas_rect(root)

	assert_eq(bounds, Rect2(Vector2(8.0, 19.0), Vector2(8.0, 4.0)))
	renderer._free_render_instance(root)
	renderer.queue_free()


func test_render_canvas_item_returns_requested_image_size() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var source: Node2D = Node2D.new()
	var sprite: Sprite2D = Sprite2D.new()
	var source_image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(0.2, 0.7, 1.0, 1.0))
	sprite.texture = ImageTexture.create_from_image(source_image)
	source.add_child(sprite)

	var rendered: Image = await renderer.render_canvas_item(
		source,
		Vector2i(40, 24),
		true,
		Rect2(Vector2(-4.0, -4.0), Vector2(8.0, 8.0)),
		0.0
	)

	if rendered != null:
		assert_eq(rendered.get_size(), Vector2i(40, 24), "输出应遵循请求尺寸。")
	else:
		assert_true(
			RenderingServer.get_video_adapter_name().strip_edges().is_empty(),
			"只有不提供纹理存储的 dummy 渲染后端可以安全返回 null。"
		)
	assert_eq(renderer._canvas_root.get_child_count(), 1, "任务完成后不应遗留临时 CanvasItem。")
	source.free()
	renderer.queue_free()
	await get_tree().process_frame
