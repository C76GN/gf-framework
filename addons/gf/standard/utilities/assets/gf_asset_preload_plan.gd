## GFAssetPreloadPlan: 通用资源预加载计划。
##
## 用 Resource 形式描述一组可预热资源、分组标识和加载约束，便于项目把资源暖机清单保存、校验并交给 GFAssetUtility 执行。
## 该类只表达通用资源路径和调度选项，不绑定资源包、远程下载或项目业务流程。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFAssetPreloadPlan
extends Resource


# --- 导出变量 ---

## 计划稳定标识，便于诊断和回调报告归因。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var plan_id: StringName = &""

## 预加载完成后注册到 GFAssetUtility 的资源分组。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var group_id: StringName = &""

## 预加载条目列表。禁用或空路径条目会保留在计划中，但不会提交给加载器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema entries: Array[Dictionary] where each entry contains `path: String`, optional `type_hint: String`, optional `enabled: bool`, and optional `metadata: Dictionary`.
@export var entries: Array[Dictionary] = []

## 成功加载后是否以分组名义锁定缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var pin_cache: bool = true

## 可选加载通道；为空时由 GFAssetUtility 使用分组和并发配置兜底。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var lane_id: StringName = &""

## 该计划默认最大并发加载数；0 表示不覆盖工具默认值。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_concurrent_loads: int = 0:
	set(value):
		max_concurrent_loads = maxi(value, 0)

## 调用方附加元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary for caller-defined preload plan metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置预加载计划。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_group_id: 预加载分组标识。
## [br]
## @param p_entries: 预加载条目数组。
## [br]
## @schema p_entries: Array[String|Dictionary] where Dictionary entries follow the entries schema.
## [br]
## @param options: 计划选项，支持 plan_id、pin_cache、lane_id、max_concurrent_loads 和 metadata。
## [br]
## @schema options: Dictionary with optional `plan_id: StringName`, `pin_cache: bool`, `lane_id: StringName`, `max_concurrent_loads: int`, and `metadata: Dictionary`.
## [br]
## @return 当前计划。
func configure(
	p_group_id: StringName,
	p_entries: Array = [],
	options: Dictionary = {}
) -> GFAssetPreloadPlan:
	group_id = p_group_id
	plan_id = GFVariantData.get_option_string_name(options, "plan_id")
	pin_cache = GFVariantData.get_option_bool(options, "pin_cache", true)
	lane_id = GFVariantData.get_option_string_name(options, "lane_id")
	max_concurrent_loads = GFVariantData.get_option_int(options, "max_concurrent_loads", 0)
	metadata = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	var _entry_count: int = set_entries(p_entries)
	return self


## 添加路径条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: ResourceLoader 类型提示。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @schema entry_metadata: Dictionary copied into the entry metadata.
## [br]
## @param enabled: 是否参与预加载。
## [br]
## @return 添加后的条目索引；路径为空时返回 -1。
func add_path(
	path: String,
	type_hint: String = "",
	entry_metadata: Dictionary = {},
	enabled: bool = true
) -> int:
	var normalized_path: String = path.strip_edges()
	if normalized_path.is_empty():
		return -1

	entries.append({
		"path": normalized_path,
		"type_hint": type_hint.strip_edges(),
		"metadata": entry_metadata.duplicate(true),
		"enabled": enabled,
	})
	return entries.size() - 1


## 添加字典条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entry: 输入条目。
## [br]
## @schema entry: Dictionary with `path`, optional `type_hint`, optional `enabled`, and optional `metadata`.
## [br]
## @return 添加后的条目索引。
func add_entry(entry: Dictionary) -> int:
	entries.append(normalize_entry(entry))
	return entries.size() - 1


