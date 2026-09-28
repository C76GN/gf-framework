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

## 会话的 committed、failed 或 rolled_back 终态。
## [br]
## @api private
## [br]
var _status: StringName = &""

## 产生此结果的会话 ID。
## [br]
## @api private
## [br]
var _session_id: StringName = &""

## 会话使用的预加载计划 ID。
## [br]
## @api private
## [br]
var _plan_id: StringName = &""

## 计划指定的目标分组 ID。
## [br]
## @api private
## [br]
var _group_id: StringName = &""

## 成功加载的资源路径。
## [br]
## @api private
## [br]
var _loaded_paths: PackedStringArray = PackedStringArray()

## 加载失败的资源路径。
## [br]
## @api private
## [br]
var _failed_paths: PackedStringArray = PackedStringArray()

## 加载失败时的说明文本。
## [br]
## @api private
## [br]
var _error: String = ""

## 会话回滚或中止时记录的原因。
## [br]
## @api private
## [br]
var _rollback_reason: StringName = &""

## 标记回滚时是否保留了已加载缓存。
## [br]
## @api private
## [br]
var _cache_retained_on_rollback: bool = false

## 调用方传入并随结果保存的元数据。
## [br]
## @api private
## [br]
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




# --- 框架内部方法 ---

## 由会话写入终态快照；路径归一化、错误文本去空白，元数据深复制。
## 只有确有已加载路径时才保留回滚后缓存仍在的标志。
## [br]
## @api framework_internal
## [br]
## @param status: 会话的终态标识。
## [br]
## @param session_id: 产生结果的会话标识。
## [br]
## @param plan_id: 对应预载计划标识。
## [br]
## @param group_id: 计划的目标资源组标识。
## [br]
## @param loaded_paths: 已加载路径，写入时归一化。
## [br]
## @param failed_paths: 加载失败路径，写入时归一化。
## [br]
## @param error: 可读失败说明，存储时移除两端空白。
## [br]
## @param rollback_reason: 回滚或中止原因。
## [br]
## @param cache_retained_on_rollback: 调用方报告的缓存保留状态。
## [br]
## @param metadata: 随结果保存的会话元数据。
## [br]
## @schema metadata: Dictionary，任意会话元数据；容器通过 duplicate(true) 复制。
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


# --- 私有/辅助方法 ---

# 由资产层配置不可变终态数据。
## 去除路径首尾空白、空项和重复项，并对结果排序。
## [br]
## @api private
## [br]
static func _normalize_paths(paths: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var normalized: String = path.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result
