# 只读代码检查的独立 MainLoop 入口；宿主不会进入 SceneTree 的项目 AutoLoad 启动分支。
# 退出时只创建无项目初始化的临时 SceneTree，设置引擎退出码后立即释放。
extends MainLoop


# --- 常量 ---

## 文本与项目检查唯一实现；预加载工具自身，不加载目标脚本。
## [br]
## @api private
const _ANALYZER_SCRIPT = preload("res://addons/gf/tools/code_quality/gf_code_quality_analyzer.gd")

## 机器输出使用单行标识，允许调用方区分 Godot 自身的启动或诊断输出。
## [br]
## @api private
const _REPORT_PREFIX: String = "GF_CODE_QUALITY_REPORT="

## 命令只检查、列出规则或显示帮助，不提供写入或修复入口。
## [br]
## @api private
const _USAGE: String = """GF GDScript code quality

godot --headless --path <project> --script res://addons/gf/tools/code_quality/cli/gf_code_quality_cli.gd -- [options]

  --root <absolute-path>  Project to inspect; defaults to the host project.
  --json                  Emit one GF_CODE_QUALITY_REPORT=<JSON> line.
  --list-rules            List configurable rule IDs without reading project source.
  --help                  Show this help.

The project must explicitly adopt .gf/code_quality.json. This command never creates
configuration, modifies source, or executes inspected scripts.
Exit codes: 0 = complete without blocking errors; 1 = complete with rule errors;
2 = unconfigured, incomplete, or invalid arguments."""


# --- 私有变量 ---

## MainLoop 完成后提交给引擎的退出码；默认失败，执行成功才覆盖。
## [br]
## @api private
var _exit_code: int = 2


# --- Godot 回调方法 ---

## 命令执行只发生一次，随后由 _process 通知引擎结束主循环。
## [br]
## @api private
func _initialize() -> void:
	var parsed: Dictionary = _parse_arguments(OS.get_cmdline_user_args())
	var machine_output: bool = parsed["json"]
	var parse_error: String = parsed["error"]
	if not parse_error.is_empty():
		_emit(
			_argument_failure(parse_error),
			machine_output
		)
		return
	if parsed["help"]:
		if machine_output:
			_emit(
				{ "schema_version": 1, "usage": _USAGE },
				true
			)
		else:
			print(_USAGE)
		_exit_code = 0
		return
	if parsed["list_rules"]:
		var rule_ids: PackedStringArray = _ANALYZER_SCRIPT.get_rule_ids()
		if machine_output:
			_emit(
				{ "schema_version": 1, "rules": rule_ids },
				true
			)
		else:
			print("\n".join(rule_ids))
		_exit_code = 0
		return
	var analyzer: _ANALYZER_SCRIPT = _ANALYZER_SCRIPT.new()
	var project_root: String = parsed["root"]
	var report: Dictionary = analyzer.analyze_project(project_root)
	_emit(report, machine_output)
	if report["complete"]:
		_exit_code = 0 if report["ok"] else 1


## 分析已在初始化阶段完成；返回 true 结束自有 MainLoop。
## [br]
## @api private
func _process(_delta: float) -> bool:
	return true


## SceneTree.quit 只负责设置引擎退出码；临时树不启动、不开场景、不装配 AutoLoad。
## [br]
## @api private
func _finalize() -> void:
	var exit_tree: SceneTree = SceneTree.new()
	exit_tree.quit(_exit_code)
	exit_tree.free()


# --- 私有/辅助方法 ---

## 参数语法闭合且不解释 shell 字符串；保留 --json 以使参数错误也有机器结果。
## [br]
## @api private
func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {
		"root": ProjectSettings.globalize_path("res://"),
		"json": arguments.has("--json"),
		"help": false,
		"list_rules": false,
		"error": "",
	}
	var root_seen: bool = false
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		match argument:
			"--json":
				pass
			"--help":
				result["help"] = true
			"--list-rules":
				result["list_rules"] = true
			"--root":
				if root_seen or index + 1 >= arguments.size():
					result["error"] = "--root requires one absolute project path and cannot be repeated."
					return result
				root_seen = true
				index += 1
				var root: String = arguments[index]
				if (
					not root.is_absolute_path()
					or root.begins_with("res://")
					or root.begins_with("user://")
				):
					result["error"] = "--root must be an absolute local project path."
					return result
				result["root"] = root
			_:
				result["error"] = "Unknown argument; use --help to list supported options."
				return result
		index += 1
	if result["help"] and result["list_rules"]:
		result["error"] = "--help and --list-rules cannot be combined."
	return result


## 机器结果固定为一行 JSON；普通模式输出摘要和完整诊断位置。
## [br]
## @api private
func _emit(report: Dictionary, machine_output: bool) -> void:
	if machine_output:
		print(_REPORT_PREFIX + JSON.stringify(report))
		return
	print(
		"GF code quality: %s; checked=%d; failed=%d"
		% [
			report["status"],
			report["files_checked"],
			report["files_failed"],
		]
	)
	for issue: Dictionary in report["diagnostics"]:
		print(
			"%s:%d:%d: %s %s: %s"
			% [
				issue["path"],
				issue["line"],
				issue["column"],
				issue["severity"],
				issue["rule"],
				issue["message"],
			]
		)
		var suggestion: String = issue["suggestion"]
		if not suggestion.is_empty():
			print("  " + suggestion)


## 参数错误沿用检查报告的机器结构，并保持未完成状态。
## [br]
## @api private
func _argument_failure(message: String) -> Dictionary:
	return {
		"schema_version": 1,
		"status": "incomplete",
		"complete": false,
		"ok": false,
		"diagnostics": [
			{
				"path": "",
				"line": 1,
				"column": 1,
				"rule": "cli_arguments",
				"severity": "error",
				"message": message,
				"suggestion": "Use --help to list supported options.",
			},
		],
		"files_checked": 0,
		"files_failed": 0,
		"source_hashes": {},
		"coverage": { "source": "none" },
	}
