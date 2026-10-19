# 代码规范配置的闭合字段、路径范围和规则级别准入。
extends RefCounted


# --- 常量 ---

## 结构排版规则注册入口。
## [br]
## @api private
const _LAYOUT_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_layout.gd")

## 声明文档规则注册入口。
## [br]
## @api private
const _DOCS_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_docs.gd")

## 配置不接受未解释字段，避免拼写错误静默关闭检查。
## [br]
## @api private
const _FIELDS: PackedStringArray = [
	"schema_version",
	"preset",
	"include",
	"exclude",
	"rules",
	"layout",
]

## 布局参数只控制结构，不提供列宽选项。
## [br]
## @api private
const _LAYOUT_DEFAULTS: Dictionary = {
	"max_inline_items": 2,
	"section_blank_lines_before": 2,
	"definition_blank_lines": 2,
}

## 第一版游戏预设的固定规则集合；新增可选规则不会改变已选版本。
## [br]
## @api private
const _GAME_V1: PackedStringArray = [
	"text_format",
	"statement_separator",
	"inline_body",
	"list_layout",
	"declaration_parameter_layout",
	"annotation_parameter_layout",
	"annotation_binding_layout",
	"enum_layout",
	"dictionary_entry_layout",
	"dictionary_spacing",
	"trailing_comma",
	"multiline_items",
	"closing_delimiter",
	"continuation_indentation",
	"condition_layout",
	"nested_ternary",
	"simple_string_layout",
	"simple_format_layout",
	"format_layout",
	"argument_group_layout",
	"call_group_layout",
	"atomic_group_layout",
	"cast_layout",
	"expression_layout",
	"index_layout",
	"chain_layout",
	"token_spacing",
	"suite_indentation",
	"section_spacing",
	"definition_spacing",
	"member_block_spacing",
	"member_doc_binding",
	"match_pattern_layout",
	"lambda_argument_separator",
	"doc_public_summary",
	"doc_private_summary",
	"doc_parameters",
	"doc_return",
	"doc_tags",
	"section_order",
]


# --- 框架内部方法 ---

## 验证并复制一份项目配置，不读取文件或修改传入字典。
## [br]
## @api framework_internal
## [br]
## @param config: 项目显式选择的预设、规则和扫描范围。
## [br]
## @schema config: Dictionary，schema_version: 1；可选 preset: "gf-game@1"、include/exclude: Array[String]、rules: Dictionary[String, String]、layout: Dictionary[String, int]。
## [br]
## @return 规范配置或配置失败原因。
## [br]
## @schema return: Dictionary，ok: bool、status: String、config: Dictionary、error: String；失败 config 为空。
static func normalize(config: Dictionary) -> Dictionary:
	if config.is_empty():
		return _failure("unconfigured", "尚未配置代码规范检查。")
	for key: Variant in config:
		if not key is String:
			return _failure("incomplete", "配置含未知字段。")
		var field: String = key
		if not _FIELDS.has(field):
			return _failure("incomplete", "配置含未知字段。")
	var version: Variant = config.get("schema_version")
	if (
		not (
			version is int
			or version is float
		)
		or version != 1
	):
		return _failure("incomplete", "schema_version 必须为 1。")
	var preset: Variant = config.get("preset", "")
	if not preset is String or not ["", "gf-game@1"].has(preset):
		return _failure("incomplete", "不支持此代码规范预设。")
	var levels: Dictionary = {}
	var rule_ids: PackedStringArray = get_rule_ids()
	for rule_id: String in rule_ids:
		levels[rule_id] = "error" if preset == "gf-game@1" and _GAME_V1.has(rule_id) else "off"
	var overrides: Variant = config.get("rules", {})
	if not overrides is Dictionary:
		return _failure("incomplete", "rules 必须是规则 ID 到级别的对象。")
	var rule_overrides: Dictionary = overrides
	for key: Variant in rule_overrides:
		if not key is String:
			return _failure("incomplete", "rules 含未知规则 ID。")
		var rule_id: String = key
		if not rule_ids.has(rule_id):
			return _failure("incomplete", "rules 含未知规则 ID。")
		var level: Variant = rule_overrides[key]
		if not level is String or not [
			"off",
			"warning",
			"error",
		].has(level):
			return _failure("incomplete", "规则级别必须为 off、warning 或 error。")
		levels[key] = level
	if not levels.values().has("error") and not levels.values().has("warning"):
		return _failure("unconfigured", "请选择预设或至少启用一项规则。")
	var include: Variant = config.get(
		"include",
		["res://"]
	)
	var exclude: Variant = config.get(
		"exclude",
		["res://addons"]
	)
	if not _paths_valid(include, false) or not _paths_valid(exclude, true):
		return _failure("incomplete", "include/exclude 必须是最多 64 项的规范 res:// 路径数组；include 不能为空。")
	var included_paths: Array = include
	var excluded_paths: Array = exclude
	var layout: Variant = config.get("layout", {})
	if not layout is Dictionary:
		return _failure("incomplete", "layout 必须是结构参数对象。")
	var layout_values: Dictionary = _LAYOUT_DEFAULTS.duplicate()
	var layout_overrides: Dictionary = layout
	for key: Variant in layout_overrides:
		if not key is String or not _LAYOUT_DEFAULTS.has(key):
			return _failure("incomplete", "layout 含未知结构参数。")
		var value: Variant = layout_overrides[key]
		if not (value is int or value is float):
			return _failure("incomplete", "结构参数必须是整数。")
		var number: float = value
		if (
			not is_finite(number)
			or number != floor(number)
			or number < 0
			or number > 8
		):
			return _failure("incomplete", "结构参数必须是 0 至 8 的整数。")
		if key == "max_inline_items" and number < 1:
			return _failure("incomplete", "max_inline_items 必须至少为 1。")
		layout_values[key] = int(number)
	return {
		"ok": true,
		"status": "configured",
		"config": {
			"schema_version": 1,
			"preset": preset,
			"include": included_paths.duplicate(),
			"exclude": excluded_paths.duplicate(),
			"rules": levels,
			"layout": layout_values,
		},
		"error": "",
	}


