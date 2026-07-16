## GFScenePreloadMap: 通用场景预加载关系图。
##
## 用资源描述场景间的相邻关系，供 GFSceneUtility 或项目层根据当前场景计算预加载计划。
## 图谱只关注资源路径和缓存策略，不绑定地图、关卡、菜单或具体业务流。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFScenePreloadMap
extends Resource


# --- 导出变量 ---

## 默认相邻搜索半径；0 表示只使用固定预加载路径。
## [br]
## @api public
@export_range(0, 16, 1, "or_greater") var default_radius: int = 1:
	set(value):
		default_radius = maxi(value, 0)

## 单次计划最多返回的临时相邻场景数量；0 表示不限制。
## [br]
## @api public
@export_range(0, 256, 1, "or_greater") var max_scheduled_scenes: int = 0:
	set(value):
		max_scheduled_scenes = maxi(value, 0)

## 始终参与预加载计划的固定场景路径。
## [br]
## @api public
@export var fixed_scene_paths: PackedStringArray = PackedStringArray()

## 场景关系条目列表。
## [br]
## @api public
@export var entries: Array[GFScenePreloadEntry] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，会复制到预加载计划报告中。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取指定路径对应的条目。
## [br]
## @api public
## [br]
## @param scene_path: 场景资源路径。
## [br]
## @return 对应条目；未找到时返回 null。
func get_entry(scene_path: String) -> GFScenePreloadEntry:
	var source_cache_key: String = _get_scene_cache_key(scene_path)
	if source_cache_key.is_empty():
		return null

	for entry: GFScenePreloadEntry in entries:
		if entry != null and entry.get_cache_key() == source_cache_key:
			return entry
	return null


## 获取去重后的固定预加载路径。
## [br]
## @api public
## [br]
## @return 固定预加载路径列表。
func get_fixed_scene_paths() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for raw_path: String in fixed_scene_paths:
		_append_unique_path(result, raw_path)
	for entry: GFScenePreloadEntry in entries:
		if entry != null and entry.fixed:
			_append_unique_path(result, entry.get_scene_path())
	return result


## 获取指定场景周围的相邻场景路径。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param scene_path: 当前场景资源路径。
## [br]
## @param radius: 搜索半径；小于 0 时使用 default_radius。
## [br]
## @param include_source: 是否包含 scene_path 自身。
## [br]
## @return 相邻场景路径列表。
func get_neighbor_scene_paths(
	scene_path: String,
	radius: int = -1,
	include_source: bool = false
) -> PackedStringArray:
	var source_identity: GFResourceIdentity = _make_scene_identity(scene_path)
	var source_path: String = _get_identity_scene_path(source_identity)
	var source_cache_key: String = source_identity.cache_key
	var result: PackedStringArray = PackedStringArray()
	if source_path.is_empty() or source_cache_key.is_empty():
		return result

	var effective_radius: int = _get_effective_radius(radius)
	if include_source:
		_append_unique_path(result, source_path)
	if effective_radius <= 0:
		return result

	var visited: Dictionary = {
		source_cache_key: true,
	}
	var queue: Array[Dictionary] = [
		{
			"path": source_path,
			"cache_key": source_cache_key,
			"depth": 0,
		},
	]
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var current_path: String = GFVariantData.get_option_string(current, "path", "")
		var depth: int = GFVariantData.get_option_int(current, "depth", 0)
		if depth >= effective_radius:
			continue

		var entry: GFScenePreloadEntry = get_entry(current_path)
		if entry == null:
			continue
		for adjacent_path: String in entry.get_adjacent_scene_paths():
			var adjacent_cache_key: String = _get_scene_cache_key(adjacent_path)
			if adjacent_cache_key.is_empty() or visited.has(adjacent_cache_key):
				continue
			visited[adjacent_cache_key] = true
			_append_unique_path(result, adjacent_path)
			if _is_schedule_limit_reached(result):
				return result
			queue.append({
				"path": adjacent_path,
				"cache_key": adjacent_cache_key,
				"depth": depth + 1,
			})
	return result


