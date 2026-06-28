## GFValidationRunner: 通用校验套件执行器。
##
## 执行 GFValidationSuite 中的规则，支持直接目标、资源路径和 PackedScene 实例化。
## Runner 不调用项目约定方法，只把目标、路径和上下文交给显式注册的规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFValidationRunner
extends RefCounted


# --- 信号 ---

## 套件开始执行后发出。
## [br]
## @api public
## [br]
## @param suite_id: 套件标识。
signal validation_started(suite_id: StringName)

## 单个目标完成校验后发出。
## [br]
## @api public
## [br]
## @param target_id: 目标标识。
## [br]
## @param report: 目标报告。
signal target_validated(target_id: String, report: GFValidationReport)

## 套件完成执行后发出。
## [br]
## @api public
## [br]
## @param report: 聚合报告。
signal validation_finished(report: GFValidationReport)


# --- 常量 ---

## 校验套件脚本基类。
## [br]
## @api public
const GFValidationSuiteBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_suite.gd")

## 校验规则脚本基类。
## [br]
## @api public
const GFValidationRuleBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_rule.gd")


# --- 公共变量 ---

## 通过路径加载 PackedScene 时是否同时实例化根节点参与 Node 规则校验。
## [br]
## @api public
var validate_scene_instances: bool = true

## 路径校验时是否释放由 Runner 实例化的场景根节点。
## [br]
## @api public
var free_instantiated_scenes: bool = true


# --- 公共方法 ---

## 执行套件。
## [br]
## @api public
## [br]
## @param suite: 校验套件。
## [br]
## @param options: 可选参数，支持 targets、paths、context、treat_warnings_as_errors。
## [br]
## @schema options: Dictionary runner options with targets, paths, context, and warning policy.
## [br]
## @return 聚合报告。
func run_suite(suite: GFValidationSuiteBase, options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = _make_report(suite, options)
	if suite == null or not suite.enabled:
		return report

	validation_started.emit(suite.suite_id)
	var context: Dictionary = _make_base_context(suite, options)
	var targets: Array = GFVariantData.as_array(GFVariantData.get_option_value(options, "targets", []))
	_run_targets_into(report, suite, targets, context)

	var paths: PackedStringArray = _resolve_paths(suite, options)
	_run_paths_into(report, suite, paths, context)
	if GFVariantData.get_option_bool(options, "treat_warnings_as_errors", suite.treat_warnings_as_errors):
		var _promoted_report: RefCounted = report.promote_warnings_to_errors()

	validation_finished.emit(report)
	return report


## 校验一组直接目标。
## [br]
## @api public
## [br]
## @param targets: 目标数组。
## [br]
## @schema targets: Array of validation targets.
## [br]
## @param suite: 可选套件；为空时使用无规则套件。
## [br]
## @param options: 可选参数，支持 context、treat_warnings_as_errors。
## [br]
## @schema options: Dictionary runner options with context and warning policy.
## [br]
## @return 聚合报告。
func run_targets(
	targets: Array,
	suite: GFValidationSuiteBase = null,
	options: Dictionary = {}
) -> GFValidationReport:
	var effective_suite: GFValidationSuiteBase = suite if suite != null else GFValidationSuiteBase.new()
	var merged_options: Dictionary = options.duplicate(true)
	merged_options["targets"] = targets
	merged_options["paths"] = PackedStringArray()
	return run_suite(effective_suite, merged_options)


## 校验一组资源或场景路径。
## [br]
## @api public
## [br]
## @param paths: 资源或场景路径列表。
## [br]
## @param suite: 可选套件；为空时使用无规则套件。
## [br]
## @param options: 可选参数，支持 context、treat_warnings_as_errors。
## [br]
## @schema options: Dictionary runner options with context and warning policy.
## [br]
## @return 聚合报告。
func run_paths(
	paths: PackedStringArray,
	suite: GFValidationSuiteBase = null,
	options: Dictionary = {}
) -> GFValidationReport:
	var effective_suite: GFValidationSuiteBase = suite if suite != null else GFValidationSuiteBase.new()
	var merged_options: Dictionary = options.duplicate(true)
	merged_options["paths"] = paths
	merged_options["targets"] = []
	return run_suite(effective_suite, merged_options)


# --- 私有/辅助方法 ---

func _make_report(suite: GFValidationSuiteBase, options: Dictionary) -> GFValidationReport:
	var subject: String = GFVariantData.get_option_string(options, "subject")
	if subject.is_empty() and suite != null and suite.suite_id != &"":
		subject = String(suite.suite_id)
	if subject.is_empty():
		subject = "GFValidationRunner"

	var metadata: Dictionary = {}
	if suite != null:
		metadata["suite_id"] = String(suite.suite_id)
		if not suite.metadata.is_empty():
			metadata["suite_metadata"] = suite.metadata.duplicate(true)
	return GFValidationReport.new(subject, metadata)


func _make_base_context(suite: GFValidationSuiteBase, options: Dictionary) -> Dictionary:
	var context: Dictionary = {}
	var custom_context: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(options, "context", {}))
	if not custom_context.is_empty():
		context = custom_context.duplicate(true)
	context["suite"] = suite
	context["suite_id"] = suite.suite_id
	return context


