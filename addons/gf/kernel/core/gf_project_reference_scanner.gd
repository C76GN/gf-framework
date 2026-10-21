@tool

## GFProjectReferenceScanner: 项目资源引用扫描服务。
##
## 面向编辑器、CI 和框架诊断流程扫描项目资源与文本源码，按目标根目录和
## class_name 输出 verified、strong 与 weak 分级引用，并在文件数量、
## 目录深度和读取字节预算耗尽时返回 fail-closed 诊断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFProjectReferenceScanner
extends RefCounted


# --- 常量 ---

## 共享选项访问脚本，供扫描预算、目标与报告字典的类型收窄使用。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 统一扫描根和资源路径的规范化及边界匹配规则，避免本扫描器重复维护路径格式。
## [br]
## @api private
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

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

## 仅文本命中的弱引用提示，不会让扫描报告的引用计数阻断。
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
## @since 8.0.0
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]

## 默认最大扫描深度。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大候选扫描文件数。
## [br]
## @api public
## [br]
## @since 8.0.0
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
## @since 8.0.0
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
## @since 8.0.0
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

## 通过 ResourceLoader 依赖图处理的二进制资源扩展名。
## [br]
## @api private
const _BINARY_RESOURCE_EXTENSIONS: Array[String] = ["res", "scn",]

## 接受二进制资源头时要求的最小文件字节数。
## [br]
## @api private
const _MIN_BINARY_RESOURCE_HEADER_BYTES: int = 24


# --- 私有变量 ---

## 一次性请求接纳标志；取消空闲实例同样消耗该实例。
## [br]
## @api private
var _started: bool = false

## 请求已完成或取消时置位，供调度者停止推进。
## [br]
## @api private
var _finished: bool = false

## 取消终态；取消后不保留可领取报告。
## [br]
## @api private
var _cancelled: bool = false

## 当前可观察阶段，不表示可计算的总完成百分比。
## [br]
## @api private
var _phase: String = "idle"

## 仅当前请求使用的选项快照；不借用调用者后续可变输入。
## [br]
## @api private
var _options: Dictionary = {}

## 跨枚举、读取和依赖补入共享的预算、覆盖诊断及累计计数。
## [br]
## @api private
var _scan_state: Dictionary = {}

## 已规范化并隔离的目标；输入顺序决定结果中的目标顺序。
## [br]
## @api private
var _scan_targets: Array[Dictionary] = []

## 各目标跨文件累计的阻断引用，顺序和强度合并沿用同步契约。
## [br]
## @api private
var _references_by_target: Array[Array] = []

## 各目标跨文件累计的弱引用，与阻断额度独立。
## [br]
## @api private
var _weak_references_by_target: Array[Array] = []

## 目标已经观察到额外阻断证据后停止该目标的后续匹配。
## [br]
## @api private
var _blocking_truncated: Array[bool] = []

## 目标弱证据被实际额外命中或阻断截断后的不完整标志。
## [br]
## @api private
var _weak_truncated: Array[bool] = []

## 已接纳的唯一文件；初始排序后，定向依赖仅排序插入未读尾部。
## [br]
## @api private
var _files: Array[String] = []

## 枚举、显式文件及必要依赖共享的规范路径去重集合。
## [br]
## @api private
var _seen_files: Dictionary = {}

## 原始声明目录范围；必要依赖不能借显式文件扩大此范围。
## [br]
## @api private
var _scan_roots: PackedStringArray = PackedStringArray()

## 标准和附加忽略根；定向依赖不能反向带回这些根。
## [br]
## @api private
var _ignored_roots: PackedStringArray = PackedStringArray()

## 实际遇到原生忽略标记的目录，仅在显式启用时记录。
## [br]
## @api private
var _native_ignored_roots: PackedStringArray = PackedStringArray()

## 调用者明确选择的文件，允许位于目录范围外并共享预算。
## [br]
## @api private
var _additional_files: Array[String] = []

## 因原生依赖补入的忽略目录内具体文件，用于范围说明。
## [br]
## @api private
var _dependency_files: Array[String] = []

## 是否按原生标记跳过目录并追踪其中必要的具体依赖文件。
## [br]
## @api private
var _respect_gdignore: bool = false

## 新范围功能实际启用时才向报告附加范围字段。
## [br]
## @api private
var _scope_enabled: bool = false

## 目录混排深度优先游标；每层只保留条目、目录集合和索引。
## [br]
## @api private
var _walk_stack: Array[Dictionary] = []

## 仅当前目录枚举期间持有的原生游标，取消时显式结束。
## [br]
## @api private
var _active_directory: DirAccess = null

## 下一个声明扫描根在稳定排序列表中的位置。
## [br]
## @api private
var _root_index: int = 0

## 目录枚举完成后接纳显式文件的游标。
## [br]
## @api private
var _additional_index: int = 0

## 实际 get_next 返回的目录项数量，包含之后按规则忽略的项。
## [br]
## @api private
var _entries: int = 0

## 下一个待读取候选的位置，已读前缀不因新依赖重新排序。
## [br]
## @api private
var _file_index: int = 0

## 当前文件路径；完成和取消后清空。
## [br]
## @api private
var _current_path: String = ""

## 当前文件原文，最终证据只基于原文和原有识别规则。
## [br]
## @api private
var _source: String = ""

## 仅用于保守排除的路径分隔符副本，绝不作为证据原文。
## [br]
## @api private
var _normalized_source: String = ""

## 当前有文本候选文件的原始行，未命中文本预筛选时不分割。
## [br]
## @api private
var _source_lines: PackedStringArray = PackedStringArray()

## 逐行移除 GDScript 注释后的文本，保持原有行级语义。
## [br]
## @api private
var _code_lines: PackedStringArray = PackedStringArray()

## 逐行屏蔽引号内容后的符号识别文本。
## [br]
## @api private
var _identifier_lines: PackedStringArray = PackedStringArray()

## 本文件原生依赖的规范证据路径，仍保留 UID 与 fallback 证据。
## [br]
## @api private
var _dependency_paths: PackedStringArray = PackedStringArray()

## 选择实际 UID 优先路径后可用于定向补入的依赖候选。
## [br]
## @api private
var _follow_paths: PackedStringArray = PackedStringArray()

## 本文件依赖补入游标，保证每步只准入一个候选。
## [br]
## @api private
var _follow_index: int = 0

## 本文件是否已经执行原生依赖查询，避免分步重复查询。
## [br]
## @api private
var _dependencies_read: bool = false

## 各目标是否可能在当前原文出现；仅为无漏报的负向预筛选。
## [br]
## @api private
var _text_targets: Array[bool] = []

## 当前文件至少一个目标需要原有文本识别时才分割和预处理。
## [br]
## @api private
var _has_text_target: bool = false

## 当前文件的规范化、目标预筛选、分行及逐行处理子阶段。
## [br]
## @api private
var _preprocess_stage: int = 0

## 整文件预筛选当前目标索引。
## [br]
## @api private
var _prefilter_target: int = 0

## 当前目标类名子串探测索引；负值表示尚未检查根路径。
## [br]
## @api private
var _prefilter_class: int = -1

## 预筛选当前目标的隔离类名列表，避免每个类名重新转换数组。
## [br]
## @api private
var _prefilter_names: Array[String] = []

## 当前文本阶段已经处理的物理行数，阶段切换时归零。
## [br]
## @api private
var _line_offset: int = 0

## 当前文件当前文本阶段的物理行数，不是全任务分母。
## [br]
## @api private
var _line_count: int = 0

## 当前文件按原始输入顺序推进的目标游标。
## [br]
## @api private
var _match_target: int = 0

## 当前目标的依赖、强文本、弱文本和提交子阶段。
## [br]
## @api private
var _match_stage: int = -1

## 当前匹配目标的规范根路径。
## [br]
## @api private
var _match_root: String = ""

## 当前匹配目标的稳定 ID。
## [br]
## @api private
var _match_id: StringName = &""

## 当前匹配目标按既有规则排序的类名列表。
## [br]
## @api private
var _match_names: Array[String] = []

## 当前目标的原生依赖证据游标。
## [br]
## @api private
var _match_dependency: int = 0

## 当前文件目标的依赖与强文本合并结果。
## [br]
## @api private
var _match_blocking: Array[Dictionary] = []

## 当前文件强文本结果；独立额度和跨行去重与旧实现一致。
## [br]
## @api private
var _match_text: Array[Dictionary] = []

## 当前文件弱文本结果，排除与阻断证据重复的键。
## [br]
## @api private
var _match_weak: Array[Dictionary] = []

## 当前目标跨文件剩余阻断额度，不包含额外探测位。
## [br]
## @api private
var _remaining_blocking: int = 0

## 当前目标跨文件剩余弱证据额度，不包含额外探测位。
## [br]
## @api private
var _remaining_weak: int = 0

## 剩余阻断额度加一，用于区分恰好达到和实际超额。
## [br]
## @api private
var _blocking_probe: int = 1

## 剩余弱额度加一，保留零额度下的超额探测。
## [br]
## @api private
var _weak_probe: int = 1

## 当前目标尚允许收集弱证据时置位。
## [br]
## @api private
var _match_collect_weak: bool = false

## 当前文件已经观察到超过剩余阻断额度的唯一证据。
## [br]
## @api private
var _file_blocking_truncated: bool = false

## 当前文件已经观察到超过剩余弱额度的唯一证据。
## [br]
## @api private
var _file_weak_truncated: bool = false

## 请求快照中的单目标阻断额度，至少为一。
## [br]
## @api private
var _max_references: int = 50

