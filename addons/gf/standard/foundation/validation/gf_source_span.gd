## GFSourceSpan: 通用源码或资源文本定位范围。
##
## 用于把校验、导入、生成器或编辑器工具中的问题定位到一个稳定的
## source_path、line、column 范围。行列约定为 1-based，0 表示未知。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSourceSpan
extends RefCounted

# --- 公共变量 ---

## 源文件或资源路径。
## [br]
## @api public
var source_path: String = ""

## 起始行号，1-based；0 表示未知。
## [br]
## @api public
var line: int = 0

## 起始列号，1-based；0 表示未知。
## [br]
## @api public
var column: int = 0

## 同一行内的跨度长度；0 表示未知。
## [br]
## @api public
var length: int = 0

## 结束行号，1-based；0 表示未知。
## [br]
## @api public
var end_line: int = 0

## 结束列号，1-based；0 表示未知。
## [br]
## @api public
var end_column: int = 0

## 可选源码预览。
## [br]
## @api public
var preview: String = ""

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary caller metadata.
var metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建源码定位范围。
## [br]
## @api public
## [br]
## @param p_source_path: 源文件或资源路径。
## [br]
## @param p_line: 起始行号，1-based；0 表示未知。
## [br]
## @param p_column: 起始列号，1-based；0 表示未知。
## [br]
## @param p_length: 同一行内的跨度长度；0 表示未知。
func _init(
	p_source_path: String = "",
	p_line: int = 0,
	p_column: int = 0,
	p_length: int = 0
) -> void:
	source_path = p_source_path
	line = maxi(p_line, 0)
	column = maxi(p_column, 0)
	length = maxi(p_length, 0)


# --- 公共方法 ---

## 配置定位范围。
## [br]
## @api public
## [br]
## @param p_source_path: 源文件或资源路径。
## [br]
## @param p_line: 起始行号，1-based；0 表示未知。
## [br]
## @param p_column: 起始列号，1-based；0 表示未知。
## [br]
## @param p_length: 同一行内的跨度长度；0 表示未知。
## [br]
## @param p_end_line: 结束行号，1-based；0 表示未知。
## [br]
## @param p_end_column: 结束列号，1-based；0 表示未知。
## [br]
## @param p_preview: 可选源码预览。
## [br]
## @param p_metadata: 调用方附加元数据。
## [br]
## @return 当前定位范围。
## [br]
## @schema p_metadata: Dictionary caller metadata.
func configure(
	p_source_path: String = "",
	p_line: int = 0,
	p_column: int = 0,
	p_length: int = 0,
	p_end_line: int = 0,
	p_end_column: int = 0,
	p_preview: String = "",
	p_metadata: Dictionary = {}
) -> RefCounted:
	source_path = p_source_path
	line = maxi(p_line, 0)
	column = maxi(p_column, 0)
	length = maxi(p_length, 0)
	end_line = maxi(p_end_line, 0)
	end_column = maxi(p_end_column, 0)
	preview = p_preview
	metadata = p_metadata.duplicate(true)
	return self


## 从字典应用字段。
## [br]
## @api public
## [br]
## @param data: 输入字典。`source` 会作为 `source_path` 的兼容别名读取。
## [br]
## @schema data: Dictionary source span fields.
func apply_dict(data: Dictionary) -> void:
	source_path = _read_source_path(data, source_path)
	line = _read_non_negative_int(data, "line", line)
	column = _read_non_negative_int(data, "column", column)
	length = _read_non_negative_int(data, "length", length)
	end_line = _read_non_negative_int(data, "end_line", end_line)
	end_column = _read_non_negative_int(data, "end_column", end_column)
	preview = GFVariantData.get_option_string(data, "preview", preview)

	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", metadata)
	metadata = GFVariantData.as_dictionary(metadata_value).duplicate(true)


## 转换为字典。
## [br]
## @api public
## [br]
## @param include_empty_fields: 为 true 时包含空字段。
## [br]
## @param include_legacy_source_alias: 为 true 时额外写入 `source` 兼容字段。
## [br]
## @return 字典副本。
## [br]
## @schema return: Dictionary source span fields.
func to_dict(include_empty_fields: bool = false, include_legacy_source_alias: bool = false) -> Dictionary:
	var result: Dictionary = {}
	if include_empty_fields or not source_path.is_empty():
		result["source_path"] = source_path
		if include_legacy_source_alias:
			result["source"] = source_path
	if include_empty_fields or line > 0:
		result["line"] = line
	if include_empty_fields or column > 0:
		result["column"] = column
	if include_empty_fields or length > 0:
		result["length"] = length
	if include_empty_fields or end_line > 0:
		result["end_line"] = end_line
	if include_empty_fields or end_column > 0:
		result["end_column"] = end_column
	if include_empty_fields or not preview.is_empty():
		result["preview"] = preview
	if include_empty_fields or not metadata.is_empty():
		result["metadata"] = metadata.duplicate(true)
	return result


## 创建当前定位范围的深拷贝。
## [br]
## @api public
## [br]
## @return 新定位范围。
func duplicate_span() -> RefCounted:
	var span: GFSourceSpan = _new_span()
	span.apply_dict(to_dict(true))
	return span


