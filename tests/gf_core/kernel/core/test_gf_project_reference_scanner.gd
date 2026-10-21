## 测试 GFProjectReferenceScanner 的项目引用扫描契约。
extends GutTest

const SIDE_EFFECT_RESOURCE_SCRIPT = preload("res://tests/gf_core/kernel/core/fixtures/gf_reference_scan_side_effect_resource.gd")


class BinaryReferenceResource:
	extends Resource

	@export var dependency: Resource


# --- 测试用例 ---

## 显式选择不会撤销默认排除；调用者明确替换 ignored_roots 时才重新接纳 GF 文件。
func test_additional_files_preserve_default_ignored_roots_until_replaced() -> void:
	var path: String = "res://addons/gf/kernel/core/gf_project_reference_scanner.gd"
	var targets: Array[Dictionary] = [
		{ "id": "explicit.default", "root_path": "res://author/explicit_default", },
	]
	var options: Dictionary = {
		"scan_roots": [],
		"additional_scan_files": [path],
		"use_resource_dependencies": false,
	}
	var excluded: Dictionary = GFProjectReferenceScanner.scan_references(targets, options)
	options["ignored_roots"] = []
	var included: Dictionary = GFProjectReferenceScanner.scan_references(targets, options)
	assert_eq(
		_option_int(excluded, "candidate_file_count"),
		0
	)
	assert_eq(
		_option_int(excluded, "scanned_file_count"),
		0
	)
	assert_false(_option_bool(excluded, "partial_scan"))
	assert_eq(
		_option_array(
			_option_dictionary(excluded, "scope"),
			"additional_scan_files"
		),
		[path],
		"scope 保留真实请求，不能把被排除的请求伪装成从未选择。"
	)
	assert_eq(
		_option_int(included, "candidate_file_count"),
		1
	)
	assert_eq(
		_option_int(included, "scanned_file_count"),
		1
	)
	assert_false(_option_bool(included, "partial_scan"))
	assert_gt(
		_option_int(included, "scanned_bytes"),
		0
	)


## 追加排除按目录边界生效；相邻前缀、隐藏目录和原生 .gdignore 不撤销具体文件的显式选择。
func test_additional_files_preserve_appended_ignored_roots_and_path_boundaries() -> void:
	var directory: String = "user://gf_reference_extra_ignored_roots"
	var excluded_directory: String = directory.path_join("skip")
	var adjacent_directory: String = directory.path_join("skipped")
	var hidden_directory: String = directory.path_join(".hidden")
	var excluded_path: String = excluded_directory.path_join("denied.gd")
	var adjacent_path: String = adjacent_directory.path_join("allowed.gd")
	var hidden_path: String = hidden_directory.path_join("consumer.gd")
	var marker: String = adjacent_directory.path_join(".gdignore")
	var framework_path: String = "res://addons/gf/kernel/core/gf_project_reference_scanner.gd"
	var _made_excluded: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(excluded_directory))
	var _made_adjacent: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(adjacent_directory))
	var _made_hidden: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(hidden_directory))
	_write_text_file(excluded_path, "var excluded: ExplicitScopeType\n")
	_write_text_file(adjacent_path, "var included: ExplicitScopeType\n")
	_write_text_file(hidden_path, "var hidden: ExplicitScopeType\n")
	_write_text_file(marker, "")
	var requested: Array[String] = [
		framework_path,
		excluded_path,
		adjacent_path,
		hidden_path,
	]
	requested.sort()
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "explicit.appended",
				"root_path": "res://author/explicit_appended",
				"class_names": ["ExplicitScopeType"],
			},
		],
		{
			"scan_roots": [],
			"additional_ignored_roots": [excluded_directory],
			"additional_scan_files": requested,
			"respect_gdignore": true,
			"use_resource_dependencies": false,
		}
	)
	for path: String in [
		excluded_path,
		adjacent_path,
		hidden_path,
		marker,
	]:
		_remove_path_if_exists(path)
	_remove_path_if_exists(excluded_directory)
	_remove_path_if_exists(adjacent_directory)
	_remove_path_if_exists(hidden_directory)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		2
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		2
	)
	assert_eq(
		_option_int(report, "reference_count"),
		2
	)
	assert_false(_option_bool(report, "partial_scan"))
	assert_eq(
		_option_array(
			_option_dictionary(report, "scope"),
			"additional_scan_files"
		),
		requested,
		"请求列表保留默认排除、追加排除及实际扫描的全部文件。"
	)
	var references: Array = _option_array(report, "references")
	var reference_paths: Array[String] = []
	for index: int in range(references.size()):
		reference_paths.append(
			_option_string(
				_array_dictionary_at(references, index),
				"path"
			)
		)
	reference_paths.sort()
	assert_eq(
		reference_paths,
		[hidden_path, adjacent_path],
		"skip 不能误杀 skipped；具体文件的显式选择仍可越过隐藏目录和 .gdignore。"
	)


## 共同前缀只能否定类名候选；路径、无共同前缀、Unicode 与单类目标仍交给原有完整识别。
func test_class_prefix_filter_preserves_path_and_identifier_boundaries() -> void:
	var directory: String = "user://gf_reference_prefix_boundaries"
	var path: String = directory.path_join("references.gd")
	var _made_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "const Asset = preload(\"res://author/prefix/path/item.tres\")\nvar actual: ActualType\nvar unrelated: GFUnrelated\nvar suffix: GFAlphaSuffix\nvar unicode: 域乙\nvar single: SingleType\n")
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "path",
				"root_path": "res://author/prefix/path",
				"class_names": ["AbsentAlpha", "AbsentBeta"],
			},
			{
				"id": "no_common",
				"root_path": "res://author/prefix/no_common",
				"class_names": ["DifferentType", "ActualType"],
			},
			{
				"id": "prefix_only",
				"root_path": "res://author/prefix/prefix_only",
				"class_names": ["GFAlpha", "GFBeta"],
			},
			{
				"id": "unicode",
				"root_path": "res://author/prefix/unicode",
				"class_names": ["域甲", "域乙"],
			},
			{
				"id": "single",
				"root_path": "res://author/prefix/single",
				"class_names": ["SingleType"],
			},
			{
				"id": "empty",
				"root_path": "res://author/prefix/empty",
				"class_names": ["", ""],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": false,
		}
	)
	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(report, "reference_count"),
		4,
		"只应保留路径、无共同前缀、Unicode 与单类的真实强引用。"
	)
	assert_eq(
		_option_int(report, "weak_reference_count"),
		0,
		"前缀命中或标识符后缀碰撞不能产生弱证据。"
	)
	var targets: Dictionary = _option_dictionary(report, "targets")
	assert_eq(
		_option_int(
			_option_dictionary(targets, "path"),
			"reference_count"
		),
		1,
		"类名前缀完全缺失时仍必须先承认真实路径引用。"
	)
	assert_eq(
		_option_int(
			_option_dictionary(targets, "no_common"),
			"reference_count"
		),
		1,
		"空共同前缀不得跳过逐类查找。"
	)
	assert_eq(
		_option_int(
			_option_dictionary(targets, "unicode"),
			"reference_count"
		),
		1,
		"共同前缀按完整 Unicode 字符比较，不能按编码字节截断。"
	)
	assert_eq(
		_option_int(
			_option_dictionary(targets, "single"),
			"reference_count"
		),
		1,
		"单类的完整名称也是有效前缀。"
	)
	assert_true(
		_option_dictionary(targets, "prefix_only").is_empty(),
		"仅前缀和标识符后缀碰撞不算引用。"
	)
	assert_true(
		_option_dictionary(targets, "empty").is_empty(),
		"空类名不产生证据。"
	)
	assert_false(
		_option_bool(report, "partial_scan"),
		"前缀筛选不改变扫描覆盖状态。"
	)


