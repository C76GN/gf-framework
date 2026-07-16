## GFTraitSet: 通用特征集合。
##
## 可从任意来源收集 `GFTrait`，再按目标键与分类计算最终数值。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFTraitSet
extends Resource


# --- 导出变量 ---

## 特征列表。
## [br]
## @api public
## [br]
## @schema traits: Array[GFTrait]，按 priority 排序保存的特征资源列表。
@export var traits: Array[GFTrait] = []


# --- 公共方法 ---

## 添加一个特征。
## [br]
## @api public
## [br]
## @param p_trait: 特征资源。
func add_trait(p_trait: GFTrait) -> void:
	if p_trait == null:
		return
	traits.append(p_trait)
	_sort_traits()


## 按 ID 移除特征。
## [br]
## @api public
## [br]
## @param trait_id: 特征 ID。
func remove_traits_by_id(trait_id: StringName) -> void:
	for index: int in range(traits.size() - 1, -1, -1):
		var current_trait: GFTrait = traits[index]
		if current_trait != null and current_trait.trait_id == trait_id:
			traits.remove_at(index)


## 查询匹配的特征。
## [br]
## @api public
## [br]
## @param target_id: 目标键。
## [br]
## @param category: 可选分类；为空时不按分类过滤。
## [br]
## @return 匹配特征数组。
## [br]
## @schema return: Array[GFTrait]，匹配目标键和分类过滤条件的特征资源。
func get_traits(target_id: StringName, category: StringName = &"") -> Array[GFTrait]:
	var result: Array[GFTrait] = []
	for current_trait: GFTrait in traits:
		if current_trait == null:
			continue
		if current_trait.target_id != target_id:
			continue
		if category != &"" and current_trait.category != category:
			continue
		result.append(current_trait)
	return result


## 计算目标键的最终数值。
## [br]
## @api public
## [br]
## @param target_id: 目标键。
## [br]
## @param base_value: 基础值。
## [br]
## @param category: 可选分类。
## [br]
## @return 合并后的数值。
func calculate_number(target_id: StringName, base_value: float, category: StringName = &"") -> float:
	var result: float = base_value
	for current_trait: GFTrait in get_traits(target_id, category):
		result = current_trait.apply_number(result)
	return result


## 清空特征。
## [br]
## @api public
func clear() -> void:
	traits.clear()


# --- 私有/辅助方法 ---

func _sort_traits() -> void:
	for index: int in range(traits.size() - 1, -1, -1):
		if traits[index] == null:
			traits.remove_at(index)
	traits.sort_custom(func(a: GFTrait, b: GFTrait) -> bool:
		return a.priority < b.priority
	)
