# Repeater 的单一同步引擎；容器只持有纯比较快照和弱节点记录，不持有项目回调。
extends RefCounted


# --- 常量 ---

## 在容器上保存重复组状态字典的 meta key。
## [br]
## @api private
const _META_GROUPS: StringName = &"_gf_repeater_groups"

## 标记克隆所属同步组的 meta key。
## [br]
## @api private
const _META_OWNER: StringName = &"_gf_repeater_owner"

## 保存克隆行状态对象的 meta key。
## [br]
## @api private
const _META_ROW: StringName = &"_gf_repeater_row"

## 标记节点为 Repeater 克隆的 meta key。
## [br]
## @api private
const _META_CLONE: StringName = &"gf_repeater_clone"

## 保存克隆分组键的 meta key。
## [br]
## @api private
const _META_GROUP_KEY: StringName = &"gf_repeater_group_key"

## 保存克隆当前条目索引的 meta key。
## [br]
## @api private
const _META_INDEX: StringName = &"gf_repeater_index"

## 保存克隆当前条目值的 meta key。
## [br]
## @api private
const _META_ITEM: StringName = &"gf_repeater_item"

## 单次同步可接受的最大条目数。
## [br]
## @api private
const _MAX_ITEMS: int = 4096

## identity 编码及快照键可使用的长度上限。
## [br]
## @api private
const _MAX_KEY_BYTES: int = 4096

## 递归比较快照允许的最大深度。
## [br]
## @api private
const _SNAPSHOT_MAX_DEPTH: int = 16

## 递归比较快照允许访问的最大节点数。
## [br]
## @api private
const _SNAPSHOT_MAX_NODES: int = 4096


# --- 框架内部方法 ---

## 执行 Repeater 的完整同步请求。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param container: 当前组的容器。
## [br]
## @param template: 复制模板。
## [br]
## @param items: 完整条目集合。
## [br]
## @param options: 公开 Repeater 同步选项。
## [br]
## @param sync_owner: 可选绑定令牌；只用于限定解绑的中断作用域，组仅保留弱引用。
## [br]
## @return 公开同步报告。
## [br]
## @schema items: Array，项目条目。
## [br]
## @schema options: Dictionary，结构同 GFRepeaterBinder.sync_container()。
## [br]
## @schema return: Dictionary，结构同 GFRepeaterBinder.sync_container()。
static func synchronize(container: Node, template: Node, items: Array, options: Dictionary, sync_owner: RefCounted = null) -> Dictionary:
	if not _live(container) or not _live(template) or container == template:
		return _report(&"invalid_target")
	var option_error: StringName = validate_options(options)
	if not option_error.is_empty():
		return _report(option_error)
	if items.size() > _MAX_ITEMS:
		return _report(&"item_limit")
	var group_key: StringName = GFVariantData.get_option_string_name(options, "group_key", &"default")
	var group: _Group = _get_group(container, group_key)
	if group._busy or group._clearing:
		return _report(&"busy")
	if _owned(template, container, group):
		return _report(&"invalid_target")
	group._busy = true
	group._sync_owner_ref = weakref(sync_owner) if sync_owner != null else null
	group._epoch += 1
	var context: _Context = _Context.new()
	context._container = container
	context._template = template
	context._group = group
	context._group_key = group_key
	context._epoch = group._epoch
	context._was_inside_tree = container.is_inside_tree()
	context._options = options.duplicate()
	for item: Variant in items:
		context._items.append(_copy_item(item))
	var result: Dictionary = _synchronize(context)
	if not GFVariantData.get_option_bool(result, "ok"):
		_release_staged(context)
	group._busy = false
	group._sync_owner_ref = null
	return result


