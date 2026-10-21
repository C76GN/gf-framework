@tool

## GFExtensionUsageAudit: 检查禁用扩展是否仍被项目文件直接引用。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/extension
class_name GFExtensionUsageAudit
extends RefCounted


# --- 常量 ---

## 读取引用扫描状态和报告字段的 Variant 访问辅助脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 规范化扫描根目录和目标路径的辅助脚本。
## [br]
## @api private
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 扫描项目文件直接引用的底层服务脚本。
## [br]
## @api private
const _GF_PROJECT_REFERENCE_SCANNER_SCRIPT = preload("res://addons/gf/kernel/core/gf_project_reference_scanner.gd")

## Godot 依赖图确认的资源引用。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_STRENGTH_VERIFIED: StringName = &"verified"

## 静态语义扫描确认的资源或 class_name 引用。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_STRENGTH_STRONG: StringName = &"strong"

## 仅文本命中的弱引用提示，不会让禁用扩展审计失败。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_STRENGTH_WEAK: StringName = &"weak"

## GDScript load/preload 等加载表达式来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_GDSCRIPT_LOAD: StringName = &"gdscript_load"

## GDScript class_name 标识符来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_GDSCRIPT_SYMBOL: StringName = &"gdscript_symbol"

## Godot 文本资源依赖字段来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_RESOURCE_TEXT: StringName = &"resource_text"

## Godot ResourceLoader 依赖图来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_GODOT_DEPENDENCY: StringName = &"godot_dependency"

## 无法确认语义的文本命中来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_TEXT_FALLBACK: StringName = &"text_fallback"

## 默认扫描根目录。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]

## 默认最大扫描深度。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大扫描文件数。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_MAX_SCANNED_FILES: int = 10000

## 默认单文件读取字节上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024

## 默认单次扫描总读取字节上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024

## 默认忽略的根目录。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_IGNORED_ROOTS: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://.gf",
	"res://addons/gf",
	"res://build",
	"res://packages",
]

## 作为文本扫描的资源扩展名。
## [br]
## @api public
## [br]
## @since 3.17.0
const TEXT_FILE_EXTENSIONS: Array[String] = [
	"cfg",
	"csv",
	"gd",
	"gdshader",
	"godot",
	"import",
	"json",
	"shader",
	"tscn",
	"tres",
]


# --- 私有变量 ---

## 一个实例只接纳一个请求，取消和领取结果都不重置接纳身份。
## [br]
## @api private
var _started: bool = false

## 完成或取消后不再推进文件系统工作。
## [br]
## @api private
var _finished: bool = false

## 取消只交付进度终态，永远不交付部分报告。
## [br]
## @api private
var _cancelled: bool = false

## 已完成且尚未领取的报告；领取时转移给调用者。
## [br]
## @api private
var _result: Dictionary = {}

## 最近一次推进后的独立小型进度快照，结束后保留计数。
## [br]
## @api private
var _progress: Dictionary = {
	"phase": "idle",
	"audit_phase": "idle",
	"finished": false,
	"cancelled": false,
	"entries": 0,
	"candidate_files": 0,
	"scanned_files": 0,
	"scanned_bytes": 0,
	"current_path": "",
	"line_offset": 0,
	"line_count": 0,
}

## 请求期选项副本，不向调用者暴露或保留可变 manifest。
## [br]
## @api private
var _options: Dictionary = {}

## 只保留用于报告的扩展身份标量，保留输入次序。
## [br]
## @api private
var _manifest_records: Array[Dictionary] = []

## class_name 发现完成后交给项目扫描器的目标副本。
## [br]
## @api private
var _targets: Array[Dictionary] = []

## 项目扫描不得反扫本次禁用扩展本身。
## [br]
## @api private
var _additional_ignored_roots: PackedStringArray = PackedStringArray()

## 根目录辅助入口返回 scanner 报告，manifest 入口返回扩展投影。
## [br]
## @api private
var _audit_report: bool = true

## 两阶段合并前保留预扫描计数、问题和原有诊断顺序。
## [br]
## @api private
var _class_state: Dictionary = {}

## 缓存仅属于本次请求，同根目标复用已完成的 class_name 发现。
## [br]
## @api private
var _class_names_by_root: Dictionary = {}

## 目标身份到已排序类名列表的投影。
## [br]
## @api private
var _class_names_by_target: Dictionary = {}

## 每个 class_name 候选文件只查找首个声明，保持既有发现语义。
## [br]
## @api private
var _class_regex: RegEx = null

## 预扫描内部游标依次经历 prepare、target、enumerate 和 read。
## [br]
## @api private
var _class_phase: String = "prepare"

## 当前目标下标只在根级发现完成后前移。
## [br]
## @api private
var _class_target_index: int = 0

## 当前根的目标身份，不保留 manifest 对象引用。
## [br]
## @api private
var _class_target_id: String = ""

## 当前根的规范路径也是请求期缓存键。
## [br]
## @api private
var _class_root: String = ""

## 当前根先完整枚举候选，再按原目录优先顺序读取。
## [br]
## @api private
var _class_files: Array[String] = []

## 当前根下一个待读取的候选下标。
## [br]
## @api private
var _class_file_index: int = 0

## 当前根发现的去重类名，根完成时排序。
## [br]
## @api private
var _class_names: Array[String] = []

## 显式深度优先栈；每帧保存已排序目录、文件及其处理位置。
## [br]
## @api private
var _class_stack: Array[_ClassDirectoryFrame] = []

## 仅当前目录的枚举句柄跨 step 保留，结束枚举或取消时关闭。
## [br]
## @api private
var _class_directory: DirAccess = null

