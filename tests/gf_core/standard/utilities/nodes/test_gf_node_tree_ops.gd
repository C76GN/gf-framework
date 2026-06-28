## 测试 GFNodeTreeOps 的通用节点树操作。
extends GutTest


func test_add_child_with_owner_sets_scene_owner() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var child: Node = Node.new()

	var added: bool = GFNodeTreeOps.add_child_with_owner(root, child)

	assert_true(added, "应能添加无父节点的子节点。")
	assert_eq(child.get_parent(), root, "子节点应挂到目标父节点。")
	assert_eq(child.owner, root, "未提供 owner 时应使用父节点作为 owner。")


func test_add_child_with_owner_rejects_self_and_ancestor_cycles() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var child: Node = Node.new()
	root.add_child(child)
	var orphan: Node = Node.new()
	autofree(orphan)

	assert_false(GFNodeTreeOps.add_child_with_owner(orphan, orphan), "节点不能作为自己的子节点。")
	assert_false(GFNodeTreeOps.add_child_with_owner(child, root), "不能把祖先挂到后代下形成循环。")
	assert_eq(child.get_parent(), root, "拒绝循环后原父子关系应保持不变。")


func test_reparent_node_moves_child_and_updates_owner() -> void:
	var first_parent: Node = Node.new()
	var second_parent: Node = Node.new()
	add_child_autofree(first_parent)
	add_child_autofree(second_parent)
	var child: Node = Node.new()
	first_parent.add_child(child)

	var moved: bool = GFNodeTreeOps.reparent_node(child, second_parent)

	assert_true(moved, "应能把节点移动到新父节点。")
	assert_eq(child.get_parent(), second_parent, "子节点应移动到新父节点。")
	assert_eq(child.owner, second_parent, "重挂后应更新 owner。")


func test_replace_child_preserves_index() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var first: Node = Node.new()
	var old_child: Node = Node.new()
	var last: Node = Node.new()
	var replacement: Node = Node.new()
	parent.add_child(first)
	parent.add_child(old_child)
	parent.add_child(last)

	var replaced: bool = GFNodeTreeOps.replace_child(parent, old_child, replacement)

	assert_true(replaced, "应能替换父节点下的子节点。")
	assert_eq(replacement.get_parent(), parent, "新节点应挂到父节点下。")
	assert_eq(replacement.get_index(), 1, "新节点应占用旧节点的位置。")
	assert_null(old_child.get_parent(), "旧节点应从父节点移除。")
	old_child.free()


func test_find_and_collect_nodes_by_type() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var branch: Node = Node.new()
	var custom: CustomNode = CustomNode.new()
	root.add_child(branch)
	branch.add_child(custom)

	assert_eq(
		GFNodeTreeOps.find_first_child_of_type(root, CustomNode, true),
		custom,
		"递归查找应返回第一个匹配脚本类型的子节点。"
	)
	assert_eq(
		GFNodeTreeOps.find_first_parent_of_type(custom, "Node"),
		branch,
		"向上查找应支持原生类名。"
	)

	var collected: Array[Node] = GFNodeTreeOps.collect_node_tree(root, CustomNode)
	assert_eq(collected, [custom], "收集节点树时应按类型过滤。")


func test_find_nodes_by_gdscript_class_name_string() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	root.add_child(machine)

	assert_eq(
		GFNodeTreeOps.find_first_child_of_type(root, "GFNodeStateMachine", true),
		machine,
		"字符串类型过滤应支持 GDScript class_name。"
	)


func test_collect_descendants_preserves_preorder_depth_and_limit() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var branch_a: Node = Node.new()
	var branch_b: Node = Node.new()
	var leaf_a: Node = Node.new()
	var leaf_b: Node = Node.new()
	root.add_child(branch_a)
	root.add_child(branch_b)
	branch_a.add_child(leaf_a)
	branch_b.add_child(leaf_b)

	var full_tree: Array[Node] = GFNodeTreeOps.collect_node_tree(root)
	var direct_descendants: Array[Node] = GFNodeTreeOps.collect_descendants(
		root,
		null,
		false,
		false,
		1
	)
	var limited_descendants: Array[Node] = GFNodeTreeOps.collect_descendants(
		root,
		null,
		false,
		false,
		-1,
		3
	)

	assert_eq(full_tree, [root, branch_a, leaf_a, branch_b, leaf_b], "整树收集应保持深度优先的场景树顺序。")
	assert_eq(direct_descendants, [branch_a, branch_b], "max_depth=1 时应只收集直接子节点。")
	assert_eq(limited_descendants, [branch_a, leaf_a, branch_b], "limit 应按匹配结果数量截断。")