## 校验闭合选项，不执行项目回调。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param options: Repeater 选项。
## [br]
## @return 空标识表示合法，否则 invalid_options。
## [br]
## @schema options: Dictionary，结构同 GFRepeaterBinder.sync_container()。
static func validate_options(options: Dictionary) -> StringName:
	for option_key: Variant in options:
		if not (option_key is String or option_key is StringName):
			return &"invalid_options"
		var option_name: String = str(option_key)
		var value: Variant = options[option_key]
		match option_name:
			"group_key", "text_key":
				if not (value is String or value is StringName):
					return &"invalid_options"
			"clear_existing", "hide_template", "sync_initial":
				if not value is bool:
					return &"invalid_options"
			"duplicate_flags":
				if not value is int:
					return &"invalid_options"
				var flags: int = value
				if flags < 0 or flags > 15:
					return &"invalid_options"
			"identity_callable", "configure_callable":
				if not value is Callable:
					return &"invalid_options"
				var callback: Callable = value
				if option_name == "identity_callable" and not callback.is_valid():
					return &"invalid_options"
			"default_items":
				if not value is Array:
					return &"invalid_options"
			_:
				return &"invalid_options"
	if options.has("identity_callable") and not GFVariantData.get_option_bool(options, "clear_existing", true):
		return &"invalid_options"
	return &""


## 查询当前组是否正在同步或清理。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param container: 目标容器。
## [br]
## @param group_key: 克隆组。
## [br]
## @return 同步或清理期间返回 true。
static func is_busy(container: Node, group_key: StringName) -> bool:
	var group: _Group = _find_group(container, group_key)
	return group != null and (group._busy or group._clearing)


## 使当前同步代失效；不释放已显示节点。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param container: 目标容器。
## [br]
## @param group_key: 克隆组。
## [br]
## @param sync_owner: 只中断此令牌的在途同步；为空时无条件中断当前组。
static func interrupt(container: Node, group_key: StringName, sync_owner: RefCounted = null) -> void:
	var group: _Group = _find_group(container, group_key)
	if group != null:
		if sync_owner != null and (
			group._sync_owner_ref == null
			or not is_same(group._sync_owner_ref.get_ref(), sync_owner)
		):
			return
		group._epoch += 1


## 清理精确由当前组拥有的克隆；同步期间调用会中断当前代。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param container: 目标容器。
## [br]
## @param group_key: 克隆组。
## [br]
## @return 已从容器移除的节点数。
static func clear_clones(container: Node, group_key: StringName) -> int:
	if not _live(container):
		return 0
	var group: _Group = _get_group(container, group_key)
	group._epoch += 1
	if group._clearing:
		return 0
	group._clearing = true
	var removed_count: int = 0
	for child: Node in container.get_children():
		if not _live(container):
			break
		if _owned(child, container, group):
			_retire_node(child, container)
			removed_count += 1
	group._rows.clear()
	group._clearing = false
	return removed_count


# --- 私有/辅助方法 ---

