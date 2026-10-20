extends GutTest

const REPORT_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_reference_report.gd")
var _directory: String = ""
var _files: PackedStringArray = PackedStringArray()
var _uids: Array[int] = []


func before_each() -> void:
	_directory = "res://tests/gf_core/tools/asset_browser/reference_fixture_%d" % Time.get_ticks_usec()
	var made: Error = DirAccess.make_dir_recursive_absolute(_directory)
	assert_eq(made, OK)


func after_each() -> void:
	for uid: int in _uids:
		ResourceUID.remove_id(uid)
	_uids.clear()
	for path: String in _files:
		var _removed: Error = DirAccess.remove_absolute(path)
	_files.clear()
	var _removed_directory: Error = DirAccess.remove_absolute(_directory)


func test_batch_uses_one_scan_and_preserves_distinct_evidence_categories() -> void:
	var first: String = _resource("first.tres")
	var second: String = _resource("second.tres")
	var unobserved: String = _resource("unobserved.tres")
	var _strong_source: String = _write(
		"strong.gd",
		"extends RefCounted\nvar asset = load(\"%s\")\n" % first
	)
	var _weak_source: String = _write(
		"weak.gd",
		"const ASSET_LABEL = \"%s\"\n" % second
	)
	var report: Dictionary = _run(
		PackedStringArray(
			[
				second,
				first,
				unobserved,
				first,
			]
		)
	)
	var rows: Array[Dictionary] = []
	rows.assign(GFVariantData.get_option_array(report, "rows"))
	assert_eq(
		rows.size(),
		3
	)
	assert_eq(
		GFVariantData.get_option_string(
			rows[0],
			"path"
		),
		first
	)
	assert_eq(
		GFVariantData.get_option_string(
			rows[0],
			"inbound_status"
		),
		"observed_static"
	)
	assert_eq(
		GFVariantData.get_option_string(
			rows[1],
			"inbound_status"
		),
		"weak_only"
	)
	assert_eq(
		GFVariantData.get_option_string(
			rows[2],
			"inbound_status"
		),
		"not_observed"
	)
	var coverage: Dictionary = GFVariantData.get_option_dictionary(report, "coverage")
	assert_eq(
		GFVariantData.get_option_int(coverage, "scanned_file_count"),
		5
	)
	assert_false(GFVariantData.get_option_bool(report, "partial_scan"))
	assert_eq(
		GFVariantData.get_option_string(report, "dynamic_paths"),
		"not_determined"
	)
	assert_false(report.has("safe_to_delete"))


func test_uid_resolved_stale_path_is_not_a_missing_dependency() -> void:
	var actual: String = _resource("actual.tres")
	var uid: int = ResourceUID.create_id()
	ResourceUID.add_id(uid, actual)
	_uids.append(uid)
	var old_path: String = _directory.path_join("old.tres")
	var missing_path: String = _directory.path_join("missing.tres")
	var root: String = _write(
		"root.tres",
		"[gd_resource type=\"Resource\" load_steps=3 format=3]\n[ext_resource type=\"Resource\" uid=\"%s\" path=\"%s\" id=\"1\"]\n[ext_resource type=\"Resource\" path=\"%s\" id=\"2\"]\n[resource]\n"
		% [
			ResourceUID.id_to_text(uid),
			old_path,
			missing_path,
		]
	)
	var report: Dictionary = _run(PackedStringArray([root]))
	var rows: Array[Dictionary] = []
	rows.assign(GFVariantData.get_option_array(report, "rows"))
	assert_eq(
		GFVariantData.get_option_int(
			rows[0],
			"missing_count"
		),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(
			rows[0],
			"stale_path_count"
		),
		1
	)
	var dependencies: Array = GFVariantData.get_option_array(
		rows[0],
		"dependencies"
	)
	assert_eq(
		dependencies.size(),
		2
	)
	var stale_found: bool = false
	for item: Dictionary in dependencies:
		if GFVariantData.get_option_string(item, "status") == "uid_resolved_stale_path":
			stale_found = true
			assert_eq(
				GFVariantData.get_option_string(item, "recorded_path"),
				old_path
			)
			assert_eq(
				GFVariantData.get_option_string(item, "resolved_path"),
				actual
			)
	assert_true(stale_found)
	assert_true(ResourceUID.has_id(uid))
	assert_false(FileAccess.file_exists(old_path))


func test_missing_edges_consume_the_shared_batch_budget() -> void:
	var first: String = _resource_with_missing("a.tres", 3)
	var second: String = _resource_with_missing("z.tres", 3)
	var report: Dictionary = _run(
		PackedStringArray([second, first]),
		{ "max_dependency_edges": 2 }
	)
	var rows: Array[Dictionary] = []
	rows.assign(GFVariantData.get_option_array(report, "rows"))
	assert_eq(
		GFVariantData.get_option_int(report, "dependency_edges_examined"),
		2
	)
	assert_eq(
		GFVariantData.get_option_int(
			rows[0],
			"missing_count"
		),
		2
	)
	assert_true(
		GFVariantData.get_option_bool(
			rows[0],
			"partial_scan"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			rows[1],
			"partial_scan"
		)
	)
	assert_eq(
		GFVariantData.get_option_string(
			rows[1],
			"dependency_issue"
		),
		"dependency_edge_budget"
	)
	assert_true(
		GFVariantData.get_option_array(
			rows[1],
			"dependencies"
		).is_empty()
	)


