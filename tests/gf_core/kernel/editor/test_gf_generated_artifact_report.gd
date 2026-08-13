extends GutTest


# --- 常量 ---

const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const GF_TEST_DIRECTORY_LINK_FIXTURE = preload(
	"res://tests/gf_core/support/gf_test_directory_link_fixture.gd"
)


# --- 私有变量 ---

var _race_allowed_root: String = ""
var _race_outside_root: String = ""
var _race_linked_child: String = ""
var _failure_output_path: String = ""
var _baseline_output_path: String = ""
var _temp_tamper_root: String = ""
var _temp_directory_path: String = ""
var _post_commit_output_path: String = ""
var _post_commit_outside_root: String = ""
var _outside_backup_path: String = ""
var _snapshot_allowed_root: String = ""
var _snapshot_outside_root: String = ""
var _snapshot_staged_root: String = ""
var _rollback_allowed_root: String = ""
var _rollback_output_path: String = ""
var _reentrant_allowed_root: String = ""
var _reentrant_output_path: String = ""
var _reentrant_report: Dictionary = {}
var _hook_observed_output_path: String = ""
var _hook_call_count: int = 0
var _scan_observer_count: int = 0
var _reoccupied_temp_path: String = ""
var _reoccupied_backup_path: String = ""
var _post_cleanup_snapshot_count: int = 0


# --- 测试生命周期 ---

func after_each() -> void:
	GFGeneratedArtifactReport._reset_test_state()


# --- 测试用例 ---

func test_save_text_reports_generated_ownership_and_content_hashes() -> void:
	var path: String = "user://gf_generated_artifact_report_%d.txt" % Time.get_ticks_usec()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"generator_id": "test.generator",
		"source_id": "fixture:item",
		"scan_filesystem": false,
	})
	var second_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"dry_run": true,
		"scan_filesystem": false,
	})
	var third_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "second", {
		"artifact_owner": GFGeneratedArtifactReport.OWNER_EXTERNAL,
		"dry_run": true,
		"scan_filesystem": false,
	})
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "首次写入应报告 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_report, "artifact_owner"), GFGeneratedArtifactReport.OWNER_GENERATED, "默认产物所有权应标记为 generated。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_report, "generator_id"), "test.generator", "报告应保留生成器 ID。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_report, "source_id"), "fixture:item", "报告应保留来源 ID。")
	assert_false(GF_VARIANT_ACCESS.get_option_string(first_report, "content_sha256").is_empty(), "报告应包含内容 sha256。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(first_report, "previous_sha256").is_empty(), "新文件没有 previous sha256。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(second_report, "status"), GFGeneratedArtifactReport.STATUS_UNCHANGED, "相同内容 dry-run 应报告 unchanged。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(second_report, "content_sha256"),
		GF_VARIANT_ACCESS.get_option_string(second_report, "previous_sha256"),
		"相同内容应让当前和 previous sha256 一致。"
	)
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(third_report, "artifact_owner"), GFGeneratedArtifactReport.OWNER_EXTERNAL, "调用方可声明外部产物所有权。")
	assert_ne(
		GF_VARIANT_ACCESS.get_option_string(third_report, "content_sha256"),
		GF_VARIANT_ACCESS.get_option_string(third_report, "previous_sha256"),
		"变更内容 dry-run 应暴露不同 sha。"
	)


func test_save_text_reports_skipped_as_non_failed_without_writing() -> void:
	var path: String = "user://gf_generated_artifact_report_skip_%d.txt" % Time.get_ticks_usec()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"scan_filesystem": false,
	})
	var skipped_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "second", {
		"overwrite_existing": false,
		"scan_filesystem": false,
	})
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取临时产物。")
	if file == null:
		var _cleanup_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var content: String = file.get_as_text()
	file.close()
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_report, "success"), "首次写入应成功。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(skipped_report, "success"), "skipped 是非失败结果。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(skipped_report, "status"), GFGeneratedArtifactReport.STATUS_SKIPPED, "禁止覆盖时应报告 skipped。")
	assert_eq(GFGeneratedArtifactReport.get_error_code(skipped_report), ERR_ALREADY_EXISTS, "调用方仍可用 error_code 判断是否阻断流程。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(skipped_report, "written"), "skipped 不应写入目标。")
	assert_eq(content, "first", "skipped 不应改写已有内容。")
	assert_push_warning("[GFGeneratedArtifactReport] 目标文件已存在，已跳过：%s" % path)


func test_make_report_returns_json_safe_metadata_boundary() -> void:
	var report: Dictionary = GFGeneratedArtifactReport.make_report("res://generated/output.gd", GFGeneratedArtifactReport.STATUS_NEW, OK, "", {
		"metadata": {
			"owner": self,
			"not_a_number": NAN,
			"template_path": "res://secret/template.gd.tpl",
		},
	})
	var metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "metadata")
	var owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(metadata, "owner")
	var owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(owner_payload, "__gf_report_value__")
	var float_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(metadata, "not_a_number")
	var float_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(float_payload, "__gf_variant__")
	var json_text: String = JSON.stringify(report)

	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "status"), "new", "报告状态应保持 JSON 原生字符串。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "artifact_owner"), "generated", "产物所有权应保持 JSON 原生字符串。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(owner_marker, "type"), "Object", "metadata 中的运行时对象应被结构化脱敏。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(float_marker, "type"), "Float", "metadata 中的 NaN 应使用 typed marker。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(metadata, "template_path"), "template.gd.tpl", "metadata 路径应按报告策略收束为文件名。")
	assert_false(json_text.contains(":null"), "报告应可直接 JSON.stringify() 且不把 NaN 降级为 null。")


func test_save_text_replaces_existing_file_without_temp_artifacts() -> void:
	var path: String = "user://gf_generated_artifact_report_atomic_%d.txt" % Time.get_ticks_usec()
	var file_name: String = path.get_file()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"scan_filesystem": false,
	})
	var second_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "second", {
		"scan_filesystem": false,
	})
	var content: String = _read_user_text(path)
	var temp_count: int = _count_user_files_with_prefix("%s.tmp." % file_name)
	var backup_count: int = _count_user_files_with_prefix("%s.backup.tmp." % file_name)
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "首次写入应报告 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(second_report, "status"), GFGeneratedArtifactReport.STATUS_CHANGED, "覆盖写入应报告 changed。")
	assert_eq(content, "second", "覆盖写入后目标文件内容应完整替换。")
	assert_eq(temp_count, 0, "成功替换后不应残留临时写入文件。")
	assert_eq(backup_count, 0, "成功替换后不应残留备份文件。")


