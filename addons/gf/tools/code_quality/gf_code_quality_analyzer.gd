## 项目代码规范的只读检查入口，供编辑器、制作工具与 CI 使用。
## [br]
## 输入只作为文本分析；检查不会执行目标脚本、写入源码或自动启用项目规范。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFCodeQualityAnalyzer
extends RefCounted


# --- 常量 ---

## 共享配置准入与规则注册。
## [br]
## @api private
const _CONFIG_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_config.gd")

## 保留源码位置与字符串边界的结构模型。
## [br]
## @api private
const _SOURCE_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_source.gd")

## 通用结构排版检查。
## [br]
## @api private
const _LAYOUT_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_layout.gd")

## 成员职责、文档绑定与标签一致性检查。
## [br]
## @api private
const _DOCS_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_docs.gd")

## 有限只读文件捕获。
## [br]
## @api private
const _FILES_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_files.gd")

## 配置复用框架有界 JSON 读取。
## [br]
## @api private
const _JSON_SCRIPT = preload("res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd")

## 单文件预算约束源码解析占用。
## [br]
## @api private
const _MAX_FILE_BYTES: int = 4 * 1024 * 1024

## 单项目源码读取预算；结束时的身份复核最多再读取同等字节。
## [br]
## @api private
const _MAX_TOTAL_BYTES: int = 64 * 1024 * 1024

## 目录枚举与文件数共同受此上限约束。
## [br]
## @api private
const _MAX_ENTRIES: int = 40_000

## 报告达到此数量后明确标记未完成，不静默截断后宣称通过。
## [br]
## @api private
const _MAX_DIAGNOSTICS: int = 10_000


# --- 公共方法 ---

## 返回可配置的规范规则，读取失败和语法分析失败不能通过规则配置关闭。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 按 ID 排序的规范规则集合。
static func get_rule_ids() -> PackedStringArray:
	return _CONFIG_SCRIPT.get_rule_ids()


## 只读加载项目选择的规范；不存在配置时返回 unconfigured。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root: 本地绝对项目目录，或当前项目的 res:// 目录。
## [br]
## @return 配置准入结果，不会创建默认配置。
## [br]
## @schema return: Dictionary，ok: bool、status: configured/unconfigured/incomplete、config: Dictionary、error: String；成功 config 为 schema_version、preset、include、exclude、rules、layout 的规范值。
static func load_project_config(root: String) -> Dictionary:
	var absolute: String = _FILES_SCRIPT.resolve_root(root)
	if absolute.is_empty():
		return _config_failure("incomplete", "项目目录不可读取或穿过链接。")
	var path: String = absolute.path_join(".gf/code_quality.json")
	if not FileAccess.file_exists(path):
		return _config_failure("unconfigured", "尚未配置 .gf/code_quality.json。")
	var capture: Dictionary = _FILES_SCRIPT.read_text(path, 65_536)
	if not capture["ok"]:
		var read_error: String = capture["error"]
		return _config_failure("incomplete", read_error)
	var config_text: String = capture["text"]
	var parsed: Dictionary = _JSON_SCRIPT.parse_object(config_text)
	if not parsed["ok"]:
		return _config_failure("incomplete", "代码规范配置必须是有效的 JSON 对象。")
	var config_data: Dictionary = parsed["data"]
	return _CONFIG_SCRIPT.normalize(config_data)