## 请求快照中的单目标弱证据额度，可为零。
## [br]
## @api private
var _max_weak_references: int = 50

## 目录和必要依赖共享的深度限制，零沿用不限深度语义。
## [br]
## @api private
var _max_scan_depth: int = 32

## 枚举、显式文件和必要依赖共享的唯一候选额度。
## [br]
## @api private
var _max_scanned_files: int = 10000

## 是否按原有规则收集弱文本证据。
## [br]
## @api private
var _include_weak: bool = true

## 是否读取原生资源依赖并准入二进制候选。
## [br]
## @api private
var _use_dependencies: bool = true

## 仅完成后可领取一次的报告，取消清空而不交付局部数据。
## [br]
## @api private
var _result: Dictionary = {}


# --- 公共方法 ---

## 扫描项目文件对一组目标根目录或 class_name 的引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param targets: 扫描目标列表。
## [br]
## @param options: 可选扫描参数。
## [br]
## @schema targets: Array[Dictionary]，每个目标支持 id、root_path 和 class_names；id 为空时使用 root_path。
## [br]
## @schema options: Dictionary，支持 scan_roots、ignored_roots、additional_ignored_roots、max_references_per_target、max_weak_references_per_target、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references、use_resource_dependencies、warning_prefix、respect_gdignore（默认 false）和 additional_scan_files（默认空）。显式文件可越过 scan_roots、隐藏目录和 .gdignore，但仍遵守 ignored_roots、文件类型及共享文件/字节预算。
## [br]
## @return 项目引用扫描报告。
## [br]
## @schema return: Dictionary，包含 ok、partial_scan、budget_exceeded、truncated、input_target_count、target_count、reference_count、weak_reference_count、targets、weak_targets、references、weak_references、candidate_file_count、scanned_file_count、scanned_bytes、skipped_files、scan_warnings、issue_count 和 issues；仅 respect_gdignore 为 true 或 additional_scan_files 非空时增加 scope，记录 respect_gdignore、additional_scan_files、ignored_directories 和 dependency_files；scope.additional_scan_files 是规范化请求列表，非成功扫描列表，非支持格式与目录候选一样排除，实际准入和读取量由计数报告。
static func scan_references(targets: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	var scanner: GFProjectReferenceScanner = GFProjectReferenceScanner.new()
	var _accepted: bool = scanner.start(targets, options)
	while not scanner.step(128, 0):
		pass
	return scanner.take_result()


## 扫描项目文件对单个根目录的引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_path: 要匹配的根目录。
## [br]
## @param class_names: 同一目标根目录下需要匹配的 class_name 列表。
## [br]
## @param options: 可选扫描参数。
## [br]
## @schema class_names: Array[String]，与 root_path 同属一个目标的公开 class_name 列表。
## [br]
## @schema options: Dictionary，支持 scan_references() 的所有 options；默认会把 root_path 加入 additional_ignored_roots，避免扫描目标自身。
## [br]
## @return 单目标项目引用扫描报告。
## [br]
## @schema return: Dictionary，字段同 scan_references() 返回值。
static func scan_root_references(
	root_path: String,
	class_names: Array[String] = [],
	options: Dictionary = {}
) -> Dictionary:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		# 保留原始调用目标，让统一 target preflight 输出 invalid_target_root
		# 并以 partial/ok=false 终结；空 targets 本身是合法的无工作量扫描。
		return scan_references(
			[
				{
					"id": root_path,
					"root_path": root_path,
					"class_names": class_names,
				},
			],
			options
		)

	var scan_options: Dictionary = options.duplicate(true)
	var ignored_roots: PackedStringArray = _read_additional_ignored_roots(scan_options)
	if not ignored_roots.has(normalized_root):
		var _append_root: bool = ignored_roots.append(normalized_root)
	scan_options["additional_ignored_roots"] = ignored_roots
	return scan_references(
		[
			{
				"id": normalized_root,
				"root_path": normalized_root,
				"class_names": class_names,
			},
		],
		scan_options
	)


# --- 框架内部方法 ---

## 接纳一次输入快照但不枚举或读取文件；输入无效仍接纳并交付终态错误报告。
## [br]
## @api framework_internal
## [br]
## @param targets: 与同步入口相同的目标列表。
## [br]
## @param options: 与同步入口相同的预算和范围选项。
## [br]
## @schema targets: Array[Dictionary]，字段及无效目标语义同 scan_references()。
## [br]
## @schema options: Dictionary，字段及默认预算同 scan_references()。
## [br]
## @return 首次接纳返回 true；已接纳或已取消实例返回 false 且不改变原请求。
func start(targets: Array[Dictionary], options: Dictionary = {}) -> bool:
	if _started:
		return false
	_started = true
	_options = _capture_options(options)
	_scan_state = _make_scan_state(_options)
	_scan_state["input_target_count"] = targets.size()
	_scan_targets = _normalize_targets(targets, _scan_state)
	_max_references = maxi(
		_get_option_int_with_alias(
			_options,
			"max_references_per_target",
			"max_references_per_extension",
			50
		),
		1
	)
	_max_weak_references = maxi(
		_get_option_int_with_alias(
			_options,
			"max_weak_references_per_target",
			"max_weak_references_per_extension",
			_max_references
		),
		0
	)
	_max_scan_depth = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			_options,
			"max_scan_depth",
			DEFAULT_MAX_SCAN_DEPTH
		),
		0
	)
	_max_scanned_files = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			_options,
			"max_scanned_files",
			DEFAULT_MAX_SCANNED_FILES
		),
		0
	)
	_include_weak = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		_options,
		"include_weak_references",
		true
	)
	_use_dependencies = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		_options,
		"use_resource_dependencies",
		true
	)
	_respect_gdignore = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_options, "respect_gdignore")
	for _target: Dictionary in _scan_targets:
		_references_by_target.append([])
		_weak_references_by_target.append([])
		_blocking_truncated.append(false)
		_weak_truncated.append(false)
	if _scan_targets.is_empty() or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_scan_state, "target_preflight_failed"):
		_finish_scan()
		return true
	_prepare_scope()
	_phase = "enumerate"
	return true


## 推进有限工作单元；时间上限是协作式软界限，单次原生读取、依赖查询和排序不可抢占。
## [br]
## @api framework_internal
## [br]
## @param max_items: 本次最多推进的单元数，非正值按一处理。
## [br]
## @param max_usec: 微秒软预算，非正值禁用时间限制；每次至少推进一个单元。
## [br]
## @return 完成或取消返回 true；未 start 的空闲实例返回 false。
func step(max_items: int = 128, max_usec: int = 4000) -> bool:
	if not _started:
		return false
	if _finished:
		return true
	var started_usec: int = Time.get_ticks_usec()
	var processed: int = 0
	while not _finished and processed < maxi(max_items, 1):
		if (
			processed > 0
			and max_usec > 0
			and Time.get_ticks_usec() - started_usec >= max_usec
		):
			break
		_advance_one()
		processed += 1
	return _finished


## 终止一次性实例，关闭目录游标并丢弃工作数据及尚未领取的完成报告。
## [br]
## @api framework_internal
func cancel() -> void:
	_started = true
	_finished = true
	_cancelled = true
	_phase = "cancelled"
	_result = {}
	_release_work()


## 返回仅含标量的独立进度快照；当前行数只描述当前文件当前文本阶段。
## [br]
## @api framework_internal
## [br]
## @return 独立标量进度字典，完成或领取后仍保留累计计数。
## [br]
## @schema return: Dictionary，包含 phase、finished、cancelled、entries、candidate_files、scanned_files、scanned_bytes、current_path、line_offset 和 line_count；行数仅属于当前文件当前阶段。
func get_progress() -> Dictionary:
	return {
		"phase": _phase,
		"finished": _finished,
		"cancelled": _cancelled,
		"entries": _entries,
		"candidate_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_scan_state, "candidate_file_count"),
		"scanned_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_scan_state, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_scan_state, "scanned_bytes"),
		"current_path": _current_path,
		"line_offset": _line_offset,
		"line_count": _line_count,
	}


## 转移一次完整结果所有权；未完成、已取消或已领取时不交付局部数据。
## [br]
## @api framework_internal
## [br]
## @return 完成报告或空字典。
## [br]
## @schema return: Dictionary，完成时字段同 scan_references()，其他状态为空。
func take_result() -> Dictionary:
	if not _finished or _cancelled:
		return {}
	var result: Dictionary = _result
	_result = {}
	return result


# --- 私有/辅助方法 ---

## 只捕获受支持选项的值，拒绝借用调用者数组，也不复制无关对象或循环容器。
## [br]
## @api private
static func _capture_options(options: Dictionary) -> Dictionary:
	var max_references: int = maxi(
		_get_option_int_with_alias(
			options,
			"max_references_per_target",
			"max_references_per_extension",
			50
		),
		1
	)
	return {
		"scan_roots": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
			options,
			"scan_roots",
			DEFAULT_SCAN_ROOTS
		),
		"ignored_roots": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
			options,
			"ignored_roots",
			DEFAULT_IGNORED_ROOTS
		),
		"additional_scan_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, "additional_scan_files"),
		"additional_ignored_roots": _read_additional_ignored_roots(options),
		"max_references_per_target": max_references,
		"max_weak_references_per_target": maxi(
			_get_option_int_with_alias(
				options,
				"max_weak_references_per_target",
				"max_weak_references_per_extension",
				max_references
			),
			0
		),
		"max_scan_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_scan_depth",
			DEFAULT_MAX_SCAN_DEPTH
		),
		"max_scanned_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_scanned_files",
			DEFAULT_MAX_SCANNED_FILES
		),
		"max_file_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_file_bytes",
			DEFAULT_MAX_FILE_BYTES
		),
		"max_total_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_total_bytes",
			DEFAULT_MAX_TOTAL_BYTES
		),
		"include_weak_references": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			options,
			"include_weak_references",
			true
		),
		"use_resource_dependencies": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			options,
			"use_resource_dependencies",
			true
		),
		"respect_gdignore": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "respect_gdignore"),
		"warning_prefix": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			options,
			"warning_prefix",
			"[GFProjectReferenceScanner]"
		),
	}


