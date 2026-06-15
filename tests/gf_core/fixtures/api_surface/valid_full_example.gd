@tool

## GFAPISurfaceFullExample: 展示 GF API Surface Contract 的完整正例。
##
## 该类型模拟一个运行时服务，覆盖公开 API、扩展点、内部协作入口、
## 层内入口、私有实现细节、公开数据类型和结构化 Dictionary 说明。
##
## @api public
## @category runtime_service
## @since 1.24.0
class_name GFAPISurfaceFullExample
extends Node


# --- 信号 ---

## 当配置被注册后发出。
##
## @api public
## @param config_id: 被注册配置的唯一 ID。
signal config_registered(config_id: StringName)

## 当请求执行完成后发出。
##
## @api public
## @param request_id: 本次请求 ID。
## @param report: 执行结果报告。
signal request_finished(request_id: StringName, report: GFAPISurfaceReport)


# --- 枚举 ---

## 定义请求执行模式。
##
## @api public
enum ExecuteMode {
	## 立即执行。
	IMMEDIATE,

	## 排队执行。
	QUEUED,

	## 只验证请求，不产生副作用。
	DRY_RUN,
}

## 定义内部缓存状态。
##
## @api framework_internal
enum CacheState {
	COLD,
	WARM,
	DIRTY,
}


# --- 常量 ---

## 默认请求超时时间，单位为秒。
##
## @api public
const DEFAULT_TIMEOUT_SECONDS: float = 5.0

## 内部缓存 key 前缀。
##
## @api framework_internal
const CACHE_PREFIX: StringName = &"gf_api_surface"


# --- 导出变量 ---

## 是否在编辑器中输出诊断信息。
##
## @api public
@export var verbose_editor_diagnostics: bool = false

## 默认执行模式。
##
## @api public
@export var default_mode: ExecuteMode = ExecuteMode.QUEUED


# --- 公共变量 ---

## 当前注册的配置数量。
##
## 该值只读语义由框架维护，项目代码不应直接写入。
##
## @api public
var config_count: int = 0


# --- 私有变量 ---

var _configs_by_id: Dictionary = {}
var _pending_requests: Array[Dictionary] = []
var _cache_state: CacheState = CacheState.COLD
var _last_architecture: Object = null


# --- @onready 变量 ---

@onready var _owner_node: Node = null


# --- Godot 生命周期方法 ---

func _ready() -> void:
	if Engine.is_editor_hint() and verbose_editor_diagnostics:
		_refresh_editor_diagnostics()


func _exit_tree() -> void:
	_pending_requests.clear()


# --- Godot 回调方法 ---

func _notification(_what: int) -> void:
	pass


# --- GF 生命周期方法 ---

## 注入当前 GF 架构实例。
##
## 这是框架生命周期入口，不是项目普通调用入口。
##
## @api framework_internal
## @param architecture: 当前 GF 架构实例。
func inject_dependencies(architecture: Object) -> void:
	_last_architecture = architecture


## 初始化服务。
##
## @api framework_internal
func init() -> void:
	_cache_state = CacheState.WARM


## 释放服务持有的运行时状态。
##
## @api framework_internal
func dispose() -> void:
	_configs_by_id.clear()
	_pending_requests.clear()
	_last_architecture = null
	_cache_state = CacheState.COLD


# --- 公共方法 ---

## 注册一个配置资源。
##
## @api public
## @param config: 要注册的配置资源。
## @return: 注册是否成功。重复 ID 会返回 false。
func register_config(config: GFAPISurfaceConfig) -> bool:
	if config == null or config.config_id.is_empty():
		return false
	if _configs_by_id.has(config.config_id):
		return false

	_configs_by_id[config.config_id] = config
	config_count = _configs_by_id.size()
	config_registered.emit(config.config_id)
	return true