## 按显式项目配置分析一份源码快照；路径仅用于定位，不触发文件读取。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param path: 诊断展示的源码路径。
## [br]
## @param source: 调用方捕获的完整 GDScript 文本。
## [br]
## @param config: 项目选择的规范配置，空配置返回 unconfigured。
## [br]
## @schema config: Dictionary，schema_version: 1，可选 preset: "gf-game@1"、rules: Dictionary[String, off/warning/error]、include/exclude: Array[String]、layout: Dictionary[String, int]。
## [br]
## @return 只读检查结果；警告不阻断 ok，未完成检查始终不通过。
## [br]
## @schema return: Dictionary，schema_version: 1、status: clean/violations/incomplete/unconfigured、complete/ok: bool、diagnostics: Array[Dictionary]、files_checked/files_failed: int、source_hashes: Dictionary[String, String]、coverage: Dictionary；诊断含 path、line/column（从 1 开始的字符坐标）、rule、severity、message、suggestion。
func analyze_source(
	path: String,
	source: String,
	config: Dictionary
) -> Dictionary:
	var admitted: Dictionary = _CONFIG_SCRIPT.normalize(config)
	if not admitted["ok"]:
		return _configuration_report(admitted)
	var report: Dictionary = _new_report("buffer")
	var options: Dictionary = admitted["config"]
	_analyze_text(
		path,
		source,
		options,
		report
	)
	_finish(report)
	return report


## 检查配置范围内的独立 .gd 文件，结束前复核来源，支持文件间取消。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root: 被检查的本地项目目录；不会加载其 project.godot 或执行其脚本。
## [br]
## @param config: 显式配置；为空时只读加载项目的 .gf/code_quality.json。
## [br]
## @param cancel_probe: 可选无参回调，返回 true 时停止扫描；回调由调用者提供并须适合当前线程。
## [br]
## @schema config: Dictionary，与 analyze_source 的 config 相同；空字典仅表示从项目加载配置。
## [br]
## @return 项目源码检查报告；失败、取消和读取期变化都返回 incomplete。
## [br]
## @schema return: Dictionary，与 analyze_source 报告相同；coverage.source 为 disk，include/exclude 记录实际配置范围；source_hashes 保存已检查文件的文本 SHA-256。
func analyze_project(
	root: String,
	config: Dictionary = {},
	cancel_probe: Callable = Callable()
) -> Dictionary:
	var absolute: String = _FILES_SCRIPT.resolve_root(root)
	if absolute.is_empty():
		return _configuration_report(_config_failure("incomplete", "项目目录不可读取或穿过链接。"))
	var admitted: Dictionary = load_project_config(absolute) if config.is_empty() else _CONFIG_SCRIPT.normalize(config)
	if not admitted["ok"]:
		return _configuration_report(admitted)
	var options: Dictionary = admitted["config"]
	var report: Dictionary = _new_report("disk")
	report["coverage"]["include"] = options["include"]
	report["coverage"]["exclude"] = options["exclude"]
	var paths: PackedStringArray = _collect_paths(
		absolute,
		options,
		cancel_probe,
		report
	)
	var total_bytes: int = 0
	var source_sizes: Dictionary = {}
	for path: String in paths:
		if _cancelled(cancel_probe, report) or _diagnostic_limit(report):
			break
		var remaining_bytes: int = _MAX_TOTAL_BYTES - total_bytes
		var capture: Dictionary = _FILES_SCRIPT.read_text(
			absolute.path_join(path.substr(6)),
			mini(_MAX_FILE_BYTES, remaining_bytes)
		)
		var consumed_bytes: int = capture["consumed_bytes"]
		total_bytes += consumed_bytes
		if not capture["ok"]:
			var rejected_size: int = capture["size_bytes"]
			if rejected_size > _MAX_FILE_BYTES:
				_record_failure(
					report,
					path,
					"analysis_budget",
					"单文件超过 4 MiB 字节预算。",
					true
				)
				continue
			if rejected_size > remaining_bytes:
				_record_failure(
					report,
					path,
					"analysis_budget",
					"项目源码超过 64 MiB 字节预算。"
				)
				break
			var read_error: String = capture["error"]
			_record_failure(
				report,
				path,
				"source_read",
				read_error,
				true
			)
			continue
		var size_bytes: int = capture["size_bytes"]
		source_sizes[path] = size_bytes
		var source: String = capture["text"]
		_analyze_text(
			path,
			source,
			options,
			report
		)
	_verify_sources(
		absolute,
		source_sizes,
		cancel_probe,
		report
	)
	if report["complete"]:
		var current_paths: PackedStringArray = _collect_paths(
			absolute,
			options,
			cancel_probe,
			report
		)
		if current_paths != paths:
			_record_failure(
				report,
				"",
				"source_changed",
				"源码文件清单在检查期间发生变化，请重新检查。"
			)
	if config.is_empty() and report["complete"]:
		var current_config: Dictionary = load_project_config(absolute)
		if not current_config["ok"] or current_config["config"] != options:
			_record_failure(
				report,
				".gf/code_quality.json",
				"source_changed",
				"项目规范配置在检查期间发生变化，请重新检查。"
			)
	_finish(report)
	return report


