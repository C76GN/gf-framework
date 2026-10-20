@tool

# Asset Browser 的一次性直接依赖与入站引用证据任务；不加载资源、不修改 UID 表或源文件。
extends RefCounted


# --- 私有变量 ---

## 当前批次的规范路径，排序去重后最多 100 项；不保留调用方容器。
## [br]
## @api private
var _paths: PackedStringArray = PackedStringArray()

## 整批共享的正数预算；调用方只能缩小默认上限，零值不会解除限制。
## [br]
## @api private
var _limits: Dictionary = {}

## 已封存的范围和排除目录，供扫描及结果覆盖声明共用。
## [br]
## @api private
var _scope: String = ""

## 本次实际交给引用扫描器的忽略目录。
## [br]
## @api private
var _ignored_roots: Array[String] = []

## 尚未消耗的共享文件读取准入字节；原生依赖查询内部 I/O 不由此预算抢占。
## [br]
## @api private
var _remaining_bytes: int = 0

## 尚未解释的直接依赖描述数，缺失、重复或无法识别的描述同样扣减。
## [br]
## @api private
var _remaining_edges: int = 0

## 正在处理的所选资源下标；每次 step 最多处理一个资源。
## [br]
## @api private
var _cursor: int = 0

## 一次多目标扫描产生的临时入站证据，完成投影后释放。
## [br]
## @api private
var _references: Dictionary = {}

## 仅含纯数据的候选结果，完成前不能领取。
## [br]
## @api private
var _report: Dictionary = {}

## 开始、取消或领取后任务进入终态；不允许重新使用同一个任务。
## [br]
## @api private
var _started: bool = false

## 取消后不再扫描或发布任何候选数据。
## [br]
## @api private
var _cancelled: bool = false

## 全部所选资源已处理或输入拒绝；仍需通过调用方的上下文检查才能展示。
## [br]
## @api private
var _finished: bool = false


# --- 框架内部方法 ---

## 捕获显式选择与范围；非法路径或超额选择整体拒绝，避免静默扩大扫描。
## [br]
## @api framework_internal
## [br]
## @param paths: 当前有效页面所选的独立 res:// 文件路径。
## [br]
## @param options: 范围、插件开关与可缩小的整批预算。
## [br]
## @schema options: Dictionary，支持 scope、include_addons、max_files、max_file_bytes、max_total_bytes、max_dependency_edges、max_evidence_per_target，数值夹限为 1 到工具默认上限。
## [br]
## @return: 输入是否被接受；拒绝后可领取带 input_error 的不完整报告。
func start(paths: PackedStringArray, options: Dictionary = {}) -> bool:
	if _started:
		return false
	_started = true
	_scope = GFVariantData.get_option_string(
		options,
		"scope",
		"res://"
	).strip_edges()
	_limits = {
		"max_files": _limit(
			options,
			"max_files",
			2000
		),
		"max_file_bytes": _limit(
			options,
			"max_file_bytes",
			1_048_576
		),
		"max_total_bytes": _limit(
			options,
			"max_total_bytes",
			8_388_608
		),
		"max_dependency_edges": _limit(
			options,
			"max_dependency_edges",
			1000
		),
		"max_evidence_per_target": _limit(
			options,
			"max_evidence_per_target",
			20
		),
	}
	_remaining_bytes = GFVariantData.get_option_int(_limits, "max_total_bytes")
	_remaining_edges = GFVariantData.get_option_int(_limits, "max_dependency_edges")
	_ignored_roots.assign(GFProjectReferenceScanner.DEFAULT_IGNORED_ROOTS)
	if not GFVariantData.get_option_bool(options, "include_addons"):
		_ignored_roots.append("res://addons")
	_ignored_roots.sort()
	_report = {
		"scope": _scope,
		"ignored_roots": _ignored_roots.duplicate(),
		"dependency_scope": "selected_resources_direct_dependencies",
		"dynamic_paths": "not_determined",
		"partial_scan": false,
		"input_error": "",
		"limits": _limits.duplicate(),
		"rows": [],
		"coverage": {},
		"dependency_edges_examined": 0,
		"dependency_bytes_admitted": 0,
	}
	if (
		paths.is_empty()
		or paths.size() > 100
		or not _valid_project_path(_scope)
	):
		return _reject_input("invalid_selection_or_scope")
	for path: String in paths:
		if (
			not _valid_project_path(path)
			or path.length() > 4096
			or path.contains("::")
		):
			return _reject_input("invalid_resource_path")
		var normalized: String = path.simplify_path()
		if not _paths.has(normalized):
			var _appended: bool = _paths.append(normalized)
	_paths.sort()
	return true


