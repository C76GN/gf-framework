## 测试 MeshLibrary 缩略图计划的失败传播与来源保护。
extends GutTest


# --- 测试方法 ---

func test_mesh_library_task_rejects_scripted_mesh_without_publishing_partial_plan() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var library: MeshLibrary = _make_mixed_library()
	var original_preview: Texture2D = library.get_item_preview(1)
	var task: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_mesh_library_preview_plan(library, Vector2i(16, 16))
	)
	var result: Variant = await task.wait_completed()

	assert_true(task.is_failed(), "任一 Mesh 违反静态策略时，整项计划任务应失败。")
	assert_true(result == null, "失败任务不得发布部分成功计划。")
	if DisplayServer.get_name() != "headless":
		assert_true(task.get_error().contains("7"), "失败应定位被拒绝的条目。")
		assert_true(task.get_error().contains("native Mesh"), "失败应保留静态资源策略原因。")
	assert_same(library.get_item_preview(1), original_preview, "生成计划不能覆盖已存在预览。")
	assert_null(library.get_item_preview(7), "被拒条目不得获得预览。")
	assert_eq(renderer._world_root.get_child_count(), 3, "失败应清理已创建的渲染副本。")
	renderer.queue_free()
	await get_tree().process_frame


func test_mesh_library_convenience_methods_do_not_apply_partial_previews_on_failure() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var library: MeshLibrary = _make_mixed_library()
	var original_preview: Texture2D = library.get_item_preview(1)
	var plan: Dictionary = await renderer.build_mesh_library_preview_plan(library, Vector2i(16, 16))

	assert_false(GFVariantData.get_option_bool(plan, "ok"), "便捷入口应报告整项计划失败。")
	assert_eq(GFVariantData.get_option_int(plan, "generated_count"), 0)
	assert_true(GFVariantData.get_option_array(plan, "changes").is_empty(), "失败计划不得带可应用变更。")
	assert_eq(renderer.apply_mesh_library_preview_plan(library, plan), 0)
	assert_eq(await renderer.render_mesh_library_previews(library, Vector2i(16, 16)), 0)
	assert_same(library.get_item_preview(1), original_preview)
	assert_null(library.get_item_preview(7))
	renderer.queue_free()
	await get_tree().process_frame


func test_mesh_library_successful_plan_applies_generated_previews() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var library: MeshLibrary = MeshLibrary.new()
	library.create_item(1)
	library.set_item_mesh(1, BoxMesh.new())
	library.create_item(2)
	var plan: Dictionary = await renderer.build_mesh_library_preview_plan(library, Vector2i(16, 16))

	assert_null(library.get_item_preview(1), "构建成功计划也不能提前修改来源。")
	if DisplayServer.get_name() == "headless":
		assert_false(GFVariantData.get_option_bool(plan, "ok"), "没有可捕获图像的后端应明确失败。")
	else:
		assert_true(GFVariantData.get_option_bool(plan, "ok"))
		assert_eq(GFVariantData.get_option_int(plan, "generated_count"), 1)
		assert_eq(renderer.apply_mesh_library_preview_plan(library, plan), 1)
		assert_not_null(library.get_item_preview(1))
	assert_null(library.get_item_preview(2), "没有 Mesh 的条目应保持为空。")
	renderer.queue_free()
	await get_tree().process_frame


func test_mesh_library_skips_existing_preview_when_overwrite_is_disabled() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var library: MeshLibrary = MeshLibrary.new()
	library.create_item(7)
	library.set_item_mesh(7, ScriptedBoxMesh.new())
	var original_preview: ImageTexture = _make_preview()
	library.set_item_preview(7, original_preview)
	var plan: Dictionary = await renderer.build_mesh_library_preview_plan(library, Vector2i(16, 16), false)

	assert_true(GFVariantData.get_option_bool(plan, "ok"), "明确跳过的条目不应执行渲染策略检查。")
	assert_eq(GFVariantData.get_option_int(plan, "generated_count"), 0)
	assert_same(library.get_item_preview(7), original_preview)
	renderer.queue_free()
	await get_tree().process_frame


func test_mesh_library_policy_failure_does_not_block_following_request() -> void:
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	add_child(renderer)
	var library: MeshLibrary = MeshLibrary.new()
	library.create_item(7)
	library.set_item_mesh(7, ScriptedBoxMesh.new())
	var rejected: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_mesh_library_preview_plan(library, Vector2i(16, 16))
	)
	var following: GFThumbnailRenderTask = renderer.submit_render_request(
		GFThumbnailRenderRequest.for_mesh_image(BoxMesh.new(), Vector2i(16, 16))
	)
	var _rejected_result: Variant = await rejected.wait_completed()
	var _following_result: Variant = await following.wait_completed()

	assert_true(rejected.is_failed())
	assert_true(rejected.get_error().contains("7"), "任务应保留失败条目 ID。")
	assert_true(rejected.get_error().contains("native Mesh"), "任务应保留原始策略错误。")
	assert_true(following.is_finished())
	assert_false(following.get_error().contains("MeshLibrary"), "前项错误不能污染后续请求。")
	if DisplayServer.get_name() != "headless":
		assert_false(following.is_failed(), "有效 Mesh 在真实渲染器中应继续成功。")
	assert_eq(renderer._world_root.get_child_count(), 3)
	renderer.queue_free()
	await get_tree().process_frame


# --- 私有/辅助方法 ---

func _make_mixed_library() -> MeshLibrary:
	var library: MeshLibrary = MeshLibrary.new()
	library.create_item(1)
	library.set_item_mesh(1, BoxMesh.new())
	library.set_item_preview(1, _make_preview())
	library.create_item(7)
	library.set_item_mesh(7, ScriptedBoxMesh.new())
	return library


func _make_preview() -> ImageTexture:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	return ImageTexture.create_from_image(image)


# --- 内部类 ---

class ScriptedBoxMesh extends BoxMesh:
	pass
