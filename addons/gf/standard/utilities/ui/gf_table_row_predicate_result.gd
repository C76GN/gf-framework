## GFTableRowPredicateResult: 类型化行谓词求值结果。
##
## 成功结果明确表示包含或排除当前行；失败结果携带稳定错误码和有界说明，
## 供 GFTableDataView 中止候选投影并保留上一份已提交视图。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFTableRowPredicateResult
extends RefCounted


# --- 常量 ---

const _MAX_ERROR_CODE_UTF8_BYTES: int = 128
const _MAX_ERROR_MESSAGE_UTF8_BYTES: int = 1_024


# --- 私有变量 ---

var _configured: bool = false
var _successful: bool = false
var _should_include: bool = false
var _error_code: StringName = &""
var _error_message: String = ""


# --- 公共方法 ---

## 创建包含当前行的成功结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新的包含结果。
static func included() -> GFTableRowPredicateResult:
	var result: GFTableRowPredicateResult = GFTableRowPredicateResult.new()
	result._configured = true
	result._successful = true
	result._should_include = true
	return result


## 创建排除当前行的成功结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新的排除结果。
static func excluded() -> GFTableRowPredicateResult:
	var result: GFTableRowPredicateResult = GFTableRowPredicateResult.new()
	result._configured = true
	result._successful = true
	result._should_include = false
	return result


## 创建求值失败结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param error_code: 非空、无首尾空白且 UTF-8 编码不超过 128 字节的稳定错误码。
## [br]
## @param error_message: 面向维护者的失败说明；最多保留 1024 个 UTF-8 字节。
## [br]
## @return 新的失败结果。
static func failed(
	error_code: StringName,
	error_message: String = ""
) -> GFTableRowPredicateResult:
	var result: GFTableRowPredicateResult = GFTableRowPredicateResult.new()
	result._configured = true
	result._successful = false
	result._error_code = _normalize_error_code(error_code)
	result._error_message = _truncate_utf8(error_message, _MAX_ERROR_MESSAGE_UTF8_BYTES)
	return result


## 从候选结果的基类存储创建纯框架归一化快照，不调用候选可覆写方法。
## [br]
## 未配置、为空或失效的候选会归一为 invalid_predicate_result 失败。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param source: 项目谓词返回的候选结果。
## [br]
## @return 由 included()、excluded() 或 failed() 创建的纯基类结果。
static func snapshot_for_framework(
	source: GFTableRowPredicateResult
) -> GFTableRowPredicateResult:
	if source == null or not is_instance_valid(source) or not source._configured:
		return failed(
			&"invalid_predicate_result",
			"Row predicate returned an uninitialized typed result."
		)
	if source._successful:
		return included() if source._should_include else excluded()
	return failed(source._error_code, source._error_message)


## 查询求值是否成功。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 成功时返回 true。
func is_successful() -> bool:
	return _successful


## 查询成功结果是否包含当前行。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 成功且应包含当前行时返回 true。
func should_include() -> bool:
	return _successful and _should_include


## 获取稳定错误码。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败错误码；成功时为空。
func get_error_code() -> StringName:
	return _error_code


## 获取有界错误说明。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败说明；成功时为空。
func get_error_message() -> String:
	return _error_message


# --- 框架内部方法 ---

## 查询结果是否由类型化工厂完整构建。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return included()、excluded() 或 failed() 已完成配置时返回 true。
func is_configured_for_framework() -> bool:
	return _configured


# --- 私有/辅助方法 ---

static func _normalize_error_code(error_code: StringName) -> StringName:
	var error_text: String = String(error_code)
	if (
		error_text.is_empty()
		or error_text != error_text.strip_edges()
		or error_text.length() > _MAX_ERROR_CODE_UTF8_BYTES
		or error_text.to_utf8_buffer().size() > _MAX_ERROR_CODE_UTF8_BYTES
	):
		return &"predicate_failed"
	return error_code


static func _truncate_utf8(text_value: String, max_bytes: int) -> String:
	var bounded_text: String = text_value.left(max_bytes)
	if text_value.length() <= max_bytes and bounded_text.to_utf8_buffer().size() <= max_bytes:
		return text_value
	var low: int = 0
	var high: int = bounded_text.length()
	while low < high:
		var middle: int = floori(float(low + high + 1) / 2.0)
		if bounded_text.left(middle).to_utf8_buffer().size() <= max_bytes:
			low = middle
		else:
			high = middle - 1
	return bounded_text.left(low)
