## GFValidationIssue: 通用校验问题条目。
##
## 用于描述配置、资源、节点树、存档载荷或编辑器工具中的单个问题。它只记录
## 严重级别、问题类别、定位信息和附加字段，不决定项目如何展示或修复问题。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFValidationIssue
extends RefCounted


# --- 枚举 ---

## 校验问题严重级别。
## [br]
## @api public
enum Severity {
	## 信息提示，不影响健康状态。
	INFO,
	## 警告，报告仍可继续使用，但不再视为完全健康。
	WARNING,
	## 错误，报告不应视为通过。
	ERROR,
}

# --- 公共变量 ---

## 严重级别。
## [br]
## @api public
var severity: Severity = Severity.ERROR

## 通用问题类别。推荐使用稳定的 snake_case 标识。
## [br]
## @api public
var kind: StringName = &""

## 可选定位键，例如行号、资源 key、节点 key 或调用方自定义标识。
## [br]
## @api public
## [br]
## @schema key: Variant caller-defined location key.
var key: Variant = null

## 可选路径，例如资源路径、节点路径或数据路径。
## [br]
## @api public
var path: String = ""

## 可选源文件或资源路径。`source` 字典字段会作为兼容别名读取。
## [br]
## @api public
var source_path: String = ""

## 可选源码起始行号，1-based；0 表示未知。
## [br]
## @api public
var line: int = 0

## 可选源码起始列号，1-based；0 表示未知。
## [br]
## @api public
var column: int = 0

## 可选源码范围长度；0 表示未知。
## [br]
## @api public
var length: int = 0

## 可选源码结束行号，1-based；0 表示未知。
## [br]
## @api public
var end_line: int = 0

## 可选源码结束列号，1-based；0 表示未知。
## [br]
## @api public
var end_column: int = 0

## 可选源码预览。
## [br]
## @api public
var preview: String = ""

## 可选主题，用于标记问题所属对象或报告域。
## [br]
## @api public
var subject: String = ""

## 面向开发者或工具 UI 的简短说明。
## [br]
## @api public
var message: String = ""

## 可选元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary caller metadata.
var metadata: Dictionary = {}

## 额外上下文字段。用于无损保留已有报告中的自定义字段。
## [br]
## @api public
## [br]
## @schema extra_fields: Dictionary caller-defined fields preserved during conversion.
var extra_fields: Dictionary = {}


# --- 私有变量 ---

var _source_span_metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建校验问题条目。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param p_severity: 严重级别，可传入 Severity、int 或字符串。
## [br]
## @param p_kind: 问题类别。
## [br]
## @param p_message: 问题说明。
## [br]
## @param p_key: 可选定位键；可变集合会在创建时复制为问题自身拥有的快照。
## [br]
## @param p_path: 可选路径。
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @schema p_severity: Variant Severity, int, or string.
## [br]
## @schema p_key: Variant caller-defined location key.
## [br]
## @schema p_metadata: Dictionary caller metadata.
func _init(
	p_severity: Variant = Severity.ERROR,
	p_kind: StringName = &"",
	p_message: String = "",
	p_key: Variant = null,
	p_path: String = "",
	p_metadata: Dictionary = {}
) -> void:
	severity = normalize_severity(p_severity)
	kind = p_kind
	message = p_message
	key = GFVariantData.duplicate_variant(p_key)
	path = p_path
	metadata = p_metadata.duplicate(true)


# --- 公共方法 ---

## 配置问题条目并返回自身，便于链式构造。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param p_severity: 严重级别，可传入 Severity、int 或字符串。
## [br]
## @param p_kind: 问题类别。
## [br]
## @param p_message: 问题说明。
## [br]
## @param p_key: 可选定位键；可变集合会在配置时复制为问题自身拥有的快照。
## [br]
## @param p_path: 可选路径。
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @return 当前问题条目。
## [br]
## @schema p_severity: Variant Severity, int, or string.
## [br]
## @schema p_key: Variant caller-defined location key.
## [br]
## @schema p_metadata: Dictionary caller metadata.
func configure(
	p_severity: Variant,
	p_kind: StringName,
	p_message: String,
	p_key: Variant = null,
	p_path: String = "",
	p_metadata: Dictionary = {}
) -> RefCounted:
	severity = normalize_severity(p_severity)
	kind = p_kind
	message = p_message
	key = GFVariantData.duplicate_variant(p_key)
	path = p_path
	metadata = p_metadata.duplicate(true)
	return self