## 校验 identity 并规划或更新行节点；同步代失效时返回 interrupted 报告。
## [br]
## @api private
static func _synchronize(context: _Context) -> Dictionary:
	var identity: Callable = _option_callable(context._options, "identity_callable")
	var tokens: Array[String] = []
	var seen: Dictionary = {}
	for index: int in range(context._items.size()):
		var token: String = ""
		if identity.is_valid():
			var item_id: Variant = identity.call(_copy_item(context._items[index]), index)
			if not _current(context):
				return _report(&"interrupted")
			token = _key_token(item_id)
			if token.is_empty():
				return _report(&"invalid_identity")
			if seen.has(token):
				return _report(&"duplicate_identity")
			seen[token] = true
		tokens.append(token)
	if not _current(context):
		return _report(&"interrupted")
	var flags: int = GFVariantData.get_option_int(context._options, "duplicate_flags", 15)
	var compatible: bool = _node_from_ref(context._group._template_ref) == context._template and context._group._flags == flags
	var old_by_token: Dictionary = {}
	var previous_rows: Array[_Row] = context._group._rows.duplicate()
	for row: _Row in previous_rows:
		if compatible and identity.is_valid() and _owned(_node_from_ref(row._node_ref), context._container, context._group):
			old_by_token[row._token] = row
	var text_key: StringName = GFVariantData.get_option_string_name(context._options, "text_key", &"text")
	for index: int in range(context._items.size()):
		var plan: _Plan = _Plan.new()
		plan._item = context._items[index]
		plan._index = index
		plan._token = tokens[index]
		plan._snapshot = _snapshot(plan._item)
		var existing: Variant = old_by_token.get(plan._token)
		if existing is _Row:
			var row: _Row = existing
			plan._row = row
			plan._node = _node_from_ref(row._node_ref)
			plan._configure = row._index != index or row._text_key != text_key or not _same_snapshot(row._snapshot, plan._snapshot)
		else:
			plan._node = context._template.duplicate(flags)
			if is_instance_valid(plan._node):
				context._new_nodes.append(plan._node)
			if not _current(context):
				return _report(&"interrupted")
			if not _live(plan._node) or plan._node.get_parent() != null:
				return _report(&"duplicate_failed")
			plan._created = true
			plan._row = _Row.new()
			plan._row._node_ref = weakref(plan._node)
			plan._node.set_meta(_META_OWNER, context._group)
			plan._node.set_meta(_META_ROW, plan._row)
			plan._node.set_meta(_META_CLONE, true)
			if not _current(context) or not _live(plan._node) or plan._node.get_parent() != null:
				return _report(&"interrupted")
			plan._node.set_meta(_META_GROUP_KEY, context._group_key)
			if not _current(context) or not _live(plan._node) or plan._node.get_parent() != null:
				return _report(&"interrupted")
		context._plans.append(plan)
	if not _current(context):
		return _report(&"interrupted")
	if GFVariantData.get_option_bool(context._options, "hide_template", true) and context._template is CanvasItem:
		var template_canvas: CanvasItem = context._template
		template_canvas.visible = false
	if not _current(context):
		return _report(&"interrupted")
	for plan: _Plan in context._plans:
		if plan._created:
			context._container.add_child(plan._node)
			if not _current(context) or not _owned(plan._node, context._container, context._group):
				return _report(&"interrupted")
	var retained: Array[_Row] = []
	if not GFVariantData.get_option_bool(context._options, "clear_existing", true):
		for row: _Row in previous_rows:
			if _owned(_node_from_ref(row._node_ref), context._container, context._group):
				retained.append(row)
	for plan: _Plan in context._plans:
		retained.append(plan._row)
	context._group._rows = retained
	var removed_count: int = 0
	for row: _Row in previous_rows:
		if retained.has(row):
			continue
		var old_node: Node = _node_from_ref(row._node_ref)
		if _owned(old_node, context._container, context._group):
			_retire_node(old_node, context._container)
			removed_count += 1
		if not _current(context):
			return _report(&"interrupted")
	if not _reorder(context, retained):
		return _report(&"interrupted")
	var nodes: Array[Node] = []
	var created_count: int = 0
	for plan: _Plan in context._plans:
		if not _current(context) or not _owned(plan._node, context._container, context._group):
			return _report(&"interrupted")
		if plan._configure:
			plan._node.set_meta(_META_INDEX, plan._index)
			if not _current(context) or not _owned(plan._node, context._container, context._group):
				return _report(&"interrupted")
			plan._node.set_meta(_META_ITEM, _copy_item(plan._item))
			if not _current(context) or not _owned(plan._node, context._container, context._group):
				return _report(&"interrupted")
			if plan._node is CanvasItem:
				var canvas: CanvasItem = plan._node
				canvas.visible = true
			if not _configure_node(context, plan):
				return _report(&"interrupted")
		plan._row._token = plan._token
		plan._row._index = plan._index
		plan._row._text_key = text_key
		plan._row._snapshot = plan._snapshot
		nodes.append(plan._node)
		if plan._created:
			created_count += 1
	if not _plans_are_owned(context):
		return _report(&"interrupted")
	context._group._template_ref = weakref(context._template)
	context._group._flags = flags
	return _report(&"", nodes, created_count, nodes.size() - created_count, removed_count)


