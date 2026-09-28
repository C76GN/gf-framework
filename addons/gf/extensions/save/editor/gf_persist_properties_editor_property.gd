@tool

# GFPersistPropertiesEditorProperty: 在 Inspector 中选择 GFPersistPropertiesSource.properties。
extends EditorProperty


# --- 常量 ---

## 属性列表筛选时用来排除只读属性的 usage 标志。
## [br]
## @api private
## [br]
const _PROPERTY_USAGE_READ_ONLY: int = 268435456

## 属性选择列表滚动区域的最大高度。
## [br]
## @api private
## [br]
const _MAX_LIST_HEIGHT: float = 180.0


# --- 私有变量 ---

## Inspector 属性编辑器的根容器。
## [br]
## @api private
## [br]
var _root: VBoxContainer

## 显示当前目标节点的标签。
## [br]
## @api private
## [br]
var _target_label: Label

## 属性名过滤输入框。
## [br]
## @api private
## [br]
var _search_edit: LineEdit

## 包围属性选择列表的滚动容器。
## [br]
## @api private
## [br]
var _list_scroll: ScrollContainer

## 显示属性复选框的容器。
## [br]
## @api private
## [br]
var _list: VBoxContainer

## 当前筛选结果为空时显示的标签。
## [br]
## @api private
## [br]
var _empty_label: Label

## 编辑开始时读取的属性白名单。
## [br]
## @api private
## [br]
var _current_properties: PackedStringArray = PackedStringArray()

## 当前目标可选择的属性名列表。
## [br]
## @api private
## [br]
var _available_properties: PackedStringArray = PackedStringArray()

## 标记属性列表正在重建期间。
## [br]
## @api private
## [br]
var _is_updating: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root)

	_target_label = Label.new()
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	_target_label.modulate = Color(0.75, 0.75, 0.75)
	_root.add_child(_target_label)

	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(toolbar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "筛选属性"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _search_connected: int = _search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_edit)

	var refresh_button: Button = Button.new()
	refresh_button.text = "刷新"
	refresh_button.tooltip_text = "重新扫描目标节点属性。"
	var _refresh_connected: int = refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)

	var clear_button: Button = Button.new()
	clear_button.text = "清空"
	clear_button.tooltip_text = "清空已选择的属性白名单。"
	var _clear_connected: int = clear_button.pressed.connect(_on_clear_pressed)
	toolbar.add_child(clear_button)

	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size = Vector2(0.0, _MAX_LIST_HEIGHT)
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_list_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	_empty_label.modulate = Color(0.75, 0.75, 0.75)
	_root.add_child(_empty_label)


# --- Godot 回调方法 ---

func _update_property() -> void:
	var source: GFPersistPropertiesSource = _get_source()
	if source == null:
		return

	_is_updating = true
	_current_properties = _read_current_properties(source)
	var target: Node = source.get_target_node()
	_available_properties = collect_storable_property_names(target)
	_update_target_label(source, target)
	_rebuild_property_list()
	_is_updating = false


# --- 框架内部方法 ---

## 收集适合在属性白名单中选择的可编辑、可存储属性名。
## [br]
## @api framework_internal
## [br]
## @layer extensions/save/editor
## [br]
## @param target: 要扫描的目标对象。
## [br]
## @return 可选择属性名列表。
## [br]
## @schema return: PackedStringArray，包含属性名字符串。
static func collect_storable_property_names(target: Object) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if target == null:
		return names

	var used: Dictionary = {}
	for property_info: Dictionary in target.get_property_list():
		if not _is_selectable_property(property_info):
			continue
		var property_name: String = GFVariantData.get_option_string(property_info, "name")
		if used.has(property_name):
			continue
		used[property_name] = true
		var _property_name_appended: bool = names.append(property_name)

	names.sort()
	return names


# --- 私有/辅助方法 ---

## 检查属性是否为非私有、可存储、可编辑且有具体类型的字段。
## [br]
## @api private
## [br]
static func _is_selectable_property(property_info: Dictionary) -> bool:
	var property_name: String = GFVariantData.get_option_string(property_info, "name")
	if property_name.is_empty():
		return false
	if property_name == "script" or property_name.begins_with("_"):
		return false
	if property_name.contains("/") or property_name.contains(":"):
		return false

	var usage: int = GFVariantData.get_option_int(property_info, "usage")
	if (usage & PROPERTY_USAGE_STORAGE) == 0:
		return false
	if (usage & PROPERTY_USAGE_EDITOR) == 0:
		return false
	if (usage & _PROPERTY_USAGE_READ_ONLY) != 0:
		return false

	var property_type: int = GFVariantData.get_option_int(property_info, "type", TYPE_NIL)
	return property_type != TYPE_NIL


## 将当前 Inspector 对象转为 GFPersistPropertiesSource。
## [br]
## @api private
## [br]
func _get_source() -> GFPersistPropertiesSource:
	var edited_object: Object = get_edited_object()
	if edited_object is GFPersistPropertiesSource:
		var source: GFPersistPropertiesSource = edited_object
		return source
	return null