## 从字典应用字段。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @schema data: Dictionary validation issue fields.
func apply_dict(data: Dictionary) -> void:
	var source_span_value: Variant = GFVariantData.get_option_value(data, "source_span")
	if source_span_value is Dictionary:
		var source_span_data: Dictionary = GFVariantData.as_dictionary(source_span_value)
		_apply_source_span(source_span_data, true)
	severity = normalize_severity(GFVariantData.get_option_value(data, "severity", severity))
	kind = _read_string_name(data, "kind", kind)
	key = GFVariantData.duplicate_variant(GFVariantData.get_option_value(data, "key", key))
	path = GFVariantData.get_option_string(data, "path", path)
	_apply_source_span(data)
	subject = GFVariantData.get_option_string(data, "subject", subject)
	message = GFVariantData.get_option_string(data, "message", message)

	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", metadata)
	metadata = GFVariantData.as_dictionary(metadata_value).duplicate(true)
	extra_fields.clear()
	for field_key: Variant in data.keys():
		if _is_reserved_field(GFVariantData.to_text(field_key)):
			continue
		extra_fields[field_key] = GFVariantData.duplicate_variant(data[field_key])


## 转换为字典。
## [br]
## @api public
## [br]
## @param include_empty_fields: 为 true 时包含空的可选字段。
## [br]
## @return 字典副本。
## [br]
## @schema return: Dictionary validation issue fields.
func to_dict(include_empty_fields: bool = false) -> Dictionary:
	var result: Dictionary = {
		"severity": severity_to_string(severity),
		"message": message,
	}
	var kind_key: String = get_kind_key()
	if include_empty_fields or not kind_key.is_empty():
		result["kind"] = kind_key
	if include_empty_fields or key != null:
		result["key"] = GFVariantData.duplicate_variant(key)
	if include_empty_fields or not path.is_empty():
		result["path"] = path
	_add_source_span_fields(result, include_empty_fields)
	if include_empty_fields or not subject.is_empty():
		result["subject"] = subject

	for field_key: Variant in extra_fields.keys():
		if _is_reserved_field(GFVariantData.to_text(field_key)):
			continue
		result[field_key] = GFVariantData.duplicate_variant(extra_fields[field_key])

	if include_empty_fields or not metadata.is_empty():
		result["metadata"] = metadata.duplicate(true)
	return result


## 创建当前问题条目的深拷贝。
## [br]
## @api public
## [br]
## @return 新问题条目。
func duplicate_issue() -> RefCounted:
	var issue: GFValidationIssue = GFValidationIssue.new()
	issue.apply_dict(to_dict(true))
	return issue


## 设置源码定位范围。
## [br]
## @api public
## [br]
## @param source_span: GFSourceSpan 或兼容字典。
## [br]
## @return 当前问题条目。
## [br]
## @schema source_span: Variant GFSourceSpan-like object or Dictionary.
func set_source_span(source_span: Variant) -> RefCounted:
	if source_span is GFSourceSpan:
		var typed_span: GFSourceSpan = source_span
		_apply_source_span(typed_span.to_dict(true), true)
	elif source_span is Dictionary:
		var source_span_data: Dictionary = source_span
		_apply_source_span(source_span_data, true)
	return self


## 获取源码定位范围副本。
## [br]
## @api public
## [br]
## @return GFSourceSpan。
func get_source_span() -> RefCounted:
	var span: GFSourceSpan = _make_source_span()
	return span


## 检查问题是否有源码行号。
## [br]
## @api public
## [br]
## @return 有行号时返回 true。
func has_source_position() -> bool:
	return line > 0


## 获取人类可读定位文本。
## [br]
## @api public
## [br]
## @return 例如 `res://table.csv:4:2`。
func get_location_text() -> String:
	var span: GFSourceSpan = _make_source_span()
	return span.get_location_text()


## 获取统计用问题类别。
## [br]
## @api public
## [br]
## @return 优先返回 kind，最后返回 unknown。
func get_kind_key() -> String:
	if kind != &"":
		return String(kind)
	return "unknown"


## 是否为错误。
## [br]
## @api public
## [br]
## @return 严重级别为 ERROR 时返回 true。
func is_error() -> bool:
	return severity == Severity.ERROR


## 是否为警告。
## [br]
## @api public
## [br]
## @return 严重级别为 WARNING 时返回 true。
func is_warning() -> bool:
	return severity == Severity.WARNING


## 是否为信息。
## [br]
## @api public
## [br]
## @return 严重级别为 INFO 时返回 true。
func is_info() -> bool:
	return severity == Severity.INFO


