## GFUINavigationTarget: 冻结的路由与语义定位参数。
##
## 不保存场景节点路径或节点引用。空参数表示只等待内容就绪；非空参数由项目 resolver
## 解释为页签、条目 ID 等业务定位信息。普通路由打开不需要创建此对象。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFUINavigationTarget
extends RefCounted


# --- 私有变量 ---

## 经过规范化并冻结的路由 ID。
## [br]
## @api private
var _route_id: StringName = &""

## 有界纯数据参数，不与调用方共享可写容器。
## [br]
## @api private
var _parameters: Dictionary = {}


# --- 公共方法 ---

## 创建一个内容就绪或语义定位请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param route_id: 非空路由 ID，最多 256 字符。
## [br]
## @param parameters: 项目定义的语义参数；空字典只等待内容。
## [br]
## @schema parameters: 由有限原生纯数据组成的 Dictionary；拒绝 Object、环、非有限数值。深度最多 8、节点 256、规范编码 16 KiB。
## [br]
## @return 冻结目标；身份或参数无效时为 null。
static func create(route_id: StringName, parameters: Dictionary = {}) -> GFUINavigationTarget:
	var report: Dictionary = _validate_create(route_id, parameters)
	if not GFVariantData.get_option_bool(report, "ok"):
		return null
	var target: GFUINavigationTarget = GFUINavigationTarget.new()
	target._route_id = StringName(String(route_id).strip_edges())
	target._parameters = parameters.duplicate(true)
	return target


## 只读检查目标输入，不创建目标或请求，create 仍会重新校验。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param route_id: 与 create 相同的路由身份，仍允许既有首尾空白规范化。
## [br]
## @param parameters: 与 create 相同的纯数据语义参数。
## [br]
## @schema parameters: 与 create.parameters 相同；报告中的位置为 /parameters 整体，不承诺定位纯数据内部叶子。
## [br]
## @return 当前输入的独立校验报告；不输出错误日志。
## [br]
## @schema return: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。
static func validate_create(route_id: StringName, parameters: Dictionary = {}) -> Dictionary:
	return _validate_create(route_id, parameters)


## 获取规范化路由身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 冻结的路由 ID；未经 create 的对象为空。
func get_route_id() -> StringName:
	return _route_id


## 获取语义定位参数的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 创建时验证的纯数据。
## [br]
## @schema return: Dictionary，结构与 create.parameters 相同，不暴露内部可写容器。
func get_parameters() -> Dictionary:
	return _parameters.duplicate(true)


## 区分只等待内容与需要语义定位的请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非空参数需要在内容就绪后执行定位。
func has_semantic_target() -> bool:
	return not _parameters.is_empty()


## 比较请求意义，用于合并同一 pending 导航。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param other: 待比较目标。
## [br]
## @return 路由身份与参数完全一致时为 true。
func is_equivalent_to(other: GFUINavigationTarget) -> bool:
	return (
		other != null
		and _route_id == other._route_id
		and _parameters == other._parameters
	)


# --- 私有/辅助方法 ---

## 工厂与诊断共用同一目标验证；只测量参数，不复制或缓存调用方数据。
## [br]
## @api private
static func _validate_create(route_id: StringName, parameters: Dictionary) -> Dictionary:
	var normalized: String = String(route_id).strip_edges()
	if normalized.is_empty():
		return _validation_report("required", "/route_id")
	if normalized.length() > 256:
		return _validation_report(
			"length_limit",
			"/route_id",
			256,
			normalized.length()
		)
	var limits: Dictionary = {
		"allow_floats": true,
		"max_depth": 8,
		"max_items": 256,
		"max_output_bytes": 16384,
		"max_string_length": 16384,
	}
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(parameters, limits)
	return _data_validation_report(
		measured,
		limits,
		"/parameters"
	)


## 每次创建独立纯数据报告，不保存全局错误或可复用的准入资格。
## [br]
## @api private
static func _validation_report(
	error_kind: String = "",
	path: String = "",
	limit: int = -1,
	observed: int = -1
) -> Dictionary:
	var report: Dictionary = {
		"ok": error_kind.is_empty(),
		"error_kind": error_kind,
		"path": path,
	}
	if limit >= 0:
		report["limit"] = limit
		report["observed"] = observed
	return report


## 保留底层计量和预算，不从错误文本猜测种类或把前缀计数当作总量。
## [br]
## @api private
static func _data_validation_report(
	measured: Dictionary,
	limits: Dictionary,
	path: String
) -> Dictionary:
	if GFVariantData.get_option_bool(measured, "ok"):
		return _validation_report()
	var report: Dictionary = _validation_report("data_invalid", path)
	report["measurement"] = measured.duplicate(true)
	report["limits"] = limits.duplicate()
	var limit_kind: String = GFVariantData.get_option_string(measured, "limit_kind")
	if not limit_kind.is_empty():
		report["error_kind"] = "budget_exceeded"
		report["limit_kind"] = limit_kind
		report["limit"] = GFVariantData.get_option_int(measured, "limit")
		report["observed"] = GFVariantData.get_option_int(measured, "observed")
		report["observed_is_lower_bound"] = GFVariantData.get_option_bool(measured, "observed_is_lower_bound")
	elif GFVariantData.get_option_string(measured, "failure_kind") == "output_limit":
		var output_limit: int = GFVariantData.get_option_int(limits, "max_output_bytes")
		report["error_kind"] = "budget_exceeded"
		report["limit_kind"] = "max_output_bytes"
		report["limit"] = output_limit
		report["observed"] = output_limit + 1
		report["observed_is_lower_bound"] = true
	return report
