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

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _FILE_ENTRY_REGULAR: StringName = &"regular"
const _FILE_ENTRY_DIRECT_LINK: StringName = &"direct_link"


# --- 私有变量 ---

static var _test_before_final_replace: Callable = Callable()
static var _test_after_final_replace: Callable = Callable()
static var _test_after_file_snapshot_read: Callable = Callable()
static var _test_scan_filesystem_observer: Callable = Callable()
static var _test_temp_write_error: Error = OK
static var _test_temp_write_failures_remaining: int = 0
static var _test_temp_path_override: String = ""


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
## @param options: 报告选项，支持 written、changed、dry_run、conflict、size_bytes、metadata、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256 和 encoding；written 是独立的物理提交事实，允许 failed 报告在最终替换已发生后仍为 true；metadata 会在返回报告中编码为 JSON-safe Dictionary。
## [br]
## @schema options: Dictionary，可包含 written、changed、dry_run、conflict、size_bytes、metadata、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256 和 encoding；metadata 允许任意 Variant，返回时会通过 GFReportValueCodec 收束。
## [br]
## @return: 生成产物报告。success 只表示产物状态不是 failed；written 独立表示物理提交是否已经发生；skipped 可保留非 OK error_code 供调用方决定是否阻断。
## [br]
## @schema return: JSON-safe Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、conflict、size_bytes、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256、encoding 和 metadata。
static func make_report(
	output_path: String,
	status: StringName,
	error_code: Error = OK,
	message: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {
		"success": status != STATUS_FAILED and (error_code == OK or status == STATUS_SKIPPED),
		"path": output_path,
		"status": status,
		"error_code": error_code,
		"error": message,
		"written": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "written", false),
		"changed": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "changed", false),
		"dry_run": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run", false),
		"conflict": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "conflict", false),
		"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "size_bytes", 0),
		"artifact_owner": _read_artifact_owner(options),
		"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id"),
		"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "source_id"),
		"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "content_sha256"),
		"previous_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "previous_sha256"),
		"expected_previous_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			options,
			"expected_previous_sha256"
		),
		"encoding": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "encoding", "utf-8"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata", {}).duplicate(true),
	}
	return _to_artifact_report_boundary(report)


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
## @param options: 汇总选项，支持 include_reports 和 metadata；metadata 与可选 reports 会在返回摘要中编码为 JSON-safe 值。
## [br]
## @schema options: Dictionary，可包含 include_reports 和 metadata；metadata 允许任意 Variant，返回时会通过 GFReportValueCodec 收束。
## [br]
## @return: 批量产物报告摘要。
## [br]
## @schema return: JSON-safe Dictionary，包含 success、subject、artifact_count、status_counts、owner_counts、written_count、changed_count、dry_run_count、failed_count、skipped_count、paths、errors、metadata 和可选 reports。
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
				"status": status_key,
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
		"metadata": _to_report_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata", {})),
	}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_reports", false):
		result["reports"] = _to_artifact_report_array(reports)
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
## @param options: 保存选项，支持 overwrite_existing、expected_previous_sha256、dry_run、scan_filesystem、label、metadata、artifact_owner、generator_id、source_id 和 allowed_roots。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、expected_previous_sha256、dry_run、scan_filesystem、label、metadata、artifact_owner、generator_id、source_id 和 allowed_roots；expected_previous_sha256 存在时要求保存前目标的解码文本仍匹配该 SHA-256，空字符串表示要求目标不存在；allowed_roots 缺省时保留旧 res:// / user:// 行为，显式提供时必须是非空且全部有效的 res:// / user:// 根目录集合，并在读取、目录创建、临时写入、替换、清理与回滚的可观察边界拒绝链接或重解析组件；scan_filesystem 为 true 时，任何已发生的可观察文件系统变化都会请求一次扫描，包括最终提交后的失败和不完整回滚。该复核不持有目录句柄，也不承诺抵御恶意本地并发修改的原子性。
## [br]
## @return: 生成产物保存报告。最终替换已提交、随后复核、暂存身份检查或清理失败时，报告可同时为 failed 且 written=true；调用方重试前必须独立检查 written。
## [br]
## @schema return: JSON-safe Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、conflict、size_bytes、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256、encoding 和 metadata。
static func save_text(output_path: String, text: String, options: Dictionary = {}) -> Dictionary:
	var before_final_replace: Callable = _test_before_final_replace
	var after_final_replace: Callable = _test_after_final_replace
	var scan_filesystem_observer: Callable = _test_scan_filesystem_observer
	_test_before_final_replace = Callable()
	_test_after_final_replace = Callable()
	_test_scan_filesystem_observer = Callable()
	var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "label", "GFGeneratedArtifactReport")
	output_path = _GF_PATH_TOOLS.normalize_resource_path(output_path)
	if output_path.is_empty():
		var empty_message: String = "输出路径为空。"
		push_error("[%s] %s" % [label, empty_message])
		return make_report(output_path, STATUS_FAILED, ERR_INVALID_PARAMETER, empty_message, {
			"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
		})

	var path_validation: Dictionary = _validate_output_path(output_path, options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(path_validation, "ok", false):
		var path_error: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(path_validation, "error")
		var path_error_code: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			path_validation,
			"error_code",
			ERR_INVALID_PARAMETER
		) as Error
		push_error("[%s] %s" % [label, path_error])
		return make_report(output_path, STATUS_FAILED, path_error_code, path_error, {
			"artifact_owner": _read_artifact_owner(options),
			"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "generator_id", label),
			"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "source_id"),
			"content_sha256": _sha256_text(text),
			"encoding": "utf-8",
			"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
		})
	var enforce_physical_ownership: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		path_validation,
		"enforce_physical_ownership",
		false
	)
	var initial_read_guard_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path]),
		enforce_physical_ownership
	)
	if initial_read_guard_error != OK:
		var initial_read_guard_message: String = (
			"输出路径的物理所有权在读取前失效：%s" % output_path
		)
		push_error("[%s] %s" % [label, initial_read_guard_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			initial_read_guard_error,
			initial_read_guard_message,
			{
				"artifact_owner": _read_artifact_owner(options),
				"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					options,
					"generator_id",
					label
				),
				"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					options,
					"source_id"
				),
				"content_sha256": _sha256_text(text),
				"encoding": "utf-8",
				"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					options,
					"metadata"
				),
			}
		)
	var output_is_file: bool = FileAccess.file_exists(output_path)
	if (
		enforce_physical_ownership
		and _path_entry_exists(output_path)
		and not output_is_file
	):
		var non_file_message: String = (
			"输出路径已被非普通文件实体占用：%s" % output_path
		)
		push_error("[%s] %s" % [label, non_file_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			ERR_FILE_ALREADY_IN_USE,
			non_file_message,
			{
				"conflict": true,
				"dry_run": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					options,
					"dry_run",
					false
				),
				"artifact_owner": _read_artifact_owner(options),
				"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					options,
					"generator_id",
					label
				),
				"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					options,
					"source_id"
				),
				"content_sha256": _sha256_text(text),
				"encoding": "utf-8",
				"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					options,
					"metadata"
				),
			}
		)

	var dry_run: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run", false)
	var overwrite_existing: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "overwrite_existing", true)
	var exists: bool = output_is_file
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
	var post_read_guard_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path]),
		enforce_physical_ownership
	)
	if post_read_guard_error != OK:
		var post_read_guard_message: String = (
			"输出路径的物理所有权在读取后失效：%s" % output_path
		)
		push_error("[%s] %s" % [label, post_read_guard_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			post_read_guard_error,
			post_read_guard_message,
			{
				"dry_run": dry_run,
				"artifact_owner": _read_artifact_owner(options),
				"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					options,
					"generator_id",
					label
				),
				"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					options,
					"source_id"
				),
				"content_sha256": _sha256_text(text),
				"encoding": "utf-8",
				"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					options,
					"metadata"
				),
			}
		)
	var previous_sha256: String = _sha256_text(existing_text) if exists else ""
	var has_expected_previous_sha256: bool = options.has("expected_previous_sha256")
	var expected_previous_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		options,
		"expected_previous_sha256"
	)
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
		"previous_sha256": previous_sha256,
		"expected_previous_sha256": expected_previous_sha256,
		"encoding": "utf-8",
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
	}

	if has_expected_previous_sha256 and previous_sha256 != expected_previous_sha256:
		report_options["conflict"] = true
		var baseline_message: String = (
			"目标文件已偏离调用方读取基线，已拒绝写入：%s" % output_path
		)
		push_error("[%s] %s" % [label, baseline_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			ERR_FILE_ALREADY_IN_USE,
			baseline_message,
			report_options
		)

	if exists and changed and not overwrite_existing:
		var skipped_message: String = "目标文件已存在，已跳过：%s" % output_path
		push_warning("[%s] %s" % [label, skipped_message])
		return make_report(output_path, STATUS_SKIPPED, ERR_ALREADY_EXISTS, skipped_message, report_options)

	if dry_run:
		return make_report(output_path, status, OK, "", report_options)

	if not changed:
		return make_report(output_path, STATUS_UNCHANGED, OK, "", report_options)

	var dir_error: Error = _ensure_output_directory(
		output_path,
		enforce_physical_ownership
	)
	if dir_error != OK:
		var dir_message: String = "无法创建输出目录：%s (%s)" % [output_path.get_base_dir(), error_string(dir_error)]
		push_error("[%s] %s" % [label, dir_message])
		return make_report(output_path, STATUS_FAILED, dir_error, dir_message, report_options)

	var temp_path_report: Dictionary = _validate_staging_path(
		_make_temp_output_path(output_path),
		output_path
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(temp_path_report, "ok", false):
		var temp_path_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			temp_path_report,
			"error_code",
			ERR_INVALID_PARAMETER
		) as Error
		var temp_path_message: String = (
			"文本产物临时路径越出输出目录，已拒绝：%s" % output_path
		)
		push_error("[%s] %s" % [label, temp_path_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			temp_path_error,
			temp_path_message,
			report_options
		)
	var temp_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		temp_path_report,
		"path"
	)
	var temp_guard_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path, temp_path]),
		enforce_physical_ownership
	)
	if temp_guard_error != OK:
		var temp_guard_message: String = "输出路径的物理所有权在临时写入前失效：%s" % output_path
		push_error("[%s] %s" % [label, temp_guard_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			temp_guard_error,
			temp_guard_message,
				report_options
			)
	if _path_entry_exists(temp_path):
		var temp_collision_message: String = (
			"文本产物临时路径已被占用，已拒绝覆盖：%s" % temp_path
		)
		push_error("[%s] %s" % [label, temp_collision_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			ERR_ALREADY_EXISTS,
			temp_collision_message,
			report_options
		)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		var open_message: String = "无法写入文本产物临时文件：%s (%s)" % [temp_path, error_string(open_error)]
		push_error("[%s] %s" % [label, open_message])
		return make_report(output_path, STATUS_FAILED, open_error, open_message, report_options)

	var _stored: Variant = file.store_string(text)
	var write_error: Error = file.get_error()
	file.close()
	if _test_temp_write_failures_remaining > 0:
		_test_temp_write_failures_remaining -= 1
		if write_error == OK:
			write_error = _test_temp_write_error
	if write_error != OK:
		var failed_write_snapshot: Dictionary = _capture_file_snapshot(
			temp_path,
			enforce_physical_ownership
		)
		var cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				failed_write_snapshot,
				"size_bytes",
				-1
			),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				failed_write_snapshot,
				"sha256"
			)
		)
		if cleanup_error != OK:
			write_error = cleanup_error
		var write_message: String = "无法写入文本产物临时文件：%s (%s)" % [temp_path, error_string(write_error)]
		push_error("[%s] %s" % [label, write_message])
		return make_report(output_path, STATUS_FAILED, write_error, write_message, report_options)
	var post_write_guard_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path, temp_path]),
		enforce_physical_ownership
	)
	if post_write_guard_error != OK:
		var _cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			size_bytes,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256")
		)
		var post_write_guard_message: String = (
			"输出路径的物理所有权在临时写入后失效：%s" % output_path
		)
		push_error("[%s] %s" % [label, post_write_guard_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			post_write_guard_error,
			post_write_guard_message,
			report_options
		)
	var staged_validation_error: Error = _validate_file_snapshot(
		temp_path,
		size_bytes,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256"),
		enforce_physical_ownership
	)
	if staged_validation_error != OK:
		var cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			size_bytes,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256")
		)
		if cleanup_error != OK:
			var cleanup_message: String = "无法安全清理文本产物临时文件：%s" % temp_path
			push_error("[%s] %s" % [label, cleanup_message])
			return make_report(
				output_path,
				STATUS_FAILED,
				cleanup_error,
				cleanup_message,
				report_options
			)
		var staged_message: String = "文本产物临时文件内容校验失败：%s" % temp_path
		push_error("[%s] %s" % [label, staged_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			staged_validation_error,
			staged_message,
			report_options
		)
	var baseline_check: Dictionary = _check_target_baseline(
		output_path,
		exists,
		previous_sha256,
		enforce_physical_ownership
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(baseline_check, "ok", false):
		var cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			size_bytes,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256")
		)
		var baseline_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			baseline_check,
			"error_code",
			ERR_FILE_ALREADY_IN_USE
		) as Error
		var baseline_message: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			baseline_check,
			"error",
			"目标文件在保存期间发生变化。"
		)
		report_options["conflict"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			baseline_check,
			"conflict",
			true
		)
		if cleanup_error != OK:
			baseline_error = cleanup_error
			baseline_message = "无法安全清理文本产物临时文件：%s" % temp_path
			report_options["conflict"] = false
		push_error("[%s] %s" % [label, baseline_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			baseline_error,
			baseline_message,
			report_options
		)
	if before_final_replace.is_valid():
		var _test_callback_result: Variant = before_final_replace.call()
	var post_hook_baseline_check: Dictionary = _check_target_baseline(
		output_path,
		exists,
		previous_sha256,
		enforce_physical_ownership
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		post_hook_baseline_check,
		"ok",
		false
	):
		var post_hook_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			size_bytes,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256")
		)
		var post_hook_baseline_error: Error = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				post_hook_baseline_check,
				"error_code",
				ERR_FILE_ALREADY_IN_USE
			) as Error
		)
		var post_hook_baseline_message: String = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				post_hook_baseline_check,
				"error",
				"目标文件在最终替换前发生变化。"
			)
		)
		report_options["conflict"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			post_hook_baseline_check,
			"conflict",
			true
		)
		if post_hook_cleanup_error != OK:
			if post_hook_baseline_error == ERR_UNAUTHORIZED:
				post_hook_baseline_message = "无法替换文本产物：%s (%s)" % [
					output_path,
					error_string(post_hook_baseline_error),
				]
			else:
				post_hook_baseline_error = post_hook_cleanup_error
				post_hook_baseline_message = "无法安全清理文本产物临时文件：%s" % temp_path
				report_options["conflict"] = false
		push_error("[%s] %s" % [label, post_hook_baseline_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			post_hook_baseline_error,
			post_hook_baseline_message,
			report_options
		)
	var post_hook_temp_error: Error = _validate_file_snapshot(
		temp_path,
		size_bytes,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256"),
		enforce_physical_ownership
	)
	if post_hook_temp_error != OK:
		var post_hook_temp_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			size_bytes,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256")
		)
		var post_hook_temp_report_error: Error = (
			post_hook_temp_cleanup_error
			if post_hook_temp_cleanup_error != OK
			else post_hook_temp_error
		)
		var post_hook_temp_message: String = (
			"文本产物临时文件在最终替换前发生变化：%s" % temp_path
		)
		push_error("[%s] %s" % [label, post_hook_temp_message])
		return make_report(
			output_path,
			STATUS_FAILED,
			post_hook_temp_report_error,
			post_hook_temp_message,
			report_options
		)
	var replace_result: Dictionary = _replace_output_with_temp(
		output_path,
		temp_path,
		exists,
		previous_sha256,
		size_bytes,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report_options, "content_sha256"),
		enforce_physical_ownership,
		after_final_replace
	)
	var replace_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		replace_result,
		"error_code",
		FAILED
	) as Error
	report_options["written"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		replace_result,
		"committed",
		false
	)
	report_options["conflict"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		replace_result,
		"conflict",
		false
	)
	var filesystem_changed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		replace_result,
		"filesystem_changed",
		false
	)
	if filesystem_changed:
		_scan_filesystem_if_needed(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "scan_filesystem", true),
			scan_filesystem_observer
		)
	if replace_error != OK:
		var replace_message: String = "无法替换文本产物：%s (%s)" % [output_path, error_string(replace_error)]
		push_error("[%s] %s" % [label, replace_message])
		return make_report(output_path, STATUS_FAILED, replace_error, replace_message, report_options)
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

