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
