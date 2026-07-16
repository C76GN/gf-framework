@tool
extends EditorPlugin


# --- 枚举 ---

enum SmokePhase {
	WAIT_STARTUP,
	WAIT_DIALOG,
	WAIT_EXTENSION_PROPERTY,
	WAIT_CODEGEN_PROPERTY,
	WAIT_NETWORK_PROPERTY,
	WAIT_NETWORK_PATH_ROW,
	WAIT_RESOURCE_DIALOG,
}


# --- 常量 ---

const _GF_PLUGIN_INSPECTOR_TOOLS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_inspector_tools.gd")
const _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")
const _GF_EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const _GF_NETWORK_EDITOR_ACTIONS_SCRIPT = preload("res://addons/gf/extensions/network/editor/gf_network_editor_actions.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _STANDARD_CONTRIBUTIONS_PATH: String = "res://addons/gf/standard/editor/gf_editor_contributions.json"
const _EXTENSIONS_SECTION: String = "gf/extensions"
const _CODEGEN_SECTION: String = "gf/codegen"
const _NETWORK_SECTION: String = "gf/network"
const _DIALOG_CLASS: String = "ProjectSettingsEditor"
const _RESOURCE_PATH_BROWSE_BUTTON_NAME: StringName = &"ResourcePathBrowseButton"
const _STARTUP_FRAME_COUNT: int = 3
const _UI_WAIT_FRAME_LIMIT: int = 180


# --- 私有变量 ---

var _remaining_startup_frames: int = _STARTUP_FRAME_COUNT
var _remaining_ui_wait_frames: int = _UI_WAIT_FRAME_LIMIT
var _phase: SmokePhase = SmokePhase.WAIT_STARTUP
var _finished: bool = false
var _inspector_tools: RefCounted = null


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	var records: Dictionary = _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_records(
		_STANDARD_CONTRIBUTIONS_PATH
	)
	var network_actions_value: Variant = _GF_NETWORK_EDITOR_ACTIONS_SCRIPT.new()
	if not network_actions_value is RefCounted:
		_fail("network editor action provider could not be instantiated")
		return
	var network_actions: RefCounted = network_actions_value
	_append_records(
		records,
		"project_setting_records",
		network_actions.call(&"get_project_setting_records")
	)
	_append_records(
		records,
		"project_setting_section_records",
		network_actions.call(&"get_project_setting_section_records")
	)
	_GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.ensure_all(
		_to_record_array(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(records, "project_setting_records", []))
	)

	var inspector_tools_value: Variant = _GF_PLUGIN_INSPECTOR_TOOLS_SCRIPT.new()
	if not inspector_tools_value is RefCounted:
		_fail("project settings inspector tools could not be instantiated")
		return
	_inspector_tools = inspector_tools_value
	var _setup_result: Variant = _inspector_tools.call(&"setup", self, records, "zh_CN")

	var connect_error: int = get_tree().process_frame.connect(_on_process_frame)
	if connect_error != OK:
		_fail("editor process frame signal could not be connected")


func _exit_tree() -> void:
	var process_frame_signal: Signal = get_tree().process_frame
	if process_frame_signal.is_connected(_on_process_frame):
		process_frame_signal.disconnect(_on_process_frame)
	if _inspector_tools != null:
		var _cleanup_result: Variant = _inspector_tools.call(&"cleanup", self)
		_inspector_tools = null


# --- 信号回调方法 ---

func _on_process_frame() -> void:
	var resource_filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if resource_filesystem != null and resource_filesystem.is_scanning():
		return
	match _phase:
		SmokePhase.WAIT_STARTUP:
			_remaining_startup_frames -= 1
			if _remaining_startup_frames > 0:
				return
			_open_project_settings()
			_phase = SmokePhase.WAIT_DIALOG
		SmokePhase.WAIT_DIALOG:
			var project_settings_dialog: Window = _find_project_settings_dialog()
			if project_settings_dialog == null or not project_settings_dialog.visible:
				_wait_or_fail("project settings dialog did not open")
				return
			if not _select_project_settings_section(project_settings_dialog, _EXTENSIONS_SECTION):
				_wait_or_fail("GF extensions section was not available")
				return
			_remaining_ui_wait_frames = _UI_WAIT_FRAME_LIMIT
			_phase = SmokePhase.WAIT_EXTENSION_PROPERTY
		SmokePhase.WAIT_EXTENSION_PROPERTY:
			var project_settings_dialog: Window = _find_project_settings_dialog()
			if project_settings_dialog == null:
				_wait_or_fail("project settings dialog disappeared")
				return
			var editor_property: EditorProperty = _find_editor_property(
				project_settings_dialog,
				"selection_mode"
			)
			if editor_property == null:
				_wait_or_fail("selection mode editor property was not rendered")
				return
			_run_extension_smoke(project_settings_dialog, editor_property)
		SmokePhase.WAIT_CODEGEN_PROPERTY:
			var project_settings_dialog: Window = _find_project_settings_dialog()
			if project_settings_dialog == null:
				_wait_or_fail("project settings dialog disappeared before codegen check")
				return
			var editor_property: EditorProperty = _find_editor_property(
				project_settings_dialog,
				"access_output_path"
			)
			if editor_property == null:
				_wait_or_fail("codegen access output editor property was not rendered")
				return
			_run_codegen_smoke(project_settings_dialog, editor_property)
		SmokePhase.WAIT_NETWORK_PROPERTY:
			var project_settings_dialog: Window = _find_project_settings_dialog()
			if project_settings_dialog == null:
				_wait_or_fail("project settings dialog disappeared before network check")
				return
			var editor_property: EditorProperty = _find_editor_property(
				project_settings_dialog,
				"contract_paths"
			)
			if editor_property == null:
				_wait_or_fail("network contract paths editor property was not rendered")
				return
			_run_network_smoke(project_settings_dialog, editor_property)
		SmokePhase.WAIT_NETWORK_PATH_ROW:
			var project_settings_dialog: Window = _find_project_settings_dialog()
			if project_settings_dialog == null:
				_wait_or_fail("project settings dialog disappeared before resource picker check")
				return
			var editor_property: EditorProperty = _find_editor_property(
				project_settings_dialog,
				"contract_paths"
			)
			if editor_property == null:
				_wait_or_fail("network contract paths editor disappeared")
				return
			_run_resource_picker_parent_smoke(project_settings_dialog, editor_property)
		SmokePhase.WAIT_RESOURCE_DIALOG:
			_run_resource_dialog_smoke()


# --- 私有/辅助方法 ---

func _run_extension_smoke(
	project_settings_dialog: Window,
	editor_property: EditorProperty
) -> void:
	if editor_property.get_label() != "扩展选择模式":
		_fail(
			"extension row label was not localized: %s" % editor_property.get_label()
		)
		return
	var option_button: OptionButton = _find_option_button(editor_property)
	if option_button == null:
		_fail("native String enum editor has no OptionButton")
		return
	if option_button.item_count != 2:
		_fail("selection mode enum option count changed")
		return
	if option_button.get_item_text(0) != "跟随清单默认值":
		_fail("default option was not localized")
		return
	if option_button.get_item_text(1) != "显式选择":
		_fail("explicit option was not localized")
		return
	if _GF_VARIANT_ACCESS_SCRIPT.to_text(option_button.get_item_metadata(0)) != "default":
		_fail("default stable value changed")
		return
	if _GF_VARIANT_ACCESS_SCRIPT.to_text(option_button.get_item_metadata(1)) != "explicit":
		_fail("explicit stable value changed")
		return
	if not option_button.tooltip_text.contains("决定启用扩展"):
		_fail("localized value-control tooltip is missing")
		return

	var tooltip_text: String = _get_custom_tooltip_text(editor_property)
	if _finished:
		return
	if not tooltip_text.contains("决定启用扩展"):
		_fail("localized property tooltip is missing")
		return
	if not tooltip_text.contains(_GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING):
		_fail("property tooltip did not retain the stable setting key")
		return
	if not _select_project_settings_section(project_settings_dialog, _CODEGEN_SECTION):
		_fail("GF codegen section was not available")
		return
	_remaining_ui_wait_frames = _UI_WAIT_FRAME_LIMIT
	_phase = SmokePhase.WAIT_CODEGEN_PROPERTY


func _run_codegen_smoke(
	project_settings_dialog: Window,
	editor_property: EditorProperty
) -> void:
	if editor_property.get_label() != "框架访问器输出路径":
		_fail("codegen row label was not localized: %s" % editor_property.get_label())
		return
	var script_value: Variant = editor_property.get_script()
	if script_value is Script:
		var editor_script: Script = script_value
		if editor_script.resource_path.ends_with("gf_resource_path_editor_property.gd"):
			_fail("codegen save target was incorrectly treated as an existing resource")
			return
	var path_edit: LineEdit = _find_line_edit_containing(
		editor_property,
		_GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.ACCESS_OUTPUT_DEFAULT
	)
	if path_edit == null:
		_fail("codegen save target did not retain its native path text")
		return
	var tooltip_text: String = _get_custom_tooltip_text(editor_property)
	if _finished:
		return
	if not tooltip_text.contains("生成 GF 框架类型访问器"):
		_fail("codegen resource path editor has no localized tooltip")
		return
	if not tooltip_text.contains(_GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.ACCESS_OUTPUT_SETTING):
		_fail("codegen tooltip did not retain the stable setting key")
		return
	if not _select_project_settings_section(project_settings_dialog, _NETWORK_SECTION):
		_fail("GF network section was not available")
		return
	_remaining_ui_wait_frames = _UI_WAIT_FRAME_LIMIT
	_phase = SmokePhase.WAIT_NETWORK_PROPERTY


func _run_network_smoke(
	project_settings_dialog: Window,
	editor_property: EditorProperty
) -> void:
	if editor_property.get_label() != "网络契约路径":
		_fail("network row label was not localized: %s" % editor_property.get_label())
		return
	var script_value: Variant = editor_property.get_script()
	if not script_value is Script:
		_fail(
			"network contract paths did not use the resource path array editor: %s"
			% _describe_editor_property(editor_property)
		)
		return
	var editor_script: Script = script_value
	if not editor_script.resource_path.ends_with("gf_resource_path_array_editor_property.gd"):
		_fail(
			"network contract paths did not retain the specialized array editor: script=%s %s"
			% [editor_script.resource_path, _describe_editor_property(editor_property)]
		)
		return
	var tooltip_text: String = _get_custom_tooltip_text(editor_property)
	if _finished:
		return
	if not tooltip_text.contains("GFNetworkContract"):
		_fail("network resource path editor has no localized tooltip")
		return
	for section_expectation: Dictionary in [
		{"path": "gf", "label": "GF"},
		{"path": _CODEGEN_SECTION, "label": "代码生成"},
		{"path": _EXTENSIONS_SECTION, "label": "扩展"},
		{"path": _NETWORK_SECTION, "label": "网络"},
		{"path": "gf/build", "label": "构建"},
	]:
		if not _check_section_presentation(project_settings_dialog, section_expectation):
			return
	var add_button: Button = _find_button_by_tooltip(editor_property, "添加资源路径")
	if add_button == null:
		_fail("network resource path array has no add command")
		return
	add_button.pressed.emit()
	_remaining_ui_wait_frames = _UI_WAIT_FRAME_LIMIT
	_phase = SmokePhase.WAIT_NETWORK_PATH_ROW


func _run_resource_picker_parent_smoke(
	project_settings_dialog: Window,
	editor_property: EditorProperty
) -> void:
	var browse_button: Button = _find_button_by_name(
		editor_property,
		_RESOURCE_PATH_BROWSE_BUTTON_NAME
	)
	if browse_button == null:
		_wait_or_fail("resource path row did not create a browse button")
		return
	var file_dialog: EditorFileDialog = _find_editor_file_dialog(editor_property)
	if file_dialog == null:
		_wait_or_fail("resource path row did not create a local EditorFileDialog")
		return
	if _find_ancestor_window(file_dialog) != project_settings_dialog:
		_fail("resource file dialog is not owned by the active ProjectSettings window")
		return

	browse_button.pressed.emit()
	_remaining_startup_frames = 3
	_phase = SmokePhase.WAIT_RESOURCE_DIALOG


func _run_resource_dialog_smoke() -> void:
	var quick_open_dialog: Window = _find_window_by_class(
		EditorInterface.get_base_control(),
		"EditorQuickOpenDialog"
	)
	if quick_open_dialog != null and quick_open_dialog.visible:
		_fail("resource path browse opened the global EditorQuickOpenDialog")
		return
	_remaining_startup_frames -= 1
	if _remaining_startup_frames > 0:
		return

	var project_settings_dialog: Window = _find_project_settings_dialog()
	if project_settings_dialog == null:
		_fail("project settings dialog disappeared while resource file dialog opened")
		return
	var file_dialog: EditorFileDialog = _find_editor_file_dialog(project_settings_dialog)
	if file_dialog == null:
		_fail("local resource file dialog disappeared")
		return
	file_dialog.hide()

	print("GF_PROJECT_SETTINGS_INSPECTOR_EDITOR_SMOKE_OK")
	_finish(0)


func _get_custom_tooltip_text(editor_property: EditorProperty) -> String:
	var custom_tooltip_value: Variant = editor_property.call(
		&"_make_custom_tooltip",
		editor_property.tooltip_text
	)
	if not custom_tooltip_value is Label:
		_fail("project settings row did not create a plain-text tooltip")
		return ""
	var tooltip_label: Label = custom_tooltip_value
	var tooltip_text: String = tooltip_label.text
	tooltip_label.free()
	return tooltip_text


func _describe_editor_property(editor_property: EditorProperty) -> String:
	var edited_object: Object = editor_property.get_edited_object()
	if edited_object == null:
		return "edited_object=<null>"
	var edited_property: String = String(editor_property.get_edited_property())
	for property_info: Dictionary in edited_object.get_property_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "name") != edited_property:
			continue
		return "type=%d hint=%d hint_string=%s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "type", TYPE_NIL),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "hint", PROPERTY_HINT_NONE),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "hint_string"),
		]
	return "property_info=<missing>"