func test_save_text_rejects_stale_expected_previous_hash() -> void:
	var path: String = "user://gf_generated_artifact_report_conflict_%d.txt" % Time.get_ticks_usec()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "current", {
		"scan_filesystem": false,
	})
	var conflict_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "replacement", {
		"expected_previous_sha256": "stale-baseline",
		"scan_filesystem": false,
	})
	var content: String = _read_user_text(path)
	var temp_count: int = _count_user_files_with_prefix("%s.tmp." % path.get_file())
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_report, "success"), "基线文件应创建成功。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(conflict_report, "success"), "基线冲突必须失败关闭。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(conflict_report, "conflict"), "报告应结构化标记冲突。")
	assert_eq(
		GFGeneratedArtifactReport.get_error_code(conflict_report),
		ERR_FILE_ALREADY_IN_USE,
		"基线冲突应返回稳定错误码。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(conflict_report, "expected_previous_sha256"),
		"stale-baseline",
		"报告应保留调用方期望的基线。"
	)
	assert_eq(content, "current", "冲突不得覆盖当前内容。")
	assert_eq(temp_count, 0, "冲突不得遗留临时文件。")
	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_push_error("[GFGeneratedArtifactReport] 目标文件已偏离调用方读取基线，已拒绝写入：%s" % path)


func test_save_text_rejects_absolute_path_and_outside_allowed_roots() -> void:
	var absolute_path: String = ProjectSettings.globalize_path("user://gf_generated_artifact_absolute.txt").replace("\\", "/")
	var allowed_root: String = "user://gf_generated_artifact_report_roots/generated"
	var generated_path: String = allowed_root.path_join("item.txt")
	var outside_path: String = "user://gf_generated_artifact_report_roots/manual/item.txt"

	var absolute_report: Dictionary = GFGeneratedArtifactReport.save_text(absolute_path, "absolute", {
		"scan_filesystem": false,
	})
	var generated_report: Dictionary = GFGeneratedArtifactReport.save_text(generated_path, "inside", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var outside_report: Dictionary = GFGeneratedArtifactReport.save_text(outside_path, "outside", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})

	var _remove_file_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(generated_path))
	var _remove_generated_dir_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(allowed_root))
	var _remove_root_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path("user://gf_generated_artifact_report_roots"))

	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(absolute_report, "status"), GFGeneratedArtifactReport.STATUS_FAILED, "绝对文件系统路径应被拒绝。")
	assert_eq(GFGeneratedArtifactReport.get_error_code(absolute_report), ERR_INVALID_PARAMETER, "绝对路径失败应报告参数错误。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(generated_report, "success"), "allowed_roots 内路径应允许写入。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(outside_report, "status"), GFGeneratedArtifactReport.STATUS_FAILED, "allowed_roots 外路径应被拒绝。")
	assert_false(FileAccess.file_exists(outside_path), "allowed_roots 外路径不应写入文件。")
	assert_push_error_count(2, "绝对路径和越界路径应各报告一次错误。")


func test_save_text_rejects_output_file_as_allowed_root_without_io() -> void:
	var test_root: String = "user://gf_generated_artifact_report_file_root_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var output_path: String = test_root.path_join("output.txt")
	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "content", {
		"allowed_roots": [output_path],
		"scan_filesystem": false,
	})
	var parent_exists: bool = DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(test_root)
	)
	var output_exists: bool = FileAccess.file_exists(output_path)
	var temp_count: int = _count_files_with_fragment(test_root, ".tmp.")
	_remove_test_tree(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_INVALID_PARAMETER)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_false(parent_exists, "文件路径不得作为 allowed_roots 目录根，且必须在 mkdir 前失败。")
	assert_false(output_exists)
	assert_eq(temp_count, 0, "非目录 allowed_roots 不得创建临时产物。")
	assert_push_error_count(1)


func test_save_text_rejects_explicit_invalid_allowed_roots_without_io() -> void:
	var test_root: String = "user://gf_generated_artifact_report_invalid_roots_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var empty_path: String = test_root.path_join("empty.txt")
	var wrong_type_path: String = test_root.path_join("wrong-type.txt")
	var invalid_item_path: String = test_root.path_join("invalid-item.txt")
	var empty_report: Dictionary = GFGeneratedArtifactReport.save_text(empty_path, "empty", {
		"allowed_roots": [],
		"scan_filesystem": false,
	})
	var wrong_type_report: Dictionary = GFGeneratedArtifactReport.save_text(
		wrong_type_path,
		"wrong-type",
		{
			"allowed_roots": { "root": test_root },
			"scan_filesystem": false,
		}
	)
	var invalid_item_report: Dictionary = GFGeneratedArtifactReport.save_text(
		invalid_item_path,
		"invalid-item",
		{
			"allowed_roots": [test_root, "C:/outside"],
			"scan_filesystem": false,
		}
	)
	var root_exists: bool = DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(test_root)
	)
	_remove_test_tree(test_root)

	for report: Dictionary in [empty_report, wrong_type_report, invalid_item_report]:
		assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
		assert_eq(
			GFGeneratedArtifactReport.get_error_code(report),
			ERR_INVALID_PARAMETER
		)
		assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_false(root_exists, "显式无效 allowed_roots 必须在 mkdir/write 前失败关闭。")
	assert_false(FileAccess.file_exists(empty_path))
	assert_false(FileAccess.file_exists(wrong_type_path))
	assert_false(FileAccess.file_exists(invalid_item_path))
	assert_push_error_count(3, "三种显式无效 allowed_roots 应各报告一次参数错误。")


func test_save_text_rejects_stringifying_allowed_root_elements_without_io() -> void:
	var test_root: String = "user://gf_generated_artifact_report_typed_roots_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var node_path_report: Dictionary = GFGeneratedArtifactReport.save_text(
		test_root.path_join("node-path.txt"),
		"node-path",
		{
			"allowed_roots": [NodePath(test_root)],
			"scan_filesystem": false,
		}
	)
	var stringifying_root: AllowedRootStringifier = AllowedRootStringifier.new(test_root)
	var object_report: Dictionary = GFGeneratedArtifactReport.save_text(
		test_root.path_join("object.txt"),
		"object",
		{
			"allowed_roots": [stringifying_root],
			"scan_filesystem": false,
		}
	)
	var root_exists: bool = DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(test_root)
	)
	_remove_test_tree(test_root)

	for report: Dictionary in [node_path_report, object_report]:
		assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
		assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_INVALID_PARAMETER)
		assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_false(root_exists, "可字符串化的非字符串 root 元素必须在 mkdir/write 前失败关闭。")
	assert_push_error_count(2, "NodePath 与自定义 _to_string Object 应各报告一次参数错误。")


