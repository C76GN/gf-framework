## 测试 GFProjectReferenceScanner 的项目引用扫描契约。
extends GutTest


const SIDE_EFFECT_RESOURCE_SCRIPT = preload(
	"res://tests/gf_core/kernel/core/fixtures/gf_reference_scan_side_effect_resource.gd"
)


class BinaryReferenceResource:
	extends Resource

	@export var dependency: Resource


# --- 测试用例 ---

func test_scans_one_file_against_multiple_targets() -> void:
	var directory: String = "user://gf_project_reference_scanner_multi"
	var path: String = directory.path_join("references.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		'const First = preload("res://addons/author/first/runtime/tool.gd")',
		'const Second = preload("res://addons/author/second/runtime/tool.gd")',
	]))

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "author.first",
			"root_path": "res://addons/author/first",
			"class_names": [],
		},
		{
			"id": "author.second",
			"root_path": "res://addons/author/second",
			"class_names": [],
		},
	], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_references_per_target": 10,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	var targets: Dictionary = _option_dictionary(report, "targets")
	assert_false(_option_bool(report, "ok"), "存在 strong 引用时扫描报告应失败。")
	assert_eq(_option_int(report, "input_target_count"), 2, "扫描报告应保留目标数量。")
	assert_eq(_option_int(report, "target_count"), 2, "两个目标被引用时都应进入 target 报告。")
	assert_eq(_option_int(report, "reference_count"), 2, "单个文件内的两个目标引用都应被记录。")
	assert_eq(_option_int(report, "scanned_file_count"), 1, "同一文件应只读取一次再匹配所有目标。")
	assert_true(targets.has(&"author.first"), "报告应包含第一个目标。")
	assert_true(targets.has(&"author.second"), "报告应包含第二个目标。")


func test_uid_dependency_uses_res_fallback_for_verified_match() -> void:
	var directory: String = "user://gf_project_reference_scanner_uid_fallback"
	var path: String = directory.path_join("consumer.tscn")
	var target_root: String = "res://addons/gf/kernel/core"
	var scanner_path: String = target_root.path_join("gf_project_reference_scanner.gd")
	var scanner_uid: String = "uid://bjdi7hjnwrh9"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(path, "\n".join([
		"[gd_scene load_steps=2 format=3]",
		"",
		(
			'[ext_resource type="Script" uid="%s" path="%s" id="1_scanner"]'
			% [scanner_uid, scanner_path]
		),
		"",
		'[node name="Root" type="Node"]',
		'metadata/scanner_script = ExtResource("1_scanner")',
	]))
	var dependency_text: String = "\n".join(ResourceLoader.get_dependencies(path))
	assert_true(
		dependency_text.contains("uid://") and dependency_text.contains(scanner_path),
		"测试夹具必须暴露 UID 与 res:// fallback 的三段依赖记录。"
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "scanner.uid.target",
		"root_path": target_root,
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})
	var references: Array = _option_array(report, "references")

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_eq(references.size(), 1, "UID dependency 的 fallback 路径应生成一条引用。")
	if references.size() == 1:
		var reference: Dictionary = _array_dictionary_at(references, 0)
		assert_eq(_option_string(reference, "strength"), "verified", "UID fallback 应保留依赖图证据等级。")
		assert_eq(_option_string(reference, "source"), "godot_dependency", "UID fallback 应记录依赖图来源。")


func test_invalid_target_root_fails_closed_before_scanning() -> void:
	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "invalid.target",
		"root_path": " ",
		"class_names": [],
	}], {
		"scan_roots": ["user://gf_project_reference_scanner_should_not_scan"],
		"ignored_roots": [],
	})

	assert_false(_option_bool(report, "ok"), "无效 target root 不能产生可用于删除决策的成功报告。")
	assert_true(_option_bool(report, "partial_scan"), "无效 target root 应标记 partial_scan。")
	assert_eq(_option_int(report, "input_target_count"), 1, "报告应保留原始 target 数量。")
	assert_eq(_option_int(report, "scanned_file_count"), 0, "target 预检失败时不应开始扫描。")
	assert_true(_has_issue_code(report, "invalid_target_root"), "报告应提供稳定的 invalid_target_root issue。")


