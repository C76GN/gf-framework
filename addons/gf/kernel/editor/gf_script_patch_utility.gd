@tool

## GFScriptPatchUtility: 通用 GDScript 头部补丁工具。
##
## 用于编辑器工具安全插入或替换脚本头部注解，保持 @tool、其他注解、文档注释、
## class_name 与 extends 的顺序。它不绑定任何具体注解语义或项目目录约定。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFScriptPatchUtility
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 计算注解插入位置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_code: GDScript 源码。
## [br]
## @param options: 位置选项，支持 after_existing_annotations。
## [br]
## @return 以行为单位的插入位置。
## [br]
## @schema options: Dictionary，包含 after_existing_annotations。
static func get_annotation_insert_index(source_code: String, options: Dictionary = {}) -> int:
	return _get_annotation_insert_index(_split_source_lines(source_code), options)


## 生成注解补丁结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_code: GDScript 源码。
## [br]
## @param annotation_line: 要插入的完整注解行。
## [br]
## @param options: 补丁选项，支持 replacement_prefix、allow_duplicate、after_existing_annotations。
## [br]
## @return 补丁结果。
## [br]
## @schema options: Dictionary，包含 replacement_prefix、allow_duplicate、after_existing_annotations。
## [br]
## @schema return: Dictionary，包含 ok、changed、source_code、insert_index、removed_count、status 和 error。
static func make_annotation_patch(
	source_code: String,
	annotation_line: String,
	options: Dictionary = {}
) -> Dictionary:
	var normalized_annotation: String = annotation_line.strip_edges()
	if normalized_annotation.is_empty() or not normalized_annotation.begins_with("@"):
		return _make_patch_result(false, false, source_code, -1, 0, &"failed", "annotation_line must be a non-empty annotation")

	var allow_duplicate: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "allow_duplicate", false)
	var replacement_prefix: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		options,
		"replacement_prefix",
		_get_annotation_prefix(normalized_annotation)
	)
	var lines: PackedStringArray = _split_source_lines(source_code)
	var header_scan_end: int = _get_header_scan_end(lines)
	var filtered_lines: PackedStringArray = PackedStringArray()
	var removed_count: int = 0

	for index: int in range(lines.size()):
		var line: String = lines[index]
		if index < header_scan_end and _should_remove_annotation_line(line, normalized_annotation, replacement_prefix, allow_duplicate):
			removed_count += 1
			continue
		var _append_result: bool = filtered_lines.append(line)

	var insert_index: int = _get_annotation_insert_index(filtered_lines, options)
	if not allow_duplicate and removed_count == 0 and _header_has_annotation(filtered_lines, normalized_annotation):
		return _make_patch_result(true, false, source_code, insert_index, removed_count, &"unchanged", "")

	var _insert_result: bool = filtered_lines.insert(insert_index, normalized_annotation)
	var patched_source: String = "\n".join(filtered_lines)
	if source_code.ends_with("\n") and not patched_source.ends_with("\n"):
		patched_source += "\n"

	var changed: bool = patched_source != source_code
	return _make_patch_result(true, changed, patched_source, insert_index, removed_count, &"changed" if changed else &"unchanged", "")