func test_save_text_rejects_linked_child_inside_allowed_root() -> void:
	var test_root: String = "user://gf_generated_artifact_report_link_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var outside_root: String = test_root.path_join("outside")
	var linked_child: String = allowed_root.path_join("linked-child")
	var output_path: String = linked_child.path_join("escaped.txt")
	var outside_path: String = outside_root.path_join("escaped.txt")
	var absolute_allowed_root: String = ProjectSettings.globalize_path(allowed_root)
	var absolute_outside_root: String = ProjectSettings.globalize_path(outside_root)
	var absolute_linked_child: String = ProjectSettings.globalize_path(linked_child)
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(absolute_allowed_root)
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(absolute_outside_root)
	assert_eq(make_allowed_error, OK, "测试应创建 allowed root。")
	assert_eq(make_outside_error, OK, "测试应创建独立的外部 target。")
	if make_allowed_error != OK or make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	var link_error: Error = GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		absolute_outside_root,
		absolute_linked_child
	)
	assert_eq(link_error, OK, "受支持平台必须建立 symlink 或 Windows directory junction 夹具。")
	if link_error != OK:
		_remove_test_tree(test_root)
		return

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "escaped", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var outside_file_exists: bool = FileAccess.file_exists(outside_path)
	var outside_content: String = _read_user_text(outside_path) if outside_file_exists else ""
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"), "linked child 输出必须失败关闭。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(report, "status"), GFGeneratedArtifactReport.STATUS_FAILED)
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_UNAUTHORIZED, "物理所有权越界应返回稳定权限错误。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"), "失败报告不得宣称已写入。")
	assert_false(outside_file_exists, "不得通过 linked child 在 allowed root 外创建文件。")
	assert_eq(outside_content, "", "外部 target 不得接收产物内容。")
	assert_true(cleanup_succeeded, "linked child fixture 必须清理。")
	assert_push_error(
		"[GFGeneratedArtifactReport] 输出路径包含链接或重解析组件，已拒绝：%s" % output_path
	)


func test_save_text_rejects_linked_output_root_and_preserves_existing_file() -> void:
	var test_root: String = "user://gf_generated_artifact_report_link_root_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed-link")
	var outside_root: String = test_root.path_join("outside")
	var output_path: String = allowed_root.path_join("existing.txt")
	var outside_path: String = outside_root.path_join("existing.txt")
	var absolute_outside_root: String = ProjectSettings.globalize_path(outside_root)
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_outside_root
	)
	assert_eq(make_outside_error, OK, "测试应创建 linked output root 的物理 target。")
	if make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	var outside_file: FileAccess = FileAccess.open(outside_path, FileAccess.WRITE)
	assert_not_null(outside_file, "测试应创建 existing replacement sentinel。")
	if outside_file == null:
		_remove_test_tree(test_root)
		return
	var _stored: Variant = outside_file.store_string("sentinel")
	outside_file.close()
	var link_error: Error = GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		absolute_outside_root,
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(link_error, OK, "受支持平台必须建立 linked output root。")
	if link_error != OK:
		_remove_test_tree(test_root)
		return

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "replacement", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var outside_content: String = _read_user_text(outside_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_UNAUTHORIZED)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(outside_content, "sentinel", "linked output root 中的 existing file 不得被替换。")
	assert_true(cleanup_succeeded, "linked output root fixture 必须清理。")
	assert_push_error(
		"[GFGeneratedArtifactReport] 输出路径包含链接或重解析组件，已拒绝：%s" % output_path
	)


func test_save_text_rechecks_physical_ownership_before_final_replace() -> void:
	var test_root: String = "user://gf_generated_artifact_report_race_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	_race_allowed_root = test_root.path_join("allowed")
	_race_outside_root = test_root.path_join("outside")
	_race_linked_child = _race_allowed_root.path_join("linked-child")
	var output_path: String = _race_linked_child.path_join("escaped.txt")
	var outside_path: String = _race_outside_root.path_join("escaped.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_race_linked_child)
	)
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_race_outside_root)
	)
	assert_eq(make_allowed_error, OK, "测试应创建普通 linked-child 占位目录。")
	assert_eq(make_outside_error, OK, "测试应创建 race 外部 target。")
	if make_allowed_error != OK or make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_replace_race_child_with_link")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "escaped", {
		"allowed_roots": [_race_allowed_root],
		"scan_filesystem": false,
	})
	var race_link_created: bool = _absolute_path_is_link(
		ProjectSettings.globalize_path(_race_linked_child)
	)
	var outside_file_exists: bool = FileAccess.file_exists(outside_path)
	var committed: bool = GF_VARIANT_ACCESS.get_option_bool(report, "written")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_true(race_link_created, "test-owned callback 必须在 validation 后建立 junction/symlink。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"), "final replace 前物理所有权失效必须失败。")
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_UNAUTHORIZED)
	assert_false(committed, "replace 前拒绝不得宣称已提交产物。")
	assert_false(outside_file_exists, "final replace preflight 不得沿 race link 写入外部 target。")
	assert_true(cleanup_succeeded, "final replace race fixture 必须清理。")
	assert_push_error(
		"[GFGeneratedArtifactReport] 无法替换文本产物：%s (%s)" % [
			output_path,
			error_string(ERR_UNAUTHORIZED),
		]
	)


func test_save_text_rejects_initial_temp_override_outside_output_directory() -> void:
	var test_root: String = "user://gf_generated_artifact_report_temp_escape_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var outside_root: String = test_root.path_join("outside")
	var output_path: String = allowed_root.path_join("output.txt")
	var outside_temp_path: String = outside_root.path_join("escaped.tmp")
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(outside_root)
	)
	assert_eq(make_outside_error, OK)
	if make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	GFGeneratedArtifactReport._configure_test_temp_path_override(outside_temp_path)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "expected", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var outside_temp_exists: bool = _path_entry_exists_for_test(
		ProjectSettings.globalize_path(outside_temp_path)
	)
	var output_exists: bool = _path_entry_exists_for_test(
		ProjectSettings.globalize_path(output_path)
	)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_UNAUTHORIZED)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_false(outside_temp_exists, "越出 output base_dir 的 temp override 必须零 I/O。")
	assert_false(output_exists)
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_rejects_backup_override_outside_output_directory() -> void:
	var test_root: String = "user://gf_generated_artifact_report_backup_escape_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var outside_root: String = test_root.path_join("outside")
	var output_path: String = allowed_root.path_join("existing.txt")
	_outside_backup_path = outside_root.path_join("escaped.backup")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(outside_root)
	)
	assert_eq(make_allowed_error, OK)
	assert_eq(make_outside_error, OK)
	if make_allowed_error != OK or make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(output_path, "original")
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_configure_outside_backup_override")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "replacement", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var output_content: String = _read_user_text(output_path)
	var outside_backup_exists: bool = _path_entry_exists_for_test(
		ProjectSettings.globalize_path(_outside_backup_path)
	)
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_UNAUTHORIZED)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(output_content, "original", "越界 backup override 不得移动或替换 existing target。")
	assert_false(outside_backup_exists, "越界 backup override 必须零 I/O。")
	assert_eq(temp_count, 0, "拒绝 backup override 后应安全清理 owned temp。")
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_rejects_non_file_output_before_dry_run_or_write() -> void:
	var test_root: String = "user://gf_generated_artifact_report_non_file_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var dry_output_path: String = allowed_root.path_join("dry-output")
	var write_output_path: String = allowed_root.path_join("write-output")
	var make_dry_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(dry_output_path)
	)
	var make_write_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(write_output_path)
	)
	assert_eq(make_dry_error, OK)
	assert_eq(make_write_error, OK)
	if make_dry_error != OK or make_write_error != OK:
		_remove_test_tree(test_root)
		return

	var dry_report: Dictionary = GFGeneratedArtifactReport.save_text(
		dry_output_path,
		"dry",
		{
			"allowed_roots": [allowed_root],
			"dry_run": true,
			"scan_filesystem": false,
		}
	)
	GFGeneratedArtifactReport._configure_test_temp_write_failure(FAILED, 1)
	var write_report: Dictionary = GFGeneratedArtifactReport.save_text(
		write_output_path,
		"write",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	for report: Dictionary in [dry_report, write_report]:
		assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
		assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_ALREADY_IN_USE)
		assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
		assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(temp_count, 0, "non-file output 必须在 dry-run/write early return 前被拒绝。")
	assert_true(cleanup_succeeded)
	assert_push_error_count(2)