## 获取指定场景的预加载计划。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param scene_path: 当前场景资源路径。
## [br]
## @param radius: 搜索半径；小于 0 时使用 default_radius。
## [br]
## @param include_fixed: 是否包含固定预加载路径。
## [br]
## @return 预加载计划字典。
## [br]
## @schema return: Dictionary，包含 source_path、source_cache_key、radius、include_fixed、fixed_paths、temporary_paths、paths、fixed_cache_keys、temporary_cache_keys、cache_keys、resource_identities 和 metadata。
func get_preload_plan(
	scene_path: String,
	radius: int = -1,
	include_fixed: bool = true
) -> Dictionary:
	var source_identity: GFResourceIdentity = _make_scene_identity(scene_path)
	var source_path: String = _get_identity_scene_path(source_identity)
	var effective_radius: int = _get_effective_radius(radius)
	var fixed_paths: PackedStringArray = PackedStringArray()
	if include_fixed:
		fixed_paths = get_fixed_scene_paths()

	var temporary_paths: PackedStringArray = PackedStringArray()
	for neighbor_path: String in get_neighbor_scene_paths(source_path, effective_radius):
		if _paths_have_cache_key(fixed_paths, _get_scene_cache_key(neighbor_path)):
			continue
		var entry: GFScenePreloadEntry = get_entry(neighbor_path)
		if entry != null and entry.fixed:
			_append_unique_path(fixed_paths, neighbor_path)
			continue
		_append_unique_path(temporary_paths, neighbor_path)

	var paths: PackedStringArray = PackedStringArray()
	for fixed_path: String in fixed_paths:
		_append_unique_path(paths, fixed_path)
	for temporary_path: String in temporary_paths:
		_append_unique_path(paths, temporary_path)

	return {
		"source_path": source_path,
		"source_cache_key": source_identity.cache_key,
		"radius": effective_radius,
		"include_fixed": include_fixed,
		"fixed_paths": fixed_paths,
		"temporary_paths": temporary_paths,
		"paths": paths,
		"fixed_cache_keys": _make_cache_key_list(fixed_paths),
		"temporary_cache_keys": _make_cache_key_list(temporary_paths),
		"cache_keys": _make_cache_key_list(paths),
		"resource_identities": _make_resource_identity_snapshot(paths),
		"metadata": metadata.duplicate(true),
	}


## 校验预加载图谱结构。
## [br]
## @api public
## [br]
## @param options: 可选参数，支持 check_exists。
## [br]
## @schema options: Dictionary，包含 check_exists: bool。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: Dictionary，由 GFValidationReport.to_dict() 生成的校验报告。
func validate_map(options: Dictionary = {}) -> Dictionary:
	var report: GFValidationReport = GFValidationReport.new("Scene preload map")
	var check_exists: bool = GFVariantData.get_option_bool(options, "check_exists")
	var seen_paths: Dictionary = {}
	for fixed_path: String in get_fixed_scene_paths():
		_validate_scene_path(report, fixed_path, "fixed_scene_paths", check_exists)

	for index: int in range(entries.size()):
		var entry: GFScenePreloadEntry = entries[index]
		if entry == null:
			var _add_warning_result_216: Variant = report.add_warning(&"null_entry", "Scene preload map contains a null entry.", str(index))
			continue

		var entry_path: String = entry.get_scene_path()
		var entry_cache_key: String = entry.get_cache_key()
		if entry_path.is_empty():
			var _add_error_result_221: Variant = report.add_error(&"empty_scene_path", "Scene preload entry requires scene_path.", str(index))
			continue
		_validate_scene_path(report, entry_path, str(index), check_exists)
		if seen_paths.has(entry_cache_key):
			var _add_warning_result_225: Variant = report.add_warning(&"duplicate_scene_path", "Scene preload map contains duplicate scene_path entries.", entry_path)
		seen_paths[entry_cache_key] = true

		for adjacent_path: String in entry.adjacent_scene_paths:
			var adjacent_identity: GFResourceIdentity = _make_scene_identity(adjacent_path)
			var normalized_adjacent_path: String = _get_identity_scene_path(adjacent_identity)
			if normalized_adjacent_path.is_empty():
				var _add_warning_result_231: Variant = report.add_warning(&"empty_adjacent_path", "Scene preload entry contains an empty adjacent path.", entry_path)
				continue
			if adjacent_identity.cache_key == entry_cache_key:
				var _add_warning_result_234: Variant = report.add_warning(&"self_adjacent_path", "Scene preload entry references itself.", entry_path)
				continue
			_validate_scene_path(report, normalized_adjacent_path, entry_path, check_exists)

	return report.to_dict(
		{
			"entry_count": entries.size(),
			"fixed_count": get_fixed_scene_paths().size(),
		},
		{
			"include_subject": false,
			"include_metadata": false,
			"include_info_count": false,
			"include_issue_count": false,
			"next_actions": _get_next_actions(),
			"fallback_action": "Review the first reported scene preload map issue before using it.",
		}
	)


