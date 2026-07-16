@tool

## GFEditorTypeIndex: 编辑器侧 GF 类型查询工具。
##
## 集中扫描 class_name 脚本与能力场景，供代码生成器和 Inspector 工具复用。
## 默认实例只使用短生命周期缓存；需要监听 EditorFileSystem 变更时必须显式绑定 owner 启用 live 失效。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorTypeIndex
extends RefCounted


# --- 常量 ---

## 默认最大扫描深度。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大扫描场景数。
## [br]
## @api public
const DEFAULT_MAX_SCANNED_SCENES: int = 10000
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _script_cache: Dictionary = {}
var _scene_root_script_cache: Dictionary = {}
var _live_invalidation_tokens: Array[GFLifetimeSubscription] = []
var _live_invalidation_owner_ref: WeakRef = null


# --- 公共方法 ---

## 收集继承指定脚本基类的全局脚本类。
## [br]
## @api public
## [br]
## @param base_script: 要匹配的基类脚本。
## [br]
## @param excluded_scripts: 收集类型时需要排除的脚本列表。
## [br]
## @return 匹配脚本记录列表。
## [br]
## @schema return: Array of Dictionary script records with class_name, path, and script.
func collect_scripts_extending(base_script: Script, excluded_scripts: Array[Script] = []) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if base_script == null:
		return records

	var used_paths: Dictionary = {}
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		var class_name_value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(global_class, "class")
		var path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(global_class, "path")
		if class_name_value.is_empty() or path.is_empty() or used_paths.has(path):
			continue

		var script: Script = _load_script(path)
		if script == null or excluded_scripts.has(script):
			continue
		if not _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(script, base_script):
			continue

		used_paths[path] = true
		records.append({
			"class_name": class_name_value,
			"path": path,
			"script": script,
		})

	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "class_name")
			< _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "class_name")
		)
	)
	return records


## 收集根脚本继承指定基类的场景。
## [br]
## @api public
## [br]
## @param base_script: 要匹配的基类脚本。
## [br]
## @param used_paths: 已使用的资源路径集合。
## [br]
## @schema used_paths: Dictionary keyed by already consumed resource path.
## [br]
## @param root_paths: 可选扫描根路径；为空时扫描整个资源树。
## [br]
## @param options: 可选参数，支持 max_scan_depth 与 max_scanned_scenes。
## [br]
## @schema options: Dictionary with optional max_scan_depth and max_scanned_scenes.
## [br]
## @return 匹配场景记录列表。
## [br]
## @schema return: Array of Dictionary scene root records with path, root_script, and class metadata.
func collect_scene_roots_extending(
	base_script: Script,
	used_paths: Dictionary = {},
	root_paths: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if base_script == null or not Engine.is_editor_hint():
		return records

	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return records

	var root_dir: EditorFileSystemDirectory = filesystem.get_filesystem()
	if root_dir == null:
		return records

	var max_scan_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_scanned_scenes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scanned_scenes", DEFAULT_MAX_SCANNED_SCENES), 0)
	var scan_state: Dictionary = _make_scene_scan_state()
	var dir_stack: Array[Dictionary] = [{
		"directory": root_dir,
		"depth": 0,
	}]
	while not dir_stack.is_empty():
		var stack_entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(dir_stack.pop_back())
		var current_dir: EditorFileSystemDirectory = _variant_to_editor_directory(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(stack_entry, "directory"))
		var current_depth: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(stack_entry, "depth", 0)
		if current_dir == null:
			continue

		for i: int in range(current_dir.get_subdir_count()):
			var subdir: EditorFileSystemDirectory = current_dir.get_subdir(i)
			if _can_scan_deeper(subdir.get_path(), current_depth, max_scan_depth, scan_state):
				dir_stack.append({
					"directory": subdir,
					"depth": current_depth + 1,
				})

		for i: int in range(current_dir.get_file_count()):
			if current_dir.get_file_type(i) != "PackedScene":
				continue
			var path: String = _join_resource_path(current_dir.get_path(), current_dir.get_file(i))
			if used_paths.has(path):
				continue
			if not _path_matches_roots(path, root_paths):
				continue
			if not _can_scan_more_scene_files(scan_state, max_scanned_scenes):
				_warn_scene_file_limit(max_scanned_scenes, scan_state)
				break
			scan_state["scanned_scene_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_scene_count", 0) + 1

			var script: Script = get_scene_root_script(path)
			if script == null or not _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(script, base_script):
				continue

			used_paths[path] = true
			records.append({
				"path": path,
				"script": script,
				"display_name": path.get_file().get_basename().to_pascal_case(),
			})

	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "display_name")
			< _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "display_name")
		)
	)
	return records