## 在接纳阶段仅规范化路径和范围说明，不访问文件系统。
## [br]
## @api private
func _prepare_scope() -> void:
	for raw_root: String in _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
		_options,
		"scan_roots",
		DEFAULT_SCAN_ROOTS
	):
		var root: String = _GF_PATH_TOOLS.normalize_root_path(raw_root)
		if root.is_empty():
			_mark_scan_partial(_scan_state)
			_append_scan_issue(
				"invalid_scan_root",
				raw_root,
				"",
				"scan_roots 包含空或无效路径。",
				_scan_state
			)
		elif not _scan_roots.has(root):
			var _appended_root: bool = _scan_roots.append(root)
	_scan_roots.sort()
	_ignored_roots = _GF_PATH_TOOLS.normalize_root_paths(
		PackedStringArray(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
				_options,
				"ignored_roots",
				DEFAULT_IGNORED_ROOTS
			)
		)
	)
	for root: String in _read_additional_ignored_roots(_options):
		if not root.is_empty() and not _ignored_roots.has(root):
			var _appended_ignored: bool = _ignored_roots.append(root)
	var requested_files: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(_options, "additional_scan_files")
	_scope_enabled = _respect_gdignore or not requested_files.is_empty()
	for raw_path: String in requested_files:
		var path: String = _GF_PATH_TOOLS.normalize_resource_path(raw_path)
		if (
			path.is_empty()
			or not (
				path.begins_with("res://")
				or path.begins_with("user://")
			)
		):
			_mark_scan_partial(_scan_state)
			_append_scan_issue(
				"invalid_scan_file",
				raw_path,
				"",
				"additional_scan_files 包含无效资源路径。",
				_scan_state
			)
		elif not _additional_files.has(path):
			_additional_files.append(path)
	_additional_files.sort()
	_scan_state["respect_gdignore"] = _respect_gdignore


## 每次只推进当前阶段的一个可中断边界；不可中断原生调用由 step 的软预算说明约束。
## [br]
## @api private
func _advance_one() -> void:
	match _phase:
		"enumerate":
			_advance_enumeration()
		"read":
			_read_next_file()
		"dependencies":
			_advance_dependencies()
		"preprocess":
			_advance_preprocess()
		"match":
			_advance_match()
		"finalize":
			_finish_scan()


## 通过 get_next 分步收集一个目录，再保持旧目录与文件混排的字典序深度优先消费。
## [br]
## @api private
func _advance_enumeration() -> void:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_scan_state, "file_collection_stopped"):
		_end_enumeration()
		return
	if _active_directory != null:
		var entry_name: String = _active_directory.get_next()
		var collecting_frame: Dictionary = _walk_stack.back()
		if entry_name.is_empty():
			_active_directory.list_dir_end()
			_active_directory = null
			var collected_entries: Array = collecting_frame["entries"]
			collected_entries.sort()
			collecting_frame["index"] = 0
			return
		_entries += 1
		if not entry_name.begins_with("."):
			var pending_entries: Array = collecting_frame["entries"]
			pending_entries.append(entry_name)
			if _active_directory.current_is_dir():
				var collected_directories: Dictionary = collecting_frame["directories"]
				collected_directories[entry_name] = true
		return
	if _walk_stack.is_empty():
		if _root_index < _scan_roots.size():
			_push_directory(
				_scan_roots[_root_index],
				0
			)
			_root_index += 1
			return
		if _additional_index < _additional_files.size():
			var additional_path: String = _additional_files[_additional_index]
			_additional_index += 1
			if not _is_path_ignored(additional_path, _ignored_roots) and _supports_candidate(additional_path):
				var _added: bool = _add_candidate(additional_path, false)
			return
		_end_enumeration()
		return
	var frame: Dictionary = _walk_stack.back()
	var index: int = frame["index"]
	if index < 0:
		_open_directory(frame)
		return
	var entries: Array = frame["entries"]
	if index >= entries.size():
		var _removed_frame: Variant = _walk_stack.pop_back()
		return
	var entry: String = entries[index]
	frame["index"] = index + 1
	var root_path: String = frame["path"]
	var depth: int = frame["depth"]
	var path: String = _GF_PATH_TOOLS.normalize_resource_path(root_path.path_join(entry))
	var directories: Dictionary = frame["directories"]
	if directories.has(entry):
		if _can_scan_deeper(
			path,
			depth,
			_max_scan_depth,
			_scan_state
		):
			_push_directory(
				path,
				depth + 1
			)
	elif _supports_candidate(path):
		var _added: bool = _add_candidate(path, false)


## 加入尚未打开的目录游标；实际 I/O 由后续单元执行。
## [br]
## @api private
func _push_directory(path: String, depth: int) -> void:
	_walk_stack.append(
		{
			"path": path,
			"depth": depth,
			"entries": [],
			"directories": {},
			"index": -1,
		}
	)


## 打开一个目录或记录原生忽略范围；失败沿用原有覆盖诊断，不留下未关闭游标。
## [br]
## @api private
func _open_directory(frame: Dictionary) -> void:
	var path: String = frame["path"]
	var depth: int = frame["depth"]
	if path.is_empty() or _is_path_ignored(path, _ignored_roots):
		var _removed_ignored: Variant = _walk_stack.pop_back()
		return
	var native_ignored: String = _find_native_ignored_directory(
		path,
		depth == 0
	) if _respect_gdignore else ""
	if not native_ignored.is_empty():
		if not _native_ignored_roots.has(native_ignored):
			var _appended_ignored: bool = _native_ignored_roots.append(native_ignored)
		var _removed_native: Variant = _walk_stack.pop_back()
		return
	_active_directory = DirAccess.open(path)
	if _active_directory == null:
		_mark_scan_partial(_scan_state)
		_append_skipped_file(
			path,
			"directory_open_failed",
			0,
			"",
			0,
			_scan_state
		)
		_append_scan_issue(
			"scan_root_open_failed" if depth == 0 else "scan_directory_open_failed",
			path,
			"",
			"无法打开扫描目录。",
			_scan_state
		)
		var _removed_unreadable: Variant = _walk_stack.pop_back()
		return
	if _active_directory.list_dir_begin() != OK:
		_active_directory = null
		_mark_scan_partial(_scan_state)
		_append_skipped_file(
			path,
			"directory_list_failed",
			0,
			"",
			0,
			_scan_state
		)
		_append_scan_issue(
			"scan_directory_list_failed",
			path,
			"",
			"无法枚举扫描目录。",
			_scan_state
		)
		var _removed_failed: Variant = _walk_stack.pop_back()


## 显式扫描根还须检查其祖先标记；后代目录已沿父游标检查，只需读取本级标记。
## [br]
## @api private
static func _find_native_ignored_directory(path: String, include_ancestors: bool) -> String:
	var current: String = path
	while not current.is_empty():
		if FileAccess.file_exists(current.path_join(".gdignore")):
			return current
		if not include_ancestors or current.ends_with("://"):
			break
		var parent: String = _GF_PATH_TOOLS.normalize_root_path(current.get_base_dir())
		if parent == current:
			break
		current = parent
	return ""


## 目录和显式文件共享同一候选集合；额外一项才触发文件预算，必要依赖仅插入待读尾部。
## [br]
## @api private
func _add_candidate(path: String, dependency: bool) -> bool:
	if _seen_files.has(path):
		return false
	if _max_scanned_files > 0 and _files.size() >= _max_scanned_files:
		_warn_scanned_file_limit(_max_scanned_files, _scan_state)
		return false
	_seen_files[path] = true
	if dependency:
		var low: int = _file_index
		var high: int = _files.size()
		while low < high:
			var middle: int = low + ((high - low) >> 1)
			if _files[middle] < path:
				low = middle + 1
			else:
				high = middle
		var _inserted: int = _files.insert(low, path)
		_dependency_files.append(path)
	else:
		_files.append(path)
	_scan_state["candidate_file_count"] = _files.size()
	return true


## 按既有文本类型与依赖选项决定文件是否属于扫描候选。
## [br]
## @api private
func _supports_candidate(path: String) -> bool:
	return (
		_is_text_resource_file(path)
		or (
			_use_dependencies
			and _is_binary_resource_file(path)
		)
	)


## 枚举完成后稳定排序初始候选，并释放目录列表；不会把配额刚好耗尽误判为截断。
## [br]
## @api private
func _end_enumeration() -> void:
	if _active_directory != null:
		_active_directory.list_dir_end()
		_active_directory = null
	_walk_stack = []
	_files.sort()
	_scan_state["candidate_file_count"] = _files.size()
	_phase = "read"


## 按原预算读取下一个文件；即使所有目标已截断，仍保留读取和依赖失败检查。
## [br]
## @api private
func _read_next_file() -> void:
	_release_current_file()
	if _file_index >= _files.size() or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_scan_state, "stop_scan"):
		_phase = "finalize"
		return
	_current_path = _files[_file_index]
	_file_index += 1
	var source_report: Dictionary = _read_scan_source(
		_current_path,
		_options,
		_scan_state
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(source_report, "ok"):
		return
	_source = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_report, "source")
	_phase = "dependencies"


