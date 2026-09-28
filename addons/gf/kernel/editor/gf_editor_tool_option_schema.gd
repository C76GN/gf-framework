@tool

## GFEditorToolOptionSchema: 编辑器工具选项集合声明。
##
## 为工具面板、持久化和调试快照提供稳定的选项描述与值规范化入口。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorToolOptionSchema
extends Resource


# --- 常量 ---

## 将不同键形式的输入选项统一转换为 StringName 的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 导出变量 ---

## 工具选项列表。
## [br]
## @api public
@export var options: Array[GFEditorToolOption] = []

## 可选元数据，供项目层扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary for caller-defined option schema metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加或替换选项声明。
## [br]
## @api public
## [br]
## @param option: 选项声明。
## [br]
## @return 添加成功返回 true。
func add_option(option: GFEditorToolOption) -> bool:
	if option == null or not option.is_valid_definition():
		return false
	for index: int in range(options.size()):
		var current: GFEditorToolOption = options[index]
		if current != null and current.option_id == option.option_id:
			options[index] = option
			return true
	options.append(option)
	return true


## 移除选项声明。
## [br]
## @api public
## [br]
## @param option_id: 选项标识。
## [br]
## @return 移除成功返回 true。
func remove_option(option_id: StringName) -> bool:
	for index: int in range(options.size()):
		var option: GFEditorToolOption = options[index]
		if option != null and option.option_id == option_id:
			options.remove_at(index)
			return true
	return false


## 清空选项声明。
## [br]
## @api public
func clear_options() -> void:
	options.clear()


## 获取选项声明。
## [br]
## @api public
## [br]
## @param option_id: 选项标识。
## [br]
## @return 找到时返回选项声明，否则返回 null。
func get_option(option_id: StringName) -> GFEditorToolOption:
	for option: GFEditorToolOption in options:
		if option != null and option.option_id == option_id:
			return option
	return null


## 检查选项声明是否存在。
## [br]
## @api public
## [br]
## @param option_id: 选项标识。
## [br]
## @return 存在返回 true。
func has_option(option_id: StringName) -> bool:
	return get_option(option_id) != null


## 获取选项 ID 列表。
## [br]
## @api public
## [br]
## @return 排序后的选项 ID。
func get_option_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for option: GFEditorToolOption in options:
		if option != null and option.option_id != &"":
			var _append_result_116: Variant = result.append(String(option.option_id))
	result.sort()
	return result


## 获取默认值字典。
## [br]
## @api public
## [br]
## @return 选项 ID 到默认值的字典。
## [br]
## @schema return: Dictionary keyed by option_id, storing normalized default values.
func get_default_values() -> Dictionary:
	var result: Dictionary = {}
	for option: GFEditorToolOption in options:
		if option != null and option.option_id != &"":
			result[option.option_id] = option.normalize_value(null)
	return result


## 规范化一组选项值。
## [br]
## @api public
## [br]
## @param values: 输入选项值。
## [br]
## @schema values: Dictionary keyed by option_id, storing raw option values.
## [br]
## @param include_defaults: 为 true 时补齐缺失默认值。
## [br]
## @return 规范化后的选项字典。
## [br]
## @schema return: Dictionary keyed by option_id, storing normalized option values.
func normalize_values(values: Dictionary, include_defaults: bool = true) -> Dictionary:
	var result: Dictionary = get_default_values() if include_defaults else {}
	for key: Variant in values.keys():
		var option_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.to_string_name(key)
		var option: GFEditorToolOption = get_option(option_id)
		if option == null:
			continue
		result[option_id] = option.normalize_value(values[key])
	return result


## 校验一组选项值。
## [br]
## @api public
## [br]
## @param values: 输入选项值。
## [br]
## @schema values: Dictionary keyed by option_id, storing option values to validate.
## [br]
## @return 校验报告字典。
## [br]
## @schema return: Dictionary containing ok, error_count, warning_count, and issues.
func validate_values(values: Dictionary) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"error_count": 0,
		"warning_count": 0,
		"issues": [],
	}
	var issues: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "issues", [])
	)
	for key: Variant in values.keys():
		var option_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.to_string_name(key)
		var option: GFEditorToolOption = get_option(option_id)
		if option == null:
			issues.append(_make_issue("warning", "unknown_option", option_id, "未知工具选项：%s。" % String(option_id)))
			report["warning_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "warning_count", 0) + 1
			continue
		if not option.is_value_valid(values[key]):
			issues.append(_make_issue("error", "invalid_option_value", option_id, "工具选项值类型不匹配：%s。" % String(option_id)))
			report["error_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "error_count", 0) + 1
			report["ok"] = false
	return report


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新选项集合声明。
func duplicate_schema() -> GFEditorToolOptionSchema:
	var schema: GFEditorToolOptionSchema = GFEditorToolOptionSchema.new()
	schema.metadata = metadata.duplicate(true)
	for option: GFEditorToolOption in options:
		schema.options.append(option.duplicate_option() if option != null else null)
	return schema


## 导出选项集合摘要。
## [br]
## @api public
## [br]
## @return 选项集合字典。
## [br]
## @schema return: Dictionary containing option descriptions and metadata.
func describe() -> Dictionary:
	var option_descriptions: Array[Dictionary] = []
	for option: GFEditorToolOption in options:
		if option != null:
			option_descriptions.append(option.describe())
	return {
		"options": option_descriptions,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 组装选项值校验诊断，标明严重级别、种类、选项 ID 和说明文本。
## [br]
## @api private
func _make_issue(severity: String, kind: String, option_id: StringName, message: String) -> Dictionary:
	return {
		"severity": severity,
		"kind": kind,
		"option_id": option_id,
		"message": message,
	}