## 返回当前规则 ID；词法失败和读取失败不属于可关闭的规范规则。
## [br]
## @api framework_internal
## [br]
## @return 排序后的稳定规则 ID 集合。
static func get_rule_ids() -> PackedStringArray:
	var result: PackedStringArray = _LAYOUT_SCRIPT.get_rule_ids()
	result.append_array(_DOCS_SCRIPT.get_rule_ids())
	result.sort()
	return result


# --- 私有/辅助方法 ---

## 路径只接受项目内明确的目录或文件，不解释通配或父目录跳转。
## [br]
## @api private
static func _paths_valid(value: Variant, allow_empty: bool) -> bool:
	if not value is Array:
		return false
	var paths: Array = value
	if (
		paths.size() > 64
		or (
			paths.is_empty()
			and not allow_empty
		)
	):
		return false
	for item: Variant in paths:
		if not item is String:
			return false
		var path: String = item
		for index: int in range(path.length()):
			if path.unicode_at(index) < 32 or path.unicode_at(index) == 127:
				return false
		if path == "res://":
			continue
		if not path.begins_with("res://") or path.length() > 4096:
			return false
		var relative: String = path.substr(6)
		for forbidden: String in [
			"\\",
			":",
			"*",
			"?",
			"<",
			">",
			"\"",
			"|",
		]:
			if relative.contains(forbidden):
				return false
		for part: String in relative.split("/", true):
			if (
				part.is_empty()
				or part.ends_with(".")
				or part.strip_edges() != part
			):
				return false
			if OS.get_name() == "Windows" and _is_windows_device(part):
				return false
	return true


## 拒绝 Windows 保留设备名，避免把资源范围解释为设备读取。
## [br]
## @api private
static func _is_windows_device(part: String) -> bool:
	var device: String = part.get_slice(".", 0).to_upper()
	if [
		"CON",
		"PRN",
		"AUX",
		"NUL",
	].has(device):
		return true
	if device.length() != 4:
		return false
	return (
		(
			device.begins_with("COM")
			or device.begins_with("LPT")
		)
		and device[3] in "123456789"
	)


## 配置失败不留下可被误用的部分规则。
## [br]
## @api private
static func _failure(status: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"status": status,
		"config": {},
		"error": message,
	}
