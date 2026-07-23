## GFPlatformActivationIntent: 平台激活入口事件。
##
## 统一表达命令行启动、邀请加入、深链、前台恢复或平台入口参数。该值对象只记录
## 平台事实，不解释奖励、导航、匹配或其他项目策略。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since unreleased
class_name GFPlatformActivationIntent
extends Resource


# --- 导出变量 ---

## 平台侧或 adapter 生成的幂等 ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var intent_id: StringName = &""

## Provider-neutral 意图类型。
## [br]
## @api public
## [br]
## @since unreleased
@export var intent_type: StringName = &""

## 来源平台 ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var platform_id: StringName = &""

## 来源 Adapter ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var adapter_id: StringName = &""

## 平台入口来源，例如 command_line、invite、deep_link 或 resume。
## [br]
## @api public
## [br]
## @since unreleased
@export var source: StringName = &""

## 单调时间戳，单位毫秒。
## [br]
## @api public
## [br]
## @since unreleased
@export var timestamp_msec: int = 0

## Provider-neutral 入口载荷。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema payload: Dictionary platform activation payload.
@export var payload: Dictionary = {}

## Adapter 定义的非敏感元数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema metadata: Dictionary platform activation metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置激活意图。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_intent_id: 幂等 ID。
## [br]
## @param p_intent_type: Provider-neutral 意图类型。
## [br]
## @param p_payload: 入口载荷。
## [br]
## @param options: 可包含 platform_id、adapter_id、source、timestamp_msec 和 metadata。
## [br]
## @schema p_payload: Dictionary platform activation payload.
## [br]
## @schema options: Dictionary platform activation options.
## [br]
## @return 当前意图。
func configure(
	p_intent_id: StringName,
	p_intent_type: StringName,
	p_payload: Dictionary = {},
	options: Dictionary = {}
) -> GFPlatformActivationIntent:
	intent_id = StringName(String(p_intent_id).strip_edges())
	intent_type = StringName(String(p_intent_type).strip_edges())
	platform_id = GFVariantData.get_option_string_name(options, "platform_id")
	adapter_id = GFVariantData.get_option_string_name(options, "adapter_id")
	source = GFVariantData.get_option_string_name(options, "source")
	timestamp_msec = maxi(GFVariantData.get_option_int(options, "timestamp_msec"), 0)
	payload = p_payload.duplicate(true)
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 检查是否缺少最小身份字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 缺少 intent_id 或 intent_type 时返回 true。
func is_empty() -> bool:
	return intent_id == &"" or intent_type == &""


## 转换为字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 激活意图字典。
## [br]
## @schema return: Dictionary platform activation intent.
func to_dict() -> Dictionary:
	return {
		"intent_id": intent_id,
		"intent_type": intent_type,
		"platform_id": platform_id,
		"adapter_id": adapter_id,
		"source": source,
		"timestamp_msec": timestamp_msec,
		"payload": payload.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param data: 激活意图字典。
## [br]
## @schema data: Dictionary platform activation intent.
func apply_dict(data: Dictionary) -> void:
	intent_id = GFVariantData.get_option_string_name(data, "intent_id")
	intent_type = GFVariantData.get_option_string_name(data, "intent_type")
	platform_id = GFVariantData.get_option_string_name(data, "platform_id")
	adapter_id = GFVariantData.get_option_string_name(data, "adapter_id")
	source = GFVariantData.get_option_string_name(data, "source")
	timestamp_msec = maxi(GFVariantData.get_option_int(data, "timestamp_msec"), 0)
	payload = GFVariantData.get_option_dictionary(data, "payload")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建意图深拷贝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新意图。
func duplicate_intent() -> GFPlatformActivationIntent:
	return from_dict(to_dict())


## 从字典创建意图。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param data: 激活意图字典。
## [br]
## @schema data: Dictionary platform activation intent.
## [br]
## @return 新意图。
static func from_dict(data: Dictionary) -> GFPlatformActivationIntent:
	var intent: GFPlatformActivationIntent = GFPlatformActivationIntent.new()
	intent.apply_dict(data)
	return intent
