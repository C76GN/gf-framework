@tool

## GFAudioBankTools: 音频集合扫描、导入和校验辅助。
##
## 面向编辑器工具和构建脚本复用；它只生成 `GFAudioBank` / `GFAudioClip`
## 配置，不接管运行时播放策略。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 3.17.0
class_name GFAudioBankTools
extends RefCounted


# --- 枚举 ---

## 从音频路径生成片段 ID 的方式。
## [br]
## @api public
enum ClipIdMode {
	## 使用文件名，不包含扩展名。
	BASENAME,
	## 使用相对 base_path 的路径，不包含扩展名。
	RELATIVE_PATH,
	## 使用完整资源路径，不包含扩展名。
	FULL_PATH,
}


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 默认音频扩展名白名单，不包含点号。
## [br]
## @api public
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3", "opus"]

## 默认排除的扫描路径。
## [br]
## @api public
const DEFAULT_EXCLUDED_PATHS: PackedStringArray = ["res://addons"]

## 默认递归扫描深度上限。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认单次扫描收集的音频路径数量上限。
## [br]
## @api public
const DEFAULT_MAX_AUDIO_PATHS: int = 10000

# --- 公共方法 ---

## 判断路径是否指向 GF 默认支持的音频扩展名。
## [br]
## @api public
## [br]
## @param path: 资源路径或文件名。
## [br]
## @param extensions: 可选扩展名白名单，不包含点号。
## [br]
## @return: 是音频路径时返回 true。
static func is_audio_path(path: String, extensions: PackedStringArray = AUDIO_EXTENSIONS) -> bool:
	var extension: String = path.get_extension().to_lower()
	return not extension.is_empty() and extensions.has(extension)


## 递归扫描音频路径。
## [br]
## @api public
## [br]
## @param root_path: 扫描起点，通常是 res:// 下的目录。
## [br]
## @param options: 可选项，支持 recursive、include_addons、excluded_paths、extensions、max_scan_depth 与 max_audio_paths。
## [br]
## @return: 按字典序排序的音频路径。
## [br]
## @schema options: Dictionary，可包含 recursive、include_addons、excluded_paths、extensions、max_scan_depth 和 max_audio_paths 字段。
static func scan_audio_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var normalized_root: String = _normalize_dir_path(root_path)
	var extensions: PackedStringArray = _get_extensions(options)
	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var excluded_paths: PackedStringArray = _get_excluded_paths(options)
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_audio_paths: int = maxi(GFVariantData.get_option_int(options, "max_audio_paths", DEFAULT_MAX_AUDIO_PATHS), 0)
	var scan_state: Dictionary = _make_scan_state()
	_scan_audio_paths_recursive(
		normalized_root,
		recursive,
		excluded_paths,
		extensions,
		result,
		0,
		max_scan_depth,
		max_audio_paths,
		scan_state
	)
	result.sort()
	return result


## 从路径列表创建新的音频集合。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param paths: 音频资源路径列表。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension、bus_name、volume_db、pitch_scale、metadata、metadata_by_path。
## [br]
## @return: 新建的音频集合。
## [br]
## @schema options: Dictionary，可包含 id_mode、base_path、path_separator、strip_extension、bus_name、volume_db、pitch_scale、metadata、metadata_by_path 和 overwrite 字段。
static func create_bank_from_paths(paths: PackedStringArray, options: Dictionary = {}) -> GFAudioBank:
	var bank: GFAudioBank = _make_bank()
	var import_options: Dictionary = GFVariantData.to_dictionary(options)
	import_options["overwrite"] = true
	var _import_report: GFValidationReport = add_paths_to_bank(bank, paths, import_options)
	return bank


## 扫描目录并创建新的音频集合。
## [br]
## @api public
## [br]
## @param root_path: 扫描起点，通常是 res://audio。
## [br]
## @param options: 可选项，同时传给 scan_audio_paths() 与 create_bank_from_paths()。
## [br]
## @return: 新建的音频集合。
## [br]
## @schema options: Dictionary，可同时包含扫描选项和片段导入选项。
static func create_bank_from_scan(root_path: String = "res://", options: Dictionary = {}) -> GFAudioBank:
	var paths: PackedStringArray = scan_audio_paths(root_path, options)
	return create_bank_from_paths(paths, options)


