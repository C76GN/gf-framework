## GFDerivedAttributeRule: 通用派生属性规则。
##
## 通过权重或自定义回调从 GFAttributeSet 的其他属性计算目标属性，不规定属性业务含义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFDerivedAttributeRule
extends Resource


# --- 常量 ---

## 默认规则最小值。
## [br]
## @api public
const DEFAULT_MIN_VALUE: float = -1.0e20

## 默认规则最大值。
## [br]
## @api public
const DEFAULT_MAX_VALUE: float = 1.0e20


# --- 导出变量 ---

## 被写入的目标属性 ID。
## [br]
## @api public
@export var attribute_id: StringName = &""

## 参与计算的来源属性 ID。为空时使用 source_weights 的键。
## [br]
## @api public
## [br]
## @schema source_attribute_ids: Array[StringName]，参与当前派生规则计算的来源属性 ID 列表。
@export var source_attribute_ids: Array[StringName] = []

## 来源属性权重，键为属性 ID，值为数字权重。
## [br]
## @api public
## [br]
## @schema source_weights: Dictionary，键为 StringName 或 String 属性 ID，值为 float 权重。
@export var source_weights: Dictionary = {}

## 固定加值。
## [br]
## @api public
@export var flat_bonus: float = 0.0

## 规则级最小值。
## [br]
## @api public
@export var min_value: float = DEFAULT_MIN_VALUE

## 规则级最大值。
## [br]
## @api public
@export var max_value: float = DEFAULT_MAX_VALUE

## 是否同步写入目标属性的 base 值。
## [br]
## @api public
@export var sync_base_value: bool = false


# --- 公共变量 ---

## 自定义计算回调，建议签名为 func(attribute_set: GFAttributeSet, rule: GFDerivedAttributeRule) -> Variant。
## [br]
## @api public
var compute_callback: Callable = Callable()


# --- 公共方法 ---

## 计算派生属性值。
## [br]
## @api public
## [br]
## @param attribute_set: 属性集合。
## [br]
## @return: 计算后的数值。
func calculate(attribute_set: Object) -> float:
	if attribute_set == null:
		return _clamp_result(flat_bonus)

	if compute_callback.is_valid():
		var custom_value: Variant = compute_callback.call(attribute_set, self)
		if custom_value is float or custom_value is int:
			return _clamp_result(GFVariantData.to_float(custom_value))

	var result: float = flat_bonus
	for source_id: StringName in get_source_attribute_ids():
		if source_id == &"" or not attribute_set.has_method("get_value"):
			continue
		result += GFVariantData.to_float(attribute_set.call("get_value", source_id, 0.0)) * get_source_weight(source_id)
	return _clamp_result(result)


## 获取来源属性 ID 列表。
## [br]
## @api public
## [br]
## @return: 来源属性 ID 副本。
## [br]
## @schema return: Array[StringName]，当前规则实际使用的来源属性 ID 列表。
func get_source_attribute_ids() -> Array[StringName]:
	if not source_attribute_ids.is_empty():
		return source_attribute_ids.duplicate()

	var result: Array[StringName] = []
	for key: Variant in source_weights.keys():
		result.append(GFVariantData.to_string_name(key))
	return result


## 获取来源属性权重。
## [br]
## @api public
## [br]
## @param source_attribute_id: 来源属性 ID。
## [br]
## @return: 权重；未配置时返回 1。
func get_source_weight(source_attribute_id: StringName) -> float:
	var fallback: float = GFVariantData.get_option_float(source_weights, String(source_attribute_id), 1.0)
	return GFVariantData.get_option_float(source_weights, source_attribute_id, fallback)


## 判断是否依赖指定属性。
## [br]
## @api public
## [br]
## @param source_attribute_id: 来源属性 ID。
## [br]
## @return: 依赖返回 true。
func depends_on(source_attribute_id: StringName) -> bool:
	return get_source_attribute_ids().has(source_attribute_id)


## 创建当前规则的深拷贝。
## [br]
## @api public
## [br]
## @return: 规则副本。
func duplicate_rule() -> GFDerivedAttributeRule:
	var rule: GFDerivedAttributeRule = _get_derived_attribute_rule_value(duplicate(true))
	return rule if rule != null else GFDerivedAttributeRule.new()


# --- 私有/辅助方法 ---

## 按规则的最小值和最大值范围限制计算结果。
## [br]
## @api private
func _clamp_result(value: float) -> float:
	var safe_min: float = minf(min_value, max_value)
	var safe_max: float = maxf(min_value, max_value)
	return clampf(value, safe_min, safe_max)


## 将任意值收窄为 GFDerivedAttributeRule 实例，否则返回 null。
## [br]
## @api private
func _get_derived_attribute_rule_value(value: Variant) -> GFDerivedAttributeRule:
	if value is GFDerivedAttributeRule:
		var rule: GFDerivedAttributeRule = value
		return rule
	return null
