@tool

# GFPersistPropertiesEditorProperty: 在 Inspector 中选择 GFPersistPropertiesSource.properties。
extends EditorProperty


# --- 常量 ---

const _PROPERTY_USAGE_READ_ONLY: int = 268435456
const _MAX_LIST_HEIGHT: float = 180.0


# --- 私有变量 ---

var _root: VBoxContainer
var _target_label: Label
var _search_edit: LineEdit
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _empty_label: Label
var _current_properties: PackedStringArray = PackedStringArray()
var _available_properties: PackedStringArray = PackedStringArray()
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


func _get_source() -> GFPersistPropertiesSource:
	var edited_object: Object = get_edited_object()
	if edited_object is GFPersistPropertiesSource:
		var source: GFPersistPropertiesSource = edited_object
		return source
	return null


func _read_current_properties(source: GFPersistPropertiesSource) -> PackedStringArray:
	return source.properties.duplicate()


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


func _clear_list() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


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


func _passes_filter(property_name: String, filter: String) -> bool:
	return filter.is_empty() or property_name.to_lower().contains(filter)


func _make_property_lookup(properties: PackedStringArray) -> Dictionary:
	var lookup: Dictionary = {}
	for property_name: String in properties:
		lookup[property_name] = true
	return lookup


func _commit_properties(next_properties: PackedStringArray) -> void:
	if _packed_string_arrays_equal(_current_properties, next_properties):
		return
	_current_properties = next_properties
	emit_changed("properties", next_properties)
	_rebuild_property_list()


func _packed_string_arrays_equal(left: PackedStringArray, right: PackedStringArray) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


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

func _on_search_changed(_new_text: String) -> void:
	if _is_updating:
		return
	_rebuild_property_list()


func _on_refresh_pressed() -> void:
	_update_property()


func _on_clear_pressed() -> void:
	_commit_properties(PackedStringArray())


func _on_property_toggled(enabled: bool, property_name: String) -> void:
	if _is_updating:
		return
	_commit_properties(_with_property_toggled(property_name, enabled))
