## GFValidationSuite: 通用校验套件资源。
##
## 保存一组规则与可选资源路径筛选条件。套件只描述“要检查什么”，实际加载、
## 实例化和报告聚合由 GFValidationRunner 完成。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFValidationSuite
extends Resource


# --- 常量 ---

## 校验规则脚本基类。
## [br]
## @api public
const GFValidationRuleBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_rule.gd")

## 默认递归扫描目录深度上限。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认单次路径收集数量上限。
## [br]
## @api public
const DEFAULT_MAX_COLLECTED_PATHS: int = 10_000


# --- 导出变量 ---

## 套件标识。
## [br]
## @api public
@export var suite_id: StringName = &""

## 套件说明。
## [br]
## @api public
@export_multiline var description: String = ""

## 是否启用套件。
## [br]
## @api public
@export var enabled: bool = true

## 是否把警告提升为错误。
## [br]
## @api public
@export var treat_warnings_as_errors: bool = false

## 校验规则列表。
## [br]
## @api public
@export var rules: Array[GFValidationRuleBase] = []

## 需要扫描的路径。可以是文件或目录；为空时不自动扫描。
## [br]
## @api public
@export var include_paths: PackedStringArray = PackedStringArray()

## 需要排除的路径或通配模式。
## [br]
## @api public
@export var exclude_paths: PackedStringArray = PackedStringArray()

## 资源文件扩展名，不含点号。
## [br]
## @api public
@export var resource_extensions: PackedStringArray = PackedStringArray(["tres", "res"])

## 场景文件扩展名，不含点号。
## [br]
## @api public
@export var scene_extensions: PackedStringArray = PackedStringArray(["tscn", "scn"])

## 扫描目录时是否递归。
## [br]
## @api public
@export var recursive: bool = true

## 扫描目录时是否包含隐藏目录和文件。
## [br]
## @api public
@export var include_hidden: bool = false

## 递归扫描的最大目录深度。0 表示不限制。
## [br]
## @api public
@export var max_scan_depth: int = DEFAULT_MAX_SCAN_DEPTH:
	set(value):
		max_scan_depth = maxi(value, 0)

## 单次 collect_paths() 最多收集的路径数量。0 表示不限制。
## [br]
## @api public
@export var max_collected_paths: int = DEFAULT_MAX_COLLECTED_PATHS:
	set(value):
		max_collected_paths = maxi(value, 0)

## 可选元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary of caller-defined suite metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加规则。
## [br]
## @api public
## [br]
## @param rule: 规则资源。
## [br]
## @return 添加成功返回 true。
func add_rule(rule: GFValidationRuleBase) -> bool:
	if rule == null:
		return false
	rules.append(rule)
	return true


## 移除规则。
## [br]
## @api public
## [br]
## @param rule: 规则资源。
## [br]
## @return 移除成功返回 true。
func remove_rule(rule: GFValidationRuleBase) -> bool:
	var index: int = rules.find(rule)
	if index < 0:
		return false
	rules.remove_at(index)
	return true


## 获取启用的规则。
## [br]
## @api public
## [br]
## @return 规则数组副本。
func get_enabled_rules() -> Array[GFValidationRuleBase]:
	var result: Array[GFValidationRuleBase] = []
	if not enabled:
		return result
	for rule: GFValidationRuleBase in rules:
		if rule != null and rule.enabled:
			result.append(rule)
	return result


## 检查路径是否会被套件扫描。
## [br]
## @api public
## [br]
## @param path: 资源或场景路径。
## [br]
## @return 匹配返回 true。
func matches_path(path: String) -> bool:
	if path.is_empty():
		return false
	if _is_excluded(path):
		return false
	return _is_supported_file(path)


## 收集 include_paths 中匹配的资源和场景路径。
## [br]
## @api public
## [br]
## @return 已排序路径列表。
func collect_paths() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not enabled:
		return result

	var scan_state: Dictionary = _make_scan_state()
	for include_path: String in include_paths:
		_collect_path(include_path, result, 0, scan_state)
		if not _can_collect_more_paths(result):
			break
	result.sort()
	return result