## 获取 PackedScene 根节点脚本。
## [br]
## @api public
## [br]
## @param path: 资源路径或状态路径。
## [br]
## @return 根节点脚本；无法解析时返回 null。
func get_scene_root_script(path: String) -> Script:
	var cached_script: Script = _get_cached_script(path, _scene_root_script_cache)
	if cached_script != null or _cache_has_current_null(path, _scene_root_script_cache):
		return cached_script

	var packed_scene: PackedScene = _variant_to_packed_scene(load(path))
	if packed_scene == null:
		_scene_root_script_cache[path] = _make_cache_entry(path, null)
		return null

	var state: SceneState = packed_scene.get_state()
	if state == null:
		_scene_root_script_cache[path] = _make_cache_entry(path, null)
		return null

	for node_index: int in range(state.get_node_count()):
		if not state.get_node_path(node_index, true).is_empty():
			continue

		for property_index: int in range(state.get_node_property_count(node_index)):
			if state.get_node_property_name(node_index, property_index) == &"script":
				var script: Script = _variant_to_script(state.get_node_property_value(node_index, property_index))
				_scene_root_script_cache[path] = _make_cache_entry(path, script)
				return script

	_scene_root_script_cache[path] = _make_cache_entry(path, null)
	return null


## 清空脚本和场景根脚本缓存。
## [br]
## @api public
func clear_cache() -> void:
	_script_cache.clear()
	_scene_root_script_cache.clear()


## 启用 EditorFileSystem 变更驱动的 live 缓存失效。
##
## 短生命周期扫描不需要调用该方法；长期持有的编辑器工具应传入自己的生命周期 owner。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: live 订阅生命周期 owner。
## [br]
## @return 成功进入 live 缓存失效模式时返回 true。
func enable_live_invalidation(owner: Object) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	_prune_inactive_live_invalidation_tokens()
	if _get_live_invalidation_owner() == owner and not _live_invalidation_tokens.is_empty():
		return true
	if not Engine.is_editor_hint():
		return false

	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return false

	disable_live_invalidation()
	_live_invalidation_owner_ref = weakref(owner)
	_connect_editor_filesystem_signal(filesystem, owner, &"filesystem_changed", Callable(self, "_on_editor_filesystem_changed"))
	_connect_editor_filesystem_signal(filesystem, owner, &"resources_reimported", Callable(self, "_on_editor_filesystem_resources_changed"))
	_connect_editor_filesystem_signal(filesystem, owner, &"resources_reload", Callable(self, "_on_editor_filesystem_resources_changed"))
	_connect_editor_filesystem_signal(filesystem, owner, &"script_classes_updated", Callable(self, "_on_editor_filesystem_changed"))
	if _live_invalidation_tokens.is_empty():
		_live_invalidation_owner_ref = null
		return false

	clear_cache()
	return true


## 停止 EditorFileSystem 变更驱动的 live 缓存失效。
## [br]
## @api public
## [br]
## @since 8.0.0
func disable_live_invalidation() -> void:
	for subscription_token: GFLifetimeSubscription in _live_invalidation_tokens:
		if subscription_token != null:
			var _cancelled: bool = subscription_token.cancel()
	_live_invalidation_tokens.clear()
	_live_invalidation_owner_ref = null


## 返回当前是否处于 live 缓存失效模式。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 至少存在一个活动 live 订阅时返回 true。
func is_live_invalidation_enabled() -> bool:
	_prune_inactive_live_invalidation_tokens()
	return not _live_invalidation_tokens.is_empty()


## 释放类型索引持有的编辑器信号订阅和缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	disable_live_invalidation()
	clear_cache()


# --- 私有/辅助方法 ---

func _load_script(path: String) -> Script:
	var cached_script: Script = _get_cached_script(path, _script_cache)
	if cached_script != null or _cache_has_current_null(path, _script_cache):
		return cached_script

	var script: Script = _variant_to_script(load(path))
	_script_cache[path] = _make_cache_entry(path, script)
	return script