## 每文件仅查询一次原生依赖，随后逐项准入必要忽略文件；证据路径与实际读取路径分开保留。
## [br]
## @api private
func _advance_dependencies() -> void:
	if not _dependencies_read:
		_dependencies_read = true
		if _use_dependencies:
			_dependency_paths = _collect_resource_dependency_paths(
				_current_path,
				_source,
				_scan_state
			)
			var follow_value: Variant = _scan_state.get(
				"follow_dependency_paths",
				PackedStringArray()
			)
			if follow_value is PackedStringArray:
				_follow_paths = follow_value
			var _removed_follow_paths: bool = _scan_state.erase("follow_dependency_paths")
		return
	if _follow_index < _follow_paths.size():
		var path: String = _follow_paths[_follow_index]
		_follow_index += 1
		_add_required_ignored_dependency(path)
		return
	_phase = "preprocess"


## 仅补入原目录范围内、原生忽略目录中的具体必要文件，禁止反向带回标准忽略根或范围外闭包。
## [br]
## @api private
func _add_required_ignored_dependency(path: String) -> void:
	if (
		not _respect_gdignore
		or _seen_files.has(path)
		or not _supports_candidate(path)
		or _is_path_ignored(path, _ignored_roots)
	):
		return
	if not _is_path_ignored(path, _native_ignored_roots):
		return
	var admitted_depth: int = -1
	for root: String in _scan_roots:
		if not _GF_PATH_TOOLS.is_path_under_root(
			path,
			root,
			false
		):
			continue
		var relative: String = _GF_PATH_TOOLS.make_relative_path(path, root)
		var depth: int = relative.get_base_dir().split("/", false).size()
		if admitted_depth < 0 or depth < admitted_depth:
			admitted_depth = depth
	if admitted_depth < 0:
		return
	if _max_scan_depth > 0 and admitted_depth > _max_scan_depth:
		_warn_scan_depth_limit(
			path.get_base_dir(),
			_max_scan_depth,
			_scan_state
		)
		return
	var _added: bool = _add_candidate(path, true)


## 整文件只作保守子串排除；原文类名与规范化路径均无可能命中时避免分行和逐目标匹配。
## [br]
## @api private
func _advance_preprocess() -> void:
	if _preprocess_stage == 0:
		_normalized_source = _normalize_source_line_path_separators(_source)
		for _target: Dictionary in _scan_targets:
			_text_targets.append(false)
		_preprocess_stage = 1
		return
	if _preprocess_stage == 1:
		if _prefilter_target >= _scan_targets.size():
			_normalized_source = ""
			_prefilter_names = []
			_preprocess_stage = 2
			return
		if _blocking_truncated[_prefilter_target]:
			_prefilter_target += 1
			_prefilter_class = -1
			return
		var target: Dictionary = _scan_targets[_prefilter_target]
		if _prefilter_class < 0:
			var root: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
			var possible: bool = _normalized_source.contains(root)
			if not possible:
				for variant: String in _root_reference_variants(root):
					if _source.contains(variant):
						possible = true
						break
			if possible:
				_accept_text_target()
				return
			var class_prefix: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "_class_name_prefix")
			if not class_prefix.is_empty() and not _source.contains(class_prefix):
				_prefilter_target += 1
				return
			_prefilter_names = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(target, "class_names")
			_prefilter_class = 0
			return
		if _prefilter_class >= _prefilter_names.size():
			_prefilter_target += 1
			_prefilter_class = -1
			return
		var class_name_text: String = _prefilter_names[_prefilter_class]
		_prefilter_class += 1
		if not class_name_text.is_empty() and _source.contains(class_name_text):
			_accept_text_target()
		return
	if _preprocess_stage == 2:
		if _has_text_target:
			_source_lines = _source.split("\n")
		_line_count = _source_lines.size()
		_line_offset = 0
		_preprocess_stage = 3
		return
	if _current_path.get_extension().to_lower() == "gd" and _line_offset < _line_count:
		var code: String = _strip_gdscript_line_comment(_source_lines[_line_offset])
		var _appended_code: bool = _code_lines.append(code)
		var _appended_identifier: bool = _identifier_lines.append(_replace_quoted_segments(code))
		_line_offset += 1
		return
	_line_offset = 0
	_line_count = 0
	_phase = "match"


## 接纳当前目标的文本候选而不产生证据；最终仍经过原有边界与语境识别。
## [br]
## @api private
func _accept_text_target() -> void:
	_text_targets[_prefilter_target] = true
	_has_text_target = true
	_prefilter_target += 1
	_prefilter_class = -1
	_prefilter_names = []


## 对一个目标依次推进依赖、强文本、弱文本；每个文本单元只处理一行并共享本文件去重数组。
## [br]
## @api private
func _advance_match() -> void:
	if _match_target >= _scan_targets.size():
		_phase = "read"
		_line_offset = 0
		_line_count = 0
		return
	if _blocking_truncated[_match_target]:
		_match_target += 1
		return
	if _match_stage < 0:
		_begin_match_target()
		return
	if _match_stage == 0:
		if _match_dependency < _dependency_paths.size() and _match_blocking.size() < _blocking_probe:
			var dependency_path: String = _dependency_paths[_match_dependency]
			_match_dependency += 1
			if not dependency_path.is_empty() and _line_references_root(dependency_path, _match_root):
				_append_reference_unique(
					_match_blocking,
					_make_reference(
						_current_path,
						0,
						_match_root,
						_match_id,
						"path",
						"",
						_match_root,
						REFERENCE_STRENGTH_VERIFIED,
						REFERENCE_SOURCE_GODOT_DEPENDENCY,
						dependency_path
					),
					_blocking_probe
				)
			return
		_match_stage = 1
		_line_offset = 0
		_line_count = _source_lines.size() if _text_targets[_match_target] else 0
		return
	if _match_stage == 1:
		var extension: String = _current_path.get_extension().to_lower()
		if (
			_line_offset < _line_count
			and _match_text.size() < _blocking_probe
			and (
				extension == "gd"
				or _is_resource_text_extension(extension)
			)
		):
			if extension == "gd":
				_collect_gdscript_line_references(
					_current_path,
					_code_lines[_line_offset],
					_identifier_lines[_line_offset],
					_match_root,
					_match_id,
					_match_names,
					_blocking_probe,
					_match_text,
					_line_offset + 1
				)
			else:
				_collect_resource_line_references(
					_current_path,
					_source_lines[_line_offset],
					_match_root,
					_match_id,
					_blocking_probe,
					_match_text,
					_line_offset + 1
				)
			_line_offset += 1
			return
		_append_reference_array_unique(
			_match_blocking,
			_match_text,
			_blocking_probe
		)
		_file_blocking_truncated = _match_blocking.size() > _remaining_blocking
		if _file_blocking_truncated:
			var _resized_blocking: int = _match_blocking.resize(maxi(_remaining_blocking, 0))
		_match_stage = 2
		_line_offset = 0
		_line_count = (
			_source_lines.size()
			if (
				_text_targets[_match_target]
				and _match_collect_weak
				and not _file_blocking_truncated
			)
			else 0
		)
		return
	if _match_stage == 2:
		if _line_offset < _line_count and _match_weak.size() < _weak_probe:
			var line: String = _code_lines[_line_offset] if _current_path.get_extension().to_lower() == "gd" else _source_lines[_line_offset]
			_collect_weak_line_references(
				_current_path,
				line,
				_match_root,
				_match_id,
				_match_names,
				_match_blocking,
				_match_weak,
				_weak_probe,
				_line_offset + 1
			)
			_line_offset += 1
			return
		_file_weak_truncated = _match_weak.size() > _remaining_weak
		if _file_weak_truncated:
			var _resized_weak: int = _match_weak.resize(maxi(_remaining_weak, 0))
		_match_stage = 3
		_line_offset = 0
		_line_count = 0
		return
	_commit_match_target()


## 建立本文件目标的独立加一探测额度；依赖与强文本分别收集后按原优先级合并。
## [br]
## @api private
func _begin_match_target() -> void:
	var target: Dictionary = _scan_targets[_match_target]
	_match_root = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
	_match_id = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(target, "id")
	_match_names = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(target, "class_names")
	_match_blocking = []
	_match_text = []
	_match_weak = []
	_remaining_blocking = _max_references - _references_by_target[_match_target].size()
	_remaining_weak = _max_weak_references - _weak_references_by_target[_match_target].size()
	_blocking_probe = maxi(
		_remaining_blocking + 1,
		1
	)
	_weak_probe = maxi(
		_remaining_weak + 1,
		1
	)
	_match_collect_weak = _include_weak and not _weak_truncated[_match_target]
	_file_blocking_truncated = false
	_file_weak_truncated = false
	_match_dependency = 0
	_match_stage = 0
	_line_offset = 0
	_line_count = 0


## 提交单文件目标证据，保持阻断截断同时使弱证据不完整的既有语义。
## [br]
## @api private
func _commit_match_target() -> void:
	var references: Array = _references_by_target[_match_target]
	var weak_references: Array = _weak_references_by_target[_match_target]
	_append_reference_array_unique(
		references,
		_match_blocking,
		_max_references
	)
	_append_reference_array_unique(
		weak_references,
		_match_weak,
		_max_weak_references
	)
	if _file_blocking_truncated:
		_blocking_truncated[_match_target] = true
		if _include_weak:
			_weak_truncated[_match_target] = true
		_mark_target_quota_truncated(
			String(_match_id),
			"max_references_per_target",
			_scan_state
		)
	if _file_weak_truncated:
		_weak_truncated[_match_target] = true
		_mark_target_quota_truncated(
			String(_match_id),
			"max_weak_references_per_target",
			_scan_state
		)
	_match_target += 1
	_match_stage = -1
	_line_offset = 0
	_line_count = 0


