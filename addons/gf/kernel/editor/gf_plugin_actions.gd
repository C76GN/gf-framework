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

## 读取菜单记录、依赖 provider 和扩展动作返回值中的类型化字段。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 创建默认 ProjectSettings 与访问器 provider 的脚本。
## [br]
## @api private
const _GF_PLUGIN_ACTION_DEPENDENCIES_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_action_dependencies.gd")

## 调用统一文本产物保存器并检查生成报告的脚本。
## [br]
## @api private
const _GF_GENERATED_ARTIFACT_REPORT_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_generated_artifact_report.gd"
)

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

# --- 私有变量 ---

## 供用户选择模板输出路径的 FileDialog。
## [br]
## @api private
var _file_dialog: FileDialog

## 当前文件对话框选择的模板 source_id。
## [br]
## @api private
var _current_template_id: String = ""

## 延迟创建并复用的生成诊断弹窗。
## [br]
## @api private
var _diagnostic_dialog: AcceptDialog

## 诊断弹窗中展示报告文本的只读 TextEdit。
## [br]
## @api private
var _diagnostic_output: TextEdit

## 本轮 setup 创建并保留用于动作调用和 cleanup 的扩展实例记录。
## [br]
## @api private
var _extension_action_records: Array[Dictionary] = []

## 已接受的扩展 ProjectSettings 记录集合。
## [br]
## @api private
var _extension_project_setting_records: Array[Dictionary] = []

## 已接受的扩展 ProjectSettings section 记录集合。
## [br]
## @api private
var _extension_project_setting_section_records: Array[Dictionary] = []

## 将菜单整数 ID 映射到模板、固定动作或扩展回调数据的表。
## [br]
## @api private
var _menu_action_handlers: Dictionary = {}

## 当前已注册的菜单展示记录。
## [br]
## @api private
var _menu_entries: Array[Dictionary] = []

## 按 source_id 索引的规范化模板记录。
## [br]
## @api private
var _template_records: Dictionary = {}

## 分配给未显式指定 menu_id 的模板动作的下一个候选 ID。
## [br]
## @api private
var _next_template_menu_id: int = TEMPLATE_MENU_ID_START

## 扩展动作菜单 ID 的单调递增计数器，setup 时复位。
## [br]
## @api private
var _next_extension_menu_id: int = EXTENSION_MENU_ID_START

## 当前注入或默认创建的动作依赖 provider。
## [br]
## @api private
var _dependencies: RefCounted


# --- 框架内部方法 ---

## 初始化菜单动作需要的文件对话框。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param template_records: 根插件或上层组合入口注入的模板记录。
## [br]
## @schema template_records: Array of Dictionary template records.
## [br]
## @param dependencies: 可选依赖 provider；为空时使用默认 GFPluginActionDependencies。
func setup(template_records: Array = [], dependencies: RefCounted = null) -> void:
	cleanup()
	_set_dependencies(dependencies)
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
	_dependencies = null


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


## 获取已加载扩展编辑器动作贡献的项目设置记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 项目设置记录副本。
## [br]
## @schema return: Array[Dictionary]，每项包含稳定 name、默认值、类型与可选展示映射。
func get_project_setting_records() -> Array[Dictionary]:
	return _extension_project_setting_records.duplicate(true)


## 获取已加载扩展编辑器动作贡献的项目设置分区记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 项目设置分区记录副本。
## [br]
## @schema return: Array[Dictionary]，每项包含稳定 path 与多语言展示映射。
func get_project_setting_section_records() -> Array[Dictionary]:
	return _extension_project_setting_section_records.duplicate(true)


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
			_show_dialog(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(handler, "template_id", ""))
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

## 清理旧扩展动作并重新注册核心/注入模板、扩展动作和固定菜单项。
## [br]
## @api private
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


## 清空菜单映射、展示记录和模板索引，并复位两类扩展菜单 ID 计数器。
## [br]
## @api private
func _reset_menu_actions() -> void:
	_menu_action_handlers.clear()
	_menu_entries.clear()
	_template_records.clear()
	_next_template_menu_id = TEMPLATE_MENU_ID_START
	_next_extension_menu_id = EXTENSION_MENU_ID_START


