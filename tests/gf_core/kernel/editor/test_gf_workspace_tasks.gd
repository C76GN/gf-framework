extends GutTest


# --- 常量 ---

const _HOST_SCRIPT = preload("res://addons/gf/kernel/editor/workspace/gf_workspace_task_host.gd")
const _RECORDS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_workspace_contribution_records.gd")
const _EXTENSION_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_tool_contribution.gd")
const _READER_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const _PAGE_PATH: String = "res://tests/gf_core/kernel/editor/fixtures/gf_workspace_passive_page.gd"


# --- 内部类 ---

class TaskPage:
	extends Control
	var calls: Array[String] = []
	var response: Variant = {"ok": true, "message": "已打开创建对话框。"}
	var before_response: Callable = Callable()

	func run_workspace_task(action_id: String) -> Variant:
		calls.append(action_id)
		if before_response.is_valid():
			var _called: Variant = before_response.call(action_id)
		return response

	func receive_workspace_resources(action_id: String, _paths: PackedStringArray) -> Variant:
		return run_workspace_task(action_id)


class IndexedTypeHost:
	extends _HOST_SCRIPT
	var indexed_type: String = ""

	func _get_file_type(_path: String) -> String:
		return indexed_type


class Navigator:
	extends RefCounted
	var page: Control = null
	var paths: Array[String] = []

	func open_workspace_page(path: String) -> Control:
		paths.append(path)
		return page


# --- 测试用例 ---

func test_receiver_reports_preserve_status_data_and_registry_authority() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var page: TaskPage = TaskPage.new()
	add_child(page)
	navigator.page = page
	host.configure([_normalized_task()], [], [{"path": _PAGE_PATH}], navigator)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.bind_workspace_host(host)
	for succeeded: bool in [false, true]:
		var receiver: Dictionary = {
			"ok": succeeded, "status": "source_selected" if succeeded else "edited_scene_required",
			"reason": "请先打开场景。", "data": {"paths": ["fixture"]},
			"error_code": 777, "action_id": "receiver-action", "metadata": {"receiver": true},
			"registry_status": "receiver-cannot-overwrite",
		}
		page.response = receiver
		var report: Dictionary = context.request_workspace_task("fixture:create")
		assert_eq(_ok(report), succeeded)
		assert_eq(str(report.get("status")), str(receiver["status"]))
		assert_eq(str(report.get("registry_status")), "invoked" if succeeded else "failed")
		assert_eq(GFVariantData.get_option_int(report, "error_code", -1), OK if succeeded else FAILED)
		assert_eq(str(report.get("action_id")), "fixture:create")
		assert_eq(GFVariantData.get_option_dictionary(report, "metadata"), {})
		assert_eq(str(report.get("message")), "请先打开场景。")
		assert_eq(GFVariantData.get_option_dictionary(report, "receiver_report"), receiver)
		var copied: Dictionary = GFVariantData.as_dictionary(report.get("receiver_report"))
		var data: Dictionary = GFVariantData.as_dictionary(copied.get("data"))
		data["paths"] = ["changed"]
		assert_eq(GFVariantData.get_option_array(GFVariantData.as_dictionary(receiver.get("data")), "paths"), ["fixture"])
	page.response = {"ok": false, "status": "placement_plugin_unavailable"}
	assert_eq(str(context.request_workspace_task("fixture:create").get("message")), "placement_plugin_unavailable")
	host.clear()
	page.free()


func test_nested_receiver_reports_do_not_leak_into_invalid_outer_response() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var outer: TaskPage = TaskPage.new()
	var inner: TaskPage = TaskPage.new()
	add_child(outer)
	add_child(inner)
	inner.response = {"ok": true, "status": "inner_done", "message": "inner-message", "data": {"inner": true}}
	navigator.page = outer
	host.configure([_normalized_task()], [], [{"path": _PAGE_PATH}], navigator)
	var nested_reports: Array[Dictionary] = []
	outer.before_response = func(_action_id: String) -> void:
		navigator.page = inner
		nested_reports.append(host.request_workspace_task("fixture:create"))
		navigator.page = outer
	outer.response = null
	var invalid: Dictionary = host.request_workspace_task("fixture:create")
	assert_false(_ok(invalid))
	assert_eq(GFVariantData.get_option_int(invalid, "error_code", -1), ERR_INVALID_DATA)
	assert_eq(str(invalid.get("status")), "failed")
	assert_false(invalid.has("receiver_report"))
	assert_false(str(invalid.get("message")).contains("inner-message"))
	assert_eq(str(nested_reports[0].get("status")), "inner_done")
	outer.response = {"ok": true, "status": "outer_done"}
	var valid: Dictionary = host.request_workspace_task("fixture:create")
	assert_eq(str(valid.get("status")), "outer_done")
	assert_eq(GFVariantData.get_option_dictionary(valid, "receiver_report"), GFVariantData.as_dictionary(outer.response))
	outer.before_response = Callable()
	host.clear()
	outer.free()
	inner.free()


