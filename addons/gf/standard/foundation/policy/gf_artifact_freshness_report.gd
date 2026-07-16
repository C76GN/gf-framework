## GFArtifactFreshnessReport: 通用 artifact 新鲜度与完整性报告。
##
## 检查本地 artifact 是否存在、可读、大小和 sha256 是否符合期望，以及生成时记录的
## source digest 是否仍匹配当前 source digest。它只读取本地文件元数据，不解析业务内容。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFArtifactFreshnessReport
extends RefCounted


# --- 常量 ---

const _DEFAULT_SUBJECT: String = "Artifact freshness report"


# --- 公共变量 ---

## 报告主题。
## [br]
## @api public
## [br]
## @since 7.0.0
var subject: String = _DEFAULT_SUBJECT

## artifact 条目列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema artifacts: Array[Dictionary]，每项包含 artifact_id/id、path、expected_sha256、expected_size_bytes、recorded_source_digest、current_source_digest 和 metadata。
var artifacts: Array[Dictionary] = []

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary caller-defined report metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置报告构建器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_subject: 报告主题。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined report metadata.
## [br]
## @return 当前构建器。
func configure(p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {}) -> GFArtifactFreshnessReport:
	subject = p_subject if not p_subject.strip_edges().is_empty() else _DEFAULT_SUBJECT
	metadata = p_metadata.duplicate(true)
	return self


## 清空 artifact 条目与元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	artifacts.clear()
	metadata.clear()


## 添加 artifact 条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param artifact_id: artifact ID。
## [br]
## @param path: 本地文件路径。
## [br]
## @param options: 附加字段，支持 expected_sha256、expected_size_bytes、minimum_modified_time、recorded_source_digest、current_source_digest、required 和 metadata。
## [br]
## @schema options: Dictionary artifact freshness metadata.
## [br]
## @return 添加后的条目副本。
## [br]
## @schema return: Dictionary artifact entry.
func add_artifact(artifact_id: StringName, path: String, options: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = options.duplicate(true)
	entry["id"] = artifact_id
	entry["artifact_id"] = artifact_id
	entry["path"] = path.strip_edges()
	artifacts.append(entry)
	return entry.duplicate(true)


## 批量添加 artifact 条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entries: artifact 条目数组。
## [br]
## @schema entries: Array[Dictionary] artifact entries.
## [br]
## @return 当前构建器。
func add_artifacts(entries: Array[Dictionary]) -> GFArtifactFreshnessReport:
	for entry: Dictionary in entries:
		artifacts.append(entry.duplicate(true))
	return self


## 构建新鲜度报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 报告选项，支持 include_sha256、include_modified_time、warnings_as_errors、fallback_action 和 no_action。
## [br]
## @schema options: Dictionary report options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, artifacts, issues, summary, and next_action.
func get_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"subject": subject,
		"artifact_count": artifacts.size(),
		"existing_count": 0,
		"missing_count": 0,
		"unreadable_count": 0,
		"stale_count": 0,
		"total_size_bytes": 0,
		"artifacts": [],
		"issues": [],
		"metadata": metadata.duplicate(true),
	}
	var result_artifacts: Array = GFVariantData.get_option_array(report, "artifacts")
	for index: int in range(artifacts.size()):
		var entry: Dictionary = artifacts[index]
		var artifact: Dictionary = _inspect_artifact(entry, index, options, report)
		result_artifacts.append(artifact)
		if GFVariantData.get_option_bool(artifact, "exists"):
			report["existing_count"] = GFVariantData.get_option_int(report, "existing_count") + 1
			report["total_size_bytes"] = (
				GFVariantData.get_option_int(report, "total_size_bytes")
				+ GFVariantData.get_option_int(artifact, "size_bytes")
			)
		elif GFVariantData.get_option_bool(artifact, "unreadable"):
			report["unreadable_count"] = GFVariantData.get_option_int(report, "unreadable_count") + 1
		else:
			report["missing_count"] = GFVariantData.get_option_int(report, "missing_count") + 1
		if GFVariantData.get_option_bool(artifact, "stale"):
			report["stale_count"] = GFVariantData.get_option_int(report, "stale_count") + 1
	report["artifacts"] = result_artifacts
	return GFValidationReportDictionary.finalize_report(report, subject, {
		"fallback_action": GFVariantData.get_option_string(options, "fallback_action", "Review the first artifact freshness issue."),
		"no_action": GFVariantData.get_option_string(options, "no_action", "Artifacts are fresh and match expected metadata."),
		"warnings_as_errors": GFVariantData.get_option_bool(options, "warnings_as_errors", false),
	})


