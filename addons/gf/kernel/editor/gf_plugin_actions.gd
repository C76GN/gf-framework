@tool

# GF 插件菜单动作与脚本模板生成辅助。
extends RefCounted


# --- 信号 ---

## 请求打开 GF 编辑器工作区。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
signal workspace_requested

## 请求刷新 GF 编辑器贡献记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
signal editor_contributions_refresh_requested


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 菜单 ID：生成 System。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_GENERATE_SYSTEM: int = 0

## 菜单 ID：生成 Model。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_GENERATE_MODEL: int = 1

## 菜单 ID：生成 Utility。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_GENERATE_UTILITY: int = 2

## 菜单 ID：生成 Command。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_GENERATE_COMMAND: int = 3

## 菜单 ID：打开工作区。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_OPEN_WORKSPACE: int = 10

## 菜单 ID：生成强类型访问器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_GENERATE_ACCESSORS: int = 11

## 菜单 ID：生成项目常量访问器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_GENERATE_PROJECT_ACCESSORS: int = 12

## 菜单 ID：刷新 GF 编辑器贡献记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MENU_REFRESH_EDITOR_CONTRIBUTIONS: int = 13

## 扩展模板菜单 ID 起始值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const TEMPLATE_MENU_ID_START: int = 100

## 扩展动作菜单 ID 起始值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EXTENSION_MENU_ID_START: int = 1000

## 强类型访问器生成器脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACCESS_GENERATOR_SCRIPT_PATH: String = "res://addons/gf/kernel/editor/gf_access_generator.gd"

## 诊断对话框最小尺寸。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DIAGNOSTIC_DIALOG_MIN_SIZE: Vector2 = Vector2(720.0, 460.0)

## 菜单分组：核心模板。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const SECTION_CORE_TEMPLATES: String = "核心模块"

## 菜单分组：扩展模板。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const SECTION_EXTENSION_TEMPLATES: String = "扩展模板"

## 菜单分组：代码生成。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const SECTION_CODE_GENERATION: String = "代码生成"

## 菜单分组：扩展工具。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const SECTION_EXTENSION_TOOLS: String = "扩展工具"

## GF ProjectSettings 注册辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFPluginProjectSettings = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

var _file_dialog: FileDialog
var _current_template_type: String = ""
var _diagnostic_dialog: AcceptDialog
var _diagnostic_output: TextEdit
var _extension_action_records: Array[Dictionary] = []
var _menu_action_handlers: Dictionary = {}
var _menu_entries: Array[Dictionary] = []
var _template_records: Dictionary = {}
var _next_template_menu_id: int = TEMPLATE_MENU_ID_START
var _next_extension_menu_id: int = EXTENSION_MENU_ID_START


# --- 公共方法 ---

## 初始化菜单动作需要的文件对话框。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param template_records: 根插件或上层组合入口注入的模板记录。
## [br]
## @schema template_records: Array of Dictionary template records.
func setup(template_records: Array = []) -> void:
	cleanup()
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.gd ; GDScript Files"])
	var _file_selected_connected: Error = _file_dialog.file_selected.connect(_on_file_selected) as Error

	var base_control: Control = _get_editor_base_control()
	if base_control != null:
		base_control.add_child(_file_dialog)
	_setup_menu_actions(template_records)


## 清理菜单动作持有的对话框。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func cleanup() -> void:
	_cleanup_extension_editor_actions()
	_cleanup_diagnostic_dialog()
	_reset_menu_actions()
	if is_instance_valid(_file_dialog):
		_queue_free_detached(_file_dialog)
	_file_dialog = null


## 获取 GF 工具菜单项。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 菜单项字典列表，每项包含 `id`、`label`、`section`。
## [br]
## @schema return: Array of Dictionary menu entries with id, label, and section.
func get_menu_entries() -> Array[Dictionary]:
	return _menu_entries.duplicate(true)


## 执行 GF 工具菜单对应动作。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param id: 菜单项 ID。
func handle_menu_id(id: int) -> void:
	var handler: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(_menu_action_handlers, id)
	if handler.is_empty():
		return

	match _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(handler, "kind", &""):
		&"template":
			_show_dialog(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(handler, "template_type", ""))
		&"generate_accessors":
			_generate_accessors()
		&"generate_project_accessors":
			_generate_project_accessors()
		&"open_workspace":
			workspace_requested.emit()
		&"refresh_editor_contributions":
			editor_contributions_refresh_requested.emit()
		&"extension_action":
			_handle_extension_action(handler)