## 空类名不影响共同前缀，注释与引号内的命中仍沿用原强弱证据规则。
func test_class_prefix_filter_preserves_empty_names_comments_and_quotes() -> void:
	var directory: String = "user://gf_reference_prefix_weak"
	var path: String = directory.path_join("quoted.gd")
	var _made_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "# PrefixAlpha\nvar text: String = \"PrefixBeta\"\n")
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "quoted",
				"root_path": "res://author/prefix/quoted",
				"class_names": [
					"",
					"PrefixAlpha",
					"PrefixBeta",
				],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": false,
		}
	)
	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(report, "reference_count"),
		0,
		"共同前缀出现不能把注释或字符串升级成强引用。"
	)
	assert_eq(
		_option_int(report, "weak_reference_count"),
		1,
		"注释仍被剔除，字符串中的完整类名仍保留为弱证据。"
	)
	var weak: Array = _option_array(report, "weak_references")
	if weak.size() == 1:
		assert_eq(
			_option_string(
				_array_dictionary_at(weak, 0),
				"symbol"
			),
			"PrefixBeta",
			"必须保留原文中的完整匹配类名。"
		)
	assert_true(
		_option_bool(report, "ok"),
		"只有弱证据的完整扫描不能阻断。"
	)


## 一次接纳在读盘前固定目标与范围，逐步完成与同步入口输出同一完整报告。
func test_incremental_session_captures_input_once_without_io() -> void:
	var scanner: GFProjectReferenceScanner = GFProjectReferenceScanner.new()
	assert_true(
		scanner.has_method("start"),
		"扫描器应提供同一实现的分步会话。"
	)
	if not scanner.has_method("start"):
		return
	var directory: String = "user://gf_reference_incremental_input"
	var path: String = directory.path_join("late.gd")
	var targets: Array[Dictionary] = [
		{
			"id": "captured",
			"root_path": "res://author/kept",
			"class_names": ["KeptType"],
		},
	]
	var options: Dictionary = {
		"scan_roots": [directory],
		"ignored_roots": [],
		"use_resource_dependencies": false,
	}
	var accepted: Variant = scanner.call(
		"start",
		targets,
		options
	)
	var request_accepted: bool = accepted is bool and accepted == true
	assert_true(request_accepted, "start 应接纳请求而不要求此时目录存在。")
	var progress: Dictionary = scanner.call("get_progress")
	assert_eq(
		_option_int(progress, "entries"),
		0,
		"start 不得枚举目录。"
	)
	assert_eq(
		_option_int(progress, "scanned_files"),
		0,
		"start 不得读文件。"
	)
	var empty_targets: Array[Dictionary] = []
	var repeated: Variant = scanner.call(
		"start",
		empty_targets,
		{}
	)
	var request_rejected: bool = repeated is bool and repeated == false
	assert_true(request_rejected, "重复 start 不得替换首个请求。")
	targets[0]["root_path"] = "res://author/replaced"
	options["scan_roots"] = ["user://not_this_scan"]
	var _make_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "var item: KeptType\n")
	var finished: bool = false
	for _index: int in range(1000):
		finished = scanner.call(
			"step",
			1,
			4000
		)
		if finished:
			break
	assert_true(finished, "有限夹具必须能在逐项调度下结束。")
	var report: Dictionary = scanner.call("take_result")
	var repeated_result: Dictionary = scanner.call("take_result")
	var expected: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "captured",
				"root_path": "res://author/kept",
				"class_names": ["KeptType"],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": false,
		}
	)
	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)
	assert_eq(
		report,
		expected,
		"分步与同步应交付相同报告，且调用者后续修改不得改变已接纳输入。"
	)
	assert_true(
		repeated_result.is_empty(),
		"完成结果只能领取一次。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		1,
		"保留最初的类名目标。"
	)


## 长脚本文本处理必须跨步骤推进，取消清理当前文件且不交付局部成功结果。
func test_incremental_session_yields_during_text_and_cancels_without_result() -> void:
	var scanner: GFProjectReferenceScanner = GFProjectReferenceScanner.new()
	assert_true(
		scanner.has_method("start"),
		"扫描器应提供可取消分步入口。"
	)
	if not scanner.has_method("start"):
		return
	var directory: String = "user://gf_reference_incremental_cancel"
	var path: String = directory.path_join("many_lines.gd")
	var _make_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		path,
		"# TargetType remains a weak comment\n".repeat(256)
	)
	var targets: Array[Dictionary] = [
		{
			"id": "target",
			"root_path": "res://author/target",
			"class_names": ["TargetType"],
		},
	]
	var _accepted: Variant = scanner.call(
		"start",
		targets,
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": false,
		}
	)
	var observed_partial_text: bool = false
	for _index: int in range(1000):
		var finished: bool = scanner.call(
			"step",
			1,
			4000
		)
		var progress: Dictionary = scanner.call("get_progress")
		var offset: int = _option_int(progress, "line_offset")
		var count: int = _option_int(progress, "line_count")
		if offset > 0 and offset < count:
			observed_partial_text = true
			break
		if finished:
			break
	assert_true(observed_partial_text, "不能把整个文本预处理与匹配都塞进一个 step。")
	var _cancelled: Variant = scanner.call("cancel")
	var final_progress: Dictionary = scanner.call("get_progress")
	var result: Dictionary = scanner.call("take_result")
	var terminal: bool = scanner.call(
		"step",
		1,
		4000
	)
	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)
	assert_true(
		_option_bool(final_progress, "finished"),
		"取消是终态。"
	)
	assert_true(
		_option_bool(final_progress, "cancelled"),
		"取消原因应可见。"
	)
	assert_true(terminal, "取消后 step 不得恢复扫描。")
	assert_true(
		result.is_empty(),
		"不得把取消时的局部报告交付为完成结果。"
	)
	assert_eq(
		_option_string(final_progress, "current_path"),
		"",
		"取消应释放当前文件状态。"
	)


