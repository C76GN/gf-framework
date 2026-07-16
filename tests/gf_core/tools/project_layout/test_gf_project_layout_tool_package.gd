extends GutTest

const PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
const GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_scaffolder.gd")
const GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_validator.gd")

var _temporary_roots: Array[String] = []


func before_each() -> void:
	_temporary_roots.clear()


func after_each() -> void:
	for root_path: String in _temporary_roots:
		_remove_directory_tree(root_path)
	_temporary_roots.clear()


func test_feature_cohesive_profile_is_valid_json_and_declares_rules() -> void:
	assert_true(FileAccess.file_exists(PROFILE_PATH), "项目结构模板必须随工具包发布。")

	var source_text: String = FileAccess.get_file_as_string(PROFILE_PATH)
	var profile_value: Variant = JSON.parse_string(source_text)
	assert_true(profile_value is Dictionary, "项目结构模板必须是 JSON Dictionary。")
	if not profile_value is Dictionary:
		return

	var profile: Dictionary = profile_value
	assert_eq(GFVariantData.get_option_int(profile, "schema_version"), 1, "项目结构模板 schema_version 必须固定。")
	assert_eq(GFVariantData.get_option_string(profile, "id"), "gf.project_layout.feature_cohesive.v1", "项目结构模板 id 必须稳定。")

	var rules_value: Variant = profile.get("rules", [])
	assert_true(rules_value is Array, "项目结构模板必须声明 rules。")
	if not rules_value is Array:
		return

	var rule_kinds: Array[String] = []
	for rule_value: Variant in rules_value:
		assert_true(rule_value is Dictionary, "每条项目结构规则必须是 Dictionary。")
		if rule_value is Dictionary:
			var rule: Dictionary = rule_value
			rule_kinds.append(str(rule.get("kind", "")))

	assert_true(rule_kinds.has("forbid_root_files"), "项目结构模板必须约束根目录文件。")
	assert_true(rule_kinds.has("naming_convention"), "项目结构模板必须约束路径命名。")
	assert_true(rule_kinds.has("feature_module_contract"), "项目结构模板必须声明 Feature 模块契约。")
	assert_true(rule_kinds.has("generated_boundary"), "项目结构模板必须约束生成物边界。")
	assert_true(rule_kinds.has("bucket_size"), "项目结构模板必须能限制遗留大桶目录增长。")


func test_project_layout_scaffolder_dry_run_plans_required_paths() -> void:
	var root_path: String = _track_root("user://gf_project_layout_dry_run_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()

	var result: Dictionary = scaffolder.scaffold_profile_path(PROFILE_PATH, {
		"root_path": root_path,
		"feature_ids": ["inventory"],
		"dry_run": true,
	})
	var planned_paths: Array = GFVariantData.get_option_array(result, "planned_paths")
	var created_paths: Array = GFVariantData.get_option_array(result, "created_paths")
	var operations: Array = GFVariantData.get_option_array(result, "operations")

	assert_true(GFVariantData.get_option_bool(result, "success"), "合法 profile dry-run 脚手架应通过。")
	assert_true(GFVariantData.get_option_bool(result, "dry_run"), "报告应保留 dry_run 标记。")
	assert_true(planned_paths.has(root_path), "dry-run 应计划创建项目根目录。")
	assert_true(planned_paths.has(root_path.path_join("app")), "dry-run 应计划创建必需 app 根。")
	assert_true(planned_paths.has(root_path.path_join("features")), "dry-run 应计划创建必需 features 根。")
	assert_true(planned_paths.has(root_path.path_join("features/inventory/scripts")), "dry-run 应计划创建 Feature 必需 scripts 子目录。")
	assert_true(created_paths.is_empty(), "dry-run 的 created_paths 必须只表达真实文件系统写入。")
	assert_true(_has_operation_state(operations, root_path, "planned"), "dry-run 应记录可审计的 planned operation。")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path)), "dry-run 不应创建真实目录。")


