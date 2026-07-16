extends GutTest


# --- 常量 ---

const GF_PLUGIN_SCRIPT = preload("res://addons/gf/plugin.gd")
const GF_PLUGIN_ACTIONS = preload("res://addons/gf/kernel/editor/gf_plugin_actions.gd")
const GF_PLUGIN_AUTOLOAD = preload("res://addons/gf/kernel/editor/gf_plugin_autoload.gd")
const GF_PLUGIN_DEBUGGER_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_debugger_tools.gd")
const GF_PLUGIN_DOCK_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")
const GF_PLUGIN_INSPECTOR_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_inspector_tools.gd")
const GF_PLUGIN_IMPORT_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_import_tools.gd")
const GF_PLUGIN_MENU = preload("res://addons/gf/kernel/editor/gf_plugin_menu.gd")
const GF_PLUGIN_PREVIEW_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_preview_tools.gd")
const GF_PLUGIN_PROJECT_SETTINGS = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")
const GF_PLUGIN_ACTION_DEPENDENCIES_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_action_dependencies.gd")
const GF_EDITOR_CONTRIBUTION_REGISTRY = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const GF_RESOURCE_PATH_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_editor_property.gd")
const GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_array_editor_property.gd")
const GF_RESOURCE_PATH_PICKER_CONTROL = preload("res://addons/gf/kernel/editor/gf_resource_path_picker_control.gd")
const GF_RESOURCE_PATH_HINT = preload("res://addons/gf/kernel/editor/gf_resource_path_hint.gd")
const GF_RESOURCE_PATH_INSPECTOR_PLUGIN = preload("res://addons/gf/kernel/editor/gf_resource_path_inspector_plugin.gd")
const GF_RESOURCE_PREVIEW_GENERATOR = preload("res://addons/gf/kernel/editor/gf_resource_preview_generator.gd")
const GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_preview_source_registry.gd")
const GF_EDITOR_WORKSPACE_DOCK = preload("res://addons/gf/kernel/editor/gf_editor_workspace_dock.gd")
const GF_EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")
const GF_EDITOR_WORKSPACE_WINDOW = preload("res://addons/gf/kernel/editor/gf_editor_workspace_window.gd")
const GF_EXTENSION_MANAGER_DOCK = preload("res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd")
const GF_PACKAGE_MANAGER_DOCK = preload("res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd")
const GF_EXTENSION_SETTINGS_BASE = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const GF_STANDARD_EDITOR_CONTRIBUTIONS_PATH: String = "res://addons/gf/standard/editor/gf_editor_contributions.json"
const _TEST_PROJECT_SETTING_PREFIX: String = "gf/test/"


# --- Godot 生命周期方法 ---

func after_each() -> void:
	_clear_test_project_settings()


# --- 测试用例 ---

func test_plugin_split_helpers_load() -> void:
	assert_not_null(GF_PLUGIN_SCRIPT, "主插件脚本应可加载。")
	assert_not_null(GF_PLUGIN_ACTIONS, "菜单动作辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_AUTOLOAD, "Autoload 辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_DEBUGGER_TOOLS, "Debugger 插件辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_DOCK_TOOLS, "Dock 辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_INSPECTOR_TOOLS, "Inspector 辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_IMPORT_TOOLS, "导入插件辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_MENU, "菜单辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_PREVIEW_TOOLS, "预览生成器辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_PROJECT_SETTINGS, "ProjectSettings 辅助脚本应可加载。")
	assert_not_null(GF_PLUGIN_ACTION_DEPENDENCIES_SCRIPT, "菜单动作依赖 provider 脚本应可加载。")
	assert_not_null(GF_EDITOR_CONTRIBUTION_REGISTRY, "编辑器贡献清单读取器脚本应可加载。")
	assert_not_null(GF_RESOURCE_PATH_EDITOR_PROPERTY, "资源路径属性编辑器脚本应可加载。")
	assert_not_null(GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY, "资源路径数组属性编辑器脚本应可加载。")
	assert_not_null(GF_RESOURCE_PATH_PICKER_CONTROL, "窗口安全的资源路径选择控件脚本应可加载。")
	assert_not_null(GF_RESOURCE_PATH_HINT, "资源路径 hint 脚本应可加载。")
	assert_not_null(GF_RESOURCE_PATH_INSPECTOR_PLUGIN, "资源路径 Inspector 脚本应可加载。")
	assert_not_null(GF_RESOURCE_PREVIEW_GENERATOR, "Resource 预览生成器脚本应可加载。")
	assert_not_null(GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT, "Resource 预览来源注册表脚本应可加载。")
	assert_not_null(GF_EDITOR_WORKSPACE_UI, "工作区页面 UI 辅助脚本应可加载。")
	assert_not_null(GF_EDITOR_WORKSPACE_WINDOW, "独立工作区窗口脚本应可加载。")
	assert_not_null(GF_PACKAGE_MANAGER_DOCK, "包管理工作区页面脚本应可加载。")


func test_editor_workspace_ui_builds_common_page_chrome() -> void:
	var page: VBoxContainer = VBoxContainer.new()
	GF_EDITOR_WORKSPACE_UI.apply_page_root(page)

	var toolbar: HBoxContainer = GF_EDITOR_WORKSPACE_UI.make_toolbar()
	var state: WorkspaceButtonState = WorkspaceButtonState.new()
	var button: Button = GF_EDITOR_WORKSPACE_UI.make_button("刷新", "重新加载。", _mark_workspace_ui_button_pressed.bind(state))
	var summary: Label = GF_EDITOR_WORKSPACE_UI.make_summary_label("准备就绪")
	var empty: Label = GF_EDITOR_WORKSPACE_UI.make_empty_label("暂无内容")
	var details: TextEdit = GF_EDITOR_WORKSPACE_UI.make_details_output(96.0)

	button.pressed.emit()
	GF_EDITOR_WORKSPACE_UI.set_status(summary, "完成", GF_EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)

	assert_true(page.clip_contents, "工作区页面根控件应裁剪自身内容。")
	assert_eq(page.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "工作区页面根控件应横向填充。")
	assert_eq(page.size_flags_vertical, Control.SIZE_EXPAND_FILL, "工作区页面根控件应纵向填充。")
	assert_eq(toolbar.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "通用工具栏应横向填充。")
	assert_eq(toolbar.get_theme_constant("separation"), GF_EDITOR_WORKSPACE_UI.TOOLBAR_SEPARATION, "通用工具栏应使用统一间距。")
	assert_eq(state.count, 1, "通用按钮应连接按下回调。")
	assert_eq(summary.text, "完成", "通用状态写入应更新文本。")
	assert_eq(summary.modulate, GF_EDITOR_WORKSPACE_UI.OK_TEXT_COLOR, "通用状态写入应更新颜色。")
	assert_eq(empty.modulate, GF_EDITOR_WORKSPACE_UI.EMPTY_TEXT_COLOR, "空状态应使用统一弱提示颜色。")
	assert_false(details.editable, "详情输出框应只读。")
	assert_eq(details.custom_minimum_size.y, 96.0, "详情输出框应接受页面自定义高度。")
	assert_eq(GF_EDITOR_WORKSPACE_UI.get_report_color({"error_count": 1}), GF_EDITOR_WORKSPACE_UI.ERROR_TEXT_COLOR, "错误报告应映射错误色。")
	assert_eq(GF_EDITOR_WORKSPACE_UI.get_report_color({"warning_count": 1}), GF_EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR, "警告报告应映射警告色。")
	assert_eq(GF_EDITOR_WORKSPACE_UI.get_report_color({}), GF_EDITOR_WORKSPACE_UI.OK_TEXT_COLOR, "无问题报告应映射成功色。")

	page.free()
	toolbar.free()
	button.free()
	summary.free()
	empty.free()
	details.free()


func test_plugin_action_menu_ids_are_unique() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [_get_standard_editor_records(&"get_template_records")])
	var entries: Array = _call_array(actions, &"get_menu_entries")
	_call_void(actions, &"_cleanup_extension_editor_actions")
	var ids: Array[int] = []
	for entry: Dictionary in entries:
		ids.append(GF_VARIANT_ACCESS.get_option_int(entry, "id", -1))

	var unique_ids: Dictionary = {}
	var highest_id: int = -1
	for id: int in ids:
		unique_ids[id] = true
		highest_id = maxi(highest_id, id)

	assert_eq(unique_ids.size(), ids.size(), "GF 菜单动作 ID 应保持唯一。")
	assert_gt(GF_PLUGIN_ACTIONS.EXTENSION_MENU_ID_START, GF_PLUGIN_ACTIONS.TEMPLATE_MENU_ID_START, "扩展菜单动作 ID 应避开模板菜单动作 ID。")
	assert_gt(highest_id, GF_PLUGIN_ACTIONS.MENU_GENERATE_PROJECT_ACCESSORS, "动态模板或包动作应可注册到菜单。")


func test_plugin_actions_use_source_id_as_template_identity() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [[
		{
			"source_id": "gf.test.editor:template.system",
			"type": "System",
			"label": "替代 System",
			"base_class": "CustomSystem",
			"template": "custom",
		},
	]])
	var core_source: String = _call_text(actions, &"_get_template", ["gf.kernel.editor:template.system"])
	var custom_source: String = _call_text(actions, &"_get_template", ["gf.test.editor:template.system"])
	var core_base_class: String = _call_text(actions, &"_get_base_class", ["gf.kernel.editor:template.system"])
	var custom_base_class: String = _call_text(actions, &"_get_base_class", ["gf.test.editor:template.system"])
	_call_void(actions, &"_cleanup_extension_editor_actions")

	assert_ne(core_source, "custom", "核心模板应保留自己的稳定 source identity。")
	assert_eq(custom_source, "custom", "相同语义 type 的模板应按 source_id 独立注册。")
	assert_eq(core_base_class, "GFSystem", "核心模板 base_class 不应被其他来源覆盖。")
	assert_eq(custom_base_class, "CustomSystem", "自定义模板应按自己的 source_id 解析 base_class。")


func test_plugin_actions_setup_replaces_previous_file_dialog_immediately() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	var old_dialog: FileDialog = FileDialog.new()
	add_child(old_dialog)
	actions.set(&"_file_dialog", old_dialog)

	_call_void(actions, &"setup", [[]])
	var current_dialog: FileDialog = _as_file_dialog(actions.get(&"_file_dialog"))

	assert_not_null(current_dialog, "setup 应创建新的文件对话框。")
	assert_ne(current_dialog, old_dialog, "重复 setup 应替换旧文件对话框。")
	assert_null(old_dialog.get_parent(), "重复 setup 应立即让旧文件对话框脱离父节点。")

	_call_void(actions, &"cleanup")
	assert_null(current_dialog.get_parent(), "cleanup 应立即让当前文件对话框脱离父节点。")

	await get_tree().process_frame
	assert_false(is_instance_valid(old_dialog), "旧文件对话框应在下一帧释放。")
	assert_false(is_instance_valid(current_dialog), "当前文件对话框应在下一帧释放。")


func test_plugin_action_system_template_uses_gf_lifecycle_section() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [[]])
	var source: String = _call_text(actions, &"_get_template", ["gf.kernel.editor:template.system"])
	_call_void(actions, &"_cleanup_extension_editor_actions")

	assert_true(source.contains("# --- GF 生命周期方法 ---"), "System 模板应使用 GF 生命周期 section。")
	assert_false(source.contains("# --- Godot 生命周期方法 ---"), "System 模板不应误用 Godot 生命周期 section。")


func test_plugin_action_open_workspace_emits_signal() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [[]])
	watch_signals(actions)

	_call_void(actions, &"handle_menu_id", [GF_PLUGIN_ACTIONS.MENU_OPEN_WORKSPACE])

	assert_signal_emitted(actions, "workspace_requested", "GF 工具菜单应能请求打开独立工作区。")
	_call_void(actions, &"_cleanup_extension_editor_actions")


func test_plugin_action_refresh_editor_contributions_emits_signal() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [[]])
	watch_signals(actions)

	_call_void(actions, &"handle_menu_id", [GF_PLUGIN_ACTIONS.MENU_REFRESH_EDITOR_CONTRIBUTIONS])

	assert_signal_emitted(actions, "editor_contributions_refresh_requested", "GF 工具菜单应能请求刷新编辑器贡献。")
	_call_void(actions, &"_cleanup_extension_editor_actions")