## 从 artifact 条目数组创建报告构建器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entries: artifact 条目数组。
## [br]
## @param options: 构建器选项，支持 subject 和 metadata。
## [br]
## @schema entries: Array[Dictionary] artifact entries.
## [br]
## @schema options: Dictionary builder options.
## [br]
## @return 新构建器。
static func from_artifacts(entries: Array[Dictionary], options: Dictionary = {}) -> GFArtifactFreshnessReport:
	var builder: GFArtifactFreshnessReport = GFArtifactFreshnessReport.new()
	var _configured: GFArtifactFreshnessReport = builder.configure(
		GFVariantData.get_option_string(options, "subject", _DEFAULT_SUBJECT),
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	var _added: GFArtifactFreshnessReport = builder.add_artifacts(entries)
	return builder


# --- 私有/辅助方法 ---

func _inspect_artifact(
	entry: Dictionary,
	entry_index: int,
	options: Dictionary,
	report: Dictionary
) -> Dictionary:
	var path: String = GFVariantData.get_option_string(entry, "path").strip_edges()
	var artifact_id: StringName = _get_artifact_id(entry, entry_index)
	var artifact: Dictionary = {
		"artifact_id": artifact_id,
		"path": path,
		"kind": GFVariantData.get_option_string_name(entry, "kind", GFVariantData.get_option_string_name(entry, "artifact_kind")),
		"exists": false,
		"unreadable": false,
		"stale": false,
		"size_bytes": -1,
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
	}
	if path.is_empty():
		_append_issue(report, "error", &"artifact_path_empty", "artifact path is empty", artifact, {
			"entry_index": entry_index,
		})
		return artifact

	if not FileAccess.file_exists(path):
		if GFVariantData.get_option_bool(entry, "required", true):
			_append_issue(report, "error", &"artifact_missing", "artifact file is missing", artifact, {
				"entry_index": entry_index,
				"actual_value": path,
			})
		return artifact

	var size_bytes: int = _get_file_size(path)
	if size_bytes < 0:
		artifact["unreadable"] = true
		_append_issue(report, "error", &"artifact_unreadable", "artifact file cannot be read", artifact, {
			"entry_index": entry_index,
			"open_error": FileAccess.get_open_error(),
		})
		return artifact

	artifact["exists"] = true
	artifact["size_bytes"] = size_bytes
	if GFVariantData.get_option_bool(options, "include_modified_time", true):
		artifact["modified_time"] = int(FileAccess.get_modified_time(path))
	if GFVariantData.get_option_bool(options, "include_sha256", true):
		artifact["sha256"] = FileAccess.get_sha256(path).to_lower()

	_validate_size(entry, entry_index, artifact, report)
	_validate_sha256(entry, entry_index, artifact, report)
	_validate_modified_time(entry, entry_index, artifact, report)
	_validate_source_digest(entry, entry_index, artifact, report)
	return artifact


func _validate_size(entry: Dictionary, entry_index: int, artifact: Dictionary, report: Dictionary) -> void:
	var expected_size: int = _first_int(entry, PackedStringArray(["expected_size_bytes", "size_bytes", "size"]), -1)
	if expected_size < 0:
		return
	var actual_size: int = GFVariantData.get_option_int(artifact, "size_bytes", -1)
	if expected_size == actual_size:
		return
	artifact["stale"] = true
	_append_issue(report, "error", &"artifact_size_mismatch", "artifact size does not match expected metadata", artifact, {
		"entry_index": entry_index,
		"expected_size_bytes": expected_size,
		"actual_size_bytes": actual_size,
	})


func _validate_sha256(entry: Dictionary, entry_index: int, artifact: Dictionary, report: Dictionary) -> void:
	var sha_was_provided: bool = entry.has("expected_sha256") or entry.has("sha256")
	if not sha_was_provided:
		return
	var expected_sha: String = _normalize_sha256(_first_string(entry, PackedStringArray(["expected_sha256", "sha256"])))
	if expected_sha.is_empty():
		artifact["stale"] = true
		_append_issue(report, "error", &"artifact_sha256_invalid", "artifact expected sha256 metadata is invalid", artifact, {
			"entry_index": entry_index,
		})
		return
	if not artifact.has("sha256"):
		return
	var actual_sha: String = GFVariantData.get_option_string(artifact, "sha256")
	if actual_sha == expected_sha:
		return
	artifact["stale"] = true
	_append_issue(report, "error", &"artifact_sha256_mismatch", "artifact sha256 does not match expected metadata", artifact, {
		"entry_index": entry_index,
		"expected_sha256": expected_sha,
		"actual_sha256": actual_sha,
	})


func _validate_modified_time(entry: Dictionary, entry_index: int, artifact: Dictionary, report: Dictionary) -> void:
	var minimum_time: int = _first_int(entry, PackedStringArray([
		"minimum_modified_time",
		"source_modified_time",
		"current_source_modified_time",
	]), -1)
	if minimum_time < 0 or not artifact.has("modified_time"):
		return
	var actual_time: int = GFVariantData.get_option_int(artifact, "modified_time")
	if actual_time >= minimum_time:
		return
	artifact["stale"] = true
	_append_issue(report, "warning", &"artifact_older_than_source", "artifact is older than its source metadata", artifact, {
		"entry_index": entry_index,
		"expected_modified_time": minimum_time,
		"actual_modified_time": actual_time,
	})


func _validate_source_digest(entry: Dictionary, entry_index: int, artifact: Dictionary, report: Dictionary) -> void:
	var recorded_digest: String = _first_string(entry, PackedStringArray([
		"recorded_source_digest",
		"artifact_source_digest",
		"built_source_digest",
	]))
	var current_digest: String = _first_string(entry, PackedStringArray([
		"current_source_digest",
		"source_digest",
	]))
	if recorded_digest.is_empty() or current_digest.is_empty() or recorded_digest == current_digest:
		return
	artifact["stale"] = true
	_append_issue(report, "error", &"artifact_source_digest_mismatch", "artifact source digest is stale", artifact, {
		"entry_index": entry_index,
		"expected_source_digest": current_digest,
		"actual_source_digest": recorded_digest,
	})


func _append_issue(
	report: Dictionary,
	severity: String,
	kind: StringName,
	message: String,
	artifact: Dictionary,
	fields: Dictionary
) -> void:
	var issue_fields: Dictionary = {
		"artifact_id": GFVariantData.get_option_string_name(artifact, "artifact_id"),
		"path": GFVariantData.get_option_string(artifact, "path"),
		"artifact_kind": GFVariantData.get_option_string_name(artifact, "kind"),
	}
	var merged_fields: Dictionary = GFVariantData.merge_dictionary(issue_fields, fields, true)
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		severity,
		kind,
		message,
		merged_fields
	)