## 已消费的真实目录项数量，不作为未知总量的百分比分母。
## [br]
## @api private
var _class_entries: int = 0

## 预扫描当前目录或文件；切换到项目阶段后使用子任务路径。
## [br]
## @api private
var _class_current_path: String = ""

## 项目扫描子会话与同步入口使用相同实现。
## [br]
## @api private
var _scanner: GFProjectReferenceScanner = null

## 子会话结束时保留最后进度，以便释放工作数据后仍返回累计计数。
## [br]
## @api private
var _project_progress: Dictionary = {}


# --- 公共方法 ---

## 检查一组禁用扩展是否仍被项目文件直接引用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param manifests: 要检查的禁用扩展 manifest 列表。
## [br]
## @param options: 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_weak_references_per_extension、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references 和 use_resource_dependencies。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, depth, scanned file count, file byte budget, total byte budget, weak text reporting, and Godot dependency graph usage.
## [br]
## @return 引用审计报告。
## [br]
## @schema return: Dictionary containing ok, partial_scan, budget_exceeded, extension_count, reference_count, weak_reference_count, extensions, weak_extensions, references, weak_references, candidate_file_count, scanned_file_count, scanned_bytes, skipped_files, scan_warnings, issue_count, issues, and class_name_scan. references only contains strong or verified blocking references.
static func audit_disabled_extensions(manifests: Array[GFExtensionManifest], options: Dictionary = {}) -> Dictionary:
	var audit: GFExtensionUsageAudit = GFExtensionUsageAudit.new()
	var _accepted: bool = audit.start(manifests, options)
	while not audit.step(128, 0):
		pass
	return audit.take_result()


## 查找项目文件中对指定扩展根目录的直接路径引用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param root_path: 扩展根目录。
## [br]
## @param options: 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_weak_references_per_extension、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references 和 use_resource_dependencies。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, depth, scanned file count, file byte budget, total byte budget, weak text reporting, and Godot dependency graph usage.
## [br]
## @return 引用列表。
## [br]
## @schema return: Array of Dictionary file reference records. By default only strong or verified blocking references are returned; include_weak_references appends weak text matches.
static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
	var scan_report: Dictionary = find_references_to_root_report(root_path, options)
	var references: Array[Dictionary] = []
	_append_typed_references(
		references,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "references")
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		options,
		"include_weak_references",
		false
	):
		_append_typed_references(
			references,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "weak_references")
		)
	return references


## 查找项目文件中对指定扩展根目录的直接引用，并返回扫描完整性报告。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param root_path: 扩展根目录。
## [br]
## @param options: 参数同 find_references_to_root()。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, shared depth, candidate file count, file byte and total byte budgets, weak text reporting, and Godot dependency graph usage.
## [br]
## @return: 引用与扫描完整性报告。
## [br]
## @schema return: Dictionary containing ok, partial_scan, budget_exceeded, truncated, references, weak_references, candidate_file_count, scanned_file_count, scanned_bytes, skipped_files, scan_warnings, issue_count, issues, and class_name_scan.
static func find_references_to_root_report(root_path: String, options: Dictionary = {}) -> Dictionary:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		return _make_invalid_root_scan_report(root_path)
	var scan_options: Dictionary = options.duplicate(true)
	if not _has_option_key(scan_options, "include_weak_references"):
		scan_options["include_weak_references"] = false
	return _scan_targets_with_class_names(
		[
			{ "id": normalized_root, "root_path": normalized_root, },
		],
		scan_options,
		PackedStringArray([normalized_root])
	)


# --- 框架内部方法 ---

## 接纳一次禁用扩展审计，只复制身份和选项，不枚举目录或读取文件。
## 同一实例不能重新接纳；调用者在两次 step 之间可以取消。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer kernel/extension
## [br]
## @param manifests: 禁用扩展列表；只快照 id、display_name 和规范根路径，不保留资源。
## [br]
## @param options: 与 audit_disabled_extensions() 相同的扫描选项，按请求复制。
## [br]
## @schema options: Dictionary containing scan roots, ignored roots, reference limits, depth and shared file/byte budgets, weak-reference and native dependency switches, and optional respect_gdignore/additional_scan_files scope.
## [br]
## @return: 首次请求返回 true；重复请求返回 false 并保留原请求。
func start(manifests: Array[GFExtensionManifest], options: Dictionary = {}) -> bool:
	if _started:
		return false
	var records: Array[Dictionary] = []
	var targets: Array[Dictionary] = []
	var root_paths: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.root_path.is_empty():
			continue
		var root_path: String = _GF_PATH_TOOLS.normalize_root_path(manifest.root_path)
		if root_path.is_empty():
			continue
		records.append(
			{
				"id": manifest.id,
				"display_name": manifest.display_name,
				"root_path": root_path,
			}
		)
		targets.append({ "id": manifest.id, "root_path": root_path, })
		root_paths.append(root_path)
	return _start_targets(
		targets,
		options,
		PackedStringArray(root_paths),
		records,
		true
	)