## 批量替换条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_entries: 新条目数组。
## [br]
## @schema p_entries: Array[String|Dictionary] where String values are treated as paths.
## [br]
## @return 写入的条目数量。
func set_entries(p_entries: Array) -> int:
	entries.clear()
	for entry_value: Variant in p_entries:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			entries.append(normalize_entry(entry))
		else:
			var path: String = GFVariantData.to_text(entry_value).strip_edges()
			if not path.is_empty():
				entries.append({
					"path": path,
					"type_hint": "",
					"metadata": {},
					"enabled": true,
				})
	return entries.size()


## 清空计划条目。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear() -> void:
	entries.clear()


## 检查计划是否没有可执行条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 没有启用且路径有效的条目时返回 true。
func is_empty() -> bool:
	return get_entries().is_empty()


## 获取条目数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param include_disabled: 为 true 时统计原始条目，否则只统计启用且路径有效的条目。
## [br]
## @return 条目数量。
func get_entry_count(include_disabled: bool = false) -> int:
	return entries.size() if include_disabled else get_entries().size()


## 规范化条目字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entry: 输入条目。
## [br]
## @schema entry: Dictionary with `path`, optional `type_hint`, optional `enabled`, and optional `metadata`.
## [br]
## @return 规范化条目。
## [br]
## @schema return: Dictionary with `path: String`, `type_hint: String`, `enabled: bool`, and `metadata: Dictionary`.
static func normalize_entry(entry: Dictionary) -> Dictionary:
	return {
		"path": GFVariantData.get_option_string(entry, "path").strip_edges(),
		"type_hint": GFVariantData.get_option_string(entry, "type_hint").strip_edges(),
		"enabled": GFVariantData.get_option_bool(entry, "enabled", true),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata").duplicate(true),
	}


## 获取可提交给 GFAssetUtility 的启用条目副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 预加载条目数组。
## [br]
## @schema return: Array[Dictionary] where each entry contains `path`, `type_hint`, and `metadata`.
func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var normalized: Dictionary = normalize_entry(entry)
		if not GFVariantData.get_option_bool(normalized, "enabled", true):
			continue
		if GFVariantData.get_option_string(normalized, "path").is_empty():
			continue
		result.append({
			"path": GFVariantData.get_option_string(normalized, "path"),
			"type_hint": GFVariantData.get_option_string(normalized, "type_hint"),
			"metadata": GFVariantData.get_option_dictionary(normalized, "metadata").duplicate(true),
		})
	return result