func test_reference_scan_and_dependency_admission_share_bytes() -> void:
	var root: String = _resource("root.tres")
	var file: FileAccess = FileAccess.open(root, FileAccess.READ)
	var bytes: int = file.get_length()
	file.close()
	var report: Dictionary = _run(
		PackedStringArray([root]),
		{ "max_total_bytes": bytes }
	)
	var rows: Array[Dictionary] = []
	rows.assign(GFVariantData.get_option_array(report, "rows"))
	assert_eq(
		GFVariantData.get_option_string(
			rows[0],
			"dependency_issue"
		),
		"dependency_byte_budget"
	)
	assert_true(GFVariantData.get_option_bool(report, "partial_scan"))
	assert_eq(
		GFVariantData.get_option_int(report, "dependency_bytes_admitted"),
		0
	)


func test_dependency_admission_charges_one_source_size() -> void:
	var root: String = _resource("root.tres")
	var file: FileAccess = FileAccess.open(root, FileAccess.READ)
	var bytes: int = file.get_length()
	file.close()
	var report: Dictionary = _run(
		PackedStringArray([root]),
		{ "max_total_bytes": bytes * 2 }
	)
	assert_false(GFVariantData.get_option_bool(report, "partial_scan"))
	assert_eq(
		GFVariantData.get_option_int(report, "dependency_bytes_admitted"),
		bytes
	)


func test_broken_selected_resources_outside_inbound_scope_remain_unknown() -> void:
	var text_path: String = _write("broken.tres", "not a Godot resource")
	var binary_path: String = _write("broken.res", "RSRCbroken")
	var report: Dictionary = _run(
		PackedStringArray([text_path, binary_path]),
		{ "scope": "res://tests/gf_core/tools/scene_placement/fixtures" }
	)
	assert_true(GFVariantData.get_option_bool(report, "partial_scan"))
	for row: Dictionary in GFVariantData.get_option_array(report, "rows"):
		assert_true(GFVariantData.get_option_bool(row, "partial_scan"))
		assert_eq(
			GFVariantData.get_option_string(row, "dependency_issue"),
			"dependency_metadata_unavailable"
		)
		assert_eq(
			GFVariantData.get_option_int(row, "missing_count"),
			0
		)


func test_cancel_discards_candidate_data_before_and_after_inbound_scan() -> void:
	var path: String = _resource("root.tres")
	for after_scan: bool in [false, true]:
		var task: REPORT_SCRIPT = REPORT_SCRIPT.new()
		assert_true(
			task.start(
				PackedStringArray([path]),
				{ "scope": _directory }
			)
		)
		if after_scan:
			assert_false(task.step())
		task.cancel()
		assert_true(task.step())
		assert_true(task.take_result().is_empty())


func test_file_quota_marks_every_selected_row_as_partial() -> void:
	var first: String = _resource("first.tres")
	var second: String = _resource("second.tres")
	var report: Dictionary = _run(
		PackedStringArray([first, second]),
		{ "max_files": 1 }
	)
	assert_push_warning("[GFProjectReferenceScanner][project_reference_scanner.file_limit_reached] max_scanned_files=1 was reached; subsequent files were skipped.")
	assert_true(GFVariantData.get_option_bool(report, "partial_scan"))
	for row: Dictionary in GFVariantData.get_option_array(report, "rows"):
		assert_true(GFVariantData.get_option_bool(row, "partial_scan"))
		assert_eq(
			GFVariantData.get_option_string(row, "inbound_status"),
			"not_observed"
		)


func test_rejects_excess_raw_candidates_and_invalid_scope_without_scanning() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for index: int in range(101):
		var _appended: bool = paths.append(_directory.path_join("root.tres"))
	var task: REPORT_SCRIPT = REPORT_SCRIPT.new()
	assert_false(
		task.start(
			paths,
			{ "scope": _directory }
		)
	)
	assert_true(task.step())
	var report: Dictionary = task.take_result()
	assert_true(GFVariantData.get_option_bool(report, "partial_scan"))
	assert_true(GFVariantData.get_option_dictionary(report, "coverage").is_empty())
	var invalid: REPORT_SCRIPT = REPORT_SCRIPT.new()
	assert_false(
		invalid.start(
			PackedStringArray(["res://root.tres"]),
			{ "scope": "res://../outside" }
		)
	)


func test_completed_report_is_transferred_once() -> void:
	var task: REPORT_SCRIPT = REPORT_SCRIPT.new()
	assert_true(
		task.start(
			PackedStringArray([_resource("root.tres")]),
			{ "scope": _directory }
		)
	)
	assert_false(task.step())
	assert_true(task.step())
	assert_false(task.take_result().is_empty())
	assert_true(task.take_result().is_empty())
	assert_false(task.start(PackedStringArray(["res://new.tres"])))


func _run(paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	if not options.has("scope"):
		options["scope"] = _directory
	var task: REPORT_SCRIPT = REPORT_SCRIPT.new()
	assert_true(task.start(paths, options))
	for index: int in range(102):
		if task.step():
			return task.take_result()
	fail_test("A bounded batch must finish within one scan and 100 resource steps.")
	return {}


func _resource(file_name: String) -> String:
	return _write(file_name, "[gd_resource type=\"Resource\" format=3]\n[resource]\n")


func _resource_with_missing(file_name: String, count: int) -> String:
	var text: String = "[gd_resource type=\"Resource\" load_steps=%d format=3]\n" % (count + 1)
	for index: int in range(count):
		text += (
			"[ext_resource type=\"Resource\" path=\"%s/missing_%d.tres\" id=\"%d\"]\n"
			% [
				_directory,
				index,
				index,
			]
		)
	return _write(
		file_name,
		text + "[resource]\n"
	)


func _write(file_name: String, text: String) -> String:
	var path: String = _directory.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var stored: bool = file.store_string(text)
		assert_true(stored)
		file.close()
	var _appended: bool = _files.append(path)
	return path
