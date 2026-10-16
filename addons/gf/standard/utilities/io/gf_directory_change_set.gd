## GFDirectoryChangeSet: 目录扫描差异结果。
##
## 描述一次目录轮询发现的新增、修改和删除路径。它只表达文件系统变化，
## 不绑定导入、热更新或业务资源刷新策略。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.23.0
class_name GFDirectoryChangeSet
extends RefCounted


# --- 公共变量 ---

## 本次扫描覆盖的根目录。
## [br]
## @api public
var root_paths: PackedStringArray = PackedStringArray()

## 新增文件路径。
## [br]
## @api public
var created: PackedStringArray = PackedStringArray()

## 修改文件路径。
## [br]
## @api public
var modified: PackedStringArray = PackedStringArray()

## 删除文件路径。
## [br]
## @api public
var deleted: PackedStringArray = PackedStringArray()

## 本次扫描访问的文件数量。
## [br]
## @api public
var scanned_count: int = 0

## 当前快照中的文件数量。
## [br]
## @api public
var snapshot_size: int = 0

## 扫描是否因深度或数量限制被截断。
## [br]
## @api public
var truncated: bool = false

## 生成时间，单位为毫秒。
## [br]
## @api public
var timestamp_msec: int = 0


# --- 公共方法 ---

## 配置变化集并返回自身。
## [br]
## @api public
## [br]
## @param p_root_paths: 扫描根目录。
## [br]
## @param p_created: 新增路径。
## [br]
## @param p_modified: 修改路径。
## [br]
## @param p_deleted: 删除路径。
## [br]
## @param p_scanned_count: 扫描文件数量。
## [br]
## @param p_snapshot_size: 当前快照文件数量。
## [br]
## @param p_truncated: 是否被截断。
## [br]
## @return 当前变化集。
func configure(
	p_root_paths: PackedStringArray,
	p_created: PackedStringArray,
	p_modified: PackedStringArray,
	p_deleted: PackedStringArray,
	p_scanned_count: int,
	p_snapshot_size: int,
	p_truncated: bool
) -> GFDirectoryChangeSet:
	root_paths = p_root_paths.duplicate()
	created = p_created.duplicate()
	modified = p_modified.duplicate()
	deleted = p_deleted.duplicate()
	scanned_count = p_scanned_count
	snapshot_size = p_snapshot_size
	truncated = p_truncated
	timestamp_msec = Time.get_ticks_msec()
	return self


## 判断本次扫描是否没有任何文件变化。
## [br]
## @api public
## [br]
## @return 没有新增、修改和删除路径时返回 true。
func is_empty() -> bool:
	return (
		created.is_empty()
		and modified.is_empty()
		and deleted.is_empty()
	)


## 获取全部变化路径。
## [br]
## @api public
## [br]
## @return 去重并排序后的变化路径。
func get_all_changed_paths() -> PackedStringArray:
	var lookup: Dictionary = {}
	for path: String in created:
		lookup[path] = true
	for path: String in modified:
		lookup[path] = true
	for path: String in deleted:
		lookup[path] = true

	var result: PackedStringArray = PackedStringArray()
	for path: String in lookup.keys():
		var _appended: bool = result.append(path)
	result.sort()
	return result


## 转换为字典。
## [br]
## @api public
## [br]
## @return 变化集字典。
## [br]
## @schema return: Dictionary with root_paths, created, modified, deleted, counts, truncated, and timestamp_msec.
func to_dict() -> Dictionary:
	return {
		"root_paths": root_paths,
		"created": created,
		"modified": modified,
		"deleted": deleted,
		"changed": get_all_changed_paths(),
		"created_count": created.size(),
		"modified_count": modified.size(),
		"deleted_count": deleted.size(),
		"changed_count": get_all_changed_paths().size(),
		"scanned_count": scanned_count,
		"snapshot_size": snapshot_size,
		"truncated": truncated,
		"timestamp_msec": timestamp_msec,
	}


## 创建变化集副本。
## [br]
## @api public
## [br]
## @return 新变化集。
func duplicate_change_set() -> GFDirectoryChangeSet:
	return (
		GFDirectoryChangeSet.new().configure(
			root_paths,
			created,
			modified,
			deleted,
			scanned_count,
			snapshot_size,
			truncated
		)
	)
