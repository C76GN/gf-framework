@tool

## GFGeneratedArtifactReport: 生成文本产物的保存报告辅助。
##
## 用于编辑器代码生成、导表导出或项目工具在写入前后获得统一的
## new / changed / unchanged / skipped / failed 状态，不绑定具体生成器语义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
## [br]
## @layer kernel/editor
class_name GFGeneratedArtifactReport
extends RefCounted


# --- 常量 ---

## 目标文件不存在，本次产物是新增内容。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_NEW: StringName = &"new"

## 目标文件存在且内容不同。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_CHANGED: StringName = &"changed"

## 目标文件存在且内容相同。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_UNCHANGED: StringName = &"unchanged"

## 目标文件因保存策略跳过。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_SKIPPED: StringName = &"skipped"

## 产物写入或准备失败。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_FAILED: StringName = &"failed"

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 创建统一生成产物报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param output_path: 产物输出路径。
## [br]
## @param status: 产物状态。
## [br]
## @param error_code: Godot Error 错误码。
## [br]
## @param message: 错误或跳过说明。
## [br]
## @param options: 报告选项，支持 written、changed、dry_run、size_bytes 和 metadata。
## [br]
## @schema options: Dictionary，可包含 written、changed、dry_run、size_bytes 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
static func make_report(
	output_path: String,
	status: StringName,
	error_code: Error = OK,
	message: String = "",
	options: Dictionary = {}
) -> Dictionary:
	return {
		"success": error_code == OK and status != STATUS_FAILED,
		"path": output_path,
		"status": status,
		"error_code": error_code,
		"error": message,
		"written": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "written", false),
		"changed": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "changed", false),
		"dry_run": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run", false),
		"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "size_bytes", 0),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata", {}).duplicate(true),
	}


## 保存文本产物并返回统一报告。
## [br]
## dry_run 为 true 时只比较目标文件状态，不创建目录或写入文件。
## overwrite_existing 为 false 且目标文件需要改写时返回 skipped / ERR_ALREADY_EXISTS。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param output_path: 产物输出路径。
## [br]
## @param text: 要写入的文本内容。
## [br]
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem、label 和 metadata。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem、label 和 metadata。
## [br]
## @return: 生成产物保存报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
static func save_text(output_path: String, text: String, options: Dictionary = {}) -> Dictionary:
	var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "label", "GFGeneratedArtifactReport")
	if output_path.is_empty():
		var empty_message: String = "输出路径为空。"
		push_error("[%s] %s" % [label, empty_message])
		return make_report(output_path, STATUS_FAILED, ERR_INVALID_PARAMETER, empty_message, {
			"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
		})

	var dry_run: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run", false)
	var overwrite_existing: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "overwrite_existing", true)
	var exists: bool = FileAccess.file_exists(output_path)
	var existing_text: String = _read_text_if_exists(output_path) if exists else ""
	var status: StringName = _resolve_text_status(exists, existing_text, text)
	var changed: bool = status != STATUS_UNCHANGED
	var size_bytes: int = text.to_utf8_buffer().size()
	var report_options: Dictionary = {
		"changed": changed,
		"dry_run": dry_run,
		"size_bytes": size_bytes,
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
	}

	if exists and changed and not overwrite_existing:
		var skipped_message: String = "目标文件已存在，已跳过：%s" % output_path
		push_warning("[%s] %s" % [label, skipped_message])
		return make_report(output_path, STATUS_SKIPPED, ERR_ALREADY_EXISTS, skipped_message, report_options)

	if dry_run:
		return make_report(output_path, status, OK, "", report_options)

	if not changed:
		return make_report(output_path, STATUS_UNCHANGED, OK, "", report_options)

	var dir_error: Error = _ensure_output_directory(output_path)
	if dir_error != OK:
		var dir_message: String = "无法创建输出目录：%s (%s)" % [output_path.get_base_dir(), error_string(dir_error)]
		push_error("[%s] %s" % [label, dir_message])
		return make_report(output_path, STATUS_FAILED, dir_error, dir_message, report_options)

	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		var open_message: String = "无法写入文本产物：%s (%s)" % [output_path, error_string(open_error)]
		push_error("[%s] %s" % [label, open_message])
		return make_report(output_path, STATUS_FAILED, open_error, open_message, report_options)

	var _stored: bool = file.store_string(text)
	file.close()
	report_options["written"] = true
	_scan_filesystem_if_needed(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "scan_filesystem", true))
	return make_report(output_path, status, OK, "", report_options)


## 从报告读取 Error 错误码。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param report: make_report() 或 save_text() 返回的报告。
## [br]
## @schema report: Dictionary，包含 error_code 字段。
## [br]
## @return: Godot Error 错误码。
static func get_error_code(report: Dictionary) -> Error:
	var error_value: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "error_code", OK)
	return error_value as Error


# --- 私有/辅助方法 ---

static func _resolve_text_status(exists: bool, existing_text: String, text: String) -> StringName:
	if not exists:
		return STATUS_NEW
	if existing_text == text:
		return STATUS_UNCHANGED
	return STATUS_CHANGED


static func _read_text_if_exists(output_path: String) -> String:
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _ensure_output_directory(output_path: String) -> Error:
	var base_dir: String = output_path.get_base_dir()
	if base_dir.is_empty():
		return OK
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))


static func _scan_filesystem_if_needed(scan_filesystem: bool) -> void:
	if not scan_filesystem or not Engine.is_editor_hint():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem != null:
		filesystem.scan()
