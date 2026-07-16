## GFDialogueContext: 通用对话运行上下文。
##
## 上下文保存运行时值，并把条件判断、mutation 和文本解析委托给项目提供的
## Callable。框架只负责规范调用与结果包装。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFDialogueContext
extends RefCounted


# --- 公共变量 ---

## 运行时值表。字段含义由项目决定。
## [br]
## @api public
## [br]
## @schema values: 项目自定义运行时值 Dictionary；键通常为 StringName，值由项目决定。
var values: Dictionary = {}

## 条件处理器，建议签名为 func(condition_id, payload, subject, context) -> Variant。
## [br]
## @api public
var condition_handler: Callable = Callable()

## mutation 处理器，建议签名为 func(mutation_id, payload, subject, context) -> Variant。
## [br]
## @api public
var mutation_handler: Callable = Callable()

## 文本解析器，建议签名为 func(text, subject, context) -> String。
## [br]
## @api public
var text_resolver: Callable = Callable()


# --- 私有变量 ---

var _architecture_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _init(architecture: GFArchitecture = null, initial_values: Dictionary = {}) -> void:
	var _set_architecture_result_48: Variant = set_architecture(architecture)
	values = initial_values.duplicate(true)


# --- 公共方法 ---

## 设置架构引用。
## [br]
## @api public
## [br]
## @param architecture: 架构实例。
## [br]
## @return: 当前上下文。
func set_architecture(architecture: GFArchitecture) -> GFDialogueContext:
	_architecture_ref = weakref(architecture) if architecture != null else null
	return self


## 获取架构引用。
## [br]
## @api public
## [br]
## @return: 架构实例；不存在时返回 null。
func get_architecture() -> GFArchitecture:
	if _architecture_ref == null:
		return null
	return _get_architecture_value(_architecture_ref.get_ref())


## 写入上下文值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param value: 值。
## [br]
## @schema value: 要写入 values 的任意项目值。
## [br]
## @return: 当前上下文。
func set_value(key: StringName, value: Variant) -> GFDialogueContext:
	values[key] = value
	return self


## 读取上下文值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param default_value: 默认值。
## [br]
## @schema default_value: key 缺失时返回的任意默认值。
## [br]
## @return: 当前值或默认值。
## [br]
## @schema return: values 中的项目值，或传入的 default_value。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(values, key, default_value)


## 检查条件。
## [br]
## @api public
## [br]
## @param condition_id: 条件 ID。
## [br]
## @param payload: 条件载荷。
## [br]
## @schema payload: 条件处理器接收的任意项目载荷；框架只透传。
## [br]
## @param subject: 触发条件的行、响应或项目对象。
## [br]
## @schema subject: GFDialogueLine、GFDialogueResponse 或项目传入的任意条件主体。
## [br]
## @return: 结构化结果。
## [br]
## @schema return: 包含 ok、reason 和 value 等字段的 Dictionary；当处理器返回 Dictionary 时会保留调用方字段。
func check_condition(condition_id: StringName, payload: Variant = null, subject: Variant = null) -> Dictionary:
	if condition_id == &"":
		return _normalize_result(true)
	if not condition_handler.is_valid():
		return _normalize_result(false, &"missing_condition_handler")
	return _normalize_result(condition_handler.call(condition_id, payload, subject, self))


## 请求执行 mutation。
## [br]
## @api public
## [br]
## @param mutation_id: mutation ID。
## [br]
## @param payload: mutation 载荷。
## [br]
## @schema payload: mutation 处理器接收的任意项目载荷；框架只透传。
## [br]
## @param subject: 触发 mutation 的行、响应或项目对象。
## [br]
## @schema subject: GFDialogueLine、GFDialogueResponse 或项目传入的任意 mutation 主体。
## [br]
## @return: 结构化结果。
## [br]
## @schema return: 包含 ok、reason 和 value 等字段的 Dictionary；当处理器返回 Dictionary 时会保留调用方字段。
func apply_mutation(mutation_id: StringName, payload: Variant = null, subject: Variant = null) -> Dictionary:
	if mutation_id == &"":
		return _normalize_result(true)
	if not mutation_handler.is_valid():
		return _normalize_result(false, &"missing_mutation_handler")
	return _normalize_result(mutation_handler.call(mutation_id, payload, subject, self))


## 解析文本。
## [br]
## @api public
## [br]
## @param text: 原始文本或文本键。
## [br]
## @param subject: 文本所属行、响应或项目对象。
## [br]
## @schema subject: GFDialogueLine、GFDialogueResponse 或项目传入的任意文本主体。
## [br]
## @return: 解析后的文本。
func resolve_text(text: String, subject: Variant = null) -> String:
	if not text_resolver.is_valid():
		return text
	return GFVariantData.to_text(text_resolver.call(text, subject, self))


## 序列化运行值为 JSON 兼容结构。
## [br]
## @api public
## [br]
## @return: JSON 兼容值表副本。
## [br]
## @since 8.0.0
## [br]
## @schema return: values 经过 GFVariantJsonCodec 编码后的深拷贝 Dictionary。
func serialize_values() -> Dictionary:
	var encoded_values: Variant = GFVariantJsonCodec.variant_to_json_compatible(values, {
		"encode_dictionary_keys": true,
	})
	if encoded_values is Dictionary:
		var encoded_dictionary: Dictionary = encoded_values
		return encoded_dictionary.duplicate(true)
	return {}


## 从 JSON 兼容结构恢复运行值。
## [br]
## @api public
## [br]
## @param data: serialize_values() 返回的值表。
## [br]
## @since 8.0.0
## [br]
## @schema data: serialize_values() 返回的 JSON 兼容 Dictionary。
func deserialize_values(data: Dictionary) -> void:
	var decoded_values: Variant = GFVariantJsonCodec.json_compatible_to_variant(data)
	if decoded_values is Dictionary:
		var decoded_dictionary: Dictionary = decoded_values
		values = decoded_dictionary.duplicate(true)
		return
	values = {}


# --- 私有/辅助方法 ---

func _normalize_result(raw_result: Variant, default_reason: StringName = &"ok") -> Dictionary:
	if raw_result is Dictionary:
		var result: Dictionary = GFVariantData.to_dictionary(raw_result, {}, true)
		if not result.has("ok"):
			result["ok"] = false
		if not result.has("reason"):
			result["reason"] = default_reason if GFVariantData.get_option_bool(result, "ok", false) else &"rejected"
		return result

	var ok: bool = false
	if raw_result is bool:
		ok = GFVariantData.to_bool(raw_result, false)
	return {
		"ok": ok,
		"reason": default_reason if ok else &"rejected",
		"value": raw_result,
	}


func _get_architecture_value(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null