# --- 私有/辅助方法 ---

func _setup_menu_actions(template_records: Array = []) -> void:
	_cleanup_extension_editor_actions()
	_reset_menu_actions()
	_register_template_records(_get_core_template_records())
	_register_template_records(template_records)
	_load_extension_editor_actions()
	_register_fixed_menu_action(
		MENU_OPEN_WORKSPACE,
		"打开 GF 工作区",
		"工作区",
		&"open_workspace"
	)
	_register_fixed_menu_action(
		MENU_REFRESH_EDITOR_CONTRIBUTIONS,
		"刷新 GF 编辑器贡献",
		"工作区",
		&"refresh_editor_contributions"
	)
	_register_fixed_menu_action(
		MENU_GENERATE_ACCESSORS,
		"生成强类型访问器",
		SECTION_CODE_GENERATION,
		&"generate_accessors"
	)
	_register_fixed_menu_action(
		MENU_GENERATE_PROJECT_ACCESSORS,
		"生成项目常量访问器",
		SECTION_CODE_GENERATION,
		&"generate_project_accessors"
	)
	_register_loaded_extension_action_entries()


func _reset_menu_actions() -> void:
	_menu_action_handlers.clear()
	_menu_entries.clear()
	_template_records.clear()
	_next_template_menu_id = TEMPLATE_MENU_ID_START
	_next_extension_menu_id = EXTENSION_MENU_ID_START


func _get_core_template_records() -> Array[Dictionary]:
	return [
		{
			"menu_id": MENU_GENERATE_SYSTEM,
			"type": "System",
			"label": "生成 System",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFSystem",
		},
		{
			"menu_id": MENU_GENERATE_MODEL,
			"type": "Model",
			"label": "生成 Model",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFModel",
		},
		{
			"menu_id": MENU_GENERATE_UTILITY,
			"type": "Utility",
			"label": "生成 Utility",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFUtility",
		},
		{
			"menu_id": MENU_GENERATE_COMMAND,
			"type": "Command",
			"label": "生成 Command",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFCommand",
		},
	]


func _register_template_records(records: Array) -> void:
	for record_variant: Variant in records:
		if record_variant is Dictionary:
			_register_template_record(_GF_VARIANT_ACCESS_SCRIPT.to_dictionary(record_variant))


func _register_template_record(source_record: Dictionary) -> void:
	var template_type: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_record, "type", "").strip_edges()
	if template_type.is_empty():
		return

	var record: Dictionary = source_record.duplicate(true)
	record["type"] = template_type
	if not record.has("base_class"):
		record["base_class"] = "GF" + template_type
	if _template_records.has(template_type):
		push_error("[GF Framework] 模板 type 重复，已跳过: %s" % template_type)
		return

	var menu_id: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "menu_id", -1)
	if menu_id < 0:
		menu_id = _allocate_template_menu_id()
	if _menu_action_handlers.has(menu_id):
		push_error("[GF Framework] 模板菜单 ID 重复，已跳过: %s" % menu_id)
		return

	var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label", "生成 " + template_type).strip_edges()
	if label.is_empty():
		label = "生成 " + template_type
	var section: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "section", SECTION_EXTENSION_TEMPLATES).strip_edges()
	if section.is_empty():
		section = SECTION_EXTENSION_TEMPLATES

	_template_records[template_type] = record
	_menu_action_handlers[menu_id] = {
		"kind": &"template",
		"template_type": template_type,
	}
	_append_menu_entry(menu_id, label, section)


func _allocate_template_menu_id() -> int:
	var menu_id: int = _next_template_menu_id
	while _menu_action_handlers.has(menu_id):
		menu_id += 1
	_next_template_menu_id = menu_id + 1
	return menu_id


func _register_fixed_menu_action(
	menu_id: int,
	label: String,
	section: String,
	handler_kind: StringName
) -> void:
	if _menu_action_handlers.has(menu_id):
		push_error("[GF Framework] 固定菜单 ID 重复，已跳过: %s" % menu_id)
		return

	_menu_action_handlers[menu_id] = {
		"kind": handler_kind,
	}
	_append_menu_entry(menu_id, label, section)