## 首步只扫描一次所有目标的入站引用，之后每步处理一个所选资源；同步原生查询不能在调用中抢占。
## [br]
## @api framework_internal
## [br]
## @return: 任务是否已结束；取消也属于结束，但不会产生可领取结果。
func step() -> bool:
	if (
		not _started
		or _cancelled
		or _finished
	):
		return true
	if _references.is_empty():
		_scan_inbound()
		return false
	_scan_selected(_paths[_cursor])
	_cursor += 1
	_finished = _cursor == _paths.size()
	if _finished:
		_references = {}
	return _finished


## 撤销任务并释放原始证据，取消后领取始终为空。
## [br]
## @api framework_internal
func cancel() -> void:
	_cancelled = true
	_references = {}
	_report = {}


## 领取完成报告一次；调用方负责检查选择、范围、资源索引及上下文仍然有效。
## [br]
## @api framework_internal
## [br]
## @return: 完成报告或空字典；转移结果而不深复制原始证据。
## [br]
## @schema return: Dictionary，包含 scope、ignored_roots、dependency_scope、dynamic_paths、partial_scan、input_error、limits、rows、coverage、dependency_edges_examined、dependency_bytes_admitted。rows 按 path 排序，包含 inbound_status、references、weak_references、dependencies、missing_count、stale_path_count、partial_scan、dependency_issue。
func take_result() -> Dictionary:
	if not _finished or _cancelled:
		return {}
	var result: Dictionary = _report
	_report = {}
	return result


## 返回小型进度，不暴露未完成报告或扫描器的大容器。
## [br]
## @api framework_internal
## [br]
## @return: 已处理与总选择数量。
## [br]
## @schema return: Dictionary，包含 completed、total。
func get_progress() -> Dictionary:
	return { "completed": _cursor, "total": _paths.size() }


# --- 私有/辅助方法 ---

## 允许缩小预算以供轻量批次使用，但禁止通过零值或负值解除限制。
## [br]
## @api private
func _limit(
	options: Dictionary,
	key: String,
	maximum: int
) -> int:
	return clampi(
		GFVariantData.get_option_int(
			options,
			key,
			maximum
		),
		1,
		maximum
	)


## 在规范化之前拒绝目录穿越和非项目路径；根目录本身可用作扫描范围。
## [br]
## @api private
func _valid_project_path(path: String) -> bool:
	return path.begins_with("res://") and not path.replace("\\", "/").split("/").has("..")


## 将输入拒绝封存为不完整结果，不启动任何文件读取。
## [br]
## @api private
func _reject_input(reason: String) -> bool:
	_report["input_error"] = reason
	_report["partial_scan"] = true
	_finished = true
	return false


## 多目标共用同一文件与字节预算；扫描器的 ok 表示无阻断引用，不能作为扫描成功标志。
## [br]
## @api private
func _scan_inbound() -> void:
	var targets: Array[Dictionary] = []
	for path: String in _paths:
		targets.append({ "id": path, "root_path": path })
	_references = GFProjectReferenceScanner.scan_references(
		targets,
		{
			"scan_roots": [_scope],
			"ignored_roots": _ignored_roots,
			"max_scan_depth": 16,
			"max_scanned_files": _limits["max_files"],
			"max_file_bytes": _limits["max_file_bytes"],
			"max_total_bytes": _remaining_bytes,
			"max_references_per_target": _limits["max_evidence_per_target"],
			"max_weak_references_per_target": _limits["max_evidence_per_target"],
		}
	)
	_remaining_bytes -= GFVariantData.get_option_int(_references, "scanned_bytes")
	_report["partial_scan"] = GFVariantData.get_option_bool(_references, "partial_scan")
	_report["coverage"] = {
		"candidate_file_count": GFVariantData.get_option_int(_references, "candidate_file_count"),
		"scanned_file_count": GFVariantData.get_option_int(_references, "scanned_file_count"),
		"scanned_bytes": GFVariantData.get_option_int(_references, "scanned_bytes"),
		"partial_scan": GFVariantData.get_option_bool(_references, "partial_scan"),
		"issues": GFVariantData.get_option_array(_references, "issues"),
		"skipped_files": GFVariantData.get_option_array(_references, "skipped_files"),
	}