func test_plugin_actions_use_dependency_provider_for_generation_and_extension_paths() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	var fake_dependencies: FakePluginActionDependencies = FakePluginActionDependencies.new()
	_call_void(actions, &"setup", [[], fake_dependencies])

	_call_void(actions, &"handle_menu_id", [GF_PLUGIN_ACTIONS.MENU_GENERATE_ACCESSORS])
	_call_void(actions, &"handle_menu_id", [GF_PLUGIN_ACTIONS.MENU_GENERATE_PROJECT_ACCESSORS])
	_call_void(actions, &"cleanup")

	assert_eq(fake_dependencies.editor_action_path_call_count, 1, "扩展编辑器动作路径应由依赖 provider 提供。")
	assert_eq(fake_dependencies.generated_access_path, fake_dependencies.access_output_path, "强类型访问器生成应通过依赖 provider 执行。")
	assert_eq(fake_dependencies.generated_project_access_path, fake_dependencies.project_access_output_path, "项目常量访问器生成应通过依赖 provider 执行。")


func test_plugin_actions_depend_on_provider_boundary_for_boot_dependencies() -> void:
	var source: String = _read_text_file("res://addons/gf/kernel/editor/gf_plugin_actions.gd")

	assert_true(source.contains("_GF_PLUGIN_ACTION_DEPENDENCIES_SCRIPT"), "菜单动作应通过 provider 边界取得启动依赖。")
	assert_false(source.contains("GFAccessGenerator.new()"), "菜单动作不应直接创建访问器生成器。")
	assert_false(source.contains("GFPluginProjectSettings."), "菜单动作不应直接读取 ProjectSettings helper。")
	assert_false(source.contains("GFExtensionSettings."), "菜单动作不应直接读取扩展设置全局类。")
	assert_false(source.contains("GFExtensionSettingsBase"), "菜单动作不应保留扩展设置 preload alias。")


func test_plugin_refresh_path_clears_manifest_cache_and_reloads_dynamic_tools() -> void:
	var source: String = _read_text_file("res://addons/gf/plugin.gd")
	var refresh_source: String = _extract_function_source(
		source,
		"func _refresh_editor_contributions() -> void:",
		"func _scan_editor_filesystem() -> void:"
	)

	assert_true(refresh_source.contains("GFExtensionSettingsBase.clear_manifest_cache()"), "编辑器贡献刷新必须清理扩展 manifest 缓存。")
	assert_true(refresh_source.contains("_import_tools.cleanup(self)"), "编辑器贡献刷新必须卸载旧 ImportPlugin。")
	assert_true(refresh_source.contains("_import_tools.setup(self)"), "编辑器贡献刷新必须重新安装启用扩展的 ImportPlugin。")
	assert_true(refresh_source.contains("_gltf_document_tools.cleanup()"), "编辑器贡献刷新必须卸载旧 glTF 文档扩展。")
	assert_true(refresh_source.contains("_gltf_document_tools.setup()"), "编辑器贡献刷新必须重新安装启用扩展的 glTF 文档扩展。")


func test_extension_manager_reload_button_clears_manifest_cache() -> void:
	var source: String = _read_text_file("res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd")
	var build_ui_source: String = _extract_function_source(
		source,
		"func _build_ui() -> void:",
		"func _create_header_row() -> Control:"
	)
	var reload_source: String = _extract_function_source(
		source,
		"func _reload_extensions() -> void:",
		"func _refresh_visible_extension_rows() -> void:"
	)

	assert_true(build_ui_source.contains("GFEditorWorkspaceUI.make_button(\"重新加载\", \"重新读取所有 gf_extension.json。\", _reload_extensions)"), "扩展管理器重新加载按钮必须走清缓存入口。")
	assert_true(reload_source.contains("GFExtensionSettingsBase.clear_manifest_cache()"), "扩展管理器手动重新加载必须清理 manifest 缓存。")
	assert_true(reload_source.contains("_refresh_extensions()"), "清理缓存后应复用现有刷新流程。")


func test_plugin_helper_setup_methods_are_idempotent_by_contract() -> void:
	var import_setup: String = _extract_function_source(
		_read_text_file("res://addons/gf/kernel/editor/gf_plugin_import_tools.gd"),
		"func setup(plugin: EditorPlugin) -> void:",
		"func cleanup(plugin: EditorPlugin) -> void:"
	)
	var inspector_setup: String = _extract_function_source(
		_read_text_file("res://addons/gf/kernel/editor/gf_plugin_inspector_tools.gd"),
		"func setup(\n\tplugin: EditorPlugin,",
		"func cleanup(plugin: EditorPlugin) -> void:"
	)
	var debugger_setup: String = _extract_function_source(
		_read_text_file("res://addons/gf/kernel/editor/gf_plugin_debugger_tools.gd"),
		"func setup(plugin: EditorPlugin, standard_records: Dictionary = {}) -> void:",
		"func cleanup(plugin: EditorPlugin) -> void:"
	)
	var preview_setup: String = _extract_function_source(
		_read_text_file("res://addons/gf/kernel/editor/gf_plugin_preview_tools.gd"),
		"func setup(plugin: EditorPlugin) -> void:",
		"func cleanup(plugin: EditorPlugin) -> void:"
	)
	var gltf_setup: String = _extract_function_source(
		_read_text_file("res://addons/gf/kernel/editor/gf_plugin_gltf_document_tools.gd"),
		"func setup() -> void:",
		"func cleanup() -> void:"
	)

	assert_true(import_setup.contains("cleanup(plugin)"), "Import helper setup 应先清理旧注册。")
	assert_true(inspector_setup.contains("cleanup(plugin)"), "Inspector/export helper setup 应先清理旧注册。")
	assert_true(debugger_setup.contains("cleanup(plugin)"), "Debugger helper setup 应先清理旧注册。")
	assert_true(preview_setup.contains("cleanup(plugin)"), "Preview helper setup 应先清理旧注册。")
	assert_true(gltf_setup.contains("cleanup()"), "glTF document helper setup 应先清理旧注册。")


func test_plugin_autoload_persists_ownership_marker_changes() -> void:
	var source: String = _read_text_file("res://addons/gf/kernel/editor/gf_plugin_autoload.gd")

	assert_true(source.contains("var save_result: Error = ProjectSettings.save()"), "Autoload 归属 marker 变更必须显式保存 ProjectSettings。")
	assert_true(source.contains("push_error(\"[GFPluginAutoload] ProjectSettings.save() 失败"), "Autoload marker 保存失败必须有可观察错误。")


func test_plugin_project_settings_does_not_persist_process_local_defaults() -> void:
	var source: String = _read_text_file("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")

	assert_false(
		source.contains("ProjectSettings.save()"),
		"注册默认值不能顺带保存同进程测试或工具写入的临时 ProjectSettings。"
	)


func test_framework_project_does_not_persist_test_project_settings() -> void:
	var project_source: String = _read_text_file("res://project.godot")

	assert_false(
		project_source.contains("test/"),
		"框架仓库 project.godot 不应持久化 gf/test 测试夹具设置。"
	)


func test_standard_template_records_are_injected_without_kernel_hardcoding() -> void:
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	var records: Array = _get_standard_editor_records(&"get_template_records")
	_call_void(actions, &"_setup_menu_actions", [records])
	var template_id: String = "gf.standard.state_machine.editor:state_machine.template.node_state"
	var source: String = _call_text(actions, &"_get_template", [template_id])
	_call_void(actions, &"_cleanup_extension_editor_actions")

	assert_true(source.contains("func _enter("), "NodeState 模板应由 standard 扩展记录注入。")
	assert_true(source.contains("# --- 可重写钩子 / 虚方法 ---"), "NodeState 模板应使用 canonical 可重写钩子 section。")
	assert_false(source.contains("# --- 虚方法（由子类重写） ---"), "NodeState 模板不应继续输出旧 section 名。")
	assert_eq(_call_text(actions, &"_get_base_class", [template_id]), "GFNodeState", "NodeState 基类应来自模板记录。")
	for record_value: Variant in records:
		var record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(record_value)
		var owner_package_id: String = GF_VARIANT_ACCESS.get_option_string(record, "owner_package_id")
		var source_id: String = GF_VARIANT_ACCESS.get_option_string(record, "source_id")
		assert_false(owner_package_id.is_empty(), "标准编辑器记录应带实际 owner_package_id。")
		assert_eq(GF_VARIANT_ACCESS.get_option_string(record, "package_id"), owner_package_id, "package_id 应指向载荷 owner。")
		assert_true(source_id.begins_with(owner_package_id + ":"), "source_id 应由 owner package 作用域限定。")


func test_standard_editor_contributions_use_data_manifest_boundary() -> void:
	var plugin_source: String = _read_text_file("res://addons/gf/plugin.gd")
	var manifest_source: String = _read_text_file(GF_STANDARD_EDITOR_CONTRIBUTIONS_PATH)

	assert_true(plugin_source.contains("GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT"), "根插件应通过 kernel registry 读取标准编辑器贡献。")
	assert_true(plugin_source.contains(GF_STANDARD_EDITOR_CONTRIBUTIONS_PATH), "根插件应引用标准编辑器 data-only manifest。")
	assert_false(plugin_source.contains("gf_standard_editor_extensions.gd"), "根插件不应再读取旧的 standard 可执行聚合脚本。")
	assert_false(plugin_source.contains("_load_optional_script"), "根插件不应通过动态脚本加载读取 standard 记录。")
	assert_false(manifest_source.contains("GFBuildInfo"), "标准编辑器 manifest 不应引用标准库运行时类型。")
	assert_false(ResourceLoader.exists("res://addons/gf/standard/editor/gf_standard_editor_extensions.gd", "Script"), "旧标准编辑器聚合脚本应移除。")


func test_editor_contribution_registry_skips_missing_script_targets() -> void:
	var manifest_path: String = "user://gf_editor_contribution_registry_missing_target.json"
	var manifest: Dictionary = {
		"schema_version": GF_EDITOR_CONTRIBUTION_REGISTRY.SCHEMA_VERSION,
		"package_id": "gf.standard.editor",
		"debugger_plugin_records": [
			{
				"owner_package_id": "gf.test.editor",
				"source_id": "debugger.missing",
				"path": "res://addons/gf/standard/__missing__/missing_debugger_plugin.gd",
				"label": "Missing Debugger",
			},
		],
		"project_setting_records": [
			{
				"owner_package_id": "gf.test.editor",
				"source_id": "setting.kept",
				"name": "gf/test/kept_from_partial_manifest",
				"default_value": false,
				"type_name": "bool",
				"basic": true,
			},
		],
	}
	_write_text_file(manifest_path, JSON.stringify(manifest))

	var report: Dictionary = GF_EDITOR_CONTRIBUTION_REGISTRY.load_manifest_report(manifest_path)
	var records: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "records")
	var debugger_records: Array = GF_VARIANT_ACCESS.get_option_array(records, "debugger_plugin_records")
	var project_setting_records: Array = GF_VARIANT_ACCESS.get_option_array(records, "project_setting_records")
	_remove_path_if_exists(manifest_path)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "缺失贡献目标应跳过记录，而不是让 manifest 读取失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "skipped_record_count"), 1, "缺失脚本目标应进入 skipped 诊断。")
	assert_true(debugger_records.is_empty(), "缺失脚本目标不应传给插件 helper 加载。")
	assert_eq(project_setting_records.size(), 1, "无脚本依赖的 ProjectSettings 记录仍应保留。")
	if project_setting_records.is_empty():
		return
	var setting_record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(project_setting_records[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_int(setting_record, "type"), TYPE_BOOL, "type_name 应被转换为 Godot Variant.Type。")


func test_editor_contribution_registry_rejects_duplicate_global_source_ids() -> void:
	var manifest_path: String = "user://gf_editor_contribution_registry_duplicate_source.json"
	var manifest: Dictionary = {
		"schema_version": GF_EDITOR_CONTRIBUTION_REGISTRY.SCHEMA_VERSION,
		"package_id": "gf.test.editor.aggregate",
		"template_records": [
			{
				"owner_package_id": "gf.test.editor",
				"source_id": "template.shared",
				"type": "First",
				"label": "First",
				"base_class": "RefCounted",
				"template_path": "res://addons/gf/standard/editor/templates/node_state.gdtemplate",
			},
			{
				"owner_package_id": "gf.test.editor",
				"source_id": "template.shared",
				"type": "Second",
				"label": "Second",
				"base_class": "RefCounted",
				"template_path": "res://addons/gf/standard/editor/templates/node_state_machine.gdtemplate",
			},
		],
	}
	_write_text_file(manifest_path, JSON.stringify(manifest))

	var report: Dictionary = GF_EDITOR_CONTRIBUTION_REGISTRY.load_manifest_report(manifest_path)
	var records: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "records")
	var templates: Array = GF_VARIANT_ACCESS.get_option_array(records, "template_records")
	_remove_path_if_exists(manifest_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "重复全局 source_id 应使 manifest 校验失败。")
	assert_eq(templates.size(), 1, "重复 source_id 应只保留第一条稳定记录。")
	assert_eq(_count_report_issue_kind(report, "duplicate_source_id"), 1, "报告应指出 source_id 冲突。")