static func _to_artifact_report_boundary(report: Dictionary) -> Dictionary:
	var status_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status")
	if status_text.is_empty():
		status_text = "unknown"
	var artifact_owner: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "artifact_owner", String(OWNER_GENERATED))
	if artifact_owner.is_empty():
		artifact_owner = String(OWNER_GENERATED)
	return {
		"success": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "success", false),
		"path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "path"),
		"status": status_text,
		"error_code": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "error_code", OK),
		"error": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "error"),
		"written": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "written", false),
		"changed": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "changed", false),
		"dry_run": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "dry_run", false),
		"conflict": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "conflict", false),
		"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "size_bytes", 0),
		"artifact_owner": artifact_owner,
		"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "generator_id"),
		"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "source_id"),
		"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "content_sha256"),
		"previous_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "previous_sha256"),
		"expected_previous_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			report,
			"expected_previous_sha256"
		),
		"encoding": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "encoding", "utf-8"),
		"metadata": _to_report_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(report, "metadata", {})),
	}


static func _to_artifact_report_array(reports: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for report: Dictionary in reports:
		result.append(_to_artifact_report_boundary(report))
	return result


static func _to_report_dictionary(value: Dictionary) -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(value, _make_report_codec_options())


static func _make_report_codec_options() -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
		_GF_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_SUPPORT,
		{ "path_redaction": "basename" }
	)


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