## 原生忽略目录只定向补入已扫描资源所需文件；传递依赖、循环与共享文件预算仍可观察。
func test_respect_gdignore_follows_only_required_in_scope_dependency_files() -> void:
	var directory: String = "user://gf_reference_ignored_closure"
	var ignored: String = directory.path_join("ignored")
	var target_directory: String = "user://gf_reference_ignored_closure_target"
	var scene_path: String = directory.path_join("a.tscn")
	var first_path: String = ignored.path_join("b.tres")
	var second_path: String = ignored.path_join("d.tres")
	var unrelated_path: String = ignored.path_join("unrelated.gd")
	var target_path: String = target_directory.path_join("c.tres")
	var marker_path: String = ignored.path_join(".gdignore")
	var _make_ignored: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ignored))
	var _make_target: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_directory))
	_write_text_file(marker_path, "")
	_write_text_file(target_path, "[gd_resource type=\"Resource\" format=3]\n[resource]\n")
	_write_text_file(
		scene_path,
		'[gd_scene load_steps=2 format=3]\n[ext_resource type="Resource" path="%s" id="1"]\n[node name="Root" type="Node"]\nmetadata/next = ExtResource("1")\n' % first_path
	)
	_write_text_file(
		first_path,
		'[gd_resource type="Resource" load_steps=2 format=3]\n[ext_resource type="Resource" path="%s" id="1"]\n[resource]\nmetadata/next = ExtResource("1")\n' % second_path
	)
	_write_text_file(
		second_path,
		'[gd_resource type="Resource" load_steps=3 format=3]\n[ext_resource type="Resource" path="%s" id="1"]\n[ext_resource type="Resource" path="%s" id="2"]\n[resource]\nmetadata/next = ExtResource("1")\nmetadata/back = ExtResource("2")\n'
		% [target_path, first_path]
	)
	_write_text_file(
		unrelated_path,
		'const Unrelated = preload("%s")\n' % target_path
	)
	var targets: Array[Dictionary] = [
		{
			"id": "closure.target",
			"root_path": target_directory,
			"class_names": [],
		},
	]
	var options: Dictionary = {
		"scan_roots": [directory],
		"ignored_roots": [],
		"respect_gdignore": true,
	}
	var report: Dictionary = GFProjectReferenceScanner.scan_references(targets, options)
	var limited_options: Dictionary = options.duplicate(true)
	limited_options["max_scanned_files"] = 2
	var limited: Dictionary = GFProjectReferenceScanner.scan_references(targets, limited_options)
	for path: String in [
		scene_path,
		first_path,
		second_path,
		unrelated_path,
		target_path,
		marker_path,
	]:
		_remove_path_if_exists(path)
	_remove_path_if_exists(ignored)
	_remove_path_if_exists(directory)
	_remove_path_if_exists(target_directory)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		3,
		"只补入 b、d，不能遍历同目录 unrelated 或范围外目标。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		3,
		"循环依赖不得重复读文件。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		1,
		"传递依赖 d 必须揭示范围外目标引用。"
	)
	var references: Array = _option_array(report, "references")
	if references.size() == 1:
		assert_eq(
			_option_string(
				_array_dictionary_at(references, 0),
				"path"
			),
			second_path,
			"应报告真实传递引用来源。"
		)
	assert_false(
		_option_bool(report, "partial_scan"),
		"有意忽略的不相关目录不是覆盖故障。"
	)
	assert_true(
		_has_issue_code(limited, "max_scanned_files"),
		"必要依赖必须扣同一候选文件预算。"
	)
	assert_true(
		_option_bool(limited, "partial_scan"),
		"必要依赖预算不足必须失败关闭。"
	)
	assert_push_warning("[GFProjectReferenceScanner][project_reference_scanner.file_limit_reached] max_scanned_files=2 was reached; subsequent files were skipped.")


## 显式文件可以补入目录范围外，但与目录候选共享去重和读取预算。
func test_additional_scan_files_are_explicit_and_share_candidate_budget() -> void:
	var directory: String = "user://gf_reference_extra_scope"
	var extra_path: String = "user://gf_reference_explicit_extra.gd"
	var inside_path: String = directory.path_join("inside.gd")
	var _make_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(inside_path, "var unrelated: int = 1\n")
	_write_text_file(extra_path, "var explicit: ExplicitType\n")
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "explicit",
				"root_path": "res://author/explicit",
				"class_names": ["ExplicitType"],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"additional_scan_files": [
				extra_path,
				inside_path,
				extra_path,
			],
			"use_resource_dependencies": false,
		}
	)
	_remove_path_if_exists(inside_path)
	_remove_path_if_exists(extra_path)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		2,
		"显式文件与枚举文件应按规范路径共同去重。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		2,
		"显式范围外文件应实际扫描一次。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		1,
		"范围外显式文件不能被默默忽略。"
	)


## 混合显式导出清单只准入既有支持格式；纹理不读取、不占预算，也不制造部分扫描失败。
func test_unsupported_additional_files_follow_normal_candidate_type_boundary() -> void:
	var directory: String = "user://gf_reference_explicit_formats"
	var texture_path: String = directory.path_join("a.png")
	var script_path: String = directory.path_join("z.gd")
	var source: String = "var explicit: ExplicitType\n"
	var _made_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		texture_path,
		"unread texture fixture".repeat(256)
	)
	_write_text_file(script_path, source)
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "formats",
				"root_path": "res://author/formats",
				"class_names": ["ExplicitType"],
			},
		],
		{
			"scan_roots": [],
			"additional_scan_files": [texture_path, script_path],
			"max_scanned_files": 1,
			"max_file_bytes": 64,
			"max_total_bytes": 64,
			"use_resource_dependencies": false,
		}
	)
	_remove_path_if_exists(texture_path)
	_remove_path_if_exists(script_path)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		1,
		"不支持的显式格式不能消耗候选预算。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		1,
		"只读取可扫描脚本。"
	)
	assert_eq(
		_option_int(report, "scanned_bytes"),
		source.to_utf8_buffer().size(),
		"超过字节预算的纹理内容也不能被读取或计费。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		1,
		"合法脚本引用仍必须被发现。"
	)
	assert_false(
		_option_bool(report, "partial_scan"),
		"选择纹理是合法输入，不是扫描覆盖故障。"
	)
	assert_false(
		_option_bool(report, "budget_exceeded"),
		"不支持的格式不占读取预算。"
	)
	assert_eq(
		_option_int(report, "issue_count"),
		0,
		"不应增加 unsupported_scan_file 诊断。"
	)
	var scope: Dictionary = _option_dictionary(report, "scope")
	assert_eq(
		_option_array(scope, "additional_scan_files"),
		[texture_path, script_path],
		"范围字段保留规范化请求，而不是冒称两项都成功扫描。"
	)