## 读取 Source 中当前的属性白名单。
## [br]
## @api private
## [br]
func _read_current_properties(source: GFPersistPropertiesSource) -> PackedStringArray:
	return source.properties.duplicate()


## 更新目标节点标签；优先显示场景树路径。
## [br]
## @api private
## [br]
func _update_target_label(source: GFPersistPropertiesSource, target: Node) -> void:
	if target == null:
		_target_label.text = "目标节点：未找到"
		return

	var target_text: String = String(target.name)
	if target.is_inside_tree():
		target_text = String(target.get_path())
	elif source.is_inside_tree():
		if source.is_ancestor_of(target):
			target_text = String(source.get_path_to(target))
		else:
			target_text = String(target.name)
	_target_label.text = "目标节点：%s" % target_text


## 按筛选文本重建可用和当前已选属性的复选框列表。
## [br]
## @api private
## [br]
func _rebuild_property_list() -> void:
	_clear_list()

	var selected_lookup: Dictionary = _make_property_lookup(_current_properties)
	var available_lookup: Dictionary = _make_property_lookup(_available_properties)
	var filter: String = _search_edit.text.strip_edges().to_lower()
	var rendered_count: int = 0

	for property_name: String in _available_properties:
		if not _passes_filter(property_name, filter):
			continue
		_list.add_child(_make_property_checkbox(property_name, true, selected_lookup.has(property_name)))
		rendered_count += 1

	for property_name: String in _current_properties:
		if available_lookup.has(property_name) or not _passes_filter(property_name, filter):
			continue
		_list.add_child(_make_property_checkbox(property_name, false, true))
		rendered_count += 1

	_empty_label.visible = rendered_count == 0
	_list_scroll.visible = rendered_count > 0
	if rendered_count == 0:
		_empty_label.text = "没有可选择属性。" if filter.is_empty() else "没有匹配的属性。"


## 移除并释放当前列表中的子控件。
## [br]
## @api private
## [br]
func _clear_list() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


## 创建一个属性复选框，并绑定对应属性名的切换回调。
## [br]
## @api private
## [br]
func _make_property_checkbox(property_name: String, available: bool, should_select: bool) -> CheckBox:
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = property_name if available else "%s（未找到）" % property_name
	checkbox.tooltip_text = "保存并恢复目标节点属性：%s" % property_name if available else "该属性当前不在目标节点上。"
	checkbox.button_pressed = should_select
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not available:
		checkbox.modulate = Color(1.0, 0.78, 0.35)
	var _checkbox_connected: int = checkbox.toggled.connect(_on_property_toggled.bind(property_name))
	return checkbox


## 判断属性名是否符合空筛选或不区分大小写的子串筛选。
## [br]
## @api private
## [br]
func _passes_filter(property_name: String, filter: String) -> bool:
	return filter.is_empty() or property_name.to_lower().contains(filter)


## 将属性名列表转换为以属性名为键的查找字典。
## [br]
## @api private
## [br]
func _make_property_lookup(properties: PackedStringArray) -> Dictionary:
	var lookup: Dictionary = {}
	for property_name: String in properties:
		lookup[property_name] = true
	return lookup


## 属性白名单改变时发出属性更新并刷新列表。
## [br]
## @api private
## [br]
func _commit_properties(next_properties: PackedStringArray) -> void:
	if _packed_string_arrays_equal(_current_properties, next_properties):
		return
	_current_properties = next_properties
	emit_changed("properties", next_properties)
	_rebuild_property_list()


## 按元素顺序比较两个 PackedStringArray。
## [br]
## @api private
## [br]
func _packed_string_arrays_equal(left: PackedStringArray, right: PackedStringArray) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


## 将属性名按启用状态加入白名单或移除。
## [br]
## @api private
## [br]
func _with_property_toggled(property_name: String, enabled: bool) -> PackedStringArray:
	var next_properties: PackedStringArray = _current_properties.duplicate()
	var index: int = next_properties.find(property_name)
	if enabled:
		if index == -1:
			var _property_name_appended: bool = next_properties.append(property_name)
	elif index >= 0:
		next_properties.remove_at(index)
	return next_properties


# --- 信号处理函数 ---

## 搜索文本变化时刷新属性列表。
## [br]
## @api private
## [br]
func _on_search_changed(_new_text: String) -> void:
	if _is_updating:
		return
	_rebuild_property_list()


## 刷新按钮回调，重新读取目标属性。
## [br]
## @api private
## [br]
func _on_refresh_pressed() -> void:
	_update_property()


## 清空按钮回调，提交空属性白名单。
## [br]
## @api private
## [br]
func _on_clear_pressed() -> void:
	_commit_properties(PackedStringArray())


## 属性复选框回调，提交更新后的白名单。
## [br]
## @api private
## [br]
func _on_property_toggled(enabled: bool, property_name: String) -> void:
	if _is_updating:
		return
	_commit_properties(_with_property_toggled(property_name, enabled))