static func _validate_output_path(output_path: String, options: Dictionary) -> Dictionary:
	if not (output_path.begins_with("res://") or output_path.begins_with("user://")):
		return {
			"ok": false,
			"error_code": ERR_INVALID_PARAMETER,
			"error": "输出路径必须使用 res:// 或 user://：%s" % output_path,
			"enforce_physical_ownership": false,
		}

	var allowed_roots_report: Dictionary = _read_allowed_roots(options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		allowed_roots_report,
		"ok",
		false
	):
		return {
			"ok": false,
			"error_code": ERR_INVALID_PARAMETER,
			"error": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				allowed_roots_report,
				"error",
				"allowed_roots 无效。"
			),
			"enforce_physical_ownership": true,
		}
	var enforce_physical_ownership: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		allowed_roots_report,
		"supplied",
		false
	)
	var allowed_roots: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			allowed_roots_report,
			"roots"
		)
	)
	if allowed_roots.is_empty():
		return {
			"ok": true,
			"error_code": OK,
			"error": "",
			"enforce_physical_ownership": enforce_physical_ownership,
		}

	for root_path: String in allowed_roots:
		if _GF_PATH_TOOLS.is_path_under_root(output_path, root_path, false, false):
			if _path_has_link_component(output_path):
				return {
					"ok": false,
					"error_code": ERR_UNAUTHORIZED,
					"error": "输出路径包含链接或重解析组件，已拒绝：%s" % output_path,
					"enforce_physical_ownership": true,
				}
			return {
				"ok": true,
				"error_code": OK,
				"error": "",
				"enforce_physical_ownership": true,
			}
	return {
		"ok": false,
		"error_code": ERR_INVALID_PARAMETER,
		"error": "输出路径不在允许的生成根目录内：%s" % output_path,
		"enforce_physical_ownership": true,
	}