## 将路径列表加入音频集合。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param bank: 要写入的音频集合。
## [br]
## @param paths: 音频资源路径列表。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension、overwrite、bus_name、volume_db、pitch_scale、metadata、metadata_by_path。
## [br]
## @return: 导入报告。
## [br]
## @schema options: Dictionary，可包含 id_mode、base_path、path_separator、strip_extension、overwrite、bus_name、volume_db、pitch_scale、metadata 和 metadata_by_path 字段。
static func add_paths_to_bank(
	bank: GFAudioBank,
	paths: PackedStringArray,
	options: Dictionary = {}
) -> GFValidationReport:
	var report: GFValidationReport = _make_report("GFAudioBankTools.add_paths_to_bank")
	if bank == null:
		_add_report_error(report, &"missing_audio_bank", "Audio bank is null.")
		return report

	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", false)
	var extensions: PackedStringArray = _get_extensions(options)
	var added_count: int = 0
	var skipped_count: int = 0
	for path: String in paths:
		if not is_audio_path(path, extensions):
			_add_report_warning(report, &"invalid_audio_path", "Path is not a supported audio file.", path, path)
			skipped_count += 1
			continue

		var clip_id: StringName = make_clip_id(path, options)
		if clip_id == &"":
			_add_report_warning(report, &"empty_audio_clip_id", "Generated clip id is empty.", path, path)
			skipped_count += 1
			continue

		if bank.has_clip(clip_id) and not overwrite:
			_add_report_warning(
				report,
				&"audio_clip_id_exists",
				"Audio clip id already exists and overwrite is disabled.",
				clip_id,
				path
			)
			skipped_count += 1
			continue

		var clip: GFAudioClip = _make_clip(path, options)
		bank.set_clip(clip_id, clip)
		added_count += 1

	report.metadata["added_count"] = added_count
	report.metadata["skipped_count"] = skipped_count
	return report


## 扫描目录并同步到已有音频集合。
## [br]
## @api public
## [br]
## @param bank: 要写入的音频集合。
## [br]
## @param root_path: 扫描起点，通常是 res://audio。
## [br]
## @param options: 可选项，同时传给 scan_audio_paths() 与 add_paths_to_bank()。
## [br]
## @return: 导入报告。
## [br]
## @schema options: Dictionary，可同时包含扫描选项和片段导入选项。
static func sync_bank_from_scan(
	bank: GFAudioBank,
	root_path: String = "res://",
	options: Dictionary = {}
) -> GFValidationReport:
	var paths: PackedStringArray = scan_audio_paths(root_path, options)
	var report: GFValidationReport = add_paths_to_bank(bank, paths, options)
	report.metadata["root_path"] = root_path
	report.metadata["scanned_count"] = paths.size()
	return report