## 完成时按原目标顺序投影报告；仅启用新范围功能才添加 scope，默认报告保持原有字段。
## [br]
## @api private
func _finish_scan() -> void:
	var target_reports: Dictionary = {}
	var weak_target_reports: Dictionary = {}
	var all_references: Array[Dictionary] = []
	var all_weak_references: Array[Dictionary] = []
	for index: int in range(_scan_targets.size()):
		var target: Dictionary = _scan_targets[index]
		var target_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(target, "id")
		var root_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
		var references: Array = _references_by_target[index]
		var weak_references: Array = _weak_references_by_target[index]
		var blocking_truncated: bool = _blocking_truncated[index]
		var weak_truncated: bool = _weak_truncated[index]
		if not references.is_empty() or blocking_truncated:
			target_reports[target_id] = {
				"id": String(target_id),
				"root_path": root_path,
				"references": references,
				"reference_count": references.size(),
				"truncated": blocking_truncated,
				"truncation_reason": "max_references_per_target" if blocking_truncated else "",
			}
			all_references.append_array(references)
		if not weak_references.is_empty() or weak_truncated:
			var reason: String = ""
			if weak_truncated:
				reason = "max_references_per_target" if blocking_truncated else "max_weak_references_per_target"
			weak_target_reports[target_id] = {
				"id": String(target_id),
				"root_path": root_path,
				"references": weak_references,
				"reference_count": weak_references.size(),
				"truncated": weak_truncated,
				"truncation_reason": reason,
			}
			all_weak_references.append_array(weak_references)
	_result = _make_scan_report(
		_scan_targets,
		all_references,
		all_weak_references,
		target_reports,
		weak_target_reports,
		_scan_state
	)
	if _scope_enabled:
		var ignored: Array[String] = []
		for path: String in _native_ignored_roots:
			ignored.append(path)
		ignored.sort()
		_dependency_files.sort()
		_result["scope"] = {
			"respect_gdignore": _respect_gdignore,
			"additional_scan_files": _additional_files.duplicate(),
			"ignored_directories": ignored,
			"dependency_files": _dependency_files.duplicate(),
		}
	_finished = true
	_phase = "finished"
	_release_work()


## 释放当前文件大文本与所有匹配游标，不改变已经累计的覆盖计数。
## [br]
## @api private
func _release_current_file() -> void:
	_current_path = ""
	_source = ""
	_normalized_source = ""
	_source_lines = PackedStringArray()
	_code_lines = PackedStringArray()
	_identifier_lines = PackedStringArray()
	_dependency_paths = PackedStringArray()
	_follow_paths = PackedStringArray()
	_follow_index = 0
	_dependencies_read = false
	_text_targets = []
	_has_text_target = false
	_preprocess_stage = 0
	_prefilter_target = 0
	_prefilter_class = -1
	_prefilter_names = []
	_line_offset = 0
	_line_count = 0
	_match_target = 0
	_match_stage = -1
	_match_names = []
	_match_root = ""
	_match_id = &""
	_match_blocking = []
	_match_text = []
	_match_weak = []


## 完成或取消时关闭唯一目录游标并释放工作容器；只保留小型进度计数及待领取报告。
## [br]
## @api private
func _release_work() -> void:
	if _active_directory != null:
		_active_directory.list_dir_end()
		_active_directory = null
	_release_current_file()
	_options = {}
	_walk_stack = []
	_files = []
	_seen_files = {}
	_scan_targets = []
	_references_by_target = []
	_weak_references_by_target = []
	_blocking_truncated = []
	_weak_truncated = []
	_scan_roots = PackedStringArray()
	_ignored_roots = PackedStringArray()
	_native_ignored_roots = PackedStringArray()
	_additional_files = []
	_dependency_files = []
	_scan_state = {
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_scan_state, "candidate_file_count"),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_scan_state, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_scan_state, "scanned_bytes"),
	}


## 规范化根路径、补足空 ID、排序类名并固定共同前缀；报告无效根或重复目标 ID。
## [br]
## @api private
static func _normalize_targets(targets: Array[Dictionary], scan_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target_ids: Dictionary = {}
	for target_index: int in range(targets.size()):
		var raw_target: Dictionary = targets[target_index]
		var root_path: String = _GF_PATH_TOOLS.normalize_root_path(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_target, "root_path"))
		if root_path.is_empty():
			scan_state["target_preflight_failed"] = true
			_mark_scan_partial(scan_state)
			_append_scan_issue(
				"invalid_target_root",
				"",
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_target, "id"),
				"扫描目标 root_path 为空或无效。",
				scan_state
			)
			continue

		var target_id_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_target, "id")
		if target_id_text.is_empty():
			target_id_text = root_path
		var target_id: StringName = StringName(target_id_text)
		if target_ids.has(target_id):
			scan_state["target_preflight_failed"] = true
			_mark_scan_partial(scan_state)
			_append_scan_issue(
				"duplicate_target_id",
				root_path,
				target_id_text,
				"扫描目标 id 必须唯一。",
				scan_state
			)
			continue
		target_ids[target_id] = true
		var class_names: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(raw_target, "class_names")
		class_names.sort()
		result.append(
			{
				"id": target_id,
				"root_path": root_path,
				"class_names": class_names,
				"_class_name_prefix": _common_class_name_prefix(class_names),
			}
		)
	return result


## 接纳时计算非空类名的逐字符共同前缀，仅作原文不含前缀时的否定筛选，不改变类名边界规则。
## [br]
## @api private
static func _common_class_name_prefix(class_names: Array[String]) -> String:
	var prefix: String = ""
	var initialized: bool = false
	for class_name_value: String in class_names:
		if class_name_value.is_empty():
			continue
		if not initialized:
			prefix = class_name_value
			initialized = true
			continue
		var shared_length: int = 0
		var limit: int = mini(
			prefix.length(),
			class_name_value.length()
		)
		while shared_length < limit and prefix.unicode_at(shared_length) == class_name_value.unicode_at(shared_length):
			shared_length += 1
		prefix = prefix.substr(0, shared_length)
		if prefix.is_empty():
			break
	return prefix


## 在单文件和总字节预算内读取文本，二进制资源仅验证头和可加载性；成功才累加扫描数及声明大小，总预算超限要求停止扫描。
## [br]
## @api private
static func _read_scan_source(
	path: String,
	options: Dictionary,
	scan_state: Dictionary
) -> Dictionary:
	var result: Dictionary = { "ok": false, "source": "", }
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_mark_scan_partial(scan_state)
		_append_skipped_file(
			path,
			"read_failed",
			0,
			"",
			0,
			scan_state
		)
		_append_scan_issue(
			"scan_file_open_failed",
			path,
			"",
			"无法打开候选扫描文件。",
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
	var max_total_bytes: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			"max_total_bytes",
			DEFAULT_MAX_TOTAL_BYTES
		),
		0
	)
	if max_file_bytes > 0 and size_bytes > max_file_bytes:
		file.close()
		_mark_budget_exceeded(
			path,
			"max_file_bytes",
			size_bytes,
			max_file_bytes,
			scan_state
		)
		return result

	var scanned_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_bytes")
	if max_total_bytes > 0 and scanned_bytes + size_bytes > max_total_bytes:
		file.close()
		_mark_budget_exceeded(
			path,
			"max_total_bytes",
			scanned_bytes + size_bytes,
			max_total_bytes,
			scan_state
		)
		scan_state["stop_scan"] = true
		return result

	if _is_binary_resource_file(path):
		var header_bytes: PackedByteArray = file.get_buffer(4)
		var binary_header: String = header_bytes.get_string_from_ascii()
		if (
			header_bytes.size() != 4
			or (
				binary_header != "RSRC"
				and binary_header != "RSCC"
			)
			or size_bytes < _MIN_BINARY_RESOURCE_HEADER_BYTES
			or not ResourceLoader.exists(path)
		):
			file.close()
			_mark_scan_partial(scan_state)
			_append_skipped_file(
				path,
				"resource_dependencies_unavailable",
				size_bytes,
				"",
				0,
				scan_state
			)
			_append_scan_issue(
				"resource_dependencies_unavailable",
				path,
				"",
				"无法解析二进制资源依赖。",
				scan_state
			)
			return result

	if not _is_binary_resource_file(path):
		result["source"] = file.get_as_text()
		var read_error: Error = file.get_error()
		if read_error != OK:
			file.close()
			_mark_scan_partial(scan_state)
			_append_skipped_file(
				path,
				"read_failed",
				size_bytes,
				"",
				0,
				scan_state
			)
			_append_scan_issue(
				"scan_file_read_failed",
				path,
				"",
				"读取候选扫描文件失败。",
				scan_state
			)
			return result
	result["ok"] = true
	file.close()
	scan_state["scanned_file_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_file_count") + 1
	scan_state["scanned_bytes"] = scanned_bytes + size_bytes
	return result


