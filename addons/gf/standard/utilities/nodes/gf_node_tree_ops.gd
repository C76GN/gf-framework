## GFNodeTreeOps: 通用节点树操作集合。
##
## 提供安全添加、重挂、替换、遍历、类型查找和 owner 传播等节点树基础操作。
## 该工具只处理 Godot Node 结构，不绑定具体玩法、UI 或场景业务。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNodeTreeOps
extends RefCounted


# --- 公共方法 ---

## 把子节点添加到父节点，并按场景编辑规则设置 owner。
## [br]
## @api public
## [br]
## @param parent: 目标父节点。
## [br]
## @param child: 要添加的子节点。
## [br]
## @param owner: 可选 owner；为空时使用 parent.owner，若没有则使用 parent。
## [br]
## @param force_readable_name: 是否要求 Godot 生成可读名称。
## [br]
## @return 添加成功返回 true。
static func add_child_with_owner(
	parent: Node,
	child: Node,
	owner: Node = null,
	force_readable_name: bool = false
) -> bool:
	if parent == null or child == null:
		return false
	if parent == child or child.is_ancestor_of(parent):
		return false
	if child.get_parent() != null:
		return false

	parent.add_child(child, force_readable_name)
	if child.get_parent() != parent:
		return false
	_apply_owner(child, _resolve_child_owner(parent, owner))
	return true


## 把节点移动到新父节点下。
## [br]
## @api public
## [br]
## @param node: 要移动的节点。
## [br]
## @param new_parent: 新父节点。
## [br]
## @param keep_global_transform: 为 true 时尽量保留 Node2D、Node3D 或 Control 的全局变换。
## [br]
## @param owner: 可选 owner；为空时使用 new_parent.owner，若没有则使用 new_parent。
## [br]
## @return 移动成功返回 true。
static func reparent_node(
	node: Node,
	new_parent: Node,
	keep_global_transform: bool = true,
	owner: Node = null
) -> bool:
	if node == null or new_parent == null:
		return false
	if node == new_parent or node.is_ancestor_of(new_parent):
		return false

	if node.get_parent() == new_parent:
		_apply_owner(node, _resolve_child_owner(new_parent, owner))
		return true

	if node.get_parent() != null:
		node.reparent(new_parent, keep_global_transform)
	else:
		new_parent.add_child(node, true)
	_apply_owner(node, _resolve_child_owner(new_parent, owner))
	return true


## 用新子节点替换父节点下的旧子节点。
## [br]
## @api public
## [br]
## @param parent: 目标父节点。
## [br]
## @param old_child: 要被替换的旧子节点。
## [br]
## @param new_child: 新子节点。
## [br]
## @param keep_global_transform: 为 true 时重挂新节点时尽量保留全局变换。
## [br]
## @param free_old_child: 为 true 时替换后 queue_free() 旧节点。
## [br]
## @param owner: 可选 owner；为空时使用 parent.owner，若没有则使用 parent。
## [br]
## @return 替换成功返回 true。
static func replace_child(
	parent: Node,
	old_child: Node,
	new_child: Node,
	keep_global_transform: bool = true,
	free_old_child: bool = false,
	owner: Node = null
) -> bool:
	if parent == null or old_child == null or new_child == null:
		return false
	if old_child.get_parent() != parent:
		return false
	if old_child == new_child:
		return true

	var old_index: int = old_child.get_index(true)
	if not reparent_node(new_child, parent, keep_global_transform, owner):
		return false
	parent.move_child(new_child, old_index)
	parent.remove_child(old_child)
	if free_old_child and not old_child.is_queued_for_deletion():
		old_child.queue_free()
	return true


