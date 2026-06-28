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
