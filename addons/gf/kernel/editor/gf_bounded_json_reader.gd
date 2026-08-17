@tool

# 编辑器兼容层：保留既有四字段报告，实际有界读取由 kernel/core 公共 primitive 完成。
extends RefCounted


# --- 常量 ---

const _GF_BOUNDED_JSON_OBJECT_READER_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd"
)


# --- 框架内部方法 ---

## 读取并解析有界 JSON 对象文件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: 要读取的 res:// 或 user:// JSON 文件路径。
## [br]
## @param max_bytes: 读取前允许的最大文件字节数。
## [br]
## @param max_depth: 解析前允许的最大对象/数组嵌套深度。
## [br]
## @return: 包含 ok、data、error_kind、error 的结果。
## [br]
## @schema return: Dictionary，包含 ok、data、error_kind 和 error。
static func read_object(path: String, max_bytes: int, max_depth: int) -> Dictionary:
	return _to_legacy_report(
		_GF_BOUNDED_JSON_OBJECT_READER_SCRIPT.read_object(
			path,
			max_bytes,
			max_depth
		)
	)


## 解析有界 JSON 对象文本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param text: 要解析的 JSON 文本。
## [br]
## @param max_bytes: 允许的最大 UTF-8 字节数。
## [br]
## @param max_depth: 允许的最大对象/数组嵌套深度。
## [br]
## @return: 包含 ok、data、error_kind、error 的结果。
## [br]
## @schema return: Dictionary，包含 ok、data、error_kind 和 error。
static func parse_object(text: String, max_bytes: int, max_depth: int) -> Dictionary:
	return _to_legacy_report(
		_GF_BOUNDED_JSON_OBJECT_READER_SCRIPT.parse_object(
			text,
			max_bytes,
			max_depth
		)
	)


# --- 私有/辅助方法 ---

static func _to_legacy_report(report: Dictionary) -> Dictionary:
	var ok_value: Variant = report.get("ok")
	var data_value: Variant = report.get("data")
	var error_kind_value: Variant = report.get("error_kind")
	var error_value: Variant = report.get("error")
	var ok: bool = false
	if ok_value is bool:
		ok = ok_value
	var data: Dictionary = {}
	if data_value is Dictionary:
		data = data_value
	var error_kind: String = ""
	if error_kind_value is String:
		error_kind = error_kind_value
	var error: String = ""
	if error_value is String:
		error = error_value
	return {
		"ok": ok,
		"data": data.duplicate(true),
		"error_kind": StringName(error_kind),
		"error": error,
	}
