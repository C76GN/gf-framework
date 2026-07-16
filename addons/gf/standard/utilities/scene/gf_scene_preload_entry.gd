## GFScenePreloadEntry: 场景预加载图谱中的单个节点。
##
## 描述一个场景与相邻场景的关系，以及该场景是否应进入固定缓存。
## 它只表达资源关系，不假设关卡、地图、菜单或玩法语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFScenePreloadEntry
extends Resource


# --- 导出变量 ---

## 当前场景资源路径。
## [br]
## @api public
@export_file("*.tscn", "*.scn") var scene_path: String = ""

## 与当前场景相邻、可能被提前预热的场景资源路径。
## [br]
## @api public
@export var adjacent_scene_paths: PackedStringArray = PackedStringArray()

## 是否建议将该场景放入固定缓存。
## [br]
## @api public
@export var fixed: bool = false

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，会复制到 describe_entry() 结果中。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取规范化后的场景路径。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 规范化后的场景路径。
func get_scene_path() -> String:
	return _normalize_scene_path(scene_path)


## 获取去重后的相邻场景路径。
## [br]
## @api public
## [br]
## @return 相邻场景路径列表。
func get_adjacent_scene_paths() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var source_cache_key: String = get_cache_key()
	for raw_path: String in adjacent_scene_paths:
		var identity: GFResourceIdentity = _make_scene_identity(raw_path)
		var path: String = _get_identity_scene_path(identity)
		if path.is_empty() or identity.cache_key.is_empty() or identity.cache_key == source_cache_key:
			continue
		if _paths_have_cache_key(result, identity.cache_key):
			continue
		var _appended: bool = result.append(path)
	return result


## 描述当前条目。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 条目描述字典。
## [br]
## @schema return: Dictionary，包含 scene_path、cache_key、resource_identity、adjacent_scene_paths、fixed 和 metadata。
func describe_entry() -> Dictionary:
	var identity: GFResourceIdentity = get_resource_identity()
	return {
		"scene_path": get_scene_path(),
		"cache_key": identity.cache_key,
		"resource_identity": identity.to_dictionary(),
		"adjacent_scene_paths": get_adjacent_scene_paths(),
		"fixed": fixed,
		"metadata": metadata.duplicate(true),
	}


## 获取当前场景资源身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 资源身份对象。
func get_resource_identity() -> GFResourceIdentity:
	return _make_scene_identity(scene_path)


## 获取当前场景资源身份缓存键。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 资源身份 cache_key。
func get_cache_key() -> String:
	return get_resource_identity().cache_key


# --- 私有/辅助方法 ---

static func _normalize_scene_path(raw_path: String) -> String:
	var identity: GFResourceIdentity = _make_scene_identity(raw_path)
	return _get_identity_scene_path(identity)


static func _make_scene_identity(raw_path: String) -> GFResourceIdentity:
	return GFResourceIdentity.from_path(raw_path, &"", "PackedScene", { "check_exists": false })


static func _get_identity_scene_path(identity: GFResourceIdentity) -> String:
	if identity == null:
		return ""
	if not identity.canonical_path.is_empty():
		return identity.canonical_path
	return identity.raw_path


static func _paths_have_cache_key(paths: PackedStringArray, cache_key: String) -> bool:
	if cache_key.is_empty():
		return false
	for existing_path: String in paths:
		var existing_identity: GFResourceIdentity = _make_scene_identity(existing_path)
		if existing_identity.cache_key == cache_key:
			return true
	return false