func test_standard_dock_records_use_standard_order_band() -> void:
	var records: Array = _get_standard_editor_records(&"get_dock_records")

	assert_false(records.is_empty(), "标准库应贡献 dock 页面记录。")
	for record_value: Variant in records:
		var record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(record_value)
		assert_gte(
			GF_VARIANT_ACCESS.get_option_int(record, "order"),
			100,
			"标准库 dock 页面应使用 100+ order 段，避免与 kernel dock 撞位。"
		)


func test_standard_debugger_records_are_injected_without_kernel_hardcoding() -> void:
	var tools: Object = _new_object(GF_PLUGIN_DEBUGGER_TOOLS)
	var records: Array = _get_standard_editor_records(&"get_debugger_plugin_records")
	var normalized: Array = _call_array(tools, &"_to_record_array", [records])

	assert_eq(normalized.size(), 1, "标准库应贡献一个 Runtime Debugger 插件记录。")
	if normalized.is_empty():
		return

	var record: Dictionary = _dictionary_at(normalized, 0)
	var script_path: String = GF_VARIANT_ACCESS.get_option_string(record, "path")
	var debugger_script: Script = _load_script_resource(script_path)
	var debugger_source: String = _read_text_file(script_path)

	assert_eq(script_path, "res://addons/gf/standard/utilities/debug/editor/gf_runtime_debugger_plugin.gd", "Debugger 插件记录应来自 standard 贡献。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(record, "label"), "GF Runtime Debugger", "Debugger 插件记录应保留显示标签。")
	assert_not_null(debugger_script, "Debugger 插件脚本应可加载。")
	if debugger_script == null:
		return
	assert_true(debugger_script.can_instantiate(), "Debugger 插件脚本应可实例化。")
	assert_eq(String(debugger_script.get_global_name()), "GFRuntimeDebuggerPlugin", "Debugger 插件记录应指向 GFRuntimeDebuggerPlugin。")
	assert_eq(String(debugger_script.get_instance_base_type()), "EditorDebuggerPlugin", "Runtime Debugger 插件应继承 EditorDebuggerPlugin。")
	assert_true(debugger_source.contains("func _has_capture(capture: String) -> bool:"), "Runtime Debugger 插件应声明 capture 回调。")
	assert_true(debugger_source.contains("GFDiagnosticsUtility.DEBUGGER_CAPTURE_NAME"), "Runtime Debugger 插件应声明 GF diagnostics capture。")
	assert_true(debugger_source.contains("session.add_session_tab(tab)"), "Runtime Debugger 页签应注册到 EditorDebuggerSession。")
	assert_false(debugger_source.contains("session.stopped.connect"), "stopped 只表示远端断开，不应销毁可复用的会话页签。")
	assert_false(debugger_source.contains("tab.queue_free()"), "已注册页签必须由 EditorDebuggerSession 统一释放。")


func test_standard_project_setting_records_use_runtime_build_info_constants() -> void:
	var records: Array[Dictionary] = _get_standard_editor_records(&"get_project_setting_records")
	var names: Array[String] = []
	for record: Dictionary in records:
		names.append(GF_VARIANT_ACCESS.get_option_string(record, "name"))

	assert_true(names.has(GFBuildInfo.EXPORT_ENABLED_SETTING), "导出开关应来自 GFBuildInfo 常量。")
	assert_true(names.has(GFBuildInfo.EXPORT_BUILD_METADATA_SETTING), "导出元数据设置应来自 GFBuildInfo 常量。")


func test_plugin_project_settings_accepts_contributed_records() -> void:
	var setting_name: String = "gf/test/contributed_project_setting"
	var restore: Dictionary = {
		"had_setting": ProjectSettings.has_setting(setting_name),
		"value": ProjectSettings.get_setting(setting_name, null) if ProjectSettings.has_setting(setting_name) else null,
	}
	_clear_project_setting_if_exists(setting_name)
	var changed: bool = GF_PLUGIN_PROJECT_SETTINGS._ensure_project_setting_records([
		{
			"name": setting_name,
			"default_value": "from-record",
			"type": TYPE_STRING,
			"basic": true,
		},
	])
	var stored_value: String = GF_VARIANT_ACCESS.to_text(ProjectSettings.get_setting(setting_name, ""))
	_restore_project_setting(setting_name, restore)

	assert_true(changed, "通用 ProjectSettings 贡献记录应能写入缺失默认值。")
	assert_eq(stored_value, "from-record", "贡献记录应由所属包提供默认值，kernel 不需要硬编码具体 key。")


func test_plugin_project_settings_retains_project_owned_settings_when_records_disappear() -> void:
	var setting_name: String = "gf/test/retained_project_setting"
	var restore: Dictionary = _set_project_setting(setting_name, "project-owned")

	GF_PLUGIN_PROJECT_SETTINGS.ensure_all([])
	var stored_value: String = GF_VARIANT_ACCESS.to_text(ProjectSettings.get_setting(setting_name, ""))

	_restore_project_setting(setting_name, restore)

	assert_eq(stored_value, "project-owned", "ensure_all 不应清理本次未贡献但已归项目所有的设置。")


func test_plugin_inspector_tools_discovers_enabled_extension_inspectors() -> void:
	var restore: Dictionary = _set_enabled_extensions(["gf.capability", "gf.flow", "gf.save"])
	var tools: Object = _new_object(GF_PLUGIN_INSPECTOR_TOOLS)
	var records: Array = _call_array(tools, &"_collect_enabled_extension_inspector_records")
	var paths: Array[String] = []
	for record: Dictionary in records:
		paths.append(GF_VARIANT_ACCESS.get_option_string(record, "path"))

	_restore_enabled_extensions(restore)

	assert_true(
		paths.has("res://addons/gf/extensions/capability/editor/gf_capability_inspector_plugin.gd"),
		"Capability Inspector 应由扩展 manifest 声明。"
	)
	assert_true(
		paths.has("res://addons/gf/extensions/flow/editor/gf_flow_graph_inspector_plugin.gd"),
		"Flow Graph Inspector 应由扩展 manifest 声明。"
	)
	assert_true(
		paths.has("res://addons/gf/extensions/save/editor/gf_persist_properties_inspector_plugin.gd"),
		"Save 属性白名单 Inspector 应由扩展 manifest 声明。"
	)


func test_plugin_import_tools_ignores_null_plugin() -> void:
	var tools: Object = _new_object(GF_PLUGIN_IMPORT_TOOLS)

	_call_void(tools, &"setup", [null])
	_call_void(tools, &"cleanup", [null])

	var import_plugins: Array = GF_VARIANT_ACCESS.as_array(tools.get(&"_import_plugins"))
	assert_true(import_plugins.is_empty(), "无 EditorPlugin 实例时导入插件辅助脚本不应注册任何对象。")


func test_resource_preview_generator_uses_resource_icon_property() -> void:
	var source_image: Image = Image.create(4, 2, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(1.0, 0.0, 0.0, 1.0))
	var source_texture: ImageTexture = ImageTexture.create_from_image(source_image)
	var resource: PreviewIconResource = PreviewIconResource.new()
	resource.icon = source_texture

	var source_preview: Texture2D = GF_RESOURCE_PREVIEW_GENERATOR.get_resource_preview_texture(resource)
	var preview_value: Variant = GF_RESOURCE_PREVIEW_GENERATOR.make_preview_texture(source_preview, Vector2i(8, 8))

	assert_true(preview_value is Texture2D, "带 icon 字段的 Resource 应生成预览纹理。")
	if not (preview_value is Texture2D):
		return

	var preview_texture: Texture2D = preview_value
	var preview_image: Image = preview_texture.get_image()
	assert_eq(preview_texture.get_size(), Vector2(8.0, 8.0), "预览纹理应使用请求尺寸。")
	assert_lt(preview_image.get_pixel(0, 0).a, 0.1, "等比适配后的空白区域应保持透明。")
	assert_gt(preview_image.get_pixel(4, 4).a, 0.9, "源图像主体应居中绘制到预览纹理。")


func test_resource_preview_generator_prefers_explicit_preview_method() -> void:
	var icon_image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	icon_image.fill(Color(1.0, 0.0, 0.0, 1.0))
	var preview_image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	preview_image.fill(Color(0.0, 1.0, 0.0, 1.0))
	var resource: PreviewMethodResource = PreviewMethodResource.new()
	resource.icon = ImageTexture.create_from_image(icon_image)
	resource.preview_texture = ImageTexture.create_from_image(preview_image)

	var source_preview: Texture2D = GF_RESOURCE_PREVIEW_GENERATOR.get_resource_preview_texture(resource)
	var preview_value: Variant = GF_RESOURCE_PREVIEW_GENERATOR.make_preview_texture(source_preview, Vector2i(4, 4))

	assert_true(preview_value is Texture2D, "显式 GF 预览方法应生成预览纹理。")
	if preview_value is Texture2D:
		var texture: Texture2D = preview_value
		var pixel: Color = texture.get_image().get_pixel(2, 2)
		assert_gt(pixel.g, 0.9, "显式 GF 预览方法应优先于 icon 字段。")


func test_resource_preview_source_registry_prefers_high_priority_provider() -> void:
	var registry: GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.new()
	var low_provider: PreviewSourceProvider = PreviewSourceProvider.new()
	low_provider.texture = _make_preview_test_texture(Color(1.0, 0.0, 0.0, 1.0))
	var high_provider: PreviewSourceProvider = PreviewSourceProvider.new()
	high_provider.texture = _make_preview_test_texture(Color(0.0, 1.0, 0.0, 1.0))

	var low_registered: bool = registry.register_source(low_provider, { "source_id": "low", "priority": 1 })
	var high_registered: bool = registry.register_source(high_provider, { "source_id": "high", "priority": 100 })
	var result: Dictionary = registry.build_preview_result(Resource.new(), Vector2i(4, 4))
	var texture: Texture2D = _get_preview_result_texture(result)

	assert_true(low_registered, "低优先级 provider 应可注册。")
	assert_true(high_registered, "高优先级 provider 应可注册。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "高优先级 provider 应生成预览。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(result, "source_id"), "high", "注册表应选择最高优先级 provider。")
	assert_not_null(texture, "预览结果应包含生成纹理。")
	if texture != null:
		assert_gt(texture.get_image().get_pixel(2, 2).g, 0.9, "高优先级 provider 的纹理应进入最终预览。")


func test_resource_preview_source_registry_reports_unknown_resource_without_source() -> void:
	var registry: GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.make_default()
	var result: Dictionary = registry.build_preview_result(Resource.new(), Vector2i(4, 4))

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "未知 Resource 没有预览来源时不应生成预览。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(result, "status"),
		GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.STATUS_NO_SOURCE,
		"未知 Resource 应稳定报告 no_source。"
	)
	assert_null(_get_preview_result_texture(result), "no_source 不应携带纹理对象。")


func test_resource_preview_source_registry_blocks_oversized_source_before_decode() -> void:
	var registry: GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.new()
	var oversized_texture: HugePreviewTexture = HugePreviewTexture.new()
	var provider: PreviewSourceProvider = PreviewSourceProvider.new()
	provider.texture = oversized_texture
	var _registered: bool = registry.register_source(provider, { "source_id": "huge", "priority": 1 })

	var result: Dictionary = registry.build_preview_result(Resource.new(), Vector2i(4, 4))

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "超预算源纹理不应生成预览。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(result, "status"),
		GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.STATUS_SOURCE_TOO_LARGE,
		"超预算源纹理应稳定报告 source_too_large。"
	)
	assert_false(oversized_texture.image_requested, "源纹理超预算时不应调用 get_image 解码。")
	assert_null(_get_preview_result_texture(result), "source_too_large 不应携带纹理对象。")