static func _get_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size_bytes: int = int(file.get_length())
	file.close()
	return size_bytes


static func _get_artifact_id(entry: Dictionary, entry_index: int) -> StringName:
	var artifact_id: StringName = GFVariantData.get_option_string_name(
		entry,
		"artifact_id",
		GFVariantData.get_option_string_name(entry, "id")
	)
	if artifact_id != &"":
		return artifact_id
	return StringName("artifact:%d" % entry_index)


static func _first_string(entry: Dictionary, keys: PackedStringArray, default_value: String = "") -> String:
	for key: String in keys:
		if entry.has(key):
			return GFVariantData.to_text(entry[key], default_value).strip_edges()
		var key_name: StringName = StringName(key)
		if entry.has(key_name):
			return GFVariantData.to_text(entry[key_name], default_value).strip_edges()
	return default_value


static func _first_int(entry: Dictionary, keys: PackedStringArray, default_value: int = 0) -> int:
	for key: String in keys:
		if entry.has(key):
			return GFVariantData.to_int(entry[key], default_value)
		var key_name: StringName = StringName(key)
		if entry.has(key_name):
			return GFVariantData.to_int(entry[key_name], default_value)
	return default_value


static func _normalize_sha256(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized.length() != 64:
		return ""
	for index: int in range(normalized.length()):
		if not "0123456789abcdef".contains(normalized.substr(index, 1)):
			return ""
	return normalized
