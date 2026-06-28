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

## 框架或项目工具生成并可安全重建的产物。
## [br]
## @api public
## [br]
## @since 6.0.0
const OWNER_GENERATED: StringName = &"generated"

## 用户手写或需要人工维护的产物。
## [br]
## @api public
## [br]
## @since 6.0.0
const OWNER_USER: StringName = &"user"

## 外部工具或框架边界外来源管理的产物。
## [br]
## @api public
## [br]
## @since 6.0.0
const OWNER_EXTERNAL: StringName = &"external"

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
## @param options: 报告选项，支持 written、changed、dry_run、size_bytes、metadata、artifact_owner、generator_id、source_id、content_sha256、previous_sha256 和 encoding。
## [br]
## @schema options: Dictionary，可包含 written、changed、dry_run、size_bytes、metadata、artifact_owner、generator_id、source_id、content_sha256、previous_sha256 和 encoding。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、encoding 和 metadata。
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
		"artifact_owner": _read_artifact_owner(options),
		"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id"),
		"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "source_id"),
		"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "content_sha256"),
		"previous_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "previous_sha256"),
		"encoding": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "encoding", "utf-8"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata", {}).duplicate(true),
	}


## 汇总多份生成产物报告。
## [br]
## 用于访问器生成、导表导出或批处理工具在一次操作后得到稳定的状态计数、
## 写入数量、dry-run 数量和产物所有权分布。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param reports: make_report() 或 save_text() 返回的报告数组。
## [br]
## @schema reports: Array of Dictionary artifact reports.
## [br]
## @param subject: 汇总主题。
## [br]
## @param options: 汇总选项，支持 include_reports 和 metadata。
## [br]
## @schema options: Dictionary，可包含 include_reports 和 metadata。
## [br]
## @return: 批量产物报告摘要。
## [br]
## @schema return: Dictionary，包含 success、subject、artifact_count、status_counts、owner_counts、written_count、changed_count、dry_run_count、failed_count、skipped_count、paths、errors、metadata 和可选 reports。
static func summarize_reports(
	reports: Array[Dictionary],
	subject: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var status_counts: Dictionary = {}
	var owner_counts: Dictionary = {}
	var paths: PackedStringArray = PackedStringArray()
	var errors: Array[Dictionary] = []
	var written_count: int = 0
	var changed_count: int = 0
	var dry_run_count: int = 0
	var failed_count: int = 0
	var skipped_count: int = 0

	for report: Dictionary in reports:
		var status: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(report, "status", &"")
		var status_key: String = String(status)
		if status_key.is_empty():
			status_key = "unknown"
		status_counts[status_key] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(status_counts, status_key, 0) + 1
		if status == STATUS_FAILED:
			failed_count += 1
		elif status == STATUS_SKIPPED:
			skipped_count += 1

		var artifact_owner: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "artifact_owner", String(OWNER_GENERATED))
		owner_counts[artifact_owner] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(owner_counts, artifact_owner, 0) + 1

		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "written", false):
			written_count += 1
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "changed", false):
			changed_count += 1
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "dry_run", false):
			dry_run_count += 1

		var output_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "path")
		if not output_path.is_empty():
			var _append_path: bool = paths.append(output_path)

		var error_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "error")
		var error_code: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "error_code", OK)
		if not error_text.is_empty() or error_code != OK:
			errors.append({
				"path": output_path,
				"status": status,
				"error_code": error_code,
				"error": error_text,
			})

	var result: Dictionary = {
		"success": failed_count == 0,
		"subject": subject,
		"artifact_count": reports.size(),
		"status_counts": _sort_dictionary_by_key(status_counts),
		"owner_counts": _sort_dictionary_by_key(owner_counts),
		"written_count": written_count,
		"changed_count": changed_count,
		"dry_run_count": dry_run_count,
		"failed_count": failed_count,
		"skipped_count": skipped_count,
		"paths": _packed_to_array(paths),
		"errors": errors,
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata", {}).duplicate(true),
	}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_reports", false):
		result["reports"] = reports.duplicate(true)
	return result


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
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem、label、metadata、artifact_owner、generator_id 和 source_id。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem、label、metadata、artifact_owner、generator_id 和 source_id。
## [br]
## @return: 生成产物保存报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、encoding 和 metadata。
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
	var existing_read: Dictionary = _read_text_if_exists(output_path) if exists else {
		"ok": true,
		"text": "",
		"error_code": OK,
		"error": "",
	}
	if exists and not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(existing_read, "ok", false):
		var read_message: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(existing_read, "error", "无法读取已有文本产物。")
		var read_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(existing_read, "error_code", ERR_CANT_OPEN) as Error
		push_error("[%s] %s" % [label, read_message])
		return make_report(output_path, STATUS_FAILED, read_error, read_message, {
			"dry_run": dry_run,
			"artifact_owner": _read_artifact_owner(options),
			"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id", label),
			"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "source_id"),
			"content_sha256": _sha256_text(text),
			"encoding": "utf-8",
			"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
		})
	var existing_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(existing_read, "text")
	var status: StringName = _resolve_text_status(exists, existing_text, text)
	var changed: bool = status != STATUS_UNCHANGED
	var size_bytes: int = text.to_utf8_buffer().size()
	var report_options: Dictionary = {
		"changed": changed,
		"dry_run": dry_run,
		"size_bytes": size_bytes,
		"artifact_owner": _read_artifact_owner(options),
		"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id", label),
		"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "source_id"),
		"content_sha256": _sha256_text(text),
		"previous_sha256": _sha256_text(existing_text) if exists else "",
		"encoding": "utf-8",
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


static func _read_text_if_exists(output_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return {
			"ok": false,
			"text": "",
			"error_code": open_error,
			"error": "无法读取已有文本产物：%s (%s)" % [output_path, error_string(open_error)],
		}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return {
			"ok": false,
			"text": "",
			"error_code": read_error,
			"error": "读取已有文本产物失败：%s (%s)" % [output_path, error_string(read_error)],
		}
	return {
		"ok": true,
		"text": text,
		"error_code": OK,
		"error": "",
	}


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


static func _read_artifact_owner(options: Dictionary) -> StringName:
	var raw_owner: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "artifact_owner", OWNER_GENERATED)
	if raw_owner == &"":
		return OWNER_GENERATED
	return raw_owner


static func _sha256_text(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(text.to_utf8_buffer())
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func _sort_dictionary_by_key(data: Dictionary) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _append_key: bool = keys.append(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_key))
	keys.sort()
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(data.get(key), true)
	return result


static func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