func test_scan_root_references_invalid_root_fails_closed() -> void:
	var report: Dictionary = GFProjectReferenceScanner.scan_root_references(
		" ",
		[],
		{
			"scan_roots": ["user://gf_project_reference_scanner_should_not_scan"],
			"ignored_roots": [],
		}
	)

	assert_false(_option_bool(report, "ok"), "单 root 便捷入口不能把无效 root 降级为空扫描成功。")
	assert_true(_option_bool(report, "partial_scan"), "无效单 root 应标记 partial_scan。")
	assert_eq(_option_int(report, "input_target_count"), 1, "便捷入口应保留失败目标数量。")
	assert_eq(_option_int(report, "scanned_file_count"), 0, "无效单 root 不应开始扫描。")
	assert_true(_has_issue_code(report, "invalid_target_root"), "便捷入口应返回稳定 invalid_target_root issue。")


func test_unreadable_scan_root_fails_closed_with_issue() -> void:
	var missing_root: String = "user://gf_project_reference_scanner_missing_root"
	_remove_path_if_exists(missing_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "valid.target",
		"root_path": "res://addons/author/target",
		"class_names": [],
	}], {
		"scan_roots": [missing_root],
		"ignored_roots": [],
	})

	assert_false(_option_bool(report, "ok"), "无法读取 scan root 时必须 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "无法读取 scan root 时应标记 partial_scan。")
	assert_eq(_option_int(report, "scanned_file_count"), 0, "无法打开目录时不应报告已扫描文件。")
	assert_true(_has_issue_code(report, "scan_root_open_failed"), "报告应提供稳定的 scan_root_open_failed issue。")


func test_empty_scan_root_fails_closed_with_issue() -> void:
	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "valid.target",
		"root_path": "res://addons/author/target",
		"class_names": [],
	}], {
		"scan_roots": [" "],
		"ignored_roots": [],
	})

	assert_false(_option_bool(report, "ok"), "空 scan root 不能退化为成功的零候选扫描。")
	assert_true(_option_bool(report, "partial_scan"), "空 scan root 应标记 partial_scan。")
	assert_true(_has_issue_code(report, "invalid_scan_root"), "报告应提供稳定的 invalid_scan_root issue。")


func test_unreadable_binary_resource_fails_closed_with_issue() -> void:
	var directory: String = "user://gf_project_reference_scanner_bad_binary"
	var path: String = directory.path_join("broken.res")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(path, "not a Godot binary resource")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "valid.target",
		"root_path": "res://addons/author/target",
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "无法解析二进制资源依赖时必须 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "无法解析二进制资源依赖时应标记 partial_scan。")
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"报告应提供稳定的 resource_dependencies_unavailable issue。"
	)


func test_unloadable_text_resource_dependencies_fail_closed_with_issue() -> void:
	var directory: String = "user://gf_project_reference_scanner_bad_text_resource"
	var path: String = directory.path_join("broken.tscn")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(path, "not a valid Godot text scene")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "valid.target",
		"root_path": "res://addons/author/target",
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "无法解析文本资源依赖时必须 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "无法解析文本资源依赖时应标记 partial_scan。")
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"报告应提供稳定的 resource_dependencies_unavailable issue。"
	)


func test_corrupted_resources_with_valid_headers_fail_closed() -> void:
	var directory: String = "user://gf_project_reference_scanner_corrupted_resources"
	var scene_path: String = directory.path_join("broken_body.tscn")
	var resource_path: String = directory.path_join("broken_body.tres")
	var binary_path: String = directory.path_join("broken_body.res")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(
		scene_path,
		"[gd_scene format=3]\n\n[node name=\"Broken\" type=\"Node\"\n"
	)
	_write_text_file(
		resource_path,
		"[gd_resource type=\"Resource\" format=3]\n\n[resource\n"
	)
	_write_text_file(binary_path, "RSRCcorrupted")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "valid.target",
		"root_path": "res://addons/author/target",
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})

	_remove_path_if_exists(scene_path)
	_remove_path_if_exists(resource_path)
	_remove_path_if_exists(binary_path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "资源头合法但正文损坏时必须 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "正文解析失败应标记 partial_scan。")
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"正文解析失败应提供稳定的 resource_dependencies_unavailable issue。"
	)