func test_resource_preview_source_registry_blocks_oversized_target() -> void:
	var registry: GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.new()
	var provider: PreviewSourceProvider = PreviewSourceProvider.new()
	provider.texture = _make_preview_test_texture(Color(0.0, 1.0, 0.0, 1.0))
	var _registered: bool = registry.register_source(provider, { "source_id": "small", "priority": 1 })

	var result: Dictionary = registry.build_preview_result(Resource.new(), Vector2i(2048, 2048))

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "超预算目标尺寸不应生成预览。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(result, "status"),
		GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.STATUS_TARGET_TOO_LARGE,
		"超预算目标尺寸应稳定报告 target_too_large。"
	)
	assert_null(_get_preview_result_texture(result), "target_too_large 不应携带纹理对象。")


func test_resource_path_editor_maps_file_hints_to_resource_types() -> void:
	assert_eq(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(PROPERTY_HINT_FILE, "*.tscn,*.scn"),
		"PackedScene",
		"场景扩展名应映射为 PackedScene。"
	)
	assert_eq(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(PROPERTY_HINT_FILE, "*.png,*.jpg"),
		"Texture2D",
		"图像扩展名应映射为 Texture2D。"
	)
	assert_eq(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(PROPERTY_HINT_FILE, "*.tscn,*.png"),
		"Resource",
		"混合资源类型应回退到 Resource。"
	)
	assert_eq(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(PROPERTY_HINT_FILE, "*.txt"),
		"",
		"普通文本文件不应被 ResourcePicker 接管。"
	)
	assert_true(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(TYPE_STRING, PROPERTY_HINT_FILE, "*.tscn"),
		"String + 可识别资源文件 hint 应接管。"
	)
	assert_true(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(TYPE_STRING, GF_RESOURCE_PATH_HINT.RESOURCE_PATH, "PackedScene"),
		"String + GF 资源路径 hint 应接管。"
	)
	assert_false(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(TYPE_STRING, PROPERTY_HINT_SAVE_FILE, "*.gd"),
		"保存目标不是既有资源引用，不应被资源路径编辑器接管。"
	)
	assert_eq(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(GF_RESOURCE_PATH_HINT.RESOURCE_PATH, ""),
		"Resource",
		"GF 资源路径 hint 未声明类型时应回退到 Resource。"
	)
	assert_false(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(TYPE_STRING_NAME, PROPERTY_HINT_FILE, "*.tscn"),
		"非 String 字段不应被资源路径编辑器接管。"
	)
	assert_false(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(TYPE_STRING, GF_RESOURCE_PATH_HINT.RESOURCE_PATH_ARRAY, "PackedScene"),
		"单值 String 不应被数组资源路径 hint 接管。"
	)
	var script_filters: PackedStringArray = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_file_filters(
		"Script"
	)
	assert_false(script_filters.is_empty(), "Script 资源选择器应提供文件过滤器。")
	assert_true(script_filters[0].contains("*.gd"), "Script 过滤器应包含 GDScript 扩展名。")


func test_codegen_outputs_use_save_file_semantics() -> void:
	GF_PLUGIN_PROJECT_SETTINGS.ensure_all()
	var access_output_info: Dictionary = _find_project_setting_property_info(
		GF_PLUGIN_PROJECT_SETTINGS.ACCESS_OUTPUT_SETTING
	)
	var project_access_output_info: Dictionary = _find_project_setting_property_info(
		GF_PLUGIN_PROJECT_SETTINGS.PROJECT_ACCESS_OUTPUT_SETTING
	)

	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(access_output_info, "hint", PROPERTY_HINT_NONE),
		PROPERTY_HINT_SAVE_FILE,
		"框架访问器输出应使用保存文件语义。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(project_access_output_info, "hint", PROPERTY_HINT_NONE),
		PROPERTY_HINT_SAVE_FILE,
		"项目访问器输出应使用保存文件语义。"
	)


func test_resource_path_array_editor_uses_explicit_custom_hint() -> void:
	assert_true(
		GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.should_handle_property(TYPE_ARRAY, GF_RESOURCE_PATH_HINT.RESOURCE_PATH_ARRAY, "PackedScene"),
		"Array + GF 资源路径数组 hint 应接管。"
	)
	assert_true(
		GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.should_handle_property(TYPE_PACKED_STRING_ARRAY, GF_RESOURCE_PATH_HINT.RESOURCE_PATH_ARRAY, "*.tscn"),
		"PackedStringArray + GF 资源路径数组 hint 应接管。"
	)
	assert_true(
		GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.should_handle_property(
			TYPE_PACKED_STRING_ARRAY,
			GF_RESOURCE_PATH_HINT.RESOURCE_PATH_ARRAY,
			"GFNetworkContract"
		),
		"GDScript 全局 Resource 子类应能作为资源路径数组的精确类型。"
	)
	assert_false(
		GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.should_handle_property(TYPE_ARRAY, PROPERTY_HINT_FILE, "*.tscn"),
		"数组字段必须显式使用 GF 资源路径数组 hint，避免误接管普通数组。"
	)
	assert_eq(
		GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.get_base_type_for_hint(GF_RESOURCE_PATH_HINT.RESOURCE_PATH_ARRAY, ""),
		"Resource",
		"资源路径数组 hint 未声明类型时应回退到 Resource。"
	)

	var paths: PackedStringArray = GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.to_resource_path_array([
		" res://scene.tscn ",
		&"uid://abc",
		123,
	])
	var packed_value: Variant = GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.make_property_value(paths, TYPE_PACKED_STRING_ARRAY)
	var array_value: Variant = GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.make_property_value(paths, TYPE_ARRAY)

	assert_eq(paths, PackedStringArray(["res://scene.tscn", "uid://abc", ""]), "资源路径数组应规范化 String 与 StringName。")
	assert_true(packed_value is PackedStringArray, "PackedStringArray 字段应写回 PackedStringArray。")
	assert_true(array_value is Array, "Array 字段应写回 Array。")
	assert_eq(GF_VARIANT_ACCESS.as_array(array_value), ["res://scene.tscn", "uid://abc", ""], "Array 写回值应保留路径顺序。")


func test_resource_path_editor_prefers_uid_paths_for_saved_resources() -> void:
	var script_path: String = "res://addons/gf/kernel/core/gf_path_tools.gd"
	var script_resource: Resource = load(script_path)
	var uid: int = ResourceLoader.get_resource_uid(script_path)
	assert_ne(uid, ResourceUID.INVALID_ID, "测试脚本资源应具有 Godot UID。")

	var stable_path: String = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_stable_resource_path(script_resource, true)
	var resolved_path: String = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resolved_resource_path(stable_path, "Script")
	var status: Dictionary = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_path_status(stable_path, "Script")
	var loaded_resource: Resource = GF_RESOURCE_PATH_EDITOR_PROPERTY.load_resource_from_path(stable_path, "Script")

	assert_eq(stable_path, ResourceUID.id_to_text(uid), "保存路径应优先使用 uid://。")
	assert_eq(resolved_path, script_path, "uid:// 路径应能解析回真实 res:// 路径。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "valid"), "已注册 UID 状态应有效。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(status, "state"), "ok", "已注册 UID 状态应标记为 ok。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(status, "resolved_path"), script_path, "状态字典应暴露解析后的资源路径。")
	assert_true(loaded_resource is Script, "uid:// 路径应能按类型提示重新加载资源。")


func test_resource_path_editor_reports_invalid_resource_paths() -> void:
	var missing_path: String = "res://tests/gf_core/kernel/editor/missing_resource_path_fixture.tres"
	var missing_status: Dictionary = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_path_status(missing_path, "Resource")
	var unsupported_status: Dictionary = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_path_status("user://config.tres", "Resource")
	var unknown_uid_value: int = 123456789012345
	while ResourceUID.has_id(unknown_uid_value):
		unknown_uid_value += 1
	var unknown_uid: String = ResourceUID.id_to_text(unknown_uid_value)
	var uid_status: Dictionary = GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_path_status(unknown_uid, "Resource")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(missing_status, "valid"), "不存在的 res:// 资源应报告无效。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(missing_status, "state"),
		"missing_or_type_mismatch",
		"缺失资源应使用稳定状态值。"
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(unsupported_status, "valid"), "非资源路径 scheme 不应被接受。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(unsupported_status, "state"),
		"unsupported_scheme",
		"不支持的 scheme 应使用稳定状态值。"
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(uid_status, "valid"), "未注册 UID 应报告无效。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(uid_status, "state"),
		"invalid_uid",
		"未注册 UID 应使用稳定状态值。"
	)
	assert_eq(
		GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resolved_resource_path(unknown_uid, "Resource"),
		"",
		"无效 UID 不应解析出资源路径。"
	)


func test_plugin_actions_discovers_enabled_extension_menu_entries() -> void:
	var restore: Dictionary = _set_enabled_extensions(["gf.save", "gf.network"])
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [[]])
	var entries: Array = _call_array(actions, &"get_menu_entries")
	var setting_records: Array = _call_array(actions, &"get_project_setting_records")
	var section_records: Array = _call_array(
		actions,
		&"get_project_setting_section_records"
	)
	_call_void(actions, &"_cleanup_extension_editor_actions")
	_restore_enabled_extensions(restore)

	var labels: Array[String] = []
	for entry: Dictionary in entries:
		labels.append(GF_VARIANT_ACCESS.get_option_string(entry, "label"))

	assert_true(labels.has("校验当前场景 SaveGraph"), "SaveGraph 诊断应由 Save 扩展 manifest 注册。")
	assert_true(labels.has("生成 Network Contract 访问器"), "Network Contract 生成器应由 Network 扩展 manifest 注册。")
	assert_true(
		_record_array_has_identity(setting_records, "name", "gf/network/contract_paths"),
		"Network tool 应通过扩展编辑器动作贡献自己的项目设置。"
	)
	assert_true(
		_record_array_has_identity(section_records, "path", "gf/network"),
		"Network tool 应通过扩展编辑器动作贡献自己的项目设置分区。"
	)


func test_plugin_actions_discovers_enabled_extension_templates() -> void:
	var restore: Dictionary = _set_enabled_extensions(["gf.capability"])
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_setup_menu_actions", [[]])
	var entries: Array = _call_array(actions, &"get_menu_entries")
	var source: String = _call_text(actions, &"_get_template", ["gf.extension.capability:template.node_capability"])
	_call_void(actions, &"_cleanup_extension_editor_actions")
	_restore_enabled_extensions(restore)

	var labels: Array[String] = []
	for entry: Dictionary in entries:
		labels.append(GF_VARIANT_ACCESS.get_option_string(entry, "label"))

	assert_true(labels.has("生成 NodeCapability"), "Capability 模板应由 Capability 扩展 manifest 注册。")
	assert_true(source.contains("func get_dependency_removal_policy()"), "Capability 模板源码应由包动作贡献。")


func test_plugin_dock_tools_keeps_core_docks_available_without_extensions() -> void:
	var restore: Dictionary = _set_enabled_extensions([])
	var tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	_call_void(tools, &"set_standard_dock_records", [_get_standard_editor_records(&"get_dock_records")])
	var core_records: Array = _call_array(tools, &"_collect_core_dock_records")
	var extension_records: Array = _call_array(tools, &"_collect_enabled_extension_dock_records")
	_restore_enabled_extensions(restore)

	var core_paths: Array[String] = []
	for record: Dictionary in core_records:
		core_paths.append(GF_VARIANT_ACCESS.get_option_string(record, "path"))

	assert_true(
		core_paths.has("res://addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd"),
		"Storage Viewer 应作为 standard Dock 保持可用。"
	)
	assert_true(
		core_paths.has("res://addons/gf/standard/input/editor/gf_input_mapping_dock.gd"),
		"输入映射工作区页面应作为 standard Dock 保持可用。"
	)
	assert_true(
		core_paths.has("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd"),
		"节点状态机工具应作为 standard Dock 保持可用。"
	)
	assert_true(
		core_paths.has("res://addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd"),
		"诊断工作区页面应作为 standard Dock 保持可用。"
	)
	assert_true(
		core_paths.has("res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd"),
		"扩展管理器应作为 kernel Dock 保持可用。"
	)
	assert_true(
		core_paths.has("res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd"),
		"包管理器应作为 kernel Dock 保持可用。"
	)
	assert_true(extension_records.is_empty(), "全禁用时不应注册任何扩展级 Dock。")


