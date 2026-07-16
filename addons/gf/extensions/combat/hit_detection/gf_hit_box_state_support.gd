# HitBox 状态节点的共享迭代遍历实现。
extends RefCounted


# --- 常量 ---

const _MAX_SCANNED_NODES: int = 65536


# --- 层内方法 ---

## 收集受状态节点管理的后代，保持场景树顺序并限制扫描预算。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param root: 状态节点根。
## [br]
## @param recursive: 是否递归扫描。
## [br]
## @param matcher: 接收 Node 并返回 bool 的类型匹配器。
## [br]
## @return 匹配节点列表。
static func collect_managed_nodes(
	root: Node,
	recursive: bool,
	matcher: Callable
) -> Array[Node]:
	var result: Array[Node] = []
	if root == null or not matcher.is_valid():
		return result

	var stack: Array[Node] = []
	for child_index: int in range(root.get_child_count() - 1, -1, -1):
		stack.append(root.get_child(child_index))
	var scanned_count: int = 0
	while not stack.is_empty() and scanned_count < _MAX_SCANNED_NODES:
		var node: Node = stack.pop_back()
		scanned_count += 1
		if GFVariantData.to_bool(matcher.call(node)):
			result.append(node)
		if not recursive:
			continue
		for child_index: int in range(node.get_child_count() - 1, -1, -1):
			stack.append(node.get_child(child_index))
	return result