func test_receiver_reconfiguration_cannot_publish_old_success_or_new_nested_report() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var old_page: TaskPage = TaskPage.new()
	var new_page: TaskPage = TaskPage.new()
	add_child(old_page)
	add_child(new_page)
	old_page.response = {"ok": true, "status": "old_success"}
	new_page.response = {"ok": true, "status": "new_success"}
	navigator.page = old_page
	host.configure([_normalized_task()], [], [{"path": _PAGE_PATH}], navigator)
	var nested_reports: Array[Dictionary] = []
	old_page.before_response = func(_action_id: String) -> void:
		navigator.page = new_page
		host.configure([_normalized_task()], [], [{"path": _PAGE_PATH}], navigator)
		nested_reports.append(host.request_workspace_task("fixture:create"))
	var report: Dictionary = host.request_workspace_task("fixture:create")
	assert_false(_ok(report))
	assert_eq(GFVariantData.get_option_int(report, "error_code", -1), ERR_UNAVAILABLE)
	assert_eq(str(report.get("status")), "failed")
	assert_false(report.has("receiver_report"))
	assert_true(_ok(nested_reports[0]))
	assert_eq(str(nested_reports[0].get("status")), "new_success")
	assert_eq(str(host.request_workspace_task("fixture:create").get("status")), "new_success")
	old_page.before_response = Callable()
	host.clear()
	old_page.free()
	new_page.free()


func test_receiver_page_retirement_rejects_calls_and_late_reports() -> void:
	for retire_during_call: bool in [false, true]:
		for queue_deletion: bool in [false, true]:
			var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
			var navigator: Navigator = Navigator.new()
			var page: TaskPage = TaskPage.new()
			add_child(page)
			page.response = {"ok": true, "status": "retired_success"}
			navigator.page = page
			host.configure([_normalized_task()], [], [{"path": _PAGE_PATH}], navigator)
			var retire: Callable = func(_action_id: String) -> void:
				if queue_deletion:
					page.queue_free()
				else:
					remove_child(page)
			if retire_during_call:
				page.before_response = retire
			else:
				var _retired: Variant = retire.call("")
			var report: Dictionary = host.request_workspace_task("fixture:create")
			assert_false(_ok(report), "离树或已排队释放的页面不能执行任务或发布成功结果。")
			assert_eq(GFVariantData.get_option_int(report, "error_code", -1), ERR_UNAVAILABLE)
			assert_eq(str(report.get("status")), "failed")
			assert_false(report.has("receiver_report"))
			assert_eq(page.calls.size(), 1 if retire_during_call else 0)
			page.before_response = Callable()
			host.clear()
			if queue_deletion:
				await get_tree().process_frame
			else:
				page.free()


func test_discovery_does_not_open_pages_and_explicit_task_routes_once() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var page: TaskPage = TaskPage.new()
	add_child(page)
	navigator.page = page
	var tasks: Array[Dictionary] = [_normalized_task()]
	var pages: Array[Dictionary] = [{"path": _PAGE_PATH}]
	host.configure(tasks, [], pages, navigator)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.bind_workspace_host(host)
	var snapshots: Array[Dictionary] = context.get_workspace_tasks()
	assert_eq(snapshots.size(), 1)
	assert_true(navigator.paths.is_empty())
	snapshots[0]["title"] = "changed"
	assert_eq(str(context.get_workspace_tasks()[0]["title"]), "创建示例")
	var report: Dictionary = context.request_workspace_task("fixture:create")
	assert_true(_ok(report))
	assert_eq(str(report["message"]), "已打开创建对话框。")
	assert_eq(navigator.paths, [_PAGE_PATH])
	assert_eq(page.calls, ["new_resource"])
	context.bind_workspace_host(null)
	assert_false(_ok(context.request_workspace_task("fixture:create")))
	assert_eq(page.calls.size(), 1)
	host.clear()
	page.free()


func test_disabled_task_opens_extension_selection_without_executing_task() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var page: TaskPage = TaskPage.new()
	add_child(page)
	navigator.page = page
	var tasks: Array[Dictionary] = [_normalized_task()]
	host.configure(tasks, [], [], navigator)
	assert_false(_available(host.get_workspace_tasks()[0]))
	assert_true(navigator.paths.is_empty())
	assert_true(_ok(host.request_workspace_task("fixture:create")))
	assert_eq(navigator.paths, ["res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd"])
	assert_true(page.calls.is_empty())
	host.clear()
	assert_false(_ok(host.request_workspace_task("fixture:create")))
	page.free()