func test_dependency_scan_does_not_instantiate_custom_resource_scripts() -> void:
	var directory: String = "user://gf_project_reference_scanner_side_effect_resource"
	var resource_path: String = directory.path_join("side_effect.tres")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(resource_path, "\n".join([
		'[gd_resource type="Resource" load_steps=2 format=3]',
		"",
		(
			'[ext_resource type="Script" '
			+ 'path="res://tests/gf_core/kernel/core/fixtures/'
			+ 'gf_reference_scan_side_effect_resource.gd" id="1_side_effect"]'
		),
		"",
		"[resource]",
		'script = ExtResource("1_side_effect")',
	]))
	SIDE_EFFECT_RESOURCE_SCRIPT.reset_initialization_count()

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "unrelated.target",
		"root_path": "res://addons/author/unrelated",
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})
	var initialization_count: int = SIDE_EFFECT_RESOURCE_SCRIPT.get_initialization_count()

	_remove_path_if_exists(resource_path)
	_remove_path_if_exists(directory)

	assert_true(_option_bool(report, "ok"), "可读依赖元数据且无目标引用时扫描应成功。")
	assert_eq(
		initialization_count,
		0,
		"引用扫描只能读取依赖元数据，不得实例化自定义 Resource 或执行 _init()。"
	)


func test_budget_exceeded_returns_partial_fail_closed_report() -> void:
	var directory: String = "user://gf_project_reference_scanner_budget"
	var path: String = directory.path_join("large_reference.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, 'const First = preload("res://addons/author/first/runtime/tool.gd")')

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "author.first",
			"root_path": "res://addons/author/first",
			"class_names": [],
		},
	], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_file_bytes": 16,
		"max_total_bytes": 1024,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	var skipped_files: Array = _option_array(report, "skipped_files")
	assert_false(_option_bool(report, "ok"), "预算耗尽时不能把不完整扫描报告为 ok。")
	assert_true(_option_bool(report, "partial_scan"), "预算耗尽应明确标记 partial_scan。")
	assert_true(_option_bool(report, "budget_exceeded"), "单文件超限应进入 budget_exceeded。")
	assert_true(_option_bool(report, "truncated"), "单文件读取预算超限应设置顶层 truncated。")
	assert_eq(_option_int(report, "reference_count"), 0, "未读取的文件不应产生伪引用。")
	assert_eq(_option_int(report, "scanned_file_count"), 0, "超过单文件预算时不应读取正文。")
	assert_eq(skipped_files.size(), 1, "被预算跳过的文件应进入 skipped_files。")
	assert_true(_has_issue_code(report, "max_file_bytes"), "报告应提供稳定的 max_file_bytes issue。")
	assert_push_warning("[GFProjectReferenceScanner] 引用扫描达到 max_file_bytes=16 字节预算，后续结果按 partial_scan 处理：%s。" % path)


func test_blocking_quota_does_not_downgrade_strong_reference_to_weak() -> void:
	var directory: String = "user://gf_project_reference_scanner_blocking_quota"
	var first_path: String = directory.path_join("a_first.gd")
	var second_path: String = directory.path_join("b_second.gd")
	var target_root: String = "res://addons/author/quota_target"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(first_path, 'const First = preload("%s/first.gd")' % target_root)
	_write_text_file(second_path, 'const Second = preload("%s/second.gd")' % target_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "quota.target",
		"root_path": target_root,
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_references_per_target": 1,
		"max_weak_references_per_target": 10,
		"include_weak_references": true,
	})
	var targets: Dictionary = _option_dictionary(report, "targets")
	var target_report: Dictionary = _option_dictionary(targets, "quota.target")
	var weak_target_report: Dictionary = _option_dictionary(
		_option_dictionary(report, "weak_targets"),
		"quota.target"
	)

	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "blocking 配额截断不能产生成功报告。")
	assert_true(_option_bool(report, "partial_scan"), "blocking 配额截断应标记 partial_scan。")
	assert_true(_option_bool(report, "truncated"), "blocking 配额截断应设置顶层 truncated。")
	assert_eq(_option_int(report, "reference_count"), 1, "blocking 引用数量应受配额限制。")
	assert_eq(_option_int(report, "weak_reference_count"), 0, "超出 blocking 配额的强引用不得降级为 weak。")
	assert_true(
		_has_issue_code(report, "max_references_per_target"),
		"报告应提供稳定的 max_references_per_target issue。"
	)
	assert_true(_option_bool(target_report, "truncated"), "受影响 target 应标记 truncated。")
	assert_eq(
		_option_string(target_report, "truncation_reason"),
		"max_references_per_target",
		"受影响 target 应说明 blocking 配额截断原因。"
	)
	assert_true(
		_option_bool(weak_target_report, "truncated"),
		"blocking 截断会停止后续 weak 扫描，weak target 也必须标记不完整。"
	)
	assert_eq(
		_option_string(weak_target_report, "truncation_reason"),
		"max_references_per_target",
		"weak target 应说明是 blocking 配额导致扫描提前停止。"
	)