## 校验音频集合是否适合交给 GFAudioUtility 播放。
## [br]
## @api public
## [br]
## @param bank: 要校验的音频集合。
## [br]
## @param options: 可选项，支持 check_resource_exists、check_bus_exists、extensions。
## [br]
## @return: 校验报告。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists、check_bus_exists 和 extensions 字段。
static func validate_bank_playback(bank: GFAudioBank, options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = _make_report("GFAudioBankPlayback")
	if bank == null:
		_add_report_error(report, &"missing_audio_bank", "Audio bank is null.")
		return report

	var check_resource_exists: bool = GFVariantData.get_option_bool(options, "check_resource_exists", false)
	_merge_report(report, bank.validate_bank(check_resource_exists), true)
	var check_bus_exists: bool = GFVariantData.get_option_bool(options, "check_bus_exists", true)
	var extensions: PackedStringArray = _get_extensions(options)
	var clip_count: int = 0
	for clip_id_text: String in bank.get_clip_ids():
		var clip_id: StringName = StringName(clip_id_text)
		var clips: Array[GFAudioClip] = bank.get_clips(clip_id)
		clip_count += clips.size()
		for index: int in range(clips.size()):
			_validate_clip_playback(report, clip_id, clips[index], index, extensions, check_bus_exists)

	report.metadata["clip_count"] = clip_count
	return report


## 按选项从路径生成稳定片段 ID。
## [br]
## @api public
## [br]
## @param path: 音频资源路径。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension。
## [br]
## @return: 片段 ID。
## [br]
## @schema options: Dictionary，可包含 id_mode、base_path、path_separator 和 strip_extension 字段。
static func make_clip_id(path: String, options: Dictionary = {}) -> StringName:
	var mode: ClipIdMode = _resolve_id_mode(GFVariantData.get_option_value(options, "id_mode", ClipIdMode.BASENAME))
	var id_text: String = path.replace("\\", "/")
	match mode:
		ClipIdMode.BASENAME:
			id_text = id_text.get_file()
		ClipIdMode.RELATIVE_PATH:
			id_text = _make_relative_path(id_text, GFVariantData.get_option_string(options, "base_path", "res://"))
		ClipIdMode.FULL_PATH:
			pass

	if GFVariantData.get_option_bool(options, "strip_extension", true):
		id_text = id_text.get_basename()
	id_text = id_text.replace("/", GFVariantData.get_option_string(options, "path_separator", "/")).strip_edges()
	return StringName(id_text)


# --- 私有/辅助方法 ---

static func _make_bank() -> GFAudioBank:
	return GFAudioBank.new()


static func _make_report(subject: String) -> GFValidationReport:
	return GFValidationReport.new(subject)


static func _make_clip(path: String, options: Dictionary) -> GFAudioClip:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = path
	clip.bus_name = GFVariantData.get_option_string(options, "bus_name", "")
	clip.volume_db = GFVariantData.get_option_float(options, "volume_db", 0.0)
	clip.pitch_scale = GFVariantData.get_option_float(options, "pitch_scale", 1.0)
	_apply_clip_metadata(clip, path, options)
	return clip


static func _apply_clip_metadata(clip: GFAudioClip, path: String, options: Dictionary) -> void:
	var base_metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata", {})
	if not base_metadata.is_empty():
		clip.metadata = GFVariantData.duplicate_metadata(base_metadata)

	var metadata_by_path: Dictionary = GFVariantData.get_option_dictionary(options, "metadata_by_path", {})
	if metadata_by_path.is_empty():
		return

	var path_metadata: Dictionary = GFVariantData.get_option_dictionary(metadata_by_path, path, {})
	if path_metadata.is_empty():
		return

	var _merged_metadata: Dictionary = GFVariantData.merge_metadata(clip.metadata, path_metadata, true, true)


static func _validate_clip_playback(
	report: GFValidationReport,
	clip_id: StringName,
	clip: GFAudioClip,
	index: int,
	extensions: PackedStringArray,
	check_bus_exists: bool
) -> void:
	if clip == null:
		return

	var metadata: Dictionary = {
		"clip_id": clip_id,
		"index": index,
	}
	if not clip.path.is_empty() and not is_audio_path(clip.path, extensions):
		_add_report_warning(
			report,
			&"unsupported_audio_extension",
			"Audio clip path uses an unsupported extension.",
			clip_id,
			clip.path,
			metadata
		)
	if check_bus_exists and not clip.bus_name.is_empty() and AudioServer.get_bus_index(clip.bus_name) < 0:
		var bus_metadata: Dictionary = GFVariantData.duplicate_metadata(metadata)
		bus_metadata["bus_name"] = clip.bus_name
		_add_report_warning(
			report,
			&"missing_audio_bus",
			"Audio clip references an audio bus that does not exist.",
			clip_id,
			clip.path,
			bus_metadata
		)


static func _scan_audio_paths_recursive(
	dir_path: String,
	recursive: bool,
	excluded_paths: PackedStringArray,
	extensions: PackedStringArray,
	result: PackedStringArray,
	depth: int,
	max_scan_depth: int,
	max_audio_paths: int,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_audio_paths(result, max_audio_paths):
		_warn_audio_path_limit(max_audio_paths, scan_state)
		return
	if _is_excluded_path(dir_path, excluded_paths):
		return

	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		return

	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not _can_collect_more_audio_paths(result, max_audio_paths):
			_warn_audio_path_limit(max_audio_paths, scan_state)
			break

		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var child_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if recursive:
				if _can_scan_deeper(child_path, depth, max_scan_depth, scan_state):
					_scan_audio_paths_recursive(
						child_path,
						recursive,
						excluded_paths,
						extensions,
						result,
						depth + 1,
						max_scan_depth,
						max_audio_paths,
						scan_state
					)
		elif is_audio_path(entry, extensions):
			_append_packed_string(result, child_path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _can_scan_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_scan_depth_limit(path, max_scan_depth, scan_state)
	return false


static func _can_collect_more_audio_paths(result: PackedStringArray, max_audio_paths: int) -> bool:
	return max_audio_paths <= 0 or result.size() < max_audio_paths


static func _make_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


static func _warn_audio_path_limit(max_audio_paths: int, scan_state: Dictionary) -> void:
	if max_audio_paths <= 0 or GFVariantData.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFAudioBankTools] scan_audio_paths 已达到 max_audio_paths=%d，后续音频已跳过。" % max_audio_paths)


static func _warn_scan_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or GFVariantData.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFAudioBankTools] scan_audio_paths 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


static func _get_extensions(options: Dictionary) -> PackedStringArray:
	return _normalize_extensions(
		GFVariantData.get_option_packed_string_array(options, "extensions", AUDIO_EXTENSIONS)
	)


static func _get_excluded_paths(options: Dictionary) -> PackedStringArray:
	if GFVariantData.get_option_bool(options, "include_addons", false):
		return PackedStringArray()
	var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "excluded_paths", DEFAULT_EXCLUDED_PATHS)
	return _GF_PATH_TOOLS.normalize_root_paths(paths, false)


