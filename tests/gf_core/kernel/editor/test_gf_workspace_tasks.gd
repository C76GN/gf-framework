extends GutTest


# --- 常量 ---

const _HOST_SCRIPT = preload("res://addons/gf/kernel/editor/workspace/gf_workspace_task_host.gd")
const _RECORDS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_workspace_contribution_records.gd")
const _EXTENSION_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_tool_contribution.gd")
const _READER_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const _CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_catalog.gd")
const _PAGE_PATH: String = "res://tests/gf_core/kernel/editor/fixtures/gf_workspace_passive_page.gd"


# --- 内部类 ---

class TaskPage:
	extends Control
	var calls: Array[String] = []

	func run_workspace_task(action_id: String) -> Dictionary:
		calls.append(action_id)
		return {"ok": true, "message": "已打开创建对话框。"}


class Navigator:
	extends RefCounted
	var page: Control = null
	var paths: Array[String] = []

	func open_workspace_page(path: String) -> Control:
		paths.append(path)
		return page


# --- 测试用例 ---

func test_discovery_does_not_open_pages_and_explicit_task_routes_once() -> void:
	var host: _HOST_SCRIPT = _HOST_SCRIPT.new()
	var navigator: Navigator = Navigator.new()
	var page: TaskPage = TaskPage.new()
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


func test_builtin_authoring_records_route_to_their_own_contributed_pages() -> void:
	var report: Dictionary = _CATALOG_SCRIPT.load_catalog_report("res://addons/gf/gf_builtin_tool_contributions.json")
	assert_true(_ok(report))
	var records: Dictionary = report.get("records", {})
	var tasks: Array = records.get("task_records", [])
	var actions: Array = records.get("resource_action_records", [])
	assert_true(tasks.any(func(record: Dictionary) -> bool: return record.get("source_id") == "gf.tool.asset_browser:asset_browser.task.browse"))
	assert_true(tasks.any(func(record: Dictionary) -> bool: return record.get("source_id") == "gf.tool.config_pipeline:config_pipeline.task.export"))
	assert_true(tasks.any(func(record: Dictionary) -> bool:
		return record.get("source_id") == "gf.tool.project_bootstrap:project_bootstrap.task.create" and record.get("action_id") == "new_project"
	))
	assert_true(actions.any(func(record: Dictionary) -> bool:
		return record.get("source_id") == "gf.tool.scene_placement:scene_placement.action.select_scene" and record.get("resource_types") == ["PackedScene"] and record.get("max_selection") == 1
	))
	for extension: String in ["action_queue", "flow", "save"]:
		var path: String = "res://addons/gf/extensions/%s/editor/gf_tool_contribution.json" % extension
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var parsed: Dictionary = _EXTENSION_SCRIPT.parse_dictionary(raw, "gf." + extension)
		assert_true(_ok(parsed), path)
		var data: Dictionary = parsed.get("data", {})
		var extension_tasks: Array = data.get("task_records", [])
		assert_eq(extension_tasks.size(), 1, path)


# --- 私有/辅助方法 ---

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