func test_exact_blocking_quota_is_not_reported_as_truncated() -> void:
	var directory: String = "user://gf_project_reference_scanner_exact_blocking_quota"
	var path: String = directory.path_join("only_reference.gd")
	var target_root: String = "res://addons/author/exact_quota_target"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(path, 'const Only = preload("%s/only.gd")' % target_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "exact.quota.target",
		"root_path": target_root,
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_references_per_target": 1,
		"include_weak_references": true,
	})
	var target_report: Dictionary = _option_dictionary(
		_option_dictionary(report, "targets"),
		"exact.quota.target"
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "partial_scan"), "blocking 引用数刚好达到配额时扫描仍是完整的。")
	assert_false(_option_bool(report, "truncated"), "blocking 引用数刚好达到配额时不应标记 truncated。")
	assert_false(_option_bool(target_report, "truncated"), "完整 target 结果不应标记 truncated。")
	assert_false(
		_has_issue_code(report, "max_references_per_target"),
		"只有实际遇到额外 blocking 引用时才能记录配额 issue。"
	)


func test_weak_quota_overflow_marks_weak_target_truncated() -> void:
	var directory: String = "user://gf_project_reference_scanner_weak_quota"
	var first_path: String = directory.path_join("a_first.gd")
	var second_path: String = directory.path_join("b_second.gd")
	var target_root: String = "res://addons/author/weak_quota_target"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	_write_text_file(first_path, 'var first_path: String = "%s/first.gd"' % target_root)
	_write_text_file(second_path, 'var second_path: String = "%s/second.gd"' % target_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "weak.quota.target",
		"root_path": target_root,
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_references_per_target": 10,
		"max_weak_references_per_target": 1,
		"include_weak_references": true,
	})
	var weak_target_report: Dictionary = _option_dictionary(
		_option_dictionary(report, "weak_targets"),
		"weak.quota.target"
	)

	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "weak 配额截断也必须 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "weak 配额截断应标记 partial_scan。")
	assert_true(_option_bool(report, "truncated"), "weak 配额截断应设置顶层 truncated。")
	assert_eq(_option_int(report, "reference_count"), 0, "纯 weak 文本不应产生 blocking 引用。")
	assert_eq(_option_int(report, "weak_reference_count"), 1, "weak 引用数量应受配额限制。")
	assert_true(
		_has_issue_code(report, "max_weak_references_per_target"),
		"报告应提供稳定的 max_weak_references_per_target issue。"
	)
	assert_true(_option_bool(weak_target_report, "truncated"), "受影响 weak target 应标记 truncated。")
	assert_eq(
		_option_string(weak_target_report, "truncation_reason"),
		"max_weak_references_per_target",
		"受影响 weak target 应说明配额截断原因。"
	)


func test_overlapping_roots_are_deduplicated_sorted_and_not_falsely_truncated() -> void:
	var directory: String = "user://gf_project_reference_scanner_stable_files"
	var nested_directory: String = directory.path_join("nested")
	var nested_path: String = nested_directory.path_join("a_nested.gd")
	var root_path: String = directory.path_join("z_root.gd")
	var target_root: String = "res://addons/author/stable_target"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(nested_directory)
	)
	_write_text_file(nested_path, 'const Nested = preload("%s/nested.gd")' % target_root)
	_write_text_file(root_path, 'const Root = preload("%s/root.gd")' % target_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "stable.target",
		"root_path": target_root,
		"class_names": [],
	}], {
		"scan_roots": [nested_directory, directory],
		"ignored_roots": [],
		"max_scanned_files": 2,
		"include_weak_references": false,
	})
	var references: Array = _option_array(report, "references")

	_remove_path_if_exists(nested_path)
	_remove_path_if_exists(root_path)
	_remove_path_if_exists(nested_directory)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "partial_scan"), "唯一文件数刚好达到上限时不应误报 partial_scan。")
	assert_false(_option_bool(report, "truncated"), "唯一文件数刚好达到上限时不应误报 truncated。")
	assert_eq(_option_int(report, "candidate_file_count"), 2, "重叠 scan root 应按规范路径去重候选文件。")
	assert_eq(_option_int(report, "scanned_file_count"), 2, "每个唯一候选文件只能读取一次。")
	assert_eq(references.size(), 2, "两个唯一文件的强引用都应保留。")
	if references.size() == 2:
		assert_eq(
			_option_string(_array_dictionary_at(references, 0), "path"),
			nested_path,
			"引用报告应按规范文件路径稳定排序。"
		)
		assert_eq(
			_option_string(_array_dictionary_at(references, 1), "path"),
			root_path,
			"引用报告应按规范文件路径稳定排序。"
		)