func _check_section_presentation(root: Node, expectation: Dictionary) -> bool:
	var section_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		expectation,
		"path"
	)
	var expected_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		expectation,
		"label"
	)
	var section_item: TreeItem = _find_section_item(root, section_path)
	if section_item == null:
		_fail("project settings section was not found: %s" % section_path)
		return false
	if section_item.get_text(0) != expected_label:
		_fail(
			"project settings section label was not localized: %s=%s"
			% [section_path, section_item.get_text(0)]
		)
		return false
	if not section_item.get_tooltip_text(0).contains(section_path):
		_fail("project settings section tooltip is missing: %s" % section_path)
		return false
	return true


func _append_records(records: Dictionary, record_key: String, additional_value: Variant) -> void:
	var merged_records: Array[Dictionary] = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(records, record_key, [])
	)
	for additional_record: Dictionary in _to_record_array(additional_value):
		merged_records.append(additional_record)
	records[record_key] = merged_records


func _to_record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not value is Array:
		return records
	var values: Array = value
	for record_value: Variant in values:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			records.append(record.duplicate(true))
	return records


func _open_project_settings() -> void:
	var editor_root: Control = EditorInterface.get_base_control()
	if _activate_project_settings_menu(editor_root):
		return
	var editor_viewport: Viewport = EditorInterface.get_base_control().get_viewport()
	var shortcut_event: InputEventKey = InputEventKey.new()
	shortcut_event.keycode = KEY_COMMA
	shortcut_event.ctrl_pressed = true
	shortcut_event.shift_pressed = true
	shortcut_event.pressed = true
	editor_viewport.push_input(shortcut_event, false)


