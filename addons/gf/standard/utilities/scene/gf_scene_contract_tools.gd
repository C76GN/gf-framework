@tool

## GFSceneContractTools: 通用场景根节点契约检查工具。
##
## 用于编辑器工具、导入预检、CI 和测试在加载场景后检查根节点的通用形状。
## 它只验证调用方显式声明的类型、脚本继承、分组、名称和路径约束，
## 不约定实体/组件目录、玩法字段或项目生命周期方法。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFSceneContractTools
extends RefCounted


# --- 常量 ---

## 默认场景扩展名白名单，不包含点号。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCENE_EXTENSIONS: PackedStringArray = ["tscn", "scn"]

## 契约字段：根节点必须是该 Godot 类或其子类。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_BASE_CLASS: StringName = &"base_class"

## 契约字段：根节点脚本必须等于或继承该脚本。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_BASE_SCRIPT: StringName = &"base_script"

## 契约字段：根节点必须属于的分组列表。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_REQUIRED_GROUPS: StringName = &"required_groups"

## 契约字段：根节点不能属于的分组列表。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_FORBIDDEN_GROUPS: StringName = &"forbidden_groups"

## 契约字段：根节点名称前缀。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_NAME_PREFIX: StringName = &"name_prefix"

## 契约字段：根节点名称后缀。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_NAME_SUFFIX: StringName = &"name_suffix"

## 契约字段：场景路径前缀。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_PATH_PREFIX: StringName = &"path_prefix"

## 契约字段：场景路径后缀。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_PATH_SUFFIX: StringName = &"path_suffix"

## 契约字段：传给 GFScriptStructureTools.check_script_structure() 的根脚本结构声明。
## [br]
## @api public
## [br]
## @since 8.0.0
const KEY_SCRIPT_STRUCTURE: StringName = &"script_structure"


# --- 公共方法 ---

## 扫描场景路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_path: 扫描起点，通常是 res:// 下的目录。
## [br]
## @param options: 可选项，支持 GFResourceRegistryTools.scan_resource_paths() 的扫描选项；extensions 默认固定为 tscn/scn。
## [br]
## @schema options: Dictionary，可包含 recursive、include_addons、excluded_paths、include_patterns、
## exclude_patterns、pattern_base_path、include_hidden、max_scan_depth、max_resource_paths 和 extensions 字段。
## [br]
## @return 排序后的场景路径。
static func scan_scene_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
	var scan_options: Dictionary = GFVariantData.to_dictionary(options)
	if not scan_options.has("extensions") and not scan_options.has(&"extensions"):
		scan_options["extensions"] = SCENE_EXTENSIONS
	return GFResourceRegistryTools.scan_resource_paths(root_path, scan_options)


