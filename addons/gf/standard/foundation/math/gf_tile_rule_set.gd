## GFTileRuleSet: 通用瓦片邻域规则表。
##
## 使用邻域值序列匹配结果，可用于自动铺砖、地形变体、网格装饰或任意
## 基于相邻格子状态的选择逻辑。规则只处理 Variant 值，不绑定 TileSet 语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTileRuleSet
extends Resource


# --- 常量 ---

const _FNV_32_OFFSET: int = 2_166_136_261
const _FNV_32_PRIME: int = 16_777_619
const _UINT_32_MASK: int = 0xffffffff


# --- 导出变量 ---

## 规则匹配失败时尝试使用的邻域回退值。
## [br]
## @api public
## [br]
## @schema fallback_neighbor_value: Variant fallback neighbor value used while resolving rules.
@export var fallback_neighbor_value: Variant = 0

## 没有匹配规则时返回的值。
## [br]
## @api public
## [br]
## @schema default_result: Variant fallback result returned when no rule matches.
@export var default_result: Variant = null

## 参与确定性加权选择的默认种子。
## [br]
## @api public
@export var deterministic_seed: int = 0


# --- 私有变量 ---

var _rules: Dictionary = {
	"branches": {},
	"results": [],
}
var _rule_count: int = 0


# --- 公共方法 ---

## 注册一条邻域规则。
## [br]
## @api public
## [br]
## @param neighbor_values: 邻域值序列。
## [br]
## @schema neighbor_values: Array ordered neighbor values used as a rule key.
## [br]
## @param result: 匹配结果。
## [br]
## @schema result: Variant result returned when the rule matches.
## [br]
## @param weight: 同一邻域下多个结果的权重。
func register_rule(neighbor_values: Array, result: Variant, weight: float = 1.0) -> void:
	if neighbor_values.is_empty():
		return

	var node: Dictionary = _rules
	for value: Variant in neighbor_values:
		var branches: Dictionary = _get_branches(node)
		if not branches.has(value):
			branches[value] = _make_node()
		node = GFVariantData.as_dictionary(GFVariantData.get_option_value(branches, value))

	var results: Array = _get_results(node)
	results.append({
		"value": result,
		"weight": maxf(weight, 0.0),
	})
	_rule_count += 1


## 清空全部规则。
## [br]
## @api public
func clear() -> void:
	_rules = _make_node()
	_rule_count = 0


## 获取已注册规则数量。
## [br]
## @api public
## [br]
## @return 规则数量。
func get_rule_count() -> int:
	return _rule_count


## 根据邻域值解析结果。
## [br]
## @api public
## [br]
## @param neighbor_values: 邻域值序列。
## [br]
## @schema neighbor_values: Array ordered neighbor values used as a rule key.
## [br]
## @param cell: 可选格坐标，用于确定性加权选择。
## [br]
## @param selection_seed: 可选选择种子；为 0 时使用 deterministic_seed。
## [br]
## @return 匹配结果；没有匹配时返回 default_result。
## [br]
## @schema return: Variant matched result or default_result.
func resolve(neighbor_values: Array, cell: Vector2i = Vector2i.ZERO, selection_seed: int = 0) -> Variant:
	if neighbor_values.is_empty():
		return default_result

	var node: Dictionary = _rules
	for value: Variant in neighbor_values:
		var branches: Dictionary = _get_branches(node)
		if not branches.has(value):
			value = fallback_neighbor_value
		if not branches.has(value):
			return default_result
		node = GFVariantData.as_dictionary(GFVariantData.get_option_value(branches, value))

	var results: Array = _get_results(node)
	if results.is_empty():
		return default_result
	return _pick_result(results, cell, selection_seed)


## 检查邻域值是否存在明确规则。
## [br]
## @api public
## [br]
## @param neighbor_values: 邻域值序列。
## [br]
## @schema neighbor_values: Array ordered neighbor values used as a rule key.
## [br]
## @return 存在规则时返回 true。
func has_rule(neighbor_values: Array) -> bool:
	var node: Dictionary = _rules
	for value: Variant in neighbor_values:
		var branches: Dictionary = _get_branches(node)
		if not branches.has(value):
			return false
		node = GFVariantData.as_dictionary(GFVariantData.get_option_value(branches, value))
	return not _get_results(node).is_empty()


# --- 私有/辅助方法 ---

func _make_node() -> Dictionary:
	return {
		"branches": {},
		"results": [],
	}


func _get_branches(node: Dictionary) -> Dictionary:
	var branches_value: Variant = GFVariantData.get_option_value(node, "branches")
	if branches_value is Dictionary:
		return GFVariantData.as_dictionary(branches_value)
	var branches: Dictionary = {}
	node["branches"] = branches
	return branches


func _get_results(node: Dictionary) -> Array:
	var results_value: Variant = GFVariantData.get_option_value(node, "results")
	if results_value is Array:
		return GFVariantData.as_array(results_value)
	var results: Array = []
	node["results"] = results
	return results


func _pick_result(results: Array, cell: Vector2i, selection_seed: int) -> Variant:
	if results.size() == 1:
		return _read_result_value(results, 0)

	var total_weight: float = 0.0
	for result_variant: Variant in results:
		total_weight += _get_result_weight(result_variant)
	if total_weight <= 0.0:
		return _read_result_value(results, 0)

	var effective_seed: int = deterministic_seed if selection_seed == 0 else selection_seed
	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(
		_stable_seed_for_choice(cell, effective_seed, results.size())
	)
	var target: float = rng.next_float_range(0.0, total_weight)
	var cursor: float = 0.0
	for result_variant: Variant in results:
		cursor += _get_result_weight(result_variant)
		if target <= cursor:
			return _read_result_entry_value(result_variant)
	return _read_result_value(results, results.size() - 1)


func _read_result_value(results: Array, index: int) -> Variant:
	if index < 0 or index >= results.size():
		return default_result
	return _read_result_entry_value(results[index])


func _read_result_entry_value(result_entry: Variant) -> Variant:
	var data: Dictionary = GFVariantData.as_dictionary(result_entry)
	return GFVariantData.get_option_value(data, "value")


func _get_result_weight(result_entry: Variant) -> float:
	var data: Dictionary = GFVariantData.as_dictionary(result_entry)
	return GFVariantData.get_option_float(data, "weight", 0.0)


func _stable_seed_for_choice(cell: Vector2i, selection_seed: int, result_count: int) -> int:
	var hash_value: int = _FNV_32_OFFSET
	var bytes: PackedByteArray = ("%d:%d:%d:%d" % [
		cell.x,
		cell.y,
		selection_seed,
		result_count,
	]).to_utf8_buffer()
	for value: int in bytes:
		hash_value = ((hash_value ^ value) * _FNV_32_PRIME) & _UINT_32_MASK
	return hash_value