func test_plugin_dock_tools_discovers_enabled_extension_docks() -> void:
	var restore: Dictionary = _set_enabled_extensions(["gf.flow"])
	var tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	var extension_records: Array = _call_array(tools, &"_collect_enabled_extension_dock_records")
	_restore_enabled_extensions(restore)

	var paths: Array[String] = []
	for record: Dictionary in extension_records:
		paths.append(GF_VARIANT_ACCESS.get_option_string(record, "path"))

	assert_true(
		paths.has("res://addons/gf/extensions/flow/editor/gf_flow_graph_dock.gd"),
		"Flow 工具面板应由 Flow 扩展 manifest 注册。"
	)
	var flow_record: Dictionary = _dictionary_at(extension_records, 0)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(flow_record, "label"), "GF Flow", "扩展页面记录应使用简洁扩展名作为 fallback。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(flow_record, "short_label"), "流程", "扩展页面应提供短标签。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(flow_record, "order"), 40, "扩展页面应读取 manifest 中的工作区排序。")


func test_plugin_dock_tools_discovers_save_extension_workspace_page() -> void:
	var restore: Dictionary = _set_enabled_extensions(["gf.save"])
	var tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	var extension_records: Array = _call_array(tools, &"_collect_enabled_extension_dock_records")
	_restore_enabled_extensions(restore)

	var paths: Array[String] = []
	for record: Dictionary in extension_records:
		paths.append(GF_VARIANT_ACCESS.get_option_string(record, "path"))

	assert_true(
		paths.has("res://addons/gf/extensions/save/editor/gf_save_graph_dock.gd"),
		"SaveGraph 工作区页面应由 Save 扩展 manifest 注册。"
	)
	var save_record: Dictionary = _dictionary_at(extension_records, 0)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(save_record, "label"), "GF Save", "Save 扩展页面应使用扩展名作为页面标题。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(save_record, "short_label"), "保存", "Save 扩展页面应提供短标签。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(save_record, "order"), 30, "Save 扩展页面应读取 manifest 中的工作区排序。")


func test_plugin_dock_tools_sorts_workspace_records_by_order() -> void:
	var tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	var records: Array[Dictionary] = [
		{"path": "res://z.gd", "label": "Z", "order": 30},
		{"path": "res://b.gd", "label": "B", "order": 10},
		{"path": "res://a.gd", "label": "A", "order": 10},
	]

	records.sort_custom(Callable(tools, "_sort_dock_records"))

	var labels: Array[String] = []
	for record: Dictionary in records:
		labels.append(GF_VARIANT_ACCESS.get_option_string(record, "label"))
	assert_eq(labels, ["A", "B", "Z"], "工作区页面应先按 order，再按标题稳定排序。")


