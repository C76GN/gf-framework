## GFSupportReportUtility: 通用支持报告构建工具。
##
## 聚合用户描述、项目元数据、诊断快照、日志和可扩展分区，并提供 JSON / Markdown 导出与回调提交入口。
## 它不绑定任何工单系统、上传服务或反馈 UI。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSupportReportUtility
extends GFUtility


# --- 信号 ---

## 报告构建完成后发出。
## [br]
## @api public
## [br]
## @param report: 已构建的支持报告。
## [br]
## @schema report: Dictionary，build_report() 返回结构。
signal report_built(report: Dictionary)

## 报告写入文件后发出。
## [br]
## @api public
## [br]
## @param path: 目标路径。
## [br]
## @param error: 写入结果错误码。
signal report_saved(path: String, error: Error)

## 报告通过外部回调提交后发出。
## [br]
## @api public
## [br]
## @param result: 提交结果。
## [br]
## @schema result: Dictionary，包含 ok、value、error、metadata，可选 submitted_at_unix。
signal report_submitted(result: Dictionary)


# --- 常量 ---

## 场景节点统计默认最大深度。
## [br]
## @api public
const DEFAULT_SCENE_COUNT_MAX_DEPTH: int = 64

## 场景节点统计默认最大节点数。
## [br]
## @api public
const DEFAULT_SCENE_COUNT_MAX_NODES: int = 10000


# --- 公共变量 ---

## 默认是否包含 GFDiagnosticsUtility 快照。
## [br]
## @api public
var include_diagnostics_by_default: bool = true

## 默认是否包含场景快照。
## [br]
## @api public
var include_scene_by_default: bool = true

## 场景节点数量统计默认最大深度。0 表示不限制。
## [br]
## @api public
var default_scene_count_max_depth: int = DEFAULT_SCENE_COUNT_MAX_DEPTH

## 场景节点数量统计默认最大节点数。0 表示不限制。
## [br]
## @api public
var default_scene_count_max_nodes: int = DEFAULT_SCENE_COUNT_MAX_NODES

## 默认最近日志数量。
## [br]
## @api public
var default_recent_log_count: int = 50

## 默认单个附件最大字节数。小于等于 0 表示不限制。
## [br]
## @api public
var default_max_attachment_bytes: int = 2 * 1024 * 1024

## 默认是否包含当前 Viewport 截图。
## [br]
## @api public
var include_screenshot_by_default: bool = false


# --- 私有变量 ---

var _section_providers: Dictionary = {}
var _reports_built_count: int = 0
var _reports_saved_count: int = 0
var _reports_submitted_count: int = 0


# --- GF 生命周期方法 ---

## 释放支持报告工具的运行时状态。
## [br]
## @api public
func dispose() -> void:
	_section_providers.clear()
	_reports_built_count = 0
	_reports_saved_count = 0
	_reports_submitted_count = 0


# --- 公共方法 ---

## 注册自定义报告分区。
## [br]
## @api public
## [br]
## @param section_id: 分区标识。
## [br]
## @param provider: 分区回调，建议签名为 func(options: Dictionary) -> Variant。
## [br]
## @param options: 分区元数据，支持 label、metadata。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema options: Dictionary，支持 label、metadata。
func register_section(section_id: StringName, provider: Callable, options: Dictionary = {}) -> bool:
	if section_id == &"" or not provider.is_valid():
		return false

	_section_providers[section_id] = {
		"provider": provider,
		"label": GFVariantData.get_option_string(options, "label", str(section_id)),
		"metadata": _get_dictionary_option(options, "metadata"),
	}
	return true


## 注销自定义报告分区。
## [br]
## @api public
## [br]
## @param section_id: 分区标识。
func unregister_section(section_id: StringName) -> void:
	_erase_dictionary_key(_section_providers, section_id)


## 检查自定义分区是否存在。
## [br]
## @api public
## [br]
## @param section_id: 分区标识。
## [br]
## @return 存在返回 true。
func has_section(section_id: StringName) -> bool:
	return _section_providers.has(section_id)


## 获取自定义分区目录。
## [br]
## @api public
## [br]
## @return 分区元数据字典。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，每个值包含 label 和 metadata。
func get_section_catalog() -> Dictionary:
	var result: Dictionary = {}
	for section_id: StringName in _section_providers.keys():
		var entry: Dictionary = GFVariantData.as_dictionary(_section_providers[section_id])
		result[section_id] = {
			"label": GFVariantData.get_option_string(entry, "label", str(section_id)),
			"metadata": _get_dictionary_option(entry, "metadata"),
		}
	return result