func _get_cached_script(path: String, cache: Dictionary) -> Script:
	if not cache.has(path):
		return null
	var entry: Variant = cache[path]
	if entry is Dictionary:
		var entry_data: Dictionary = entry
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry_data, "modified_time", -1) != _get_resource_modified_time(path):
			var _removed_stale: bool = cache.erase(path)
			return null
		return _variant_to_script(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry_data, "script"))
	var legacy_script: Script = _variant_to_script(entry)
	var _removed_legacy: bool = cache.erase(path)
	return legacy_script


func _cache_has_current_null(path: String, cache: Dictionary) -> bool:
	if not cache.has(path):
		return false
	var entry: Variant = cache[path]
	if not (entry is Dictionary):
		return false
	var entry_data: Dictionary = entry
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry_data, "modified_time", -1) != _get_resource_modified_time(path):
		var _removed_stale: bool = cache.erase(path)
		return false
	var script_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry_data, "script")
	return not (script_value is Script)


func _make_cache_entry(path: String, script: Script) -> Dictionary:
	return {
		"modified_time": _get_resource_modified_time(path),
		"script": script,
	}


func _get_resource_modified_time(path: String) -> int:
	var resolved_path: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		resolved_path = ProjectSettings.globalize_path(path)
	return int(FileAccess.get_modified_time(resolved_path))


func _join_resource_path(dir_path: String, file_name: String) -> String:
	if dir_path.ends_with("/"):
		return dir_path + file_name
	return "%s/%s" % [dir_path, file_name]


func _connect_editor_filesystem_signal(
	filesystem: EditorFileSystem,
	owner: Object,
	signal_name: StringName,
	callback: Callable
) -> void:
	if not filesystem.has_signal(signal_name):
		return

	var subscription_token: GFLifetimeSubscription = GFSignalSubscriptionToken.connect_owned(
		Signal(filesystem, signal_name),
		owner,
		callback,
		0,
		"GFEditorTypeIndex.%s" % String(signal_name)
	)
	if subscription_token.is_active():
		_live_invalidation_tokens.append(subscription_token)


func _prune_inactive_live_invalidation_tokens() -> void:
	for i: int in range(_live_invalidation_tokens.size() - 1, -1, -1):
		var subscription_token: GFLifetimeSubscription = _live_invalidation_tokens[i]
		if subscription_token != null and subscription_token.is_active():
			continue
		if subscription_token != null:
			var _cancelled: bool = subscription_token.cancel()
		_live_invalidation_tokens.remove_at(i)
	if _live_invalidation_tokens.is_empty():
		_live_invalidation_owner_ref = null


func _get_live_invalidation_owner() -> Object:
	if _live_invalidation_owner_ref == null:
		return null
	var raw_owner: Variant = _live_invalidation_owner_ref.get_ref()
	if raw_owner is Object:
		var owner: Object = raw_owner
		if is_instance_valid(owner):
			return owner
	return null


func _path_matches_roots(path: String, root_paths: PackedStringArray) -> bool:
	if root_paths.is_empty():
		return true

	for root_path: String in root_paths:
		var normalized_root: String = root_path
		if not normalized_root.ends_with("/"):
			normalized_root += "/"
		if path == root_path or path.begins_with(normalized_root):
			return true
	return false


func _can_scan_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_scan_depth_limit(path, max_scan_depth, scan_state)
	return false


func _can_scan_more_scene_files(scan_state: Dictionary, max_scanned_scenes: int) -> bool:
	return max_scanned_scenes <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_scene_count", 0) < max_scanned_scenes


func _make_scene_scan_state() -> Dictionary:
	return {
		"scanned_scene_count": 0,
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


func _warn_scene_file_limit(max_scanned_scenes: int, scan_state: Dictionary) -> void:
	if max_scanned_scenes <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted", false):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFEditorTypeIndex] collect_scene_roots_extending 已达到 max_scanned_scenes=%d，后续场景已跳过。" % max_scanned_scenes)


func _warn_scan_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted", false):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFEditorTypeIndex] collect_scene_roots_extending 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _variant_to_packed_scene(value: Variant) -> PackedScene:
	if value is PackedScene:
		var packed_scene: PackedScene = value
		return packed_scene
	return null


func _variant_to_editor_directory(value: Variant) -> EditorFileSystemDirectory:
	if value is EditorFileSystemDirectory:
		var directory: EditorFileSystemDirectory = value
		return directory
	return null


# --- 信号处理函数 ---

func _on_editor_filesystem_changed() -> void:
	clear_cache()


func _on_editor_filesystem_resources_changed(_resources: PackedStringArray = PackedStringArray()) -> void:
	clear_cache()