func test_removed_generation_cannot_route_and_missing_host_is_unavailable() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var tasks: Array[Dictionary] = [_normalized_task()]
	var pages: Array[Dictionary] = [{"path": _PAGE_PATH}]
	host.configure(tasks, [], pages, navigator)
	assert_eq(host.invoke_workspace_record("fixture:create", PackedStringArray(), -1), ERR_UNAVAILABLE)
	assert_true(navigator.paths.is_empty())
	navigator = null
	assert_false(_available(host.get_workspace_tasks()[0]))
	host.clear()


func test_global_resource_classes_match_native_action_types_without_loading_scripts() -> void:
	var host: IndexedTypeHost = IndexedTypeHost.new()
	var navigator: Navigator = Navigator.new()
	var page: TaskPage = TaskPage.new()
	add_child(page)
	navigator.page = page
	var action: Dictionary = _normalized_task()
	action["resource_types"] = ["Resource"]
	action["max_selection"] = 1
	host.configure([], [action], [{"path": _PAGE_PATH}], navigator)
	var paths: PackedStringArray = PackedStringArray([_PAGE_PATH])
	for indexed_type: String in ["Resource", "GFAssetCatalogEntry", "GFAssetCatalog", "GradientTexture2D"]:
		host.indexed_type = indexed_type
		assert_true(_available(host.get_resource_actions(paths)[0]), indexed_type)
	assert_true(navigator.paths.is_empty(), "类型适用性查询不能打开页面或执行接收器。")
	host.indexed_type = "GFAssetCatalogEntry"
	page.response = {"ok": true, "status": "source_selected", "data": {"resource": "fixture"}}
	var report: Dictionary = host.request_resource_action("fixture:create", paths)
	assert_true(_ok(report))
	assert_eq(str(report.get("status")), "source_selected")
	assert_eq(GFVariantData.get_option_dictionary(report, "receiver_report"), GFVariantData.as_dictionary(page.response))
	assert_eq(page.calls, ["new_resource"])
	for indexed_type: String in ["UnknownProjectResource", "Node2D", "GFEditorToolContext", ""]:
		host.indexed_type = indexed_type
		assert_false(_available(host.get_resource_actions(paths)[0]), indexed_type)
		assert_false(_ok(host.request_resource_action("fixture:create", paths)))
	assert_eq(page.calls, ["new_resource"], "非法或非 Resource 类型不能路由到接收器。")
	action["resource_types"] = ["Texture2D"]
	host.configure([], [action], [{"path": _PAGE_PATH}], navigator)
	host.indexed_type = "GFAssetCatalogEntry"
	assert_false(_available(host.get_resource_actions(paths)[0]))
	host.indexed_type = "GradientTexture2D"
	assert_true(_available(host.get_resource_actions(paths)[0]))
	host.clear()
	page.free()


func test_oversized_extension_contribution_does_not_starve_later_valid_records() -> void:
	var oversized: GFExtensionManifest = _make_budget_manifest(0, 4_194_305)
	var valid: GFExtensionManifest = _make_budget_manifest(1, 0)
	var report: Dictionary = _HOST_SCRIPT.collect_extension_records([oversized, valid])
	var records: Array = GFVariantData.get_option_array(report, "task_records")
	assert_eq(records.size(), 1, "单文件超限必须跳过，不能耗尽后续扩展的总预算。")
	if records.size() == 1:
		assert_eq(str(GFVariantData.as_dictionary(records[0]).get("owner_package_id")), valid.id)
	_remove_budget_manifest(oversized)
	_remove_budget_manifest(valid)


func test_extension_contribution_total_budget_stops_after_four_mebibytes() -> void:
	var manifests: Array[GFExtensionManifest] = []
	for index: int in range(5):
		manifests.append(_make_budget_manifest(index, 1_048_576))
	var report: Dictionary = _HOST_SCRIPT.collect_extension_records(manifests)
	var records: Array = GFVariantData.get_option_array(report, "task_records")
	assert_eq(records.size(), 4)
	for index: int in range(mini(4, records.size())):
		assert_eq(str(GFVariantData.as_dictionary(records[index]).get("owner_package_id")), manifests[index].id)
	for manifest: GFExtensionManifest in manifests:
		_remove_budget_manifest(manifest)


func test_records_reject_arbitrary_handlers_cross_owner_targets_and_duplicates() -> void:
	var pages: Dictionary = {_PAGE_PATH: "fixture"}
	var raw: Dictionary = _local_task()
	var report: Dictionary = _RECORDS_SCRIPT.parse_records([raw], "fixture", pages)
	assert_eq(_errors(report), [])
	raw["handler"] = "delete_everything"
	assert_false(_errors(_RECORDS_SCRIPT.parse_records([raw], "fixture", pages)).is_empty())
	var _erased: bool = raw.erase("handler")
	raw["owner_package_id"] = "other"
	assert_false(_errors(_RECORDS_SCRIPT.parse_records([raw], "fixture", pages)).is_empty())
	var _owner_erased: bool = raw.erase("owner_package_id")
	assert_false(_errors(_RECORDS_SCRIPT.parse_records([raw, raw], "fixture", pages)).is_empty())