## 显式扫描根位于忽略祖先下时仍应排除整根；明确选择的单文件可以绕过该原生目录排除。
func test_native_ignore_ancestor_applies_to_scan_roots_but_not_explicit_files() -> void:
	var directory: String = "user://gf_reference_ignored_ancestor"
	var child: String = directory.path_join("child")
	var path: String = child.path_join("selected.gd")
	var marker: String = directory.path_join(".gdignore")
	var _made_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(child))
	_write_text_file(marker, "")
	_write_text_file(path, "var selected: AncestorType\n")
	var targets: Array[Dictionary] = [
		{
			"id": "ancestor",
			"root_path": "res://author/ancestor",
			"class_names": ["AncestorType"],
		},
	]
	var options: Dictionary = {
		"scan_roots": [child],
		"ignored_roots": [],
		"respect_gdignore": true,
		"use_resource_dependencies": false,
	}
	var excluded: Dictionary = GFProjectReferenceScanner.scan_references(targets, options)
	options["additional_scan_files"] = [path]
	var selected: Dictionary = GFProjectReferenceScanner.scan_references(targets, options)
	_remove_path_if_exists(path)
	_remove_path_if_exists(marker)
	_remove_path_if_exists(child)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(excluded, "candidate_file_count"),
		0,
		"scan_roots 不得绕过祖先 .gdignore。"
	)
	var scope: Dictionary = _option_dictionary(excluded, "scope")
	assert_eq(
		_option_array(scope, "ignored_directories"),
		[directory],
		"报告应定位实际祖先标记所在目录。"
	)
	assert_eq(
		_option_int(selected, "reference_count"),
		1,
		"明确选择的文件仍必须扫描。"
	)
	assert_eq(
		_option_int(selected, "scanned_file_count"),
		1,
		"明确文件只扫描一次。"
	)
	assert_false(
		_option_bool(selected, "partial_scan"),
		"主动原生目录排除不应制造覆盖失败。"
	)


## 原生依赖闭包选择有效 UID 而不读取陈旧 fallback，并且不能反带回标准忽略根或原范围外文件。
func test_native_ignore_closure_prefers_uid_and_preserves_scope_exclusions() -> void:
	var directory: String = "user://gf_reference_uid_scope"
	var ignored: String = directory.path_join("native")
	var forbidden: String = directory.path_join("forbidden")
	var outside: String = "user://gf_reference_uid_outside"
	var target: String = "user://gf_reference_uid_target"
	var scene_path: String = directory.path_join("a.tscn")
	var required_path: String = ignored.path_join("b.tres")
	var stale_path: String = ignored.path_join("stale.tres")
	var forbidden_path: String = forbidden.path_join("c.tres")
	var outside_path: String = outside.path_join("d.tres")
	var target_path: String = target.path_join("target.tres")
	for path: String in [
		ignored,
		forbidden,
		outside,
		target,
	]:
		var _made_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	_write_text_file(
		ignored.path_join(".gdignore"),
		""
	)
	_write_text_file(
		forbidden.path_join(".gdignore"),
		""
	)
	_write_text_file(
		outside.path_join(".gdignore"),
		""
	)
	_write_text_file(target_path, "[gd_resource type=\"Resource\" format=3]\n[resource]\n")
	var dependency_source: String = '[gd_resource type="Resource" load_steps=2 format=3]\n[ext_resource type="Resource" path="%s" id="1"]\n[resource]\nmetadata/next = ExtResource("1")\n' % target_path
	_write_text_file(required_path, dependency_source)
	_write_text_file(forbidden_path, dependency_source)
	_write_text_file(outside_path, dependency_source)
	var resource_id: int = ResourceUID.create_id()
	ResourceUID.add_id(resource_id, required_path)
	var scene_source: String = (
		'[gd_scene load_steps=4 format=3]\n[ext_resource type="Resource" uid="%s" path="%s" id="1"]\n[ext_resource type="Resource" path="%s" id="2"]\n[ext_resource type="Resource" path="%s" id="3"]\n[node name="Root" type="Node"]\nmetadata/next = ExtResource("1")\nmetadata/forbidden = ExtResource("2")\nmetadata/outside = ExtResource("3")\n'
		% [
			ResourceUID.id_to_text(resource_id),
			stale_path,
			forbidden_path,
			outside_path,
		]
	)
	_write_text_file(scene_path, scene_source)
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "uid.scope",
				"root_path": target,
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [forbidden],
			"respect_gdignore": true,
		}
	)
	ResourceUID.remove_id(resource_id)
	for path: String in [
		scene_path,
		required_path,
		forbidden_path,
		outside_path,
		target_path,
		ignored.path_join(".gdignore"),
		forbidden.path_join(".gdignore"),
		outside.path_join(".gdignore"),
	]:
		_remove_path_if_exists(path)
	for path: String in [
		ignored,
		forbidden,
		outside,
		target,
		directory,
	]:
		_remove_path_if_exists(path)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		2,
		"只有场景和实际 UID 指向的必要文件可进入候选。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		2,
		"陈旧 fallback、标准忽略根和范围外依赖都不能被额外读取。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		1,
		"必要 UID 文件的下一层引用必须被发现。"
	)
	assert_false(
		_option_bool(report, "partial_scan"),
		"可用 UID 的陈旧 fallback 不应制造不可读文件错误。"
	)
	var scope: Dictionary = _option_dictionary(report, "scope")
	assert_eq(
		_option_array(scope, "dependency_files"),
		[required_path],
		"报告只列实际准入的必要文件。"
	)
	var references: Array = _option_array(report, "references")
	if references.size() == 1:
		assert_eq(
			_option_string(
				_array_dictionary_at(references, 0),
				"path"
			),
			required_path,
			"引用来源必须是实际读过的 UID 资源。"
		)


