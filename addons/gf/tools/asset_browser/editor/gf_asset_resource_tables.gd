@tool

# 将显式选择的源 Resource 按真实 Undo history 与资源类型分组。
extends VBoxContainer


# --- 私有变量 ---

## 宿主提供的编辑上下文；撤销上下文后禁用保存，但保留已加载 Resource 的内存修改。
## [br]
## @api private
var _context: GFEditorToolContext = null

## 持有按资源类型与原生 Undo history 分组的表格子节点；更换资源选择时移除并延迟释放旧表格。
## [br]
## @api private
var _tabs: TabContainer = null

## 展示加载拒绝、未保存数量和逐文件保存结果的状态控件，由本容器的节点树管理。
## [br]
## @api private
var _status: Label = null

## 保留显式加载的共享源 Resource 引用并订阅 changed；清理只断开订阅和释放本容器引用，不回退资源字段。
## [br]
## @api private
var _resources: Array[Resource] = []

## 按资源实例 ID 记录读取或最近成功保存时的存储字段哈希，用于脏状态比较；不是可用于恢复内容的快照。
## [br]
## @api private
var _saved_values: Dictionary = {}

## 触发显式逐资源磁盘保存；是否可用随编辑上下文绑定状态更新，不随 Undo 自动保存。
## [br]
## @api private
var _save_button: Button = null


# --- Godot 生命周期方法 ---

## 建立页面树拥有的状态提示、显式保存按钮和分组表格页签；获得宿主上下文前保存按钮禁用。
## [br]
## @api private
func _init() -> void:
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_save_button = Button.new()
	_save_button.text = "保存表格中的源资源"
	_save_button.disabled = true
	var _save_connection: int = _save_button.pressed.connect(_save_resources)
	add_child(_save_button)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)


## 退树时断开资源变更监听并清除本表持有的引用与保存基线；不保存或回滚共享 Resource 对象。
## [br]
## @api private
func _exit_tree() -> void:
	_clear_resources()


# --- 框架内部方法 ---

## 只加载显式所选的独立 tres/res，按真实 history 和类型分组，不把多个 history 拼成一次动作。
## [br]
## @api framework_internal
## [br]
## @param paths: 最多 100 个源资源路径。
## [br]
## @param context: 当前编辑上下文。
## [br]
## @return 加载报告。
## [br]
## @schema return: Dictionary with loaded_count, group_count and rejected_paths.
func show_paths(paths: PackedStringArray, context: GFEditorToolContext) -> Dictionary:
	if has_unsaved_changes():
		_status.text = "当前表格有未保存修改；请先保存或使用 Undo 恢复后再更换选择。"
		return {"loaded_count": _resources.size(), "group_count": _tabs.get_child_count(), "rejected_paths": paths}
	_clear_resources()
	set_editor_context(context)
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var groups: Dictionary[String, Array] = {}
	var rejected: PackedStringArray = PackedStringArray()
	for path: String in paths.slice(0, 100):
		if not is_editable_source_path(path):
			var _rejected: bool = rejected.append(path)
			continue
		var resource: Resource = ResourceLoader.load(path)
		if resource == null or resource.resource_path != path:
			var _rejected: bool = rejected.append(path)
			continue
		var history_id: int = -1
		if context != null and context.undo_manager is EditorUndoRedoManager:
			var manager: EditorUndoRedoManager = context.undo_manager
			history_id = manager.get_object_history_id(resource)
		var script: Script = resource.get_script()
		var resource_type: String = script.resource_path if script != null else resource.get_class()
		var group_key: String = "%d:%s" % [history_id, resource_type]
		var group: Array[Resource] = []
		if groups.has(group_key):
			group.assign(groups[group_key])
		group.append(resource)
		groups[group_key] = group
		_resources.append(resource)
		_saved_values[resource.get_instance_id()] = _fingerprint(resource)
		var _changed_connection: int = resource.changed.connect(_on_resource_changed)
	for group_key: String in groups:
		var group: Array[Resource] = []
		group.assign(groups[group_key])
		var table: GFResourceTableEditor = GFResourceTableEditor.new()
		table.name = "组 %d · %d 项" % [_tabs.get_child_count() + 1, group.size()]
		table.set_editor_context(context)
		table.auto_save_committed_resources = false
		table.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tabs.add_child(table)
		table.load_resources(group)
	_status.text = "%d 个源资源，%d 个独立 Undo 分组。跳过 %d 项；每组独立撤销，磁盘保存逐文件执行。" % [_resources.size(), groups.size(), rejected.size()]
	if not rejected.is_empty():
		_status.text += "\n只读或不支持：" + ", ".join(rejected)
	return {"loaded_count": _resources.size(), "group_count": groups.size(), "rejected_paths": rejected}


