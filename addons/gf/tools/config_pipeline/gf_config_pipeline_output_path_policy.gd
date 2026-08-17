# Config Pipeline 输出路径的包内规范化与 URI 合同。
#
# 该策略只处理字符串身份和框架源码保护，不访问文件系统，也不承诺真实写入成功。
extends RefCounted


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 框架内部方法 ---

## 将 Config Pipeline 输出路径解析为同一 resource URI 域内的规范身份。
##
## @api framework_internal
## [br]
## @layer tools
## [br]
## @param output_path: 待解析的输出路径。
## [br]
## @param options: 路径策略选项；可包含 allow_parent_output_path 与 allow_gf_source_output。
## [br]
## @param artifact_label: 用于诊断的产物标签。
## [br]
## @schema options: Dictionary；未知字段由所属的公开入口验证，本策略只读取路径相关字段。
## [br]
## @return 闭合的路径解析结果。
## [br]
## @schema return: Dictionary，成功包含 success、path、scheme、error_code 和 error；失败额外包含 input_path。
static func resolve_output_path(
	output_path: String,
	options: Dictionary,
	artifact_label: String
) -> Dictionary:
	var raw_path: String = output_path.strip_edges().replace("\\", "/")
	if raw_path.is_empty():
		return _make_failure(output_path, "%s输出路径为空。" % artifact_label)

	var scheme: StringName = _resolve_supported_scheme(raw_path)
	if scheme == &"":
		return _make_failure(
			output_path,
			"%s输出路径必须使用 res:// 或 user://：%s。" % [artifact_label, output_path]
		)
	var scheme_prefix: String = "%s://" % String(scheme)
	var body: String = raw_path.substr(scheme_prefix.length())
	if body.is_empty() or body.begins_with("/") or body.ends_with("/") or body.contains("://"):
		return _make_failure(
			output_path,
			"%s输出路径必须是 res:// 或 user:// 下的文件 URI：%s。" % [artifact_label, output_path]
		)

	var parent_error: String = _validate_parent_segments(
		body,
		GFVariantData.get_option_bool(options, "allow_parent_output_path", false),
		artifact_label,
		output_path
	)
	if not parent_error.is_empty():
		return _make_failure(output_path, parent_error)

	var canonical_path: String = _GF_PATH_TOOLS.normalize_resource_path(raw_path)
	var canonical_body: String = (
		canonical_path.substr(scheme_prefix.length())
		if canonical_path.begins_with(scheme_prefix)
		else ""
	)
	if canonical_body.is_empty():
		return _make_failure(
			output_path,
			"%s输出路径规范化后必须仍指向 resource URI 根内的文件：%s。" % [artifact_label, output_path]
		)
	if (
		_is_gf_source_output_path(canonical_path)
		and not GFVariantData.get_option_bool(options, "allow_gf_source_output", false)
	):
		return _make_failure(
			output_path,
			"%s输出路径不能写入 GF 框架源码目录：%s。" % [artifact_label, output_path]
		)
	return {
		"success": true,
		"path": canonical_path,
		"scheme": scheme,
		"error_code": OK,
		"error": "",
	}


# --- 私有/辅助方法 ---

static func _resolve_supported_scheme(path: String) -> StringName:
	if path.begins_with("res://"):
		return &"res"
	if path.begins_with("user://"):
		return &"user"
	return &""


static func _validate_parent_segments(
	body: String,
	allow_parent_output_path: bool,
	artifact_label: String,
	output_path: String
) -> String:
	var depth: int = 0
	for part: String in body.split("/", true):
		if part.is_empty() or part == ".":
			continue
		if part != "..":
			depth += 1
			continue
		if not allow_parent_output_path:
			return "%s输出路径不能包含父级片段：%s。" % [artifact_label, output_path]
		if depth <= 0:
			return "%s输出路径不能越过 resource URI 根目录：%s。" % [artifact_label, output_path]
		depth -= 1
	return ""


static func _is_gf_source_output_path(path: String) -> bool:
	var lower_path: String = path.to_lower()
	const GF_SOURCE_ROOT: String = "res://addons/gf"
	return lower_path == GF_SOURCE_ROOT or lower_path.begins_with(GF_SOURCE_ROOT + "/")


static func _make_failure(output_path: String, message: String) -> Dictionary:
	return {
		"success": false,
		"path": "",
		"input_path": output_path,
		"scheme": &"",
		"error_code": ERR_INVALID_PARAMETER,
		"error": message,
	}
