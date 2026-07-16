## GFWeightedEntry: 权重表中的单个候选项。
##
## 只保存值、权重和可选元数据，不约束 value 的业务类型。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFWeightedEntry
extends Resource


# --- 导出变量 ---

## 被选择后返回的值。
## [br]
## @api public
## [br]
## @schema value: Variant selected value owned by project code.
@export var value: Variant = null

## 权重；必须是有限正数才会被选择。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_range(0.0, 1000000000000.0, 0.001, "or_greater") var weight: float = 1.0:
	set(raw_weight):
		weight = _normalize_weight(raw_weight)

## 项目层可选元数据，框架不解释其含义。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary extension metadata for the weighted entry.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置条目内容。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_value: 被选择后返回的值。
## [br]
## @schema p_value: Variant selected value owned by project code.
## [br]
## @param p_weight: 权重；非有限数或小于等于 0 表示不可被选择。
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @schema p_metadata: Dictionary extension metadata for the weighted entry.
## [br]
## @return 当前条目。
func configure(p_value: Variant, p_weight: float = 1.0, p_metadata: Dictionary = {}) -> GFWeightedEntry:
	value = p_value
	weight = p_weight
	metadata = p_metadata.duplicate(true)
	return self


## 判断该条目当前是否可被选择。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 权重为有限正数时返回 true。
func is_selectable() -> bool:
	return weight > 0.0 and not is_nan(weight) and not is_inf(weight)


## 复制当前条目。
## [br]
## @api public
## [br]
## @param deep: 是否深拷贝元数据。
## [br]
## @return 新条目实例。
func duplicate_entry(deep: bool = true) -> GFWeightedEntry:
	var entry: GFWeightedEntry = GFWeightedEntry.new()
	entry.value = GFVariantData.duplicate_variant(value, deep, true)
	entry.weight = weight
	entry.metadata = metadata.duplicate(deep)
	return entry


## 导出为通用字典。
## [br]
## @api public
## [br]
## @return 包含 `value`、`weight` 与 `metadata` 的字典。
## [br]
## @schema return: Dictionary serialized weighted entry.
func to_dict() -> Dictionary:
	return {
		"value": value,
		"weight": weight,
		"metadata": metadata.duplicate(true),
	}


## 从通用字典创建条目。
## [br]
## @api public
## [br]
## @param data: 包含 `value`、`weight` 与 `metadata` 的字典。
## [br]
## @schema data: Dictionary serialized weighted entry.
## [br]
## @return 新条目实例。
static func from_dict(data: Dictionary) -> GFWeightedEntry:
	var entry: GFWeightedEntry = GFWeightedEntry.new()
	entry.value = GFVariantData.get_option_value(data, "value")
	entry.weight = GFVariantData.get_option_float(data, "weight", 1.0)
	var raw_metadata: Variant = GFVariantData.get_option_value(data, "metadata", {})
	entry.metadata = GFVariantData.as_dictionary(raw_metadata)
	return entry


# --- 私有/辅助方法 ---

static func _normalize_weight(raw_weight: float) -> float:
	if is_nan(raw_weight) or is_inf(raw_weight):
		push_error("[GFWeightedEntry] weight 必须是有限数字，已重置为 0。")
		return 0.0
	return raw_weight