## 在调用线程有界推进枚举、class_name 预扫描和项目引用扫描。
## 文件读取、单个正则查询和原生依赖查询不可中断，时间上限是软预算。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer kernel/extension
## [br]
## @param max_items: 本次最多推进的工作项数，小于一时按一处理。
## [br]
## @param max_usec: 本次软时间预算；不大于零时不限制时间。
## [br]
## @return: 完成或取消返回 true，尚有工作或尚未 start 返回 false。
func step(max_items: int = 128, max_usec: int = 4000) -> bool:
	if _finished:
		return true
	if not _started:
		return false
	var started_at: int = Time.get_ticks_usec()
	var item_limit: int = maxi(max_items, 1)
	var processed: int = 0
	while not _finished and processed < item_limit:
		if _scanner != null:
			var remaining_usec: int = 0
			if max_usec > 0:
				remaining_usec = maxi(
					max_usec - (Time.get_ticks_usec() - started_at),
					1
				)
			var scanner_finished: bool = _scanner.step(
				item_limit - processed,
				remaining_usec
			)
			_project_progress = _scanner.get_progress()
			if scanner_finished:
				_finish_scan(_scanner.take_result())
			break
		_step_class_names()
		processed += 1
		if max_usec > 0 and Time.get_ticks_usec() - started_at >= max_usec:
			break
	if not _finished:
		_refresh_progress()
	return _finished


## 取消当前请求并释放目录游标、文本、缓存和子会话；取消后不交付报告。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer kernel/extension
func cancel() -> void:
	if _cancelled:
		return
	_started = true
	_cancelled = true
	_finished = true
	if _scanner != null:
		_project_progress = _scanner.get_progress()
		_scanner.cancel()
	_refresh_progress()
	_result = {}
	_release_work()


## 返回不与会话共享容器的进度快照，不宣称未知扫描总量或完成百分比。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer kernel/extension
## [br]
## @return: 当前阶段、实际累计计数、当前路径和子扫描当前行进度。
## [br]
## @schema return: Dictionary containing phase, audit_phase, finished, cancelled, entries, candidate_files, scanned_files, scanned_bytes, current_path, line_offset, and line_count. phase is class_names during prescanning and otherwise the scanner phase; audit_phase is idle/class_names/references/finished/cancelled. Line counters reset when the current file or scanner phase changes.
func get_progress() -> Dictionary:
	return _progress.duplicate(true)


## 单次领取完成报告，未完成、已领取或取消时返回空字典。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer kernel/extension
## [br]
## @return: 与 audit_disabled_extensions() 同形的完整报告，或尚不可领取的空字典。
## [br]
## @schema return: Dictionary containing the same completed audit fields as audit_disabled_extensions(); empty when unavailable or cancelled.
func take_result() -> Dictionary:
	if not _finished or _cancelled:
		return {}
	var result: Dictionary = _result
	_result = {}
	return result


# --- 私有/辅助方法 ---

## 统一接纳 manifest 投影或根目录辅助请求；接纳阶段只复制数据。
## [br]
## @api private
func _start_targets(
	targets: Array[Dictionary],
	options: Dictionary,
	additional_ignored_roots: PackedStringArray,
	manifest_records: Array[Dictionary] = [],
	audit_report: bool = false
) -> bool:
	if _started:
		return false
	_started = true
	_targets = targets.duplicate(true)
	_options = options.duplicate(true)
	_manifest_records = manifest_records.duplicate(true)
	_additional_ignored_roots = additional_ignored_roots.duplicate()
	_audit_report = audit_report
	_class_state = _make_class_name_scan_state()
	if _audit_report and _targets.is_empty():
		_result = _make_audit_report(
			true,
			{},
			{},
			[],
			[],
			{}
		)
		_finished = true
		_refresh_progress()
		_release_work()
	else:
		_refresh_progress()
	return true


## 每次推进一个预扫描动作；根内候选枚举完成之前不读取该根脚本。
## [br]
## @api private
func _step_class_names() -> void:
	match _class_phase:
		"prepare":
			_class_regex = RegEx.new()
			var compile_error: Error = _class_regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
			if compile_error != OK:
				_mark_class_scan_partial(_class_state)
				_append_class_scan_issue(
					"class_name_pattern_invalid",
					"",
					"",
					"[extension_usage_audit.regex_compile_failed] Could not compile the extension class_name prescan regular expression.",
					_class_state
				)
				_emit_class_scan_warning("[extension_usage_audit.regex_compile_failed] Could not compile the extension class_name prescan regular expression.", _class_state)
				_begin_project_scan()
			else:
				_class_phase = "target"
		"target":
			_begin_class_root()
		"enumerate":
			_step_class_directory()
		"read":
			_step_class_file()