func test_project_layout_scaffolder_creates_feature_directories() -> void:
	var root_path: String = _track_root("user://gf_project_layout_create_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()

	var result: Dictionary = scaffolder.scaffold_default_profile({
		"root_path": root_path,
		"feature_ids": PackedStringArray(["inventory"]),
	})

	assert_true(GFVariantData.get_option_bool(result, "success"), "脚手架应能创建 profile 声明目录。")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path.path_join("app"))), "脚手架应创建 app 根。")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path.path_join("features/inventory/scripts"))), "脚手架应创建 Feature scripts 子目录。")


func test_project_layout_scaffolder_rejects_invalid_feature_id() -> void:
	var root_path: String = _track_root("user://gf_project_layout_invalid_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()

	var result: Dictionary = scaffolder.scaffold_profile_path(PROFILE_PATH, {
		"root_path": root_path,
		"feature_ids": ["Bad-Name"],
		"dry_run": true,
	})
	var issues: Array = GFVariantData.get_option_array(result, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "非法 Feature ID 应阻断脚手架。")
	assert_eq(GFVariantData.get_option_int(result, "error_count"), 1, "非法 Feature ID 应记录一个 error。")
	assert_true(_has_issue_kind(issues, "invalid_feature_id"), "报告应明确 invalid_feature_id。")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path)), "失败 dry-run 不应创建目录。")


func test_project_layout_scaffolder_safe_helper_rejects_unsafe_feature_id() -> void:
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var profile: Dictionary = _make_minimal_feature_profile()

	var escape_paths: PackedStringArray = scaffolder.make_feature_module_paths(profile, "../escape")
	var bad_separator_paths: PackedStringArray = scaffolder.make_feature_module_paths(profile, "bad\\name")

	assert_eq(escape_paths.size(), 0, "public helper 不应返回父级越界 Feature 路径。")
	assert_eq(bad_separator_paths.size(), 0, "public helper 不应返回含路径分隔符的 Feature 路径。")


func test_project_layout_scaffolder_safe_helper_rejects_windows_parent_segments() -> void:
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var unsafe_root_profile: Dictionary = _make_minimal_feature_profile()
	unsafe_root_profile["rules"][0]["roots"] = ["features\\..\\escape"]
	var unsafe_subdir_profile: Dictionary = _make_minimal_feature_profile()
	unsafe_subdir_profile["rules"][0]["required_subdirs"] = ["scripts\\..\\escape"]

	assert_true(
		scaffolder.make_feature_module_paths(unsafe_root_profile, "inventory").is_empty(),
		"public helper 不应返回含 Windows 父级片段的 root。"
	)
	assert_true(
		scaffolder.make_feature_module_paths(unsafe_subdir_profile, "inventory").is_empty(),
		"public helper 不应返回含 Windows 父级片段的 subdir。"
	)


func test_project_layout_scaffolder_rolls_back_created_paths_on_partial_failure() -> void:
	var root_path: String = _track_root("user://gf_project_layout_partial_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "partial_failure_fixture",
		"zones": [
			{ "id": "app", "roots": ["generated/cache/nested"], "required": true, "severity": "error" },
			{ "id": "blocked", "roots": ["blocked/child"], "required": true, "severity": "error" },
		],
		"rules": [],
	}
	_write_text(root_path.path_join("blocked"), "not a directory")

	var result: Dictionary = scaffolder.scaffold_profile(profile, { "root_path": root_path })
	var issues: Array = GFVariantData.get_option_array(result, "issues")
	var rolled_back_paths: Array = GFVariantData.get_option_array(result, "rolled_back_paths")
	var operations: Array = GFVariantData.get_option_array(result, "operations")

	assert_false(GFVariantData.get_option_bool(result, "success"), "部分目录创建失败应阻断脚手架。")
	assert_true(_has_issue_kind(issues, "directory_create_failed"), "报告应包含原始创建失败。")
	assert_true(_has_issue_kind(issues, "scaffold_rolled_back_after_failure"), "报告应明确已执行回滚。")
	assert_true(rolled_back_paths.has(root_path.path_join("generated/cache/nested")), "显式末级目录应被回滚并记录。")
	assert_true(rolled_back_paths.has(root_path.path_join("generated/cache")), "递归创建的中间目录应被回滚并记录。")
	assert_true(rolled_back_paths.has(root_path.path_join("generated")), "递归创建的首级目录应被回滚并记录。")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path.path_join("generated"))), "失败后不应留下递归创建的中间目录。")
	assert_true(
		_has_operation_state(operations, root_path.path_join("generated/cache"), "rolled_back"),
		"operation journal 应记录隐式父目录已回滚。"
	)