func _append_menu_entry(menu_id: int, label: String, section: String) -> void:
	_menu_entries.append({
		"id": menu_id,
		"label": label,
		"section": section,
	})


func _show_dialog(type: String) -> void:
	if type.is_empty():
		return
	_current_template_type = type
	_file_dialog.title = "生成 GF " + type
	_file_dialog.current_file = "new_" + type.to_lower() + ".gd"
	_file_dialog.popup_centered_ratio(0.5)


func _on_file_selected(path: String) -> void:
	if FileAccess.file_exists(path):
		push_error("[GF Framework] 文件已存在，已取消生成: %s" % path)
		return

	var file_name: String = path.get_file().get_basename()
	var class_name_str: String = file_name.to_pascal_case()
	var template: String = _get_template(_current_template_type)
	template = template.replace("{ClassName}", class_name_str)
	template = template.replace("{FileName}", file_name + ".gd")
	template = template.replace("{BaseClass}", _get_base_class(_current_template_type))

	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if dir_error != OK:
		push_error("[GF Framework] 文件目录创建失败: %s" % error_string(dir_error))
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		var _stored: bool = file.store_string(template)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
		print("[GF Framework] 成功生成文件: ", path)
	else:
		push_error("[GF Framework] 文件生成失败: ", path)


func _generate_accessors() -> void:
	var output_path: String = GFPluginProjectSettings.get_access_output_path()
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var error: Error = generator.generate(output_path)
	if error == OK:
		print("[GF Framework] 成功生成强类型访问器: ", output_path)
	else:
		push_error("[GF Framework] 强类型访问器生成失败: %s" % error_string(error))


func _generate_project_accessors() -> void:
	var output_path: String = GFPluginProjectSettings.get_project_access_output_path()
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var error: Error = generator.generate_project_access(output_path)
	if error == OK:
		print("[GF Framework] 成功生成项目常量访问器: ", output_path)
	else:
		push_error("[GF Framework] 项目常量访问器生成失败: %s" % error_string(error))


func _show_diagnostic_dialog(title: String, text: String) -> void:
	if not is_instance_valid(_diagnostic_dialog):
		_diagnostic_dialog = AcceptDialog.new()
		var dialog_min_size: Vector2i = Vector2i(
			int(DIAGNOSTIC_DIALOG_MIN_SIZE.x),
			int(DIAGNOSTIC_DIALOG_MIN_SIZE.y)
		)
		_diagnostic_dialog.min_size = dialog_min_size
		_diagnostic_output = TextEdit.new()
		_diagnostic_output.editable = false
		_diagnostic_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_diagnostic_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_diagnostic_dialog.add_child(_diagnostic_output)
		EditorInterface.get_base_control().add_child(_diagnostic_dialog)

	_diagnostic_dialog.title = title
	if is_instance_valid(_diagnostic_output):
		_diagnostic_output.text = text
	_diagnostic_dialog.popup_centered(Vector2i(
		int(DIAGNOSTIC_DIALOG_MIN_SIZE.x),
		int(DIAGNOSTIC_DIALOG_MIN_SIZE.y)
	))


func _load_extension_editor_actions() -> void:
	_cleanup_extension_editor_actions()
	for script_path: String in GFExtensionSettings.get_enabled_editor_action_paths():
		var action: RefCounted = _create_extension_editor_action(script_path)
		if action == null:
			continue
		_extension_action_records.append({
			"instance": action,
			"script_path": script_path,
		})
		if action.has_method("setup"):
			var _setup_result: Variant = action.call("setup")
		_register_extension_template_records(action, script_path)


func _create_extension_editor_action(script_path: String) -> RefCounted:
	var script: Script = _load_script(script_path)
	if script == null or not script.can_instantiate():
		push_error("[GF Framework] 扩展编辑器动作加载失败: %s" % script_path)
		return null

	var instance: RefCounted = _variant_to_ref_counted(script.call("new"))
	if instance == null:
		push_error("[GF Framework] 扩展编辑器动作实例化失败: %s" % script_path)
		return null
	return instance


func _register_extension_template_records(action: RefCounted, script_path: String) -> void:
	if not action.has_method("get_template_records"):
		return

	var records_variant: Variant = action.call("get_template_records")
	if not (records_variant is Array):
		push_error("[GF Framework] 扩展脚本模板声明无效: %s" % script_path)
		return

	var records: Array[Dictionary] = []
	for record_variant: Variant in records_variant:
		if record_variant is Dictionary:
			records.append(_GF_VARIANT_ACCESS_SCRIPT.to_dictionary(record_variant))
	_register_template_records(records)