## 向上查找第一个匹配类型的父级节点。
## [br]
## @api public
## [br]
## @param node: 查询起点。
## [br]
## @param parent_type: 目标类型，可为脚本类型、原生类或类名字符串。
## [br]
## @schema parent_type: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, or script resource path.
## [br]
## @param include_self: 是否包含查询起点。
## [br]
## @return 匹配节点；未找到时返回 null。
static func find_first_parent_of_type(
	node: Node,
	parent_type: Variant,
	include_self: bool = false
) -> Node:
	var current: Node = null
	if node != null:
		current = node if include_self else node.get_parent()
	while current != null:
		if _matches_type(current, parent_type):
			return current
		current = current.get_parent()
	return null


## 向下查找第一个匹配类型的子节点。
## [br]
## @api public
## [br]
## @param parent: 查询根节点。
## [br]
## @param child_type: 目标类型，可为脚本类型、原生类或类名字符串。
## [br]
## @schema child_type: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, or script resource path.
## [br]
## @param recursive: 是否递归查找。
## [br]
## @param include_internal: 是否包含内部子节点。
## [br]
## @param include_parent: 是否允许 parent 自身命中。
## [br]
## @return 匹配节点；未找到时返回 null。
static func find_first_child_of_type(
	parent: Node,
	child_type: Variant,
	recursive: bool = false,
	include_internal: bool = false,
	include_parent: bool = false
) -> Node:
	if parent == null:
		return null
	if include_parent and _matches_type(parent, child_type):
		return parent

	var node_stack: Array[Node] = []
	for child_index: int in range(parent.get_child_count(include_internal) - 1, -1, -1):
		var child: Node = parent.get_child(child_index, include_internal)
		node_stack.append(child)
	while not node_stack.is_empty():
		var stack_index: int = node_stack.size() - 1
		var current: Node = node_stack[stack_index]
		node_stack.remove_at(stack_index)
		if _matches_type(current, child_type):
			return current
		if recursive:
			for child_index: int in range(current.get_child_count(include_internal) - 1, -1, -1):
				var child: Node = current.get_child(child_index, include_internal)
				node_stack.append(child)

		if not recursive:
			continue
	return null


## 收集节点树中的节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param root: 节点树根节点。
## [br]
## @param type_filter: 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.
## [br]
## @param include_root: 是否包含 root 自身。
## [br]
## @param include_internal: 是否包含内部子节点。
## [br]
## @param max_depth: 最大遍历深度；0 只允许 root，负数表示不限深度。
## [br]
## @param limit: 最多返回多少个匹配节点；负数表示不限数量，0 表示返回空数组。
## [br]
## @return 匹配节点列表。
static func collect_node_tree(
	root: Node,
	type_filter: Variant = null,
	include_root: bool = true,
	include_internal: bool = false,
	max_depth: int = -1,
	limit: int = -1
) -> Array[Node]:
	return collect_descendants(root, type_filter, include_root, include_internal, max_depth, limit)


## 收集直接子节点，可选包含起点自身。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param parent: 查询起点。
## [br]
## @param type_filter: 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.
## [br]
## @param include_self: 是否把 parent 自身作为第一个候选。
## [br]
## @param include_internal: 是否包含内部子节点。
## [br]
## @param limit: 最多返回多少个匹配节点；负数表示不限数量，0 表示返回空数组。
## [br]
## @return 匹配节点列表。
static func collect_children(
	parent: Node,
	type_filter: Variant = null,
	include_self: bool = false,
	include_internal: bool = false,
	limit: int = -1
) -> Array[Node]:
	var result: Array[Node] = []
	if parent == null or limit == 0:
		return result
	if include_self and not _append_if_matches(result, parent, type_filter, limit):
		return result

	for child_index: int in range(parent.get_child_count(include_internal)):
		var child: Node = parent.get_child(child_index, include_internal)
		if not _append_if_matches(result, child, type_filter, limit):
			return result
	return result