## 返回 System、Model、Utility 和 Command 四种内置模板的菜单记录。
## [br]
## @api private
func _get_core_template_records() -> Array[Dictionary]:
	return [
		{
			"source_id": "gf.kernel.editor:template.system",
			"menu_id": MENU_GENERATE_SYSTEM,
			"type": "System",
			"label": "生成 System",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFSystem",
		},
		{
			"source_id": "gf.kernel.editor:template.model",
			"menu_id": MENU_GENERATE_MODEL,
			"type": "Model",
			"label": "生成 Model",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFModel",
		},
		{
			"source_id": "gf.kernel.editor:template.utility",
			"menu_id": MENU_GENERATE_UTILITY,
			"type": "Utility",
			"label": "生成 Utility",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFUtility",
		},
		{
			"source_id": "gf.kernel.editor:template.command",
			"menu_id": MENU_GENERATE_COMMAND,
			"type": "Command",
			"label": "生成 Command",
			"section": SECTION_CORE_TEMPLATES,
			"base_class": "GFCommand",
		},
	]


## 仅把输入中为 Dictionary 的元素转换并交给单条模板注册逻辑。
## [br]
## @api private
func _register_template_records(records: Array) -> void:
	for record_variant: Variant in records:
		if record_variant is Dictionary:
			_register_template_record(_GF_VARIANT_ACCESS_SCRIPT.to_dictionary(record_variant))


## 复制并补齐模板记录，拒绝空/重复 source_id 和冲突菜单 ID 后建立索引与展示项。
## 未提供菜单 ID 时分配下一个未占用模板 ID。
## [br]
## @api private
func _register_template_record(source_record: Dictionary) -> void:
	var template_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		source_record,
		"source_id",
		""
	).strip_edges()
	if template_id.is_empty():
		push_error("[GFPluginActions][plugin_actions.template_source_id_empty] Skipped a template with an empty source_id.")
		return
	var template_type: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_record, "type", "").strip_edges()
	if template_type.is_empty():
		return

	var record: Dictionary = source_record.duplicate(true)
	record["type"] = template_type
	if not record.has("base_class"):
		record["base_class"] = "GF" + template_type
	if _template_records.has(template_id):
		push_error("[GFPluginActions][plugin_actions.template_source_id_duplicate] Skipped a duplicate template source_id: %s." % template_id)
		return

	var menu_id: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "menu_id", -1)
	if menu_id < 0:
		menu_id = _allocate_template_menu_id()
	if _menu_action_handlers.has(menu_id):
		push_error("[GFPluginActions][plugin_actions.template_menu_id_duplicate] Skipped a duplicate template menu ID: %s." % menu_id)
		return

	var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label", "生成 " + template_type).strip_edges()
	if label.is_empty():
		label = "生成 " + template_type
	var section: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "section", SECTION_EXTENSION_TEMPLATES).strip_edges()
	if section.is_empty():
		section = SECTION_EXTENSION_TEMPLATES

	record["source_id"] = template_id
	_template_records[template_id] = record
	_menu_action_handlers[menu_id] = {
		"kind": &"template",
		"template_id": template_id,
	}
	_append_menu_entry(menu_id, label, section)


## 从模板菜单 ID 计数器开始跳过已占用值，并把下一候选值推进到返回值之后。
## [br]
## @api private
func _allocate_template_menu_id() -> int:
	var menu_id: int = _next_template_menu_id
	while _menu_action_handlers.has(menu_id):
		menu_id += 1
	_next_template_menu_id = menu_id + 1
	return menu_id


## 若菜单 ID 尚未占用，登记固定动作种类并添加展示项。
## [br]
## @api private
func _register_fixed_menu_action(
	menu_id: int,
	label: String,
	section: String,
	handler_kind: StringName
) -> void:
	if _menu_action_handlers.has(menu_id):
		push_error("[GFPluginActions][plugin_actions.fixed_menu_id_duplicate] Skipped a duplicate fixed menu ID: %s." % menu_id)
		return

	_menu_action_handlers[menu_id] = {
		"kind": handler_kind,
	}
	_append_menu_entry(menu_id, label, section)


