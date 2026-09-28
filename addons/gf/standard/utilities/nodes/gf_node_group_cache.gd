## GFNodeGroupCache: SceneTree group 查询缓存。
##
## 适合相机、交互、物理探针、运行时注册表或编辑器预览等需要频繁读取
## 同一 group 节点快照的场景。它只缓存 Godot group 查询结果，不规定节点业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFNodeGroupCache
extends RefCounted


# --- 信号 ---

## 缓存被标记为脏时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 失效原因。
signal cache_invalidated(reason: StringName)


# --- 公共变量 ---

## 查询的 SceneTree。
## [br]
## @api public
## [br]
## @since 8.0.0
var tree: SceneTree:
	get:
		return _tree
	set(value):
		_set_tree(value)

## 查询的 group 名。
## [br]
## @api public
## [br]
## @since 8.0.0
var group_name: StringName:
	get:
		return _group_name
	set(value):
		_set_group_name(value)

## 可选类型过滤器，可为脚本类型、原生类或类名字符串。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null.
var type_filter: Variant:
	get:
		return _type_filter
	set(value):
		_set_type_filter(value)


# --- 私有变量 ---

## 当前查询节点 group 的 SceneTree。
## [br]
## @api private
## [br]
var _tree: SceneTree = null

## 当前查询的 group 名称。
## [br]
## @api private
## [br]
var _group_name: StringName = &""

## 可选节点类型过滤条件。
## [br]
## @api private
## [br]
var _type_filter: Variant = null

## 上次重建或同步后缓存的匹配节点。
## [br]
## @api private
## [br]
var _nodes: Array[Node] = []

## 缓存是否需要在下一次读取时重建。
## [br]
## @api private
## [br]
var _dirty: bool = true

## 记录命中、未命中、失效与重建次数的诊断对象。
## [br]
## @api private
## [br]
var _diagnostics: GFCacheDiagnostics = GFCacheDiagnostics.new()


# --- Godot 生命周期方法 ---

func _init(
	p_tree: SceneTree = null,
	p_group_name: StringName = &"",
	p_type_filter: Variant = null
) -> void:
	_diagnostics.cache_id = &"node_group_cache"
	var _configure_result: GFNodeGroupCache = configure(p_tree, p_group_name, p_type_filter)


# --- 公共方法 ---

## 创建并配置 group 缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_tree: 查询的 SceneTree。
## [br]
## @param p_group_name: 查询的 group 名。
## [br]
## @param p_type_filter: 可选类型过滤器。
## [br]
## @schema p_type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null.
## [br]
## @return 新 group 缓存。
static func from_tree(
	p_tree: SceneTree,
	p_group_name: StringName,
	p_type_filter: Variant = null
) -> GFNodeGroupCache:
	return GFNodeGroupCache.new(p_tree, p_group_name, p_type_filter)


## 重新配置缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_tree: 查询的 SceneTree。
## [br]
## @param p_group_name: 查询的 group 名。
## [br]
## @param p_type_filter: 可选类型过滤器。
## [br]
## @schema p_type_filter: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null.
## [br]
## @return 当前缓存。
func configure(
	p_tree: SceneTree,
	p_group_name: StringName,
	p_type_filter: Variant = null
) -> GFNodeGroupCache:
	_set_tree(p_tree)
	_group_name = p_group_name
	_type_filter = p_type_filter
	invalidate(&"configured")
	return self


## 手动标记缓存失效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 失效原因。
func invalidate(reason: StringName = &"manual") -> void:
	if _dirty:
		return
	_dirty = true
	_diagnostics.record_invalidation(reason, _group_name)
	cache_invalidated.emit(reason)


## 立即重建缓存并返回节点快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前 group 节点快照。
func refresh() -> Array[Node]:
	_rebuild_cache()
	return _copy_nodes()


## 获取 group 节点快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前 group 节点快照。
func get_nodes() -> Array[Node]:
	if _dirty:
		_diagnostics.record_miss(_group_name)
		_rebuild_cache()
	else:
		_diagnostics.record_hit(_group_name)
		_prune_stale_cached_nodes()
		_sync_current_group_members()
	return _copy_nodes()


## 获取第一项 group 节点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 第一个匹配节点；没有匹配时返回 null。
func get_first() -> Node:
	var nodes: Array[Node] = get_nodes()
	if nodes.is_empty():
		return null
	return nodes[0]


## 检查节点是否在当前缓存快照中。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param node: 目标节点。
## [br]
## @return 在缓存快照中返回 true。
func has_node(node: Node) -> bool:
	if node == null:
		return false
	return get_nodes().has(node)


## 获取当前匹配节点数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 匹配节点数量。
func size() -> int:
	return get_nodes().size()


## 检查缓存是否已失效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 缓存需要重建时返回 true。
func is_dirty() -> bool:
	return _dirty


## 断开 SceneTree 信号并清空缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	_disconnect_tree_signals()
	_tree = null
	_nodes.clear()
	_dirty = true


## 获取缓存诊断快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 诊断快照。
## [br]
## @schema return: Dictionary，包含 group_name、dirty、node_count、has_tree、type_filter 和 diagnostics。
func get_debug_snapshot() -> Dictionary:
	return {
		"group_name": _group_name,
		"dirty": _dirty,
		"node_count": _nodes.size(),
		"has_tree": _tree != null,
		"type_filter": _type_filter_to_text(_type_filter),
		"diagnostics": _diagnostics.get_debug_snapshot(),
	}


# --- 私有/辅助方法 ---

## Tree 改变时重连 node_added/node_removed 信号并标记缓存失效。
## [br]
## @api private
## [br]
func _set_tree(value: SceneTree) -> void:
	if _tree == value:
		return
	_disconnect_tree_signals()
	_tree = value
	_connect_tree_signals()
	invalidate(&"tree_changed")


