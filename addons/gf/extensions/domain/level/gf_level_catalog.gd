## GFLevelCatalog: 通用关卡目录资源。
##
## 用于按关卡包和排序值组织 GFLevelEntry，保持目录查询与具体关卡规则解耦。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFLevelCatalog
extends Resource


# --- 导出变量 ---

## 关卡条目列表。
## [br]
## @api public
## [br]
## @schema entries: Array[GFLevelEntry]，关卡目录条目列表；查询方法会返回条目拷贝。
@export var entries: Array[GFLevelEntry] = []


# --- 公共方法 ---

## 添加关卡条目。
## [br]
## @api public
## [br]
## @param entry: 关卡条目。
func add_entry(entry: GFLevelEntry) -> void:
	if entry == null:
		return

	var level_id: StringName = entry.get_level_id()
	if level_id == &"":
		push_error("[GFLevelCatalog] add_entry 失败：关卡 ID 为空。")
		return

	for index: int in range(entries.size()):
		if entries[index] != null and entries[index].get_level_id() == level_id:
			entries[index] = entry
			return
	entries.append(entry)


## 检查关卡是否存在。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
## [br]
## @return: 存在时返回 true。
func has_level(level_id: StringName) -> bool:
	return get_entry(level_id) != null


## 获取关卡条目。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
## [br]
## @return: 条目拷贝；不存在时返回 null。
func get_entry(level_id: StringName) -> GFLevelEntry:
	for entry: GFLevelEntry in entries:
		if entry != null and entry.get_level_id() == level_id:
			return entry.duplicate_entry()
	return null


## 获取指定关卡扩展中的条目。
## [br]
## @api public
## [br]
## @param pack_id: 关卡扩展 ID；为空时返回全部。
## [br]
## @return: 已排序的条目拷贝数组。
## [br]
## @schema return: Array[GFLevelEntry]，按 sort_order 与 level_id 排序后的关卡条目拷贝。
func get_levels(pack_id: StringName = &"") -> Array[GFLevelEntry]:
	var result: Array[GFLevelEntry] = []
	for entry: GFLevelEntry in entries:
		if entry == null:
			continue
		if pack_id != &"" and entry.pack_id != pack_id:
			continue
		result.append(entry.duplicate_entry())

	result.sort_custom(_sort_entries)
	return result


## 获取所有关卡扩展 ID。
## [br]
## @api public
## [br]
## @return: 关卡扩展 ID 数组。
## [br]
## @schema return: Array[StringName]，已排序的关卡包或章节 ID 列表。
func get_pack_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: GFLevelEntry in entries:
		if entry == null:
			continue
		if not result.has(entry.pack_id):
			result.append(entry.pack_id)
	result.sort()
	return result


## 获取同关卡扩展内下一个关卡 ID。
## [br]
## @api public
## [br]
## @param level_id: 当前关卡 ID。
## [br]
## @return: 后续关卡 ID；没有时返回空 StringName。
func get_next_level_id(level_id: StringName) -> StringName:
	var entry: GFLevelEntry = get_entry(level_id)
	if entry == null:
		return &""

	var levels: Array[GFLevelEntry] = _get_exact_pack_levels(entry.pack_id)
	for index: int in range(levels.size()):
		if levels[index].get_level_id() == level_id and index + 1 < levels.size():
			return levels[index + 1].get_level_id()
	return &""


## 获取同关卡扩展内上一个关卡 ID。
## [br]
## @api public
## [br]
## @param level_id: 当前关卡 ID。
## [br]
## @return: 前序关卡 ID；没有时返回空 StringName。
func get_previous_level_id(level_id: StringName) -> StringName:
	var entry: GFLevelEntry = get_entry(level_id)
	if entry == null:
		return &""

	var levels: Array[GFLevelEntry] = _get_exact_pack_levels(entry.pack_id)
	for index: int in range(levels.size()):
		if levels[index].get_level_id() == level_id and index > 0:
			return levels[index - 1].get_level_id()
	return &""


# --- 私有/辅助方法 ---

func _get_exact_pack_levels(pack_id: StringName) -> Array[GFLevelEntry]:
	var result: Array[GFLevelEntry] = []
	for entry: GFLevelEntry in get_levels():
		if entry.pack_id == pack_id:
			result.append(entry)
	return result

func _sort_entries(left: GFLevelEntry, right: GFLevelEntry) -> bool:
	if left.sort_order != right.sort_order:
		return left.sort_order < right.sort_order
	return String(left.get_level_id()) < String(right.get_level_id())