## 获取指定配置。
##
## @api public
## @param config_id: 配置 ID。
## @return: 找到的配置；不存在时返回 null。
func get_config(config_id: StringName) -> GFAPISurfaceConfig:
	if not _configs_by_id.has(config_id):
		return null
	var config: Variant = _configs_by_id[config_id]
	if config is GFAPISurfaceConfig:
		return config
	return null


## 构建一个请求。
##
## `payload` 使用开放字典是为了兼容项目自定义字段，因此必须通过 `@schema` 描述稳定结构。
##
## @api public
## @param config_id: 配置 ID。
## @param payload: 请求载荷。
## @return: 可提交给 `execute_request()` 的请求字典。
## @schema payload {
##   "type": "Dictionary",
##   "required": ["actor_id"],
##   "properties": {
##     "actor_id": "StringName",
##     "amount": "float",
##     "tags": "Array[StringName]"
##   },
##   "additional_properties": true
## }
## @schema return {
##   "type": "Dictionary",
##   "required": ["request_id", "config_id", "payload", "mode"]
## }
func build_request(config_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var normalized_payload: Dictionary = _normalize_payload(payload)
	return {
		"request_id": _make_request_id(config_id),
		"config_id": config_id,
		"payload": normalized_payload,
		"mode": default_mode,
	}


## 执行请求并返回结果报告。
##
## @api public
## @param request: `build_request()` 生成的请求字典。
## @param mode: 本次执行模式。
## @return: 执行结果报告。
## @schema request {
##   "type": "Dictionary",
##   "required": ["request_id", "config_id", "payload", "mode"]
## }
func execute_request(request: Dictionary, mode: ExecuteMode = ExecuteMode.QUEUED) -> GFAPISurfaceReport:
	var validation: GFAPISurfaceReport = validate_request(request)
	if not validation.accepted:
		return validation

	if mode == ExecuteMode.DRY_RUN:
		return GFAPISurfaceReport.make_accepted(_get_request_id(request))

	if mode == ExecuteMode.QUEUED:
		_pending_requests.append(request)
		return GFAPISurfaceReport.make_queued(_get_request_id(request))

	var report: GFAPISurfaceReport = _execute_now(request)
	request_finished.emit(report.request_id, report)
	return report


## 校验请求结构。
##
## @api public
## @param request: 待校验请求。
## @return: 表示校验结果的报告。
## @schema request {
##   "type": "Dictionary",
##   "required": ["request_id", "config_id"]
## }
func validate_request(request: Dictionary) -> GFAPISurfaceReport:
	if not request.has("request_id"):
		return GFAPISurfaceReport.make_rejected(&"", "missing_request_id")
	if not request.has("config_id"):
		return GFAPISurfaceReport.make_rejected(_string_name_value(request["request_id"]), "missing_config_id")
	if not _configs_by_id.has(_string_name_value(request["config_id"])):
		return GFAPISurfaceReport.make_rejected(_string_name_value(request["request_id"]), "unknown_config")

	return GFAPISurfaceReport.make_accepted(_string_name_value(request["request_id"]))


## 执行所有排队请求。
##
## @api public
## @return: 每个请求的执行报告。
func flush_pending_requests() -> Array[GFAPISurfaceReport]:
	var reports: Array[GFAPISurfaceReport] = []
	var requests: Array[Dictionary] = []
	requests.assign(_pending_requests)
	_pending_requests.clear()

	for request: Dictionary in requests:
		reports.append(execute_request(request, ExecuteMode.IMMEDIATE))

	return reports


## 旧版立即执行入口。
##
## @api public
## @deprecated 1.26.0 Use `execute_request(request, ExecuteMode.IMMEDIATE)` instead.
## @param request: 待执行请求。
## @return: 执行结果报告。
## @schema request {
##   "type": "Dictionary",
##   "required": ["request_id", "config_id", "payload", "mode"]
## }
func run_now(request: Dictionary) -> GFAPISurfaceReport:
	return execute_request(request, ExecuteMode.IMMEDIATE)


# --- 可重写钩子 / 虚方法 ---

## 规范化请求载荷。
##
## 子类可以重写该方法补充项目字段，但必须保留原始字段，不得返回 null。
##
## @api protected
## @param payload: 原始请求载荷。
## @return: 规范化后的请求载荷。
## @schema payload {
##   "type": "Dictionary",
##   "additional_properties": true
## }
## @schema return {
##   "type": "Dictionary",
##   "additional_properties": true
## }
func _normalize_payload(payload: Dictionary) -> Dictionary:
	var normalized: Dictionary = payload.duplicate(true)
	if not normalized.has("tags"):
		normalized["tags"] = []
	return normalized


## 请求实际执行前的钩子。
##
## 返回 false 会拒绝执行，且不会发出 `request_finished`。
##
## @api protected
## @param request: 已通过基础校验的请求。
## @return: 是否允许继续执行。
## @schema request {
##   "type": "Dictionary",
##   "required": ["request_id", "config_id"]
## }
func _before_execute(request: Dictionary) -> bool:
	return not request.is_empty()


## 创建最终报告。
##
## 子类可重写以扩展报告内容，但返回类型必须保持公开类型。
##
## @api protected
## @param request: 已执行的请求。
## @return: 执行结果报告。
## @schema request {
##   "type": "Dictionary",
##   "required": ["request_id", "config_id"]
## }
func _create_success_report(request: Dictionary) -> GFAPISurfaceReport:
	return GFAPISurfaceReport.make_completed(_string_name_value(request["request_id"]))


# --- 框架内部方法 ---

## 重建内部缓存。
##
## 这是 GF 内部跨文件可调用 API，不进入用户公开文档。
##
## @api framework_internal
func rebuild_cache() -> void:
	_cache_state = CacheState.WARM


## 导出内部诊断快照。
##
## 返回 `Dictionary` 是为了编辑器诊断面板动态展示，结构由 `@schema` 锁定。
##
## @api framework_internal
## @return: 当前服务的诊断数据。
## @schema return {
##   "type": "Dictionary",
##   "required": ["config_count", "pending_count", "cache_state"]
## }
func dump_diagnostics() -> Dictionary:
	return {
		"config_count": config_count,
		"pending_count": _pending_requests.size(),
		"cache_state": int(_cache_state),
	}


# --- 层内方法 ---

## 从同一扩展层恢复运行时状态。
##
## 只允许 `addons/gf/extensions/example/**` 调用。
##
## @api layer_internal
## @layer extensions/example
## @param state: 层内保存的状态字典。
## @schema state {
##   "type": "Dictionary",
##   "properties": {
##     "pending_requests": "Array[Dictionary]"
##   }
## }
func restore_layer_state(state: Dictionary) -> void:
	_pending_requests.clear()
	if not state.has("pending_requests"):
		return
	var requests: Variant = state["pending_requests"]
	if not requests is Array:
		return
	for request: Variant in requests:
		if request is Dictionary:
			_pending_requests.append(request)


# --- 私有/辅助方法 ---

func _execute_now(request: Dictionary) -> GFAPISurfaceReport:
	if not _before_execute(request):
		return GFAPISurfaceReport.make_rejected(_string_name_value(request["request_id"]), "blocked_by_hook")

	var report: GFAPISurfaceReport = _create_success_report(request)
	return report


func _make_request_id(config_id: StringName) -> StringName:
	return StringName("%s:%d" % [config_id, Time.get_ticks_usec()])


func _refresh_editor_diagnostics() -> void:
	# Editor-only diagnostics intentionally stays private; it must not enter generated API docs.
	var owner_name: String = ""
	if _owner_node != null:
		owner_name = _owner_node.name
	print_verbose("[GFAPISurfaceFullExample] configs=%d pending=%d owner=%s" % [config_count, _pending_requests.size(), owner_name])


func _get_request_id(request: Dictionary) -> StringName:
	if not request.has("request_id"):
		return &""
	return _string_name_value(request["request_id"])


func _string_name_value(value: Variant) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var text: String = value
		return StringName(text)
	return &""


# --- 信号处理函数 ---

func _on_external_config_changed(config_id: StringName) -> void:
	if _configs_by_id.has(config_id):
		_cache_state = CacheState.DIRTY


# --- 内部类 ---

## 示例服务的公开配置资源。
##
## 公开 Resource 类型的导出字段必须全部有文档注释。
##
## @api public
## @category resource_definition
## @since 1.24.0
class GFAPISurfaceConfig:
	extends Resource

	# --- 导出变量 ---

	## 配置唯一 ID。
	##
	## @api public
	@export var config_id: StringName = &""

	## 展示名称。
	##
	## @api public
	@export var display_name: String = ""

	## 默认权重。
	##
	## @api public
	@export var weight: float = 1.0

	# --- 公共方法 ---

	## 判断配置是否可用。
	##
	## @api public
	## @return: 配置是否具备最小可用信息。
	func is_valid() -> bool:
		return not config_id.is_empty()


## 示例服务的公开结果对象。
##
## 值对象字段必须保持稳定，适合进入 API 文档。
##
## @api public
## @category value_object
## @since 1.24.0
class GFAPISurfaceReport:
	extends RefCounted

	# --- 公共变量 ---

	## 请求 ID。
	##
	## @api public
	var request_id: StringName = &""

	## 请求是否被接受。
	##
	## @api public
	var accepted: bool = false

	## 请求是否已完成。
	##
	## @api public
	var completed: bool = false

	## 拒绝原因；成功时为空字符串。
	##
	## @api public
	var reason: String = ""

	# --- 公共方法 ---

	## 创建已接受报告。
	##
	## @api public
	## @param report_request_id: 请求 ID。
	## @return: 新报告。
	static func make_accepted(report_request_id: StringName) -> GFAPISurfaceReport:
		var report: GFAPISurfaceReport = GFAPISurfaceReport.new()
		report.request_id = report_request_id
		report.accepted = true
		return report

	## 创建已排队报告。
	##
	## @api public
	## @param report_request_id: 请求 ID。
	## @return: 新报告。
	static func make_queued(report_request_id: StringName) -> GFAPISurfaceReport:
		var report: GFAPISurfaceReport = make_accepted(report_request_id)
		report.reason = "queued"
		return report

	## 创建已完成报告。
	##
	## @api public
	## @param report_request_id: 请求 ID。
	## @return: 新报告。
	static func make_completed(report_request_id: StringName) -> GFAPISurfaceReport:
		var report: GFAPISurfaceReport = make_accepted(report_request_id)
		report.completed = true
		return report

	## 创建拒绝报告。
	##
	## @api public
	## @param report_request_id: 请求 ID。
	## @param reject_reason: 拒绝原因。
	## @return: 新报告。
	static func make_rejected(report_request_id: StringName, reject_reason: String) -> GFAPISurfaceReport:
		var report: GFAPISurfaceReport = GFAPISurfaceReport.new()
		report.request_id = report_request_id
		report.reason = reject_reason
		return report


## 示例服务的公开运行时句柄。
##
## 句柄类必须清楚说明所有权、释放和失效语义。
##
## @api public
## @category runtime_handle
## @since 1.24.0
class GFAPISurfaceHandle:
	extends RefCounted

	# --- 公共变量 ---

	## 句柄持有的配置 ID。
	##
	## @api public
	var config_id: StringName = &""

	## 句柄是否已经释放。
	##
	## @api public
	var released: bool = false

	# --- 公共方法 ---

	## 释放句柄。
	##
	## @api public
	## @return: 本次调用是否完成释放。
	func release() -> bool:
		if released:
			return false

		released = true
		return true


class _ParserState:
	extends RefCounted

	var _cursor: int = 0
	var _source: String = ""

	func _reset(source_text: String) -> void:
		_cursor = 0
		_source = source_text

	func _is_at_end() -> bool:
		return _cursor >= _source.length()