## 在输入次序中选择下一个根；重复根仅复用本请求已经完成的类名列表。
## [br]
## @api private
func _begin_class_root() -> void:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_class_state, "stop_scan") or _class_target_index >= _targets.size():
		_begin_project_scan()
		return
	var target: Dictionary = _targets[_class_target_index]
	_class_target_id = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		target,
		"id",
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
	)
	_class_root = _GF_PATH_TOOLS.normalize_root_path(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path"))
	if _class_names_by_root.has(_class_root):
		_class_names_by_target[_class_target_id] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(_class_names_by_root, _class_root)
		_class_target_index += 1
		return
	_class_files = []
	_class_file_index = 0
	_class_names = []
	_class_stack = [_make_class_directory_frame(_class_root, 0)]
	_class_phase = "enumerate"


## 创建目录游标帧，枚举完成后分别排序目录与文件以保留既有深度优先顺序。
## [br]
## @api private
static func _make_class_directory_frame(path: String, depth: int) -> _ClassDirectoryFrame:
	var frame: _ClassDirectoryFrame = _ClassDirectoryFrame.new()
	frame._path = path
	frame._depth = depth
	return frame


## 一次消费一个真实目录项或一个已排序候选；文件配额仍按候选准入计数。
## [br]
## @api private
func _step_class_directory() -> void:
	if _class_stack.is_empty() or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_class_state, "stop_scan"):
		_close_class_directory()
		_class_stack = []
		_class_phase = "read"
		_class_current_path = ""
		return
	var frame: _ClassDirectoryFrame = _class_stack[_class_stack.size() - 1]
	var path: String = frame._path
	_class_current_path = path
	if not frame._listed:
		_step_class_listing(frame, path)
		return
	var directory_index: int = frame._directory_index
	var depth: int = frame._depth
	if directory_index < frame._directories.size():
		frame._directory_index = directory_index + 1
		var child_path: String = _GF_PATH_TOOLS.normalize_resource_path(path.path_join(frame._directories[directory_index]))
		var max_depth: int = maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				_options,
				"max_scan_depth",
				DEFAULT_MAX_SCAN_DEPTH
			),
			0
		)
		if max_depth > 0 and depth >= max_depth:
			_mark_class_depth_limit(
				child_path,
				max_depth,
				_class_state
			)
		else:
			_class_stack.append(
				_make_class_directory_frame(
					child_path,
					depth + 1
				)
			)
		return
	var file_index: int = frame._file_index
	if file_index >= frame._files.size():
		var _removed_frame: Variant = _class_stack.pop_back()
		return
	frame._file_index = file_index + 1
	var file_name: String = frame._files[file_index]
	if file_name.get_extension().to_lower() != "gd":
		return
	var candidate_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_class_state, "candidate_file_count")
	var max_files: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			_options,
			"max_scanned_files",
			DEFAULT_MAX_SCANNED_FILES
		),
		0
	)
	if max_files > 0 and candidate_count >= max_files:
		_mark_class_file_count_limit(max_files, _class_state)
		return
	_class_files.append(_GF_PATH_TOOLS.normalize_resource_path(path.path_join(file_name)))
	_class_state["candidate_file_count"] = candidate_count + 1


## 目录句柄只用于当前帧；到达末尾立即关闭，排序不改变原目录优先策略。
## [br]
## @api private
func _step_class_listing(frame: _ClassDirectoryFrame, path: String) -> void:
	if _class_directory == null:
		if path.is_empty() or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			var _missing_frame: Variant = _class_stack.pop_back()
			return
		_class_directory = DirAccess.open(path)
		if _class_directory == null:
			_fail_class_directory(path)
			return
		var begin_error: Error = _class_directory.list_dir_begin()
		if begin_error != OK:
			_fail_class_directory(path)
			return
		return
	var entry_name: String = _class_directory.get_next()
	if entry_name.is_empty():
		_close_class_directory()
		frame._directories.sort()
		frame._files.sort()
		frame._listed = true
		return
	_class_entries += 1
	if entry_name.begins_with("."):
		return
	if _class_directory.current_is_dir():
		frame._directories.append(entry_name)
	else:
		frame._files.append(entry_name)


## 目录不可枚举时沿用原有部分扫描诊断，并继续其余目录。
## [br]
## @api private
func _fail_class_directory(path: String) -> void:
	_close_class_directory()
	_mark_class_scan_partial(_class_state)
	_append_class_skipped_file(
		path,
		"directory_open_failed",
		0,
		"",
		0,
		_class_state
	)
	_append_class_scan_issue(
		"class_name_directory_open_failed",
		path,
		"",
		"无法打开扩展 class_name 扫描目录。",
		_class_state
	)
	var _failed_frame: Variant = _class_stack.pop_back()


## 每次读取一个有界候选；原有停止标记优先于已收集但尚未读取的文件。
## [br]
## @api private
func _step_class_file() -> void:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_class_state, "stop_scan") or _class_file_index >= _class_files.size():
		_class_names.sort()
		_class_names_by_root[_class_root] = _class_names.duplicate()
		_class_names_by_target[_class_target_id] = _class_names.duplicate()
		_class_target_index += 1
		_class_files = []
		_class_names = []
		_class_current_path = ""
		_class_phase = "target"
		return
	_class_current_path = _class_files[_class_file_index]
	_class_file_index += 1
	var source_report: Dictionary = _read_class_name_source(
		_class_current_path,
		_options,
		_class_state
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(source_report, "ok"):
		return
	var match_result: RegExMatch = _class_regex.search(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_report, "source"))
	if match_result == null:
		return
	var class_name_value: String = match_result.get_string(1)
	if not _class_names.has(class_name_value):
		_class_names.append(class_name_value)


