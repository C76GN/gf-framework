## GFPlatformBridgeRequest: 平台桥接请求。
##
## 用纯数据描述从 GF 或项目侧发往外部平台 adapter 的一次调用。它不执行调用，
## 只为 JS bridge、native SDK bridge 或进程桥接提供统一请求载体。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFPlatformBridgeRequest
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

## 请求载荷。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema payload: Dictionary adapter-defined request payload.
@export var payload: Dictionary = {}

## 超时时间，单位毫秒；小于等于 0 表示由调用方决定。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var timeout_msec: int = 0

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined request metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置桥接请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_request_id: 请求 ID。
## [br]
## @param p_contract_id: 桥接契约 ID。
## [br]
## @param p_method_id: 方法 ID。
## [br]
## @param p_payload: 请求载荷。
## [br]
## @param p_timeout_msec: 超时时间，单位毫秒。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_payload: Dictionary adapter-defined request payload.
## [br]
## @schema p_metadata: Dictionary caller-defined request metadata.
## [br]
## @return 当前请求。
func configure(
	p_request_id: StringName,
	p_contract_id: StringName,
	p_method_id: StringName,
	p_payload: Dictionary = {},
	p_timeout_msec: int = 0,
	p_metadata: Dictionary = {}
) -> GFPlatformBridgeRequest:
	request_id = p_request_id
	contract_id = p_contract_id
	method_id = p_method_id
	payload = p_payload.duplicate(true)
	timeout_msec = max(p_timeout_msec, 0)
	metadata = p_metadata.duplicate(true)
	return self


## 检查请求是否缺少最小契约字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 缺少 request_id、contract_id 或 method_id 时返回 true。
func is_empty() -> bool:
	return request_id == &"" or contract_id == &"" or method_id == &""


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 桥接请求字典。
## [br]
## @schema return: Dictionary platform bridge request.
func to_dict() -> Dictionary:
	return {
		"request_id": request_id,
		"contract_id": contract_id,
		"method_id": method_id,
		"payload": payload.duplicate(true),
		"timeout_msec": timeout_msec,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用桥接请求字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 桥接请求字典。
## [br]
## @schema data: Dictionary platform bridge request.
func apply_dict(data: Dictionary) -> void:
	request_id = GFVariantData.get_option_string_name(data, "request_id")
	contract_id = GFVariantData.get_option_string_name(data, "contract_id")
	method_id = GFVariantData.get_option_string_name(data, "method_id")
	payload = GFVariantData.get_option_dictionary(data, "payload")
	timeout_msec = max(GFVariantData.get_option_int(data, "timeout_msec"), 0)
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建桥接请求深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新桥接请求。
func duplicate_request() -> GFPlatformBridgeRequest:
	return from_dict(to_dict())


## 从字典创建桥接请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 桥接请求字典。
## [br]
## @schema data: Dictionary platform bridge request.
## [br]
## @return 新桥接请求。
static func from_dict(data: Dictionary) -> GFPlatformBridgeRequest:
	var result: GFPlatformBridgeRequest = GFPlatformBridgeRequest.new()
	result.apply_dict(data)
	return result