# --- 私有/辅助方法 ---

## 将同一语法模型交给两类规则，并应用统一严重级别。
## [br]
## @api private
func _analyze_text(
	path: String,
	source: String,
	options: Dictionary,
	report: Dictionary
) -> void:
	if source.to_utf8_buffer().size() > _MAX_FILE_BYTES:
		_record_failure(
			report,
			path,
			"analysis_budget",
			"源码超过 4 MiB 单文件预算。",
			true
		)
		return
	var view: Dictionary = _SOURCE_SCRIPT.lex_source(path, source)
	var findings: Array[Dictionary] = []
	var source_diagnostics: Array = view["diagnostics"]
	findings.assign(source_diagnostics)
	var complete: bool = view["complete"]
	var levels: Dictionary = options["rules"]
	if complete:
		if _has_enabled_rules(
			_LAYOUT_SCRIPT.get_rule_ids(),
			levels
		):
			var layout_options: Dictionary = options["layout"]
			layout_options = layout_options.duplicate()
			layout_options["rule_levels"] = levels
			findings.append_array(_LAYOUT_SCRIPT.analyze(view, layout_options))
		if _has_enabled_rules(
			_DOCS_SCRIPT.get_rule_ids(),
			levels
		):
			findings.append_array(
				_DOCS_SCRIPT.analyze(
					view,
					{ "rule_levels": levels }
				)
			)
	else:
		report["complete"] = false
		report["files_failed"] += 1
	var diagnostics: Array = report["diagnostics"]
	for finding: Dictionary in findings:
		var rule_id: String = finding["rule"]
		if rule_id == "analysis_budget":
			if complete:
				report["complete"] = false
				report["files_failed"] += 1
				complete = false
		var level: String = levels.get(rule_id, "error")
		if level == "off":
			continue
		var issue: Dictionary = finding.duplicate(true)
		issue["path"] = path
		issue["severity"] = level
		issue["suggestion"] = finding.get("suggestion", "")
		diagnostics.append(issue)
		if _diagnostic_limit(report):
			if complete:
				report["files_failed"] += 1
			break
	report["files_checked"] += 1
	report["source_hashes"][path] = source.sha256_text()


## 完全关闭的规则族不运行，避免无关诊断消耗分析预算。
## [br]
## @api private
func _has_enabled_rules(rule_ids: PackedStringArray, levels: Dictionary) -> bool:
	for rule_id: String in rule_ids:
		if levels.get(rule_id, "off") != "off":
			return true
	return false