## 从两阶段共享额度中扣除预扫描消耗，再把增强目标交给同一个项目扫描会话。
## [br]
## @api private
func _begin_project_scan() -> void:
	_close_class_directory()
	_class_current_path = ""
	_class_state["class_names_by_target"] = _class_names_by_target
	var enriched_targets: Array[Dictionary] = []
	for target: Dictionary in _targets:
		var enriched_target: Dictionary = target.duplicate(true)
		var target_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			target,
			"id",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
		)
		enriched_target["class_names"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(_class_names_by_target, target_id)
		enriched_targets.append(enriched_target)
	var scanner_options: Dictionary = _make_scanner_options(_options, _additional_ignored_roots)
	if not _apply_remaining_scan_budgets(scanner_options, _class_state):
		_finish_scan(_make_empty_project_scan_report(enriched_targets))
		return
	_scanner = _GF_PROJECT_REFERENCE_SCANNER_SCRIPT.new()
	var _accepted: bool = _scanner.start(enriched_targets, scanner_options)
	_project_progress = _scanner.get_progress()


## 组装完整报告后释放工作态；未完成时从不发布中间结果。
## [br]
## @api private
func _finish_scan(project_report: Dictionary) -> void:
	var scan_report: Dictionary = _merge_scan_phase_reports(project_report, _class_state)
	_result = _project_audit_report(scan_report) if _audit_report else scan_report
	_finished = true
	_refresh_progress()
	_release_work()


## 只用接纳时保存的身份标量生成 manifest 报告，避免扫描期间资源修改造成串写。
## [br]
## @api private
func _project_audit_report(scan_report: Dictionary) -> Dictionary:
	var extension_reports: Dictionary = {}
	var weak_extension_reports: Dictionary = {}
	var references: Array[Dictionary] = []
	var weak_references: Array[Dictionary] = []
	var targets: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(scan_report, "targets")
	var weak_targets: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(scan_report, "weak_targets")
	for record: Dictionary in _manifest_records:
		var extension_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "id")
		var target: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(targets, extension_id)
		var weak_target: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(weak_targets, extension_id)
		var target_references: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(target, "references")
		var weak_target_references: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(weak_target, "references")
		if not target_references.is_empty():
			extension_reports[extension_id] = {
				"id": extension_id,
				"display_name": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "display_name"),
				"root_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "root_path"),
				"references": target_references,
				"reference_count": target_references.size(),
			}
			_append_typed_references(references, target_references)
		if not weak_target_references.is_empty():
			weak_extension_reports[extension_id] = {
				"id": extension_id,
				"display_name": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "display_name"),
				"root_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "root_path"),
				"references": weak_target_references,
				"reference_count": weak_target_references.size(),
			}
			_append_typed_references(weak_references, weak_target_references)
	return _make_audit_report(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_report, "ok"),
		extension_reports,
		weak_extension_reports,
		references,
		weak_references,
		scan_report
	)


## 把真实子阶段与累计计数投影为独立小快照，终态保留计数并清除当前行定位。
## [br]
## @api private
func _refresh_progress() -> void:
	if not _class_state.is_empty():
		var phase: String = "class_names"
		var audit_phase: String = "class_names"
		var current_path: String = _class_current_path
		if _scanner != null:
			phase = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				_project_progress,
				"phase",
				"idle"
			)
			audit_phase = "references"
			current_path = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(_project_progress, "current_path")
		_progress = {
			"phase": phase,
			"audit_phase": audit_phase,
			"finished": _finished,
			"cancelled": _cancelled,
			"entries": _class_entries + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_project_progress, "entries"),
			"candidate_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_class_state, "candidate_file_count") + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_project_progress, "candidate_files"),
			"scanned_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_class_state, "scanned_file_count") + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_project_progress, "scanned_files"),
			"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_class_state, "scanned_bytes") + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_project_progress, "scanned_bytes"),
			"current_path": current_path,
			"line_offset": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_project_progress, "line_offset"),
			"line_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_project_progress, "line_count"),
		}
	if _finished:
		_progress["phase"] = "cancelled" if _cancelled else "finished"
		_progress["audit_phase"] = _progress["phase"]
		_progress["finished"] = true
		_progress["cancelled"] = _cancelled
		_progress["current_path"] = ""
		_progress["line_offset"] = 0
		_progress["line_count"] = 0


## 释放当前目录枚举句柄，幂等供正常末尾、错误和取消复用。
## [br]
## @api private
func _close_class_directory() -> void:
	if _class_directory != null:
		_class_directory.list_dir_end()
		_class_directory = null


## 清空调用期工作集合但不改已发布报告或保留的终态进度。
## [br]
## @api private
func _release_work() -> void:
	_close_class_directory()
	_options = {}
	_manifest_records = []
	_targets = []
	_additional_ignored_roots = PackedStringArray()
	_class_state = {}
	_class_names_by_root = {}
	_class_names_by_target = {}
	_class_regex = null
	_class_files = []
	_class_names = []
	_class_stack = []
	_scanner = null
	_project_progress = {}


## 将引用列表、扫描完整性计数和 class_name 子报告组装为审计报告。
## [br]
## @api private
static func _make_audit_report(
	ok: bool,
	extension_reports: Dictionary,
	weak_extension_reports: Dictionary,
	references: Array[Dictionary],
	weak_references: Array[Dictionary],
	scan_report: Dictionary
) -> Dictionary:
	var report: Dictionary = {
		"ok": ok,
		"partial_scan": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_report, "partial_scan"),
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_report, "budget_exceeded"),
		"extension_count": extension_reports.size(),
		"reference_count": references.size(),
		"weak_reference_count": weak_references.size(),
		"extensions": extension_reports,
		"weak_extensions": weak_extension_reports,
		"references": references,
		"weak_references": weak_references,
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "candidate_file_count"),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "scanned_bytes"),
		"skipped_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "skipped_files"),
		"scan_warnings": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "scan_warnings"),
		"issue_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "issue_count"),
		"issues": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "issues"),
		"class_name_scan": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(scan_report, "class_name_scan"),
	}
	if scan_report.has("scope"):
		report["scope"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(scan_report, "scope")
	return report


## 深复制扫描选项，设置 warning 前缀、缺省引用/字节上限并合并额外忽略根。
## [br]
## @api private
static func _make_scanner_options(options: Dictionary, additional_ignored_roots: PackedStringArray) -> Dictionary:
	var scan_options: Dictionary = options.duplicate(true)
	scan_options["warning_prefix"] = "[GFExtensionUsageAudit]"
	if not _has_option_key(scan_options, "max_references_per_target"):
		scan_options["max_references_per_target"] = maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				options,
				"max_references_per_extension",
				50
			),
			1
		)
	if not _has_option_key(scan_options, "max_weak_references_per_target"):
		scan_options["max_weak_references_per_target"] = maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				options,
				"max_weak_references_per_extension",
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					scan_options,
					"max_references_per_target",
					50
				)
			),
			0
		)
	if not _has_option_key(scan_options, "max_file_bytes"):
		scan_options["max_file_bytes"] = DEFAULT_MAX_FILE_BYTES
	if not _has_option_key(scan_options, "max_total_bytes"):
		scan_options["max_total_bytes"] = DEFAULT_MAX_TOTAL_BYTES

	var ignored_roots: PackedStringArray = _read_option_packed_string_array(scan_options, "additional_ignored_roots")
	for ignored_root: String in additional_ignored_roots:
		if ignored_root.is_empty() or ignored_roots.has(ignored_root):
			continue
		var _append_ignored_root: bool = ignored_roots.append(ignored_root)
	scan_options["additional_ignored_roots"] = ignored_roots
	return scan_options


