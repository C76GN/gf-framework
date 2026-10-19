@tool

## GFCodeQualityScanWorker: 只读代码检查的单次后台请求。
##
## 请求只传项目路径、冻结配置和可选编辑缓冲文本；不访问编辑器对象或加载项目资源。
## 取消标志由互斥锁保护，项目扫描在分析器规定的检查点停止。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFCodeQualityScanWorker
extends RefCounted


# --- 常量 ---

## 编辑器和命令行共用的文本与项目分析入口。
## [br]
## @api private
const _ANALYZER_SCRIPT = preload("res://addons/gf/tools/code_quality/gf_code_quality_analyzer.gd")

## 收窄请求字典的受控字段。
## [br]
## @api private
const _ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

## 主线程与分析线程访问取消状态时共用的锁。
## [br]
## @api private
var _cancel_mutex: Mutex = Mutex.new()

## 本实例只归属一次请求，取消后不会再次启动。
## [br]
## @api private
var _cancelled: bool = false


# --- 框架内部方法 ---

## 使用冻结输入运行一次检查；文件枚举只在项目请求中发生。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param request: 主线程准备的单次请求。
## [br]
## @return 原生分析器报告；取消中的单文件请求返回空字典，由拥有者丢弃。
## [br]
## @schema request: Dictionary，包含 mode: String、root: String、config: Dictionary；mode 为 buffer 时另含 path: String 和 source: String。
## [br]
## @schema return: Dictionary，非空结果沿用 GFCodeQualityAnalyzer 的报告契约。
func run_request(request: Dictionary) -> Dictionary:
	if _is_cancelled():
		return {}
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var config: Dictionary = _ACCESS_SCRIPT.get_option_dictionary(
		request,
		"config",
		{}
	)
	if _ACCESS_SCRIPT.get_option_string(
		request,
		"mode",
		""
	) == "buffer":
		return analyzer.analyze_source(
			_ACCESS_SCRIPT.get_option_string(
				request,
				"path",
				""
			),
			_ACCESS_SCRIPT.get_option_string(
				request,
				"source",
				""
			),
			config
		)
	return analyzer.analyze_project(
		_ACCESS_SCRIPT.get_option_string(
			request,
			"root",
			""
		),
		config,
		_is_cancelled
	)


## 请求停止后续扫描；已开始的单文件分析由其文本预算限制。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func cancel() -> void:
	_cancel_mutex.lock()
	_cancelled = true
	_cancel_mutex.unlock()


# --- 私有/辅助方法 ---

## 在持锁期间复制标志，不把锁跨入分析或文件读取。
## [br]
## @api private
func _is_cancelled() -> bool:
	_cancel_mutex.lock()
	var cancelled: bool = _cancelled
	_cancel_mutex.unlock()
	return cancelled