## 将菜单 ID、显示文字和分组追加到菜单展示数组。
## [br]
## @api private
func _append_menu_entry(menu_id: int, label: String, section: String) -> void:
	_menu_entries.append({
		"id": menu_id,
		"label": label,
		"section": section,
	})


## 查找模板记录并更新 FileDialog 标题、默认文件名和当前模板 ID 后弹出。
## [br]
## @api private
func _show_dialog(template_id: String) -> void:
	if template_id.is_empty():
		return
	var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		_template_records,
		template_id
	)
	if record.is_empty():
		return
	var template_type: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "type")
	_current_template_id = template_id
	_file_dialog.title = "生成 GF " + template_type
	_file_dialog.current_file = "new_" + template_type.to_lower() + ".gd"
	_file_dialog.popup_centered_ratio(0.5)


## 从依赖 provider 读取访问器路径并请求生成，按 Error 输出成功或失败信息。
## [br]
## @api private
func _generate_accessors() -> void:
	var output_path: String = _call_dependency_string(&"get_access_output_path")
	var error: Error = _call_dependency_error(&"generate_accessors", [output_path])
	if error == OK:
		print("[GF Framework] 成功生成强类型访问器: ", output_path)
	else:
		push_error("[GFPluginActions][plugin_actions.accessor_generation_failed] Typed accessor generation failed: %s." % error_string(error))


## 从依赖 provider 读取项目访问器路径并请求生成，按 Error 输出成功或失败信息。
## [br]
## @api private
func _generate_project_accessors() -> void:
	var output_path: String = _call_dependency_string(&"get_project_access_output_path")
	var error: Error = _call_dependency_error(&"generate_project_accessors", [output_path])
	if error == OK:
		print("[GF Framework] 成功生成项目常量访问器: ", output_path)
	else:
		push_error("[GFPluginActions][plugin_actions.project_accessor_generation_failed] Project constant accessor generation failed: %s." % error_string(error))


## 按需创建只读诊断弹窗并刷新标题、报告文本和居中显示尺寸。
## [br]
## @api private
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


## 先清理旧扩展动作，再实例化已启用动作、按需 setup，并登记其模板与项目设置展示信息。
## [br]
## @api private
func _load_extension_editor_actions() -> void:
	_cleanup_extension_editor_actions()
	for script_path: String in _call_dependency_string_array(&"get_enabled_editor_action_paths"):
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
		_register_extension_project_setting_records(action, script_path)
		_register_extension_project_setting_section_records(action, script_path)


## 加载扩展动作脚本并确认其可实例化且 new() 返回 RefCounted。
## 检查失败时记录错误并返回 null。
## [br]
## @api private
func _create_extension_editor_action(script_path: String) -> RefCounted:
	var script: Script = _load_script(script_path)
	if script == null or not script.can_instantiate():
		push_error("[GFPluginActions][plugin_actions.extension_action_load_failed] Could not load the extension editor action: %s." % script_path)
		return null

	var instance: RefCounted = _variant_to_ref_counted(script.call("new"))
	if instance == null:
		push_error("[GFPluginActions][plugin_actions.extension_action_instantiation_failed] Could not instantiate the extension editor action: %s." % script_path)
		return null
	return instance


## 若扩展动作提供模板记录数组，则筛出字典项并交给统一模板注册逻辑。
## 非数组返回值会报告扩展脚本路径并停止该 provider 的模板注册。
## [br]
## @api private
func _register_extension_template_records(action: RefCounted, script_path: String) -> void:
	if not action.has_method("get_template_records"):
		return

	var records_variant: Variant = action.call("get_template_records")
	if not (records_variant is Array):
		push_error("[GFPluginActions][plugin_actions.extension_template_invalid] Invalid extension script template declaration: %s." % script_path)
		return

	var records: Array[Dictionary] = []
	for record_variant: Variant in records_variant:
		if record_variant is Dictionary:
			records.append(_GF_VARIANT_ACCESS_SCRIPT.to_dictionary(record_variant))
	_register_template_records(records)


