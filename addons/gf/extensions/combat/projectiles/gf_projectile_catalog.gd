## GFProjectileCatalog: typed projectile definition 目录。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFProjectileCatalog
extends Resource


# --- 导出变量 ---

## 目录条目；重复或无效条目不会参与查找结果。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema entries: Array[GFProjectileCatalogEntry]，每个有效 projectile_id 只保留首个定义。
@export var entries: Array[GFProjectileCatalogEntry] = []


# --- 公共方法 ---

## 设置或替换一个 typed definition。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param projectile_id: 非空稳定 ID。
## [br]
## @param definition: typed definition；null 等价于移除。
func set_definition(
	projectile_id: StringName,
	definition: GFProjectileDefinition
) -> void:
	if projectile_id == &"":
		return
	if definition == null:
		var _removed: bool = remove_definition(projectile_id)
		return
	var entry: GFProjectileCatalogEntry = _get_entry(projectile_id)
	if entry == null:
		entry = GFProjectileCatalogEntry.new()
		entry.projectile_id = projectile_id
		entries.append(entry)
	entry.definition = definition
	_remove_duplicates(projectile_id, entries.find(entry))


## 查找指定 ID 的 typed definition。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param projectile_id: 稳定 ID。
## [br]
## @return: definition；不存在时返回 null。
func get_definition(projectile_id: StringName) -> GFProjectileDefinition:
	var entry: GFProjectileCatalogEntry = _get_entry(projectile_id)
	return entry.definition if entry != null else null


## 判断指定 ID 是否有有效 definition。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param projectile_id: 稳定 ID。
## [br]
## @return: 是否存在有效 definition。
func has_definition(projectile_id: StringName) -> bool:
	return get_definition(projectile_id) != null


## 移除指定 ID 的所有重复条目。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param projectile_id: 稳定 ID。
## [br]
## @return: 是否至少移除一个条目。
func remove_definition(projectile_id: StringName) -> bool:
	var removed: bool = false
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: GFProjectileCatalogEntry = entries[index]
		if entry != null and entry.projectile_id == projectile_id:
			entries.remove_at(index)
			removed = true
	return removed


## 返回已排序且去重的有效 projectile ID。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 字典序排序的 ID 快照。
func get_projectile_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for entry: GFProjectileCatalogEntry in entries:
		if entry == null or not entry.is_valid_entry() or seen.has(entry.projectile_id):
			continue
		seen[entry.projectile_id] = true
		var _appended: bool = result.append(String(entry.projectile_id))
	result.sort()
	return result


## 清理 null、无效和重复条目。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 被移除的条目数量。
func prune_invalid_entries() -> int:
	var before_size: int = entries.size()
	var seen: Dictionary = {}
	var retained: Array[GFProjectileCatalogEntry] = []
	for entry: GFProjectileCatalogEntry in entries:
		if entry == null or not entry.is_valid_entry() or seen.has(entry.projectile_id):
			continue
		seen[entry.projectile_id] = true
		retained.append(entry)
	entries = retained
	return before_size - entries.size()


# --- 私有/辅助方法 ---

func _get_entry(projectile_id: StringName) -> GFProjectileCatalogEntry:
	if projectile_id == &"":
		return null
	for entry: GFProjectileCatalogEntry in entries:
		if (
			entry != null
			and entry.projectile_id == projectile_id
			and entry.is_valid_entry()
		):
			return entry
	return null


func _remove_duplicates(projectile_id: StringName, keep_index: int) -> void:
	for index: int in range(entries.size() - 1, -1, -1):
		if index == keep_index:
			continue
		var entry: GFProjectileCatalogEntry = entries[index]
		if entry != null and entry.projectile_id == projectile_id:
			entries.remove_at(index)