func test_plugin_dock_tools_deduplicates_workspace_records_by_path() -> void:
	var tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	var records: Array[Dictionary] = [
		{"path": "res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd", "label": "Core Package", "order": 70},
		{"path": "res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd", "label": "Duplicate Package", "order": 1},
		{"path": "res://addons/gf/extensions/save/editor/gf_save_graph_dock.gd", "label": "Save", "order": 30},
	]

	var deduplicated: Array = _call_array(tools, &"_deduplicate_dock_records", [records])

	assert_eq(deduplicated.size(), 2, "工作区页面应按 path 全局去重。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(_dictionary_at(deduplicated, 0), "label"), "Core Package", "重复 path 应保留先出现的核心/标准记录。")


func test_plugin_dock_tools_creates_workspace_lazily() -> void:
	var tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	var base_control: Control = Control.new()
	add_child(base_control)
	var records: Array[Dictionary] = []
	tools.set(&"_editor_base_control", base_control)
	tools.set(&"_dock_records", records)

	var initial_window_value: Variant = _call_value(tools, &"get_workspace_window")
	assert_true(initial_window_value == null, "setup 不应立即实例化独立工作区窗口。")

	_call_void(tools, &"show_workspace")

	var window_value: Variant = _call_value(tools, &"get_workspace_window")
	assert_true(window_value is Window, "首次打开工作区时才应创建独立窗口。")
	var window_ref: WeakRef = null
	if window_value is Window:
		var window: Window = window_value
		window_ref = weakref(window)
		assert_eq(window.title, "GF Workspace", "懒加载窗口应保持统一标题。")
		assert_eq(window.get_parent(), base_control, "懒加载窗口应挂到编辑器根控件。")

	_call_void(tools, &"cleanup", [null])

	await get_tree().process_frame
	if window_ref != null:
		var released_window_value: Variant = window_ref.get_ref()
		assert_true(released_window_value == null, "cleanup 后懒加载窗口应在下一帧释放。")
	base_control.free()


func test_editor_workspace_dock_groups_gf_panels() -> void:
	var dock: Control = _new_control(GF_EDITOR_WORKSPACE_DOCK)
	var records: Array[Dictionary] = [
		{
			"path": "res://addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd",
			"label": "GF Storage Viewer",
		},
		{
			"path": "res://addons/gf/standard/input/editor/gf_input_mapping_dock.gd",
			"label": "GF Input Mapping",
		},
		{
			"path": "res://addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd",
			"label": "GF Signal Diagnostics",
		},
		{
			"path": "res://addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd",
			"label": "GF Diagnostics",
		},
		{
			"path": "res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd",
			"label": "GF Extensions",
		},
	]
	_call_void(dock, &"setup", [records])

	assert_eq(dock.name, "GF", "统一工作区根节点应保留 GF 名称。")
	assert_true(dock.clip_contents, "统一工作区应裁剪超出内容，避免覆盖 Godot 底部栏。")
	assert_eq(dock.custom_minimum_size, Vector2(0.0, 72.0), "统一工作区最小高度只应保留顶部入口区。")
	assert_eq(_call_int(dock, &"get_page_count"), 5, "工作区应把多个 GF 面板收束为内部页面。")
	assert_eq(
		_call_packed_string_array(dock, &"get_page_titles"),
		PackedStringArray(["GF Storage Viewer", "GF Input Mapping", "GF Signal Diagnostics", "GF Diagnostics", "GF Extensions"]),
		"页面标题应保留原面板语义。"
	)
	assert_eq(
		_call_packed_string_array(dock, &"get_page_button_titles"),
		PackedStringArray(["存储", "输入", "信号诊断", "诊断", "扩展"]),
		"响应式页面入口应使用短标签。"
	)
	var about_summary: String = _call_text(dock, &"get_about_text")
	assert_true(about_summary.contains("版本：%s" % _call_text(dock, &"_get_framework_version")), "关于弹窗应展示当前框架版本。")
	assert_true(about_summary.contains("https://github.com/C76GN/gf-framework"), "关于弹窗应提供项目地址。")
	assert_true(about_summary.contains("https://gf-framework.readthedocs.io/"), "关于弹窗应提供正式文档地址。")
	assert_true(about_summary.contains("https://github.com/C76GN/gf-framework/issues"), "关于弹窗应提供问题反馈地址。")
	assert_true(about_summary.contains("https://github.com/C76GN/gf-framework/releases"), "关于弹窗应提供发布记录地址。")
	assert_true(about_summary.contains("cl7o6dgyn@gmail.com"), "关于弹窗应提供联系邮箱。")
	var tabs: TabContainer = _get_tab_container(dock, &"_tabs")
	var page_count: int = _call_int(dock, &"get_page_count")
	for index: int in range(page_count):
		var page: Control = _as_control(tabs.get_child(index))
		var content: Control = _as_control(page.get_child(0))
		assert_true(page.clip_contents, "每个页面容器都应裁剪内容，避免覆盖底部栏。")
		assert_eq(page.custom_minimum_size, Vector2.ZERO, "页面容器不应继承内部工具最小高度。")
		assert_true(content.clip_contents, "被装入工作区的工具页面应裁剪自身溢出内容。")
		assert_eq(content.anchor_right, 1.0, "工具页面应横向铺满页面容器。")
		assert_eq(content.anchor_bottom, 1.0, "工具页面应纵向跟随页面容器。")

	_call_void(dock, &"_ensure_about_dialog")
	var about_dialog: AcceptDialog = _get_accept_dialog(dock, &"_about_dialog")
	var about_scroll: ScrollContainer = _as_scroll_container(about_dialog.get_node("AboutContent/AboutLayout/AboutScroll"))
	var about_text: RichTextLabel = _as_rich_text_label(about_dialog.get_node("AboutContent/AboutLayout/AboutScroll/AboutText"))
	var about_actions: HBoxContainer = _as_hbox_container(about_dialog.get_node("AboutContent/AboutLayout/AboutActionRow"))
	var about_issues: Button = _as_button(about_dialog.get_node("AboutContent/AboutLayout/AboutActionRow/AboutIssuesButton"))
	var about_releases: Button = _as_button(about_dialog.get_node("AboutContent/AboutLayout/AboutActionRow/AboutReleasesButton"))
	var about_version_check: Button = _as_button(about_dialog.get_node("AboutContent/AboutLayout/AboutActionRow/AboutVersionCheckButton"))
	var about_update_release: Button = _as_button(about_dialog.get_node("AboutContent/AboutLayout/AboutActionRow/AboutUpdateReleaseButton"))
	var about_version_status: Label = _as_label(about_dialog.get_node("AboutContent/AboutLayout/AboutVersionStatus"))
	var about_confirm: Button = _as_button(about_dialog.get_node("AboutContent/AboutLayout/AboutConfirmCenter/AboutConfirmButton"))
	assert_eq(about_dialog.min_size, Vector2i(560, 320), "关于弹窗应保持固定可控尺寸。")
	assert_eq(about_dialog.max_size, Vector2i(560, 320), "关于弹窗应限制最大尺寸，避免被编辑器窗口撑高。")
	assert_true(about_dialog.unresizable, "关于弹窗应避免被内容撑成过大的可调整窗口。")
	assert_false(about_dialog.wrap_controls, "关于弹窗不应按内容自动包裹成异常尺寸。")
	assert_eq(about_scroll.custom_minimum_size.y, 150.0, "关于正文区域应限制高度，避免长链接撑高弹窗。")
	assert_not_null(about_text, "关于弹窗应使用可点击链接文本。")
	assert_false(about_text.fit_content, "关于正文不应使用 fit_content，避免参与过长最小高度计算。")
	assert_true(about_text.text.contains("[url=https://github.com/C76GN/gf-framework]GitHub[/url]"), "项目地址应作为短正文链接呈现。")
	assert_true(about_text.text.contains("[url=https://gf-framework.readthedocs.io/]文档[/url]"), "文档地址应作为短正文链接呈现。")
	assert_true(about_text.text.contains("[url=https://github.com/C76GN/gf-framework/issues]Issues[/url]"), "Issues 地址应作为短正文链接呈现。")
	assert_true(about_text.text.contains("[url=https://github.com/C76GN/gf-framework/releases]Releases[/url]"), "Releases 地址应作为短正文链接呈现。")
	assert_true(about_text.text.contains("WeChat：C76_GN"), "关于弹窗应展示微信联系方式。")
	assert_true(about_text.text.contains("QQ：403150493"), "关于弹窗应展示 QQ 联系方式。")
	assert_not_null(about_actions, "关于弹窗应提供项目链接快捷按钮行。")
	assert_eq(about_issues.text, "Issues", "关于弹窗应提供 Issues 快捷按钮。")
	assert_eq(about_releases.text, "Releases", "关于弹窗应提供 Releases 快捷按钮。")
	assert_eq(about_version_check.text, "检测最新版本", "关于弹窗应提供手动版本检测按钮。")
	assert_eq(about_update_release.text, "打开更新页面", "关于弹窗应提供检测后的更新入口。")
	assert_false(about_update_release.visible, "更新入口应只在检测到新版本后显示。")
	assert_true(about_version_status.text.contains("当前版本："), "版本检测状态应先展示当前版本。")
	assert_true(about_version_status.text.contains("手动检测"), "版本检测状态应提示可手动检查最新发布版本。")
	assert_eq(_call_text(dock, &"_normalize_version_tag", ["refs/tags/v3.5.0-beta+1"]), "3.5.0", "版本号归一化应忽略 tag 前缀、预发布和构建元数据。")
	assert_eq(_call_int(dock, &"_compare_version_strings", ["v3.5.1", "3.5.0"]), 1, "更新版本应被识别为更高版本。")
	assert_eq(_call_int(dock, &"_compare_version_strings", ["3.5.0", "v3.5.0"]), 0, "相同版本应被识别为一致。")
	assert_eq(_call_int(dock, &"_compare_version_strings", ["3.4.9", "3.5.0"]), -1, "旧版本应被识别为更低版本。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string(_call_dictionary(dock, &"_make_latest_version_status", ["v3.5.1", "3.5.0"]), "message").contains("发现新版本"),
		"最新版本高于当前版本时应提示更新。"
	)
	var latest_release_url: String = "https://github.com/C76GN/gf-framework/releases/tag/3.5.1"
	var latest_status: Dictionary = _call_dictionary(dock, &"_make_latest_version_status", ["v3.5.1", "3.5.0", latest_release_url])
	assert_true(GF_VARIANT_ACCESS.get_option_bool(latest_status, "update_available"), "检测到新版本时应标记可更新。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(latest_status, "release_url"), latest_release_url, "更新入口应保留具体 Release URL。")
	assert_eq(
		_call_text(dock, &"_normalize_release_url", ["https://example.com/gf-framework/releases/tag/3.5.1"]),
		"https://github.com/C76GN/gf-framework/releases",
		"更新入口不应接受非官方 Release URL。"
	)
	assert_eq(
		_call_text(dock, &"_normalize_release_url", ["https://github.com/C76GN/gf-framework/releases.evil/tag/3.5.1"]),
		"https://github.com/C76GN/gf-framework/releases",
		"更新入口不应接受伪装成 releases 前缀的 URL。"
	)
	_call_void(dock, &"_apply_latest_version_status", [latest_status])
	assert_true(about_update_release.visible, "检测到新版本后应显示更新入口。")
	assert_false(about_update_release.disabled, "检测到新版本后更新入口应可点击。")
	assert_eq(GF_VARIANT_ACCESS.to_text(dock.get("_latest_release_url")), latest_release_url, "工作区应记录待打开的新版本 Release URL。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string(_call_dictionary(dock, &"_make_latest_version_status", ["v3.5.0", "3.5.0"]), "message").contains("当前已是最新版本"),
		"最新版本等于当前版本时应提示已是最新。"
	)
	add_child(dock)
	_call_void(dock, &"show_about_dialog")
	assert_eq(about_dialog.size, Vector2i(560, 320), "关于弹窗弹出后仍应保持紧凑尺寸。")
	assert_eq(about_dialog.mode, Window.MODE_WINDOWED, "关于弹窗弹出时应重置为普通窗口，避免沿用最大化状态。")
	about_dialog.hide()
	assert_false(about_dialog.get_ok_button().visible, "默认底部确认按钮应隐藏，避免按钮停在右下角。")
	assert_eq(about_confirm.text, "确定", "自定义确认按钮应使用中文确定。")
	assert_true(about_confirm.get_parent() is CenterContainer, "自定义确认按钮应放在居中容器中。")

	dock.free()


func test_editor_workspace_prefers_record_label_over_page_script_name() -> void:
	var dock: Control = _new_control(GF_EDITOR_WORKSPACE_DOCK)
	var records: Array[Dictionary] = [
		{
			"path": "res://addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd",
			"label": "GF Save",
		},
	]
	_call_void(dock, &"setup", [records])

	assert_eq(_call_packed_string_array(dock, &"get_page_titles"), PackedStringArray(["GF Save"]), "工作区页面标题应优先使用产品化记录标题。")
	assert_eq(_call_packed_string_array(dock, &"get_page_button_titles"), PackedStringArray(["保存"]), "短标签应从产品化标题派生。")

	dock.free()


func test_editor_workspace_window_hosts_workspace_pages() -> void:
	var window: Window = _new_window(GF_EDITOR_WORKSPACE_WINDOW)
	var records: Array[Dictionary] = [
		{
			"path": "res://addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd",
			"label": "GF Storage Viewer",
		},
		{
			"path": "res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd",
			"label": "GF Extensions",
		},
	]

	_call_void(window, &"setup", [records])

	assert_eq(window.title, "GF Workspace", "独立窗口应使用统一 GF 工作区标题。")
	assert_eq(window.min_size, Vector2i(900, 560), "独立窗口应提供足够的编辑器工作面积。")
	assert_eq(_call_int(window, &"get_page_count"), 2, "独立窗口应承载注入的工作区页面。")
	assert_eq(_call_packed_string_array(window, &"get_page_titles"), PackedStringArray(["GF Storage Viewer", "GF Extensions"]), "独立窗口应保留页面标题。")
	var workspace: Control = _call_control(window, &"get_workspace")
	assert_not_null(workspace, "独立窗口应持有内部工作区控件。")
	window.transient = true
	window.exclusive = true
	_call_void(window, &"set_always_on_top_enabled", [true])
	assert_true(_call_bool(window, &"is_always_on_top_enabled"), "独立工作区窗口应支持置顶。")
	assert_false(window.transient, "启用置顶前应解除 transient，避免 Godot 报错。")
	assert_false(window.exclusive, "启用置顶前应解除 exclusive，避免沿用临时弹窗语义。")
	var always_on_top_button: Button = _get_button(workspace, &"_always_on_top_button")
	assert_true(always_on_top_button.button_pressed, "工作区置顶按钮应同步窗口状态。")
	_call_void(workspace, &"_on_always_on_top_toggled", [false])
	assert_false(_call_bool(window, &"is_always_on_top_enabled"), "置顶按钮应能关闭独立窗口置顶。")

	window.free()


func test_package_manager_dock_uses_default_source_for_empty_registry() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var registry_field: LineEdit = _as_line_edit(dock.get(&"_registry_field"))
	registry_field.text = ""

	var channel_field: LineEdit = _as_line_edit(dock.get(&"_channel_field"))
	var install_button: Button = _get_button(dock, &"_install_button")
	var uninstall_button: Button = _get_button(dock, &"_uninstall_button")
	var uses_native_backend: bool = _call_bool(dock, &"_can_use_native_backend", [""])

	assert_eq(dock.name, "GF Package Manager", "包管理工作区页面应使用稳定页面名称。")
	assert_true(registry_field.placeholder_text.contains("默认在线源"), "空 registry 应走默认在线源而不是要求用户填写。")
	assert_true(registry_field.tooltip_text.contains("registry source"), "Registry 输入应说明 source manifest 能力。")
	assert_true(uses_native_backend, "空 registry 应继续使用 Godot 原生后端的默认 release source。")
	assert_false(dock.has_method(&"_run_python_operation"), "编辑器包管理页不应保留 Python fallback 安装路径。")
	assert_false(dock.has_method(&"_run_package_tool"), "编辑器包管理页不应直接执行外部 package tool。")
	assert_true(channel_field.visible, "普通用户路径应能选择 registry source channel。")
	assert_eq(channel_field.placeholder_text, "默认", "channel 留空时应使用 source manifest default_channel。")
	assert_true(install_button.disabled, "没有选中包时安装按钮应禁用。")
	assert_true(uninstall_button.disabled, "没有选中包时卸载按钮应禁用。")

	dock.free()


func test_package_manager_dock_builds_registry_source_channel_options() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var channel_field: LineEdit = _as_line_edit(dock.get(&"_channel_field"))
	channel_field.text = " stable "

	var options: Dictionary = _call_dictionary(dock, &"_make_backend_options")

	assert_eq(GF_VARIANT_ACCESS.get_option_string(options, "channel"), "stable", "包管理工作区应把 channel 传给 Godot 原生后端。")

	dock.free()


func test_package_manager_dock_formats_registry_source_diagnostics() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var status_data: Dictionary = {
		"registry": "C:/tmp/gf/package-cache/registries/index.json",
		"registry_remote": true,
		"registry_source": "http://127.0.0.1:9000/sources/gf-registry-source.json",
		"registry_source_manifest": "http://127.0.0.1:9000/sources/gf-registry-source.json",
		"registry_channel": "stable",
		"registry_mirror_index": 0,
		"registry_cache_dir": "C:/tmp/gf/package-cache",
	}

	var diagnostics: String = _call_text(dock, &"_format_registry_diagnostics", [status_data])
	var tooltip: String = _call_text(dock, &"_format_registry_diagnostics_tooltip", [status_data])

	assert_true(diagnostics.contains("source: http://127.0.0.1:9000/sources/gf-registry-source.json"), "包管理工作区应展示 registry source。")
	assert_true(diagnostics.contains("channel: stable"), "包管理工作区应展示选中的 registry channel。")
	assert_true(diagnostics.contains("mirror: #0"), "包管理工作区应展示命中的 mirror 索引。")
	assert_true(diagnostics.contains("remote"), "包管理工作区应展示 remote registry 状态。")
	assert_true(tooltip.contains("source_manifest: http://127.0.0.1:9000/sources/gf-registry-source.json"), "registry 诊断 tooltip 应保留 source manifest URL。")
	assert_true(tooltip.contains("cache_dir: C:/tmp/gf/package-cache"), "registry 诊断 tooltip 应保留 cache 目录。")

	dock.free()


func test_package_manager_dock_updates_registry_diagnostics_label() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var diagnostics_label: Label = _as_label(dock.get(&"_registry_diagnostics_label"))
	var status_data: Dictionary = {
		"registry": "res://build/registry/index.json",
		"registry_channel": "preview",
		"registry_mirror_index": -1,
	}

	_call_void(dock, &"_update_registry_diagnostics", [status_data])

	assert_true(diagnostics_label.text.contains("res://build/registry/index.json"), "registry 诊断标签应展示当前 registry。")
	assert_true(diagnostics_label.text.contains("channel: preview"), "registry 诊断标签应展示当前 channel。")
	assert_true(diagnostics_label.text.contains("mirror: primary"), "registry 诊断标签应展示 primary registry 命中状态。")

	dock.free()


func test_package_manager_dock_defaults_to_preset_first_view() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var packages: Array[Dictionary] = [
		_make_package_manager_entry("gf.extension.save", "extension"),
		_make_package_manager_entry("gf.standard.storage", "standard"),
		_make_package_manager_entry("gf.preset.rpg_save_dialogue", "preset"),
	]
	dock.set(&"_packages", packages)
	dock.set(&"_selected_package_id", "")

	_call_void(dock, &"_render_package_rows")
	_call_void(dock, &"_select_first_visible_package")

	var view_filter_option: OptionButton = _get_option_button(dock, &"_view_filter_option")
	var visible_packages: Array = _call_array(dock, &"_get_visible_packages")
	var selected_package_id: String = GF_VARIANT_ACCESS.to_text(dock.get(&"_selected_package_id"))
	var first_visible: Dictionary = _dictionary_at(visible_packages, 0)

	assert_eq(view_filter_option.get_item_text(view_filter_option.selected), "推荐组合", "包管理工作区默认应先展示 preset 组合。")
	assert_eq(visible_packages.size(), 1, "默认推荐组合视图应只展示 preset 包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_visible, "id"), "gf.preset.rpg_save_dialogue", "推荐组合视图应暴露 preset 包。")
	assert_eq(selected_package_id, "gf.preset.rpg_save_dialogue", "默认选中项应是第一个可见 preset。")

	dock.free()


func test_package_manager_dock_switches_to_extension_view() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var packages: Array[Dictionary] = [
		_make_package_manager_entry("gf.preset.rpg_save_dialogue", "preset"),
		_make_package_manager_entry("gf.extension.save", "extension"),
		_make_package_manager_entry("gf.standard.storage", "standard"),
	]
	dock.set(&"_packages", packages)
	var view_filter_option: OptionButton = _get_option_button(dock, &"_view_filter_option")
	view_filter_option.select(1)

	_call_void(dock, &"_on_view_filter_selected", [1])

	var visible_packages: Array = _call_array(dock, &"_get_visible_packages")
	var first_visible: Dictionary = _dictionary_at(visible_packages, 0)
	var selected_package_id: String = GF_VARIANT_ACCESS.to_text(dock.get(&"_selected_package_id"))

	assert_eq(visible_packages.size(), 1, "扩展包视图应只展示 extension 包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_visible, "id"), "gf.extension.save", "扩展包视图应暴露 raw extension 包。")
	assert_eq(selected_package_id, "gf.extension.save", "切换视图后应选中当前视图中的第一个包。")

	dock.free()


func test_extension_manager_dock_exposes_strict_reference_export_policy() -> void:
	var restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
		true
	)
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	_call_void(dock, &"_refresh_extensions")

	var export_fail_check: CheckBox = _get_check_box(dock, &"_export_fail_check")
	assert_not_null(export_fail_check, "扩展管理面板应暴露禁用扩展引用的严格导出策略。")
	assert_eq(export_fail_check.text, "引用禁用扩展时阻止导出", "严格导出策略应有清晰的 UI 文案。")
	assert_true(export_fail_check.button_pressed, "扩展管理面板应读取当前严格导出策略。")

	dock.free()
	_restore_project_setting(
		GF_EXTENSION_SETTINGS_BASE.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
		restore
	)


func test_extension_manager_dock_usage_audit_ignores_framework_outputs() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	var options: Dictionary = _call_dictionary(dock, &"_make_usage_audit_options")
	var ignored_roots: Array[String] = GF_VARIANT_ACCESS.get_option_string_array(options, "ignored_roots")

	assert_true(ignored_roots.has("res://ai_analysis"), "扩展管理面板不应把 AI 工作区算作项目引用风险。")
	assert_true(ignored_roots.has("res://site"), "扩展管理面板不应把生成站点算作项目引用风险。")
	assert_true(ignored_roots.has("res://tests/gf_core"), "扩展管理面板不应把 GF 框架测试算作用户项目引用风险。")
	assert_false(ignored_roots.has("res://tests"), "扩展管理面板不应泛化屏蔽用户项目测试目录。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(options, "max_references_per_extension"), 20, "面板引用风险预览应保持有限输出。")

	dock.free()


func test_extension_manager_dock_writes_setup_policy_to_project_settings() -> void:
	var enabled_restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)
	var auto_install_restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		true
	)
	var export_exclude_restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.EXPORT_EXCLUDE_DISABLED_SETTING,
		true
	)
	var export_fail_restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
		true
	)
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	_call_void(dock, &"_refresh_extensions")

	var auto_install_check: CheckBox = _get_check_box(dock, &"_auto_install_check")
	var export_exclude_check: CheckBox = _get_check_box(dock, &"_export_exclude_check")
	var export_fail_check: CheckBox = _get_check_box(dock, &"_export_fail_check")
	assert_true(auto_install_check.button_pressed, "扩展 setup 面板应读取 Installer 自动装配设置。")
	assert_true(export_exclude_check.button_pressed, "扩展 setup 面板应读取导出排除设置。")
	assert_true(export_fail_check.button_pressed, "扩展 setup 面板应读取禁用引用失败设置。")

	_call_void(dock, &"_set_all_enabled", [false])
	auto_install_check.button_pressed = false
	export_exclude_check.button_pressed = false
	export_fail_check.button_pressed = false
	_call_void(dock, &"_write_selection_to_project_settings")

	var stored_enabled_ids: Array[String] = GF_EXTENSION_SETTINGS_BASE.get_enabled_extension_ids()
	var stored_selection_mode: String = GF_EXTENSION_SETTINGS_BASE.get_extension_selection_mode()
	var stored_auto_install: bool = GF_EXTENSION_SETTINGS_BASE.should_auto_install_enabled_installers()
	var stored_export_exclude: bool = GF_EXTENSION_SETTINGS_BASE.should_export_exclude_disabled_extensions()
	var stored_export_fail: bool = GF_EXTENSION_SETTINGS_BASE.should_fail_export_on_disabled_extension_references()

	dock.free()
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING, export_fail_restore)
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.EXPORT_EXCLUDE_DISABLED_SETTING, export_exclude_restore)
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, auto_install_restore)
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING, enabled_restore)

	assert_eq(stored_enabled_ids, [], "扩展 setup 面板应把当前勾选状态写入启用扩展设置。")
	assert_eq(stored_selection_mode, GF_EXTENSION_SETTINGS_BASE.SELECTION_MODE_EXPLICIT, "手动勾选保存应进入显式扩展选择模式。")
	assert_false(stored_auto_install, "扩展 setup 面板应保存 Installer 自动装配策略。")
	assert_false(stored_export_exclude, "扩展 setup 面板应保存导出排除策略。")
	assert_false(stored_export_fail, "扩展 setup 面板应保存禁用引用失败策略。")