func test_collect_children_and_siblings_support_type_filters_and_self() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var first: Node = Node.new()
	var target: CustomNode = CustomNode.new()
	var after: CustomNode = CustomNode.new()
	var last: Node = Node.new()
	parent.add_child(first)
	parent.add_child(target)
	parent.add_child(after)
	parent.add_child(last)

	var typed_children: Array[Node] = GFNodeTreeOps.collect_children(parent, CustomNode)
	var previous_with_self: Array[Node] = GFNodeTreeOps.collect_previous_siblings(target, null, true)
	var next_typed_with_self: Array[Node] = GFNodeTreeOps.collect_next_siblings(target, CustomNode, true)
	var next_plain: Array[Node] = GFNodeTreeOps.collect_next_siblings(target)

	assert_eq(typed_children, [target, after], "直接子节点收集应支持脚本类型过滤。")
	assert_eq(previous_with_self, [first, target], "previous siblings 包含自身时，自身应位于最后。")
	assert_eq(next_typed_with_self, [target, after], "next siblings 包含自身时，自身应位于第一个候选。")
	assert_eq(next_plain, [after, last], "next siblings 默认只返回自身之后的同级节点。")


func test_collect_ancestors_supports_self_filter_and_limit() -> void:
	var grandparent: Node = Node.new()
	autofree(grandparent)
	var parent: Node = Node.new()
	var child: CustomNode = CustomNode.new()
	grandparent.add_child(parent)
	parent.add_child(child)

	var with_self: Array[Node] = GFNodeTreeOps.collect_ancestors(child, null, true)
	var limited: Array[Node] = GFNodeTreeOps.collect_ancestors(child, null, true, 2)
	var typed: Array[Node] = GFNodeTreeOps.collect_ancestors(child, CustomNode, true)

	assert_eq(with_self, [child, parent, grandparent], "祖先轴包含自身时应从起点向上收集。")
	assert_eq(limited, [child, parent], "祖先轴应支持结果数量上限。")
	assert_eq(typed, [child], "祖先轴应复用通用类型过滤。")


func test_collect_children_respects_internal_nodes() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var visible_child: Node = Node.new()
	var internal_child: Node = Node.new()
	parent.add_child(visible_child)
	parent.add_child(internal_child, false, Node.INTERNAL_MODE_BACK)

	var visible_only: Array[Node] = GFNodeTreeOps.collect_children(parent)
	var with_internal: Array[Node] = GFNodeTreeOps.collect_children(parent, null, false, true)

	assert_eq(visible_only, [visible_child], "默认不应收集内部子节点。")
	assert_true(with_internal.has(internal_child), "include_internal=true 时应包含内部子节点。")


func test_free_children_queues_direct_children() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var first: Node = Node.new()
	var second: Node = Node.new()
	parent.add_child(first)
	parent.add_child(second)

	var count: int = GFNodeTreeOps.free_children(parent)

	assert_eq(count, 2, "应返回进入释放队列的子节点数量。")
	assert_eq(parent.get_child_count(), 0, "释放子节点时应立即从父节点移除。")
	assert_null(first.get_parent(), "第一个子节点应立即脱离父节点。")
	assert_null(second.get_parent(), "第二个子节点应立即脱离父节点。")

	await get_tree().process_frame
	assert_false(is_instance_valid(first), "下一帧第一个子节点应完成释放。")
	assert_false(is_instance_valid(second), "下一帧第二个子节点应完成释放。")


# --- 内部类 ---

class CustomNode extends Node:
	pass