## 稳定枚举配置范围，不进入引擎缓存、版本库或显式排除路径。
## [br]
## @api private
func _collect_paths(
	root: String,
	options: Dictionary,
	cancel_probe: Callable,
	report: Dictionary
) -> PackedStringArray:
	var selected: Dictionary = {}
	var visited: Dictionary = {}
	var scope_directory: DirAccess = DirAccess.open(root)
	if scope_directory == null:
		_record_failure(
			report,
			"res://",
			"source_read",
			"项目根目录不可访问。"
		)
		return PackedStringArray()
	var case_cache: Dictionary = {}
	var excluded_identities: PackedStringArray = PackedStringArray()
	var excluded_paths: Array = ["res://.godot", "res://.git"]
	var configured_exclusions: Array = options["exclude"]
	excluded_paths.append_array(configured_exclusions)
	for path: String in excluded_paths:
		var _appended: bool = excluded_identities.append(
			_scope_identity(
				path,
				scope_directory,
				case_cache
			)
		)
	var pending: Array[String] = []
	for path: String in options["include"]:
		pending.append(path)
	var entries: int = 0
	while not pending.is_empty():
		if _cancelled(cancel_probe, report) or _diagnostic_limit(report):
			break
		var logical: String = pending.pop_back()
		var identity: String = _scope_identity(
			logical,
			scope_directory,
			case_cache
		)
		if visited.has(identity) or _excluded(identity, excluded_identities):
			continue
		visited[identity] = true
		entries += 1
		if entries > _MAX_ENTRIES:
			_record_failure(
				report,
				logical,
				"analysis_budget",
				"项目目录枚举超过 40000 项预算。"
			)
			break
		var absolute: String = root.path_join(logical.substr(6))
		if _FILES_SCRIPT.crosses_link(absolute):
			_record_failure(
				report,
				logical,
				"source_path",
				"所选路径不可读取或穿过链接。"
			)
			continue
		if FileAccess.file_exists(absolute):
			if logical.ends_with(".gd"):
				selected[logical] = true
			continue
		var directory: DirAccess = DirAccess.open(absolute)
		if directory != null:
			directory.include_hidden = true
		if directory == null or directory.list_dir_begin() != OK:
			_record_failure(
				report,
				logical,
				"source_read",
				"所选目录不存在或不可枚举。"
			)
			continue
		var name: String = directory.get_next()
		while not name.is_empty():
			if name != "." and name != "..":
				pending.append(logical.path_join(name))
				if pending.size() + entries > _MAX_ENTRIES:
					_record_failure(
						report,
						logical,
						"analysis_budget",
						"项目目录枚举超过 40000 项预算。"
					)
					pending.clear()
					break
			name = directory.get_next()
		directory.list_dir_end()
	var paths: PackedStringArray = PackedStringArray(selected.keys())
	paths.sort()
	return paths


## 全量结果发布前复核已消费文本，防止并发编辑被描述为同一源码状态。
## [br]
## @api private
func _verify_sources(
	root: String,
	source_sizes: Dictionary,
	cancel_probe: Callable,
	report: Dictionary
) -> void:
	if not report["complete"]:
		return
	var hashes: Dictionary = report["source_hashes"]
	for path: String in hashes:
		if _cancelled(cancel_probe, report):
			return
		var size_bytes: int = source_sizes[path]
		var capture: Dictionary = _FILES_SCRIPT.read_text(
			root.path_join(path.substr(6)),
			size_bytes
		)
		var text: String = capture["text"]
		if not capture["ok"] or text.sha256_text() != hashes[path]:
			_record_failure(
				report,
				path,
				"source_changed",
				"源码在检查期间发生变化，请重新检查。",
				true
			)
			return


## 排除以目录边界匹配，避免 scripts/vendor 误匹配 scripts/vendor_game。
## [br]
## @api private
func _excluded(identity: String, excluded: PackedStringArray) -> bool:
	for excluded_identity: String in excluded:
		if (
			excluded_identity == "res://"
			or identity == excluded_identity
			or identity.begins_with(excluded_identity + "/")
		):
			return true
	return false


## 每段名称遵循其父目录的大小写规则，范围排除与去重采用同一身份。
## [br]
## @api private
func _scope_identity(
	path: String,
	directory: DirAccess,
	case_cache: Dictionary
) -> String:
	var identity: String = "res://"
	var absolute: String = directory.get_current_dir()
	for component: String in path.substr(6).split("/", false):
		if not case_cache.has(identity):
			case_cache[identity] = directory.is_case_sensitive(absolute)
		var case_sensitive: bool = case_cache[identity]
		identity = identity.path_join(component if case_sensitive else component.to_lower())
		absolute = absolute.path_join(component)
	return identity