## 空闲、刚完成和已领取状态都不允许取消后交付报告，进度副本不得反向改写会话。
func test_incremental_session_terminal_boundaries_and_progress_are_isolated() -> void:
	var scanner: GFProjectReferenceScanner = GFProjectReferenceScanner.new()
	assert_false(
		scanner.step(0, 0),
		"空闲实例还不是完成请求。"
	)
	assert_true(
		scanner.take_result().is_empty(),
		"空闲实例不产生报告。"
	)
	var targets: Array[Dictionary] = []
	assert_true(
		scanner.start(targets),
		"空目标请求仍被一次性接纳。"
	)
	var progress: Dictionary = scanner.get_progress()
	assert_true(
		_option_bool(progress, "finished"),
		"空目标应同步进入完成状态。"
	)
	progress["phase"] = "tampered"
	assert_eq(
		_option_string(
			scanner.get_progress(),
			"phase"
		),
		"finished",
		"进度字典必须是隔离副本。"
	)
	scanner.cancel()
	scanner.cancel()
	assert_true(
		scanner.step(-1, -1),
		"取消是稳定终态。"
	)
	assert_true(
		scanner.take_result().is_empty(),
		"取消会清除尚未领取的完整结果。"
	)
	assert_false(
		scanner.start(targets),
		"取消后不能复用一次性实例。"
	)
	var idle: GFProjectReferenceScanner = GFProjectReferenceScanner.new()
	idle.cancel()
	assert_false(
		idle.start(targets),
		"空闲取消同样消费实例。"
	)
	assert_true(
		_option_bool(
			idle.get_progress(),
			"cancelled"
		),
		"空闲取消原因应可观察。"
	)


## 所有目标配额已截断后仍须读取后续资源并验证原生依赖，预过滤不改变失败覆盖。
func test_truncated_targets_still_check_later_dependency_failures() -> void:
	var directory: String = "user://gf_reference_truncated_coverage"
	var first_path: String = directory.path_join("a.gd")
	var broken_path: String = directory.path_join("z.tres")
	var _made_directory: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(first_path, "var first: FirstType\nvar second: SecondType\n")
	_write_text_file(broken_path, "this is not a resource header\n")
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "bounded",
				"root_path": "res://author/bounded",
				"class_names": ["FirstType", "SecondType"],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_target": 1,
		}
	)
	_remove_path_if_exists(first_path)
	_remove_path_if_exists(broken_path)
	_remove_path_if_exists(directory)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		2,
		"引用额度耗尽后不能跳过后续读盘覆盖。"
	)
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"无文本候选也必须检查损坏资源。"
	)
	assert_true(
		_has_issue_code(report, "max_references_per_target"),
		"保留原加一探测的配额诊断。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"后续损坏资源必须让报告失败关闭。"
	)


func test_scans_one_file_against_multiple_targets() -> void:
	var directory: String = "user://gf_project_reference_scanner_multi"
	var path: String = directory.path_join("references.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		path,
		"\n".join(['const First = preload("res://addons/author/first/runtime/tool.gd")', 'const Second = preload("res://addons/author/second/runtime/tool.gd")',])
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
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
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_target": 10,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	var targets: Dictionary = _option_dictionary(report, "targets")
	assert_false(
		_option_bool(report, "ok"),
		"存在 strong 引用时扫描报告应失败。"
	)
	assert_eq(
		_option_int(report, "input_target_count"),
		2,
		"扫描报告应保留目标数量。"
	)
	assert_eq(
		_option_int(report, "target_count"),
		2,
		"两个目标被引用时都应进入 target 报告。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		2,
		"单个文件内的两个目标引用都应被记录。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		1,
		"同一文件应只读取一次再匹配所有目标。"
	)
	assert_true(
		targets.has(&"author.first"),
		"报告应包含第一个目标。"
	)
	assert_true(
		targets.has(&"author.second"),
		"报告应包含第二个目标。"
	)


func test_uid_dependency_uses_res_fallback_for_verified_match() -> void:
	var directory: String = "user://gf_project_reference_scanner_uid_fallback"
	var path: String = directory.path_join("consumer.tscn")
	var target_root: String = "res://addons/gf/kernel/core"
	var scanner_path: String = target_root.path_join("gf_project_reference_scanner.gd")
	var scanner_uid: String = "uid://bjdi7hjnwrh9"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		path,
		"\n".join(
			[
				"[gd_scene load_steps=2 format=3]",
				"",
				'[ext_resource type="Script" uid="%s" path="%s" id="1_scanner"]'
				% [scanner_uid, scanner_path],
				"",
				'[node name="Root" type="Node"]',
				'metadata/scanner_script = ExtResource("1_scanner")',
			]
		)
	)
	var dependency_text: String = "\n".join(ResourceLoader.get_dependencies(path))
	assert_true(
		dependency_text.contains("uid://") and dependency_text.contains(scanner_path),
		"测试夹具必须暴露 UID 与 res:// fallback 的三段依赖记录。"
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "scanner.uid.target",
				"root_path": target_root,
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)
	var references: Array = _option_array(report, "references")

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_eq(
		references.size(),
		1,
		"UID dependency 的 fallback 路径应生成一条引用。"
	)
	if references.size() == 1:
		var reference: Dictionary = _array_dictionary_at(references, 0)
		assert_eq(
			_option_string(reference, "strength"),
			"verified",
			"UID fallback 应保留依赖图证据等级。"
		)
		assert_eq(
			_option_string(reference, "source"),
			"godot_dependency",
			"UID fallback 应记录依赖图来源。"
		)


func test_invalid_target_root_fails_closed_before_scanning() -> void:
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "invalid.target",
				"root_path": " ",
				"class_names": [],
			},
		],
		{
			"scan_roots": ["user://gf_project_reference_scanner_should_not_scan"],
			"ignored_roots": [],
		}
	)

	assert_false(
		_option_bool(report, "ok"),
		"无效 target root 不能产生可用于删除决策的成功报告。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"无效 target root 应标记 partial_scan。"
	)
	assert_eq(
		_option_int(report, "input_target_count"),
		1,
		"报告应保留原始 target 数量。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		0,
		"target 预检失败时不应开始扫描。"
	)
	assert_true(
		_has_issue_code(report, "invalid_target_root"),
		"报告应提供稳定的 invalid_target_root issue。"
	)