## 构建支持报告。
## [br]
## @api public
## [br]
## @param description: 用户描述或问题摘要。
## [br]
## @param options: 可选参数，支持 metadata、tags、include_diagnostics、diagnostics_options、include_scene、scene_options、include_sections、section_options、attachments、max_attachment_bytes、include_screenshot、viewport、screenshot_path。
## [br]
## @return 报告字典。
## [br]
## @schema options: Dictionary，支持 report_id、metadata、tags、include_diagnostics、diagnostics_options、include_scene、scene_options、include_sections、section_options、attachments、max_attachment_bytes、include_screenshot、viewport、screenshot_path。
## [br]
## @schema return: Dictionary，包含 report_id、timestamp_unix、description、metadata、tags、build、runtime、scene、diagnostics、sections、attachments。
func build_report(description: String = "", options: Dictionary = {}) -> Dictionary:
	var report_id: String = GFVariantData.get_option_string(options, "report_id", _make_report_id())
	var attachments: Dictionary = collect_attachments(GFVariantData.get_option_value(options, "attachments", {}), options)
	var report: Dictionary = {
		"report_id": report_id,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"description": description,
		"metadata": _get_dictionary_option(options, "metadata"),
		"tags": _get_tags(GFVariantData.get_option_value(options, "tags", PackedStringArray())),
		"build": GFBuildInfo.collect().to_dict(),
		"runtime": _collect_runtime_snapshot(),
		"scene": {},
		"diagnostics": {},
		"sections": {},
		"attachments": {},
	}

	if GFVariantData.get_option_bool(options, "include_scene", include_scene_by_default):
		report["scene"] = _collect_scene_snapshot(_get_dictionary_option(options, "scene_options"))
	if GFVariantData.get_option_bool(options, "include_diagnostics", include_diagnostics_by_default):
		report["diagnostics"] = _collect_diagnostics_snapshot(options)
	if GFVariantData.get_option_bool(options, "include_sections", true):
		report["sections"] = collect_sections(_get_dictionary_option(options, "section_options"))
	if GFVariantData.get_option_bool(options, "include_screenshot", include_screenshot_by_default):
		var screenshot: PackedByteArray = _capture_viewport_png_buffer(_get_viewport_value(GFVariantData.get_option_value(options, "viewport")))
		if not screenshot.is_empty():
			_append_attachment_without_result(attachments, &"screenshot", screenshot, {
				"filename": "screenshot.png",
				"mime_type": "image/png",
				"max_attachment_bytes": GFVariantData.get_option_int(options, "max_attachment_bytes", default_max_attachment_bytes),
				"save_path": GFVariantData.get_option_string(options, "screenshot_path"),
			})
	report["attachments"] = attachments

	_reports_built_count += 1
	report_built.emit(report)
	return report


## 采集所有自定义分区。
## [br]
## @api public
## [br]
## @param options: 传给每个 provider 的选项。
## [br]
## @return 分区结果字典。
## [br]
## @schema options: Dictionary，原样传给各分区 provider。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，每个值包含 label、metadata、value、ok、error。
func collect_sections(options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for section_id: StringName in _section_providers.keys():
		var entry: Dictionary = GFVariantData.as_dictionary(_section_providers[section_id])
		var provider: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "provider", Callable()))
		var section: Dictionary = {
			"label": GFVariantData.get_option_string(entry, "label", str(section_id)),
			"metadata": _get_dictionary_option(entry, "metadata"),
			"value": null,
			"ok": false,
			"error": "",
		}
		if provider.is_valid():
			section["value"] = provider.call(options.duplicate(true))
			section["ok"] = true
		else:
			section["error"] = "Section provider is invalid."
		result[section_id] = section
	return result


