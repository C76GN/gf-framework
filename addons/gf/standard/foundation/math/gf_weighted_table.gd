## GFWeightedTable: 通用权重选择表。
##
## 适合需要“按权重从候选集合中选择值”的纯算法场景。
## 该类只处理权重和随机源，不绑定掉落、奖励、AI 等业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFWeightedTable
extends Resource


# --- 导出变量 ---

## 候选条目列表。
## [br]
## @api public
@export var entries: Array[GFWeightedEntry] = []

## 没有可选条目时返回的默认值。
## [br]
## @api public
## [br]
## @schema default_value: Variant fallback value returned when no entry can be selected.
@export var default_value: Variant = null

## 可选 GF 固定随机源后备种子；为 0 时使用随机化 Godot RNG。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var deterministic_seed: int = 0


# --- 公共方法 ---

## 追加一个候选条目。
## [br]
## @api public
## [br]
## @param value: 被选择后返回的值。
## [br]
## @schema value: Variant selected value owned by project code.
## [br]
## @param weight: 权重；小于等于 0 的条目会保留但不会被选择。
## [br]
## @param metadata: 可选元数据。
## [br]
## @schema metadata: Dictionary extension metadata for the new weighted entry.
## [br]
## @return 新增的条目实例。
func add_entry(value: Variant, weight: float = 1.0, metadata: Dictionary = {}) -> GFWeightedEntry:
	var entry: GFWeightedEntry = GFWeightedEntry.new().configure(value, weight, metadata)
	entries.append(entry)
	return entry


## 追加已有候选条目。
## [br]
## @api public
## [br]
## @param entry: 要追加的条目。
## [br]
## @return 添加成功时返回 true。
func add_weighted_entry(entry: GFWeightedEntry) -> bool:
	if entry == null:
		return false

	entries.append(entry)
	return true


## 移除候选条目。
## [br]
## @api public
## [br]
## @param entry: 要移除的条目。
## [br]
## @return 找到并移除时返回 true。
func remove_entry(entry: GFWeightedEntry) -> bool:
	var index: int = entries.find(entry)
	if index < 0:
		return false

	entries.remove_at(index)
	return true


## 清空候选条目。
## [br]
## @api public
func clear() -> void:
	entries.clear()


## 获取当前可被选择的条目。
## [br]
## @api public
## [br]
## @return 权重大于 0 的条目数组。
func get_selectable_entries() -> Array[GFWeightedEntry]:
	var result: Array[GFWeightedEntry] = []
	for entry: GFWeightedEntry in entries:
		if entry != null and entry.is_selectable():
			result.append(entry)

	return result


## 计算当前总权重。
## [br]
## @api public
## [br]
## @return 所有可选条目的权重总和。
func get_total_weight() -> float:
	var total: float = 0.0
	for entry: GFWeightedEntry in entries:
		if entry != null and entry.is_selectable():
			total += entry.weight

	return total


## 判断当前是否没有可选条目。
## [br]
## @api public
## [br]
## @return 没有可选条目时返回 true。
func is_empty() -> bool:
	return get_total_weight() <= 0.0


## 按权重选择一个条目。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param rng: 可选随机源；支持 `RandomNumberGenerator` 或 `GFDeterministicRandom`。
## [br]
## @schema rng: RandomNumberGenerator or GFDeterministicRandom. Null uses deterministic_seed fallback or a randomized Godot RNG.
## [br]
## @return 选中的条目；没有可选条目时返回 null。
func pick_entry(rng: Variant = null) -> GFWeightedEntry:
	return _pick_entry_from(get_selectable_entries(), _resolve_rng(rng))


## 按权重选择一个值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param rng: 可选随机源；支持 `RandomNumberGenerator` 或 `GFDeterministicRandom`。
## [br]
## @schema rng: RandomNumberGenerator or GFDeterministicRandom. Null uses deterministic_seed fallback or a randomized Godot RNG.
## [br]
## @return 选中条目的 value；没有可选条目时返回 default_value。
## [br]
## @schema return: Variant selected value or default_value.
func pick_value(rng: Variant = null) -> Variant:
	var entry: GFWeightedEntry = pick_entry(rng)
	return entry.value if entry != null else default_value