func test_extension_manager_dock_restore_default_writes_default_selection_mode() -> void:
	var enabled_restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)
	var mode_restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
		GF_EXTENSION_SETTINGS_BASE.SELECTION_MODE_EXPLICIT
	)
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	_call_void(dock, &"_refresh_extensions")

	_call_void(dock, &"_restore_default_selection")
	_call_void(dock, &"_write_selection_to_project_settings")
	var stored_selection_mode: String = GF_EXTENSION_SETTINGS_BASE.get_extension_selection_mode()

	dock.free()
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING, mode_restore)
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING, enabled_restore)

	assert_eq(stored_selection_mode, GF_EXTENSION_SETTINGS_BASE.SELECTION_MODE_DEFAULT, "恢复默认保存时应保留 default 模式，而不是固化当前默认列表。")


func test_extension_manager_dock_exposes_extension_presets() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	_call_void(dock, &"_refresh_extensions")
	var preset_option: OptionButton = _get_option_button(dock, &"_preset_option")
	assert_not_null(preset_option, "扩展管理面板应暴露 preset 选择器。")

	var preset_labels: PackedStringArray = PackedStringArray()
	for index: int in range(preset_option.item_count):
		var _append_result: bool = preset_labels.append(preset_option.get_item_text(index))

	var applied: bool = _call_bool(dock, &"_apply_extension_preset_by_id", [&"gf.none"])
	var selected_ids: Array = _call_array(dock, &"_get_selected_enabled_ids")

	assert_true(preset_labels.has("默认选择"), "扩展管理面板应提供动态默认选择 preset。")
	assert_true(preset_labels.has("全部关闭"), "扩展管理面板应提供全部关闭 preset。")
	assert_true(preset_labels.has("全部扩展"), "扩展管理面板应提供全部扩展 preset。")
	assert_true(applied, "扩展管理面板应能应用 preset 到当前勾选状态。")
	assert_true(selected_ids.is_empty(), "全部关闭 preset 应清空当前扩展选择。")

	dock.free()


func test_extension_manager_dock_manages_project_preset_file_paths() -> void:
	var preset_path: String = "res://tests/gf_core/kernel/editor/tmp_project_tools_preset.json"
	_remove_path_if_exists(preset_path)
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.tools",
		"display_name": "Project Tools",
		"description": "Project preset from editor dock.",
		"extension_ids": ["gf.save"],
	}))
	var restore: Dictionary = _set_project_setting(
		GF_EXTENSION_SETTINGS_BASE.EXTENSION_PRESET_PATHS_SETTING,
		[]
	)
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	_call_void(dock, &"_refresh_extensions")
	_call_void(dock, &"_ensure_preset_file_dialog")

	var added: bool = _call_bool(dock, &"_add_extension_preset_path", [preset_path.replace("/", "\\")])
	var paths_after_add: Array[String] = GF_EXTENSION_SETTINGS_BASE.get_extension_preset_paths()
	var preset_option: OptionButton = _get_option_button(dock, &"_preset_option")
	var selected: bool = _select_option_by_text(preset_option, "Project Tools")
	var removed: bool = _call_bool(dock, &"_remove_selected_preset_path")
	var paths_after_remove: Array[String] = GF_EXTENSION_SETTINGS_BASE.get_extension_preset_paths()
	var preset_file_dialog: FileDialog = _get_file_dialog(dock, &"_preset_file_dialog")
	var preset_file_dialog_mode: int = preset_file_dialog.file_mode
	var preset_file_dialog_access: int = preset_file_dialog.access
	var has_json_filter: bool = preset_file_dialog.filters.has("*.json ; JSON 文件")

	dock.free()
	_restore_project_setting(GF_EXTENSION_SETTINGS_BASE.EXTENSION_PRESET_PATHS_SETTING, restore)
	_remove_path_if_exists(preset_path)

	assert_true(added, "扩展管理面板应能把项目 preset JSON 路径加入 ProjectSettings。")
	assert_eq(paths_after_add, [preset_path], "扩展管理面板应按规范化 res:// 路径保存 preset JSON。")
	assert_true(selected, "新增项目 preset 应出现在扩展组合下拉框中。")
	assert_true(removed, "扩展管理面板应能移除当前项目 preset JSON 路径。")
	assert_eq(paths_after_remove, [], "移除项目 preset 后 ProjectSettings 路径列表应为空。")
	assert_eq(preset_file_dialog_mode, FileDialog.FILE_MODE_OPEN_FILE, "preset 文件选择器应只打开已有 JSON。")
	assert_eq(preset_file_dialog_access, FileDialog.ACCESS_RESOURCES, "preset 文件选择器应限制在 res:// 资源路径。")
	assert_true(has_json_filter, "preset 文件选择器应只提示 JSON 文件。")


func test_extension_manager_dock_clears_rows_immediately() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_EXTENSION_MANAGER_DOCK)
	var first: Label = Label.new()
	var second: Label = Label.new()
	var extension_rows: VBoxContainer = _get_vbox_container(dock, &"_extension_rows")
	extension_rows.add_child(first)
	extension_rows.add_child(second)

	_call_void(dock, &"_clear_extension_rows")

	assert_eq(extension_rows.get_child_count(), 0, "刷新扩展列表时旧行应立即从容器移除。")
	assert_null(first.get_parent(), "第一行应立即脱离扩展列表容器。")
	assert_null(second.get_parent(), "第二行应立即脱离扩展列表容器。")

	await get_tree().process_frame
	assert_false(is_instance_valid(first), "下一帧第一行应完成释放。")
	assert_false(is_instance_valid(second), "下一帧第二行应完成释放。")
	dock.free()


# --- 私有/辅助方法 ---

func _make_preview_test_texture(color: Color) -> Texture2D:
	var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _get_preview_result_texture(result: Dictionary) -> Texture2D:
	var value: Variant = GF_VARIANT_ACCESS.get_option_value(result, "texture")
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


func _set_enabled_extensions(extension_ids: Array[String]) -> Dictionary:
	var setting_name: String = GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING
	var restore: Dictionary = {
		"had_setting": ProjectSettings.has_setting(setting_name),
		"value": ProjectSettings.get_setting(setting_name, []),
		"selection_mode_had_setting": ProjectSettings.has_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING
		),
		"selection_mode_value": ProjectSettings.get_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
			null
		),
	}
	ProjectSettings.set_setting(setting_name, extension_ids)
	ProjectSettings.set_setting(
		GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
		GF_EXTENSION_SETTINGS_BASE.SELECTION_MODE_EXPLICIT
	)
	return restore


func _restore_enabled_extensions(restore: Dictionary) -> void:
	var setting_name: String = GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING
	if GF_VARIANT_ACCESS.get_option_bool(restore, "had_setting"):
		ProjectSettings.set_setting(setting_name, GF_VARIANT_ACCESS.get_option_value(restore, "value", []))
	else:
		ProjectSettings.clear(setting_name)
	if GF_VARIANT_ACCESS.get_option_bool(restore, "selection_mode_had_setting"):
		ProjectSettings.set_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
			GF_VARIANT_ACCESS.get_option_value(restore, "selection_mode_value", null)
		)
	else:
		ProjectSettings.clear(GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING)


func _mark_workspace_ui_button_pressed(state: WorkspaceButtonState) -> void:
	state.count += 1


func _set_project_setting(setting_name: String, value: Variant) -> Dictionary:
	var restore: Dictionary = {
		"had_setting": ProjectSettings.has_setting(setting_name),
		"value": ProjectSettings.get_setting(setting_name, null),
	}
	if setting_name == GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING:
		restore["selection_mode_had_setting"] = ProjectSettings.has_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING
		)
		restore["selection_mode_value"] = ProjectSettings.get_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
			null
		)
	ProjectSettings.set_setting(setting_name, value)
	if setting_name == GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING:
		ProjectSettings.set_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
			GF_EXTENSION_SETTINGS_BASE.SELECTION_MODE_EXPLICIT
		)
	return restore


func _restore_project_setting(setting_name: String, restore: Dictionary) -> void:
	if GF_VARIANT_ACCESS.get_option_bool(restore, "had_setting"):
		ProjectSettings.set_setting(setting_name, GF_VARIANT_ACCESS.get_option_value(restore, "value", null))
	else:
		_clear_project_setting_if_exists(setting_name)
	if setting_name != GF_EXTENSION_SETTINGS_BASE.ENABLED_EXTENSIONS_SETTING:
		return

	if GF_VARIANT_ACCESS.get_option_bool(restore, "selection_mode_had_setting"):
		ProjectSettings.set_setting(
			GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING,
			GF_VARIANT_ACCESS.get_option_value(restore, "selection_mode_value", null)
		)
	else:
		_clear_project_setting_if_exists(GF_EXTENSION_SETTINGS_BASE.EXTENSION_SELECTION_MODE_SETTING)


func _clear_project_setting_if_exists(setting_name: String) -> void:
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)


func _find_project_setting_property_info(setting_name: String) -> Dictionary:
	for property_info: Dictionary in ProjectSettings.get_property_list():
		if GF_VARIANT_ACCESS.get_option_string(property_info, "name") == setting_name:
			return property_info
	return {}


func _clear_test_project_settings() -> void:
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = GF_VARIANT_ACCESS.get_option_string(property_info, "name")
		if setting_name.begins_with(_TEST_PROJECT_SETTING_PREFIX):
			ProjectSettings.clear(setting_name)