## 一条选择记录同时保留入站等级和直接依赖状态；覆盖不足不覆盖已经观察到的缺失事实。
## [br]
## @api private
func _scan_selected(path: String) -> void:
	var strong: Array[Dictionary] = _project_references(path, "targets")
	var weak: Array[Dictionary] = _project_references(path, "weak_targets")
	var inbound_status: String = "not_observed"
	if not strong.is_empty():
		inbound_status = "observed_static"
	elif not weak.is_empty():
		inbound_status = "weak_only"
	var row: Dictionary = {
		"path": path,
		"inbound_status": inbound_status,
		"references": strong,
		"weak_references": weak,
		"dependencies": [],
		"missing_count": 0,
		"stale_path_count": 0,
		"partial_scan": GFVariantData.get_option_bool(_references, "partial_scan"),
		"dependency_issue": "",
	}
	_scan_dependencies(path, row)
	if GFVariantData.get_option_bool(row, "partial_scan"):
		_report["partial_scan"] = true
	var rows: Array = GFVariantData.get_option_array(_report, "rows")
	rows.append(row)
	_report["rows"] = rows


## 仅投影位置、等级与来源，丢弃扫描器的原文片段，避免重复保留长行文本。
## [br]
## @api private
func _project_references(path: String, group: String) -> Array[Dictionary]:
	var groups: Dictionary = GFVariantData.get_option_dictionary(_references, group)
	var target: Dictionary = GFVariantData.get_option_dictionary(groups, path)
	var result: Array[Dictionary] = []
	for item: Variant in GFVariantData.get_option_array(target, "references"):
		if item is Dictionary:
			var evidence: Dictionary = item
			result.append(
				{
					"path": GFVariantData.get_option_string(evidence, "path"),
					"line": GFVariantData.get_option_int(evidence, "line"),
					"strength": GFVariantData.get_option_string(evidence, "strength"),
					"source": GFVariantData.get_option_string(evidence, "source"),
				}
			)
	return result