## 检查是否没有任何定位信息。
## [br]
## @api public
## [br]
## @return 没有路径且没有位置时返回 true。
func is_empty() -> bool:
	return source_path.is_empty() and line <= 0 and column <= 0 and length <= 0 and end_line <= 0 and end_column <= 0


## 检查是否有源路径。
## [br]
## @api public
## [br]
## @return 有源路径时返回 true。
func has_source_path() -> bool:
	return not source_path.is_empty()


## 检查是否有起始行号。
## [br]
## @api public
## [br]
## @return 有起始行号时返回 true。
func has_position() -> bool:
	return line > 0


## 获取有效结束行。
## [br]
## @api public
## [br]
## @return 显式 end_line 或起始行。
func get_effective_end_line() -> int:
	if end_line > 0:
		return end_line
	return line


## 获取有效结束列。
## [br]
## @api public
## [br]
## @return 显式 end_column，或根据 column 与 length 推导出的列号。
func get_effective_end_column() -> int:
	if end_column > 0:
		return end_column
	if column <= 0:
		return 0
	if length > 0:
		return column + length
	return column


## 生成人类可读定位文本。
## [br]
## @api public
## [br]
## @return 例如 `res://table.csv:4:2`。
func get_location_text() -> String:
	var label: String = source_path
	if label.is_empty():
		label = "source"
	if line > 0 and column > 0:
		return "%s:%d:%d" % [label, line, column]
	if line > 0:
		return "%s:%d" % [label, line]
	return label


## 将定位字段写入目标字典。
## [br]
## @api public
## [br]
## @param target: 目标字典。
## [br]
## @param include_empty_fields: 为 true 时包含空字段。
## [br]
## @param include_legacy_source_alias: 为 true 时额外写入 `source` 兼容字段。
## [br]
## @return 目标字典。
## [br]
## @schema target: Dictionary updated in place.
## [br]
## @schema return: Dictionary same instance as target with source span fields.
func merge_into_dictionary(
	target: Dictionary,
	include_empty_fields: bool = false,
	include_legacy_source_alias: bool = false
) -> Dictionary:
	var span_dict: Dictionary = to_dict(include_empty_fields, include_legacy_source_alias)
	for field_key: Variant in span_dict.keys():
		target[field_key] = GFVariantData.duplicate_variant(span_dict[field_key])
	return target


## 从字典创建定位范围。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @return 新定位范围。
## [br]
## @schema data: Dictionary source span fields.
static func from_dict(data: Dictionary) -> RefCounted:
	var span: GFSourceSpan = _new_span()
	span.apply_dict(data)
	return span


## 从问题对象或问题字典创建定位范围。
## [br]
## @api public
## [br]
## @param issue: GFValidationIssue 或问题字典。
## [br]
## @return 新定位范围。
## [br]
## @schema issue: Variant GFValidationIssue-like object or Dictionary.
static func from_issue(issue: Variant) -> RefCounted:
	if issue is Dictionary:
		var data: Dictionary = issue
		var source_span_value: Variant = GFVariantData.get_option_value(data, "source_span")
		if source_span_value is Dictionary:
			var nested_span: GFSourceSpan = _new_span()
			var nested_data: Dictionary = GFVariantData.as_dictionary(source_span_value)
			nested_span.apply_dict(nested_data)
			nested_span.apply_dict(data)
			return nested_span
		return from_dict(data)
	if issue is GFValidationIssue:
		var validation_issue: GFValidationIssue = issue
		return validation_issue.get_source_span()
	return _new_span()


## 创建定位范围。
## [br]
## @api public
## [br]
## @param p_source_path: 源文件或资源路径。
## [br]
## @param p_line: 起始行号，1-based；0 表示未知。
## [br]
## @param p_column: 起始列号，1-based；0 表示未知。
## [br]
## @param p_length: 同一行内的跨度长度；0 表示未知。
## [br]
## @return 新定位范围。
static func make(
	p_source_path: String = "",
	p_line: int = 0,
	p_column: int = 0,
	p_length: int = 0
) -> RefCounted:
	var span: GFSourceSpan = _new_span()
	var _configured_span: RefCounted = span.configure(p_source_path, p_line, p_column, p_length)
	return span


# --- 私有/辅助方法 ---

## 创建新的空 GFSourceSpan 实例。
## [br]
## @api private
## [br]
static func _new_span() -> GFSourceSpan:
	return GFSourceSpan.new()


## 优先读取 source_path，缺失时兼容读取 source，再缺失时返回默认路径。
## [br]
## @api private
## [br]
static func _read_source_path(data: Dictionary, default_value: String = "") -> String:
	if data.has("source_path"):
		return GFVariantData.get_option_string(data, "source_path")
	if data.has("source"):
		return GFVariantData.get_option_string(data, "source")
	return default_value


## 读取指定数值字段，将浮点值四舍五入并把结果限制为非负整数。
## [br]
## @api private
## [br]
static func _read_non_negative_int(data: Dictionary, field_name: String, default_value: int) -> int:
	if not data.has(field_name):
		return default_value
	var value: Variant = GFVariantData.get_option_value(data, field_name, default_value)
	if value is float:
		return maxi(roundi(GFVariantData.to_float(value, float(default_value))), 0)
	return maxi(GFVariantData.to_int(value, default_value), 0)