## 创建套件配置副本。
## [br]
## @api public
## [br]
## @return 新套件。
func duplicate_suite() -> GFValidationSuite:
	var suite: GFValidationSuite = GFValidationSuite.new()
	suite.suite_id = suite_id
	suite.description = description
	suite.enabled = enabled
	suite.treat_warnings_as_errors = treat_warnings_as_errors
	suite.include_paths = include_paths.duplicate()
	suite.exclude_paths = exclude_paths.duplicate()
	suite.resource_extensions = resource_extensions.duplicate()
	suite.scene_extensions = scene_extensions.duplicate()
	suite.recursive = recursive
	suite.include_hidden = include_hidden
	suite.max_scan_depth = max_scan_depth
	suite.max_collected_paths = max_collected_paths
	suite.metadata = metadata.duplicate(true)
	for rule: GFValidationRuleBase in rules:
		suite.rules.append(rule.duplicate_rule() if rule != null else null)
	return suite


# --- 私有/辅助方法 ---

func _collect_path(path: String, result: PackedStringArray, depth: int, scan_state: Dictionary) -> void:
	if not _can_collect_more_paths(result):
		_warn_collected_path_limit(scan_state)
		return
	if path.is_empty() or _is_excluded(path):
		return
	if FileAccess.file_exists(path):
		_append_path_if_allowed(path, result, scan_state)
		return

	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = include_hidden
	dir.include_navigational = false
	var list_result: Error = dir.list_dir_begin()
	if list_result != OK:
		return
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not _can_collect_more_paths(result):
			_warn_collected_path_limit(scan_state)
			break

		var child_path: String = path.path_join(entry)
		if dir.current_is_dir():
			if recursive and _should_scan_directory(entry, child_path, depth, scan_state):
				_collect_path(child_path, result, depth + 1, scan_state)
		else:
			_append_path_if_allowed(child_path, result, scan_state)
		entry = dir.get_next()
	dir.list_dir_end()


func _should_scan_directory(entry: String, path: String, current_depth: int, scan_state: Dictionary) -> bool:
	if not include_hidden and entry.begins_with("."):
		return false
	if _is_excluded(path):
		return false
	if max_scan_depth > 0 and current_depth >= max_scan_depth:
		_warn_scan_depth_limit(path, scan_state)
		return false
	return true


func _append_path_if_allowed(path: String, result: PackedStringArray, scan_state: Dictionary) -> void:
	if not matches_path(path) or _scan_state_has_path(scan_state, path):
		return
	if not _can_collect_more_paths(result):
		_warn_collected_path_limit(scan_state)
		return
	_append_packed_string(result, path)
	_scan_state_add_path(scan_state, path)


func _can_collect_more_paths(result: PackedStringArray) -> bool:
	return max_collected_paths <= 0 or result.size() < max_collected_paths


func _make_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
		"path_lookup": {},
	}


func _warn_collected_path_limit(scan_state: Dictionary) -> void:
	if GFVariantData.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFValidationSuite] collect_paths 已达到 max_collected_paths=%d，后续路径已跳过。" % max_collected_paths)


func _warn_scan_depth_limit(path: String, scan_state: Dictionary) -> void:
	if GFVariantData.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFValidationSuite] collect_paths 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


func _is_supported_file(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	return resource_extensions.has(extension) or scene_extensions.has(extension)


func _is_excluded(path: String) -> bool:
	for pattern: String in exclude_paths:
		if pattern.is_empty():
			continue
		if path == pattern or path.begins_with(pattern.path_join("")):
			return true
		if pattern.contains("*") or pattern.contains("?"):
			if path.match(pattern):
				return true
	return false


func _scan_state_has_path(scan_state: Dictionary, path: String) -> bool:
	var path_lookup: Dictionary = GFVariantData.get_option_dictionary(scan_state, "path_lookup")
	return path_lookup.has(path)


func _scan_state_add_path(scan_state: Dictionary, path: String) -> void:
	var path_lookup: Dictionary = GFVariantData.get_option_dictionary(scan_state, "path_lookup")
	path_lookup[path] = true
	scan_state["path_lookup"] = path_lookup


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