func test_save_text_cleans_temp_when_target_appears_before_final_replace() -> void:
	var test_root: String = "user://gf_generated_artifact_report_failure_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_failure_output_path = allowed_root.path_join("blocked.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_create_directory_at_failure_output")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_failure_output_path,
		"blocked",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	var replace_error: Error = GFGeneratedArtifactReport.get_error_code(report)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"), "final replace 前 target 漂移应返回 failed report。")
	assert_eq(replace_error, ERR_FILE_ALREADY_IN_USE)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"), "未提交 replace 不得报告 written。")
	assert_eq(temp_count, 0, "final replace 前 target 漂移后应清理 staged temp。")
	assert_true(cleanup_succeeded, "target drift fixture 必须清理。")
	assert_push_error(
		"[GFGeneratedArtifactReport] 目标文件在保存期间发生创建或删除：%s" % _failure_output_path
	)


func test_save_text_cleans_temp_after_injected_write_failure() -> void:
	var test_root: String = "user://gf_generated_artifact_report_write_failure_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var output_path: String = allowed_root.path_join("failed.txt")
	GFGeneratedArtifactReport._configure_test_temp_write_failure(FAILED, 1)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "failed", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	var output_exists: bool = FileAccess.file_exists(output_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), FAILED)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(temp_count, 0, "temp store 失败后必须走真实 cleanup。")
	assert_false(output_exists, "temp store 失败不得创建 final output。")
	assert_true(cleanup_succeeded, "temp write failure fixture 必须清理。")
	assert_push_error_count(1, "注入的 temp write failure 应报告一次错误。")


func test_save_text_rejects_existing_temp_collision_without_overwrite() -> void:
	var test_root: String = "user://gf_generated_artifact_report_temp_collision_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var output_path: String = allowed_root.path_join("output.txt")
	var collision_path: String = allowed_root.path_join("owned-temp.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(collision_path, "sentinel")
	GFGeneratedArtifactReport._configure_test_temp_path_override(collision_path)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "expected", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var collision_content: String = _read_user_text(collision_path)
	var output_exists: bool = FileAccess.file_exists(output_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_ALREADY_EXISTS)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(collision_content, "sentinel", "既有 temp identity 不得被 WRITE 截断。")
	assert_false(output_exists)
	assert_true(cleanup_succeeded, "temp collision fixture 必须清理。")
	assert_push_error_count(1, "temp name collision 应报告一次错误。")


func test_save_text_rechecks_existing_baseline_after_test_hook() -> void:
	var test_root: String = "user://gf_generated_artifact_report_baseline_race_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_baseline_output_path = allowed_root.path_join("existing.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(_baseline_output_path, "original")
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_replace_existing_with_concurrent_content")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_baseline_output_path,
		"replacement",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var final_content: String = _read_user_text(_baseline_output_path)
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(
		GFGeneratedArtifactReport.get_error_code(report),
		ERR_FILE_ALREADY_IN_USE
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(final_content, "concurrent", "post-hook baseline 漂移不得被 staged 内容吞掉。")
	assert_eq(temp_count, 0)
	assert_true(cleanup_succeeded, "baseline race fixture 必须清理。")
	assert_push_error_count(1, "post-hook baseline 漂移应报告一次冲突。")


func test_save_text_marks_conflict_when_existing_file_becomes_directory() -> void:
	var test_root: String = "user://gf_generated_artifact_report_existing_directory_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_baseline_output_path = allowed_root.path_join("existing.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(_baseline_output_path, "original")
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_replace_existing_file_with_directory")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_baseline_output_path,
		"replacement",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var output_is_directory: bool = DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(_baseline_output_path)
	)
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_ALREADY_IN_USE)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_true(output_is_directory, "baseline drift cleanup 不得删除接管 target 的未知目录。")
	assert_eq(temp_count, 0, "existing→directory 漂移后应清理 owned temp。")
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_rejects_same_size_staged_temp_tamper() -> void:
	var test_root: String = "user://gf_generated_artifact_report_temp_tamper_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	_temp_tamper_root = test_root.path_join("allowed")
	var output_path: String = _temp_tamper_root.path_join("output.txt")
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_replace_staged_temp_with_same_size_content")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "expected", {
		"allowed_roots": [_temp_tamper_root],
		"scan_filesystem": false,
	})
	var output_exists: bool = FileAccess.file_exists(output_path)
	var temp_count: int = _count_files_with_fragment(_temp_tamper_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_CORRUPT)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_false(output_exists, "同尺寸 staged temp 篡改不得提交 final output。")
	assert_eq(temp_count, 1, "未知的同尺寸 staged temp 不得由 cleanup 盲删。")
	assert_true(cleanup_succeeded, "staged temp tamper fixture 必须清理。")
	assert_push_error_count(1, "staged temp identity 漂移应报告一次错误。")


func test_save_text_preserves_unknown_directory_at_staged_temp_path() -> void:
	var test_root: String = "user://gf_generated_artifact_report_temp_directory_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	_temp_tamper_root = test_root.path_join("allowed")
	var output_path: String = _temp_tamper_root.path_join("output.txt")
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_replace_staged_temp_with_directory")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(output_path, "expected", {
		"allowed_roots": [_temp_tamper_root],
		"scan_filesystem": false,
	})
	var output_exists: bool = FileAccess.file_exists(output_path)
	var directory_preserved: bool = DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(_temp_directory_path)
	)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_CANT_WRITE)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_false(output_exists)
	assert_true(directory_preserved, "cleanup 不得把未知目录当作不存在或 owned temp 删除。")
	assert_true(cleanup_succeeded, "staged temp directory fixture 必须清理。")
	assert_push_error_count(1, "unknown temp directory 应报告一次错误。")


func test_save_text_reports_written_when_post_commit_guard_fails() -> void:
	var test_root: String = "user://gf_generated_artifact_report_post_commit_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_post_commit_output_path = allowed_root.path_join("output.txt")
	_post_commit_outside_root = test_root.path_join("outside")
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_post_commit_outside_root)
	)
	assert_eq(make_outside_error, OK)
	if make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	GFGeneratedArtifactReport._configure_test_after_final_replace(
		Callable(self, "_link_consumed_temp_after_final_replace")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_post_commit_output_path,
		"committed",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var output_content: String = _read_user_text(_post_commit_output_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_UNAUTHORIZED)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "written"), "rename 已提交后失败必须报告真实 written。")
	assert_eq(output_content, "committed")
	assert_true(cleanup_succeeded, "post-commit fixture 必须清理。")
	assert_push_error_count(1, "post-commit physical failure 应报告一次错误。")