## 预检文本资源头并读取 ResourceLoader 依赖记录，解析 URI 或 UID 后去重排序；无法读取或解析时记录部分扫描，空列表不代表肯定无依赖。
## [br]
## @api private
static func _collect_resource_dependency_paths(
	path: String,
	source: String,
	scan_state: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var follow_paths: PackedStringArray = PackedStringArray()
	var follow_required: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "respect_gdignore")
	if _is_loadable_text_resource_file(path) and not _resource_text_has_valid_header(path, source):
		_mark_resource_dependencies_unavailable(path, scan_state)
		return result
	if not ResourceLoader.exists(path):
		if _is_loadable_resource_file(path):
			_mark_resource_dependencies_unavailable(path, scan_state)
		return result
	var dependency_entries: PackedStringArray = ResourceLoader.get_dependencies(path)
	if (
		dependency_entries.is_empty()
		and _is_loadable_text_resource_file(path)
		and source.contains("[ext_resource")
	):
		_mark_resource_dependencies_unavailable(path, scan_state)
		return result
	for dependency_entry: String in dependency_entries:
		var dependency_resource_paths: PackedStringArray = _extract_dependency_resource_paths(dependency_entry)
		if dependency_resource_paths.is_empty() and not dependency_entry.strip_edges().is_empty():
			_mark_scan_partial(scan_state)
			_append_scan_issue(
				"resource_dependency_parse_failed",
				path,
				"",
				"无法解析 ResourceLoader 返回的依赖记录。",
				scan_state
			)
			continue
		for dependency_path: String in dependency_resource_paths:
			if not result.has(dependency_path):
				var _append_result: Variant = result.append(dependency_path)
		if follow_required:
			var actual_path: String = _select_dependency_scan_path(dependency_entry)
			if not actual_path.is_empty() and not follow_paths.has(actual_path):
				var _appended_follow: bool = follow_paths.append(actual_path)
	result.sort()
	if follow_required:
		follow_paths.sort()
		scan_state["follow_dependency_paths"] = follow_paths
	return result


## 将资源依赖不可用记录为 partial scan issue。
## [br]
## @api private
static func _mark_resource_dependencies_unavailable(path: String, scan_state: Dictionary) -> void:
	_mark_scan_partial(scan_state)
	_append_scan_issue(
		"resource_dependencies_unavailable",
		path,
		"",
		"无法解析 Godot 资源依赖。",
		scan_state
	)


## 将单行 GDScript 强证据追加到本文件共享数组，保留跨行去重后再检查额度的顺序。
## [br]
## @api private
static func _collect_gdscript_line_references(
	path: String,
	code_line: String,
	identifier_line: String,
	root_path: String,
	target_id: StringName,
	class_names: Array[String],
	remaining: int,
	result: Array[Dictionary],
	line_number: int
) -> void:
	if _line_references_root(code_line, root_path) and _line_has_gdscript_path_context(code_line, root_path):
		_append_reference_unique(
			result,
			_make_reference(
				path,
				line_number,
				root_path,
				target_id,
				"path",
				"",
				root_path,
				REFERENCE_STRENGTH_STRONG,
				REFERENCE_SOURCE_GDSCRIPT_LOAD,
				root_path
			),
			remaining
		)
		if result.size() >= remaining:
			return
	for class_name_value: String in class_names:
		if not _line_references_identifier(identifier_line, class_name_value):
			continue
		_append_reference_unique(
			result,
			_make_reference(
				path,
				line_number,
				root_path,
				target_id,
				"class_name",
				class_name_value,
				class_name_value,
				REFERENCE_STRENGTH_STRONG,
				REFERENCE_SOURCE_GDSCRIPT_SYMBOL,
				class_name_value
			),
			remaining
		)
		break


## 将资源文本单行中的路径语境交给原有识别规则，不加载资源对象。
## [br]
## @api private
static func _collect_resource_line_references(
	path: String,
	line: String,
	root_path: String,
	target_id: StringName,
	remaining: int,
	result: Array[Dictionary],
	line_number: int
) -> void:
	if not _line_references_root(line, root_path) or not _line_has_resource_path_context(line):
		return
	_append_reference_unique(
		result,
		_make_reference(
			path,
			line_number,
			root_path,
			target_id,
			"path",
			"",
			root_path,
			REFERENCE_STRENGTH_STRONG,
			REFERENCE_SOURCE_RESOURCE_TEXT,
			root_path
		),
		remaining
	)


## 单行弱证据按原顺序排除阻断键，每行只采用排序类名中的首个命中。
## [br]
## @api private
static func _collect_weak_line_references(
	path: String,
	line: String,
	root_path: String,
	target_id: StringName,
	class_names: Array[String],
	blocking_references: Array[Dictionary],
	result: Array[Dictionary],
	max_count: int,
	line_number: int
) -> void:
	if line.is_empty():
		return
	if _line_references_root(line, root_path):
		_append_weak_reference_unique(
			result,
			blocking_references,
			_make_reference(
				path,
				line_number,
				root_path,
				target_id,
				"path",
				"",
				root_path,
				REFERENCE_STRENGTH_WEAK,
				REFERENCE_SOURCE_TEXT_FALLBACK,
				root_path
			),
			max_count
		)
	for class_name_value: String in class_names:
		if not _line_references_identifier(line, class_name_value):
			continue
		_append_weak_reference_unique(
			result,
			blocking_references,
			_make_reference(
				path,
				line_number,
				root_path,
				target_id,
				"class_name",
				class_name_value,
				class_name_value,
				REFERENCE_STRENGTH_WEAK,
				REFERENCE_SOURCE_TEXT_FALLBACK,
				class_name_value
			),
			max_count
		)
		break


## 为定向读取选择实际依赖路径；可用 UID 优先，陈旧 fallback 不会被额外读取成假覆盖失败。
## [br]
## @api private
static func _select_dependency_scan_path(dependency_entry: String) -> String:
	var uid_path: String = ""
	var fallback_paths: Array[String] = []
	for part: String in dependency_entry.strip_edges().split("::", false):
		var candidate: String = _GF_PATH_TOOLS.normalize_resource_path(part)
		if candidate.begins_with("uid://"):
			var resource_id: int = ResourceUID.text_to_id(candidate)
			if resource_id != ResourceUID.INVALID_ID and ResourceUID.has_id(resource_id):
				var resolved: String = _GF_PATH_TOOLS.normalize_resource_path(ResourceUID.get_id_path(resource_id))
				if resolved.begins_with("res://") or resolved.begins_with("user://"):
					if FileAccess.file_exists(resolved):
						return resolved
					if uid_path.is_empty():
						uid_path = resolved
		elif candidate.begins_with("res://") or candidate.begins_with("user://"):
			fallback_paths.append(candidate)
	for path: String in fallback_paths:
		if FileAccess.file_exists(path):
			return path
	if not uid_path.is_empty():
		return uid_path
	return "" if fallback_paths.is_empty() else fallback_paths[0]


## 构造统一引用记录，并为 path 类型推导 target_path 与 blocking 标志。
## [br]
## @api private
static func _make_reference(
	path: String,
	line: int,
	root_path: String,
	target_id: StringName,
	kind: String,
	symbol: String,
	match_text: String,
	strength: StringName,
	source: StringName,
	evidence: String
) -> Dictionary:
	var target_path: String = ""
	if kind == "path":
		target_path = evidence if _is_resource_path_text(evidence) else root_path
	return {
		"path": path,
		"line": line,
		"target_id": String(target_id),
		"root_path": root_path,
		"kind": kind,
		"symbol": symbol,
		"match": match_text,
		"target_path": target_path,
		"strength": String(strength),
		"source": String(source),
		"evidence": evidence,
		"blocking": strength == REFERENCE_STRENGTH_VERIFIED or strength == REFERENCE_STRENGTH_STRONG,
		"preview": "%s reference: %s"
		% [kind, match_text],
	}


## 将数组中的 Dictionary 引用逐项交给唯一键追加逻辑。
## [br]
## @api private
static func _append_reference_array_unique(
	result: Array,
	values: Array,
	max_count: int
) -> void:
	for value: Variant in values:
		if value is Dictionary:
			var reference_record: Dictionary = value
			_append_reference_unique(
				result,
				reference_record,
				max_count
			)


## 按引用键去重；重复项保留等级较高者，新项受 max_count 限制。
## [br]
## @api private
static func _append_reference_unique(
	result: Array,
	candidate: Dictionary,
	max_count: int
) -> void:
	if candidate.is_empty():
		return

	var candidate_key: String = _make_reference_key(candidate)
	for index: int in range(result.size()):
		var existing_value: Variant = result[index]
		if not (existing_value is Dictionary):
			continue
		var existing_reference: Dictionary = existing_value
		if _make_reference_key(existing_reference) != candidate_key:
			continue
		if _get_reference_rank(candidate) > _get_reference_rank(existing_reference):
			result[index] = candidate
		return

	if max_count > 0 and result.size() >= max_count:
		return
	result.append(candidate)


## 若阻断引用中不存在相同键，则按普通唯一规则追加弱引用。
## [br]
## @api private
static func _append_weak_reference_unique(
	result: Array,
	blocking_references: Array,
	candidate: Dictionary,
	max_count: int
) -> void:
	if _reference_key_exists(
		blocking_references,
		_make_reference_key(candidate)
	):
		return
	_append_reference_unique(
		result,
		candidate,
		max_count
	)


## 检查引用数组中是否已存在给定唯一键。
## [br]
## @api private
static func _reference_key_exists(references: Array, reference_key: String) -> bool:
	for reference_value: Variant in references:
		if not (reference_value is Dictionary):
			continue
		var reference_record: Dictionary = reference_value
		if _make_reference_key(reference_record) == reference_key:
			return true
	return false