func _activate_project_settings_menu(root: Node) -> bool:
	if root is PopupMenu:
		var popup_menu: PopupMenu = root
		for item_index: int in range(popup_menu.item_count):
			var item_text: String = popup_menu.get_item_text(item_index)
			if not item_text.contains("Project Settings") and not item_text.contains("项目设置"):
				continue
			var item_id: int = popup_menu.get_item_id(item_index)
			var _emit_result: Error = popup_menu.emit_signal(&"id_pressed", item_id)
			return true
	for child: Node in root.get_children():
		if _activate_project_settings_menu(child):
			return true
	return false


func _find_project_settings_dialog() -> Window:
	return _find_window_by_class(EditorInterface.get_base_control(), _DIALOG_CLASS)


func _find_window_by_class(root: Node, target_class: String) -> Window:
	if root is Window and root.get_class() == target_class:
		var matching_window: Window = root
		return matching_window
	for child: Node in root.get_children():
		var nested_window: Window = _find_window_by_class(child, target_class)
		if nested_window != null:
			return nested_window
	return null


func _select_project_settings_section(root: Node, section: String) -> bool:
	if root is Tree:
		var section_tree: Tree = root
		var root_item: TreeItem = section_tree.get_root()
		var section_item: TreeItem = _find_tree_item_by_metadata(root_item, section)
		if section_item != null:
			section_item.select(0)
			var _emit_result: Error = section_tree.emit_signal(&"cell_selected")
			return true
	for child: Node in root.get_children():
		if _select_project_settings_section(child, section):
			return true
	return false