# --- 私有/辅助方法 ---

func _get_effective_radius(radius: int) -> int:
	return maxi(default_radius if radius < 0 else radius, 0)


func _is_schedule_limit_reached(paths: PackedStringArray) -> bool:
	return max_scheduled_scenes > 0 and paths.size() >= max_scheduled_scenes


func _validate_scene_path(
	report: GFValidationReport,
	scene_path: String,
	key: Variant,
	check_exists: bool
) -> void:
	if scene_path.is_empty():
		var _add_error_result_271: Variant = report.add_error(&"empty_scene_path", "Scene path is empty.", key)
		return
	if not check_exists:
		return
	if not ResourceLoader.exists(scene_path):
		var _add_warning_result_276: Variant = report.add_warning(&"missing_scene_resource", "Scene resource does not exist.", key, scene_path)


func _get_next_actions() -> Dictionary:
	return {
		"null_entry": "Remove the null entry or assign a GFScenePreloadEntry resource.",
		"empty_scene_path": "Set a valid scene_path on every GFScenePreloadEntry.",
		"duplicate_scene_path": "Merge duplicate scene preload entries for the same scene_path.",
		"empty_adjacent_path": "Remove empty adjacent_scene_paths values.",
		"self_adjacent_path": "Remove self-references from adjacent_scene_paths.",
		"missing_scene_resource": "Fix the missing scene resource path or remove it from the preload map.",
	}


static func _append_unique_path(paths: PackedStringArray, raw_path: String) -> void:
	var identity: GFResourceIdentity = _make_scene_identity(raw_path)
	var path: String = _get_identity_scene_path(identity)
	if path.is_empty() or identity.cache_key.is_empty() or _paths_have_cache_key(paths, identity.cache_key):
		return
	var _appended: bool = paths.append(path)


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


static func _get_scene_cache_key(raw_path: String) -> String:
	return _make_scene_identity(raw_path).cache_key


static func _paths_have_cache_key(paths: PackedStringArray, cache_key: String) -> bool:
	if cache_key.is_empty():
		return false
	for existing_path: String in paths:
		if _get_scene_cache_key(existing_path) == cache_key:
			return true
	return false


static func _make_cache_key_list(paths: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var cache_key: String = _get_scene_cache_key(path)
		if cache_key.is_empty() or result.has(cache_key):
			continue
		var _appended: bool = result.append(cache_key)
	return result


static func _make_resource_identity_snapshot(paths: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for path: String in paths:
		var identity: GFResourceIdentity = _make_scene_identity(path)
		if identity.cache_key.is_empty():
			continue
		result[identity.cache_key] = identity.to_dictionary()
	return result