## 由源文件、目标根、引用种类和匹配文本组成去重键。
## [br]
## @api private
static func _make_reference_key(reference_record: Dictionary) -> String:
	return (
		"%s|%s|%s|%s"
		% [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "path"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "root_path"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "kind"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "match"),
		]
	)


## 将 verified、strong、weak 等级映射为 3、2、1，未知等级为零。
## [br]
## @api private
static func _get_reference_rank(reference_record: Dictionary) -> int:
	var strength: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "strength")
	if strength == String(REFERENCE_STRENGTH_VERIFIED):
		return 3
	if strength == String(REFERENCE_STRENGTH_STRONG):
		return 2
	if strength == String(REFERENCE_STRENGTH_WEAK):
		return 1
	return 0


## 拆分 ResourceLoader 的双冒号依赖字段，保留资源或用户 URI 并解析已登记 UID；无法解析的 UID 忽略，输出保持去重。
## [br]
## @api private
static func _extract_dependency_resource_paths(dependency_entry: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var normalized_entry: String = dependency_entry.strip_edges()
	if normalized_entry.is_empty():
		return result
	var parts: PackedStringArray = normalized_entry.split("::", false)
	for part: String in parts:
		var candidate: String = _GF_PATH_TOOLS.normalize_resource_path(part)
		if candidate.begins_with("res://") or candidate.begins_with("user://"):
			_append_unique_variant(result, candidate)
		elif candidate.begins_with("uid://"):
			var resource_id: int = ResourceUID.text_to_id(candidate)
			if resource_id == ResourceUID.INVALID_ID or not ResourceUID.has_id(resource_id):
				continue
			var resolved_path: String = _GF_PATH_TOOLS.normalize_resource_path(ResourceUID.get_id_path(resource_id))
			if resolved_path.begins_with("res://") or resolved_path.begins_with("user://"):
				_append_unique_variant(result, resolved_path)
	return result


## 遍历一行内符合根边界的路径命中，检查其前缀是否类似继承或加载表达式；只是加载语境启发式判断。
## [br]
## @api private
static func _line_has_gdscript_path_context(line: String, root_path: String) -> bool:
	var normalized_line: String = _normalize_source_line_path_separators(line)
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	var match_start: int = _find_root_reference_start(normalized_line, normalized_root)
	while match_start >= 0:
		var before_path: String = normalized_line.substr(0, match_start)
		if _context_before_path_is_gdscript_load(before_path):
			return true
		match_start = _find_root_reference_start_from(
			normalized_line,
			normalized_root,
			match_start + 1
		)
	return false


## 通过 extends 前缀或最近左括号前的加载函数后缀识别路径语境；不验证完整调用表达式或作用域。
## [br]
## @api private
static func _context_before_path_is_gdscript_load(before_path: String) -> bool:
	var stripped: String = before_path.strip_edges()
	if stripped.begins_with("extends"):
		return true

	var open_parenthesis_index: int = before_path.rfind("(")
	if open_parenthesis_index < 0:
		return false
	var callee_text: String = before_path.substr(0, open_parenthesis_index).strip_edges()
	return (
		callee_text.ends_with("preload")
		or callee_text.ends_with("load")
		or callee_text.ends_with("ResourceLoader.load")
		or callee_text.ends_with("ResourceLoader.load_interactive")
		or callee_text.ends_with("ResourceLoader.load_threaded_request")
		or callee_text.ends_with("ResourceLoader.load_threaded_get")
	)


## 按 ext_resource 段开头及 path/script 赋值片段识别资源路径语境；这是行级筛选，不能替代资源格式解析。
## [br]
## @api private
static func _line_has_resource_path_context(line: String) -> bool:
	var stripped: String = line.strip_edges()
	return (
		stripped.begins_with("[ext_resource")
		or stripped.contains("path=")
		or stripped.contains("path =")
		or stripped.contains("script=")
		or stripped.contains("script =")
	)


## 在单行内跳过带转义的单引号或双引号字符串，仅截去字符串外的井号后缀；不维护跨行字符串状态。
## [br]
## @api private
static func _strip_gdscript_line_comment(line: String) -> String:
	var in_string: bool = false
	var quote_character: String = ""
	var escaped: bool = false
	for index: int in range(line.length()):
		var character: String = line.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote_character:
				in_string = false
			continue

		if character == "\"" or character == "'":
			in_string = true
			quote_character = character
		elif character == "#":
			return line.substr(0, index)
	return line


## 将单行引号片段逐字符替为空格，保留非字符串字符位置供标识符匹配；不跨行追踪多行字符串。
## [br]
## @api private
static func _replace_quoted_segments(line: String) -> String:
	var result: String = ""
	var in_string: bool = false
	var quote_character: String = ""
	var escaped: bool = false
	for index: int in range(line.length()):
		var character: String = line.substr(index, 1)
		if in_string:
			result += " "
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote_character:
				in_string = false
			continue

		if character == "\"" or character == "'":
			in_string = true
			quote_character = character
			result += " "
		else:
			result += character
	return result


## 先规范化路径分隔符，再检查根路径及其文本变体的边界命中，避免把同名前缀目录直接视为目标根。
## [br]
## @api private
static func _line_references_root(line: String, root_path: String) -> bool:
	var normalized_line: String = _normalize_source_line_path_separators(line)
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if _line_references_root_variant(normalized_line, normalized_root):
		return true

	for root_variant: String in _root_reference_variants(root_path):
		if _line_references_root_variant(line, root_variant):
			return true
	return false


## 将扫描行中的反斜杠和重复资源 URI 分隔符规范化。
## [br]
## @api private
static func _normalize_source_line_path_separators(line: String) -> String:
	var normalized_line: String = line.replace("\\\\", "/").replace("\\", "/")
	normalized_line = normalized_line.replace("res:/", "res://").replace("user:/", "user://")
	while normalized_line.contains("res:///"):
		normalized_line = normalized_line.replace("res:///", "res://")
	while normalized_line.contains("user:///"):
		normalized_line = normalized_line.replace("user:///", "user://")
	return normalized_line


## 检查行中是否出现带有效尾部边界的目标根路径变体。
## [br]
## @api private
static func _line_references_root_variant(line: String, root_path: String) -> bool:
	if root_path.is_empty():
		return false
	var match_start: int = line.find(root_path)
	while match_start >= 0:
		var next_index: int = match_start + root_path.length()
		if next_index >= line.length():
			return true

		var next_character: String = line.substr(next_index, 1)
		if _is_reference_boundary(next_character):
			return true
		match_start = line.find(
			root_path,
			match_start + 1
		)
	return false


## 返回行内首个带有效尾部边界的目标根路径起始位置。
## [br]
## @api private
static func _find_root_reference_start(line: String, root_path: String) -> int:
	return _find_root_reference_start_from(
		line,
		root_path,
		0
	)


## 从指定偏移处查找目标根路径，并忽略尾部边界不成立的命中。
## [br]
## @api private
static func _find_root_reference_start_from(
	line: String,
	root_path: String,
	from_index: int
) -> int:
	if root_path.is_empty():
		return -1
	var match_start: int = line.find(root_path, from_index)
	while match_start >= 0:
		var next_index: int = match_start + root_path.length()
		if next_index >= line.length():
			return match_start

		var next_character: String = line.substr(next_index, 1)
		if _is_reference_boundary(next_character):
			return match_start
		match_start = line.find(
			root_path,
			match_start + 1
		)
	return -1


## 生成规范路径及其两种反斜杠写法。
## [br]
## @api private
static func _root_reference_variants(root_path: String) -> PackedStringArray:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	var variants: PackedStringArray = PackedStringArray()
	_append_unique_variant(variants, normalized_root)
	_append_unique_variant(
		variants,
		normalized_root.replace("/", "\\")
	)
	_append_unique_variant(
		variants,
		normalized_root.replace("/", "\\\\")
	)
	return variants


## 将非空且尚未存在的路径变体追加到数组。
## [br]
## @api private
static func _append_unique_variant(values: PackedStringArray, value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	var _append_value: bool = values.append(value)


## 检查标识符是否以 ASCII 标识符字符边界完整出现在行中。
## [br]
## @api private
static func _line_references_identifier(line: String, identifier: String) -> bool:
	if identifier.is_empty():
		return false

	var match_start: int = line.find(identifier)
	while match_start >= 0:
		var before_ok: bool = match_start == 0 or not _is_identifier_character(
			line.substr(
				match_start - 1,
				1
			)
		)
		var end: int = match_start + identifier.length()
		var after_ok: bool = end >= line.length() or not _is_identifier_character(line.substr(end, 1))
		if before_ok and after_ok:
			return true
		match_start = line.find(
			identifier,
			match_start + 1
		)
	return false


## 判断单个字符是否属于此扫描器接受的 ASCII 标识符字符。
## [br]
## @api private
static func _is_identifier_character(character: String) -> bool:
	if character.is_empty():
		return false
	var code: int = character.unicode_at(0)
	return (
		(
			code >= 65
			and code <= 90
		)
		or (
			code >= 97
			and code <= 122
		)
		or (
			code >= 48
			and code <= 57
		)
		or code == 95
	)


## 判断字符是否可作为引用路径命中的尾部边界。
## [br]
## @api private
static func _is_reference_boundary(character: String) -> bool:
	return [
		"/",
		"\\",
		"\"",
		"'",
		")",
		"]",
		"}",
		",",
		" ",
		"\t",
	].has(character)


## 按公开文本扩展名列表判断文件是否进入文本扫描。
## [br]
## @api private
static func _is_text_resource_file(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	return TEXT_FILE_EXTENSIONS.has(extension)


## 判断文件扩展名是否属于由 ResourceLoader 处理的二进制资源。
## [br]
## @api private
static func _is_binary_resource_file(path: String) -> bool:
	return _BINARY_RESOURCE_EXTENSIONS.has(path.get_extension().to_lower())


## 判断路径是否为扫描器支持的可加载文本或二进制资源。
## [br]
## @api private
static func _is_loadable_resource_file(path: String) -> bool:
	return [
		"res",
		"scn",
		"tres",
		"tscn",
	].has(path.get_extension().to_lower())


## 判断路径是否为可解析的 `.tres` 或 `.tscn` 文本资源。
## [br]
## @api private
static func _is_loadable_text_resource_file(path: String) -> bool:
	return ["tres", "tscn"].has(path.get_extension().to_lower())


## 检查 tscn/tres 的起始头及已识别段行是否闭合；允许 BOM 和外围空白，此预检不保证完整资源可解析。
## [br]
## @api private
static func _resource_text_has_valid_header(path: String, source: String) -> bool:
	var normalized_source: String = source.trim_prefix("\uFEFF").strip_edges()
	match path.get_extension().to_lower():
		"tscn":
			if not normalized_source.begins_with("[gd_scene"):
				return false
		"tres":
			if not normalized_source.begins_with("[gd_resource"):
				return false
	for raw_line: String in normalized_source.split("\n"):
		var line: String = raw_line.strip_edges()
		if _is_resource_section_prefix(line) and not line.ends_with("]"):
			return false
	return true


## 判断去除首尾空白后的行是否以已识别的资源段标记开头。
## [br]
## @api private
static func _is_resource_section_prefix(line: String) -> bool:
	return (
		line.begins_with("[gd_scene")
		or line.begins_with("[gd_resource")
		or line.begins_with("[ext_resource")
		or line.begins_with("[sub_resource")
		or line.begins_with("[resource")
		or line.begins_with("[node")
		or line.begins_with("[connection")
		or line.begins_with("[editable")
	)


## 判断扩展名是否属于包含资源路径字段的文本配置类型。
## [br]
## @api private
static func _is_resource_text_extension(extension: String) -> bool:
	return [
		"tscn",
		"tres",
		"godot",
		"import",
	].has(extension)


## 判断值是否以 Godot 资源、用户或 UID 路径前缀开头。
## [br]
## @api private
static func _is_resource_path_text(value: String) -> bool:
	return (
		value.begins_with("res://")
		or value.begins_with("user://")
		or value.begins_with("uid://")
	)


## 委托路径工具判断路径是否落在忽略根目录内。
## [br]
## @api private
static func _is_path_ignored(path: String, ignored_roots: PackedStringArray) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, ignored_roots)


## 判断当前目录是否可继续递归，并在达到正数深度上限时记录截断。
## [br]
## @api private
static func _can_scan_deeper(
	path: String,
	current_depth: int,
	max_scan_depth: int,
	scan_state: Dictionary
) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_scan_depth_limit(
		path,
		max_scan_depth,
		scan_state
	)
	return false


## 创建扫描计数、截断标志、诊断数组及警告选项的初始状态。
## [br]
## @api private
static func _make_scan_state(options: Dictionary) -> Dictionary:
	return {
		"input_target_count": 0,
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"partial_scan": false,
		"budget_exceeded": false,
		"truncated": false,
		"stop_scan": false,
		"file_collection_stopped": false,
		"target_preflight_failed": false,
		"skipped_files": [],
		"scan_warnings": [],
		"issues": [],
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
		"budget_warning_emitted": false,
		"warning_prefix": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			options,
			"warning_prefix",
			"[GFProjectReferenceScanner]"
		),
	}


## 将扫描状态、目标结果和引用数组汇总为公开报告字典。
## [br]
## @api private
static func _make_scan_report(
	scan_targets: Array[Dictionary],
	references: Array[Dictionary],
	weak_references: Array[Dictionary],
	target_reports: Dictionary,
	weak_target_reports: Dictionary,
	scan_state: Dictionary
) -> Dictionary:
	var partial_scan: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "partial_scan")
	return {
		"ok": references.is_empty() and not partial_scan,
		"partial_scan": partial_scan,
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "budget_exceeded"),
		"truncated": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "truncated"),
		"input_target_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			scan_state,
			"input_target_count",
			scan_targets.size()
		),
		"target_count": target_reports.size(),
		"reference_count": references.size(),
		"weak_reference_count": weak_references.size(),
		"targets": target_reports,
		"weak_targets": weak_target_reports,
		"references": references,
		"weak_references": weak_references,
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "candidate_file_count"),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_bytes"),
		"skipped_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "skipped_files"),
		"scan_warnings": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "scan_warnings"),
		"issue_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "issues").size(),
		"issues": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "issues"),
	}