## 先调用节点的 set_repeater_item() 或写入 text 属性，再调用 configure_callable。
## [br]
## @api private
static func _configure_node(context: _Context, plan: _Plan) -> bool:
	if not _current(context) or not _owned(plan._node, context._container, context._group):
		return false
	if plan._node.has_method("set_repeater_item"):
		var _hook_result: Variant = plan._node.call("set_repeater_item", _copy_item(plan._item), plan._index)
	elif "text" in plan._node:
		plan._node.set("text", _item_text(plan._item, context._options))
	if not _current(context) or not _owned(plan._node, context._container, context._group):
		return false
	var callback: Callable = _option_callable(context._options, "configure_callable")
	if callback.is_valid():
		var _configured: Variant = callback.call(plan._node, _copy_item(plan._item), plan._index)
	return _current(context) and _owned(plan._node, context._container, context._group)


## 将目标行按顺序放回本组克隆占用的子节点槽位，并检查容器顺序仍可核验。
## [br]
## @api private
static func _reorder(context: _Context, rows: Array[_Row]) -> bool:
	var slots: Array[int] = []
	var children: Array[Node] = context._container.get_children()
	for child: Node in children:
		if _owned(child, context._container, context._group):
			slots.append(child.get_index())
	if slots.size() != rows.size():
		return false
	for index: int in range(rows.size()):
		var node: Node = _node_from_ref(rows[index]._node_ref)
		if not _current(context) or not _owned(node, context._container, context._group):
			return false
		if node.get_index() != slots[index]:
			var old_index: int = node.get_index()
			var displaced: Node = context._container.get_child(slots[index])
			if not _owned(displaced, context._container, context._group):
				return false
			context._container.move_child(node, slots[index])
			if not _current(context) or not _owned(displaced, context._container, context._group):
				return false
			context._container.move_child(displaced, old_index)
			if not _current(context) or context._container.get_child_count() != children.size():
				return false
	for index: int in range(children.size()):
		var child: Node = children[index]
		if not _owned(child, context._container, context._group):
			if not _live(child) or child.get_parent() != context._container or child.get_index() != index:
				return false
	for index: int in range(rows.size()):
		var node: Node = _node_from_ref(rows[index]._node_ref)
		if not _owned(node, context._container, context._group) or node.get_index() != slots[index]:
			return false
	return true


## 清理尚未提交的副本：未挂载节点排队释放，仍由本组拥有的挂载节点退役。
## [br]
## @api private
static func _release_staged(context: _Context) -> void:
	for node: Node in context._new_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() == null:
			node.queue_free()
		elif _live(context._container) and _owned(node, context._container, context._group):
			_retire_node(node, context._container)


## 移除节点的组与行标记，将其从容器移除，并在无父节点时排队释放。
## [br]
## @api private
static func _retire_node(node: Node, container: Node) -> void:
	node.remove_meta(_META_OWNER)
	if node.has_meta(_META_ROW):
		node.remove_meta(_META_ROW)
	container.remove_child(node)
	if is_instance_valid(node) and node.get_parent() == null:
		node.queue_free()


## 检查目标节点、同步代、容器组及初始场景树状态是否仍匹配请求上下文。
## [br]
## @api private
static func _current(context: _Context) -> bool:
	return (
		_live(context._container)
		and _live(context._template)
		and context._group._epoch == context._epoch
		and _find_group(context._container, context._group_key) == context._group
		and (not context._was_inside_tree or context._container.is_inside_tree())
	)


## 校验所有计划节点仍归当前组所有，且组内行顺序与容器一致。
## [br]
## @api private
static func _plans_are_owned(context: _Context) -> bool:
	if not _current(context):
		return false
	for plan: _Plan in context._plans:
		if not _owned(plan._node, context._container, context._group):
			return false
	var row_index: int = 0
	for child: Node in context._container.get_children():
		if not _owned(child, context._container, context._group):
			continue
		if row_index >= context._group._rows.size() or _node_from_ref(context._group._rows[row_index]._node_ref) != child:
			return false
		row_index += 1
	return row_index == context._group._rows.size()


