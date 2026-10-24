## GFContextCloseResult: 节点上下文一次关闭尝试的不可变结果。
##
## closed 表示绑定和自有架构均已关闭，drained 表示全部子上下文和架构正常完成静默工作。
## 关闭结果不持有 Node；子结果数组在读取边界复制。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
## [br]
## @layer kernel/core
class_name GFContextCloseResult
extends RefCounted


# --- 私有变量 ---

## 是否已关闭。
## [br]
## @api private
var _closed: bool = false

## 是否完成全部协作静默工作。
## [br]
## @api private
var _drained: bool = false

## 关闭尝试的错误码。
## [br]
## @api private
var _error_code: Error = OK

## 关闭尝试的错误说明。
## [br]
## @api private
var _error: String = ""

## 自有架构的关闭结果，继承上下文为空。
## [br]
## @api private
var _architecture_result: GFArchitectureShutdownResult = null

## 直接逻辑子上下文的关闭结果。
## [br]
## @api private
var _children: Array[GFContextCloseResult] = []


# --- 公共方法 ---

## 检查本次尝试结束后上下文是否已关闭。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已关闭时返回 true；ERR_BUSY 等拒绝可能仍未关闭。
func is_closed() -> bool:
	return _closed


## 检查全部拥有的工作是否正常完成静默关闭。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 无强制释放、取消、超时或失败时返回 true。
func is_drained() -> bool:
	return _drained


## 读取关闭错误码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首个子关闭或架构关闭错误；正常完成为 OK。
func get_error_code() -> Error:
	return _error_code


## 读取关闭错误说明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 失败说明；正常完成为空。
func get_error() -> String:
	return _error


## 读取自有架构的关闭结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 自有架构结果的副本；INHERITED 或尚未尝试架构关闭时为 null。
func get_architecture_result() -> GFArchitectureShutdownResult:
	return _architecture_result.duplicate_result() if _architecture_result != null else null


## 读取直接逻辑子上下文的关闭结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 独立数组，元素为不可变关闭结果。
func get_child_results() -> Array[GFContextCloseResult]:
	return _children.duplicate()


# --- 框架内部方法 ---

## 构造一次关闭尝试的结果。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param closed: 是否已关闭。
## [br]
## @param drained: 是否全部正常静默完成。
## [br]
## @param error_code: 关闭错误码。
## [br]
## @param error: 关闭错误说明。
## [br]
## @param architecture_result: 自有架构的关闭结果。
## [br]
## @param children: 子上下文结果。
## [br]
## @return 不可变结果。
static func create(
	closed: bool,
	drained: bool,
	error_code: Error = OK,
	error: String = "",
	architecture_result: GFArchitectureShutdownResult = null,
	children: Array[GFContextCloseResult] = []
) -> GFContextCloseResult:
	var result: GFContextCloseResult = GFContextCloseResult.new()
	result._closed = closed
	result._drained = drained
	result._error_code = error_code
	result._error = error
	result._architecture_result = architecture_result.duplicate_result() if architecture_result != null else null
	result._children = children.duplicate()
	return result
