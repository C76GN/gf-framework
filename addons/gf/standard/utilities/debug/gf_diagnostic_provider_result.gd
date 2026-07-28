## GFDiagnosticProviderResult: 惰性诊断 Provider 的类型化采集结果。
##
## 成功结果携带尚未编码的临时值；失败结果携带稳定错误码和面向维护者的说明。
## 非法错误码会归一为 `provider_failed`，错误说明最多保留 1024 个字符。
## `GFDiagnosticsUtility` 会在把结果纳入快照前执行结构预算、脱敏和 JSON-safe 编码。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFDiagnosticProviderResult
extends RefCounted


# --- 常量 ---

const _MAX_ERROR_CODE_LENGTH: int = 128
const _MAX_ERROR_MESSAGE_LENGTH: int = 1024


# --- 私有变量 ---

var _successful: bool = false
var _value: Variant = null
var _error_code: StringName = &""
var _error_message: String = ""
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 创建成功结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param value: Provider 采集的临时值。
## [br]
## @schema value: Variant with provider-defined ephemeral diagnostic data.
## [br]
## @param metadata: 本次采集的附加元数据。
## [br]
## @schema metadata: Dictionary with provider-defined ephemeral metadata.
## [br]
## @return 新的成功结果。
static func succeeded(value: Variant, metadata: Dictionary = {}) -> GFDiagnosticProviderResult:
	var result: GFDiagnosticProviderResult = GFDiagnosticProviderResult.new()
	result._successful = true
	result._value = GFVariantData.duplicate_variant(value)
	result._metadata = _duplicate_dictionary(metadata)
	return result


## 创建失败结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param error_code: 非空、无首尾空白且不超过 128 个字符的稳定错误码；非法值回退为 provider_failed。
## [br]
## @param error_message: 面向维护者的失败说明；最多保留 1024 个字符。
## [br]
## @param metadata: 本次失败的附加元数据。
## [br]
## @schema metadata: Dictionary with provider-defined ephemeral metadata.
## [br]
## @return 新的失败结果。
static func failed(
	error_code: StringName,
	error_message: String = "",
	metadata: Dictionary = {}
) -> GFDiagnosticProviderResult:
	var result: GFDiagnosticProviderResult = GFDiagnosticProviderResult.new()
	result._successful = false
	var error_code_text: String = String(error_code)
	var normalized_error_code_text: String = error_code_text.strip_edges()
	if (
		normalized_error_code_text.is_empty()
		or normalized_error_code_text != error_code_text
		or normalized_error_code_text.length() > _MAX_ERROR_CODE_LENGTH
	):
		result._error_code = &"provider_failed"
	else:
		result._error_code = StringName(normalized_error_code_text)
	result._error_message = error_message.left(_MAX_ERROR_MESSAGE_LENGTH)
	result._metadata = _duplicate_dictionary(metadata)
	return result


## 查询采集是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功时返回 true。
func is_successful() -> bool:
	return _successful


## 获取成功值副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Provider 值副本；失败时返回 null。
## [br]
## @schema return: Provider-defined Variant copy, or null for a failed result.
func get_value() -> Variant:
	return GFVariantData.duplicate_variant(_value) if _successful else null


## 获取稳定错误码。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 失败错误码；成功时为空。
func get_error_code() -> StringName:
	return _error_code


## 获取错误说明。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 失败说明；成功时为空。
func get_error_message() -> String:
	return _error_message


## 获取采集元数据副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Provider 元数据副本。
## [br]
## @schema return: Dictionary with provider-defined ephemeral metadata.
func get_metadata() -> Dictionary:
	return _duplicate_dictionary(_metadata)


# --- 私有/辅助方法 ---

static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))