func test_scan_root_references_invalid_root_fails_closed() -> void:
	var report: Dictionary = GFProjectReferenceScanner.scan_root_references(
		" ",
		[],
		{
			"scan_roots": ["user://gf_project_reference_scanner_should_not_scan"],
			"ignored_roots": [],
		}
	)

	assert_false(
		_option_bool(report, "ok"),
		"单 root 便捷入口不能把无效 root 降级为空扫描成功。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"无效单 root 应标记 partial_scan。"
	)
	assert_eq(
		_option_int(report, "input_target_count"),
		1,
		"便捷入口应保留失败目标数量。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		0,
		"无效单 root 不应开始扫描。"
	)
	assert_true(
		_has_issue_code(report, "invalid_target_root"),
		"便捷入口应返回稳定 invalid_target_root issue。"
	)


func test_unreadable_scan_root_fails_closed_with_issue() -> void:
	var missing_root: String = "user://gf_project_reference_scanner_missing_root"
	_remove_path_if_exists(missing_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "valid.target",
				"root_path": "res://addons/author/target",
				"class_names": [],
			},
		],
		{
			"scan_roots": [missing_root],
			"ignored_roots": [],
		}
	)

	assert_false(
		_option_bool(report, "ok"),
		"无法读取 scan root 时必须 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"无法读取 scan root 时应标记 partial_scan。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		0,
		"无法打开目录时不应报告已扫描文件。"
	)
	assert_true(
		_has_issue_code(report, "scan_root_open_failed"),
		"报告应提供稳定的 scan_root_open_failed issue。"
	)


func test_empty_scan_root_fails_closed_with_issue() -> void:
	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "valid.target",
				"root_path": "res://addons/author/target",
				"class_names": [],
			},
		],
		{
			"scan_roots": [" "],
			"ignored_roots": [],
		}
	)

	assert_false(
		_option_bool(report, "ok"),
		"空 scan root 不能退化为成功的零候选扫描。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"空 scan root 应标记 partial_scan。"
	)
	assert_true(
		_has_issue_code(report, "invalid_scan_root"),
		"报告应提供稳定的 invalid_scan_root issue。"
	)


func test_unreadable_binary_resource_fails_closed_with_issue() -> void:
	var directory: String = "user://gf_project_reference_scanner_bad_binary"
	var path: String = directory.path_join("broken.res")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "not a Godot binary resource")

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "valid.target",
				"root_path": "res://addons/author/target",
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"无法解析二进制资源依赖时必须 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"无法解析二进制资源依赖时应标记 partial_scan。"
	)
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"报告应提供稳定的 resource_dependencies_unavailable issue。"
	)


func test_unloadable_text_resource_dependencies_fail_closed_with_issue() -> void:
	var directory: String = "user://gf_project_reference_scanner_bad_text_resource"
	var path: String = directory.path_join("broken.tscn")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "not a valid Godot text scene")

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "valid.target",
				"root_path": "res://addons/author/target",
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"无法解析文本资源依赖时必须 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"无法解析文本资源依赖时应标记 partial_scan。"
	)
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"报告应提供稳定的 resource_dependencies_unavailable issue。"
	)


func test_corrupted_resources_with_valid_headers_fail_closed() -> void:
	var directory: String = "user://gf_project_reference_scanner_corrupted_resources"
	var scene_path: String = directory.path_join("broken_body.tscn")
	var resource_path: String = directory.path_join("broken_body.tres")
	var binary_path: String = directory.path_join("broken_body.res")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(scene_path, "[gd_scene format=3]\n\n[node name=\"Broken\" type=\"Node\"\n")
	_write_text_file(resource_path, "[gd_resource type=\"Resource\" format=3]\n\n[resource\n")
	_write_text_file(binary_path, "RSRCcorrupted")

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "valid.target",
				"root_path": "res://addons/author/target",
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)

	_remove_path_if_exists(scene_path)
	_remove_path_if_exists(resource_path)
	_remove_path_if_exists(binary_path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"资源头合法但正文损坏时必须 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"正文解析失败应标记 partial_scan。"
	)
	assert_true(
		_has_issue_code(report, "resource_dependencies_unavailable"),
		"正文解析失败应提供稳定的 resource_dependencies_unavailable issue。"
	)


func test_dependency_scan_does_not_instantiate_custom_resource_scripts() -> void:
	var directory: String = "user://gf_project_reference_scanner_side_effect_resource"
	var resource_path: String = directory.path_join("side_effect.tres")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		resource_path,
		"\n".join(
			[
				'[gd_resource type="Resource" load_steps=2 format=3]',
				"",
				('[ext_resource type="Script" ' + 'path="res://tests/gf_core/kernel/core/fixtures/' + 'gf_reference_scan_side_effect_resource.gd" id="1_side_effect"]'),
				"",
				"[resource]",
				'script = ExtResource("1_side_effect")',
			]
		)
	)
	SIDE_EFFECT_RESOURCE_SCRIPT.reset_initialization_count()

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "unrelated.target",
				"root_path": "res://addons/author/unrelated",
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)
	var initialization_count: int = SIDE_EFFECT_RESOURCE_SCRIPT.get_initialization_count()

	_remove_path_if_exists(resource_path)
	_remove_path_if_exists(directory)

	assert_true(
		_option_bool(report, "ok"),
		"可读依赖元数据且无目标引用时扫描应成功。"
	)
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

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "author.first",
				"root_path": "res://addons/author/first",
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_file_bytes": 16,
			"max_total_bytes": 1024,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	var skipped_files: Array = _option_array(report, "skipped_files")
	assert_false(
		_option_bool(report, "ok"),
		"预算耗尽时不能把不完整扫描报告为 ok。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"预算耗尽应明确标记 partial_scan。"
	)
	assert_true(
		_option_bool(report, "budget_exceeded"),
		"单文件超限应进入 budget_exceeded。"
	)
	assert_true(
		_option_bool(report, "truncated"),
		"单文件读取预算超限应设置顶层 truncated。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		0,
		"未读取的文件不应产生伪引用。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		0,
		"超过单文件预算时不应读取正文。"
	)
	assert_eq(
		skipped_files.size(),
		1,
		"被预算跳过的文件应进入 skipped_files。"
	)
	assert_true(
		_has_issue_code(report, "max_file_bytes"),
		"报告应提供稳定的 max_file_bytes issue。"
	)
	assert_push_warning("[GFProjectReferenceScanner][project_reference_scanner.byte_budget_reached] Reference scanning reached the max_file_bytes=16 byte budget; subsequent results are treated as partial_scan: %s." % path)