func test_resource_actions_require_finite_native_types_and_selection_budget() -> void:
	var raw: Dictionary = _local_task()
	raw["resource_types"] = ["PackedScene"]
	raw["max_selection"] = 1
	var pages: Dictionary = {_PAGE_PATH: "fixture"}
	assert_eq(_errors(_RECORDS_SCRIPT.parse_records([raw], "fixture", pages, true)), [])
	raw["max_selection"] = 0
	assert_false(_errors(_RECORDS_SCRIPT.parse_records([raw], "fixture", pages, true)).is_empty())
	raw["max_selection"] = 1
	raw["resource_types"] = ["ProjectScriptThatMustNotLoad"]
	assert_false(_errors(_RECORDS_SCRIPT.parse_records([raw], "fixture", pages, true)).is_empty())


func test_extension_v2_is_preserved_and_v3_is_closed() -> void:
	var data: Dictionary = {"schema_version": 2, "extension_id": "author.fixture", "editor_dock_paths": [_PAGE_PATH]}
	assert_true(_ok(_EXTENSION_SCRIPT.parse_dictionary(data)))
	data["task_records"] = [_local_task()]
	assert_false(_ok(_EXTENSION_SCRIPT.parse_dictionary(data)))
	data["schema_version"] = 3
	assert_true(_ok(_EXTENSION_SCRIPT.parse_dictionary(data)))
	data["arbitrary_loader"] = "script.gd"
	assert_false(_ok(_EXTENSION_SCRIPT.parse_dictionary(data)))


func test_standard_v4_compatibility_and_v5_workspace_records() -> void:
	var data: Dictionary = {
		"schema_version": 4, "package_id": "fixture",
		"dock_records": [{"owner_package_id": "fixture", "source_id": "page", "path": _PAGE_PATH, "label": "Fixture", "short_label": "Fixture", "order": 0}],
	}
	var path: String = "user://gf_workspace_contribution_test.json"
	_write_json(path, data)
	assert_true(_ok(_READER_SCRIPT.load_manifest_report(path)))
	data["task_records"] = [_local_task()]
	_write_json(path, data)
	assert_false(_ok(_READER_SCRIPT.load_manifest_report(path)))
	data["schema_version"] = 5
	_write_json(path, data)
	assert_true(_ok(_READER_SCRIPT.load_manifest_report(path)))
	var _removed: Error = DirAccess.remove_absolute(path)


# --- 私有/辅助方法 ---

func _make_budget_manifest(index: int, target_size: int) -> GFExtensionManifest:
	var manifest: GFExtensionManifest = GFExtensionManifest.new()
	manifest.id = "fixture.budget%d" % index
	manifest.root_path = "user://gf_workspace_budget_%d_%d" % [Time.get_ticks_usec(), index]
	var directory: String = manifest.root_path.path_join("editor")
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	var data: Dictionary = {
		"schema_version": 3, "extension_id": manifest.id,
		"editor_dock_paths": ["editor/page.gd"],
		"task_records": [{"source_id": "create", "title": "Budget", "page_path": "editor/page.gd"}],
	}
	var text: String = JSON.stringify(data)
	if target_size > text.to_utf8_buffer().size():
		text += " ".repeat(target_size - text.to_utf8_buffer().size())
	var file: FileAccess = FileAccess.open(directory.path_join("gf_tool_contribution.json"), FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		assert_true(file.store_string(text))
		file.close()
	return manifest


func _remove_budget_manifest(manifest: GFExtensionManifest) -> void:
	var directory: String = manifest.root_path.path_join("editor")
	assert_eq(DirAccess.remove_absolute(directory.path_join("gf_tool_contribution.json")), OK)
	assert_eq(DirAccess.remove_absolute(directory), OK)
	assert_eq(DirAccess.remove_absolute(manifest.root_path), OK)


func _local_task() -> Dictionary:
	return {"source_id": "create", "title": "创建示例", "page_path": _PAGE_PATH, "action_id": "new_resource"}


func _normalized_task() -> Dictionary:
	var record: Dictionary = _local_task()
	record["source_id"] = "fixture:create"
	return record


func _errors(report: Dictionary) -> Array:
	var errors: Array = report["errors"]
	return errors


func _ok(report: Dictionary) -> bool:
	return report.get("ok", false) == true


func _available(report: Dictionary) -> bool:
	return report.get("available", false) == true


func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var _stored: bool = file.store_string(JSON.stringify(data))
		file.close()