## 读取 PackedStringArray 时返回副本，否则尝试将选项值转换为字符串数组。
## [br]
## @api private
static func _read_option_packed_string_array(options: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		options,
		key,
		PackedStringArray()
	)
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	return PackedStringArray(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(value))


## 仅将输入数组中的 Dictionary 项追加到目标引用列表。
## [br]
## @api private
static func _append_typed_references(result: Array[Dictionary], values: Array) -> void:
	for value: Variant in values:
		if value is Dictionary:
			var reference_record: Dictionary = value
			result.append(reference_record)


## 检查选项字典是否含给定 String 或其 StringName 形式的键。
## [br]
## @api private
static func _has_option_key(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))


## 先预扫描扩展 class_name 充实目标，再用扣除预扫描消耗后的预算扫描项目引用；最后合并两个阶段的计数和不完整标志。
## [br]
## @api private
static func _scan_targets_with_class_names(
	targets: Array[Dictionary],
	options: Dictionary,
	additional_ignored_roots: PackedStringArray
) -> Dictionary:
	var audit: GFExtensionUsageAudit = GFExtensionUsageAudit.new()
	var _accepted: bool = audit._start_targets(
		targets,
		options,
		additional_ignored_roots
	)
	while not audit.step(128, 0):
		pass
	return audit.take_result()


## 从共享文件及字节额度中扣除 class_name 阶段消耗，原地更新项目扫描选项；额度已耗尽时记录阶段问题并阻止项目扫描。
## [br]
## @api private
static func _apply_remaining_scan_budgets(scanner_options: Dictionary, class_name_report: Dictionary) -> bool:
	var can_scan_project: bool = true
	var max_scanned_files: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			scanner_options,
			"max_scanned_files",
			DEFAULT_MAX_SCANNED_FILES
		),
		0
	)
	var candidate_file_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "candidate_file_count")
	if max_scanned_files > 0:
		var remaining_files: int = max_scanned_files - candidate_file_count
		if remaining_files <= 0:
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "stop_scan"):
				_mark_class_phase_exhausted(
					class_name_report,
					"max_scanned_files",
					"[extension_usage_audit.shared_file_budget_exhausted] Extension class_name prescanning exhausted max_scanned_files=%d shared with project scanning." % max_scanned_files
				)
			can_scan_project = false
		else:
			scanner_options["max_scanned_files"] = remaining_files

	var max_total_bytes: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			scanner_options,
			"max_total_bytes",
			DEFAULT_MAX_TOTAL_BYTES
		),
		0
	)
	var scanned_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_bytes")
	if max_total_bytes > 0:
		var remaining_bytes: int = max_total_bytes - scanned_bytes
		if remaining_bytes <= 0:
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "stop_scan"):
				_mark_class_phase_exhausted(
					class_name_report,
					"max_total_bytes",
					"[extension_usage_audit.shared_byte_budget_exhausted] Extension class_name prescanning exhausted the max_total_bytes=%d byte budget shared with project scanning." % max_total_bytes
				)
			can_scan_project = false
		else:
			scanner_options["max_total_bytes"] = remaining_bytes
	return can_scan_project