func test_extra_unique_file_marks_file_collection_truncated() -> void:
	var directory: String = "user://gf_project_reference_scanner_file_limit"
	var target_root: String = "res://addons/author/file_limit_target"
	var paths: Array[String] = [
		directory.path_join("a_first.gd"),
		directory.path_join("b_second.gd"),
		directory.path_join("c_third.gd"),
	]
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	for index: int in range(paths.size()):
		_write_text_file(paths[index], 'const Ref = preload("%s/%d.gd")' % [target_root, index])

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "file.limit.target",
		"root_path": target_root,
		"class_names": [],
	}], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_scanned_files": 2,
		"include_weak_references": false,
	})

	for path: String in paths:
		_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "存在额外唯一候选文件时必须 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "存在额外唯一候选文件时应标记 partial_scan。")
	assert_true(_option_bool(report, "truncated"), "存在额外唯一候选文件时应标记 truncated。")
	assert_eq(_option_int(report, "scanned_file_count"), 2, "文件读取数量应受 max_scanned_files 限制。")
	assert_true(_has_issue_code(report, "max_scanned_files"), "报告应提供稳定的 max_scanned_files issue。")
	assert_push_warning("[GFProjectReferenceScanner] 已达到 max_scanned_files=2，后续文件已跳过。")


func test_duplicate_target_id_fails_preflight_before_directory_read() -> void:
	var missing_root: String = "user://gf_project_reference_scanner_duplicate_should_not_scan"
	_remove_path_if_exists(missing_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "duplicate.target",
			"root_path": "res://addons/author/first",
			"class_names": [],
		},
		{
			"id": "duplicate.target",
			"root_path": "res://addons/author/second",
			"class_names": [],
		},
	], {
		"scan_roots": [missing_root],
		"ignored_roots": [],
	})

	assert_false(_option_bool(report, "ok"), "duplicate target id 必须整体 fail closed。")
	assert_true(_option_bool(report, "partial_scan"), "duplicate target id 应标记 partial_scan。")
	assert_eq(_option_int(report, "input_target_count"), 2, "报告应保留重复输入的原始 target 数量。")
	assert_eq(_option_int(report, "candidate_file_count"), 0, "duplicate target id 失败后不应枚举候选文件。")
	assert_eq(_option_int(report, "scanned_file_count"), 0, "duplicate target id 失败后不应读取文件。")
	assert_true(_has_issue_code(report, "duplicate_target_id"), "报告应提供稳定的 duplicate_target_id issue。")
	assert_false(
		_has_issue_code(report, "scan_root_open_failed"),
		"duplicate target id 必须在 scan root 读取前完成预检。"
	)
	assert_eq(_option_dictionary(report, "targets").size(), 0, "预检失败不得产生覆盖后的 target 结果。")


func test_weak_text_references_do_not_block_report() -> void:
	var directory: String = "user://gf_project_reference_scanner_weak"
	var path: String = directory.path_join("weak_text.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		'# preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")',
		'var path_text: String = "res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd"',
		'var class_text: String = "GFSaveGraphUtility"',
	]))

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "gf.extension.save",
			"root_path": "res://addons/gf/extensions/save",
			"class_names": ["GFSaveGraphUtility"],
		},
	], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"include_weak_references": true,
		"max_references_per_target": 10,
		"max_weak_references_per_target": 10,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_true(_option_bool(report, "ok"), "只有弱文本命中时扫描报告应保持 ok。")
	assert_eq(_option_int(report, "reference_count"), 0, "弱文本命中不应计入阻断引用。")
	assert_eq(_option_int(report, "weak_reference_count"), 2, "普通字符串路径和 class_name 应进入弱引用报告。")