func _write_text_file(path: String, text: String) -> void:
	var write_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var file: FileAccess = FileAccess.open(write_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时文本文件。")
	if file == null:
		return
	var _store_string_result: Variant = file.store_string(text)
	file.close()


func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)


func _count_report_issue_kind(report: Dictionary, issue_kind: String) -> int:
	var count: int = 0
	for issue_value: Variant in GF_VARIANT_ACCESS.get_option_array(report, "issues"):
		var issue: Dictionary = GF_VARIANT_ACCESS.as_dictionary(issue_value)
		if GF_VARIANT_ACCESS.get_option_string(issue, "kind") == issue_kind:
			count += 1
	return count


func _load_script_resource(path: String) -> Script:
	var resource: Resource = load(path)
	assert_true(resource is Script, "测试资源路径应指向 Script：%s" % path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _get_standard_editor_records(method_name: StringName) -> Array[Dictionary]:
	var record_key: String = _standard_method_to_record_key(method_name)
	if record_key.is_empty():
		return []
	var records: Array[Dictionary] = []
	var manifest_records: Dictionary = GF_EDITOR_CONTRIBUTION_REGISTRY.load_manifest_records(GF_STANDARD_EDITOR_CONTRIBUTIONS_PATH)
	var value: Variant = manifest_records.get(record_key, [])
	if not (value is Array):
		return records
	var raw_records: Array = value
	for raw_record: Variant in raw_records:
		if raw_record is Dictionary:
			var record: Dictionary = raw_record
			records.append(record.duplicate(true))
	return records


func _standard_method_to_record_key(method_name: StringName) -> String:
	match method_name:
		&"get_inspector_plugin_records":
			return "inspector_plugin_records"
		&"get_export_plugin_records":
			return "export_plugin_records"
		&"get_debugger_plugin_records":
			return "debugger_plugin_records"
		&"get_dock_records":
			return "dock_records"
		&"get_template_records":
			return "template_records"
		&"get_project_setting_records":
			return "project_setting_records"
		_:
			return ""


func _read_text_file(path: String) -> String:
	var read_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var file: FileAccess = FileAccess.open(read_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取文本文件：%s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _extract_function_source(source: String, start_marker: String, end_marker: String) -> String:
	var start_index: int = source.find(start_marker)
	assert_gte(start_index, 0, "测试 helper 应能找到函数起点。")
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_marker, start_index)
	assert_gt(end_index, start_index, "测试 helper 应能找到函数终点。")
	if end_index <= start_index:
		return source.substr(start_index)
	return source.substr(start_index, end_index - start_index)


func _new_object(script: Variant) -> Object:
	assert_true(script is Script, "测试 helper 脚本应是可实例化 Script。")
	if script is Script:
		var helper_script: Script = script
		var instance: Variant = helper_script.call(&"new")
		assert_true(instance is Object, "测试 helper 脚本应实例化为 Object。")
		if instance is Object:
			var object_instance: Object = instance
			return object_instance
	return null


func _new_control(script: Variant) -> Control:
	var object_instance: Object = _new_object(script)
	assert_true(object_instance is Control, "测试 helper 脚本应实例化为 Control。")
	if object_instance is Control:
		var control: Control = object_instance
		return control
	return null


func _new_vbox_container(script: Variant) -> VBoxContainer:
	var object_instance: Object = _new_object(script)
	assert_true(object_instance is VBoxContainer, "测试 helper 脚本应实例化为 VBoxContainer。")
	if object_instance is VBoxContainer:
		var container: VBoxContainer = object_instance
		return container
	return null


func _new_window(script: Variant) -> Window:
	var object_instance: Object = _new_object(script)
	assert_true(object_instance is Window, "测试 helper 脚本应实例化为 Window。")
	if object_instance is Window:
		var window: Window = object_instance
		return window
	return null


func _call_value(target: Object, method_name: StringName, args: Array = []) -> Variant:
	assert_not_null(target, "测试 helper 反射调用目标不能为空：%s" % method_name)
	if target == null:
		return null
	assert_true(target.has_method(method_name), "测试 helper 反射调用目标应包含方法：%s" % method_name)
	if not target.has_method(method_name):
		return null
	return target.callv(method_name, args)


func _call_void(target: Object, method_name: StringName, args: Array = []) -> void:
	var _call_result: Variant = _call_value(target, method_name, args)


func _call_array(target: Object, method_name: StringName, args: Array = []) -> Array:
	return GF_VARIANT_ACCESS.as_array(_call_value(target, method_name, args))


func _call_dictionary(target: Object, method_name: StringName, args: Array = []) -> Dictionary:
	return GF_VARIANT_ACCESS.as_dictionary(_call_value(target, method_name, args))


func _call_int(target: Object, method_name: StringName, args: Array = []) -> int:
	return GF_VARIANT_ACCESS.to_int(_call_value(target, method_name, args))


func _call_bool(target: Object, method_name: StringName, args: Array = []) -> bool:
	return GF_VARIANT_ACCESS.to_bool(_call_value(target, method_name, args))


func _call_text(target: Object, method_name: StringName, args: Array = []) -> String:
	return GF_VARIANT_ACCESS.to_text(_call_value(target, method_name, args))


func _call_packed_string_array(target: Object, method_name: StringName, args: Array = []) -> PackedStringArray:
	var value: Variant = _call_value(target, method_name, args)
	if value is PackedStringArray:
		var strings: PackedStringArray = value
		return strings
	if value is Array:
		var values: Array = value
		var result: PackedStringArray = PackedStringArray()
		for item: Variant in values:
			var _append_result: bool = result.append(GF_VARIANT_ACCESS.to_text(item))
		return result
	return PackedStringArray()


func _call_control(target: Object, method_name: StringName, args: Array = []) -> Control:
	var value: Variant = _call_value(target, method_name, args)
	assert_true(value is Control, "测试观察值应为 Control。")
	if value is Control:
		var control: Control = value
		return control
	return null


func _dictionary_at(values: Array, index: int) -> Dictionary:
	assert_true(index >= 0 and index < values.size(), "测试记录索引应在数组范围内。")
	var value: Variant = values[index] if index >= 0 and index < values.size() else {}
	assert_true(value is Dictionary, "测试记录应为 Dictionary。")
	return GF_VARIANT_ACCESS.as_dictionary(value)


func _record_array_has_identity(records: Array, identity_key: String, identity: String) -> bool:
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if GF_VARIANT_ACCESS.get_option_string(record, identity_key) == identity:
			return true
	return false


func _make_package_manager_entry(package_id: String, kind: String) -> Dictionary:
	return {
		"id": package_id,
		"kind": kind,
		"version": "unreleased",
		"display_name": package_id,
		"description": "Package manager test fixture.",
		"dependencies": [],
		"packages": [],
		"paths": [],
		"installed": false,
		"reason": [],
		"required_by": [],
		"install_preview": {
			"ok": true,
			"install_order": [package_id],
			"to_install": [package_id],
			"to_update": [],
		},
		"uninstall_preview": {},
	}


func _select_option_by_text(option_button: OptionButton, text: String) -> bool:
	if option_button == null:
		return false

	for index: int in range(option_button.item_count):
		if option_button.get_item_text(index) == text:
			option_button.select(index)
			return true
	return false


func _get_tab_container(target: Object, property_name: StringName) -> TabContainer:
	return _as_tab_container(target.get(property_name))


func _get_accept_dialog(target: Object, property_name: StringName) -> AcceptDialog:
	return _as_accept_dialog(target.get(property_name))


func _get_button(target: Object, property_name: StringName) -> Button:
	return _as_button(target.get(property_name))


func _get_check_box(target: Object, property_name: StringName) -> CheckBox:
	return _as_check_box(target.get(property_name))


func _get_option_button(target: Object, property_name: StringName) -> OptionButton:
	return _as_option_button(target.get(property_name))


func _get_vbox_container(target: Object, property_name: StringName) -> VBoxContainer:
	return _as_vbox_container(target.get(property_name))


func _get_file_dialog(target: Object, property_name: StringName) -> FileDialog:
	return _as_file_dialog(target.get(property_name))


func _as_file_dialog(value: Variant) -> FileDialog:
	assert_true(value is FileDialog, "测试观察值应为 FileDialog。")
	if value is FileDialog:
		var dialog: FileDialog = value
		return dialog
	return null


func _as_control(value: Variant) -> Control:
	assert_true(value is Control, "测试观察值应为 Control。")
	if value is Control:
		var control: Control = value
		return control
	return null


func _as_scroll_container(value: Variant) -> ScrollContainer:
	assert_true(value is ScrollContainer, "测试观察值应为 ScrollContainer。")
	if value is ScrollContainer:
		var control: ScrollContainer = value
		return control
	return null


func _as_rich_text_label(value: Variant) -> RichTextLabel:
	assert_true(value is RichTextLabel, "测试观察值应为 RichTextLabel。")
	if value is RichTextLabel:
		var label: RichTextLabel = value
		return label
	return null


func _as_hbox_container(value: Variant) -> HBoxContainer:
	assert_true(value is HBoxContainer, "测试观察值应为 HBoxContainer。")
	if value is HBoxContainer:
		var container: HBoxContainer = value
		return container
	return null


func _as_vbox_container(value: Variant) -> VBoxContainer:
	assert_true(value is VBoxContainer, "测试观察值应为 VBoxContainer。")
	if value is VBoxContainer:
		var container: VBoxContainer = value
		return container
	return null


func _as_tab_container(value: Variant) -> TabContainer:
	assert_true(value is TabContainer, "测试观察值应为 TabContainer。")
	if value is TabContainer:
		var container: TabContainer = value
		return container
	return null


func _as_accept_dialog(value: Variant) -> AcceptDialog:
	assert_true(value is AcceptDialog, "测试观察值应为 AcceptDialog。")
	if value is AcceptDialog:
		var dialog: AcceptDialog = value
		return dialog
	return null


func _as_button(value: Variant) -> Button:
	assert_true(value is Button, "测试观察值应为 Button。")
	if value is Button:
		var button: Button = value
		return button
	return null


func _as_line_edit(value: Variant) -> LineEdit:
	assert_true(value is LineEdit, "测试观察值应为 LineEdit。")
	if value is LineEdit:
		var line_edit: LineEdit = value
		return line_edit
	return null


func _as_check_box(value: Variant) -> CheckBox:
	assert_true(value is CheckBox, "测试观察值应为 CheckBox。")
	if value is CheckBox:
		var check_box: CheckBox = value
		return check_box
	return null


func _as_option_button(value: Variant) -> OptionButton:
	assert_true(value is OptionButton, "测试观察值应为 OptionButton。")
	if value is OptionButton:
		var option_button: OptionButton = value
		return option_button
	return null


func _as_label(value: Variant) -> Label:
	assert_true(value is Label, "测试观察值应为 Label。")
	if value is Label:
		var label: Label = value
		return label
	return null


# --- 辅助类型 ---

class WorkspaceButtonState:
	extends RefCounted

	var count: int = 0


class FakePluginActionDependencies:
	extends RefCounted

	var access_output_path: String = "user://gf_fake_access.gd"
	var project_access_output_path: String = "user://gf_fake_project_access.gd"
	var generated_access_path: String = ""
	var generated_project_access_path: String = ""
	var editor_action_path_call_count: int = 0

	func get_access_output_path() -> String:
		return access_output_path

	func get_project_access_output_path() -> String:
		return project_access_output_path

	func generate_accessors(output_path: String) -> Error:
		generated_access_path = output_path
		return OK

	func generate_project_accessors(output_path: String) -> Error:
		generated_project_access_path = output_path
		return OK

	func get_enabled_editor_action_paths() -> Array[String]:
		editor_action_path_call_count += 1
		return []


class PreviewIconResource:
	extends Resource

	var icon: Texture2D = null


class PreviewSourceProvider:
	extends RefCounted

	var texture: Texture2D = null

	func get_preview_texture(_resource: Resource) -> Texture2D:
		return texture


class HugePreviewTexture:
	extends Texture2D

	var image_requested: bool = false

	func _get_width() -> int:
		return 8192

	func _get_height() -> int:
		return 8192

	func _get_image() -> Image:
		image_requested = true
		var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 0.0, 0.0, 1.0))
		return image


class PreviewMethodResource:
	extends Resource

	var icon: Texture2D = null
	var preview_texture: Texture2D = null

	func get_gf_preview_texture() -> Texture2D:
		return preview_texture