## 转换为 GFAssetUtility.preload_group_async() 选项。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param extra_options: 调用方覆盖选项。
## [br]
## @schema extra_options: Dictionary with GFAssetUtility preload options.
## [br]
## @return 合并后的加载选项。
## [br]
## @schema return: Dictionary with optional `pin_cache`, `lane_id`, and `max_concurrent_loads`.
func to_preload_options(extra_options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = extra_options.duplicate(true)
	if not result.has("pin_cache"):
		result["pin_cache"] = pin_cache
	if lane_id != &"" and not result.has("lane_id") and not result.has("serial_lane_id"):
		result["lane_id"] = lane_id
	if max_concurrent_loads > 0 and not result.has("max_concurrent_loads"):
		result["max_concurrent_loads"] = max_concurrent_loads
	return result


## 校验计划并返回结构化报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 校验报告。
## [br]
## @schema return: Dictionary with `ok`, `plan_id`, `group_id`, `entry_count`, `enabled_count`, `disabled_count`, `invalid_count`, `duplicate_paths`, `issues`, and `metadata`.
func validate() -> Dictionary:
	var issues: Array[Dictionary] = []
	var path_indexes: Dictionary = {}
	var enabled_count: int = 0
	var disabled_count: int = 0
	var invalid_count: int = 0

	if group_id == &"":
		issues.append(_make_issue(0, &"missing_group_id", "group_id is required.", &"group_id"))

	for index: int in range(entries.size()):
		var entry: Dictionary = normalize_entry(entries[index])
		if not GFVariantData.get_option_bool(entry, "enabled", true):
			disabled_count += 1
			continue

		var path: String = GFVariantData.get_option_string(entry, "path")
		if path.is_empty():
			invalid_count += 1
			issues.append(_make_issue(index, &"missing_path", "path is required for enabled entries.", &"path"))
			continue

		enabled_count += 1
		_add_path_index(path_indexes, path, index)

	var duplicate_paths: Array[Dictionary] = _collect_duplicate_paths(path_indexes)
	return {
		"ok": issues.is_empty(),
		"plan_id": plan_id,
		"group_id": group_id,
		"entry_count": entries.size(),
		"enabled_count": enabled_count,
		"disabled_count": disabled_count,
		"invalid_count": invalid_count,
		"duplicate_paths": duplicate_paths,
		"issues": issues,
		"metadata": metadata.duplicate(true),
	}


## 描述计划当前内容。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 计划描述。
## [br]
## @schema return: Dictionary with plan_id, group_id, pin_cache, lane_id, max_concurrent_loads, entry_count, executable_entry_count, entries, validation, and metadata.
func describe() -> Dictionary:
	var described_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		described_entries.append(normalize_entry(entry))
	return {
		"plan_id": plan_id,
		"group_id": group_id,
		"pin_cache": pin_cache,
		"lane_id": lane_id,
		"max_concurrent_loads": max_concurrent_loads,
		"entry_count": entries.size(),
		"executable_entry_count": get_entry_count(),
		"entries": described_entries,
		"validation": validate(),
		"metadata": metadata.duplicate(true),
	}


## 复制计划。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 计划副本。
func duplicate_plan() -> GFAssetPreloadPlan:
	return from_dictionary(to_dictionary())


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 计划字典。
## [br]
## @schema return: Dictionary with `plan_id`, `group_id`, `entries`, `pin_cache`, `lane_id`, `max_concurrent_loads`, and `metadata`.
func to_dictionary() -> Dictionary:
	return {
		"plan_id": plan_id,
		"group_id": group_id,
		"entries": _copy_entries(entries),
		"pin_cache": pin_cache,
		"lane_id": lane_id,
		"max_concurrent_loads": max_concurrent_loads,
		"metadata": metadata.duplicate(true),
	}


## 从字典创建计划。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 计划字典。
## [br]
## @schema data: Dictionary with `plan_id`, `group_id`, `entries`, `pin_cache`, `lane_id`, `max_concurrent_loads`, and `metadata`.
## [br]
## @return 计划对象。
static func from_dictionary(data: Dictionary) -> GFAssetPreloadPlan:
	var plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = plan.configure(
		GFVariantData.get_option_string_name(data, "group_id"),
		GFVariantData.get_option_array(data, "entries"),
		{
			"plan_id": GFVariantData.get_option_string_name(data, "plan_id"),
			"pin_cache": GFVariantData.get_option_bool(data, "pin_cache", true),
			"lane_id": GFVariantData.get_option_string_name(data, "lane_id"),
			"max_concurrent_loads": GFVariantData.get_option_int(data, "max_concurrent_loads", 0),
			"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
		}
	)
	return plan


# --- 私有/辅助方法 ---

static func _copy_entries(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source_entries:
		result.append(normalize_entry(entry))
	return result


static func _make_issue(index: int, issue_kind: StringName, message: String, field_name: StringName) -> Dictionary:
	return {
		"index": index,
		"kind": issue_kind,
		"message": message,
		"field": field_name,
	}


static func _add_path_index(path_indexes: Dictionary, path: String, index: int) -> void:
	if not path_indexes.has(path):
		path_indexes[path] = []
	var indexes: Array = GFVariantData.get_option_array(path_indexes, path)
	indexes.append(index)
	path_indexes[path] = indexes


static func _collect_duplicate_paths(path_indexes: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path_variant: Variant in path_indexes.keys():
		var path: String = GFVariantData.to_text(path_variant)
		var indexes: Array = GFVariantData.get_option_array(path_indexes, path)
		if indexes.size() < 2:
			continue
		result.append({
			"path": path,
			"count": indexes.size(),
			"indexes": indexes.duplicate(true),
		})
	return result