## 采集并规范化报告附件。
## [br]
## @api public
## [br]
## @param attachments: 附件集合。Dictionary 使用键作为附件标识；Array 中的 Dictionary 可提供 id 或 attachment_id。
## [br]
## @param options: 可选参数，支持 max_attachment_bytes。
## [br]
## @return 附件字典。
## [br]
## @schema attachments: Variant，支持 Dictionary[StringName, Variant] 或 Array[Dictionary]。
## [br]
## @schema options: Dictionary，支持 filename、mime_type、metadata、max_attachment_bytes、save_path。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，每个值为规范化附件条目。
func collect_attachments(attachments: Variant, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if attachments is Dictionary:
		var attachment_map: Dictionary = GFVariantData.as_dictionary(attachments)
		for attachment_id_variant: Variant in attachment_map.keys():
			var attachment_id: StringName = GFVariantData.to_string_name(attachment_id_variant)
			_append_attachment_without_result(result, attachment_id, attachment_map[attachment_id_variant], options)
	elif attachments is Array:
		var attachment_array: Array = GFVariantData.as_array(attachments)
		for index: int in range(attachment_array.size()):
			var entry: Dictionary = GFVariantData.as_dictionary(attachment_array[index])
			if entry.is_empty():
				continue
			var entry_id_value: Variant = GFVariantData.get_option_value(
				entry,
				"attachment_id",
				GFVariantData.get_option_value(entry, "id", "attachment_%d" % index)
			)
			var entry_attachment_id: StringName = GFVariantData.to_string_name(entry_id_value)
			_append_attachment_without_result(result, entry_attachment_id, entry, options)
	return result


## 向已有报告追加附件。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @param attachment_id: 附件标识。
## [br]
## @param content: 附件内容，可为 PackedByteArray、String 或带 bytes/text/path 字段的 Dictionary。
## [br]
## @param options: 可选参数，支持 filename、mime_type、metadata、max_attachment_bytes、save_path。
## [br]
## @return 规范化附件结果。
## [br]
## @schema report: Dictionary，build_report() 返回结构或带 attachments 字段的兼容结构。
## [br]
## @schema content: Variant，支持 PackedByteArray、String 或包含 bytes、text、path 字段的 Dictionary。
## [br]
## @schema options: Dictionary，支持 filename、mime_type、metadata、max_attachment_bytes、save_path。
## [br]
## @schema return: Dictionary，包含 ok、filename、mime_type、size_bytes、encoding、data、metadata，失败时包含 reason。
func add_attachment_to_report(
	report: Dictionary,
	attachment_id: StringName,
	content: Variant,
	options: Dictionary = {}
) -> Dictionary:
	if not report.has("attachments") or not (report["attachments"] is Dictionary):
		report["attachments"] = {}
	var attachments: Dictionary = GFVariantData.as_dictionary(report["attachments"])
	return _append_attachment(attachments, attachment_id, content, options)


## 将报告导出为 JSON 文本。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @param indent: JSON 缩进字符串。
## [br]
## @return JSON 文本。
## [br]
## @schema report: Dictionary，build_report() 返回结构。
func export_report_json(report: Dictionary, indent: String = "\t") -> String:
	return JSON.stringify(report, indent)


## 将报告导出为 Markdown 文本。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @param options: 可选参数，支持 title、include_metadata、include_diagnostics_summary、include_sections、include_attachments。
## [br]
## @return Markdown 文本。
## [br]
## @schema report: Dictionary，build_report() 返回结构。
## [br]
## @schema options: Dictionary，支持 title、include_metadata、include_diagnostics_summary、include_sections、include_attachments。
func export_report_markdown(report: Dictionary, options: Dictionary = {}) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var title: String = GFVariantData.get_option_string(options, "title", "GF Support Report")
	_append_packed_string(lines, "# %s" % _markdown_line(title))
	_append_packed_string(lines, "")

	_append_markdown_summary(lines, report)
	_append_markdown_dictionary_fields(lines, "Build", GFVariantData.get_option_value(report, "build", {}), PackedStringArray([
		"project_name",
		"project_version",
		"gf_version",
		"build_id",
		"godot_version",
		"platform",
	]))
	_append_markdown_dictionary_fields(lines, "Runtime", GFVariantData.get_option_value(report, "runtime", {}), PackedStringArray([
		"platform",
		"locale",
		"processor_count",
		"static_memory",
		"object_count",
	]))
	_append_markdown_dictionary_fields(lines, "Scene", GFVariantData.get_option_value(report, "scene", {}), PackedStringArray([
		"available",
		"name",
		"path",
		"node_count",
		"node_count_truncated",
	]))
	if GFVariantData.get_option_bool(options, "include_metadata", true):
		_append_markdown_dictionary(lines, "Metadata", GFVariantData.get_option_value(report, "metadata", {}))
	if GFVariantData.get_option_bool(options, "include_diagnostics_summary", true):
		_append_markdown_diagnostics(lines, GFVariantData.get_option_value(report, "diagnostics", {}))
	if GFVariantData.get_option_bool(options, "include_sections", true):
		_append_markdown_sections(lines, GFVariantData.get_option_value(report, "sections", {}))
	if GFVariantData.get_option_bool(options, "include_attachments", true):
		_append_markdown_attachments(lines, GFVariantData.get_option_value(report, "attachments", {}))

	return "\n".join(lines)


## 保存报告到文件。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @param path: 目标路径。
## [br]
## @return Godot 错误码。
## [br]
## @schema report: Dictionary，build_report() 返回结构。
func save_report(report: Dictionary, path: String) -> Error:
	if path.is_empty():
		report_saved.emit(path, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER

	var base_dir: String = path.get_base_dir()
	if not base_dir.is_empty() and base_dir != "user://":
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if dir_error != OK:
			report_saved.emit(path, dir_error)
			return dir_error

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		report_saved.emit(path, open_error)
		return open_error

	_store_file_string(file, export_report_json(report))
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		_reports_saved_count += 1
	report_saved.emit(path, error)
	return error


## 构建并保存支持报告。
## [br]
## @api public
## [br]
## @param path: 目标路径。
## [br]
## @param description: 用户描述或问题摘要。
## [br]
## @param options: 构建选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，build_report() 支持的构建选项。
func build_and_save_report(path: String, description: String = "", options: Dictionary = {}) -> Error:
	return save_report(build_report(description, options), path)


## 通过外部回调提交报告。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @param transport: 提交回调，签名为 func(report: Dictionary, options: Dictionary) -> Variant。
## [br]
## @param options: 提交选项。
## [br]
## @return 提交结果字典。
## [br]
## @schema report: Dictionary，build_report() 返回结构。
## [br]
## @schema options: Dictionary，提交回调使用的选项。
## [br]
## @schema return: Dictionary，包含 ok、value、error、metadata，可选 submitted_at_unix。
func submit_report(report: Dictionary, transport: Callable, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"value": null,
		"error": "",
		"metadata": {},
	}
	if not transport.is_valid():
		result["error"] = "Transport callback is invalid."
		report_submitted.emit(result)
		return result

	var raw_result: Variant = transport.call(report.duplicate(true), options.duplicate(true))
	result = _normalize_submit_result(raw_result)
	result["submitted_at_unix"] = Time.get_unix_time_from_system()
	if GFVariantData.get_option_bool(result, "ok"):
		_reports_submitted_count += 1
	report_submitted.emit(result)
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 section_count、reports_built_count、reports_saved_count、reports_submitted_count 和默认配置字段。
func get_debug_snapshot() -> Dictionary:
	return {
		"section_count": _section_providers.size(),
		"reports_built_count": _reports_built_count,
		"reports_saved_count": _reports_saved_count,
		"reports_submitted_count": _reports_submitted_count,
		"include_diagnostics_by_default": include_diagnostics_by_default,
		"include_scene_by_default": include_scene_by_default,
		"default_scene_count_max_depth": default_scene_count_max_depth,
		"default_scene_count_max_nodes": default_scene_count_max_nodes,
		"default_recent_log_count": default_recent_log_count,
		"default_max_attachment_bytes": default_max_attachment_bytes,
		"include_screenshot_by_default": include_screenshot_by_default,
	}


# --- 私有/辅助方法 ---

func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _append_attachment_without_result(
	attachments: Dictionary,
	attachment_id: StringName,
	content: Variant,
	options: Dictionary
) -> void:
	var entry: Dictionary = _append_attachment(attachments, attachment_id, content, options)
	if entry.is_empty():
		return


func _store_file_string(file: FileAccess, value: String) -> void:
	var stored: Variant = file.store_string(value)
	if stored == null:
		return


func _store_file_buffer(file: FileAccess, bytes: PackedByteArray) -> void:
	var stored: Variant = file.store_buffer(bytes)
	if stored == null:
		return


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _get_diagnostics_utility() -> GFDiagnosticsUtility:
	var utility: Object = get_utility(GFDiagnosticsUtility)
	if utility is GFDiagnosticsUtility:
		return utility
	return null


func _get_log_utility() -> GFLogUtility:
	var utility: Object = get_utility(GFLogUtility)
	if utility is GFLogUtility:
		return utility
	return null


func _make_report_id() -> String:
	return "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]


func _collect_runtime_snapshot() -> Dictionary:
	return {
		"engine": Engine.get_version_info(),
		"locale": TranslationServer.get_locale(),
		"platform": OS.get_name(),
		"processor_count": OS.get_processor_count(),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
	}


func _collect_scene_snapshot(options: Dictionary = {}) -> Dictionary:
	var tree: SceneTree = _get_scene_tree()
	if tree == null or tree.current_scene == null:
		return {
			"available": false,
			"node_count": 0,
			"node_count_truncated": false,
		}

	var scene: Node = tree.current_scene
	var counters: Dictionary = _make_node_count_counters()
	var max_depth: int = maxi(GFVariantData.get_option_int(options, "max_depth", default_scene_count_max_depth), 0)
	var max_nodes: int = maxi(GFVariantData.get_option_int(options, "max_nodes", default_scene_count_max_nodes), 0)
	return {
		"available": true,
		"name": scene.name,
		"path": scene.scene_file_path,
		"node_count": _count_nodes(scene, 0, max_depth, max_nodes, counters),
		"node_count_truncated": GFVariantData.get_option_bool(counters, "truncated"),
	}


func _collect_diagnostics_snapshot(options: Dictionary) -> Dictionary:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility()
	if diagnostics != null:
		var diagnostics_options: Dictionary = _get_dictionary_option(options, "diagnostics_options")
		if not diagnostics_options.has("recent_log_count"):
			diagnostics_options["recent_log_count"] = default_recent_log_count
		return diagnostics.collect_snapshot(diagnostics_options)

	var log_utility: GFLogUtility = _get_log_utility()
	if log_utility == null:
		return {
			"available": false,
		}
	return {
		"available": true,
		"logs": {
			"memory_count": log_utility.get_memory_entry_count(),
			"dropped_count": log_utility.get_dropped_memory_entry_count(),
			"recent": log_utility.get_recent_entries(default_recent_log_count),
		},
	}


func _capture_viewport_png_buffer(viewport: Viewport) -> PackedByteArray:
	var screenshot_utility: GFScreenshotUtility = GFScreenshotUtility.new()
	return screenshot_utility.capture_viewport_png_buffer(viewport)


func _append_attachment(
	attachments: Dictionary,
	attachment_id: StringName,
	content: Variant,
	options: Dictionary
) -> Dictionary:
	if attachment_id == &"":
		return {
			"ok": false,
			"reason": "attachment_id_is_empty",
		}

	var entry: Dictionary = _make_attachment_entry(attachment_id, content, options)
	attachments[attachment_id] = entry
	return entry


func _make_attachment_entry(attachment_id: StringName, content: Variant, options: Dictionary) -> Dictionary:
	var attachment_options: Dictionary = options.duplicate(true)
	var payload: Variant = content
	if content is Dictionary:
		var content_dictionary: Dictionary = GFVariantData.as_dictionary(content)
		attachment_options.merge(content_dictionary, true)
		if content_dictionary.has("bytes"):
			payload = content_dictionary["bytes"]
		elif content_dictionary.has("text"):
			payload = content_dictionary["text"]
		elif content_dictionary.has("path"):
			var path_filename: String = GFVariantData.get_option_string(attachment_options, "filename")
			if path_filename.is_empty():
				path_filename = GFVariantData.get_option_string(content_dictionary, "path").get_file()
				if path_filename.is_empty():
					path_filename = String(attachment_id)
				attachment_options["filename"] = path_filename
			return _make_path_attachment_entry(
				GFVariantData.get_option_string(content_dictionary, "path"),
				attachment_options
			)

	var filename: String = GFVariantData.get_option_string(attachment_options, "filename", String(attachment_id))
	var mime_type: String = GFVariantData.get_option_string(attachment_options, "mime_type", "application/octet-stream")
	var metadata: Dictionary = _get_dictionary_option(attachment_options, "metadata")
	if payload is PackedByteArray:
		var bytes: PackedByteArray = payload
		return _make_binary_attachment_entry(bytes, filename, mime_type, metadata, attachment_options)
	if payload is String:
		var text: String = payload
		return _make_text_attachment_entry(text, filename, mime_type, metadata, attachment_options)

	return {
		"ok": false,
		"filename": filename,
		"mime_type": mime_type,
		"size_bytes": 0,
		"reason": "unsupported_attachment_content",
		"metadata": metadata,
	}


func _make_binary_attachment_entry(
	bytes: PackedByteArray,
	filename: String,
	mime_type: String,
	metadata: Dictionary,
	options: Dictionary
) -> Dictionary:
	var max_bytes: int = GFVariantData.get_option_int(options, "max_attachment_bytes", default_max_attachment_bytes)
	if max_bytes > 0 and bytes.size() > max_bytes:
		return _make_rejected_attachment_entry(filename, mime_type, bytes.size(), max_bytes, metadata)

	var entry: Dictionary = {
		"ok": true,
		"filename": filename,
		"mime_type": mime_type,
		"size_bytes": bytes.size(),
		"encoding": "base64",
		"data": Marshalls.raw_to_base64(bytes),
		"metadata": metadata,
	}
	_save_attachment_if_requested(entry, bytes, options)
	return entry


func _make_text_attachment_entry(
	text: String,
	filename: String,
	mime_type: String,
	metadata: Dictionary,
	options: Dictionary
) -> Dictionary:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	var max_bytes: int = GFVariantData.get_option_int(options, "max_attachment_bytes", default_max_attachment_bytes)
	if max_bytes > 0 and bytes.size() > max_bytes:
		return _make_rejected_attachment_entry(filename, mime_type, bytes.size(), max_bytes, metadata)

	return {
		"ok": true,
		"filename": filename,
		"mime_type": mime_type,
		"size_bytes": bytes.size(),
		"encoding": "text",
		"data": text,
		"metadata": metadata,
	}


func _make_rejected_attachment_entry(
	filename: String,
	mime_type: String,
	size_bytes: int,
	max_bytes: int,
	metadata: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"filename": filename,
		"mime_type": mime_type,
		"size_bytes": size_bytes,
		"max_bytes": max_bytes,
		"reason": "attachment_too_large",
		"metadata": metadata,
	}


func _save_attachment_if_requested(entry: Dictionary, bytes: PackedByteArray, options: Dictionary) -> void:
	var save_path: String = GFVariantData.get_option_string(options, "save_path")
	if save_path.is_empty():
		return
	if not _is_path_under_allowed_roots(save_path, _get_path_roots(options, "allowed_output_roots", PackedStringArray(["user://"]))):
		entry["save_error"] = ERR_UNAUTHORIZED
		entry["save_error_reason"] = "save_path_not_allowed"
		return

	var base_dir: String = save_path.get_base_dir()
	if not base_dir.is_empty() and base_dir != "user://":
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if dir_error != OK:
			entry["save_error"] = dir_error
			return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		entry["save_error"] = FileAccess.get_open_error()
		return

	_store_file_buffer(file, bytes)
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		entry["saved_path"] = save_path
	else:
		entry["save_error"] = error


func _make_path_attachment_entry(path: String, options: Dictionary) -> Dictionary:
	var filename: String = GFVariantData.get_option_string(options, "filename", path.get_file())
	var mime_type: String = GFVariantData.get_option_string(options, "mime_type", "application/octet-stream")
	var metadata: Dictionary = _get_dictionary_option(options, "metadata")
	if path.is_empty() or not FileAccess.file_exists(path):
		return _make_path_rejected_attachment_entry(filename, mime_type, 0, metadata, "attachment_path_missing")
	if not GFVariantData.get_option_bool(options, "allow_path_attachments", false):
		return _make_path_rejected_attachment_entry(filename, mime_type, 0, metadata, "attachment_path_not_allowed")
	if not _is_path_under_allowed_roots(path, _get_path_roots(options, "allowed_attachment_roots", PackedStringArray(["user://"]))):
		return _make_path_rejected_attachment_entry(filename, mime_type, 0, metadata, "attachment_path_not_allowed")

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _make_path_rejected_attachment_entry(filename, mime_type, 0, metadata, "attachment_path_open_failed")

	var size_bytes: int = file.get_length()
	var max_bytes: int = GFVariantData.get_option_int(options, "max_attachment_bytes", default_max_attachment_bytes)
	if max_bytes > 0 and size_bytes > max_bytes:
		file.close()
		return _make_rejected_attachment_entry(filename, mime_type, size_bytes, max_bytes, metadata)

	var bytes: PackedByteArray = file.get_buffer(size_bytes)
	file.close()
	return _make_binary_attachment_entry(bytes, filename, mime_type, metadata, options)


func _make_path_rejected_attachment_entry(
	filename: String,
	mime_type: String,
	size_bytes: int,
	metadata: Dictionary,
	reason: String
) -> Dictionary:
	return {
		"ok": false,
		"filename": filename,
		"mime_type": mime_type,
		"size_bytes": size_bytes,
		"reason": reason,
		"metadata": metadata,
	}


func _get_path_roots(options: Dictionary, key: String, default_roots: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var raw_roots: Array = GFVariantData.get_option_array(options, key)
	if raw_roots.is_empty():
		return default_roots
	for root_value: Variant in raw_roots:
		var root: String = GFVariantData.to_text(root_value).strip_edges()
		if not root.is_empty():
			var _appended: bool = result.append(root.replace("\\", "/"))
	return result


func _is_path_under_allowed_roots(path: String, roots: PackedStringArray) -> bool:
	var normalized_path: String = path.replace("\\", "/")
	for root: String in roots:
		var normalized_root: String = root.replace("\\", "/")
		if normalized_root.is_empty():
			continue
		if normalized_path == normalized_root:
			return true
		var prefix: String = normalized_root
		if not prefix.ends_with("/"):
			prefix += "/"
		if normalized_path.begins_with(prefix):
			return true
	return false


func _normalize_submit_result(raw_result: Variant) -> Dictionary:
	if raw_result is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(raw_result)
		if data.has("ok"):
			return {
				"ok": GFVariantData.get_option_bool(data, "ok"),
				"value": GFVariantData.get_option_value(data, "value", GFVariantData.get_option_value(data, "data")),
				"error": GFVariantData.get_option_string(data, "error"),
				"metadata": _get_dictionary_option(data, "metadata"),
			}
	return {
		"ok": true,
		"value": raw_result,
		"error": "",
		"metadata": {},
	}


func _append_markdown_summary(lines: PackedStringArray, report: Dictionary) -> void:
	_append_packed_string(lines, "## Summary")
	_append_packed_string(lines, "")
	_append_markdown_field(lines, "Report ID", GFVariantData.get_option_value(report, "report_id", ""))
	_append_markdown_field(lines, "Timestamp", _format_unix_timestamp(GFVariantData.get_option_value(report, "timestamp_unix", "")))
	var description: String = GFVariantData.get_option_string(report, "description")
	if not description.is_empty():
		_append_markdown_field(lines, "Description", description)
	var tags: String = _tags_to_markdown_text(GFVariantData.get_option_value(report, "tags", PackedStringArray()))
	if not tags.is_empty():
		_append_markdown_field(lines, "Tags", tags)
	_append_packed_string(lines, "")


func _append_markdown_dictionary_fields(
	lines: PackedStringArray,
	title: String,
	value: Variant,
	keys: PackedStringArray
) -> void:
	if not (value is Dictionary):
		return

	var dictionary: Dictionary = GFVariantData.as_dictionary(value)
	if dictionary.is_empty():
		return

	var wrote_field: bool = false
	_append_packed_string(lines, "## %s" % _markdown_line(title))
	_append_packed_string(lines, "")
	for key: String in keys:
		if dictionary.has(key):
			_append_markdown_field(lines, key, dictionary[key])
			wrote_field = true
	if not wrote_field:
		_append_markdown_dictionary_items(lines, dictionary)
	_append_packed_string(lines, "")


func _append_markdown_dictionary(lines: PackedStringArray, title: String, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var dictionary: Dictionary = GFVariantData.as_dictionary(value)
	if dictionary.is_empty():
		return

	_append_packed_string(lines, "## %s" % _markdown_line(title))
	_append_packed_string(lines, "")
	_append_markdown_dictionary_items(lines, dictionary)
	_append_packed_string(lines, "")


func _append_markdown_diagnostics(lines: PackedStringArray, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var diagnostics: Dictionary = GFVariantData.as_dictionary(value)
	if diagnostics.is_empty():
		return

	_append_packed_string(lines, "## Diagnostics")
	_append_packed_string(lines, "")
	if diagnostics.has("available"):
		_append_markdown_field(lines, "available", diagnostics["available"])
	if diagnostics.has("timestamp_unix"):
		_append_markdown_field(lines, "timestamp", _format_unix_timestamp(diagnostics["timestamp_unix"]))

	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in _get_sorted_dictionary_keys(diagnostics):
		_append_packed_string(keys, GFVariantData.to_text(key))
	if not keys.is_empty():
		_append_markdown_field(lines, "keys", ", ".join(keys))

	var performance: Dictionary = GFVariantData.get_option_dictionary(diagnostics, "performance")
	if not performance.is_empty():
		_append_markdown_field(lines, "performance.fps", GFVariantData.get_option_value(performance, "fps", ""))
		_append_markdown_field(lines, "performance.object_count", GFVariantData.get_option_value(performance, "object_count", ""))
		_append_markdown_field(lines, "performance.node_count", GFVariantData.get_option_value(performance, "node_count", ""))

	var logs: Dictionary = GFVariantData.get_option_dictionary(diagnostics, "logs")
	if not logs.is_empty():
		_append_markdown_field(lines, "logs.memory_count", GFVariantData.get_option_value(logs, "memory_count", ""))
		_append_markdown_field(lines, "logs.dropped_count", GFVariantData.get_option_value(logs, "dropped_count", ""))
	_append_packed_string(lines, "")


func _append_markdown_sections(lines: PackedStringArray, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var sections: Dictionary = GFVariantData.as_dictionary(value)
	if sections.is_empty():
		return

	_append_packed_string(lines, "## Sections")
	_append_packed_string(lines, "")
	for section_id: Variant in _get_sorted_dictionary_keys(sections):
		var section: Dictionary = GFVariantData.as_dictionary(sections[section_id])
		if section.is_empty():
			continue

		var label: String = GFVariantData.get_option_string(section, "label", GFVariantData.to_text(section_id))
		_append_packed_string(lines, "### %s" % _markdown_line(label))
		_append_packed_string(lines, "")
		_append_markdown_field(lines, "id", section_id)
		_append_markdown_field(lines, "ok", GFVariantData.get_option_value(section, "ok", false))
		var error: String = GFVariantData.get_option_string(section, "error")
		if not error.is_empty():
			_append_markdown_field(lines, "error", error)
		if section.has("value"):
			_append_packed_string(lines, "")
			_append_packed_string(lines, "```json")
			_append_packed_string(lines, _variant_to_json_text(section["value"]))
			_append_packed_string(lines, "```")
		_append_packed_string(lines, "")


func _append_markdown_attachments(lines: PackedStringArray, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var attachments: Dictionary = GFVariantData.as_dictionary(value)
	if attachments.is_empty():
		return

	_append_packed_string(lines, "## Attachments")
	_append_packed_string(lines, "")
	for attachment_id: Variant in _get_sorted_dictionary_keys(attachments):
		var attachment: Dictionary = GFVariantData.as_dictionary(attachments[attachment_id])
		if attachment.is_empty():
			continue

		_append_packed_string(lines, "### %s" % _markdown_line(GFVariantData.to_text(attachment_id)))
		_append_packed_string(lines, "")
		_append_markdown_field(lines, "ok", GFVariantData.get_option_value(attachment, "ok", false))
		_append_markdown_field(lines, "filename", GFVariantData.get_option_value(attachment, "filename", ""))
		_append_markdown_field(lines, "mime_type", GFVariantData.get_option_value(attachment, "mime_type", ""))
		_append_markdown_field(lines, "size_bytes", GFVariantData.get_option_value(attachment, "size_bytes", 0))
		if attachment.has("reason"):
			_append_markdown_field(lines, "reason", attachment["reason"])
		if attachment.has("saved_path"):
			_append_markdown_field(lines, "saved_path", attachment["saved_path"])
		_append_packed_string(lines, "")


func _append_markdown_dictionary_items(lines: PackedStringArray, dictionary: Dictionary) -> void:
	for key: Variant in _get_sorted_dictionary_keys(dictionary):
		_append_markdown_field(lines, GFVariantData.to_text(key), dictionary[key])


func _append_markdown_field(lines: PackedStringArray, label: String, value: Variant) -> void:
	_append_packed_string(lines, "- %s: %s" % [_markdown_line(label), _markdown_value(value)])


func _markdown_value(value: Variant) -> String:
	if value is Dictionary or value is Array:
		return "`%s`" % _markdown_inline(_variant_to_json_text(value))
	if value is PackedStringArray:
		var values: PackedStringArray = value
		return "`%s`" % _markdown_inline(", ".join(values))
	return "`%s`" % _markdown_inline(GFVariantData.to_text(value))


func _markdown_line(value: String) -> String:
	var result: String = value.replace("\r", " ").replace("\n", " ").strip_edges()
	return result if not result.is_empty() else "-"


func _markdown_inline(value: String) -> String:
	return _markdown_line(value).replace("`", "'")


func _format_unix_timestamp(value: Variant) -> String:
	if value is int or value is float:
		var timestamp: int = GFVariantData.to_int(value)
		if timestamp > 0:
			return Time.get_datetime_string_from_unix_time(timestamp, true)
	return GFVariantData.to_text(value)


func _tags_to_markdown_text(value: Variant) -> String:
	var tags: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		tags = _get_packed_string_array_value(value, true)
	elif value is Array:
		for item: Variant in GFVariantData.as_array(value):
			_append_packed_string(tags, GFVariantData.to_text(item))
	return ", ".join(tags)


func _variant_to_json_text(value: Variant) -> String:
	var compatible: Variant = GFVariantJsonCodec.variant_to_json_compatible(value, {
		"unsupported": "string",
	})
	return JSON.stringify(compatible, "\t")


func _get_sorted_dictionary_keys(dictionary: Dictionary) -> Array:
	var keys: Array = dictionary.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return GFVariantData.to_text(a) < GFVariantData.to_text(b)
	)
	return keys


func _get_viewport_value(value: Variant) -> Viewport:
	if value is Viewport:
		return value
	return null


func _get_packed_string_array_value(value: Variant, duplicate_value: bool = false) -> PackedStringArray:
	if value is PackedStringArray:
		var array: PackedStringArray = value
		return array.duplicate() if duplicate_value else array
	return PackedStringArray()


func _get_dictionary_option(options: Dictionary, key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(options, key)


func _get_tags(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		return _get_packed_string_array_value(value, true)
	if value is Array:
		for item: Variant in value:
			_append_packed_string(result, GFVariantData.to_text(item))
	return result


func _count_nodes(root: Node, depth: int, max_depth: int, max_nodes: int, counters: Dictionary) -> int:
	if root == null:
		return 0
	if not _can_count_more_nodes(counters, max_nodes):
		counters["truncated"] = true
		return 0

	var count: int = 1
	counters["count"] = GFVariantData.get_option_int(counters, "count", 0) + 1
	if max_depth > 0 and depth >= max_depth:
		if root.get_child_count() > 0:
			counters["truncated"] = true
		return count

	for child: Node in root.get_children():
		if not _can_count_more_nodes(counters, max_nodes):
			counters["truncated"] = true
			break
		count += _count_nodes(child, depth + 1, max_depth, max_nodes, counters)
	return count


func _can_count_more_nodes(counters: Dictionary, max_nodes: int) -> bool:
	return max_nodes <= 0 or GFVariantData.get_option_int(counters, "count", 0) < max_nodes


func _make_node_count_counters() -> Dictionary:
	return {
		"count": 0,
		"truncated": false,
	}