func test_save_text_scans_committed_failure_and_preserves_reoccupied_temp() -> void:
	var test_root: String = "user://gf_generated_artifact_report_scan_committed_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_post_commit_output_path = allowed_root.path_join("output.txt")
	_scan_observer_count = 0
	_reoccupied_temp_path = ""
	GFGeneratedArtifactReport._configure_test_scan_filesystem_observer(
		Callable(self, "_record_scan_filesystem_request")
	)
	GFGeneratedArtifactReport._configure_test_after_final_replace(
		Callable(self, "_occupy_consumed_temp_after_final_replace")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_post_commit_output_path,
		"committed",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": true,
		}
	)
	var output_content: String = _read_user_text(_post_commit_output_path)
	var unknown_temp_content: String = _read_user_text(_reoccupied_temp_path)
	var unknown_temp_preserved: bool = FileAccess.file_exists(_reoccupied_temp_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_ALREADY_IN_USE)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_eq(output_content, "committed")
	assert_true(unknown_temp_preserved, "post-commit guard 不得删除重新占用 temp identity 的未知文件。")
	assert_eq(unknown_temp_content, "unknown-temp")
	assert_eq(_scan_observer_count, 1, "已提交失败且 scan_filesystem=true 应精确请求一次扫描。")
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_does_not_scan_committed_failure_when_disabled() -> void:
	var test_root: String = "user://gf_generated_artifact_report_no_scan_committed_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_post_commit_output_path = allowed_root.path_join("output.txt")
	_scan_observer_count = 0
	_reoccupied_temp_path = ""
	GFGeneratedArtifactReport._configure_test_scan_filesystem_observer(
		Callable(self, "_record_scan_filesystem_request")
	)
	GFGeneratedArtifactReport._configure_test_after_final_replace(
		Callable(self, "_occupy_consumed_temp_after_final_replace")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_post_commit_output_path,
		"committed",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var unknown_temp_preserved: bool = FileAccess.file_exists(_reoccupied_temp_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_true(unknown_temp_preserved)
	assert_eq(_scan_observer_count, 0, "scan_filesystem=false 不得触发测试 observer 或 EditorFileSystem 扫描。")
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_rejects_backup_reoccupation_after_cleanup() -> void:
	var test_root: String = "user://gf_generated_artifact_report_backup_reoccupied_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	_post_commit_output_path = allowed_root.path_join("output.txt")
	_reoccupied_backup_path = ""
	_post_cleanup_snapshot_count = 0
	_scan_observer_count = 0
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(_post_commit_output_path, "original")
	GFGeneratedArtifactReport._configure_test_scan_filesystem_observer(
		Callable(self, "_record_scan_filesystem_request")
	)
	GFGeneratedArtifactReport._configure_test_after_final_replace(
		Callable(self, "_arm_backup_reoccupation_after_final_replace")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_post_commit_output_path,
		"replacement",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": true,
		}
	)
	var output_content: String = _read_user_text(_post_commit_output_path)
	var unknown_backup_content: String = _read_user_text(_reoccupied_backup_path)
	var unknown_backup_preserved: bool = FileAccess.file_exists(_reoccupied_backup_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_ALREADY_IN_USE)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_eq(output_content, "replacement")
	assert_eq(_post_cleanup_snapshot_count, 3, "fixture 必须在 backup cleanup 后的 output snapshot 重占 backup。")
	assert_true(unknown_backup_preserved, "final guard 不得删除 cleanup 后重占 backup identity 的未知文件。")
	assert_eq(unknown_backup_content, "unknown-backup")
	assert_eq(_scan_observer_count, 1)
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_capture_file_snapshot_rechecks_physical_guard_after_hash_read() -> void:
	var test_root: String = "user://gf_generated_artifact_report_snapshot_race_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	_snapshot_allowed_root = test_root.path_join("allowed")
	_snapshot_outside_root = test_root.path_join("outside")
	_snapshot_staged_root = test_root.path_join("staged")
	var snapshot_path: String = _snapshot_allowed_root.path_join("snapshot.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_snapshot_allowed_root)
	)
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_snapshot_outside_root)
	)
	assert_eq(make_allowed_error, OK)
	assert_eq(make_outside_error, OK)
	if make_allowed_error != OK or make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(snapshot_path, "snapshot")
	GFGeneratedArtifactReport._configure_test_after_file_snapshot_read(
		Callable(self, "_replace_snapshot_parent_with_link")
	)

	var snapshot: Dictionary = GFGeneratedArtifactReport._capture_file_snapshot(
		snapshot_path,
		true
	)
	var linked_parent: bool = _absolute_path_is_link(
		ProjectSettings.globalize_path(_snapshot_allowed_root)
	)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_true(linked_parent, "snapshot callback 必须在 SHA 读取后交换父目录为 link。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(snapshot, "ok"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(snapshot, "error_code"),
		ERR_UNAUTHORIZED,
		"post-read physical guard 错误不得折叠为 ERR_FILE_CORRUPT。"
	)
	assert_true(cleanup_succeeded)


func test_save_text_marks_conflict_when_rollback_target_becomes_directory() -> void:
	var test_root: String = "user://gf_generated_artifact_report_rollback_takeover_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	_rollback_allowed_root = test_root.path_join("allowed")
	_rollback_output_path = _rollback_allowed_root.path_join("existing.txt")
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_rollback_allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(_rollback_output_path, "original")
	_scan_observer_count = 0
	GFGeneratedArtifactReport._configure_test_scan_filesystem_observer(
		Callable(self, "_record_scan_filesystem_request")
	)
	GFGeneratedArtifactReport._configure_test_after_file_snapshot_read(
		Callable(self, "_take_over_output_after_backup_snapshot")
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		_rollback_output_path,
		"replacement",
		{
			"allowed_roots": [_rollback_allowed_root],
			"scan_filesystem": true,
		}
	)
	var output_is_directory: bool = DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(_rollback_output_path)
	)
	var backup_count: int = _count_files_with_fragment(
		_rollback_allowed_root,
		".backup.tmp."
	)
	var backup_path: String = _find_file_with_fragment(
		_rollback_allowed_root,
		".backup.tmp."
	)
	var backup_content: String = _read_user_text(backup_path)
	var total_temp_count: int = _count_files_with_fragment(
		_rollback_allowed_root,
		".tmp."
	)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_FILE_ALREADY_IN_USE)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "conflict"))
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_true(output_is_directory, "rollback 不得删除接管 output identity 的未知目录。")
	assert_eq(backup_count, 1, "rollback takeover 后应保留精确原始 backup。")
	assert_eq(backup_content, "original", "保留的 rollback backup 必须仍匹配原始 target 内容。")
	assert_eq(total_temp_count, 1, "rollback takeover 后只允许保留 backup，owned staged temp 必须清理。")
	assert_eq(_scan_observer_count, 1, "rollback 未恢复可见输出时必须请求一次文件系统扫描。")
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_captures_both_replace_hooks_before_reentrant_save() -> void:
	var test_root: String = "user://gf_generated_artifact_report_hook_reentry_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	_reentrant_allowed_root = test_root.path_join("allowed")
	_reentrant_output_path = _reentrant_allowed_root.path_join("outer.txt")
	_post_commit_outside_root = test_root.path_join("outside")
	var make_outside_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_post_commit_outside_root)
	)
	assert_eq(make_outside_error, OK)
	if make_outside_error != OK:
		_remove_test_tree(test_root)
		return
	GFGeneratedArtifactReport._configure_test_before_final_replace(
		Callable(self, "_run_reentrant_save_before_outer_replace")
	)
	GFGeneratedArtifactReport._configure_test_after_final_replace(
		Callable(self, "_record_and_link_outer_consumed_temp")
	)

	var outer_report: Dictionary = GFGeneratedArtifactReport.save_text(
		_reentrant_output_path,
		"outer",
		{
			"allowed_roots": [_reentrant_allowed_root],
			"scan_filesystem": false,
		}
	)
	var outer_content: String = _read_user_text(_reentrant_output_path)
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(_reentrant_report, "success"))
	assert_eq(_hook_observed_output_path, _reentrant_output_path)
	assert_eq(_hook_call_count, 1, "outer after hook 必须 exactly-once，nested save 不得观察它。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(outer_report, "success"))
	assert_eq(GFGeneratedArtifactReport.get_error_code(outer_report), ERR_UNAUTHORIZED)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(outer_report, "written"))
	assert_eq(outer_content, "outer")
	assert_true(cleanup_succeeded)
	assert_push_error_count(1)


