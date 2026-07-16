## 测试 GFNodeGroupCache 的 group 查询缓存与失效行为。
extends GutTest


func test_group_cache_returns_snapshot_and_reuses_until_tree_changes() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var first: Node = Node.new()
	first.add_to_group(&"gf_group_cache_test")
	root.add_child(first)
	var cache: GFNodeGroupCache = GFNodeGroupCache.from_tree(get_tree(), &"gf_group_cache_test")

	var first_snapshot: Array[Node] = cache.get_nodes()
	first_snapshot.clear()
	var second_snapshot: Array[Node] = cache.get_nodes()

	assert_eq(second_snapshot, [first], "返回快照不应暴露缓存内部数组。")
	assert_false(cache.is_dirty(), "首次读取后缓存应处于干净状态。")

	var second: Node = Node.new()
	second.add_to_group(&"gf_group_cache_test")
	root.add_child(second)

	assert_true(cache.is_dirty(), "SceneTree 新节点进入时应标记 group 缓存失效。")
	assert_eq(cache.get_nodes(), [first, second], "失效后再次读取应重建 group 快照。")

	cache.dispose()


func test_group_cache_filters_types_and_prunes_stale_nodes() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var plain: Node = Node.new()
	var custom: CustomGroupNode = CustomGroupNode.new()
	plain.add_to_group(&"gf_group_cache_typed")
	custom.add_to_group(&"gf_group_cache_typed")
	root.add_child(plain)
	root.add_child(custom)
	var cache: GFNodeGroupCache = GFNodeGroupCache.from_tree(get_tree(), &"gf_group_cache_typed", CustomGroupNode)

	assert_eq(cache.get_nodes(), [custom], "类型过滤应只保留匹配节点。")

	custom.remove_from_group(&"gf_group_cache_typed")
	assert_eq(cache.get_nodes(), [], "读取干净缓存时应剪掉已移出 group 的旧节点。")

	cache.dispose()


func test_group_cache_picks_up_group_membership_added_later_on_read() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var node: Node = Node.new()
	root.add_child(node)
	var cache: GFNodeGroupCache = GFNodeGroupCache.from_tree(get_tree(), &"gf_group_cache_manual")

	assert_eq(cache.size(), 0, "未加入 group 的节点不应进入缓存。")

	node.add_to_group(&"gf_group_cache_manual")
	assert_eq(cache.size(), 1, "读取干净缓存时也应同步同树节点后来加入 group 的成员。")
	assert_false(cache.is_dirty(), "同步新增 group 成员不应把缓存留在脏状态。")
	assert_eq(cache.get_first(), node, "同步后应能读取后来加入 group 的节点。")
	assert_true(cache.has_node(node), "has_node 应基于当前缓存快照判断。")

	cache.dispose()


func test_group_cache_debug_snapshot_reports_state_and_diagnostics() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var node: Node = Node.new()
	node.add_to_group(&"gf_group_cache_debug")
	root.add_child(node)
	var cache: GFNodeGroupCache = GFNodeGroupCache.from_tree(get_tree(), &"gf_group_cache_debug", "Node")

	var _nodes: Array[Node] = cache.get_nodes()
	var snapshot: Dictionary = cache.get_debug_snapshot()
	var diagnostics: Dictionary = GFVariantData.get_option_dictionary(snapshot, "diagnostics")

	assert_eq(GFVariantData.get_option_string_name(snapshot, "group_name"), &"gf_group_cache_debug", "快照应包含 group 名。")
	assert_eq(GFVariantData.get_option_string(snapshot, "type_filter"), "Node", "快照应包含类型过滤文本。")
	assert_eq(GFVariantData.get_option_int(snapshot, "node_count"), 1, "快照应包含当前节点数量。")
	assert_eq(GFVariantData.get_option_int(diagnostics, "miss_count"), 1, "首次读取应记录一次缓存 miss。")

	cache.dispose()


class CustomGroupNode extends Node:
	pass