func test_binary_res_dependency_is_reported_as_verified_reference() -> void:
	var directory: String = "user://gf_project_reference_scanner_binary_res"
	var target_directory: String = directory.path_join("target")
	var consumer_directory: String = directory.path_join("consumer")
	var target_path: String = target_directory.path_join("target.res")
	var consumer_path: String = consumer_directory.path_join("consumer.res")
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_directory)
	)
	var _make_consumer_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(consumer_directory)
	)
	var target: Resource = Resource.new()
	assert_eq(ResourceSaver.save(target, target_path), OK, "测试应能保存目标二进制资源。")
	var consumer: BinaryReferenceResource = BinaryReferenceResource.new()
	consumer.dependency = ResourceLoader.load(target_path)
	assert_not_null(consumer.dependency, "测试应能加载目标二进制资源。")
	assert_eq(ResourceSaver.save(consumer, consumer_path), OK, "测试应能保存引用目标的 .res。")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "binary.res.target",
		"root_path": target_directory,
		"class_names": [],
	}], {
		"scan_roots": [consumer_directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})
	var references: Array = _option_array(report, "references")

	consumer.dependency = null
	_remove_path_if_exists(consumer_path)
	_remove_path_if_exists(target_path)
	_remove_path_if_exists(consumer_directory)
	_remove_path_if_exists(target_directory)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "二进制 .res 依赖必须阻断目标移除。")
	assert_eq(references.size(), 1, "二进制 .res 依赖应生成一条引用记录。")
	if references.size() == 1:
		var reference: Dictionary = _array_dictionary_at(references, 0)
		assert_eq(_option_string(reference, "strength"), "verified", "二进制依赖应由 Godot 依赖图验证。")
		assert_eq(_option_string(reference, "source"), "godot_dependency", "二进制依赖应记录依赖图来源。")


func test_binary_scn_dependency_is_reported_as_verified_reference() -> void:
	var directory: String = "user://gf_project_reference_scanner_binary_scn"
	var target_directory: String = directory.path_join("target")
	var consumer_directory: String = directory.path_join("consumer")
	var target_path: String = target_directory.path_join("texture.res")
	var consumer_path: String = consumer_directory.path_join("consumer.scn")
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_directory)
	)
	var _make_consumer_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(consumer_directory)
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	assert_eq(ResourceSaver.save(texture, target_path), OK, "测试应能保存场景依赖纹理。")
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = ResourceLoader.load(target_path)
	assert_not_null(sprite.texture, "测试应能加载场景依赖纹理。")
	var packed_scene: PackedScene = PackedScene.new()
	assert_eq(packed_scene.pack(sprite), OK, "测试应能打包二进制场景。")
	assert_eq(ResourceSaver.save(packed_scene, consumer_path), OK, "测试应能保存 .scn。")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "binary.scn.target",
		"root_path": target_directory,
		"class_names": [],
	}], {
		"scan_roots": [consumer_directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})
	var references: Array = _option_array(report, "references")

	sprite.free()
	_remove_path_if_exists(consumer_path)
	_remove_path_if_exists(target_path)
	_remove_path_if_exists(consumer_directory)
	_remove_path_if_exists(target_directory)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "二进制 .scn 依赖必须阻断目标移除。")
	assert_eq(references.size(), 1, "二进制 .scn 依赖应生成一条引用记录。")
	if references.size() == 1:
		var reference: Dictionary = _array_dictionary_at(references, 0)
		assert_eq(_option_string(reference, "strength"), "verified", "二进制场景依赖应由 Godot 依赖图验证。")
		assert_eq(_option_string(reference, "source"), "godot_dependency", "二进制场景依赖应记录依赖图来源。")


# --- 私有/辅助方法 ---

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


func _option_bool(options: Dictionary, key: String, default_value: bool = false) -> bool:
	if options.has(key) and options[key] is bool:
		var bool_value: bool = options[key]
		return bool_value
	return default_value


func _option_int(options: Dictionary, key: String, default_value: int = 0) -> int:
	if options.has(key) and options[key] is int:
		var int_value: int = options[key]
		return int_value
	return default_value


func _option_array(options: Dictionary, key: String) -> Array:
	if options.has(key) and options[key] is Array:
		var array_value: Array = options[key]
		return array_value
	return []


func _option_dictionary(options: Dictionary, key: String) -> Dictionary:
	if options.has(key) and options[key] is Dictionary:
		var dictionary_value: Dictionary = options[key]
		return dictionary_value
	return {}


func _array_dictionary_at(values: Array, index: int) -> Dictionary:
	if index < 0 or index >= values.size():
		return {}
	var value: Variant = values[index]
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _option_string(options: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = options.get(key)
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return default_value


func _has_issue_code(report: Dictionary, expected_code: String) -> bool:
	for issue_value: Variant in _option_array(report, "issues"):
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if _option_string(issue, "code") == expected_code:
			return true
	return false