## 按场景树顺序收集后代节点，可选包含 root 自身。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param root: 查询起点。
## [br]
## @param type_filter: 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.
## [br]
## @param include_root: 是否把 root 自身作为第一个候选。
## [br]
## @param include_internal: 是否包含内部子节点。
## [br]
## @param max_depth: 最大遍历深度；0 只允许 root，负数表示不限深度。
## [br]
## @param limit: 最多返回多少个匹配节点；负数表示不限数量，0 表示返回空数组。
## [br]
## @return 匹配节点列表。
static func collect_descendants(
	root: Node,
	type_filter: Variant = null,
	include_root: bool = false,
	include_internal: bool = false,
	max_depth: int = -1,
	limit: int = -1
) -> Array[Node]:
	var result: Array[Node] = []
	if root == null or limit == 0:
		return result

	var node_stack: Array[Node] = [root]
	var depth_stack: Array[int] = [0]
	while not node_stack.is_empty():
		var stack_index: int = node_stack.size() - 1
		var current: Node = node_stack[stack_index]
		node_stack.remove_at(stack_index)

		var current_depth: int = depth_stack[depth_stack.size() - 1]
		depth_stack.remove_at(depth_stack.size() - 1)

		if (current_depth > 0 or include_root) and not _append_if_matches(result, current, type_filter, limit):
			return result
		if max_depth >= 0 and current_depth >= max_depth:
			continue

		for child_index: int in range(current.get_child_count(include_internal) - 1, -1, -1):
			var child: Node = current.get_child(child_index, include_internal)
			node_stack.append(child)
			depth_stack.append(current_depth + 1)
	return result


## 从节点向上收集祖先节点，可选包含起点自身。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param node: 查询起点。
## [br]
## @param type_filter: 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.
## [br]
## @param include_self: 是否把 node 自身作为第一个候选。
## [br]
## @param limit: 最多返回多少个匹配节点；负数表示不限数量，0 表示返回空数组。
## [br]
## @return 匹配节点列表。
static func collect_ancestors(
	node: Node,
	type_filter: Variant = null,
	include_self: bool = false,
	limit: int = -1
) -> Array[Node]:
	var result: Array[Node] = []
	if node == null or limit == 0:
		return result

	var current: Node = node if include_self else node.get_parent()
	while current != null:
		if not _append_if_matches(result, current, type_filter, limit):
			return result
		current = current.get_parent()
	return result


## 按场景树顺序收集位于节点之前的同级节点，可选包含起点自身。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param node: 查询起点。
## [br]
## @param type_filter: 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.
## [br]
## @param include_self: 是否把 node 自身作为最后一个候选。
## [br]
## @param include_internal: 是否包含内部同级节点。
## [br]
## @param limit: 最多返回多少个匹配节点；负数表示不限数量，0 表示返回空数组。
## [br]
## @return 匹配节点列表。
static func collect_previous_siblings(
	node: Node,
	type_filter: Variant = null,
	include_self: bool = false,
	include_internal: bool = false,
	limit: int = -1
) -> Array[Node]:
	var result: Array[Node] = []
	if node == null or limit == 0:
		return result

	var parent: Node = node.get_parent()
	if parent == null:
		return result

	var own_index: int = _find_child_index(parent, node, include_internal)
	if own_index < 0:
		return result

	var end_index: int = own_index + 1 if include_self else own_index
	for sibling_index: int in range(0, end_index):
		var sibling: Node = parent.get_child(sibling_index, include_internal)
		if not _append_if_matches(result, sibling, type_filter, limit):
			return result
	return result


## 按场景树顺序收集位于节点之后的同级节点，可选包含起点自身。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param node: 查询起点。
## [br]
## @param type_filter: 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.
## [br]
## @param include_self: 是否把 node 自身作为第一个候选。
## [br]
## @param include_internal: 是否包含内部同级节点。
## [br]
## @param limit: 最多返回多少个匹配节点；负数表示不限数量，0 表示返回空数组。
## [br]
## @return 匹配节点列表。
static func collect_next_siblings(
	node: Node,
	type_filter: Variant = null,
	include_self: bool = false,
	include_internal: bool = false,
	limit: int = -1
) -> Array[Node]:
	var result: Array[Node] = []
	if node == null or limit == 0:
		return result

	var parent: Node = node.get_parent()
	if parent == null:
		return result

	var own_index: int = _find_child_index(parent, node, include_internal)
	if own_index < 0:
		return result

	var start_index: int = own_index if include_self else own_index + 1
	for sibling_index: int in range(start_index, parent.get_child_count(include_internal)):
		var sibling: Node = parent.get_child(sibling_index, include_internal)
		if not _append_if_matches(result, sibling, type_filter, limit):
			return result
	return result