## 读取扩展 ProjectSettings 记录，忽略非字典、空 name 和重复 name，并深复制接受项。
## [br]
## @api private
func _register_extension_project_setting_records(action: RefCounted, script_path: String) -> void:
	if not action.has_method("get_project_setting_records"):
		return

	var records_variant: Variant = action.call("get_project_setting_records")
	if not records_variant is Array:
		push_error("[GFPluginActions][plugin_actions.extension_settings_invalid] Invalid extension project settings declaration: %s." % script_path)
		return
	var records: Array = records_variant
	for record_variant: Variant in records:
		if not record_variant is Dictionary:
			continue
		var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.to_dictionary(record_variant)
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			"name"
		).strip_edges()
		if setting_name.is_empty() or _has_project_setting_record(setting_name):
			continue
		_extension_project_setting_records.append(record.duplicate(true))


## 读取扩展 section 记录，去除 path 首尾空白及末尾斜线后忽略空值和重复路径。
## 接受项写回规范化 path 并深复制保存。
## [br]
## @api private
func _register_extension_project_setting_section_records(
	action: RefCounted,
	script_path: String
) -> void:
	if not action.has_method("get_project_setting_section_records"):
		return

	var records_variant: Variant = action.call("get_project_setting_section_records")
	if not records_variant is Array:
		push_error("[GFPluginActions][plugin_actions.extension_settings_section_invalid] Invalid extension project settings section declaration: %s." % script_path)
		return
	var records: Array = records_variant
	for record_variant: Variant in records:
		if not record_variant is Dictionary:
			continue
		var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.to_dictionary(record_variant)
		var section_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			"path"
		).strip_edges().trim_suffix("/")
		if section_path.is_empty() or _has_project_setting_section_record(section_path):
			continue
		record["path"] = section_path
		_extension_project_setting_section_records.append(record.duplicate(true))


## 按 name 字段检查项目设置记录集合中是否已有指定名称。
## [br]
## @api private
func _has_project_setting_record(setting_name: String) -> bool:
	for record: Dictionary in _extension_project_setting_records:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "name") == setting_name:
			return true
	return false


## 按 path 字段检查项目设置 section 集合中是否已有指定路径。
## [br]
## @api private
func _has_project_setting_section_record(section_path: String) -> bool:
	for record: Dictionary in _extension_project_setting_section_records:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path") == section_path:
			return true
	return false


## 遍历已加载扩展实例记录，提取 instance 和 script_path 后注册其菜单项。
## [br]
## @api private
func _register_loaded_extension_action_entries() -> void:
	for action_record: Dictionary in _extension_action_records:
		var action: RefCounted = _get_dictionary_ref_counted(action_record, "instance")
		var script_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(action_record, "script_path", "")
		if action == null:
			continue
		_register_extension_action_entries(action, script_path)


## 读取扩展菜单数组，筛选具有非空 id 与 label 的记录并分配扩展菜单 ID。
## handler 保存扩展实例和 action_id，以供菜单触发时回调。
## [br]
## @api private
func _register_extension_action_entries(action: RefCounted, script_path: String) -> void:
	if not action.has_method("get_menu_entries"):
		return

	var entries_variant: Variant = action.call("get_menu_entries")
	if not (entries_variant is Array):
		push_error("[GFPluginActions][plugin_actions.extension_action_menu_invalid] Invalid extension editor action menu declaration: %s." % script_path)
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


## handler 中的扩展实例仍有效且实现 handle_menu_action 时转发 action_id。
## [br]
## @api private
func _handle_extension_action(handler: Dictionary) -> void:
	var action: RefCounted = _get_dictionary_ref_counted(handler, "instance")
	if action == null or not action.has_method("handle_menu_action"):
		return

	var _handled: Variant = action.call("handle_menu_action", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(handler, "action_id", &""))