func test_blocking_quota_does_not_downgrade_strong_reference_to_weak() -> void:
	var directory: String = "user://gf_project_reference_scanner_blocking_quota"
	var first_path: String = directory.path_join("a_first.gd")
	var second_path: String = directory.path_join("b_second.gd")
	var target_root: String = "res://addons/author/quota_target"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		first_path,
		'const First = preload("%s/first.gd")' % target_root
	)
	_write_text_file(
		second_path,
		'const Second = preload("%s/second.gd")' % target_root
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "quota.target",
				"root_path": target_root,
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_target": 1,
			"max_weak_references_per_target": 10,
			"include_weak_references": true,
		}
	)
	var targets: Dictionary = _option_dictionary(report, "targets")
	var target_report: Dictionary = _option_dictionary(targets, "quota.target")
	var weak_target_report: Dictionary = _option_dictionary(
		_option_dictionary(report, "weak_targets"),
		"quota.target"
	)

	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"blocking 配额截断不能产生成功报告。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"blocking 配额截断应标记 partial_scan。"
	)
	assert_true(
		_option_bool(report, "truncated"),
		"blocking 配额截断应设置顶层 truncated。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		1,
		"blocking 引用数量应受配额限制。"
	)
	assert_eq(
		_option_int(report, "weak_reference_count"),
		0,
		"超出 blocking 配额的强引用不得降级为 weak。"
	)
	assert_true(
		_has_issue_code(report, "max_references_per_target"),
		"报告应提供稳定的 max_references_per_target issue。"
	)
	assert_true(
		_option_bool(target_report, "truncated"),
		"受影响 target 应标记 truncated。"
	)
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
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		path,
		'const Only = preload("%s/only.gd")' % target_root
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "exact.quota.target",
				"root_path": target_root,
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_target": 1,
			"include_weak_references": true,
		}
	)
	var target_report: Dictionary = _option_dictionary(
		_option_dictionary(report, "targets"),
		"exact.quota.target"
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "partial_scan"),
		"blocking 引用数刚好达到配额时扫描仍是完整的。"
	)
	assert_false(
		_option_bool(report, "truncated"),
		"blocking 引用数刚好达到配额时不应标记 truncated。"
	)
	assert_false(
		_option_bool(target_report, "truncated"),
		"完整 target 结果不应标记 truncated。"
	)
	assert_false(
		_has_issue_code(report, "max_references_per_target"),
		"只有实际遇到额外 blocking 引用时才能记录配额 issue。"
	)


func test_weak_quota_overflow_marks_weak_target_truncated() -> void:
	var directory: String = "user://gf_project_reference_scanner_weak_quota"
	var first_path: String = directory.path_join("a_first.gd")
	var second_path: String = directory.path_join("b_second.gd")
	var target_root: String = "res://addons/author/weak_quota_target"
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		first_path,
		'var first_path: String = "%s/first.gd"' % target_root
	)
	_write_text_file(
		second_path,
		'var second_path: String = "%s/second.gd"' % target_root
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "weak.quota.target",
				"root_path": target_root,
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_target": 10,
			"max_weak_references_per_target": 1,
			"include_weak_references": true,
		}
	)
	var weak_target_report: Dictionary = _option_dictionary(
		_option_dictionary(report, "weak_targets"),
		"weak.quota.target"
	)

	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"weak 配额截断也必须 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"weak 配额截断应标记 partial_scan。"
	)
	assert_true(
		_option_bool(report, "truncated"),
		"weak 配额截断应设置顶层 truncated。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		0,
		"纯 weak 文本不应产生 blocking 引用。"
	)
	assert_eq(
		_option_int(report, "weak_reference_count"),
		1,
		"weak 引用数量应受配额限制。"
	)
	assert_true(
		_has_issue_code(report, "max_weak_references_per_target"),
		"报告应提供稳定的 max_weak_references_per_target issue。"
	)
	assert_true(
		_option_bool(weak_target_report, "truncated"),
		"受影响 weak target 应标记 truncated。"
	)
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
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(nested_directory))
	_write_text_file(
		nested_path,
		'const Nested = preload("%s/nested.gd")' % target_root
	)
	_write_text_file(
		root_path,
		'const Root = preload("%s/root.gd")' % target_root
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "stable.target",
				"root_path": target_root,
				"class_names": [],
			},
		],
		{
			"scan_roots": [nested_directory, directory],
			"ignored_roots": [],
			"max_scanned_files": 2,
			"include_weak_references": false,
		}
	)
	var references: Array = _option_array(report, "references")

	_remove_path_if_exists(nested_path)
	_remove_path_if_exists(root_path)
	_remove_path_if_exists(nested_directory)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "partial_scan"),
		"唯一文件数刚好达到上限时不应误报 partial_scan。"
	)
	assert_false(
		_option_bool(report, "truncated"),
		"唯一文件数刚好达到上限时不应误报 truncated。"
	)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		2,
		"重叠 scan root 应按规范路径去重候选文件。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		2,
		"每个唯一候选文件只能读取一次。"
	)
	assert_eq(
		references.size(),
		2,
		"两个唯一文件的强引用都应保留。"
	)
	if references.size() == 2:
		assert_eq(
			_option_string(
				_array_dictionary_at(references, 0),
				"path"
			),
			nested_path,
			"引用报告应按规范文件路径稳定排序。"
		)
		assert_eq(
			_option_string(
				_array_dictionary_at(references, 1),
				"path"
			),
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
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for index: int in range(paths.size()):
		_write_text_file(
			paths[index],
			'const Ref = preload("%s/%d.gd")'
			% [target_root, index]
		)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "file.limit.target",
				"root_path": target_root,
				"class_names": [],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_scanned_files": 2,
			"include_weak_references": false,
		}
	)

	for path: String in paths:
		_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"存在额外唯一候选文件时必须 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"存在额外唯一候选文件时应标记 partial_scan。"
	)
	assert_true(
		_option_bool(report, "truncated"),
		"存在额外唯一候选文件时应标记 truncated。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		2,
		"文件读取数量应受 max_scanned_files 限制。"
	)
	assert_true(
		_has_issue_code(report, "max_scanned_files"),
		"报告应提供稳定的 max_scanned_files issue。"
	)
	assert_push_warning("[GFProjectReferenceScanner][project_reference_scanner.file_limit_reached] max_scanned_files=2 was reached; subsequent files were skipped.")