## 检查一个已存在的场景根节点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root: 场景根节点。
## [br]
## @param contract: 契约声明，可包含 base_class、base_script、required_groups、forbidden_groups、
## name_prefix、name_suffix、path_prefix、path_suffix 和 script_structure。
## [br]
## @schema contract: Dictionary scene root contract fields.
## [br]
## @param options: 可选项，支持 scene_path、subject 和 script_structure_options。
## [br]
## @schema options: Dictionary scene contract check options.
## [br]
## @return 检查报告。
## [br]
## @schema return: Dictionary，包含 ok、scene_path、root_name、root_class、root_script_path、issues、counts 与 summary 字段。
static func check_node(root: Node, contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var scene_path: String = GFVariantData.get_option_string(options, "scene_path")
	var report: Dictionary = _make_report(
		GFVariantData.get_option_string(options, "subject", "Scene root contract"),
		scene_path
	)
	if root == null:
		_append_issue(report, "error", "invalid_root", "root", "Node", "", "Scene root is null.")
		return _finalize_report(report)

	report["root_name"] = String(root.name)
	report["root_class"] = root.get_class()
	report["root_script_path"] = _get_root_script_path(root)

	_check_base_class(report, root, contract)
	_check_base_script(report, root, contract)
	_check_required_groups(report, root, contract)
	_check_forbidden_groups(report, root, contract)
	_check_name_constraints(report, root, contract)
	_check_path_constraints(report, contract, scene_path)
	_check_script_structure(report, root, contract, options)
	return _finalize_report(report)


## 实例化 PackedScene 并检查根节点契约。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param packed_scene: 待检查场景。
## [br]
## @param contract: 契约声明。
## [br]
## @schema contract: Dictionary scene root contract fields.
## [br]
## @param options: 可选项，支持 scene_path、subject、free_instance、gen_edit_state 和 script_structure_options。
## [br]
## @schema options: Dictionary packed scene contract check options.
## [br]
## @return 检查报告。
## [br]
## @schema return: Dictionary，包含 ok、scene_path、root_name、root_class、root_script_path、issues、counts 与 summary 字段。
static func check_packed_scene(
	packed_scene: PackedScene,
	contract: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var scene_path: String = GFVariantData.get_option_string(options, "scene_path")
	var report: Dictionary = _make_report(
		GFVariantData.get_option_string(options, "subject", "PackedScene contract"),
		scene_path
	)
	if packed_scene == null:
		_append_issue(report, "error", "invalid_packed_scene", "packed_scene", "PackedScene", "", "PackedScene is null.")
		return _finalize_report(report)

	var edit_state: int = GFVariantData.get_option_int(
		options,
		"gen_edit_state",
		PackedScene.GEN_EDIT_STATE_DISABLED
	)
	var root: Node = packed_scene.instantiate(edit_state)
	if root == null:
		_append_issue(
			report,
			"error",
			"scene_instantiation_failed",
			"packed_scene",
			"Node",
			"",
			"Scene could not be instantiated."
		)
		return _finalize_report(report)

	var check_options: Dictionary = GFVariantData.to_dictionary(options)
	check_options["scene_path"] = scene_path
	report = check_node(root, contract, check_options)
	if GFVariantData.get_option_bool(options, "free_instance", true):
		root.free()
	return report


## 加载场景路径并检查根节点契约。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scene_path: 待检查场景资源路径。
## [br]
## @param contract: 契约声明。
## [br]
## @schema contract: Dictionary scene root contract fields.
## [br]
## @param options: 可选项，支持 check_packed_scene() 的选项。
## [br]
## @schema options: Dictionary scene path contract check options.
## [br]
## @return 检查报告。
## [br]
## @schema return: Dictionary，包含 ok、scene_path、root_name、root_class、root_script_path、issues、counts 与 summary 字段。
static func check_scene_path(scene_path: String, contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = scene_path.strip_edges()
	var report: Dictionary = _make_report(
		GFVariantData.get_option_string(options, "subject", "Scene path contract"),
		normalized_path
	)
	if normalized_path.is_empty():
		_append_issue(report, "error", "empty_scene_path", "scene_path", "non-empty path", "", "Scene path is empty.")
		return _finalize_report(report)
	if not ResourceLoader.exists(normalized_path):
		_append_issue(
			report,
			"error",
			"scene_missing",
			"scene_path",
			"existing resource",
			normalized_path,
			"Scene resource does not exist."
		)
		return _finalize_report(report)

	var resource: Resource = ResourceLoader.load(normalized_path)
	if not (resource is PackedScene):
		_append_issue(
			report,
			"error",
			"resource_not_packed_scene",
			"scene_path",
			"PackedScene",
			resource.get_class() if resource != null else "",
			"Resource is not a PackedScene."
		)
		return _finalize_report(report)

	var packed_scene: PackedScene = resource
	var check_options: Dictionary = GFVariantData.to_dictionary(options)
	check_options["scene_path"] = normalized_path
	return check_packed_scene(packed_scene, contract, check_options)


## 批量检查场景路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param paths: 场景路径列表。
## [br]
## @param contract: 契约声明。
## [br]
## @schema contract: Dictionary scene root contract fields.
## [br]
## @param options: 可选项，支持 check_scene_path() 的选项。
## [br]
## @schema options: Dictionary scene path batch contract check options.
## [br]
## @return 聚合检查报告。
## [br]
## @schema return: Dictionary，包含 ok、checked_count、passed_count、failed_count、entries、issues、
## counts 与 summary 字段。
static func check_scene_paths(
	paths: PackedStringArray,
	contract: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = _make_collection_report("Scene contract batch")
	var entries: Array = GFVariantData.as_array(report["entries"])
	for scene_path: String in paths:
		var entry: Dictionary = check_scene_path(scene_path, contract, options)
		entries.append(entry)
		report["checked_count"] = GFVariantData.get_option_int(report, "checked_count") + 1
		if GFVariantData.get_option_bool(entry, "ok"):
			report["passed_count"] = GFVariantData.get_option_int(report, "passed_count") + 1
		else:
			report["failed_count"] = GFVariantData.get_option_int(report, "failed_count") + 1
		_merge_entry_issues(report, entry)
	return _finalize_report(report)


## 扫描目录并批量检查场景契约。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_path: 扫描起点，通常是 res:// 下的目录。
## [br]
## @param contract: 契约声明。
## [br]
## @schema contract: Dictionary scene root contract fields.
## [br]
## @param options: 可选项，同时支持 scan_scene_paths() 与 check_scene_path() 的选项。
## [br]
## @schema options: Dictionary scene scan and contract check options.
## [br]
## @return 聚合检查报告。
## [br]
## @schema return: Dictionary，包含 ok、checked_count、passed_count、failed_count、entries、issues、
## counts 与 summary 字段。
static func check_scene_directory(
	root_path: String = "res://",
	contract: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	return check_scene_paths(scan_scene_paths(root_path, options), contract, options)


## 创建可加入 GFValidationSuite 的根节点契约规则。
## [br]
## 默认 target_kind 为 GFValidationRule.TargetKind.NODE，适合配合 GFValidationRunner 的
## PackedScene 根节点实例化流程使用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contract: 契约声明。
## [br]
## @schema contract: Dictionary scene root contract fields.
## [br]
## @param options: 可选项，支持 rule_id、description、target_kind、severity、metadata 和
## check_node() 的选项。
## [br]
## @schema options: Dictionary validation rule and contract check options.
## [br]
## @return 校验规则。
static func make_validation_rule(contract: Dictionary = {}, options: Dictionary = {}) -> GFValidationRule:
	var rule_options: Dictionary = {
		"description": GFVariantData.get_option_string(
			options,
			"description",
			"Validate a scene root contract."
		),
		"target_kind": GFVariantData.get_option_int(options, "target_kind", GFValidationRule.TargetKind.NODE),
		"severity": GFVariantData.get_option_value(options, "severity", GFValidationIssue.Severity.ERROR),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	return GFValidationRule.new().configure(
		GFVariantData.get_option_string_name(options, "rule_id", &"scene_root_contract"),
		Callable(GFSceneContractTools, "_validate_rule_target").bind(
			contract.duplicate(true),
			options.duplicate(true)
		),
		rule_options
	)


# --- 私有/辅助方法 ---

static func _validate_rule_target(
	target: Variant,
	validation_report: GFValidationReport,
	context: Dictionary,
	contract: Dictionary,
	options: Dictionary
) -> Variant:
	var check_options: Dictionary = GFVariantData.to_dictionary(options)
	var context_path: String = GFVariantData.get_option_string(context, "scene_path")
	if context_path.is_empty():
		context_path = GFVariantData.get_option_string(context, "path")
	if not context_path.is_empty() and GFVariantData.get_option_string(check_options, "scene_path").is_empty():
		check_options["scene_path"] = context_path
	if GFVariantData.get_option_string(check_options, "subject").is_empty():
		check_options["subject"] = GFVariantData.get_option_string(context, "subject", "Scene root contract")

	var report: Dictionary = {}
	if target is Node:
		var target_node: Node = target
		report = check_node(target_node, contract, check_options)
	elif target is PackedScene:
		var packed_scene: PackedScene = target
		report = check_packed_scene(packed_scene, contract, check_options)
	else:
		report = _make_report(
			GFVariantData.get_option_string(check_options, "subject", "Scene root contract"),
			GFVariantData.get_option_string(check_options, "scene_path")
		)
		_append_issue(
			report,
			"error",
			"unsupported_target",
			"target",
			"Node or PackedScene",
			type_string(typeof(target)),
			"Target is not supported by scene contract validation."
		)
		report = _finalize_report(report)

	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var _added_issue: RefCounted = validation_report.add_issue(issue)
	return null


static func _make_report(subject: String, scene_path: String) -> Dictionary:
	return {
		"ok": true,
		"subject": subject,
		"scene_path": scene_path,
		"root_name": "",
		"root_class": "",
		"root_script_path": "",
		"counts": {},
		"issues": [],
		"summary": "",
	}


static func _make_collection_report(subject: String) -> Dictionary:
	return {
		"ok": true,
		"subject": subject,
		"checked_count": 0,
		"passed_count": 0,
		"failed_count": 0,
		"entries": [],
		"counts": {},
		"issues": [],
		"summary": "",
	}


static func _check_base_class(report: Dictionary, root: Node, contract: Dictionary) -> void:
	if not _has_option(contract, KEY_BASE_CLASS):
		return
	var expected_class: String = GFVariantData.get_option_string(contract, KEY_BASE_CLASS).strip_edges()
	if expected_class.is_empty():
		return
	if root.is_class(expected_class):
		return
	_append_issue(
		report,
		"error",
		"base_class_mismatch",
		String(KEY_BASE_CLASS),
		expected_class,
		root.get_class(),
		"Scene root class does not match the required base class."
	)


static func _check_base_script(report: Dictionary, root: Node, contract: Dictionary) -> void:
	var expected_value: Variant = GFVariantData.get_option_value(contract, KEY_BASE_SCRIPT)
	if not (expected_value is Script):
		return

	var expected_script: Script = expected_value
	var actual_value: Variant = root.get_script()
	if not (actual_value is Script):
		_append_issue(
			report,
			"error",
			"missing_root_script",
			String(KEY_BASE_SCRIPT),
			_get_script_label(expected_script),
			"",
			"Scene root has no script."
		)
		return

	var actual_script: Script = actual_value
	if _script_extends_or_equals(actual_script, expected_script):
		return
	_append_issue(
		report,
		"error",
		"base_script_mismatch",
		String(KEY_BASE_SCRIPT),
		_get_script_label(expected_script),
		_get_script_label(actual_script),
		"Scene root script does not extend the required base script."
	)


static func _check_required_groups(report: Dictionary, root: Node, contract: Dictionary) -> void:
	for group_name: String in _get_contract_string_list(contract, KEY_REQUIRED_GROUPS):
		if root.is_in_group(group_name):
			continue
		_append_issue(
			report,
			"error",
			"missing_required_group",
			String(KEY_REQUIRED_GROUPS),
			group_name,
			"",
			"Scene root is missing a required group."
		)


static func _check_forbidden_groups(report: Dictionary, root: Node, contract: Dictionary) -> void:
	for group_name: String in _get_contract_string_list(contract, KEY_FORBIDDEN_GROUPS):
		if not root.is_in_group(group_name):
			continue
		_append_issue(
			report,
			"error",
			"forbidden_group_present",
			String(KEY_FORBIDDEN_GROUPS),
			group_name,
			group_name,
			"Scene root belongs to a forbidden group."
		)


static func _check_name_constraints(report: Dictionary, root: Node, contract: Dictionary) -> void:
	var root_name: String = String(root.name)
	var name_prefix: String = GFVariantData.get_option_string(contract, KEY_NAME_PREFIX).strip_edges()
	if not name_prefix.is_empty() and not root_name.begins_with(name_prefix):
		_append_issue(
			report,
			"error",
			"name_prefix_mismatch",
			String(KEY_NAME_PREFIX),
			name_prefix,
			root_name,
			"Scene root name does not start with the required prefix."
		)

	var name_suffix: String = GFVariantData.get_option_string(contract, KEY_NAME_SUFFIX).strip_edges()
	if not name_suffix.is_empty() and not root_name.ends_with(name_suffix):
		_append_issue(
			report,
			"error",
			"name_suffix_mismatch",
			String(KEY_NAME_SUFFIX),
			name_suffix,
			root_name,
			"Scene root name does not end with the required suffix."
		)


static func _check_path_constraints(report: Dictionary, contract: Dictionary, scene_path: String) -> void:
	var path_prefix: String = GFVariantData.get_option_string(contract, KEY_PATH_PREFIX).strip_edges()
	if not path_prefix.is_empty() and scene_path.is_empty():
		_append_issue(
			report,
			"error",
			"missing_scene_path",
			String(KEY_PATH_PREFIX),
			path_prefix,
			"",
			"Scene path is required for path prefix checks."
		)
	elif not path_prefix.is_empty() and not scene_path.begins_with(path_prefix):
		_append_issue(
			report,
			"error",
			"path_prefix_mismatch",
			String(KEY_PATH_PREFIX),
			path_prefix,
			scene_path,
			"Scene path does not start with the required prefix."
		)

	var path_suffix: String = GFVariantData.get_option_string(contract, KEY_PATH_SUFFIX).strip_edges()
	if not path_suffix.is_empty() and scene_path.is_empty():
		_append_issue(
			report,
			"error",
			"missing_scene_path",
			String(KEY_PATH_SUFFIX),
			path_suffix,
			"",
			"Scene path is required for path suffix checks."
		)
	elif not path_suffix.is_empty() and not scene_path.ends_with(path_suffix):
		_append_issue(
			report,
			"error",
			"path_suffix_mismatch",
			String(KEY_PATH_SUFFIX),
			path_suffix,
			scene_path,
			"Scene path does not end with the required suffix."
		)


static func _check_script_structure(report: Dictionary, root: Node, contract: Dictionary, options: Dictionary) -> void:
	var structure: Dictionary = GFVariantData.get_option_dictionary(contract, KEY_SCRIPT_STRUCTURE)
	if structure.is_empty():
		return

	var actual_value: Variant = root.get_script()
	if not (actual_value is Script):
		_append_issue(
			report,
			"error",
			"missing_root_script",
			String(KEY_SCRIPT_STRUCTURE),
			"Script",
			"",
			"Scene root has no script for script structure checks."
		)
		return

	var actual_script: Script = actual_value
	var structure_options: Dictionary = GFVariantData.get_option_dictionary(options, "script_structure_options")
	var structure_report: Dictionary = GFScriptStructureTools.check_script_structure(
		actual_script,
		structure,
		structure_options
	)
	report["script_structure"] = structure_report
	for issue_value: Variant in GFVariantData.get_option_array(structure_report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var issue_kind: String = GFVariantData.get_option_string(issue, "kind", "script_structure_issue")
		_append_issue(
			report,
			GFVariantData.get_option_string(issue, "severity", "error"),
			"script_%s" % issue_kind,
			"%s.%s" % [String(KEY_SCRIPT_STRUCTURE), GFVariantData.get_option_string(issue, "field")],
			GFVariantData.get_option_string(issue, "member_name"),
			"",
			GFVariantData.get_option_string(issue, "message", "Script structure check failed.")
		)


static func _merge_entry_issues(report: Dictionary, entry: Dictionary) -> void:
	var issues: Array = GFVariantData.as_array(report["issues"])
	for issue_value: Variant in GFVariantData.get_option_array(entry, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		issues.append(issue.duplicate(true))


static func _append_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	field: String,
	expected: Variant,
	actual: Variant,
	message: String
) -> void:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"field": field,
		"key": field,
		"path": GFVariantData.get_option_string(report, "scene_path"),
		"subject": GFVariantData.get_option_string(report, "subject"),
		"root_name": GFVariantData.get_option_string(report, "root_name"),
		"root_class": GFVariantData.get_option_string(report, "root_class"),
		"message": message,
	}
	if expected != null and str(expected) != "":
		issue["expected"] = GFVariantData.duplicate_variant(expected)
	if actual != null and str(actual) != "":
		issue["actual"] = GFVariantData.duplicate_variant(actual)
	var issues: Array = GFVariantData.as_array(report["issues"])
	issues.append(issue)


static func _finalize_report(report: Dictionary) -> Dictionary:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var error_count: int = 0
	var warning_count: int = 0
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		match GFVariantData.get_option_string(issue, "severity"):
			"error":
				error_count += 1
			"warning":
				warning_count += 1

	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "counts")
	counts["issue_count"] = issues.size()
	counts["error_count"] = error_count
	counts["warning_count"] = warning_count
	report["counts"] = counts
	report["ok"] = error_count == 0
	if report.has("checked_count"):
		report["summary"] = "ok" if error_count == 0 else "checked=%s failed=%s errors=%s warnings=%s" % [
			GFVariantData.get_option_int(report, "checked_count"),
			GFVariantData.get_option_int(report, "failed_count"),
			error_count,
			warning_count,
		]
	else:
		report["summary"] = "ok" if error_count == 0 else "issues=%s errors=%s warnings=%s" % [
			issues.size(),
			error_count,
			warning_count,
		]
	return report


static func _get_contract_string_list(contract: Dictionary, key: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var value: Variant = GFVariantData.get_option_value(contract, key)
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed.duplicate()
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if not text.is_empty():
			var _single_appended: bool = result.append(text)
		return result
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			var item_text: String = GFVariantData.to_text(item).strip_edges()
			if not item_text.is_empty():
				var _item_appended: bool = result.append(item_text)
	return result


static func _has_option(options: Dictionary, key: StringName) -> bool:
	return options.has(key) or options.has(String(key))


static func _script_extends_or_equals(candidate: Script, expected: Script) -> bool:
	if candidate == null or expected == null:
		return false
	var current: Script = candidate
	while current != null:
		if current == expected:
			return true
		current = current.get_base_script()
	return false


static func _get_root_script_path(root: Node) -> String:
	if root == null:
		return ""
	var script_value: Variant = root.get_script()
	if script_value is Script:
		var script: Script = script_value
		return script.resource_path
	return ""


static func _get_script_label(script: Script) -> String:
	if script == null:
		return ""
	if not script.resource_path.is_empty():
		return script.resource_path
	if script.has_method("get_global_name"):
		return GFVariantData.to_text(script.call("get_global_name"))
	return script.get_instance_base_type()