func test_save_text_preserves_ordinary_allowed_and_legacy_user_paths() -> void:
	var test_root: String = "user://gf_generated_artifact_report_ordinary_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var allowed_path: String = allowed_root.path_join("item.txt")
	var legacy_path: String = test_root.path_join("legacy/item.txt")
	var res_root: String = "res://.gf_generated_artifact_report_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var res_path: String = res_root.path_join("item.txt")
	var legacy_res_path: String = res_root.path_join("legacy.txt")
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(allowed_path, "first", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var replacement_report: Dictionary = GFGeneratedArtifactReport.save_text(allowed_path, "second", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var legacy_report: Dictionary = GFGeneratedArtifactReport.save_text(
		legacy_path,
		"legacy",
		{ "scan_filesystem": false }
	)
	var res_report: Dictionary = GFGeneratedArtifactReport.save_text(res_path, "res", {
		"allowed_roots": [res_root],
		"scan_filesystem": false,
	})
	var legacy_res_report: Dictionary = GFGeneratedArtifactReport.save_text(
		legacy_res_path,
		"legacy-res",
		{ "scan_filesystem": false }
	)
	var allowed_content: String = _read_user_text(allowed_path)
	var legacy_content: String = _read_user_text(legacy_path)
	var res_content: String = _read_user_text(res_path)
	var legacy_res_content: String = _read_user_text(legacy_res_path)
	var temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	_remove_test_tree(test_root)
	_remove_test_tree(res_root)
	var user_cleanup_succeeded: bool = not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(test_root)
	)
	var res_cleanup_succeeded: bool = not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(res_root)
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_report, "success"), "普通 allowed user:// 新写入应兼容。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(replacement_report, "success"), "普通 existing replacement 应兼容。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(replacement_report, "written"), "replacement 成功应报告已提交。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(legacy_report, "success"), "缺省 allowed_roots 的旧 user:// 行为应兼容。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(res_report, "success"), "普通 allowed res:// 写入应兼容。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(legacy_res_report, "success"), "缺省 allowed_roots 的旧 res:// 行为应兼容。")
	assert_eq(allowed_content, "second")
	assert_eq(legacy_content, "legacy")
	assert_eq(res_content, "res")
	assert_eq(legacy_res_content, "legacy-res")
	assert_eq(temp_count, 0, "successful replacement 不得残留 temp/backup。")
	assert_true(user_cleanup_succeeded, "ordinary user:// fixture 必须清理。")
	assert_true(res_cleanup_succeeded, "ordinary res:// fixture 必须清理。")


func test_save_text_replaces_malformed_utf8_using_original_raw_backup_identity() -> void:
	var test_root: String = "user://gf_generated_artifact_report_raw_backup_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var allowed_root: String = test_root.path_join("allowed")
	var output_path: String = allowed_root.path_join("malformed.txt")
	var original_bytes: PackedByteArray = PackedByteArray([0x66, 0x80, 0x6f])
	var make_allowed_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(allowed_root)
	)
	assert_eq(make_allowed_error, OK)
	if make_allowed_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_bytes(output_path, original_bytes)
	var decoded_text: String = _read_user_text(output_path)
	var decoded_bytes: PackedByteArray = decoded_text.to_utf8_buffer()
	assert_false(
		decoded_bytes == original_bytes,
		"fixture 必须证明 get_as_text() 后的 UTF-8 字节不再等于原始文件。"
	)

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		output_path,
		"replacement",
		{
			"allowed_roots": [allowed_root],
			"scan_filesystem": false,
		}
	)
	var final_bytes: PackedByteArray = _read_user_bytes(output_path)
	var backup_count: int = _count_files_with_fragment(allowed_root, ".backup.tmp.")
	var total_temp_count: int = _count_files_with_fragment(allowed_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_eq(final_bytes, "replacement".to_utf8_buffer())
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(report, "previous_sha256"),
		_sha256_bytes(decoded_bytes),
		"public previous_sha256 必须继续表示 decoded-text baseline。"
	)
	assert_ne(
		GF_VARIANT_ACCESS.get_option_string(report, "previous_sha256"),
		_sha256_bytes(original_bytes),
		"raw backup identity 不得泄漏或替换 public text baseline。"
	)
	assert_eq(backup_count, 0, "raw-byte replacement 成功后不得遗留 backup。")
	assert_eq(total_temp_count, 0, "raw-byte replacement 成功后不得遗留 staging。")
	assert_true(cleanup_succeeded)