func _register_loaded_extension_action_entries() -> void:
	for action_record: Dictionary in _extension_action_records:
		var action: RefCounted = _get_dictionary_ref_counted(action_record, "instance")
		var script_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(action_record, "script_path", "")
		if action == null:
			continue
		_register_extension_action_entries(action, script_path)


func _register_extension_action_entries(action: RefCounted, script_path: String) -> void:
	if not action.has_method("get_menu_entries"):
		return

	var entries_variant: Variant = action.call("get_menu_entries")
	if not (entries_variant is Array):
		push_error("[GF Framework] 扩展编辑器动作菜单声明无效: %s" % script_path)
		return

	for entry_variant: Variant in entries_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.to_dictionary(entry_variant)
		var action_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(entry, "id", &"")
		var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "label", "").strip_edges()
		if action_id == &"" or label.is_empty():
			continue

		var menu_id: int = _next_extension_menu_id
		_next_extension_menu_id += 1
		var section: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "section", SECTION_EXTENSION_TOOLS).strip_edges()
		if section.is_empty():
			section = SECTION_EXTENSION_TOOLS

		_menu_action_handlers[menu_id] = {
			"kind": &"extension_action",
			"instance": action,
			"action_id": action_id,
		}
		_append_menu_entry(menu_id, label, section)


func _handle_extension_action(handler: Dictionary) -> void:
	var action: RefCounted = _get_dictionary_ref_counted(handler, "instance")
	if action == null or not action.has_method("handle_menu_action"):
		return

	var _handled: Variant = action.call("handle_menu_action", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(handler, "action_id", &""))


func _cleanup_extension_editor_actions() -> void:
	for action_record: Dictionary in _extension_action_records:
		var action: RefCounted = _get_dictionary_ref_counted(action_record, "instance")
		if action != null and action.has_method("cleanup"):
			var _cleanup_result: Variant = action.call("cleanup")
	_extension_action_records.clear()


func _cleanup_diagnostic_dialog() -> void:
	if is_instance_valid(_diagnostic_dialog):
		_queue_free_detached(_diagnostic_dialog)
	_diagnostic_dialog = null
	_diagnostic_output = null


func _queue_free_detached(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if not node.is_queued_for_deletion():
		node.queue_free()


func _get_editor_base_control() -> Control:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_base_control()


func _load_script(path: String) -> Script:
	var resource: Resource = load(path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _variant_to_ref_counted(value: Variant) -> RefCounted:
	if value is RefCounted:
		var instance: RefCounted = value
		return instance
	return null


func _get_dictionary_ref_counted(source: Dictionary, key: Variant) -> RefCounted:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, key)
	if value is RefCounted:
		var instance: RefCounted = value
		return instance
	return null


func _get_template(type: String) -> String:
	var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(_template_records, type)
	if not record.is_empty() and record.has("template"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "template", "")

	var base_template: String = """## {ClassName}: TODO。
class_name {ClassName}
extends {BaseClass}


# --- 信号 ---


# --- 枚举 ---


# --- 常量 ---


# --- 导出变量 ---


"""

	var lifecycle_template: String = """# --- GF 生命周期方法 ---

func init() -> void:
	pass


func async_init() -> void:
	pass


func ready() -> void:
	pass


func dispose() -> void:
	pass


"""

	var tick_template: String = """func tick(_delta: float) -> void:
	pass


"""

	var methods_template: String = """# --- 公共变量 ---


# --- 私有变量 ---


# --- @onready 变量 (节点引用) ---


# --- 公共方法 ---


# --- 私有/辅助方法 ---


# --- 信号处理函数 ---

"""

	if type == "Command":
		return base_template + """# --- 公共变量 ---


# --- 私有变量 ---


# --- 公共方法 ---

func execute() -> Variant:
	return null


# --- 私有/辅助方法 ---

"""
	elif type == "System":
		return base_template + methods_template + lifecycle_template + tick_template
	else:
		return base_template + methods_template + lifecycle_template


func _get_base_class(type: String) -> String:
	var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(_template_records, type)
	if not record.is_empty():
		var base_class: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "base_class", "").strip_edges()
		if not base_class.is_empty():
			return base_class
	return "GF" + type