## 在单文件与累计字节额度内读取候选脚本文本，所有打开后的分支关闭句柄；成功才增加读取计数，总预算不足可终止后续扫描。
## [br]
## @api private
static func _read_class_name_source(
	path: String,
	options: Dictionary,
	scan_state: Dictionary
) -> Dictionary:
	var result: Dictionary = { "ok": false, "source": "", }
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_mark_class_scan_partial(scan_state)
		_append_class_skipped_file(
			path,
			"read_failed",
			0,
			"",
			0,
			scan_state
		)
		_append_class_scan_issue(
			"class_name_file_open_failed",
			path,
			"",
			"无法打开扩展 class_name 候选脚本。",
			scan_state
		)
		return result
	var size_bytes: int = file.get_length()
	var max_file_bytes: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_file_bytes",
			DEFAULT_MAX_FILE_BYTES
		),
		0
	)
	if max_file_bytes > 0 and size_bytes > max_file_bytes:
		file.close()
		_mark_class_byte_budget(
			path,
			"max_file_bytes",
			size_bytes,
			max_file_bytes,
			false,
			scan_state
		)
		return result
	var scanned_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_bytes")
	var max_total_bytes: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_total_bytes",
			DEFAULT_MAX_TOTAL_BYTES
		),
		0
	)
	if max_total_bytes > 0 and scanned_bytes + size_bytes > max_total_bytes:
		file.close()
		_mark_class_byte_budget(
			path,
			"max_total_bytes",
			scanned_bytes + size_bytes,
			max_total_bytes,
			true,
			scan_state
		)
		return result
	var source: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		_mark_class_scan_partial(scan_state)
		_append_class_skipped_file(
			path,
			"read_failed",
			size_bytes,
			"",
			0,
			scan_state
		)
		_append_class_scan_issue(
			"class_name_file_read_failed",
			path,
			"",
			"读取扩展 class_name 候选脚本失败。",
			scan_state
		)
		return result
	scan_state["scanned_file_count"] = ((_GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_file_count")) + 1)
	scan_state["scanned_bytes"] = scanned_bytes + size_bytes
	result["ok"] = true
	result["source"] = source
	return result


## 创建 class_name 预扫描状态及计数、截断、跳过项、警告和问题集合的初始值。
## [br]
## @api private
static func _make_class_name_scan_state() -> Dictionary:
	return {
		"class_names_by_target": {},
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"partial_scan": false,
		"budget_exceeded": false,
		"truncated": false,
		"stop_scan": false,
		"skipped_files": [],
		"scan_warnings": [],
		"issues": [],
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
		"budget_warning_emitted": false,
	}


## 将 class_name 预扫描状态标记为 partial_scan。
## [br]
## @api private
static func _mark_class_scan_partial(scan_state: Dictionary) -> void:
	scan_state["partial_scan"] = true


## 首次触及正数文件上限时设置截断/停止/partial 标记并记录问题和警告。
## [br]
## @api private
static func _mark_class_file_count_limit(max_scanned_files: int, scan_state: Dictionary) -> void:
	if (max_scanned_files <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted")):
		return
	scan_state["count_warning_emitted"] = true
	scan_state["truncated"] = true
	scan_state["stop_scan"] = true
	_mark_class_scan_partial(scan_state)
	_append_class_scan_issue(
		"max_scanned_files",
		"",
		"",
		"扩展 class_name 预扫描候选文件数量超过共享配额。",
		scan_state
	)
	_emit_class_scan_warning(
		"[extension_usage_audit.file_limit_reached] Extension class_name prescanning reached max_scanned_files=%d; subsequent scanning is treated as partial_scan." % max_scanned_files,
		scan_state
	)


## 首次触及正数目录深度上限时设置截断/partial 标记并记录问题和警告。
## [br]
## @api private
static func _mark_class_depth_limit(
	path: String,
	max_scan_depth: int,
	scan_state: Dictionary
) -> void:
	if (max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted")):
		return
	scan_state["depth_warning_emitted"] = true
	scan_state["truncated"] = true
	_mark_class_scan_partial(scan_state)
	_append_class_scan_issue(
		"max_scan_depth",
		path,
		"",
		"扩展 class_name 预扫描目录深度超过共享配额。",
		scan_state
	)
	_emit_class_scan_warning(
		"[extension_usage_audit.depth_limit_reached] Extension class_name prescanning reached max_scan_depth=%d; deeper directories were skipped: %s."
		% [max_scan_depth, path],
		scan_state
	)


## 设置字节预算超限与截断/partial 标记，可选停止扫描，并记录跳过项、问题和至多一条警告。
## [br]
## @api private
static func _mark_class_byte_budget(
	path: String,
	reason: String,
	size_bytes: int,
	limit_bytes: int,
	stop_scan: bool,
	scan_state: Dictionary
) -> void:
	scan_state["budget_exceeded"] = true
	scan_state["truncated"] = true
	if stop_scan:
		scan_state["stop_scan"] = true
	_mark_class_scan_partial(scan_state)
	_append_class_skipped_file(
		path,
		reason,
		size_bytes,
		reason,
		limit_bytes,
		scan_state
	)
	_append_class_scan_issue(
		reason,
		path,
		"",
		"扩展 class_name 候选脚本超过共享读取字节预算。",
		scan_state
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "budget_warning_emitted"):
		return
	scan_state["budget_warning_emitted"] = true
	_emit_class_scan_warning(
		"[extension_usage_audit.byte_budget_reached] Extension class_name prescanning reached the %s=%d byte budget; results are treated as partial_scan: %s."
		% [
			reason,
			limit_bytes,
			path,
		],
		scan_state
	)


## 将 class_name 阶段标记为超预算、截断、停止和 partial，并追加问题及警告。
## [br]
## @api private
static func _mark_class_phase_exhausted(
	class_name_report: Dictionary,
	code: String,
	message: String
) -> void:
	class_name_report["budget_exceeded"] = true
	class_name_report["truncated"] = true
	class_name_report["stop_scan"] = true
	class_name_report["partial_scan"] = true
	_append_class_scan_issue(
		code,
		"",
		"",
		message,
		class_name_report
	)
	_emit_class_scan_warning(message, class_name_report)


## 将文件路径、跳过原因、大小、预算字段和 class_name 阶段加入 skipped_files。
## [br]
## @api private
static func _append_class_skipped_file(
	path: String,
	reason: String,
	size_bytes: int,
	limit_key: String,
	limit_bytes: int,
	scan_state: Dictionary
) -> void:
	var skipped_files: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "skipped_files")
	skipped_files.append(
		{
			"path": path,
			"reason": reason,
			"size_bytes": size_bytes,
			"limit_key": limit_key,
			"limit_bytes": limit_bytes,
			"phase": "class_name_pre_scan",
		}
	)
	scan_state["skipped_files"] = skipped_files


## 按 code、path 和 target_id 去重后向 class_name 扫描状态追加问题记录。
## [br]
## @api private
static func _append_class_scan_issue(
	code: String,
	path: String,
	target_id: String,
	message: String,
	scan_state: Dictionary
) -> void:
	var issues: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "issues")
	for issue_value: Variant in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "code") == code
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "path") == path
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "target_id") == target_id
		):
			return
	issues.append(
		{
			"code": code,
			"path": path,
			"target_id": target_id,
			"message": message,
			"phase": "class_name_pre_scan",
		}
	)
	scan_state["issues"] = issues


