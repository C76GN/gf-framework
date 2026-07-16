extends GutTest


# --- 测试用例 ---

func test_type_index_defaults_to_non_live_invalidation() -> void:
	var type_index: GFEditorTypeIndex = GFEditorTypeIndex.new()

	assert_not_null(type_index, "类型索引应可在 headless 测试中创建。")
	assert_false(type_index.is_live_invalidation_enabled(), "短生命周期类型索引默认不应订阅 EditorFileSystem。")

	type_index.clear_cache()
	type_index.dispose()
	assert_false(type_index.is_live_invalidation_enabled(), "dispose 后类型索引不应保留 live 订阅。")


func test_type_index_live_invalidation_requires_editor_context() -> void:
	var type_index: GFEditorTypeIndex = GFEditorTypeIndex.new()
	var owner_node: Node = Node.new()

	assert_false(type_index.enable_live_invalidation(null), "空 owner 不应进入 live 模式。")
	assert_false(type_index.enable_live_invalidation(owner_node), "非 editor context 不应连接 EditorFileSystem。")
	assert_false(type_index.is_live_invalidation_enabled(), "失败的 live 启用不应留下订阅状态。")
	owner_node.free()