func _find_section_item(root: Node, section: String) -> TreeItem:
	if root is Tree:
		var section_tree: Tree = root
		var section_item: TreeItem = _find_tree_item_by_metadata(
			section_tree.get_root(),
			section
		)
		if section_item != null:
			return section_item
	for child: Node in root.get_children():
		var nested_item: TreeItem = _find_section_item(child, section)
		if nested_item != null:
			return nested_item
	return null


func _find_tree_item_by_metadata(root_item: TreeItem, metadata: String) -> TreeItem:
	if root_item == null:
		return null
	var item: TreeItem = root_item.get_first_child()
	while item != null:
		var item_metadata: Variant = item.get_metadata(0)
		if item_metadata is String and item_metadata == metadata:
			return item
		var nested_item: TreeItem = _find_tree_item_by_metadata(item, metadata)
		if nested_item != null:
			return nested_item
		item = item.get_next()
	return null


func _find_editor_property(root: Node, property_name: String) -> EditorProperty:
	if root is EditorProperty:
		var editor_property: EditorProperty = root
		if String(editor_property.get_edited_property()) == property_name:
			return editor_property
	for child: Node in root.get_children():
		var nested_property: EditorProperty = _find_editor_property(child, property_name)
		if nested_property != null:
			return nested_property
	return null