## 添加 GFExtensionUsageAudit 前缀并去重发出 class_name 扫描警告。
## [br]
## @api private
static func _emit_class_scan_warning(message: String, scan_state: Dictionary) -> void:
	var warning_message: String = "[GFExtensionUsageAudit]%s" % message
	var scan_warnings: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "scan_warnings")
	if not scan_warnings.has(warning_message):
		scan_warnings.append(warning_message)
		scan_state["scan_warnings"] = scan_warnings
		push_warning(warning_message)


## 创建项目引用扫描阶段的空报告，并将输入目标数设为 targets.size()。
## [br]
## @api private
static func _make_empty_project_scan_report(targets: Array[Dictionary]) -> Dictionary:
	return {
		"ok": true,
		"partial_scan": false,
		"budget_exceeded": false,
		"truncated": false,
		"input_target_count": targets.size(),
		"target_count": 0,
		"reference_count": 0,
		"weak_reference_count": 0,
		"targets": {},
		"weak_targets": {},
		"references": [],
		"weak_references": [],
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"skipped_files": [],
		"scan_warnings": [],
		"issue_count": 0,
		"issues": [],
	}


## 合并预扫描与项目扫描的消耗、问题和截断标志；仅项目强引用数为零且两个阶段均完整时报告成功，并附预扫描分项详情。
## [br]
## @api private
static func _merge_scan_phase_reports(project_report: Dictionary, class_name_report: Dictionary) -> Dictionary:
	var result: Dictionary = project_report.duplicate(true)
	var partial_scan: bool = (_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(project_report, "partial_scan") or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "partial_scan"))
	result["partial_scan"] = partial_scan
	result["budget_exceeded"] = (_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(project_report, "budget_exceeded") or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "budget_exceeded"))
	result["truncated"] = (_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(project_report, "truncated") or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "truncated"))
	result["candidate_file_count"] = (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "candidate_file_count") + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "candidate_file_count"))
	result["scanned_file_count"] = (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "scanned_file_count") + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_file_count"))
	result["scanned_bytes"] = (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "scanned_bytes") + _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_bytes"))
	result["skipped_files"] = _merge_report_arrays(
		class_name_report,
		project_report,
		"skipped_files"
	)
	result["scan_warnings"] = _merge_report_arrays(
		class_name_report,
		project_report,
		"scan_warnings"
	)
	result["issues"] = _merge_report_arrays(
		class_name_report,
		project_report,
		"issues"
	)
	result["issue_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "issues").size()
	result["ok"] = (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "reference_count") == 0 and not partial_scan)
	result["class_name_scan"] = {
		"partial_scan": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "partial_scan"),
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "budget_exceeded"),
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "candidate_file_count"),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_bytes"),
		"class_names_by_target": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(class_name_report, "class_names_by_target"),
	}
	return result


## 深复制第一个报告的指定数组，再追加第二个报告的数组项。
## [br]
## @api private
static func _merge_report_arrays(
	first_report: Dictionary,
	second_report: Dictionary,
	key: String
) -> Array:
	var result: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(first_report, key).duplicate(true)
	result.append_array(_GF_VARIANT_ACCESS_SCRIPT.get_option_array(second_report, key))
	return result


## 为无效扫描根目录构造 partial_scan 报告及一条 invalid_target_root 问题。
## [br]
## @api private
static func _make_invalid_root_scan_report(root_path: String) -> Dictionary:
	var issue: Dictionary = {
		"code": "invalid_target_root",
		"path": root_path,
		"target_id": root_path,
		"message": "扩展引用扫描 root_path 为空或无效。",
		"phase": "class_name_pre_scan",
	}
	return {
		"ok": false,
		"partial_scan": true,
		"budget_exceeded": false,
		"truncated": false,
		"input_target_count": 1,
		"target_count": 0,
		"reference_count": 0,
		"weak_reference_count": 0,
		"targets": {},
		"weak_targets": {},
		"references": [],
		"weak_references": [],
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"skipped_files": [],
		"scan_warnings": [],
		"issue_count": 1,
		"issues": [issue],
		"class_name_scan": {
			"partial_scan": true,
			"budget_exceeded": false,
			"candidate_file_count": 0,
			"scanned_file_count": 0,
			"scanned_bytes": 0,
			"class_names_by_target": {},
		},
	}


# --- 内部类 ---

## 单目录的有序枚举帧；字段只在本文件内使用，不复制不断增长的目录项列表。
## [br]
## @api private
class _ClassDirectoryFrame:
	extends RefCounted


	# --- 私有变量 ---

	## 当前目录的规范资源路径。
	## [br]
	## @api private
	var _path: String = ""

	## 根目录深度为零，沿子目录递增。
	## [br]
	## @api private
	var _depth: int = 0

	## 目录枚举关闭后才处理已排序子项。
	## [br]
	## @api private
	var _listed: bool = false

	## 当前目录直接子目录名，枚举完成时排序。
	## [br]
	## @api private
	var _directories: Array[String] = []

	## 当前目录直接文件名，待子目录处理完毕后消费。
	## [br]
	## @api private
	var _files: Array[String] = []

	## 下一待处理子目录位置。
	## [br]
	## @api private
	var _directory_index: int = 0

	## 下一待处理文件位置。
	## [br]
	## @api private
	var _file_index: int = 0