## 按权重选择多个值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param count: 选择次数。
## [br]
## @param rng: 可选随机源；支持 `RandomNumberGenerator` 或 `GFDeterministicRandom`。
## [br]
## @schema rng: RandomNumberGenerator or GFDeterministicRandom. Null uses deterministic_seed fallback or a randomized Godot RNG.
## [br]
## @param allow_repeats: 是否允许同一条目被重复选择。
## [br]
## @return 选中的 value 数组。
## [br]
## @schema return: Array selected values.
func pick_many(
	count: int,
	rng: Variant = null,
	allow_repeats: bool = true
) -> Array[Variant]:
	var result: Array[Variant] = []
	if count <= 0:
		return result

	var active_rng: Variant = _resolve_rng(rng)
	var available: Array[GFWeightedEntry] = get_selectable_entries()
	if allow_repeats:
		for _index: int in range(count):
			var repeated_entry: GFWeightedEntry = _pick_entry_from(available, active_rng)
			if repeated_entry == null:
				break

			result.append(repeated_entry.value)
		return result

	for _index: int in range(count):
		var entry: GFWeightedEntry = _pick_entry_from(available, active_rng)
		if entry == null:
			break

		result.append(entry.value)
		available.erase(entry)

	return result


## 复制当前权重表。
## [br]
## @api public
## [br]
## @param deep: 是否深拷贝条目和元数据。
## [br]
## @return 新权重表实例。
func duplicate_table(deep: bool = true) -> GFWeightedTable:
	var table: GFWeightedTable = GFWeightedTable.new()
	table.default_value = GFVariantData.duplicate_variant(default_value, deep, true)
	table.deterministic_seed = deterministic_seed
	for entry: GFWeightedEntry in entries:
		table.entries.append(entry.duplicate_entry(deep) if entry != null and deep else entry)

	return table


## 导出为通用字典。
## [br]
## @api public
## [br]
## @return 包含条目、默认值和确定性种子的字典。
## [br]
## @schema return: Dictionary serialized weighted table.
func to_dict() -> Dictionary:
	var serialized_entries: Array[Dictionary] = []
	for entry: GFWeightedEntry in entries:
		if entry != null:
			serialized_entries.append(entry.to_dict())

	return {
		"entries": serialized_entries,
		"default_value": default_value,
		"deterministic_seed": deterministic_seed,
	}


## 使用通用字典覆盖当前权重表。
## [br]
## @api public
## [br]
## @param data: 包含 `entries`、`default_value` 与 `deterministic_seed` 的字典。
## [br]
## @schema data: Dictionary serialized weighted table.
func apply_dict(data: Dictionary) -> void:
	entries.clear()
	default_value = GFVariantData.get_option_value(data, "default_value")
	deterministic_seed = GFVariantData.get_option_int(data, "deterministic_seed")

	var raw_entries: Array = GFVariantData.get_option_array(data, "entries")
	for raw_entry: Variant in raw_entries:
		if raw_entry is Dictionary:
			entries.append(GFWeightedEntry.from_dict(GFVariantData.as_dictionary(raw_entry)))


## 从通用字典创建权重表。
## [br]
## @api public
## [br]
## @param data: 包含 `entries`、`default_value` 与 `deterministic_seed` 的字典。
## [br]
## @schema data: Dictionary serialized weighted table.
## [br]
## @return 新权重表实例。
static func from_dict(data: Dictionary) -> GFWeightedTable:
	var table: GFWeightedTable = GFWeightedTable.new()
	table.apply_dict(data)
	return table


# --- 私有/辅助方法 ---

func _pick_entry_from(source_entries: Array[GFWeightedEntry], rng: Variant) -> GFWeightedEntry:
	var total: float = 0.0
	for entry: GFWeightedEntry in source_entries:
		if entry != null and entry.is_selectable():
			total += entry.weight

	if total <= 0.0:
		return null

	var threshold: float = _random_float_range(rng, 0.0, total)
	var accumulated: float = 0.0
	var fallback: GFWeightedEntry = null
	for entry: GFWeightedEntry in source_entries:
		if entry == null or not entry.is_selectable():
			continue

		fallback = entry
		accumulated += entry.weight
		if threshold <= accumulated:
			return entry

	return fallback


func _resolve_rng(rng: Variant) -> Variant:
	if rng is RandomNumberGenerator or rng is GFDeterministicRandom:
		return rng

	if rng != null:
		push_error("[GFWeightedTable] rng 必须是 RandomNumberGenerator 或 GFDeterministicRandom。")

	if deterministic_seed != 0:
		return GFDeterministicRandom.from_seed(deterministic_seed)

	var fallback: RandomNumberGenerator = RandomNumberGenerator.new()
	fallback.randomize()
	return fallback


func _random_float_range(rng: Variant, min_value: float, max_value: float) -> float:
	if rng is GFDeterministicRandom:
		var deterministic_rng: GFDeterministicRandom = rng
		return deterministic_rng.next_float_range(min_value, max_value)
	if rng is RandomNumberGenerator:
		var godot_rng: RandomNumberGenerator = rng
		return godot_rng.randf_range(min_value, max_value)
	return min_value