func test_save_text_preserves_legacy_direct_file_symlink_replacement() -> void:
	var test_root: String = "user://gf_generated_artifact_report_legacy_symlink_%d_%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]
	var output_path: String = test_root.path_join("output.txt")
	var referent_path: String = test_root.path_join("referent.txt")
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(test_root)
	)
	assert_eq(make_root_error, OK)
	if make_root_error != OK:
		_remove_test_tree(test_root)
		return
	_write_user_text(referent_path, "original")
	var link_error: Error = _create_direct_file_link_for_test(
		referent_path,
		output_path
	)
	assert_eq(link_error, OK, "fixture 必须创建 direct file symlink。")
	if link_error != OK:
		_remove_test_tree(test_root)
		return
	assert_true(
		_absolute_path_is_link(ProjectSettings.globalize_path(output_path)),
		"fixture output 必须是 direct link。"
	)
	assert_true(FileAccess.file_exists(output_path), "legacy output link 必须可读取 referent。")

	var report: Dictionary = GFGeneratedArtifactReport.save_text(
		output_path,
		"replacement",
		{ "scan_filesystem": false }
	)
	var output_exists: bool = FileAccess.file_exists(output_path)
	var output_is_link: bool = _absolute_path_is_link(
		ProjectSettings.globalize_path(output_path)
	)
	var output_content: String = _read_user_text(output_path)
	var referent_content: String = _read_user_text(referent_path)
	var backup_count: int = _count_files_with_fragment(test_root, ".backup.tmp.")
	var total_temp_count: int = _count_files_with_fragment(test_root, ".tmp.")
	_remove_test_tree(test_root)
	var cleanup_succeeded: bool = _test_tree_removed(test_root)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "written"))
	assert_true(output_exists, "legacy symlink replacement 后 output 必须存在。")
	assert_false(output_is_link, "replacement 应用新 regular file 取代 symlink 目录项。")
	assert_eq(output_content, "replacement")
	assert_eq(referent_content, "original", "替换 symlink 不得改写原 referent。")
	assert_eq(backup_count, 0, "legacy symlink replacement 成功后不得遗留 backup link。")
	assert_eq(total_temp_count, 0)
	assert_true(cleanup_succeeded)


func test_summarize_reports_counts_statuses_and_owner_groups() -> void:
	var reports: Array[Dictionary] = [
		GFGeneratedArtifactReport.make_report("res://a.gd", GFGeneratedArtifactReport.STATUS_NEW, OK, "", {
			"written": true,
			"changed": true,
			"artifact_owner": GFGeneratedArtifactReport.OWNER_GENERATED,
		}),
		GFGeneratedArtifactReport.make_report("res://b.gd", GFGeneratedArtifactReport.STATUS_UNCHANGED, OK, "", {
			"artifact_owner": GFGeneratedArtifactReport.OWNER_GENERATED,
		}),
		GFGeneratedArtifactReport.make_report("res://c.gd", GFGeneratedArtifactReport.STATUS_SKIPPED, ERR_ALREADY_EXISTS, "skip", {
			"artifact_owner": GFGeneratedArtifactReport.OWNER_USER,
			"dry_run": true,
		}),
	]

	var summary: Dictionary = GFGeneratedArtifactReport.summarize_reports(reports, "Accessors", {
		"include_reports": true,
	})
	var status_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "status_counts")
	var owner_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "owner_counts")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(reports[2], "success"), "单个 skipped 报告不应被标记为 failed。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(summary, "success"), "skipped 不是 failed，批量摘要仍应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "artifact_count"), 3, "摘要应统计产物数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "written_count"), 1, "摘要应统计写入数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "changed_count"), 1, "摘要应统计 changed 数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "dry_run_count"), 1, "摘要应统计 dry-run 数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "skipped_count"), 1, "摘要应统计 skipped 数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status_counts, "new"), 1, "状态计数应包含 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status_counts, "unchanged"), 1, "状态计数应包含 unchanged。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status_counts, "skipped"), 1, "状态计数应包含 skipped。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(owner_counts, "generated"), 2, "所有权计数应包含 generated。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(owner_counts, "user"), 1, "所有权计数应包含 user。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(summary, "errors").size(), 1, "非 OK error_code 应进入 errors 便于审查。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(summary, "reports").size(), 3, "include_reports 应保留报告副本。")


func test_summarize_reports_returns_json_safe_metadata_and_reports() -> void:
	var raw_report: Dictionary = {
		"success": true,
		"path": "res://generated/raw.gd",
		"status": GFGeneratedArtifactReport.STATUS_NEW,
		"error_code": OK,
		"error": "",
		"written": true,
		"changed": true,
		"dry_run": false,
		"size_bytes": 5,
		"artifact_owner": GFGeneratedArtifactReport.OWNER_GENERATED,
		"generator_id": "test.generator",
		"source_id": "raw",
		"content_sha256": "abc",
		"previous_sha256": "",
		"encoding": "utf-8",
		"metadata": {
			"owner": self,
		},
	}
	var summary: Dictionary = GFGeneratedArtifactReport.summarize_reports([raw_report], "Safe", {
		"include_reports": true,
		"metadata": {
			"owner": self,
		},
	})
	var summary_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "metadata")
	var summary_owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary_metadata, "owner")
	var summary_owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary_owner_payload, "__gf_report_value__")
	var included_reports: Array = GF_VARIANT_ACCESS.get_option_array(summary, "reports")
	var included_report: Dictionary = {}
	if not included_reports.is_empty() and included_reports[0] is Dictionary:
		included_report = included_reports[0]
	var included_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_report, "metadata")
	var included_owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_metadata, "owner")
	var included_owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_owner_payload, "__gf_report_value__")

	assert_eq(GF_VARIANT_ACCESS.get_option_string(summary_owner_marker, "type"), "Object", "摘要 metadata 应通过报告边界编码。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(included_owner_marker, "type"), "Object", "include_reports 中的单项 metadata 应通过报告边界编码。")
	assert_false(JSON.stringify(summary).contains(":null"), "批量摘要应可直接 JSON.stringify()。")


func _read_user_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _read_user_bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


func _count_user_files_with_prefix(prefix: String) -> int:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return 0
	var count: int = 0
	var _list_begin_error: Error = dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if not dir.current_is_dir() and file_name.begins_with(prefix):
			count += 1
	dir.list_dir_end()
	return count


func _remove_test_tree(resource_root: String) -> void:
	var absolute_root: String = ProjectSettings.globalize_path(resource_root)
	_remove_absolute_test_path(absolute_root)


func _test_tree_removed(resource_root: String) -> bool:
	var absolute_root: String = ProjectSettings.globalize_path(resource_root)
	return not _path_entry_exists_for_test(absolute_root)


func _path_entry_exists_for_test(path: String) -> bool:
	return (
		_absolute_path_is_link(path)
		or FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(path)
	)


func _remove_absolute_test_path(path: String) -> void:
	if _absolute_path_is_link(path):
		var _remove_link_error: Error = DirAccess.remove_absolute(path)
		return
	if FileAccess.file_exists(path):
		var _remove_file_error: Error = DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.include_navigational = false
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		_remove_absolute_test_path(path.path_join(entry_name))
		entry_name = directory.get_next()
	directory.list_dir_end()
	var _remove_directory_error: Error = DirAccess.remove_absolute(path)


func _absolute_path_is_link(path: String) -> bool:
	var parent_path: String = path.get_base_dir()
	var entry_name: String = path.get_file()
	if parent_path.is_empty() or entry_name.is_empty():
		return false
	var parent_directory: DirAccess = DirAccess.open(parent_path)
	if parent_directory == null:
		return false
	return parent_directory.is_link(entry_name)


func _replace_race_child_with_link() -> void:
	var absolute_child: String = ProjectSettings.globalize_path(_race_linked_child)
	var absolute_staged_child: String = ProjectSettings.globalize_path(
		_race_allowed_root.path_join("staged-child")
	)
	var move_child_error: Error = DirAccess.rename_absolute(
		absolute_child,
		absolute_staged_child
	)
	assert_eq(move_child_error, OK, "race callback 必须先移走含 staged temp 的普通目录。")
	if move_child_error != OK:
		return
	var link_error: Error = GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(_race_outside_root),
		absolute_child
	)
	assert_eq(link_error, OK, "race callback 必须建立 symlink 或 Windows directory junction。")