## 依据节点存活状态、父容器、组 meta 与行引用检查节点是否由指定组拥有。
## [br]
## @api private
static func _owned(node: Node, container: Node, group: _Group) -> bool:
	return (
		_live(node)
		and _node_from_ref(group._container_ref) == container
		and node.get_parent() == container
		and node.has_meta(_META_OWNER)
		and is_same(node.get_meta(_META_OWNER), group)
		and node.has_meta(_META_ROW)
		and _row_belongs_to_node(node.get_meta(_META_ROW), node)
	)


## 检查节点实例有效且未排队删除。
## [br]
## @api private
static func _live(node: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()


## 从弱引用取回仍存活的 Node；引用为空、目标失效或类型不符时返回 null。
## [br]
## @api private
static func _node_from_ref(node_ref: WeakRef) -> Node:
	if node_ref == null:
		return null
	var candidate: Variant = node_ref.get_ref()
	if candidate is Node:
		var node: Node = candidate
		return node if _live(node) else null
	return null


## 从容器 meta 中查找指定组，并确认其弱引用仍指向该容器。
## [br]
## @api private
static func _find_group(container: Node, group_key: StringName) -> _Group:
	if not _live(container) or not container.has_meta(_META_GROUPS):
		return null
	var groups_value: Variant = container.get_meta(_META_GROUPS)
	if groups_value is Dictionary:
		var groups: Dictionary = groups_value
		var candidate: Variant = groups.get(group_key)
		if candidate is _Group:
			var group: _Group = candidate
			return group if _node_from_ref(group._container_ref) == container else null
	return null


## 获取或创建容器分组状态；遇到来自复制容器的旧组时重建该容器的组记录。
## [br]
## @api private
static func _get_group(container: Node, group_key: StringName) -> _Group:
	var existing: _Group = _find_group(container, group_key)
	if existing != null:
		return existing
	var groups: Dictionary = {}
	if container.has_meta(_META_GROUPS):
		var source_groups: Dictionary = GFVariantData.as_dictionary(container.get_meta(_META_GROUPS))
		for key: Variant in source_groups:
			var candidate: Variant = source_groups[key]
			if candidate is _Group:
				var candidate_group: _Group = candidate
				if _node_from_ref(candidate_group._container_ref) == container:
					groups[key] = candidate_group
				else:
					var copied_group: _Group = _Group.new()
					copied_group._container_ref = weakref(container)
					_adopt_copied_rows(container, candidate_group, copied_group)
					groups[key] = copied_group
	if groups.has(group_key):
		container.set_meta(_META_GROUPS, groups)
		var copied_candidate: Variant = groups[group_key]
		if copied_candidate is _Group:
			var copied_group: _Group = copied_candidate
			return copied_group
	var group: _Group = _Group.new()
	group._container_ref = weakref(container)
	groups[group_key] = group
	container.set_meta(_META_GROUPS, groups)
	return group


## 为携带源组行 meta 的复制子节点建立本容器的行记录并更新其所有权 meta。
## [br]
## @api private
static func _adopt_copied_rows(container: Node, source_group: _Group, group: _Group) -> void:
	for child: Node in container.get_children():
		if not child.has_meta(_META_OWNER) or not child.has_meta(_META_ROW):
			continue
		if not is_same(child.get_meta(_META_OWNER), source_group):
			continue
		var source_row: Variant = child.get_meta(_META_ROW)
		if not source_row is _Row or _row_belongs_to_node(source_row, child):
			continue
		var row: _Row = _Row.new()
		row._node_ref = weakref(child)
		group._rows.append(row)
		child.set_meta(_META_OWNER, group)
		child.set_meta(_META_ROW, row)


## 检查行对象保存的节点弱引用是否仍指向给定节点。
## [br]
## @api private
static func _row_belongs_to_node(candidate: Variant, node: Node) -> bool:
	if candidate is _Row:
		var row: _Row = candidate
		return row._node_ref != null and is_same(row._node_ref.get_ref(), node)
	return false


## 将 identity 编码为键 token；节点路径、文本和最终编码超长时返回空字符串。
## [br]
## @api private
static func _key_token(value: Variant) -> String:
	if value is NodePath:
		var path: NodePath = value
		if path.get_name_count() + path.get_subname_count() > _MAX_KEY_BYTES:
			return ""
		var path_length: int = path.get_name_count() + path.get_subname_count()
		for index: int in range(path.get_name_count()):
			path_length += path.get_name(index).length()
			if path_length > _MAX_KEY_BYTES:
				return ""
		for index: int in range(path.get_subname_count()):
			path_length += path.get_subname(index).length()
			if path_length > _MAX_KEY_BYTES:
				return ""
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH] and str(value).length() > _MAX_KEY_BYTES:
		return ""
	var token: String = GFVariantKeyCodec.make_key_token(value)
	if token.length() > _MAX_KEY_BYTES or token.to_utf8_buffer().size() > _MAX_KEY_BYTES:
		return ""
	return token