## 标记扫描结果不完整。
## [br]
## @api private
static func _mark_scan_partial(scan_state: Dictionary) -> void:
	scan_state["partial_scan"] = true


## 标记目标引用配额导致的截断，并为该目标追加诊断。
## [br]
## @api private
static func _mark_target_quota_truncated(
	target_id: String,
	reason: String,
	scan_state: Dictionary
) -> void:
	_mark_scan_partial(scan_state)
	scan_state["truncated"] = true
	_append_scan_issue(
		reason,
		"",
		target_id,
		"扫描目标引用数量超过配额，结果已截断。",
		scan_state
	)


## 记录读取预算耗尽、跳过文件及单次预算警告。
## [br]
## @api private
static func _mark_budget_exceeded(
	path: String,
	reason: String,
	size_bytes: int,
	limit_bytes: int,
	scan_state: Dictionary
) -> void:
	scan_state["budget_exceeded"] = true
	scan_state["truncated"] = true
	_mark_scan_partial(scan_state)
	_append_skipped_file(
		path,
		reason,
		size_bytes,
		reason,
		limit_bytes,
		scan_state
	)
	_append_scan_issue(
		reason,
		path,
		"",
		"候选扫描文件超过读取字节预算。",
		scan_state
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "budget_warning_emitted"):
		return
	scan_state["budget_warning_emitted"] = true
	_emit_scan_warning(
		"[project_reference_scanner.byte_budget_reached] Reference scanning reached the %s=%d byte budget; subsequent results are treated as partial_scan: %s."
		% [
			reason,
			limit_bytes,
			path,
		],
		scan_state
	)


## 将因读取限制而跳过的文件及对应限制值加入扫描状态。
## [br]
## @api private
static func _append_skipped_file(
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
		}
	)
	scan_state["skipped_files"] = skipped_files


## 按 code、path 与 target_id 去重后追加扫描诊断。
## [br]
## @api private
static func _append_scan_issue(
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
		}
	)
	scan_state["issues"] = issues


## 首次达到正数文件数上限时停止收集并记录截断诊断。
## [br]
## @api private
static func _warn_scanned_file_limit(max_scanned_files: int, scan_state: Dictionary) -> void:
	if max_scanned_files <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	scan_state["file_collection_stopped"] = true
	scan_state["truncated"] = true
	_mark_scan_partial(scan_state)
	_append_scan_issue(
		"max_scanned_files",
		"",
		"",
		"候选扫描文件数量超过配额。",
		scan_state
	)
	_emit_scan_warning(
		"[project_reference_scanner.file_limit_reached] max_scanned_files=%d was reached; subsequent files were skipped." % max_scanned_files,
		scan_state
	)


## 首次达到正数目录深度上限时记录截断诊断。
## [br]
## @api private
static func _warn_scan_depth_limit(
	path: String,
	max_scan_depth: int,
	scan_state: Dictionary
) -> void:
	if max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	scan_state["truncated"] = true
	_mark_scan_partial(scan_state)
	_append_scan_issue(
		"max_scan_depth",
		path,
		"",
		"扫描目录深度超过配额。",
		scan_state
	)
	_emit_scan_warning(
		"[project_reference_scanner.depth_limit_reached] max_scan_depth=%d was reached; deeper directories were skipped: %s."
		% [max_scan_depth, path],
		scan_state
	)


## 添加警告前缀、保存警告文本并发送 Godot warning。
## [br]
## @api private
static func _emit_scan_warning(message: String, scan_state: Dictionary) -> void:
	var warning_prefix: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		scan_state,
		"warning_prefix",
		"[GFProjectReferenceScanner]"
	)
	var warning_message: String = (
		"%s%s"
		% [warning_prefix, message]
	)
	var scan_warnings: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "scan_warnings")
	scan_warnings.append(warning_message)
	scan_state["scan_warnings"] = scan_warnings
	push_warning(warning_message)


## 将附加忽略根选项转换并规范化为打包字符串数组。
## [br]
## @api private
static func _read_additional_ignored_roots(options: Dictionary) -> PackedStringArray:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		options,
		"additional_ignored_roots",
		PackedStringArray()
	)
	if value is PackedStringArray:
		var packed_roots: PackedStringArray = value
		return _GF_PATH_TOOLS.normalize_root_paths(packed_roots)
	return _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(value)))


## 优先读取主键；主键不存在时读取兼容别名及默认值。
## [br]
## @api private
static func _get_option_int_with_alias(
	options: Dictionary,
	key: String,
	alias: String,
	default_value: int
) -> int:
	if _has_option_key(options, key):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			options,
			key,
			default_value
		)
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		alias,
		default_value
	)


## 同时检查 String 和 StringName 形式的选项键。
## [br]
## @api private
static func _has_option_key(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))