## 递归设置节点树 owner。
## [br]
## @api public
## [br]
## @param node: 节点树根节点。
## [br]
## @param owner: 目标 owner；必须是节点树中被设置节点的祖先。
static func set_owner_recursive(node: Node, owner: Node) -> void:
	if node == null or owner == null:
		return

	var node_stack: Array[Node] = [node]
	while not node_stack.is_empty():
		var stack_index: int = node_stack.size() - 1
		var current: Node = node_stack[stack_index]
		node_stack.remove_at(stack_index)
		_apply_owner(current, owner)

		for child_index: int in range(current.get_child_count(true) - 1, -1, -1):
			var child: Node = current.get_child(child_index, true)
			node_stack.append(child)


## 从父节点移除并 queue_free() 父节点下的全部子节点。
## [br]
## @api public
## [br]
## @param parent: 目标父节点。
## [br]
## @param include_internal: 是否包含内部子节点。
## [br]
## @return 进入释放队列的子节点数量。
static func free_children(parent: Node, include_internal: bool = false) -> int:
	if parent == null:
		return 0

	var count: int = 0
	for child: Node in parent.get_children(include_internal):
		parent.remove_child(child)
		if child.is_queued_for_deletion():
			continue
		child.queue_free()
		count += 1
	return count


# --- 私有/辅助方法 ---

static func _append_if_matches(
	result: Array[Node],
	node: Node,
	type_filter: Variant,
	limit: int
) -> bool:
	if _is_result_limit_reached(result, limit):
		return false
	if _matches_type(node, type_filter):
		result.append(node)
	return not _is_result_limit_reached(result, limit)


static func _is_result_limit_reached(result: Array[Node], limit: int) -> bool:
	return limit >= 0 and result.size() >= limit


static func _find_child_index(parent: Node, target: Node, include_internal: bool) -> int:
	if parent == null or target == null:
		return -1
	for child_index: int in range(parent.get_child_count(include_internal)):
		if parent.get_child(child_index, include_internal) == target:
			return child_index
	return -1


static func _matches_type(node: Node, type_filter: Variant) -> bool:
	if node == null:
		return false
	if type_filter == null:
		return true
	if typeof(type_filter) == TYPE_STRING or typeof(type_filter) == TYPE_STRING_NAME:
		return _matches_type_name(node, GFVariantData.to_text(type_filter))
	return is_instance_of(node, type_filter)


static func _matches_type_name(node: Node, type_name: String) -> bool:
	if type_name.is_empty():
		return true
	if node.is_class(type_name):
		return true

	var script: Script = _variant_to_script(node.get_script())
	while script != null:
		if String(script.get_global_name()) == type_name or script.resource_path == type_name:
			return true
		script = script.get_base_script()
	return false


static func _resolve_child_owner(parent: Node, explicit_owner: Node) -> Node:
	if explicit_owner != null and _can_apply_owner(parent, explicit_owner):
		return explicit_owner
	if parent.owner != null and _can_apply_owner(parent, parent.owner):
		return parent.owner
	return parent


static func _apply_owner(node: Node, owner: Node) -> void:
	if node == null or owner == null:
		return
	if _can_apply_owner(node, owner):
		node.owner = owner


static func _can_apply_owner(node: Node, owner: Node) -> bool:
	if node == null or owner == null or node == owner:
		return false
	return owner.is_ancestor_of(node)


static func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null