## 先限制源文件与原始依赖描述；一次读取直接依赖元数据并以 UID 优先解释，不沿用路径优先的 missing 判定。
## 每个 native get_dependencies 调用不可抢占；源文件准入字节不声称覆盖引擎内部导入数据读取。
## [br]
## @api private
func _scan_dependencies(path: String, row: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		row["dependency_issue"] = "selected_resource_missing"
		row["missing_count"] = 1
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_mark_incomplete(row, "source_unreadable")
		return
	var source_bytes: int = file.get_length()
	if source_bytes > GFVariantData.get_option_int(_limits, "max_file_bytes") or source_bytes > _remaining_bytes:
		file.close()
		_mark_incomplete(row, "dependency_byte_budget")
		return
	if _remaining_edges <= 0:
		file.close()
		_mark_incomplete(row, "dependency_edge_budget")
		return
	_remaining_bytes -= source_bytes
	_report["dependency_bytes_admitted"] = GFVariantData.get_option_int(_report, "dependency_bytes_admitted") + source_bytes
	var extension: String = path.get_extension().to_lower()
	var source: String = ""
	var metadata_readable: bool = true
	if extension == "tres" or extension == "tscn":
		var bytes: PackedByteArray = file.get_buffer(source_bytes)
		source = bytes.get_string_from_utf8()
		metadata_readable = bytes.size() == source_bytes and _resource_text_header_valid(extension, source)
	elif extension == "res" or extension == "scn":
		var header: String = file.get_buffer(4).get_string_from_ascii()
		metadata_readable = (
			source_bytes >= 24
			and (
				header == "RSRC"
				or header == "RSCC"
			)
		)
	file.close()
	if not metadata_readable or not ResourceLoader.exists(path):
		_mark_incomplete(row, "dependency_metadata_unavailable")
		return
	var descriptors: PackedStringArray = ResourceLoader.get_dependencies(path)
	if (
		descriptors.is_empty()
		and (
			source.contains("[ext_resource")
			or extension == "res"
			or extension == "scn"
		)
	):
		_mark_incomplete(row, "dependency_metadata_unavailable")
		return
	descriptors.sort()
	if descriptors.size() > _remaining_edges:
		_mark_incomplete(row, "dependency_edge_budget")
	var admitted: int = mini(
		descriptors.size(),
		_remaining_edges
	)
	_remaining_edges -= admitted
	_report["dependency_edges_examined"] = GFVariantData.get_option_int(_report, "dependency_edges_examined") + admitted
	var dependencies: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index: int in range(admitted):
		var descriptor: String = descriptors[index]
		if descriptor.length() > 4096:
			_mark_incomplete(row, "dependency_descriptor_limit")
			continue
		var evidence: Dictionary = _dependency_evidence(descriptor)
		var key: String = JSON.stringify(evidence)
		if seen.has(key):
			continue
		seen[key] = true
		dependencies.append(evidence)
		match GFVariantData.get_option_string(evidence, "status"):
			"missing":
				row["missing_count"] = GFVariantData.get_option_int(row, "missing_count") + 1
			"uid_resolved_stale_path":
				row["stale_path_count"] = GFVariantData.get_option_int(row, "stale_path_count") + 1
			"unknown":
				_mark_incomplete(row, "dependency_identity_unknown")
	dependencies.sort_custom(_dependency_less)
	row["dependencies"] = dependencies


## 仅预检已限额文本的资源头和已识别段闭合，不加载对象，也不承诺验证完整资源语法。
## [br]
## @api private
func _resource_text_header_valid(extension: String, source: String) -> bool:
	var normalized: String = source.trim_prefix("\uFEFF").strip_edges()
	var expected: String = "[gd_resource" if extension == "tres" else "[gd_scene"
	if not normalized.begins_with(expected):
		return false
	for raw_line: String in normalized.split("\n"):
		var line: String = raw_line.strip_edges()
		for prefix: String in [
			"[gd_scene",
			"[gd_resource",
			"[ext_resource",
			"[sub_resource",
			"[resource",
			"[node",
			"[connection",
			"[editable",
		]:
			if line.begins_with(prefix) and not line.ends_with("]"):
				return false
	return true


## UID 可解析且目标存在时优先使用 UID；陈旧 fallback 与真正无法解析的强依赖分开记录。
## [br]
## @api private
func _dependency_evidence(descriptor: String) -> Dictionary:
	var uid_text: String = ""
	var fallback: String = ""
	for part: String in descriptor.split("::", false):
		if part.begins_with("uid://"):
			uid_text = part
		elif part.begins_with("res://") or part.begins_with("user://"):
			fallback = part
	var resolved: String = ""
	if not uid_text.is_empty():
		var uid: int = ResourceUID.text_to_id(uid_text)
		if uid >= 0 and ResourceUID.has_id(uid):
			resolved = ResourceUID.get_id_path(uid)
	var status: String = "missing"
	if not resolved.is_empty() and _resource_exists(resolved):
		status = "resolved" if fallback.is_empty() or fallback == resolved else "uid_resolved_stale_path"
	elif not fallback.is_empty() and _resource_exists(fallback):
		resolved = fallback
		status = "resolved"
	elif uid_text.is_empty() and fallback.is_empty():
		status = "unknown"
	if (
		(
			not fallback.is_empty()
			and not _valid_project_path(fallback)
		)
		or (
			not resolved.is_empty()
			and not _valid_project_path(resolved)
		)
	):
		status = "unknown"
	return {
		"uid": uid_text,
		"recorded_path": fallback,
		"resolved_path": resolved,
		"status": status,
	}


## 只查询资源或文件是否存在，不加载资源或执行脚本。
## [br]
## @api private
func _resource_exists(path: String) -> bool:
	return (
		path.begins_with("res://")
		and (
			FileAccess.file_exists(path)
			or ResourceLoader.exists(path)
		)
	)


## 依赖证据按记录路径、UID 和解析路径排序，原生枚举顺序不影响展示。
## [br]
## @api private
func _dependency_less(left: Dictionary, right: Dictionary) -> bool:
	return JSON.stringify(left) < JSON.stringify(right)


## 记录直接依赖覆盖不足；保留第一个原因，已有缺失计数不因此消失。
## [br]
## @api private
func _mark_incomplete(row: Dictionary, reason: String) -> void:
	row["partial_scan"] = true
	if GFVariantData.get_option_string(row, "dependency_issue").is_empty():
		row["dependency_issue"] = reason