static func _normalize_extensions(extensions: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		var normalized: String = extension.strip_edges().to_lower()
		if normalized.begins_with("."):
			normalized = normalized.substr(1)
		if not normalized.is_empty():
			_append_packed_string(result, normalized)
	return result


static func _resolve_id_mode(value: Variant) -> ClipIdMode:
	if value is int or value is bool or value is float:
		var mode_value: int = GFVariantData.to_int(value, ClipIdMode.BASENAME)
		match clampi(mode_value, ClipIdMode.BASENAME, ClipIdMode.FULL_PATH):
			ClipIdMode.RELATIVE_PATH:
				return ClipIdMode.RELATIVE_PATH
			ClipIdMode.FULL_PATH:
				return ClipIdMode.FULL_PATH
			_:
				return ClipIdMode.BASENAME

	match GFVariantData.to_text(value).strip_edges().to_lower():
		"relative", "relative_path":
			return ClipIdMode.RELATIVE_PATH
		"full", "full_path", "path":
			return ClipIdMode.FULL_PATH
		_:
			return ClipIdMode.BASENAME


static func _make_relative_path(path: String, base_path: String) -> String:
	var relative_path: String = _GF_PATH_TOOLS.make_relative_path(path, base_path)
	if relative_path.is_empty():
		return _GF_PATH_TOOLS.normalize_resource_path(path, "", false)
	return relative_path


static func _normalize_dir_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", false)


static func _is_excluded_path(path: String, excluded_paths: PackedStringArray) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, excluded_paths)


static func _add_report_warning(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	var _issue: RefCounted = report.add_warning(kind, message, key, path, metadata)


static func _add_report_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	var _issue: RefCounted = report.add_error(kind, message, key, path, metadata)


static func _merge_report(target: GFValidationReport, source: Variant, include_metadata: bool = true) -> void:
	var _merged_report: RefCounted = target.merge(source, include_metadata)


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