static func _read_allowed_roots(options: Dictionary) -> Dictionary:
	var roots: PackedStringArray = PackedStringArray()
	var supplied: bool = options.has("allowed_roots") or options.has(&"allowed_roots")
	if not supplied:
		return {
			"ok": true,
			"supplied": false,
			"roots": roots,
			"error": "",
		}
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		options,
		"allowed_roots"
	)
	if not (
		raw_value is Array
		or raw_value is PackedStringArray
		or raw_value is String
		or raw_value is StringName
	):
		return {
			"ok": false,
			"supplied": true,
			"roots": roots,
			"error": "allowed_roots 必须是非空的资源根目录集合。",
		}
	if raw_value is Array:
		var raw_root_values: Array = raw_value
		for raw_root_value: Variant in raw_root_values:
			if not (raw_root_value is String or raw_root_value is StringName):
				return {
					"ok": false,
					"supplied": true,
					"roots": roots,
					"error": "allowed_roots 数组元素必须是 String 或 StringName。",
				}
	var raw_roots: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			options,
			"allowed_roots"
		)
	)
	if raw_roots.is_empty():
		return {
			"ok": false,
			"supplied": true,
			"roots": roots,
			"error": "allowed_roots 提供后不得为空。",
		}
	for raw_root: String in raw_roots:
		var root_path: String = _GF_PATH_TOOLS.normalize_root_path(raw_root)
		if (
			root_path.is_empty()
			or not (
				root_path.begins_with("res://")
				or root_path.begins_with("user://")
			)
		):
			return {
				"ok": false,
				"supplied": true,
				"roots": PackedStringArray(),
				"error": "allowed_roots 包含无效的资源根目录。",
			}
		if roots.has(root_path):
			continue
		var _append_root: bool = roots.append(root_path)
	return {
		"ok": true,
		"supplied": true,
		"roots": roots,
		"error": "",
	}


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


static func _check_target_baseline(
	output_path: String,
	expected_exists: bool,
	expected_sha256: String,
	enforce_physical_ownership: bool
) -> Dictionary:
	var preflight_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path]),
		enforce_physical_ownership
	)
	if preflight_error != OK:
		return {
			"ok": false,
			"conflict": false,
			"error_code": preflight_error,
			"error": "目标文件的物理所有权在基线复核前失效：%s" % output_path,
		}
	var current_exists: bool = _path_entry_exists(output_path)
	if current_exists != expected_exists:
		return {
			"ok": false,
			"conflict": true,
			"error_code": ERR_FILE_ALREADY_IN_USE,
			"error": "目标文件在保存期间发生创建或删除：%s" % output_path,
		}
	if not current_exists:
		return {
			"ok": true,
			"conflict": false,
			"error_code": OK,
			"error": "",
		}
	if not FileAccess.file_exists(output_path):
		return {
			"ok": false,
			"conflict": true,
			"error_code": ERR_FILE_ALREADY_IN_USE,
			"error": "目标文件在保存期间变为非普通文件实体：%s" % output_path,
		}
	var current_read: Dictionary = _read_text_if_exists(output_path)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(current_read, "ok", false):
		return {
			"ok": false,
			"conflict": false,
			"error_code": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				current_read,
				"error_code",
				ERR_CANT_OPEN
			),
			"error": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				current_read,
				"error",
				"无法重新读取目标文件。"
			),
		}
	var current_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		current_read,
		"text"
	)
	var post_read_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path]),
		enforce_physical_ownership
	)
	if post_read_error != OK:
		return {
			"ok": false,
			"conflict": false,
			"error_code": post_read_error,
			"error": "目标文件的物理所有权在基线读取后失效：%s" % output_path,
		}
	if _sha256_text(current_text) != expected_sha256:
		return {
			"ok": false,
			"conflict": true,
			"error_code": ERR_FILE_ALREADY_IN_USE,
			"error": "目标文件在保存期间发生内容变化：%s" % output_path,
		}
	return {
		"ok": true,
		"conflict": false,
		"error_code": OK,
		"error": "",
	}


static func _ensure_output_directory(
	output_path: String,
	enforce_physical_ownership: bool
) -> Error:
	var preflight_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path]),
		enforce_physical_ownership
	)
	if preflight_error != OK:
		return preflight_error
	var base_dir: String = output_path.get_base_dir()
	if base_dir.is_empty():
		return OK
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(base_dir)
	)
	if make_directory_error != OK:
		return make_directory_error
	return _get_paths_physical_error(
		PackedStringArray([base_dir, output_path]),
		enforce_physical_ownership
	)


static func _make_temp_output_path(output_path: String) -> String:
	if not _test_temp_path_override.is_empty():
		var overridden_path: String = _test_temp_path_override
		_test_temp_path_override = ""
		return overridden_path
	var base_dir: String = output_path.get_base_dir()
	var file_name: String = output_path.get_file()
	var suffix: String = ".tmp.%d" % Time.get_ticks_usec()
	return base_dir.path_join("%s%s" % [file_name, suffix])


static func _validate_staging_path(candidate_path: String, output_path: String) -> Dictionary:
	var normalized_candidate: String = _GF_PATH_TOOLS.normalize_resource_path(
		candidate_path
	)
	var normalized_output: String = _GF_PATH_TOOLS.normalize_resource_path(output_path)
	if (
		normalized_candidate.is_empty()
		or not (
			normalized_candidate.begins_with("res://")
			or normalized_candidate.begins_with("user://")
		)
		or normalized_output.is_empty()
	):
		return {
			"ok": false,
			"error_code": ERR_INVALID_PARAMETER,
			"path": "",
		}
	if (
		normalized_candidate == normalized_output
		or normalized_candidate.get_base_dir() != normalized_output.get_base_dir()
	):
		return {
			"ok": false,
			"error_code": ERR_UNAUTHORIZED,
			"path": "",
		}
	return {
		"ok": true,
		"error_code": OK,
		"path": normalized_candidate,
	}


