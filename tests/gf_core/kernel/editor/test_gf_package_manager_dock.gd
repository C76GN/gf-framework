extends GutTest


# --- 常量 ---

const GF_PACKAGE_MANAGER_DOCK = preload("res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_uses_default_source_for_empty_registry() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var registry_field: LineEdit = _as_line_edit(dock.get(&"_registry_field"))
	registry_field.text = ""

	var channel_field: LineEdit = _as_line_edit(dock.get(&"_channel_field"))
	var install_button: Button = _get_button(dock, &"_install_button")
	var uninstall_button: Button = _get_button(dock, &"_uninstall_button")
	var uses_native_backend: bool = _call_bool(dock, &"_can_use_native_backend", [""])

	assert_eq(dock.name, "GF Package Manager", "包管理工作区页面应使用稳定页面名称。")
	assert_true(registry_field.placeholder_text.contains("默认在线源"), "空 registry 应走默认在线源而不是要求用户填写。")
	assert_true(registry_field.placeholder_text.contains("offline bundle"), "Registry 输入应提示离线 bundle zip 能力。")
	assert_true(registry_field.tooltip_text.contains("registry source"), "Registry 输入应说明 source manifest 能力。")
	assert_true(registry_field.tooltip_text.contains("offline bundle"), "Registry 输入 tooltip 应说明离线 bundle zip 能力。")
	assert_true(uses_native_backend, "空 registry 应继续使用 Godot 原生后端的默认 release source。")
	assert_false(dock.has_method(&"_run_python_operation"), "编辑器包管理页不应保留 Python fallback 安装路径。")
	assert_false(dock.has_method(&"_run_package_tool"), "编辑器包管理页不应直接执行外部 package tool。")
	assert_true(channel_field.visible, "普通用户路径应能选择 registry source channel。")
	assert_eq(channel_field.placeholder_text, "默认", "channel 留空时应使用 source manifest default_channel。")
	assert_true(install_button.disabled, "没有选中包时安装按钮应禁用。")
	assert_true(uninstall_button.disabled, "没有选中包时卸载按钮应禁用。")

	dock.free()


func test_prefers_local_registry_source_when_generated() -> void:
	var local_source_path: String = "res://build/registry/gf-registry-source.json"
	var absolute_local_source_path: String = ProjectSettings.globalize_path(local_source_path)
	var existed: bool = FileAccess.file_exists(absolute_local_source_path)
	if not existed:
		var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/registry"))
		_write_text_file(local_source_path, "{}")

	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var registry_field: LineEdit = _as_line_edit(dock.get(&"_registry_field"))
	var selected_registry_path: String = registry_field.text

	dock.free()
	if not existed:
		_remove_path_if_exists(local_source_path)
		_remove_path_if_exists("res://build/registry")
		_remove_path_if_exists("res://build")

	assert_eq(selected_registry_path, absolute_local_source_path, "开发态已生成本地 registry source 时，包管理页应优先使用本地源。")


func test_builds_registry_source_channel_options() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var channel_field: LineEdit = _as_line_edit(dock.get(&"_channel_field"))
	channel_field.text = " stable "

	var options: Dictionary = _call_dictionary(dock, &"_make_backend_options")

	assert_eq(GF_VARIANT_ACCESS.get_option_string(options, "channel"), "stable", "包管理工作区应把 channel 传给 Godot 原生后端。")

	dock.free()


func test_formats_registry_source_diagnostics() -> void:
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


func test_formats_offline_bundle_diagnostics() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var status_data: Dictionary = {
		"registry": "C:/project/.gf/package_cache/offline_bundles/abc/registry/index.json",
		"registry_source": "C:/downloads/gf-package-offline-bundle.zip",
		"registry_offline_bundle": "C:/downloads/gf-package-offline-bundle.zip",
		"registry_offline_bundle_extracted": "C:/project/.gf/package_cache/offline_bundles/abc",
		"registry_cache_dir": "C:/project/.gf/package_cache",
	}

	var diagnostics: String = _call_text(dock, &"_format_registry_diagnostics", [status_data])
	var tooltip: String = _call_text(dock, &"_format_registry_diagnostics_tooltip", [status_data])

	assert_true(diagnostics.contains("offline bundle"), "包管理工作区应展示离线 bundle registry 来源。")
	assert_true(tooltip.contains("offline_bundle: C:/downloads/gf-package-offline-bundle.zip"), "registry 诊断 tooltip 应保留离线 bundle 路径。")
	assert_true(tooltip.contains("offline_bundle_extracted: C:/project/.gf/package_cache/offline_bundles/abc"), "registry 诊断 tooltip 应保留离线 bundle 解包路径。")

	dock.free()


func test_updates_registry_diagnostics_label() -> void:
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


func test_defaults_to_preset_first_view() -> void:
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


func test_formats_package_row_status_markers() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var available_entry: Dictionary = _make_package_manager_entry("gf.extension.save", "extension")
	var installed_entry: Dictionary = _make_package_manager_entry("gf.standard.storage", "standard")
	installed_entry["installed"] = true
	var update_entry: Dictionary = _make_package_manager_entry("gf.standard.ui", "standard")
	update_entry["installed"] = true
	update_entry["install_preview"] = {
		"ok": true,
		"install_order": ["gf.standard.ui"],
		"to_install": [],
		"to_update": ["gf.standard.ui"],
	}

	var available_text: String = _call_text(dock, &"_format_package_row_text", [available_entry])
	var installed_text: String = _call_text(dock, &"_format_package_row_text", [installed_entry])
	var update_text: String = _call_text(dock, &"_format_package_row_text", [update_entry])
	var installed_details: String = _call_text(dock, &"_format_package_details", [installed_entry])

	assert_true(available_text.begins_with("[+ 可安装]"), "未安装包列表行应明确显示可安装状态。")
	assert_true(installed_text.begins_with("[✓ 已安装]"), "已安装包列表行应显示对勾状态。")
	assert_true(update_text.begins_with("[↑ 可更新]"), "已安装且存在更新计划的包应显示可更新状态。")
	assert_true(installed_details.contains("status: ✓ 已安装"), "包详情应同步显示人读状态。")

	dock.free()


func test_status_summary_explains_source_checkout_lockfile_state() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var status_data: Dictionary = {
		"backend": "godot_native",
		"package_count": 35,
		"installed_count": 0,
	}

	var summary: String = _call_text(dock, &"_format_status_summary", [status_data])

	assert_true(summary.contains("35 个包，已安装 0 个"), "状态摘要应继续展示包计数。")
	assert_true(summary.contains("源码目录存在不代表已安装"), "GF 源码仓库中应解释 lockfile 状态来源。")
	assert_true(summary.contains(".gf/packages.lock.json"), "开发态提示应指出包状态依据 lockfile。")

	dock.free()


func test_busy_state_shows_progress_and_locks_package_controls() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var registry_field: LineEdit = _as_line_edit(dock.get(&"_registry_field"))
	var channel_field: LineEdit = _as_line_edit(dock.get(&"_channel_field"))
	var search_field: LineEdit = _as_line_edit(dock.get(&"_search_field"))
	var view_filter_option: OptionButton = _get_option_button(dock, &"_view_filter_option")
	var refresh_button: Button = _get_button(dock, &"_refresh_button")
	var install_button: Button = _get_button(dock, &"_install_button")
	var uninstall_button: Button = _get_button(dock, &"_uninstall_button")
	var busy_row: HBoxContainer = _as_hbox_container(dock.get(&"_busy_row"))
	var busy_progress: ProgressBar = _as_progress_bar(dock.get(&"_busy_progress"))
	var busy_label: Label = _as_label(dock.get(&"_busy_message_label"))
	var packages: Array[Dictionary] = [_make_package_manager_entry("gf.extension.save", "extension")]
	dock.set(&"_packages", packages)
	dock.set(&"_selected_package_id", "gf.extension.save")
	_call_void(dock, &"_update_action_buttons")

	assert_false(install_button.disabled, "选中未安装包后安装按钮应可用。")
	assert_true(uninstall_button.disabled, "未安装包不允许直接卸载。")

	_call_void(dock, &"_begin_busy", ["正在安装：gf.extension.save...", 32.0])

	assert_true(busy_row.visible, "包管理操作开始后应显示进度区域。")
	assert_eq(busy_progress.value, 32.0, "忙碌状态应记录当前阶段进度。")
	assert_true(busy_label.text.contains("正在安装"), "忙碌状态应展示当前后台阶段。")
	assert_false(registry_field.editable, "后台操作期间 registry 输入应锁定。")
	assert_false(channel_field.editable, "后台操作期间 channel 输入应锁定。")
	assert_false(search_field.editable, "后台操作期间搜索输入应锁定。")
	assert_true(view_filter_option.disabled, "后台操作期间视图切换应锁定。")
	assert_true(refresh_button.disabled, "后台操作期间刷新按钮应锁定。")
	assert_true(install_button.disabled, "后台操作期间安装按钮应锁定。")

	_call_void(dock, &"_end_busy")

	assert_false(busy_row.visible, "后台操作结束后应隐藏进度区域。")
	assert_true(registry_field.editable, "后台操作结束后 registry 输入应恢复。")
	assert_true(channel_field.editable, "后台操作结束后 channel 输入应恢复。")
	assert_true(search_field.editable, "后台操作结束后搜索输入应恢复。")
	assert_false(view_filter_option.disabled, "后台操作结束后视图切换应恢复。")
	assert_false(refresh_button.disabled, "后台操作结束后刷新按钮应恢复。")
	assert_false(install_button.disabled, "后台操作结束后安装按钮应按包状态恢复。")

	dock.free()


func test_switches_to_extension_view() -> void:
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


func test_formats_install_dependency_risk_summary() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var package_entry: Dictionary = _make_package_manager_entry("gf.extension.save", "extension")
	package_entry["dependencies"] = ["gf.kernel", "gf.standard.storage"]
	package_entry["install_preview"] = {
		"ok": true,
		"install_order": ["gf.kernel", "gf.standard.storage", "gf.extension.save"],
		"to_install": ["gf.standard.storage", "gf.extension.save"],
		"to_update": ["gf.kernel"],
	}

	var details: String = _call_text(dock, &"_format_package_details", [package_entry])

	assert_true(details.contains("risk summary:"), "Package details should expose a dependency risk summary.")
	assert_true(details.contains("install: 2 new, 1 update, order 3"), "Install risk summary should count dependency closure changes.")
	assert_true(details.contains("protected: -"), "Non-installed package details should not imply lockfile protection.")
	assert_true(details.contains("dependencies: gf.kernel, gf.standard.storage"), "Package details should keep raw dependency context.")

	dock.free()


func test_formats_uninstall_blocker_risk_summary() -> void:
	var dock: VBoxContainer = _new_vbox_container(GF_PACKAGE_MANAGER_DOCK)
	var package_entry: Dictionary = _make_package_manager_entry("gf.standard.storage", "standard")
	package_entry["installed"] = true
	package_entry["reason"] = ["dependency", "manual"]
	package_entry["required_by"] = ["gf.extension.save"]
	package_entry["uninstall_preview"] = {
		"ok": false,
		"to_remove": [],
		"blocked": [
			{
				"id": "gf.standard.storage",
				"reason": "required_by",
				"required_by": ["gf.extension.save"],
			},
			{
				"id": "gf.standard.storage",
				"reason": "project_references",
				"references": [
					{
						"path": "res://scripts/save_consumer.gd",
						"match": "GFStorageUtility",
					},
				],
			},
		],
	}

	var details: String = _call_text(dock, &"_format_package_details", [package_entry])

	assert_true(details.contains("protected: manual, required_by: gf.extension.save"), "Risk summary should explain manual pins and shared dependency protection.")
	assert_true(details.contains("uninstall: blocked 2, remove 0"), "Risk summary should expose blocked uninstall count.")
	assert_true(details.contains("blocker: required_by gf.standard.storage required_by: gf.extension.save"), "Details should include required_by blocker context.")
	assert_true(details.contains("blocker: project_references gf.standard.storage references: res://scripts/save_consumer.gd"), "Details should include project reference blocker context.")

	dock.free()


# --- 私有/辅助方法 ---

func _new_object(script: Variant) -> Object:
	assert_true(script is GDScript, "测试 helper 需要 GDScript。")
	if script is GDScript:
		var gdscript: GDScript = script
		var instance: Variant = gdscript.new()
		assert_true(instance is Object, "测试 helper 脚本应实例化为 Object。")
		if instance is Object:
			var object_instance: Object = instance
			return object_instance
	return null


func _new_vbox_container(script: Variant) -> VBoxContainer:
	var object_instance: Object = _new_object(script)
	assert_true(object_instance is VBoxContainer, "测试 helper 脚本应实例化为 VBoxContainer。")
	if object_instance is VBoxContainer:
		var container: VBoxContainer = object_instance
		return container
	return null


func _call_value(target: Object, method_name: StringName, args: Array = []) -> Variant:
	return target.callv(method_name, args)


func _call_void(target: Object, method_name: StringName, args: Array = []) -> void:
	var _call_result: Variant = _call_value(target, method_name, args)


func _call_array(target: Object, method_name: StringName, args: Array = []) -> Array:
	return GF_VARIANT_ACCESS.as_array(_call_value(target, method_name, args))


func _call_dictionary(target: Object, method_name: StringName, args: Array = []) -> Dictionary:
	return GF_VARIANT_ACCESS.as_dictionary(_call_value(target, method_name, args))


func _write_text_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时文本文件。")
	if file == null:
		return
	var _store_string_result: Variant = file.store_string(text)
	file.close()


func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)


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


func _dictionary_at(values: Array, index: int) -> Dictionary:
	assert_true(index >= 0 and index < values.size(), "测试记录索引应在数组范围内。")
	var value: Variant = values[index] if index >= 0 and index < values.size() else {}
	assert_true(value is Dictionary, "测试记录应为 Dictionary。")
	return GF_VARIANT_ACCESS.as_dictionary(value)


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


func _get_button(target: Object, property_name: StringName) -> Button:
	return _as_button(target.get(property_name))


func _get_option_button(target: Object, property_name: StringName) -> OptionButton:
	return _as_option_button(target.get(property_name))


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


func _as_hbox_container(value: Variant) -> HBoxContainer:
	assert_true(value is HBoxContainer, "测试观察值应为 HBoxContainer。")
	if value is HBoxContainer:
		var container: HBoxContainer = value
		return container
	return null


func _as_progress_bar(value: Variant) -> ProgressBar:
	assert_true(value is ProgressBar, "测试观察值应为 ProgressBar。")
	if value is ProgressBar:
		var progress_bar: ProgressBar = value
		return progress_bar
	return null