func test_duplicate_target_id_fails_preflight_before_directory_read() -> void:
	var missing_root: String = "user://gf_project_reference_scanner_duplicate_should_not_scan"
	_remove_path_if_exists(missing_root)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
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
		],
		{
			"scan_roots": [missing_root],
			"ignored_roots": [],
		}
	)

	assert_false(
		_option_bool(report, "ok"),
		"duplicate target id 必须整体 fail closed。"
	)
	assert_true(
		_option_bool(report, "partial_scan"),
		"duplicate target id 应标记 partial_scan。"
	)
	assert_eq(
		_option_int(report, "input_target_count"),
		2,
		"报告应保留重复输入的原始 target 数量。"
	)
	assert_eq(
		_option_int(report, "candidate_file_count"),
		0,
		"duplicate target id 失败后不应枚举候选文件。"
	)
	assert_eq(
		_option_int(report, "scanned_file_count"),
		0,
		"duplicate target id 失败后不应读取文件。"
	)
	assert_true(
		_has_issue_code(report, "duplicate_target_id"),
		"报告应提供稳定的 duplicate_target_id issue。"
	)
	assert_false(
		_has_issue_code(report, "scan_root_open_failed"),
		"duplicate target id 必须在 scan root 读取前完成预检。"
	)
	assert_eq(
		_option_dictionary(report, "targets").size(),
		0,
		"预检失败不得产生覆盖后的 target 结果。"
	)


func test_weak_text_references_do_not_block_report() -> void:
	var directory: String = "user://gf_project_reference_scanner_weak"
	var path: String = directory.path_join("weak_text.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		path,
		"\n".join(
			[
				'# preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")',
				'var path_text: String = "res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd"',
				'var class_text: String = "GFSaveGraphUtility"',
			]
		)
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "gf.extension.save",
				"root_path": "res://addons/gf/extensions/save",
				"class_names": ["GFSaveGraphUtility"],
			},
		],
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"include_weak_references": true,
			"max_references_per_target": 10,
			"max_weak_references_per_target": 10,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_true(
		_option_bool(report, "ok"),
		"只有弱文本命中时扫描报告应保持 ok。"
	)
	assert_eq(
		_option_int(report, "reference_count"),
		0,
		"弱文本命中不应计入阻断引用。"
	)
	assert_eq(
		_option_int(report, "weak_reference_count"),
		2,
		"普通字符串路径和 class_name 应进入弱引用报告。"
	)


func test_binary_res_dependency_is_reported_as_verified_reference() -> void:
	var directory: String = "user://gf_project_reference_scanner_binary_res"
	var target_directory: String = directory.path_join("target")
	var consumer_directory: String = directory.path_join("consumer")
	var target_path: String = target_directory.path_join("target.res")
	var consumer_path: String = consumer_directory.path_join("consumer.res")
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_directory))
	var _make_consumer_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(consumer_directory))
	var target: Resource = Resource.new()
	assert_eq(
		ResourceSaver.save(target, target_path),
		OK,
		"测试应能保存目标二进制资源。"
	)
	var consumer: BinaryReferenceResource = BinaryReferenceResource.new()
	consumer.dependency = ResourceLoader.load(target_path)
	assert_not_null(consumer.dependency, "测试应能加载目标二进制资源。")
	assert_eq(
		ResourceSaver.save(consumer, consumer_path),
		OK,
		"测试应能保存引用目标的 .res。"
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "binary.res.target",
				"root_path": target_directory,
				"class_names": [],
			},
		],
		{
			"scan_roots": [consumer_directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)
	var references: Array = _option_array(report, "references")

	consumer.dependency = null
	_remove_path_if_exists(consumer_path)
	_remove_path_if_exists(target_path)
	_remove_path_if_exists(consumer_directory)
	_remove_path_if_exists(target_directory)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"二进制 .res 依赖必须阻断目标移除。"
	)
	assert_eq(
		references.size(),
		1,
		"二进制 .res 依赖应生成一条引用记录。"
	)
	if references.size() == 1:
		var reference: Dictionary = _array_dictionary_at(references, 0)
		assert_eq(
			_option_string(reference, "strength"),
			"verified",
			"二进制依赖应由 Godot 依赖图验证。"
		)
		assert_eq(
			_option_string(reference, "source"),
			"godot_dependency",
			"二进制依赖应记录依赖图来源。"
		)


func test_binary_scn_dependency_is_reported_as_verified_reference() -> void:
	var directory: String = "user://gf_project_reference_scanner_binary_scn"
	var target_directory: String = directory.path_join("target")
	var consumer_directory: String = directory.path_join("consumer")
	var target_path: String = target_directory.path_join("texture.res")
	var consumer_path: String = consumer_directory.path_join("consumer.scn")
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_directory))
	var _make_consumer_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(consumer_directory))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	assert_eq(
		ResourceSaver.save(texture, target_path),
		OK,
		"测试应能保存场景依赖纹理。"
	)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = ResourceLoader.load(target_path)
	assert_not_null(sprite.texture, "测试应能加载场景依赖纹理。")
	var packed_scene: PackedScene = PackedScene.new()
	assert_eq(
		packed_scene.pack(sprite),
		OK,
		"测试应能打包二进制场景。"
	)
	assert_eq(
		ResourceSaver.save(packed_scene, consumer_path),
		OK,
		"测试应能保存 .scn。"
	)

	var report: Dictionary = GFProjectReferenceScanner.scan_references(
		[
			{
				"id": "binary.scn.target",
				"root_path": target_directory,
				"class_names": [],
			},
		],
		{
			"scan_roots": [consumer_directory],
			"ignored_roots": [],
			"use_resource_dependencies": true,
		}
	)
	var references: Array = _option_array(report, "references")

	sprite.free()
	_remove_path_if_exists(consumer_path)
	_remove_path_if_exists(target_path)
	_remove_path_if_exists(consumer_directory)
	_remove_path_if_exists(target_directory)
	_remove_path_if_exists(directory)

	assert_false(
		_option_bool(report, "ok"),
		"二进制 .scn 依赖必须阻断目标移除。"
	)
	assert_eq(
		references.size(),
		1,
		"二进制 .scn 依赖应生成一条引用记录。"
	)
	if references.size() == 1:
		var reference: Dictionary = _array_dictionary_at(references, 0)
		assert_eq(
			_option_string(reference, "strength"),
			"verified",
			"二进制场景依赖应由 Godot 依赖图验证。"
		)
		assert_eq(
			_option_string(reference, "source"),
			"godot_dependency",
			"二进制场景依赖应记录依赖图来源。"
		)


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


func _option_bool(
	options: Dictionary,
	key: String,
	default_value: bool = false
) -> bool:
	if options.has(key) and options[key] is bool:
		var bool_value: bool = options[key]
		return bool_value
	return default_value


func _option_int(
	options: Dictionary,
	key: String,
	default_value: int = 0
) -> int:
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


func _option_string(
	options: Dictionary,
	key: String,
	default_value: String = ""
) -> String:
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
