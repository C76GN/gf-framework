## GFAssetLoadSessionResult: 资产加载会话终态结果。
##
## 结果区分 committed、failed 和 rolled_back，并显式说明回滚只撤销会话分组，
## 不破坏可能被其他 owner 共享的缓存项。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFAssetLoadSessionResult
extends RefCounted


# --- 常量 ---

## 会话已原子提交到目标分组。
## [br]
## @api public
## [br]
## @since 9.0.0
const STATUS_COMMITTED: StringName = &"committed"

## 会话因校验或加载失败而回滚。
## [br]
## @api public
## [br]
## @since 9.0.0
const STATUS_FAILED: StringName = &"failed"

## 调用方主动回滚会话。
## [br]
## @api public
## [br]
## @since 9.0.0
const STATUS_ROLLED_BACK: StringName = &"rolled_back"


# --- 私有变量 ---

var _status: StringName = &""
var _session_id: StringName = &""
var _plan_id: StringName = &""
var _group_id: StringName = &""
var _loaded_paths: PackedStringArray = PackedStringArray()
var _failed_paths: PackedStringArray = PackedStringArray()
var _error: String = ""
var _rollback_reason: StringName = &""
var _cache_retained_on_rollback: bool = false
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 检查会话是否已提交。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return committed 终态返回 true。
func is_successful() -> bool:
	return _status == STATUS_COMMITTED


## 获取终态状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return committed、failed 或 rolled_back。
func get_status() -> StringName:
	return _status


## 获取会话 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 会话 ID。
func get_session_id() -> StringName:
	return _session_id


## 获取计划 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 计划 ID。
func get_plan_id() -> StringName:
	return _plan_id


## 获取目标分组 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 目标分组 ID。
func get_group_id() -> StringName:
	return _group_id


## 获取成功加载路径副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 成功加载路径。
func get_loaded_paths() -> PackedStringArray:
	return _loaded_paths.duplicate()


## 获取失败路径副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 失败路径。
func get_failed_paths() -> PackedStringArray:
	return _failed_paths.duplicate()


## 获取失败说明。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 失败说明；提交或主动回滚时可为空。
func get_error() -> String:
	return _error


## 获取回滚原因。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 回滚原因；提交时为空。
func get_rollback_reason() -> StringName:
	return _rollback_reason


## 检查回滚后是否保留已加载缓存。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 为保护共享 owner 而保留缓存时返回 true。
func is_cache_retained_on_rollback() -> bool:
	return _cache_retained_on_rollback


## 获取结果元数据副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 调用方元数据副本。
## [br]
## @schema return: Dictionary caller-defined session metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 转换为字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 会话结果字典。
## [br]
## @schema return: Dictionary with ok, status, session_id, plan_id, group_id, loaded_paths, failed_paths, error, rollback_reason, cache_retained_on_rollback, and metadata.
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"status": _status,
		"session_id": _session_id,
		"plan_id": _plan_id,
		"group_id": _group_id,
		"loaded_paths": _loaded_paths.duplicate(),
		"failed_paths": _failed_paths.duplicate(),
		"error": _error,
		"rollback_reason": _rollback_reason,
		"cache_retained_on_rollback": _cache_retained_on_rollback,
		"metadata": _metadata.duplicate(true),
	}


## 创建结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 隔离结果副本。
func duplicate_result() -> GFAssetLoadSessionResult:
	var copy: GFAssetLoadSessionResult = GFAssetLoadSessionResult.new()
	copy._gf_configure(
		_status,
		_session_id,
		_plan_id,
		_group_id,
		_loaded_paths,
		_failed_paths,
		_error,
		_rollback_reason,
		_cache_retained_on_rollback,
		_metadata
	)
	return copy


# --- 私有/辅助方法 ---

# 由资产层配置不可变终态数据。
func _gf_configure(
	status: StringName,
	session_id: StringName,
	plan_id: StringName,
	group_id: StringName,
	loaded_paths: PackedStringArray,
	failed_paths: PackedStringArray,
	error: String,
	rollback_reason: StringName,
	cache_retained_on_rollback: bool,
	metadata: Dictionary
) -> void:
	_status = status
	_session_id = session_id
	_plan_id = plan_id
	_group_id = group_id
	_loaded_paths = _normalize_paths(loaded_paths)
	_failed_paths = _normalize_paths(failed_paths)
	_error = error.strip_edges()
	_rollback_reason = rollback_reason
	_cache_retained_on_rollback = cache_retained_on_rollback and not _loaded_paths.is_empty()
	_metadata = metadata.duplicate(true)
static func _normalize_paths(paths: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var normalized: String = path.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result