## 将任意输入归一为 Severity。
## [br]
## @api public
## [br]
## @param value: Severity、int 或字符串。
## [br]
## @return 归一后的严重级别。
## [br]
## @schema value: Variant Severity, int, string, or null.
static func normalize_severity(value: Variant) -> Severity:
	if value == null:
		return Severity.ERROR
	if typeof(value) == TYPE_INT:
		var int_value: int = value
		var severity_index: int = clampi(int_value, Severity.INFO, Severity.ERROR)
		match severity_index:
			Severity.INFO:
				return Severity.INFO
			Severity.WARNING:
				return Severity.WARNING
			_:
				return Severity.ERROR

	var text: String = GFVariantData.to_text(value).strip_edges().to_lower()
	match text:
		"info", "information", "note":
			return Severity.INFO
		"warn", "warning":
			return Severity.WARNING
		"error", "err", "fatal":
			return Severity.ERROR
		_:
			return Severity.ERROR


## 将严重级别转换为稳定字符串。
## [br]
## @api public
## [br]
## @param value: Severity、int 或字符串。
## [br]
## @return info、warning 或 error。
## [br]
## @schema value: Variant Severity, int, string, or null.
static func severity_to_string(value: Variant) -> String:
	match normalize_severity(value):
		Severity.INFO:
			return "info"
		Severity.WARNING:
			return "warning"
		_:
			return "error"


## 从字典创建问题条目。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @return 新问题条目。
## [br]
## @schema data: Dictionary validation issue fields.
static func from_dict(data: Dictionary) -> RefCounted:
	var issue: GFValidationIssue = GFValidationIssue.new()
	issue.apply_dict(data)
	return issue


# --- 私有/辅助方法 ---

static func _read_string_name(data: Dictionary, field_name: String, default_value: StringName = &"") -> StringName:
	if not data.has(field_name):
		return default_value
	var value: Variant = GFVariantData.get_option_value(data, field_name, "")
	if value == null:
		return default_value
	return GFVariantData.to_string_name(value)


func _apply_source_span(data: Dictionary, include_metadata: bool = false) -> void:
	source_path = _read_source_path(data, source_path)
	line = _read_non_negative_int(data, "line", line)
	column = _read_non_negative_int(data, "column", column)
	length = _read_non_negative_int(data, "length", length)
	end_line = _read_non_negative_int(data, "end_line", end_line)
	end_column = _read_non_negative_int(data, "end_column", end_column)
	preview = GFVariantData.get_option_string(data, "preview", preview)
	if include_metadata:
		var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", {})
		_source_span_metadata = GFVariantData.as_dictionary(metadata_value).duplicate(true)


func _add_source_span_fields(result: Dictionary, include_empty_fields: bool) -> void:
	var span: GFSourceSpan = _make_source_span()
	var span_dict: Dictionary = span.to_dict(include_empty_fields, true)
	for field_key: Variant in span_dict.keys():
		if field_key == "metadata":
			continue
		result[field_key] = GFVariantData.duplicate_variant(span_dict[field_key])
	if not span_dict.is_empty():
		result["source_span"] = span.to_dict(include_empty_fields, false)


static func _read_source_path(data: Dictionary, default_value: String = "") -> String:
	if data.has("source_path"):
		return GFVariantData.get_option_string(data, "source_path")
	if data.has("source"):
		return GFVariantData.get_option_string(data, "source")
	return default_value


static func _read_non_negative_int(data: Dictionary, field_name: String, default_value: int) -> int:
	if not data.has(field_name):
		return default_value
	var value: Variant = GFVariantData.get_option_value(data, field_name, default_value)
	if value is float:
		return maxi(roundi(GFVariantData.to_float(value, float(default_value))), 0)
	return maxi(GFVariantData.to_int(value, default_value), 0)


func _make_source_span() -> GFSourceSpan:
	var span: GFSourceSpan = GFSourceSpan.new()
	var _configured_span: RefCounted = span.configure(
		source_path,
		line,
		column,
		length,
		end_line,
		end_column,
		preview,
		_source_span_metadata
	)
	return span


static func _is_reserved_field(field_name: String) -> bool:
	return (
		field_name == "severity"
		or field_name == "kind"
		or field_name == "code"
		or field_name == "type"
		or field_name == "key"
		or field_name == "path"
		or field_name == "source"
		or field_name == "source_path"
		or field_name == "line"
		or field_name == "column"
		or field_name == "length"
		or field_name == "end_line"
		or field_name == "end_column"
		or field_name == "preview"
		or field_name == "source_span"
		or field_name == "subject"
		or field_name == "message"
		or field_name == "metadata"
	)