## 读取脚本文件、生成注解补丁并写回。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param script_path: res:// 或 user:// 脚本路径。
## [br]
## @param annotation_line: 要插入的完整注解行。
## [br]
## @param options: 补丁和保存选项，支持 make_annotation_patch() 与 GFGeneratedArtifactReport.save_text() 的选项。
## [br]
## @return 补丁与产物报告。
## [br]
## @schema options: Dictionary，包含补丁选项和保存选项。
## [br]
## @schema return: Dictionary，包含 ok、changed、patch、artifact_report 和 error。
static func patch_script_path_annotation(
	script_path: String,
	annotation_line: String,
	options: Dictionary = {}
) -> Dictionary:
	var read_result: Dictionary = _read_text(script_path)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(read_result, "ok"):
		var read_error: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(read_result, "error")
		return _make_file_patch_result(false, false, {}, _make_failed_artifact_report(script_path, read_error), read_error)

	var source_code: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(read_result, "text")
	var patch: Dictionary = make_annotation_patch(source_code, annotation_line, options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(patch, "ok"):
		var patch_error: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(patch, "error")
		return _make_file_patch_result(false, false, patch, _make_failed_artifact_report(script_path, patch_error), patch_error)

	var changed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(patch, "changed")
	if not changed:
		var unchanged_report: Dictionary = GFGeneratedArtifactReport.make_report(
			script_path,
			GFGeneratedArtifactReport.STATUS_UNCHANGED,
			OK,
			"",
			{
				"dry_run": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run", false),
				"artifact_owner": GFGeneratedArtifactReport.OWNER_USER,
				"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id", "GFScriptPatchUtility"),
			}
		)
		return _make_file_patch_result(true, false, patch, unchanged_report, "")

	var save_options: Dictionary = options.duplicate(true)
	save_options["label"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "label", "GFScriptPatchUtility")
	save_options["artifact_owner"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "artifact_owner", GFGeneratedArtifactReport.OWNER_USER)
	save_options["generator_id"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id", "GFScriptPatchUtility")
	var artifact_report: Dictionary = GFGeneratedArtifactReport.save_text(
		script_path,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(patch, "source_code"),
		save_options
	)
	var ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(artifact_report, "success")
	return _make_file_patch_result(ok, changed, patch, artifact_report, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(artifact_report, "error"))


# --- 私有/辅助方法 ---

static func _split_source_lines(source_code: String) -> PackedStringArray:
	var lines: PackedStringArray = source_code.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	if source_code.is_empty():
		return PackedStringArray()
	if source_code.ends_with("\n") and lines.size() > 0 and lines[lines.size() - 1] == "":
		return lines
	return lines


static func _get_annotation_insert_index(lines: PackedStringArray, options: Dictionary) -> int:
	var insert_index: int = 0
	while insert_index < lines.size() and lines[insert_index].strip_edges().is_empty():
		insert_index += 1

	if insert_index < lines.size() and lines[insert_index].strip_edges() == "@tool":
		insert_index += 1

	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "after_existing_annotations", true):
		while insert_index < lines.size():
			var text: String = lines[insert_index].strip_edges()
			if text.is_empty():
				break
			if text.begins_with("@") and text != "@tool":
				insert_index += 1
				continue
			break
	return insert_index


static func _get_header_scan_end(lines: PackedStringArray) -> int:
	for index: int in range(lines.size()):
		var text: String = lines[index].strip_edges()
		if text.begins_with("class_name ") or text.begins_with("extends "):
			return index
	return lines.size()


static func _should_remove_annotation_line(
	line: String,
	annotation_line: String,
	replacement_prefix: String,
	allow_duplicate: bool
) -> bool:
	var text: String = line.strip_edges()
	if not text.begins_with("@"):
		return false
	if allow_duplicate:
		return false
	if not replacement_prefix.is_empty() and text.begins_with(replacement_prefix):
		return true
	return text == annotation_line


static func _header_has_annotation(lines: PackedStringArray, annotation_line: String) -> bool:
	var header_scan_end: int = _get_header_scan_end(lines)
	for index: int in range(header_scan_end):
		if lines[index].strip_edges() == annotation_line:
			return true
	return false


static func _get_annotation_prefix(annotation_line: String) -> String:
	var stop_index: int = annotation_line.length()
	var parenthesis_index: int = annotation_line.find("(")
	if parenthesis_index >= 0:
		stop_index = mini(stop_index, parenthesis_index)
	var space_index: int = annotation_line.find(" ")
	if space_index >= 0:
		stop_index = mini(stop_index, space_index)
	return annotation_line.substr(0, stop_index)


static func _read_text(path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path.is_empty():
		return {
			"ok": false,
			"text": "",
			"error": "script_path is empty",
		}
	if not (normalized_path.begins_with("res://") or normalized_path.begins_with("user://")):
		return {
			"ok": false,
			"text": "",
			"error": "script_path must use res:// or user://",
		}

	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"text": "",
			"error": "cannot open script: %s" % error_string(FileAccess.get_open_error()),
		}
	var text: String = file.get_as_text()
	var error: Error = file.get_error()
	file.close()
	return {
		"ok": error == OK,
		"text": text,
		"error": "" if error == OK else error_string(error),
	}


static func _make_patch_result(
	ok: bool,
	changed: bool,
	source_code: String,
	insert_index: int,
	removed_count: int,
	status: StringName,
	error: String
) -> Dictionary:
	return {
		"ok": ok,
		"changed": changed,
		"source_code": source_code,
		"insert_index": insert_index,
		"removed_count": removed_count,
		"status": status,
		"error": error,
	}


static func _make_file_patch_result(
	ok: bool,
	changed: bool,
	patch: Dictionary,
	artifact_report: Dictionary,
	error: String
) -> Dictionary:
	return {
		"ok": ok,
		"changed": changed,
		"patch": patch.duplicate(true),
		"artifact_report": artifact_report.duplicate(true),
		"error": error,
	}


static func _make_failed_artifact_report(path: String, error: String) -> Dictionary:
	return GFGeneratedArtifactReport.make_report(
		path,
		GFGeneratedArtifactReport.STATUS_FAILED,
		ERR_INVALID_PARAMETER,
		error,
		{
			"artifact_owner": GFGeneratedArtifactReport.OWNER_USER,
			"generator_id": "GFScriptPatchUtility",
		}
	)