func _find_option_button(node: Node) -> OptionButton:
	for child: Node in node.get_children():
		if child is OptionButton:
			var option_button: OptionButton = child
			return option_button
		var nested_option: OptionButton = _find_option_button(child)
		if nested_option != null:
			return nested_option
	return null


func _find_line_edit_containing(node: Node, expected_text: String) -> LineEdit:
	if node is LineEdit:
		var line_edit: LineEdit = node
		if line_edit.text.contains(expected_text):
			return line_edit
	for child: Node in node.get_children():
		var nested_line_edit: LineEdit = _find_line_edit_containing(child, expected_text)
		if nested_line_edit != null:
			return nested_line_edit
	return null


func _find_button_by_name(node: Node, button_name: StringName) -> Button:
	if node is Button and node.name == button_name:
		var matching_button: Button = node
		return matching_button
	for child: Node in node.get_children():
		var nested_button: Button = _find_button_by_name(child, button_name)
		if nested_button != null:
			return nested_button
	return null


func _find_button_by_tooltip(node: Node, tooltip: String) -> Button:
	if node is Button:
		var button: Button = node
		if button.tooltip_text == tooltip:
			return button
	for child: Node in node.get_children():
		var nested_button: Button = _find_button_by_tooltip(child, tooltip)
		if nested_button != null:
			return nested_button
	return null


func _find_editor_file_dialog(node: Node) -> EditorFileDialog:
	if node is EditorFileDialog:
		var file_dialog: EditorFileDialog = node
		return file_dialog
	for child: Node in node.get_children():
		var nested_dialog: EditorFileDialog = _find_editor_file_dialog(child)
		if nested_dialog != null:
			return nested_dialog
	return null


func _find_ancestor_window(node: Node) -> Window:
	var ancestor: Node = node.get_parent()
	while ancestor != null:
		if ancestor is Window:
			var window: Window = ancestor
			return window
		ancestor = ancestor.get_parent()
	return null


func _wait_or_fail(message: String) -> void:
	_remaining_ui_wait_frames -= 1
	if _remaining_ui_wait_frames <= 0:
		_fail(message)


func _fail(message: String) -> void:
	push_error("GF_PROJECT_SETTINGS_INSPECTOR_EDITOR_SMOKE_FAILED: %s" % message)
	_finish(1)


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	var project_settings_dialog: Window = _find_project_settings_dialog()
	if project_settings_dialog != null:
		project_settings_dialog.hide()
	if _inspector_tools != null:
		var _cleanup_result: Variant = _inspector_tools.call(&"cleanup", self)
		_inspector_tools = null
	get_tree().call_deferred(&"quit", exit_code)
