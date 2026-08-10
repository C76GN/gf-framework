## GFProjectileCatalog: 发射体场景目录。
##
## 用唯一稳定 ID 管理 PackedScene，供发射器、技能或项目自己的生成流程复用。
## 重复导出 ID 读取时以首个有效条目为准，写入与移除会规范化重复项。
## 目录不规定发射体的伤害、阵营、消耗或命中特效。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFProjectileCatalog
extends Resource


# --- 常量 ---

const _GF_PROJECTILE_CATALOG_ENTRY_SCRIPT = preload("res://addons/gf/extensions/combat/projectiles/gf_projectile_catalog_entry.gd")


# --- 导出变量 ---

## 发射体场景条目列表。
## [br]
## @api public
@export var entries: Array[GFProjectileCatalogEntry] = []


# --- 公共方法 ---

## 设置或替换一个发射体场景。
## [br]
## @api public
## [br]
## @param projectile_id: 发射体 ID。
## [br]
## @param scene: 发射体场景；为 null 时移除该 ID。
func set_scene(projectile_id: StringName, scene: PackedScene) -> void:
	if projectile_id == &"":
		return
	if scene == null:
		var _remove_scene_result_41: Variant = remove_scene(projectile_id)
		return

	var entry: GFProjectileCatalogEntry = _get_entry(projectile_id)
	if entry == null:
		entry = GFProjectileCatalogEntry.new()
		entry.projectile_id = projectile_id
		entries.append(entry)
	entry.scene = scene
	_remove_duplicate_entries(projectile_id, entries.find(entry))


## 获取指定 ID 的发射体场景。
## [br]
## @api public
## [br]
## @param projectile_id: 发射体 ID。
## [br]
## @return 找到时返回 PackedScene，否则返回 null。
func get_scene(projectile_id: StringName) -> PackedScene:
	var entry: GFProjectileCatalogEntry = _get_entry(projectile_id)
	if entry == null:
		return null
	return entry.scene


## 移除指定 ID 的发射体场景。
## [br]
## @api public
## [br]
## @param projectile_id: 发射体 ID。
## [br]
## @return 移除成功返回 true。
func remove_scene(projectile_id: StringName) -> bool:
	var removed: bool = false
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: GFProjectileCatalogEntry = entries[index]
		if entry != null and entry.projectile_id == projectile_id:
			entries.remove_at(index)
			removed = true
	return removed


## 检查指定 ID 是否存在有效场景。
## [br]
## @api public
## [br]
## @param projectile_id: 发射体 ID。
## [br]
## @return 存在有效场景时返回 true。
func has_scene(projectile_id: StringName) -> bool:
	return get_scene(projectile_id) != null


## 获取所有有效发射体 ID。
## [br]
## @api public
## [br]
## @return 按字典序排序的 ID 数组。
func get_projectile_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var seen_ids: Dictionary = {}
	for entry: GFProjectileCatalogEntry in entries:
		if entry == null or not entry.is_valid_entry() or seen_ids.has(entry.projectile_id):
			continue
		seen_ids[entry.projectile_id] = true
		var _append_result_102: Variant = ids.append(String(entry.projectile_id))
	ids.sort()
	return ids


## 清理空条目、空 ID 或空场景。
## [br]
## @api public
## [br]
## @return 被清理的条目数量。
func prune_invalid_entries() -> int:
	var removed_count: int = 0
	var seen_ids: Dictionary = {}
	var index: int = 0
	while index < entries.size():
		var entry: GFProjectileCatalogEntry = entries[index]
		if (
			entry == null
			or not entry.is_valid_entry()
			or seen_ids.has(entry.projectile_id)
		):
			entries.remove_at(index)
			removed_count += 1
			continue
		seen_ids[entry.projectile_id] = true
		index += 1
	return removed_count


# --- 私有/辅助方法 ---

func _get_entry(projectile_id: StringName) -> GFProjectileCatalogEntry:
	if projectile_id == &"":
		return null
	for entry: GFProjectileCatalogEntry in entries:
		if entry != null and entry.projectile_id == projectile_id:
			return entry
	return null


func _remove_duplicate_entries(projectile_id: StringName, keep_index: int) -> void:
	for index: int in range(entries.size() - 1, -1, -1):
		if index == keep_index:
			continue
		var entry: GFProjectileCatalogEntry = entries[index]
		if entry != null and entry.projectile_id == projectile_id:
			entries.remove_at(index)