## 对已记录且提供 cleanup 的动作调用清理，再清空动作和项目设置展示记录。
## [br]
## @api private
func _cleanup_extension_editor_actions() -> void:
	for action_record: Dictionary in _extension_action_records:
		var action: RefCounted = _get_dictionary_ref_counted(action_record, "instance")
		if action != null and action.has_method("cleanup"):
			var _cleanup_result: Variant = action.call("cleanup")
	_extension_action_records.clear()
	_extension_project_setting_records.clear()
	_extension_project_setting_section_records.clear()


## 将仍有效的诊断弹窗从父节点分离并排队释放，然后清空弹窗和输出控件引用。
## [br]
## @api private
func _cleanup_diagnostic_dialog() -> void:
	if is_instance_valid(_diagnostic_dialog):
		_queue_free_detached(_diagnostic_dialog)
	_diagnostic_dialog = null
	_diagnostic_output = null


## 忽略无效节点；否则先从父节点移除，并在尚未排队时调用 queue_free。
## [br]
## @api private
func _queue_free_detached(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if not node.is_queued_for_deletion():
		node.queue_free()


## 只在 Editor hint 环境下返回 EditorInterface 的 base Control。
## [br]
## @api private
func _get_editor_base_control() -> Control:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_base_control()


## 使用注入的 RefCounted provider，或在参数为空时创建默认依赖 provider。
## [br]
## @api private
func _set_dependencies(dependencies: RefCounted = null) -> void:
	if dependencies == null:
		_dependencies = _GF_PLUGIN_ACTION_DEPENDENCIES_SCRIPT.new()
		return
	_dependencies = dependencies


## 返回当前依赖 provider；尚未设置时懒创建默认 provider。
## [br]
## @api private
func _get_dependencies() -> RefCounted:
	if _dependencies == null:
		_dependencies = _GF_PLUGIN_ACTION_DEPENDENCIES_SCRIPT.new()
	return _dependencies


## 检查 provider 是否实现指定方法后以 callv 转发参数；缺少方法时报告并返回 null。
## [br]
## @api private
func _call_dependency_value(method_name: StringName, args: Array = []) -> Variant:
	var dependencies: RefCounted = _get_dependencies()
	if dependencies == null or not dependencies.has_method(method_name):
		push_error("[GFPluginActions][plugin_actions.dependency_method_missing] A plugin action dependency is missing method: %s." % method_name)
		return null
	return dependencies.callv(method_name, args)


## 调用依赖方法并将返回值转成去除首尾空白的文本。
## [br]
## @api private
func _call_dependency_string(method_name: StringName) -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(_call_dependency_value(method_name)).strip_edges()


## 将 PackedStringArray 或 Array 返回项转成非空、去首尾空白的 String 数组。
## 其他返回类型产生空数组。
## [br]
## @api private
func _call_dependency_string_array(method_name: StringName) -> Array[String]:
	var value: Variant = _call_dependency_value(method_name)
	var result: Array[String] = []
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item: String in packed_values:
			var packed_path: String = item.strip_edges()
			if not packed_path.is_empty():
				result.append(packed_path)
		return result
	if value is Array:
		var raw_values: Array = value
		for item: Variant in raw_values:
			var path: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(item).strip_edges()
			if not path.is_empty():
				result.append(path)
	return result


## 仅将 int provider 返回值转换为 Error；其他类型报告错误并返回 FAILED。
## [br]
## @api private
func _call_dependency_error(method_name: StringName, args: Array = []) -> Error:
	var value: Variant = _call_dependency_value(method_name, args)
	if value is int:
		var error_code: int = value
		return error_code as Error
	push_error("[GFPluginActions][plugin_actions.dependency_result_invalid] A plugin action dependency returned a value that is not an Error: %s." % method_name)
	return FAILED


## 加载资源并仅在其为 Script 时返回，否则返回 null。
## [br]
## @api private
func _load_script(path: String) -> Script:
	var resource: Resource = load(path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


## 仅当 Variant 为 RefCounted 时返回强类型实例，否则返回 null。
## [br]
## @api private
func _variant_to_ref_counted(value: Variant) -> RefCounted:
	if value is RefCounted:
		var instance: RefCounted = value
		return instance
	return null


## 从字典读取字段，仅当字段值为 RefCounted 时返回实例，否则返回 null。
## [br]
## @api private
func _get_dictionary_ref_counted(source: Dictionary, key: Variant) -> RefCounted:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, key)
	if value is RefCounted:
		var instance: RefCounted = value
		return instance
	return null


## 优先返回记录内模板文本；未提供文本时按模板 type 生成内置骨架字符串。
## Command 使用 execute 骨架，System 额外包含 tick，其他类型使用通用生命周期骨架。
## [br]
## @api private
func _get_template(template_id: String) -> String:
	var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		_template_records,
		template_id
	)
	if not record.is_empty() and record.has("template"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "template", "")
	var template_type: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "type")

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