static func _replace_output_with_temp(
	output_path: String,
	temp_path: String,
	output_exists: bool,
	expected_output_sha256: String,
	expected_temp_size: int,
	expected_temp_sha256: String,
	enforce_physical_ownership: bool,
	after_final_replace: Callable
) -> Dictionary:
	var output_absolute: String = ProjectSettings.globalize_path(output_path)
	var temp_absolute: String = ProjectSettings.globalize_path(temp_path)
	var backup_path_report: Dictionary = _validate_staging_path(
		_make_temp_output_path("%s.backup" % output_path),
		output_path
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		backup_path_report,
		"ok",
		false
	):
		var invalid_backup_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			expected_temp_size,
			expected_temp_sha256
		)
		var invalid_backup_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			backup_path_report,
			"error_code",
			ERR_INVALID_PARAMETER
		) as Error
		return _make_replace_result(
			invalid_backup_cleanup_error
			if invalid_backup_cleanup_error != OK
			else invalid_backup_error,
			false,
			false,
			invalid_backup_cleanup_error != OK
		)
	var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		backup_path_report,
		"path"
	)
	var backup_absolute: String = ProjectSettings.globalize_path(backup_path)
	var moved_existing: bool = false
	var target_baseline: Dictionary = _check_target_baseline(
		output_path,
		output_exists,
		expected_output_sha256,
		enforce_physical_ownership
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(target_baseline, "ok", false):
		var baseline_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			expected_temp_size,
			expected_temp_sha256
		)
		var baseline_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			target_baseline,
			"error_code",
			ERR_FILE_ALREADY_IN_USE
		) as Error
		return _make_replace_result(
			baseline_cleanup_error if baseline_cleanup_error != OK else baseline_error,
			false,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				target_baseline,
				"conflict",
				true
			) if baseline_cleanup_error == OK else false,
			baseline_cleanup_error != OK
		)
	var staged_validation_error: Error = _validate_file_snapshot(
		temp_path,
		expected_temp_size,
		expected_temp_sha256,
		enforce_physical_ownership
	)
	if staged_validation_error != OK:
		var staged_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			expected_temp_size,
			expected_temp_sha256
		)
		return _make_replace_result(
			staged_cleanup_error if staged_cleanup_error != OK else staged_validation_error,
			false,
			false,
			staged_cleanup_error != OK
		)
	var original_snapshot: Dictionary = {}
	if output_exists:
		original_snapshot = _capture_original_file_snapshot(
			output_path,
			enforce_physical_ownership
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			original_snapshot,
			"ok",
			false
		):
			var original_cleanup_error: Error = _remove_file_if_exists(
				temp_path,
				enforce_physical_ownership,
				expected_temp_size,
				expected_temp_sha256
			)
			var original_snapshot_error: Error = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					original_snapshot,
					"error_code",
					ERR_FILE_CORRUPT
				) as Error
			)
			return _make_replace_result(
				original_cleanup_error
				if original_cleanup_error != OK
				else original_snapshot_error,
				false,
				false,
				original_cleanup_error != OK
			)

	if output_exists:
		if _path_entry_exists(backup_path):
			var backup_collision_cleanup_error: Error = _remove_file_if_exists(
				temp_path,
				enforce_physical_ownership,
				expected_temp_size,
				expected_temp_sha256
			)
			return _make_replace_result(
				backup_collision_cleanup_error
				if backup_collision_cleanup_error != OK
				else ERR_ALREADY_EXISTS,
				false,
				false,
				backup_collision_cleanup_error != OK
			)
		var backup_guard_error: Error = _get_paths_physical_error(
			PackedStringArray([output_path, temp_path, backup_path]),
			enforce_physical_ownership
		)
		if backup_guard_error != OK:
			var backup_guard_cleanup_error: Error = _remove_file_if_exists(
				temp_path,
				enforce_physical_ownership,
				expected_temp_size,
				expected_temp_sha256
			)
			return _make_replace_result(
				backup_guard_cleanup_error if backup_guard_cleanup_error != OK else backup_guard_error,
				false,
				false,
				backup_guard_cleanup_error != OK
			)
		var backup_error: Error = DirAccess.rename_absolute(output_absolute, backup_absolute)
		if backup_error != OK:
			var backup_rename_cleanup_error: Error = _remove_file_if_exists(
				temp_path,
				enforce_physical_ownership,
				expected_temp_size,
				expected_temp_sha256
			)
			return _make_replace_result(
				backup_rename_cleanup_error if backup_rename_cleanup_error != OK else backup_error,
				false,
				false,
				backup_rename_cleanup_error != OK
			)
		moved_existing = true
		var moved_output_check: Dictionary = _check_target_baseline(
			output_path,
			false,
			"",
			enforce_physical_ownership
		)
		var backup_snapshot_error: Error = _validate_original_file_snapshot(
			backup_path,
			original_snapshot,
			enforce_physical_ownership
		)
		var moved_temp_error: Error = _validate_file_snapshot(
			temp_path,
			expected_temp_size,
			expected_temp_sha256,
			enforce_physical_ownership
		)
		if (
			not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				moved_output_check,
				"ok",
				false
			)
			or backup_snapshot_error != OK
			or moved_temp_error != OK
		):
			var moved_cleanup_error: Error = _remove_file_if_exists(
				temp_path,
				enforce_physical_ownership,
				expected_temp_size,
				expected_temp_sha256
			)
			var moved_state_error: Error = backup_snapshot_error
			if moved_state_error == OK:
				moved_state_error = moved_temp_error
			if moved_state_error == OK:
				moved_state_error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					moved_output_check,
					"error_code",
					ERR_FILE_ALREADY_IN_USE
				) as Error
			var moved_rollback_result: Dictionary = _rollback_backup(
				backup_path,
				output_path,
				original_snapshot,
				enforce_physical_ownership
			)
			var moved_rollback_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				moved_rollback_result,
				"error_code",
				FAILED
			) as Error
			if moved_rollback_error != OK:
				return _make_replace_result(
					moved_rollback_error,
					false,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						moved_output_check,
						"conflict",
						false
					) or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						moved_rollback_result,
						"conflict",
						false
					),
					true
				)
			return _make_replace_result(
				moved_cleanup_error if moved_cleanup_error != OK else moved_state_error,
				false,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					moved_output_check,
					"conflict",
					false
				) if moved_cleanup_error == OK else false,
				moved_cleanup_error != OK
			)

	var final_target_check: Dictionary = _check_target_baseline(
		output_path,
		false,
		"",
		enforce_physical_ownership
	)
	var final_temp_error: Error = _validate_file_snapshot(
		temp_path,
		expected_temp_size,
		expected_temp_sha256,
		enforce_physical_ownership
	)
	var final_backup_error: Error = OK
	if moved_existing:
		final_backup_error = _validate_original_file_snapshot(
			backup_path,
			original_snapshot,
			enforce_physical_ownership
		)
	if (
		not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(final_target_check, "ok", false)
		or final_temp_error != OK
		or final_backup_error != OK
	):
		var final_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			expected_temp_size,
			expected_temp_sha256
		)
		var final_state_error: Error = final_temp_error
		if final_state_error == OK:
			final_state_error = final_backup_error
		if final_state_error == OK:
			final_state_error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				final_target_check,
				"error_code",
				ERR_FILE_ALREADY_IN_USE
			) as Error
		if moved_existing:
			var final_rollback_result: Dictionary = _rollback_backup(
				backup_path,
				output_path,
				original_snapshot,
				enforce_physical_ownership
			)
			var final_rollback_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				final_rollback_result,
				"error_code",
				FAILED
			) as Error
			if final_rollback_error != OK:
				return _make_replace_result(
					final_rollback_error,
					false,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						final_target_check,
						"conflict",
						false
					) or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						final_rollback_result,
						"conflict",
						false
					),
					true
				)
		return _make_replace_result(
			final_cleanup_error if final_cleanup_error != OK else final_state_error,
			false,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				final_target_check,
				"conflict",
				false
			) if final_cleanup_error == OK else false,
			final_cleanup_error != OK
		)

	var replace_guard_error: Error = _get_paths_physical_error(
		PackedStringArray([output_path, temp_path, backup_path]),
		enforce_physical_ownership
	)
	if replace_guard_error != OK:
		var replace_guard_cleanup_error: Error = _remove_file_if_exists(
			temp_path,
			enforce_physical_ownership,
			expected_temp_size,
			expected_temp_sha256
		)
		if moved_existing:
			var rollback_result: Dictionary = _rollback_backup(
				backup_path,
				output_path,
				original_snapshot,
				enforce_physical_ownership
			)
			var rollback_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				rollback_result,
				"error_code",
				FAILED
			) as Error
			if rollback_error != OK:
				return _make_replace_result(
					rollback_error,
					false,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						rollback_result,
						"conflict",
						false
					),
					true
				)
		return _make_replace_result(
			replace_guard_cleanup_error if replace_guard_cleanup_error != OK else replace_guard_error,
			false,
			false,
			replace_guard_cleanup_error != OK
		)
	var replace_error: Error = DirAccess.rename_absolute(temp_absolute, output_absolute)
	if replace_error == OK:
		if after_final_replace.is_valid():
			var _test_after_replace_result: Variant = after_final_replace.call(
				output_path,
				temp_path,
				backup_path
			)
		var post_commit_error: Error = _get_paths_physical_error(
			PackedStringArray([output_path, temp_path, backup_path]),
			enforce_physical_ownership
		)
		if post_commit_error != OK:
			return _make_replace_result(post_commit_error, true)
		var consumed_temp_check: Dictionary = _check_target_baseline(
			temp_path,
			false,
			"",
			enforce_physical_ownership
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			consumed_temp_check,
			"ok",
			false
		):
			return _make_replace_result(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					consumed_temp_check,
					"error_code",
					ERR_FILE_ALREADY_IN_USE
				) as Error,
				true,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					consumed_temp_check,
					"conflict",
					false
				)
			)
		if not moved_existing:
			var unused_backup_check: Dictionary = _check_target_baseline(
				backup_path,
				false,
				"",
				enforce_physical_ownership
			)
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				unused_backup_check,
				"ok",
				false
			):
				return _make_replace_result(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
						unused_backup_check,
						"error_code",
						ERR_FILE_ALREADY_IN_USE
					) as Error,
					true,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						unused_backup_check,
						"conflict",
						false
					)
				)
		var committed_snapshot_error: Error = _validate_file_snapshot(
			output_path,
			expected_temp_size,
			expected_temp_sha256,
			enforce_physical_ownership
		)
		if committed_snapshot_error != OK:
			return _make_replace_result(committed_snapshot_error, true)
		if moved_existing:
			var backup_cleanup_error: Error = _remove_original_file_if_exists(
				backup_path,
				original_snapshot,
				enforce_physical_ownership
			)
			if backup_cleanup_error != OK:
				return _make_replace_result(backup_cleanup_error, true)
		var post_cleanup_error: Error = _validate_file_snapshot(
			output_path,
			expected_temp_size,
			expected_temp_sha256,
			enforce_physical_ownership
		)
		if post_cleanup_error != OK:
			return _make_replace_result(post_cleanup_error, true)
		var final_post_commit_guard_error: Error = _get_paths_physical_error(
			PackedStringArray([output_path, temp_path, backup_path]),
			enforce_physical_ownership
		)
		if final_post_commit_guard_error != OK:
			return _make_replace_result(final_post_commit_guard_error, true)
		for consumed_path: String in PackedStringArray([temp_path, backup_path]):
			var consumed_path_check: Dictionary = _check_target_baseline(
				consumed_path,
				false,
				"",
				enforce_physical_ownership
			)
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				consumed_path_check,
				"ok",
				false
			):
				return _make_replace_result(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
						consumed_path_check,
						"error_code",
						ERR_FILE_ALREADY_IN_USE
					) as Error,
					true,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						consumed_path_check,
						"conflict",
						false
					)
				)
		return _make_replace_result(OK, true)

	var cleanup_error: Error = _remove_file_if_exists(
		temp_path,
		enforce_physical_ownership,
		expected_temp_size,
		expected_temp_sha256
	)
	if moved_existing:
		var rollback_result: Dictionary = _rollback_backup(
			backup_path,
			output_path,
			original_snapshot,
			enforce_physical_ownership
		)
		var rollback_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			rollback_result,
			"error_code",
			FAILED
		) as Error
		if rollback_error != OK:
			return _make_replace_result(
				rollback_error,
				false,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					rollback_result,
					"conflict",
					false
				),
				true
			)
	return _make_replace_result(
		cleanup_error if cleanup_error != OK else replace_error,
		false,
		false,
		cleanup_error != OK
	)