## 从选项读取 Callable；值不是 Callable 时返回空回调。
## [br]
## @api private
static func _option_callable(options: Dictionary, key: String) -> Callable:
	var value: Variant = options.get(key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 字典条目依次尝试指定 text_key、label、name、id，其他情况交给 GFVariantData 转文本。
## [br]
## @api private
static func _item_text(item: Variant, options: Dictionary) -> String:
	if item is Dictionary:
		var source: Dictionary = item
		var text_key: StringName = GFVariantData.get_option_string_name(options, "text_key", &"text")
		var text: String = GFVariantData.get_option_string(source, text_key)
		if not text.is_empty():
			return text
		for fallback: StringName in [&"label", &"name", &"id"]:
			text = GFVariantData.get_option_string(source, fallback)
			if not text.is_empty():
				return text
	return GFVariantData.to_text(item)


## 为条目构建比较快照；递归内容不可比较时清空快照值并保留不可比较标记。
## [br]
## @api private
static func _snapshot(item: Variant) -> _Snapshot:
	var snapshot: _Snapshot = _Snapshot.new()
	snapshot._value = _copy_comparable(item, snapshot, [], 0)
	if not snapshot._comparable:
		snapshot._value = null
	return snapshot


## 条目可比较时返回 duplicate_variant() 的结果，否则返回原输入值。
## [br]
## @api private
static func _copy_item(item: Variant) -> Variant:
	var snapshot: _Snapshot = _snapshot(item)
	return GFVariantData.duplicate_variant(item) if snapshot._comparable else item


## 递归记录可比较值及类型信息；遇到循环、受限规模、对象类值或不稳定键时标记不可比较。
## [br]
## @api private
static func _copy_comparable(value: Variant, snapshot: _Snapshot, ancestors: Array, depth: int) -> Variant:
	snapshot._visited += 1
	if depth > _SNAPSHOT_MAX_DEPTH or snapshot._visited > _SNAPSHOT_MAX_NODES:
		snapshot._comparable = false
		return null
	snapshot._types.append(str(typeof(value)))
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		snapshot._comparable = false
		return null
	if value is Array or value is Dictionary:
		for ancestor: Variant in ancestors:
			if is_same(ancestor, value):
				snapshot._comparable = false
				return null
		ancestors.append(value)
		var result: Variant = null
		if value is Array:
			var source: Array = value
			snapshot._types.append("a:%s:%s:%s" % [source.get_typed_builtin(), source.get_typed_class_name(), _script_identity(source.get_typed_script())])
			var copied: Array = []
			if source.size() > _SNAPSHOT_MAX_NODES:
				snapshot._comparable = false
			for child: Variant in source:
				if not snapshot._comparable:
					break
				copied.append(_copy_comparable(child, snapshot, ancestors, depth + 1))
			result = copied
		else:
			var source: Dictionary = value
			snapshot._types.append("d:%s:%s:%s:%s:%s:%s" % [
				source.get_typed_key_builtin(), source.get_typed_key_class_name(), _script_identity(source.get_typed_key_script()),
				source.get_typed_value_builtin(), source.get_typed_value_class_name(), _script_identity(source.get_typed_value_script()),
			])
			var copied: Dictionary = {}
			if source.size() > _SNAPSHOT_MAX_NODES:
				snapshot._comparable = false
			for key: Variant in source:
				if not snapshot._comparable:
					break
				if key != null and not GFVariantKeyCodec.is_stable_key(key):
					snapshot._comparable = false
					break
				snapshot._types.append("key:" + _key_token(key))
				copied[key] = _copy_comparable(source[key], snapshot, ancestors, depth + 1)
			result = copied
		var _removed_ancestor: Variant = ancestors.pop_back()
		return result
	return GFVariantData.duplicate_variant(value)


## 返回有效 Object 的实例 id；非 Object 或已失效实例返回 0。
## [br]
## @api private
static func _script_identity(value: Variant) -> int:
	if value is Object and is_instance_valid(value):
		var object: Object = value
		return object.get_instance_id()
	return 0


## 仅当两个快照都可比较时，比较其类型记录和值。
## [br]
## @api private
static func _same_snapshot(left: _Snapshot, right: _Snapshot) -> bool:
	if left == null or not left._comparable or not right._comparable:
		return false
	return left._types == right._types and left._value == right._value


## 统一构造包含状态、节点和创建/复用/移除计数的同步报告。
## [br]
## @api private
static func _report(error: StringName, nodes: Array[Node] = [], created: int = 0, reused: int = 0, removed: int = 0) -> Dictionary:
	return {
		"ok": error.is_empty(),
		"error": error,
		"nodes": nodes,
		"created_count": created,
		"reused_count": reused,
		"removed_count": removed,
	}


# --- 内部类 ---

## 保存单个容器分组当前同步状态及已提交行记录。
## [br]
## @api private
class _Group extends RefCounted:

	# --- 私有变量 ---

	## 组所属容器的弱引用，用于验证归属而不延长容器生命周期。
	## [br]
	## @api private
	var _container_ref: WeakRef = null

	## 正在同步的可选绑定令牌弱引用；限定 interrupt 的作用对象，完成后清空。
	## [br]
	## @api private
	var _sync_owner_ref: WeakRef = null

	## 同步、清理或中断时递增的代次，供项目回调返回后检查操作是否仍有效。
	## [br]
	## @api private
	var _epoch: int = 0

	## 同步期间的重入门禁，与清理标志共同阻止同组再次同步。
	## [br]
	## @api private
	var _busy: bool = false

	## 清理克隆的重入门禁；重复清理可使代次失效，但不会递归移除节点。
	## [br]
	## @api private
	var _clearing: bool = false

	## 上次成功同步的模板弱引用，与复制标志共同决定旧行能否复用。
	## [br]
	## @api private
	var _template_ref: WeakRef = null

	## 上次成功同步的节点复制标志；初始 -1 表示尚无已提交配置。
	## [br]
	## @api private
	var _flags: int = -1

	## 当前拥有的行记录，只弱引用节点；清理或计划提交时更新。
	## [br]
	## @api private
	var _rows: Array[_Row] = []


## 保存一个重复行节点的弱引用、identity 及上次配置比较数据。
## [br]
## @api private
class _Row extends RefCounted:

	# --- 私有变量 ---

	## 行节点弱引用；复用前仍须核对存活、父容器和所有权标记。
	## [br]
	## @api private
	var _node_ref: WeakRef = null

	## 稳定 identity 的编码，用于跨同步匹配旧行；无 identity 时为空。
	## [br]
	## @api private
	var _token: String = ""

	## 上次配置的条目下标；下标变化触发重新配置。
	## [br]
	## @api private
	var _index: int = -1

	## 上次配置的文本字段名；选项变化时不能只凭值相等跳过更新。
	## [br]
	## @api private
	var _text_key: StringName = &""

	## 上次配置成功的比较快照；不可比较的数据每次都需要更新。
	## [br]
	## @api private
	var _snapshot: _Snapshot = null


## 保存条目是否可比较以及构建出的比较值和类型记录。
## [br]
## @api private
class _Snapshot extends RefCounted:

	# --- 私有变量 ---

	## 遇到循环、对象、非法键或预算越界即置 false，使快照不能用于跳过配置。
	## [br]
	## @api private
	var _comparable: bool = true

	## 递归访问值的累计次数，包含容器节点，供快照规模上限检查。
	## [br]
	## @api private
	var _visited: int = 0

	## 可比较条目的复制值；任一子值不可比较时入口最终将其清空。
	## [br]
	## @api private
	var _value: Variant = null

	## 遍历记录的值类型、容器类型信息及字典键编码，与值一起比较以保留类型差异。
	## [br]
	## @api private
	var _types: Array[String] = []


## 描述一个目标条目及其候选行节点的同步计划。
## [br]
## @api private
class _Plan extends RefCounted:

	# --- 私有变量 ---

	## 本轮目标节点，来自旧行或模板副本；回调后仍须重验归属。
	## [br]
	## @api private
	var _node: Node = null

	## 最终提交的行记录；新节点新建记录，复用节点继续使用旧记录。
	## [br]
	## @api private
	var _row: _Row = null

	## 本轮条目值；可比较值已复制，不可比较值可能保留调用方引用。
	## [br]
	## @api private
	var _item: Variant = null

	## 本轮目标条目下标，用于节点元数据和配置回调。
	## [br]
	## @api private
	var _index: int = -1

	## 本轮已验证的 identity 编码，成功后写入行记录。
	## [br]
	## @api private
	var _token: String = ""

	## 是否由本轮复制产生，决定挂载与创建计数。
	## [br]
	## @api private
	var _created: bool = false

	## 是否需要更新节点；复用行只在下标、文本键或快照变化时更新。
	## [br]
	## @api private
	var _configure: bool = true

	## 本轮比较快照，配置成功后取代旧行快照。
	## [br]
	## @api private
	var _snapshot: _Snapshot = null


## 收集单次同步请求的目标、选项、代数及阶段性计划。
## [br]
## @api private
class _Context extends RefCounted:

	# --- 私有变量 ---

	## 本轮目标容器引用，每次可重入操作后重新检查其有效性。
	## [br]
	## @api private
	var _container: Node = null

	## 本轮复制模板，必须与容器不同且不属于本组克隆。
	## [br]
	## @api private
	var _template: Node = null

	## 共享组状态；回调可能中断它，不能仅凭引用存在判断本轮有效。
	## [br]
	## @api private
	var _group: _Group = null

	## 容器内组标识，写入新节点元数据并用于归属判断。
	## [br]
	## @api private
	var _group_key: StringName = &""

	## 入口捕获的组代次，与共享组不同表示本轮被中断。
	## [br]
	## @api private
	var _epoch: int = 0

	## 入口时容器是否在树内；原本在树内的容器离树会使本轮失效。
	## [br]
	## @api private
	var _was_inside_tree: bool = false

	## 入口浅复制的选项字典，隔离键级替换但不保证嵌套值独立。
	## [br]
	## @api private
	var _options: Dictionary = {}

	## 入口逐项准备的数据；可比较项复制，不可比较项保持原值。
	## [br]
	## @api private
	var _items: Array = []

	## 按条目顺序保存已规划的节点更新。
	## [br]
	## @api private
	var _plans: Array[_Plan] = []

	## 本轮复制节点清单，失败时清理仍可安全退役的实例。
	## [br]
	## @api private
	var _new_nodes: Array[Node] = []