func test_project_layout_validator_accepts_scaffolded_feature_layout() -> void:
	var root_path: String = _track_root("user://gf_project_layout_validate_ok_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()

	var scaffold_result: Dictionary = scaffolder.scaffold_default_profile({
		"root_path": root_path,
		"feature_ids": ["inventory"],
	})
	var validate_result: Dictionary = validator.validate_default_profile({ "root_path": root_path })

	assert_true(GFVariantData.get_option_bool(scaffold_result, "success"), "测试结构应先由脚手架创建成功。")
	assert_true(GFVariantData.get_option_bool(validate_result, "success"), "脚手架创建的最小 Feature 内聚结构应通过校验。")
	assert_eq(GFVariantData.get_option_int(validate_result, "error_count"), 0, "合法结构不应产生 error。")
	assert_true(GFVariantData.get_option_int(validate_result, "directory_count") >= 3, "校验报告应统计扫描目录。")


func test_project_layout_validator_rejects_unknown_rule_kind() -> void:
	var root_path: String = _track_root("user://gf_project_layout_unknown_rule_%d" % Time.get_ticks_usec())
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var profile: Dictionary = _make_minimal_feature_profile()
	profile["rules"] = [{ "id": "typo", "kind": "generated_boundry", "severity": "error" }]

	var result: Dictionary = validator.validate_profile(profile, {
		"root_path": root_path,
		"allow_missing_root": true,
	})
	var issues: Array = GFVariantData.get_option_array(result, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "未知规则类型应阻断 profile。")
	assert_true(_has_issue_kind(issues, "unsupported_rule_kind"), "报告应明确 unsupported_rule_kind。")


func test_project_layout_validator_rejects_invalid_severity() -> void:
	var root_path: String = _track_root("user://gf_project_layout_bad_severity_%d" % Time.get_ticks_usec())
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var profile: Dictionary = _make_minimal_feature_profile()
	profile["rules"] = [{ "id": "bad", "kind": "feature_module_contract", "roots": ["features"], "required_subdirs": ["scripts"], "severity": "erorr" }]

	var result: Dictionary = validator.validate_profile(profile, {
		"root_path": root_path,
		"allow_missing_root": true,
	})
	var issues: Array = GFVariantData.get_option_array(result, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "非法 severity 不应降级为 info。")
	assert_true(_has_issue_kind(issues, "invalid_severity"), "报告应明确 invalid_severity。")


func test_project_layout_tools_reject_unknown_profile_fields() -> void:
	var root_path: String = _track_root("user://gf_project_layout_unknown_fields_%d" % Time.get_ticks_usec())
	var profile: Dictionary = _make_minimal_feature_profile()
	profile["preset"] = "unsupported"
	profile["zones"] = [{
		"id": "app",
		"roots": ["app"],
		"required": true,
		"unexpected": true,
	}]
	profile["rules"][0]["max_filez"] = 3
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()

	var validate_result: Dictionary = validator.validate_profile(profile, {
		"root_path": root_path,
		"allow_missing_root": true,
	})
	var scaffold_result: Dictionary = scaffolder.scaffold_profile(profile, {
		"root_path": root_path,
		"dry_run": true,
	})

	assert_false(GFVariantData.get_option_bool(validate_result, "success"), "validator 必须拒绝未知 profile 字段。")
	assert_false(GFVariantData.get_option_bool(scaffold_result, "success"), "scaffolder 必须拒绝未知 profile 字段。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(validate_result, "issues"), "unsupported_profile_field"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(validate_result, "issues"), "unsupported_zone_field"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(validate_result, "issues"), "unsupported_rule_field"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(scaffold_result, "issues"), "unsupported_profile_field"))


func test_project_layout_tools_reject_non_integer_schema_and_limits() -> void:
	var root_path: String = _track_root("user://gf_project_layout_strict_int_%d" % Time.get_ticks_usec())
	var profile: Dictionary = _make_minimal_feature_profile()
	profile["schema_version"] = 1.5
	var rules: Array = GFVariantData.get_option_array(profile, "rules")
	rules.append({
		"id": "bucket",
		"kind": "bucket_size",
		"roots": ["scripts"],
		"max_files": 3.5,
		"severity": "warning",
	})
	profile["rules"] = rules
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()

	var validate_result: Dictionary = validator.validate_profile(profile, {
		"root_path": root_path,
		"allow_missing_root": true,
	})
	var scaffold_result: Dictionary = scaffolder.scaffold_profile(profile, {
		"root_path": root_path,
		"dry_run": true,
	})

	assert_false(GFVariantData.get_option_bool(validate_result, "success"), "validator 不得截断非整数 schema/limit。")
	assert_false(GFVariantData.get_option_bool(scaffold_result, "success"), "scaffolder 不得截断非整数 schema/limit。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(validate_result, "issues"), "invalid_integer_field"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(scaffold_result, "issues"), "invalid_integer_field"))


func test_project_layout_validator_rejects_non_integer_scan_budget() -> void:
	var root_path: String = _track_root("user://gf_project_layout_scan_budget_type_%d" % Time.get_ticks_usec())
	_make_directory(root_path)
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()

	var result: Dictionary = validator.validate_profile(_make_minimal_feature_profile(), {
		"root_path": root_path,
		"max_scanned_files": 1.5,
	})

	assert_false(GFVariantData.get_option_bool(result, "success"), "扫描预算必须是严格整数。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(result, "issues"), "invalid_integer_option"))


func test_project_layout_validator_rejects_linked_directory_traversal_when_supported() -> void:
	var root_path: String = _track_root("user://gf_project_layout_link_root_%d" % Time.get_ticks_usec())
	var outside_path: String = _track_root("user://gf_project_layout_link_outside_%d" % Time.get_ticks_usec())
	_make_directory(root_path)
	_make_directory(outside_path.path_join("nested"))
	_write_text(outside_path.path_join("nested/external.gd"), "extends RefCounted\n")
	var root_directory: DirAccess = DirAccess.open(ProjectSettings.globalize_path(root_path))
	assert_not_null(root_directory, "测试应能打开 link fixture 根目录。")
	if root_directory == null:
		return
	var link_error: Error = root_directory.create_link(
		ProjectSettings.globalize_path(outside_path),
		ProjectSettings.globalize_path(root_path.path_join("linked"))
	)
	if link_error != OK:
		return

	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var result: Dictionary = validator.validate_profile({
		"schema_version": 1,
		"id": "link_fixture",
		"zones": [],
		"rules": [],
	}, { "root_path": root_path })

	assert_false(GFVariantData.get_option_bool(result, "success"), "validator 不得跟随越过扫描根的链接目录。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(result, "issues"), "linked_path_not_allowed"))
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var scaffold_result: Dictionary = scaffolder.scaffold_profile({
		"schema_version": 1,
		"id": "link_scaffold_fixture",
		"zones": [{
			"id": "linked",
			"roots": ["linked/nested"],
			"required": true,
		}],
		"rules": [],
	}, {
		"root_path": root_path,
		"dry_run": true,
	})
	assert_false(GFVariantData.get_option_bool(scaffold_result, "success"), "scaffolder dry-run 也不得接受链接目标。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(scaffold_result, "issues"), "linked_path_not_allowed"))


func test_project_layout_validator_reports_forbidden_root_file_as_warning() -> void:
	var root_path: String = _track_root("user://gf_project_layout_validate_root_file_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var scaffold_result: Dictionary = scaffolder.scaffold_default_profile({ "root_path": root_path })
	_write_text(root_path.path_join("loose.gd"), "extends Node\n")

	var validate_result: Dictionary = validator.validate_default_profile({ "root_path": root_path })
	var issues: Array = GFVariantData.get_option_array(validate_result, "issues")

	assert_true(GFVariantData.get_option_bool(scaffold_result, "success"), "测试结构应先由脚手架创建成功。")
	assert_true(GFVariantData.get_option_bool(validate_result, "success"), "根文件规则是 warning，不应阻断整体校验。")
	assert_true(GFVariantData.get_option_int(validate_result, "warning_count") > 0, "未声明根文件应记录 warning。")
	assert_true(_has_issue_kind(issues, "forbidden_root_file"), "报告应明确 forbidden_root_file。")


func test_project_layout_validator_reports_missing_feature_scripts_subdir() -> void:
	var root_path: String = _track_root("user://gf_project_layout_validate_feature_%d" % Time.get_ticks_usec())
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	_make_directory(root_path.path_join("app"))
	_make_directory(root_path.path_join("features/inventory"))

	var validate_result: Dictionary = validator.validate_default_profile({ "root_path": root_path })
	var issues: Array = GFVariantData.get_option_array(validate_result, "issues")

	assert_false(GFVariantData.get_option_bool(validate_result, "success"), "缺少 Feature scripts 子目录应阻断校验。")
	assert_true(_has_issue_kind(issues, "missing_feature_subdir"), "报告应明确 missing_feature_subdir。")


func test_project_layout_validator_reports_generated_file_outside_generated_root() -> void:
	var root_path: String = _track_root("user://gf_project_layout_validate_generated_%d" % Time.get_ticks_usec())
	var scaffolder: GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT = GF_PROJECT_LAYOUT_SCAFFOLDER_SCRIPT.new()
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var scaffold_result: Dictionary = scaffolder.scaffold_default_profile({
		"root_path": root_path,
		"feature_ids": ["inventory"],
	})
	_write_text(root_path.path_join("features/inventory/scripts/items.generated.gd"), "extends RefCounted\n")

	var validate_result: Dictionary = validator.validate_default_profile({ "root_path": root_path })
	var issues: Array = GFVariantData.get_option_array(validate_result, "issues")

	assert_true(GFVariantData.get_option_bool(scaffold_result, "success"), "测试结构应先由脚手架创建成功。")
	assert_false(GFVariantData.get_option_bool(validate_result, "success"), "生成物泄漏到手写模块应阻断校验。")
	assert_true(_has_issue_kind(issues, "generated_path_outside_roots"), "报告应明确 generated_path_outside_roots。")


func test_project_layout_validator_glob_double_star_excludes_nested_generated_paths() -> void:
	var root_path: String = _track_root("user://gf_project_layout_glob_%d" % Time.get_ticks_usec())
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "glob_fixture",
		"zones": [],
		"rules": [{
			"id": "runtime_paths",
			"kind": "naming_convention",
			"roots": ["features"],
			"exclude": ["features/**/generated/**"],
			"pattern": "^[a-z0-9_./-]+$",
			"severity": "error",
		}],
	}
	_write_text(root_path.path_join("features/inventory/generated/BadName.gd"), "extends RefCounted\n")

	var result: Dictionary = validator.validate_profile(profile, { "root_path": root_path })
	var issues: Array = GFVariantData.get_option_array(result, "issues")

	assert_true(GFVariantData.get_option_bool(result, "success"), "双星 glob exclude 应匹配任意嵌套 generated 目录。")
	assert_false(_has_issue_kind(issues, "path_naming_mismatch"), "被 exclude 的 generated 路径不应进入命名校验。")


func test_project_layout_validator_reports_directory_scan_limit() -> void:
	var root_path: String = _track_root("user://gf_project_layout_scan_limit_%d" % Time.get_ticks_usec())
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "scan_limit_fixture",
		"zones": [],
		"rules": [],
	}
	_make_directory(root_path.path_join("a"))
	_make_directory(root_path.path_join("b"))

	var result: Dictionary = validator.validate_profile(profile, {
		"root_path": root_path,
		"max_scanned_directories": 1,
	})
	var issues: Array = GFVariantData.get_option_array(result, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "目录扫描不完整时不能报告项目结构有效。")
	assert_true(_has_issue_kind(issues, "scan_directory_limit_reached"), "目录数量上限应 fail closed。")


func test_project_layout_validator_fails_closed_when_file_scan_is_incomplete() -> void:
	var root_path: String = _track_root("user://gf_project_layout_file_scan_limit_%d" % Time.get_ticks_usec())
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "file_scan_limit_fixture",
		"zones": [],
		"rules": [],
	}
	_write_text(root_path.path_join("a.txt"), "a")
	_write_text(root_path.path_join("b.txt"), "b")

	var result: Dictionary = validator.validate_profile(profile, {
		"root_path": root_path,
		"max_scanned_files": 1,
	})
	var issues: Array = GFVariantData.get_option_array(result, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "文件扫描不完整时不能报告项目结构有效。")
	assert_true(_has_issue_kind(issues, "scan_file_limit_reached"), "文件数量上限应 fail closed。")


func _track_root(root_path: String) -> String:
	_temporary_roots.append(root_path)
	return root_path


func _make_minimal_feature_profile() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "minimal_feature_fixture",
		"zones": [],
		"rules": [{
			"id": "features",
			"kind": "feature_module_contract",
			"roots": ["features"],
			"feature_id_pattern": "^[a-z][a-z0-9_]*$",
			"required_subdirs": ["scripts"],
			"allowed_subdirs": ["scripts"],
			"severity": "error",
		}],
	}


func _make_directory(path: String) -> void:
	var create_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	assert_eq(create_result, OK, "测试应能创建项目结构目录。")


func _write_text(path: String, text: String) -> void:
	var create_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	assert_eq(create_result, OK, "测试应能创建文本文件目录。")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入文本文件。")
	if file == null:
		return
	var _store_string_result: bool = file.store_string(text)


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			if GFVariantData.get_option_string(issue, "kind") == kind:
				return true
	return false


func _has_operation_state(operations: Array, path: String, state: String) -> bool:
	for operation_value: Variant in operations:
		if not operation_value is Dictionary:
			continue
		var operation: Dictionary = operation_value
		if (
			GFVariantData.get_option_string(operation, "path") == path
			and GFVariantData.get_option_string(operation, "state") == state
		):
			return true
	return false


func _remove_directory_tree(root_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return

	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return

	var files: PackedStringArray = directory.get_files()
	for file_name: String in files:
		var _remove_file_result: Error = DirAccess.remove_absolute(absolute_path.path_join(file_name))

	var directories: PackedStringArray = directory.get_directories()
	for directory_name: String in directories:
		if directory.is_link(directory_name):
			var _remove_link_result: Error = DirAccess.remove_absolute(absolute_path.path_join(directory_name))
		else:
			_remove_directory_tree(root_path.path_join(directory_name))

	var _remove_dir_result: Error = DirAccess.remove_absolute(absolute_path)