static func _make_replace_result(
	error_code: Error,
	committed: bool,
	conflict: bool = false,
	filesystem_changed: bool = false
) -> Dictionary:
	return {
		"error_code": error_code,
		"committed": committed,
		"conflict": conflict,
		"filesystem_changed": filesystem_changed or committed,
	}


static func _make_rollback_result(error_code: Error, conflict: bool = false) -> Dictionary:
	return {
		"error_code": error_code,
		"conflict": conflict,
	}


static func _rollback_backup(
	backup_path: String,
	output_path: String,
	original_snapshot: Dictionary,
	enforce_physical_ownership: bool
) -> Dictionary:
	var guard_error: Error = _get_paths_physical_error(
		PackedStringArray([backup_path, output_path]),
		enforce_physical_ownership
	)
	if guard_error != OK:
		return _make_rollback_result(guard_error)
	var output_check: Dictionary = _check_target_baseline(
		output_path,
		false,
		"",
		enforce_physical_ownership
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(output_check, "ok", false):
		return _make_rollback_result(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				output_check,
				"error_code",
				ERR_FILE_ALREADY_IN_USE
			) as Error,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				output_check,
				"conflict",
				false
			)
		)
	var backup_validation_error: Error = _validate_original_file_snapshot(
		backup_path,
		original_snapshot,
		enforce_physical_ownership
	)
	if backup_validation_error != OK:
		return _make_rollback_result(backup_validation_error)
	var rollback_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(backup_path),
		ProjectSettings.globalize_path(output_path)
	)
	if rollback_error != OK:
		return _make_rollback_result(rollback_error)
	var restored_validation_error: Error = _validate_original_file_snapshot(
		output_path,
		original_snapshot,
		enforce_physical_ownership
	)
	if restored_validation_error != OK:
		return _make_rollback_result(restored_validation_error)
	return _make_rollback_result(
		OK if not _path_entry_exists(backup_path) else ERR_FILE_CANT_WRITE
	)