func _resolve_paths(suite: GFValidationSuiteBase, options: Dictionary) -> PackedStringArray:
	var explicit_paths: Variant = GFVariantData.get_option_value(options, "paths")
	if explicit_paths is PackedStringArray:
		var packed_paths: PackedStringArray = explicit_paths
		return packed_paths.duplicate()
	if explicit_paths is Array:
		var result: PackedStringArray = PackedStringArray()
		var path_values: Array = explicit_paths
		for path_variant: Variant in path_values:
			_append_packed_string(result, GFVariantData.to_text(path_variant))
		return result
	return suite.collect_paths()


func _run_targets_into(
	report: GFValidationReport,
	suite: GFValidationSuiteBase,
	targets: Array,
	base_context: Dictionary
) -> void:
	var index: int = 0
	for target: Variant in targets:
		var context: Dictionary = base_context.duplicate(true)
		context["target_index"] = index
		var target_report: GFValidationReport = _validate_target(target, suite, context)
		_merge_report(report, target_report)
		target_validated.emit(_make_target_id(target, context), target_report)
		index += 1


func _run_paths_into(
	report: GFValidationReport,
	suite: GFValidationSuiteBase,
	paths: PackedStringArray,
	base_context: Dictionary
) -> void:
	for path: String in paths:
		if not suite.matches_path(path):
			continue
		_validate_path_into(report, suite, path, base_context)


func _validate_path_into(
	report: GFValidationReport,
	suite: GFValidationSuiteBase,
	path: String,
	base_context: Dictionary
) -> void:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		var _missing_issue: RefCounted = report.add_error(&"resource_missing", "Resource path does not exist.", null, path)
		return

	var resource: Resource = load(path)
	if resource == null:
		var _load_issue: RefCounted = report.add_error(&"resource_load_failed", "Resource could not be loaded.", null, path)
		return

	var resource_context: Dictionary = base_context.duplicate(true)
	resource_context["path"] = path
	resource_context["subject"] = path
	var resource_report: GFValidationReport = _validate_target(resource, suite, resource_context)
	_merge_report(report, resource_report)
	target_validated.emit(path, resource_report)

	if validate_scene_instances and resource is PackedScene:
		var packed_scene: PackedScene = resource
		_validate_scene_instance_into(report, suite, packed_scene, path, base_context)


func _validate_scene_instance_into(
	report: GFValidationReport,
	suite: GFValidationSuiteBase,
	packed_scene: PackedScene,
	path: String,
	base_context: Dictionary
) -> void:
	var root: Node = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if root == null:
		var _scene_issue: RefCounted = report.add_error(&"scene_instantiation_failed", "Scene could not be instantiated.", null, path)
		return

	var context: Dictionary = base_context.duplicate(true)
	context["path"] = path
	context["scene_path"] = path
	context["subject"] = "%s#root" % path
	var scene_report: GFValidationReport = _validate_target(root, suite, context)
	_merge_report(report, scene_report)
	target_validated.emit("%s#root" % path, scene_report)
	if free_instantiated_scenes:
		root.free()


func _validate_target(
	target: Variant,
	suite: GFValidationSuiteBase,
	base_context: Dictionary
) -> GFValidationReport:
	var target_report: GFValidationReport = GFValidationReport.new(GFVariantData.get_option_string(base_context, "subject", _make_target_id(target, base_context)))
	for rule: GFValidationRuleBase in suite.get_enabled_rules():
		if rule == null:
			continue
		var context: Dictionary = base_context.duplicate(true)
		context["rule_id"] = rule.rule_id
		_merge_report(target_report, rule.validate(target, context))
	return target_report


func _make_target_id(target: Variant, context: Dictionary) -> String:
	var path: String = GFVariantData.get_option_string(context, "path")
	if not path.is_empty():
		return path
	if target is Node:
		var node: Node = target
		return str(node.get_path()) if node.is_inside_tree() else String(node.name)
	if target is Resource:
		var resource: Resource = target
		return resource.resource_path
	return str(target)


func _merge_report(target_report: GFValidationReport, source_report: Variant) -> void:
	var _merged_report: RefCounted = target_report.merge(source_report)


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