## @param _scope: 异步初始化作用域。
func async_init(_scope: GFAsyncScope) -> void:
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

	if template_type == "Command":
		return base_template + """# --- 公共变量 ---


# --- 私有变量 ---


# --- 公共方法 ---

func execute() -> Variant:
	return null


# --- 私有/辅助方法 ---

"""
	elif template_type == "System":
		return base_template + methods_template + lifecycle_template + tick_template
	else:
		return base_template + methods_template + lifecycle_template


## 返回模板记录中的非空 base_class；记录缺失或字段为空时返回空字符串。
## [br]
## @api private
func _get_base_class(template_id: String) -> String:
	var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		_template_records,
		template_id
	)
	if not record.is_empty():
		var base_class: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "base_class", "").strip_edges()
		if not base_class.is_empty():
			return base_class
	return ""


## 接受 GDScript 标识符且排除此处列出的语言关键字。
## [br]
## @api private
static func _is_valid_gdscript_identifier(value: String) -> bool:
	if not value.is_valid_identifier():
		return false
	match value:
		"and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue", "elif", "else", "enum", "extends", "false", "for", "func", "if", "in", "is", "match", "not", "null", "or", "pass", "preload", "return", "self", "signal", "static", "super", "true", "var", "void", "while", "yield":
			return false
		_:
			return true


# --- 信号处理函数 ---

## 拒绝已存在路径与无效类标识，替换选中模板的占位符后通过受管产物写入入口创建文件；写入报告未确认成功时只报告错误。
## [br]
## @api private
func _on_file_selected(path: String) -> void:
	if FileAccess.file_exists(path):
		push_error("[GFPluginActions][plugin_actions.output_exists] Generation cancelled because the file already exists: %s." % path)
		return

	var file_name: String = path.get_file().get_basename()
	var class_name_str: String = file_name.to_pascal_case()
	if not _is_valid_gdscript_identifier(class_name_str):
		push_error(
			"[GFPluginActions][plugin_actions.class_name_invalid] Generation cancelled because the filename cannot produce a valid GDScript class_name: %s."
			% path
		)
		return
	var base_class: String = _get_base_class(_current_template_id)
	if not _is_valid_gdscript_identifier(base_class):
		push_error(
			"[GFPluginActions][plugin_actions.base_class_invalid] Generation cancelled because template base_class is not a valid GDScript identifier: %s."
			% _current_template_id
		)
		return
	var template: String = _get_template(_current_template_id)
	template = template.replace("{ClassName}", class_name_str)
	template = template.replace("{FileName}", file_name + ".gd")
	template = template.replace("{BaseClass}", base_class)

	var report: Dictionary = _GF_GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(
		path,
		template,
		{
			"overwrite_existing": false,
			"expected_previous_sha256": "",
			"allowed_roots": ["res://"],
			"artifact_owner": _GF_GENERATED_ARTIFACT_REPORT_SCRIPT.OWNER_USER,
			"generator_id": "GFPluginActions",
			"source_id": _current_template_id,
			"label": "GF Framework",
		}
	)
	if (
		not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "success", false)
		or not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "written", false)
	):
		push_error(
			"[GFPluginActions][plugin_actions.file_generation_failed] File generation failed: %s (%s)." % [
				path,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					report,
					"error",
					error_string(
						_GF_GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(
							report
						)
					)
				),
			]
		)
		return
	print("[GF Framework] 成功生成文件: ", path)