static func _remove_file_if_exists(
	path: String,
	enforce_physical_ownership: bool,
	expected_size: int,
	expected_sha256: String
) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var guard_error: Error = _get_paths_physical_error(
		PackedStringArray([path]),
		enforce_physical_ownership
	)
	if guard_error != OK:
		return guard_error
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if _path_component_is_link(absolute_path):
		return ERR_UNAUTHORIZED
	if DirAccess.dir_exists_absolute(absolute_path):
		return ERR_FILE_CANT_WRITE
	if not FileAccess.file_exists(path):
		if _path_entry_exists(path):
			return ERR_FILE_CANT_WRITE
		return OK
	if expected_size < 0 or expected_sha256.is_empty():
		return ERR_FILE_CANT_WRITE
	var snapshot_error: Error = _validate_file_snapshot(
		path,
		expected_size,
		expected_sha256,
		enforce_physical_ownership
	)
	if snapshot_error != OK:
		return snapshot_error
	var remove_error: Error = DirAccess.remove_absolute(
		absolute_path
	)
	if remove_error != OK:
		return remove_error
	var post_remove_error: Error = _get_paths_physical_error(
		PackedStringArray([path]),
		enforce_physical_ownership
	)
	if post_remove_error != OK:
		return post_remove_error
	return OK if not _path_entry_exists(path) else ERR_FILE_CANT_WRITE


static func _capture_file_snapshot(
	path: String,
	enforce_physical_ownership: bool
) -> Dictionary:
	return _capture_file_entry_snapshot(
		path,
		enforce_physical_ownership,
		false,
		true
	)


static func _capture_original_file_snapshot(
	path: String,
	enforce_physical_ownership: bool
) -> Dictionary:
	return _capture_file_entry_snapshot(
		path,
		enforce_physical_ownership,
		not enforce_physical_ownership,
		false
	)


static func _capture_file_entry_snapshot(
	path: String,
	enforce_physical_ownership: bool,
	allow_legacy_direct_link: bool,
	notify_test_hook: bool
) -> Dictionary:
	var guard_error: Error = _get_paths_physical_error(
		PackedStringArray([path]),
		enforce_physical_ownership
	)
	if guard_error != OK:
		return _make_failed_file_entry_snapshot(guard_error)
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var is_direct_link: bool = _path_component_is_link(absolute_path)
	if is_direct_link and not allow_legacy_direct_link:
		return _make_failed_file_entry_snapshot(
			ERR_UNAUTHORIZED if enforce_physical_ownership else ERR_FILE_CORRUPT
		)
	if DirAccess.dir_exists_absolute(absolute_path) or not FileAccess.file_exists(path):
		return _make_failed_file_entry_snapshot(ERR_FILE_CORRUPT)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _make_failed_file_entry_snapshot(ERR_FILE_CORRUPT)
	var size_bytes: int = file.get_length()
	var raw_bytes: PackedByteArray = file.get_buffer(size_bytes)
	file.close()
	var sha256: String = _sha256_bytes(raw_bytes)
	if notify_test_hook:
		var after_file_snapshot_read: Callable = _test_after_file_snapshot_read
		_test_after_file_snapshot_read = Callable()
		if after_file_snapshot_read.is_valid():
			var _test_callback_result: Variant = after_file_snapshot_read.call(path)
	var post_read_guard_error: Error = _get_paths_physical_error(
		PackedStringArray([path]),
		enforce_physical_ownership
	)
	if post_read_guard_error != OK:
		return _make_failed_file_entry_snapshot(post_read_guard_error)
	if (
		_path_component_is_link(absolute_path) != is_direct_link
		or DirAccess.dir_exists_absolute(absolute_path)
		or not FileAccess.file_exists(path)
	):
		return _make_failed_file_entry_snapshot(ERR_FILE_CORRUPT)
	var snapshot_ok: bool = (
		size_bytes >= 0
		and raw_bytes.size() == size_bytes
		and not sha256.is_empty()
	)
	return {
		"ok": snapshot_ok,
		"size_bytes": size_bytes,
		"sha256": sha256,
		"entry_kind": _FILE_ENTRY_DIRECT_LINK if is_direct_link else _FILE_ENTRY_REGULAR,
		"error_code": OK if snapshot_ok else ERR_FILE_CORRUPT,
	}


static func _make_failed_file_entry_snapshot(error_code: Error) -> Dictionary:
	return {
		"ok": false,
		"size_bytes": -1,
		"sha256": "",
		"entry_kind": &"",
		"error_code": error_code,
	}


