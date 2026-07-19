## GFPlatformBridgeResult: 平台桥接结果。
##
## 用纯数据表达外部平台 adapter 对一次桥接请求的成功、失败、状态、返回值和耗时。
## 它不包含平台 SDK 依赖，也不假设同步或异步实现方式。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFPlatformBridgeResult
extends Resource


# --- 导出变量 ---

## 请求 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var request_id: StringName = &""

## 桥接契约 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var contract_id: StringName = &""

## 方法 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var method_id: StringName = &""

## 是否成功。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var ok: bool = false

## 状态码。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var status: StringName = &""

## 返回值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema value: Adapter-defined result value.
@export var value: Variant = null

## 错误描述。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var error: String = ""

## 开始时间戳，单位毫秒。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var started_at_msec: int = 0

## 完成时间戳，单位毫秒。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var completed_at_msec: int = 0

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined result metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置成功结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param request: 对应请求。
## [br]
## @param p_value: 返回值。
## [br]
## @param p_status: 状态码。
## [br]
## @param p_started_at_msec: 开始时间戳。
## [br]
## @param p_completed_at_msec: 完成单调时间戳；0 表示调用方未提供。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_value: Adapter-defined result value.
## [br]
## @schema p_metadata: Dictionary caller-defined result metadata.
## [br]
## @return 当前结果。
func configure_success(
	request: GFPlatformBridgeRequest,
	p_value: Variant = null,
	p_status: StringName = &"ok",
	p_started_at_msec: int = 0,
	p_completed_at_msec: int = 0,
	p_metadata: Dictionary = {}
) -> GFPlatformBridgeResult:
	_apply_request(request)
	ok = true
	status = p_status
	value = GFVariantData.duplicate_variant(p_value)
	error = ""
	started_at_msec = max(p_started_at_msec, 0)
	completed_at_msec = maxi(p_completed_at_msec, 0)
	metadata = p_metadata.duplicate(true)
	return self


## 配置失败结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param request: 对应请求。
## [br]
## @param p_error: 错误描述。
## [br]
## @param p_status: 状态码。
## [br]
## @param p_started_at_msec: 开始时间戳。
## [br]
## @param p_completed_at_msec: 完成单调时间戳；0 表示调用方未提供。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined result metadata.
## [br]
## @return 当前结果。
func configure_failure(
	request: GFPlatformBridgeRequest,
	p_error: String,
	p_status: StringName = &"failed",
	p_started_at_msec: int = 0,
	p_completed_at_msec: int = 0,
	p_metadata: Dictionary = {}
) -> GFPlatformBridgeResult:
	_apply_request(request)
	ok = false
	status = p_status
	value = null
	error = p_error.strip_edges()
	started_at_msec = max(p_started_at_msec, 0)
	completed_at_msec = maxi(p_completed_at_msec, 0)
	metadata = p_metadata.duplicate(true)
	return self


## 获取耗时，单位毫秒。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 完成时间减开始时间；缺少时间戳时返回 0。
func get_duration_msec() -> int:
	if started_at_msec <= 0 or completed_at_msec <= 0:
		return 0
	return max(completed_at_msec - started_at_msec, 0)


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 桥接结果字典。
## [br]
## @schema return: Dictionary platform bridge result.
func to_dict() -> Dictionary:
	return {
		"request_id": request_id,
		"contract_id": contract_id,
		"method_id": method_id,
		"ok": ok,
		"status": status,
		"value": GFVariantData.duplicate_variant(value),
		"error": error,
		"started_at_msec": started_at_msec,
		"completed_at_msec": completed_at_msec,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用桥接结果字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 桥接结果字典。
## [br]
## @schema data: Dictionary platform bridge result.
func apply_dict(data: Dictionary) -> void:
	request_id = GFVariantData.get_option_string_name(data, "request_id")
	contract_id = GFVariantData.get_option_string_name(data, "contract_id")
	method_id = GFVariantData.get_option_string_name(data, "method_id")
	ok = GFVariantData.get_option_bool(data, "ok")
	status = GFVariantData.get_option_string_name(data, "status")
	value = GFVariantData.duplicate_variant(GFVariantData.get_option_value(data, "value"))
	error = GFVariantData.get_option_string(data, "error").strip_edges()
	started_at_msec = max(GFVariantData.get_option_int(data, "started_at_msec"), 0)
	completed_at_msec = max(GFVariantData.get_option_int(data, "completed_at_msec"), 0)
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建桥接结果深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新桥接结果。
func duplicate_result() -> GFPlatformBridgeResult:
	return from_dict(to_dict())


## 从字典创建桥接结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 桥接结果字典。
## [br]
## @schema data: Dictionary platform bridge result.
## [br]
## @return 新桥接结果。
static func from_dict(data: Dictionary) -> GFPlatformBridgeResult:
	var result: GFPlatformBridgeResult = GFPlatformBridgeResult.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

func _apply_request(request: GFPlatformBridgeRequest) -> void:
	if request == null:
		request_id = &""
		contract_id = &""
		method_id = &""
		return
	request_id = request.request_id
	contract_id = request.contract_id
	method_id = request.method_id