## 检查当前受管源资源是否与读取或最近成功保存的字段状态不同。
## [br]
## @api framework_internal
## [br]
## @return 是否仍需显式保存。
func has_unsaved_changes() -> bool:
	for resource: Resource in _resources:
		if _saved_values.get(resource.get_instance_id()) != _fingerprint(resource):
			return true
	return false


## 宿主卸载时撤销全部表格编辑上下文，不丢弃内存里的 Resource 修改。
## [br]
## @api framework_internal
func release_context() -> void:
	set_editor_context(null)


## 同步已有表格与保存按钮的上下文，重新绑定时保留未保存的资源字段。
## [br]
## @api framework_internal
## [br]
## @param context: 当前编辑上下文或 null。
func set_editor_context(context: GFEditorToolContext) -> void:
	_context = context
	_save_button.disabled = context == null
	for child: Node in _tabs.get_children():
		if child is GFResourceTableEditor:
			var table: GFResourceTableEditor = child
			table.set_editor_context(context)


## 判断是否为独立的项目原生源资源；导入结果与场景子资源交给原生 Inspector。
## [br]
## @api framework_internal
## [br]
## @param path: 待编辑路径。
## [br]
## @return 是否允许进入保存流程。
static func is_editable_source_path(path: String) -> bool:
	return path.begins_with("res://") and not path.contains("::") and not path.contains("..") and path.get_extension().to_lower() in ["tres", "res"] and not FileAccess.file_exists(path + ".import")


# --- 私有/辅助方法 ---

## 断开当前资源的 changed 订阅，清空引用与保存基线并撤销本地上下文；不保存、回滚或释放外部共享资源。
## [br]
## @api private
func _clear_resources() -> void:
	for resource: Resource in _resources:
		if resource.changed.is_connected(_on_resource_changed):
			resource.changed.disconnect(_on_resource_changed)
	_resources.clear()
	_saved_values.clear()
	_context = null


## 按属性列表顺序汇集带 STORAGE usage 的当前值并取哈希，供读取/保存基线比较；不复制资源或读取磁盘。
## [br]
## @api private
func _fingerprint(resource: Resource) -> int:
	var values: Array = []
	for property: Dictionary in resource.get_property_list():
		if (GFVariantData.get_option_int(property, "usage") & PROPERTY_USAGE_STORAGE) != 0:
			values.append(resource.get(GFVariantData.get_option_string_name(property, "name")))
	return hash(values)


## 有编辑上下文时逐个保存脏资源，并在写入前重新确认独立源路径；只更新成功项的基线，失败项保留脏状态，整批不提供原子提交。
## [br]
## @api private
func _save_resources() -> void:
	if _context == null:
		_status.text = "编辑上下文已撤销，无法保存源资源。"
		return
	var failures: PackedStringArray = PackedStringArray()
	var saved_count: int = 0
	for resource: Resource in _resources:
		if _saved_values.get(resource.get_instance_id()) == _fingerprint(resource):
			continue
		var path: String = resource.resource_path
		if not is_editable_source_path(path):
			var _rejected: bool = failures.append(path + "：当前不是可保存源资源")
			continue
		var error: Error = ResourceSaver.save(resource, path)
		if error != OK:
			var _failed: bool = failures.append(path + "：" + error_string(error))
		else:
			_saved_values[resource.get_instance_id()] = _fingerprint(resource)
			saved_count += 1
	_status.text = "已保存 %d 项；失败 %d 项。磁盘保存不随属性 Undo 自动撤销。" % [saved_count, failures.size()]
	if not failures.is_empty():
		_status.text += "\n" + "\n".join(failures)


# --- 信号处理函数 ---

## 重新比较全部已加载资源与各自保存基线，显示仍需显式保存的数量；资源 changed 通知本身不触发磁盘写入。
## [br]
## @api private
func _on_resource_changed() -> void:
	var dirty_count: int = 0
	for resource: Resource in _resources:
		if _saved_values.get(resource.get_instance_id()) != _fingerprint(resource):
			dirty_count += 1
	_status.text = "%d / %d 个源资源与本次读取或保存状态不同；请显式保存。不同页签独立 Undo。" % [dirty_count, _resources.size()]