static func _validate_file_snapshot(
	path: String,
	expected_size: int,
	expected_sha256: String,
	enforce_physical_ownership: bool
) -> Error:
	var snapshot: Dictionary = _capture_file_snapshot(
		path,
		enforce_physical_ownership
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(snapshot, "ok", false):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			snapshot,
			"error_code",
			ERR_FILE_CORRUPT
		) as Error
	if (
		expected_size < 0
		or expected_sha256.is_empty()
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			snapshot,
			"size_bytes",
			-1
		) != expected_size
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			snapshot,
			"sha256"
		) != expected_sha256.to_lower()
	):
		return ERR_FILE_CORRUPT
	return OK


static func _validate_original_file_snapshot(
	path: String,
	expected_snapshot: Dictionary,
	enforce_physical_ownership: bool
) -> Error:
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(expected_snapshot, "ok", false):
		return ERR_FILE_CORRUPT
	var expected_entry_kind: StringName = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			expected_snapshot,
			"entry_kind"
		)
	)
	if (
		expected_entry_kind != _FILE_ENTRY_REGULAR
		and expected_entry_kind != _FILE_ENTRY_DIRECT_LINK
	):
		return ERR_FILE_CORRUPT
	if enforce_physical_ownership and expected_entry_kind == _FILE_ENTRY_DIRECT_LINK:
		return ERR_UNAUTHORIZED
	var snapshot: Dictionary = _capture_file_entry_snapshot(
		path,
		enforce_physical_ownership,
		expected_entry_kind == _FILE_ENTRY_DIRECT_LINK,
		true
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(snapshot, "ok", false):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			snapshot,
			"error_code",
			ERR_FILE_CORRUPT
		) as Error
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			snapshot,
			"entry_kind"
		) != expected_entry_kind
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			snapshot,
			"size_bytes",
			-1
		) != _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			expected_snapshot,
			"size_bytes",
			-1
		)
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			snapshot,
			"sha256"
		) != _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			expected_snapshot,
			"sha256"
		).to_lower()
	):
		return ERR_FILE_CORRUPT
	return OK


static func _remove_original_file_if_exists(
	path: String,
	expected_snapshot: Dictionary,
	enforce_physical_ownership: bool
) -> Error:
	var validation_error: Error = _validate_original_file_snapshot(
		path,
		expected_snapshot,
		enforce_physical_ownership
	)
	if validation_error != OK:
		return validation_error
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var remove_error: Error = DirAccess.remove_absolute(absolute_path)
	if remove_error != OK:
		return remove_error
	var post_remove_error: Error = _get_paths_physical_error(
		PackedStringArray([path]),
		enforce_physical_ownership
	)
	if post_remove_error != OK:
		return post_remove_error
	return OK if not _path_entry_exists(path) else ERR_FILE_CANT_WRITE


static func _path_entry_exists(path: String) -> bool:
	if path.is_empty():
		return false
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(absolute_path)
		or _path_component_is_link(absolute_path)
	):
		return true
	var parent_path: String = absolute_path.get_base_dir()
	var entry_name: String = absolute_path.get_file()
	if parent_path.is_empty() or entry_name.is_empty():
		return false
	var parent_directory: DirAccess = DirAccess.open(parent_path)
	if parent_directory == null:
		return false
	var list_error: Error = parent_directory.list_dir_begin()
	if list_error != OK:
		return true
	var current_name: String = parent_directory.get_next()
	while not current_name.is_empty():
		if current_name == entry_name:
			parent_directory.list_dir_end()
			return true
		current_name = parent_directory.get_next()
	parent_directory.list_dir_end()
	return false


static func _get_paths_physical_error(
	paths: PackedStringArray,
	enforce_physical_ownership: bool
) -> Error:
	if not enforce_physical_ownership:
		return OK
	for path: String in paths:
		if path.is_empty() or _path_has_link_component(path):
			return ERR_UNAUTHORIZED
	return OK


static func _path_has_link_component(path: String) -> bool:
	var current: String = _trim_trailing_separators(
		ProjectSettings.globalize_path(path).replace("\\", "/")
	)
	while not current.is_empty():
		if _path_component_is_link(current):
			return true
		var parent: String = _trim_trailing_separators(
			current.get_base_dir().replace("\\", "/")
		)
		if parent.is_empty() or parent == current:
			break
		current = parent
	return false


static func _path_component_is_link(path: String) -> bool:
	var normalized: String = _trim_trailing_separators(path.replace("\\", "/"))
	var parent: String = normalized.get_base_dir()
	var component_name: String = normalized.get_file()
	if parent.is_empty() or component_name.is_empty():
		return false
	var directory: DirAccess = DirAccess.open(parent)
	if directory == null:
		return DirAccess.dir_exists_absolute(parent)
	return directory.is_link(component_name)


static func _trim_trailing_separators(path: String) -> String:
	var result: String = path
	while result.length() > 1 and result.ends_with("/"):
		result = result.substr(0, result.length() - 1)
	return result


static func _configure_test_before_final_replace(callback: Callable) -> void:
	_test_before_final_replace = callback


static func _configure_test_after_final_replace(callback: Callable) -> void:
	_test_after_final_replace = callback


static func _configure_test_after_file_snapshot_read(callback: Callable) -> void:
	_test_after_file_snapshot_read = callback


static func _configure_test_scan_filesystem_observer(callback: Callable) -> void:
	_test_scan_filesystem_observer = callback


static func _configure_test_temp_write_failure(
	error_code: Error = FAILED,
	failure_count: int = 1
) -> void:
	_test_temp_write_error = error_code
	_test_temp_write_failures_remaining = maxi(failure_count, 0)


static func _configure_test_temp_path_override(temp_path: String) -> void:
	_test_temp_path_override = temp_path


static func _reset_test_state() -> void:
	_test_before_final_replace = Callable()
	_test_after_final_replace = Callable()
	_test_after_file_snapshot_read = Callable()
	_test_scan_filesystem_observer = Callable()
	_test_temp_write_error = OK
	_test_temp_write_failures_remaining = 0
	_test_temp_path_override = ""


static func _scan_filesystem_if_needed(
	scan_filesystem: bool,
	observer: Callable = Callable()
) -> void:
	if not scan_filesystem:
		return
	if observer.is_valid():
		var _observer_result: Variant = observer.call()
	if not Engine.is_editor_hint():
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
	return _sha256_bytes(text.to_utf8_buffer())


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
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