func _create_directory_at_failure_output() -> void:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_failure_output_path)
	)
	assert_eq(make_directory_error, OK, "test-owned callback 必须建立阻断 final rename 的目录。")


func _replace_existing_with_concurrent_content() -> void:
	_write_user_text(_baseline_output_path, "concurrent")


func _replace_existing_file_with_directory() -> void:
	var remove_error: Error = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(_baseline_output_path)
	)
	assert_eq(remove_error, OK)
	if remove_error != OK:
		return
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_baseline_output_path)
	)
	assert_eq(make_directory_error, OK)


func _replace_staged_temp_with_same_size_content() -> void:
	var temp_path: String = _find_file_with_fragment(_temp_tamper_root, ".tmp.")
	assert_false(temp_path.is_empty(), "test-owned callback 必须定位 staged temp。")
	if temp_path.is_empty():
		return
	_write_user_text(temp_path, "tampered")


func _replace_staged_temp_with_directory() -> void:
	_temp_directory_path = _find_file_with_fragment(_temp_tamper_root, ".tmp.")
	assert_false(_temp_directory_path.is_empty(), "test-owned callback 必须定位 staged temp。")
	if _temp_directory_path.is_empty():
		return
	var remove_error: Error = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(_temp_directory_path)
	)
	assert_eq(remove_error, OK, "test-owned callback 必须先移除 owned staged temp。")
	if remove_error != OK:
		return
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_temp_directory_path)
	)
	assert_eq(make_directory_error, OK, "test-owned callback 必须建立 unknown directory identity。")


func _link_consumed_temp_after_final_replace(
	output_path: String,
	temp_path: String,
	_backup_path: String
) -> void:
	assert_eq(output_path, _post_commit_output_path)
	var link_error: Error = GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(_post_commit_outside_root),
		ProjectSettings.globalize_path(temp_path)
	)
	assert_eq(link_error, OK, "test-owned post-commit callback 必须在 consumed temp identity 建立 link。")


func _record_scan_filesystem_request() -> void:
	_scan_observer_count += 1


func _occupy_consumed_temp_after_final_replace(
	output_path: String,
	temp_path: String,
	_backup_path: String
) -> void:
	assert_eq(output_path, _post_commit_output_path)
	_reoccupied_temp_path = temp_path
	_write_user_text(temp_path, "unknown-temp")


func _arm_backup_reoccupation_after_final_replace(
	output_path: String,
	_temp_path: String,
	backup_path: String
) -> void:
	assert_eq(output_path, _post_commit_output_path)
	_reoccupied_backup_path = backup_path
	GFGeneratedArtifactReport._configure_test_after_file_snapshot_read(
		Callable(self, "_reoccupy_backup_after_post_cleanup_snapshot")
	)


func _reoccupy_backup_after_post_cleanup_snapshot(snapshot_path: String) -> void:
	_post_cleanup_snapshot_count += 1
	if (
		snapshot_path != _post_commit_output_path
		or GFGeneratedArtifactReport._path_entry_exists(_reoccupied_backup_path)
	):
		GFGeneratedArtifactReport._configure_test_after_file_snapshot_read(
			Callable(self, "_reoccupy_backup_after_post_cleanup_snapshot")
		)
		return
	assert_false(
		GFGeneratedArtifactReport._path_entry_exists(_reoccupied_backup_path),
		"第二次 committed output snapshot 前 backup cleanup 必须已完成。"
	)
	_write_user_text(_reoccupied_backup_path, "unknown-backup")


func _configure_outside_backup_override() -> void:
	GFGeneratedArtifactReport._configure_test_temp_path_override(_outside_backup_path)


func _replace_snapshot_parent_with_link(_snapshot_path: String) -> void:
	var move_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(_snapshot_allowed_root),
		ProjectSettings.globalize_path(_snapshot_staged_root)
	)
	assert_eq(move_error, OK)
	if move_error != OK:
		return
	var link_error: Error = GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(_snapshot_outside_root),
		ProjectSettings.globalize_path(_snapshot_allowed_root)
	)
	assert_eq(link_error, OK)


func _take_over_output_after_backup_snapshot(snapshot_path: String) -> void:
	if not snapshot_path.contains(".backup.tmp."):
		GFGeneratedArtifactReport._configure_test_after_file_snapshot_read(
			Callable(self, "_take_over_output_after_backup_snapshot")
		)
		return
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_rollback_output_path)
	)
	assert_eq(make_directory_error, OK)


func _run_reentrant_save_before_outer_replace() -> void:
	_reentrant_report = GFGeneratedArtifactReport.save_text(
		_reentrant_allowed_root.path_join("nested.txt"),
		"nested",
		{
			"allowed_roots": [_reentrant_allowed_root],
			"scan_filesystem": false,
		}
	)


func _record_and_link_outer_consumed_temp(
	output_path: String,
	temp_path: String,
	_backup_path: String
) -> void:
	_hook_call_count += 1
	_hook_observed_output_path = output_path
	if output_path != _reentrant_output_path:
		return
	var link_error: Error = GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(_post_commit_outside_root),
		ProjectSettings.globalize_path(temp_path)
	)
	assert_eq(link_error, OK)


func _write_user_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入 fixture 文本。")
	if file == null:
		return
	var _stored: Variant = file.store_string(text)
	file.close()


func _write_user_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入 fixture 字节。")
	if file == null:
		return
	var _store_result: Variant = file.store_buffer(bytes)
	file.close()


func _create_direct_file_link_for_test(target_path: String, link_path: String) -> Error:
	var link_parent: DirAccess = DirAccess.open(link_path.get_base_dir())
	if link_parent == null:
		return ERR_CANT_OPEN
	return link_parent.create_link(
		ProjectSettings.globalize_path(target_path),
		ProjectSettings.globalize_path(link_path)
	)


func _find_file_with_fragment(resource_root: String, fragment: String) -> String:
	var directory: DirAccess = DirAccess.open(resource_root)
	if directory == null:
		return ""
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return ""
	var result: String = ""
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if not directory.current_is_dir() and entry_name.contains(fragment):
			result = resource_root.path_join(entry_name)
			break
		entry_name = directory.get_next()
	directory.list_dir_end()
	return result


class AllowedRootStringifier extends RefCounted:
	var _value: String = ""

	func _init(value: String) -> void:
		_value = value

	func _to_string() -> String:
		return _value


func _count_files_with_fragment(resource_root: String, fragment: String) -> int:
	var directory: DirAccess = DirAccess.open(resource_root)
	if directory == null:
		return 0
	var count: int = 0
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return 0
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if not directory.current_is_dir() and entry_name.contains(fragment):
			count += 1
		entry_name = directory.get_next()
	directory.list_dir_end()
	return count