## group 名变化时保存新值并使缓存失效。
## [br]
## @api private
## [br]
func _set_group_name(value: StringName) -> void:
	if _group_name == value:
		return
	_group_name = value
	invalidate(&"group_changed")


## 类型过滤器变化时保存新值并使缓存失效。
## [br]
## @api private
## [br]
func _set_type_filter(value: Variant) -> void:
	if _type_filters_equal(_type_filter, value):
		return
	_type_filter = value
	invalidate(&"type_filter_changed")


## 连接当前 Tree 的节点添加和移除信号，避免重复连接。
## [br]
## @api private
## [br]
func _connect_tree_signals() -> void:
	if _tree == null:
		return
	var added: Callable = Callable(self, "_on_tree_node_changed")
	var removed: Callable = Callable(self, "_on_tree_node_changed")
	if not _tree.node_added.is_connected(added):
		var _connect_added_result: Error = _tree.node_added.connect(added) as Error
	if not _tree.node_removed.is_connected(removed):
		var _connect_removed_result: Error = _tree.node_removed.connect(removed) as Error


## 若当前 Tree 存在，则断开已连接的节点添加和移除信号。
## [br]
## @api private
## [br]
func _disconnect_tree_signals() -> void:
	if _tree == null:
		return
	var added: Callable = Callable(self, "_on_tree_node_changed")
	var removed: Callable = Callable(self, "_on_tree_node_changed")
	if _tree.node_added.is_connected(added):
		_tree.node_added.disconnect(added)
	if _tree.node_removed.is_connected(removed):
		_tree.node_removed.disconnect(removed)




## 清空并重查 Tree group；Tree 或 group 缺失时完成空缓存写入。
## [br]
## @api private
## [br]
func _rebuild_cache() -> void:
	_nodes.clear()
	if _tree == null or _group_name == &"":
		_dirty = false
		_diagnostics.record_write(_group_name)
		return

	for node: Node in _tree.get_nodes_in_group(_group_name):
		if _is_node_match(node):
			_nodes.append(node)
	_dirty = false
	_diagnostics.record_write(_group_name)


## 移除已不满足节点匹配条件的缓存项，并逐项记录 stale_node_pruned。
## [br]
## @api private
## [br]
func _prune_stale_cached_nodes() -> void:
	for index: int in range(_nodes.size() - 1, -1, -1):
		var node: Node = _nodes[index]
		if not _is_node_match(node):
			_nodes.remove_at(index)
			_diagnostics.record_invalidation(&"stale_node_pruned", _group_name)


## 在未失效的缓存上补入新增匹配节点，并按 instance ID 避免重复添加。
## [br]
## @api private
## [br]
func _sync_current_group_members() -> void:
	if _tree == null or _group_name == &"":
		return
	var cached_instance_ids: Dictionary = {}
	for cached_node: Node in _nodes:
		cached_instance_ids[cached_node.get_instance_id()] = true
	var added_count: int = 0
	for node: Node in _tree.get_nodes_in_group(_group_name):
		var node_id: int = node.get_instance_id()
		if cached_instance_ids.has(node_id):
			continue
		if not _is_node_match(node):
			continue
		_nodes.append(node)
		cached_instance_ids[node_id] = true
		added_count += 1
	if added_count > 0:
		_diagnostics.record_write(_group_name)


## 创建新的数组并按原顺序收集缓存中的 Node 引用。
## [br]
## @api private
## [br]
func _copy_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in _nodes:
		result.append(node)
	return result


## 要求节点仍有效、未排队删除、在 Tree 内、属于目标 group 且通过类型过滤。
## [br]
## @api private
## [br]
func _is_node_match(node: Node) -> bool:
	return (
		is_instance_valid(node)
		and not node.is_queued_for_deletion()
		and node.is_inside_tree()
		and node.is_in_group(_group_name)
		and _matches_type(node, _type_filter)
	)


## null 过滤器匹配所有节点；字符串类过滤器按名称处理，其余交给 is_instance_of。
## [br]
## @api private
## [br]
static func _matches_type(node: Node, filter: Variant) -> bool:
	if node == null:
		return false
	if filter == null:
		return true
	if typeof(filter) == TYPE_STRING or typeof(filter) == TYPE_STRING_NAME:
		return _matches_type_name(node, GFVariantData.to_text(filter))
	return is_instance_of(node, filter)


## 依次匹配原生类名和脚本继承链上的 global_name 或 resource_path。
## [br]
## @api private
## [br]
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


## 仅当 Variant 为 Script 时返回强类型脚本引用。
## [br]
## @api private
## [br]
static func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


## 类型不同即不相等；同类型值按 == 比较，两个 null 视为相等。
## [br]
## @api private
## [br]
static func _type_filters_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left == null and right == null:
		return true
	return left == right


## 将 null、名称、Script 或其他过滤值转换为调试快照文本。
## [br]
## @api private
## [br]
static func _type_filter_to_text(filter: Variant) -> String:
	if filter == null:
		return ""
	if typeof(filter) == TYPE_STRING or typeof(filter) == TYPE_STRING_NAME:
		return GFVariantData.to_text(filter)
	if filter is Script:
		var script: Script = filter
		if not String(script.get_global_name()).is_empty():
			return String(script.get_global_name())
		return script.resource_path
	return str(filter)


# --- 信号处理函数 ---

## 场景树有节点加入或移除时令缓存失效；不尝试只增删传入节点，下一次查询统一重建组快照。
## [br]
## @api private
func _on_tree_node_changed(_node: Node) -> void:
	invalidate(&"tree_changed")