## 取消属于未完成状态，不生成通过报告。
## [br]
## @api private
func _cancelled(probe: Callable, report: Dictionary) -> bool:
	if probe.is_valid() and probe.call() == true:
		_record_failure(
			report,
			"",
			"analysis_cancelled",
			"检查已取消。"
		)
		return true
	return false


## 诊断预算与扫描成功状态分开，达到预算后停止产出普通诊断。
## [br]
## @api private
func _diagnostic_limit(report: Dictionary) -> bool:
	var diagnostics: Array = report["diagnostics"]
	if diagnostics.size() < _MAX_DIAGNOSTICS:
		return false
	if diagnostics.size() == _MAX_DIAGNOSTICS:
		var last: Dictionary = diagnostics.back()
		if last["rule"] == "analysis_budget":
			return true
		var _resize_error: int = diagnostics.resize(_MAX_DIAGNOSTICS - 1)
		_record_failure(
			report,
			"",
			"analysis_budget",
			"诊断数量达到 10000 项上限，检查未完成。"
		)
	return true


## 汇总时稳定排序，并将警告与阻断错误分开。
## [br]
## @api private
func _finish(report: Dictionary) -> void:
	var diagnostics: Array = report["diagnostics"]
	diagnostics.sort_custom(_diagnostic_precedes)
	var errors: int = 0
	for issue: Dictionary in diagnostics:
		if issue["severity"] == "error":
			errors += 1
	report["ok"] = report["complete"] and errors == 0
	if not report["complete"]:
		report["status"] = "incomplete"
	else:
		report["status"] = "clean" if diagnostics.is_empty() else "violations"


## 诊断顺序只由位置与稳定规则 ID 决定。
## [br]
## @api private
func _diagnostic_precedes(left: Dictionary, right: Dictionary) -> bool:
	for field: String in [
		"path",
		"line",
		"column",
		"rule",
	]:
		if left[field] != right[field]:
			return left[field] < right[field]
	return false


## 所有来源错误使用不可关闭的错误级别，保留已得到的诊断。
## [br]
## @api private
func _record_failure(
	report: Dictionary,
	path: String,
	rule: String,
	message: String,
	count_file_failure: bool = false
) -> void:
	report["complete"] = false
	if count_file_failure:
		report["files_failed"] += 1
	var diagnostics: Array = report["diagnostics"]
	if diagnostics.size() >= _MAX_DIAGNOSTICS:
		return
	diagnostics.append(
		{
			"path": path,
			"line": 1,
			"column": 1,
			"rule": rule,
			"severity": "error",
			"message": message,
			"suggestion": "",
		}
	)


## 创建独立报告容器，调用之间不保留项目或源码引用。
## [br]
## @api private
func _new_report(source_kind: String) -> Dictionary:
	return {
		"schema_version": 1,
		"status": "clean",
		"complete": true,
		"ok": true,
		"diagnostics": [],
		"files_checked": 0,
		"files_failed": 0,
		"source_hashes": {},
		"coverage": { "source": source_kind },
	}


## 配置失败复用统一报告形状，同时保留未配置与无效配置的区别。
## [br]
## @api private
func _configuration_report(admitted: Dictionary) -> Dictionary:
	var report: Dictionary = _new_report("none")
	var message: String = admitted["error"]
	_record_failure(
		report,
		".gf/code_quality.json",
		"configuration",
		message
	)
	report["ok"] = false
	report["status"] = admitted["status"]
	return report


## 配置读取失败不返回可执行的部分配置。
## [br]
## @api private
static func _config_failure(status: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"status": status,
		"config": {},
		"error": message,
	}
