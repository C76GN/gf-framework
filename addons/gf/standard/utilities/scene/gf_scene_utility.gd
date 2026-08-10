## GFSceneUtility: 场景与流程切换管理器。
##
## 封装原生场景切换，支持带有 `loading scene` 的异步加载、PackedScene
## 资源预加载缓存、切换参数、场景历史，并可在切换完成后清理不需要跨场景保留的 `System/Model`。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSceneUtility
extends GFUtility


# --- 信号 ---

## 当场景异步加载开始时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
signal scene_load_started(path: String)

## 当场景异步加载进度更新时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param progress: 当前进度，范围在 `0.0` 到 `1.0` 之间。
signal scene_load_progress(path: String, progress: float)

## 当场景异步加载完成时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param scene: 已加载完成的场景资源。
signal scene_load_completed(path: String, scene: PackedScene)

## 当场景异步加载失败时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
signal scene_load_failed(path: String)

## 当场景预加载开始时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
signal scene_preload_started(path: String)

## 当场景预加载进度更新时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param progress: 当前进度，范围在 `0.0` 到 `1.0` 之间。
signal scene_preload_progress(path: String, progress: float)

## 当场景预加载完成并进入缓存时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param scene: 已缓存的场景资源。
signal scene_preload_completed(path: String, scene: PackedScene)

## 当场景预加载失败时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
signal scene_preload_failed(path: String)

## 当场景预加载被取消时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
signal scene_preload_cancelled(path: String)

## 当一次场景切换流程开始时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param previous_path: 切换前场景路径。
signal scene_switch_started(path: String, previous_path: String)

## 当一次场景切换流程完成时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param previous_path: 切换前场景路径。
signal scene_switch_completed(path: String, previous_path: String)

## 当一次场景切换流程失败时发出。
## [br]
## @api public
## [br]
## @param path: 目标场景路径。
## [br]
## @param previous_path: 切换前场景路径。
## [br]
## @param message: 失败说明。
signal scene_switch_failed(path: String, previous_path: String, message: String)

## 当 loading scene 切入后发出。
## [br]
## @api public
## [br]
## @param path: loading scene 路径。
signal loading_scene_shown(path: String)

## 当 loading scene 准备退出时发出。
## [br]
## @api public
## [br]
## @param path: loading scene 路径。
signal loading_scene_hidden(path: String)

## 当场景资源写入预加载缓存后发出。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @param fixed: 是否写入固定缓存。
signal scene_cache_added(path: String, fixed: bool)

## 当场景资源从预加载缓存移除后发出。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @param fixed: 是否来自固定缓存。
signal scene_cache_removed(path: String, fixed: bool)

# --- 枚举 ---

## 场景资源在 GFSceneUtility 内部的缓存状态。
## [br]
## @api public
enum SceneResourceState {
	## 未加载。
	NOT_LOADED,
	## 正在预加载。
	PRELOADING,
	## 已缓存 PackedScene。
	PRELOADED,
	## 当前 load_scene_async() 正在等待该资源。
	ACTIVE_LOADING,
}


# --- 常量 ---

const _RESOURCE_BROKER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_broker.gd")
const _RESOURCE_LEASE_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_lease.gd")
const _SCENE_CHANGE_NONE: int = 0
const _SCENE_CHANGE_LOADING: int = 1
const _SCENE_CHANGE_TARGET: int = 2
const _SCENE_CHANGE_RESTORE: int = 3


# --- 公共变量 ---

## 最多保留的预加载 PackedScene 数量；设为 `0` 表示禁用预加载缓存。
## [br]
## @api public
var max_preloaded_scene_resources: int:
	get:
		return _max_preloaded_scene_resources
	set(value):
		_max_preloaded_scene_resources = maxi(value, 0)
		if _max_preloaded_scene_resources == 0:
			clear_preloaded_scenes(false)
			return
		_evict_preloaded_scenes()

## 通过 load_scene_async() 加载完成的目标场景是否写入预加载缓存。
## [br]
## @api public
var cache_loaded_scenes: bool = true

## 可选场景预加载图谱；配置后可按当前场景自动预热相邻场景。
## [br]
## @api public
## [br]
## @since 2.6.0
var scene_preload_map: GFScenePreloadMap:
	get:
		return _scene_preload_map
	set(value):
		if _scene_preload_map == value:
			return
		_cancel_auto_neighbor_plan(&"scene_preload_map_changed")
		_scene_preload_map = value

## 成功切换场景后是否自动按 scene_preload_map 预加载相邻场景。
## [br]
## @api public
## [br]
## @since 2.6.0
var auto_preload_map_neighbors_on_switch: bool:
	get:
		return _auto_preload_map_neighbors_on_switch
	set(value):
		if _auto_preload_map_neighbors_on_switch == value:
			return
		_cancel_auto_neighbor_plan(&"auto_neighbor_policy_changed")
		_auto_preload_map_neighbors_on_switch = value

## 自动图谱预加载半径；小于 0 时使用 GFScenePreloadMap.default_radius。
## [br]
## @api public
## [br]
## @since 2.6.0
var scene_preload_map_radius: int:
	get:
		return _scene_preload_map_radius
	set(value):
		if _scene_preload_map_radius == maxi(value, -1):
			return
		_cancel_auto_neighbor_plan(&"auto_neighbor_radius_changed")
		_scene_preload_map_radius = maxi(value, -1)

## loading scene 可选淡入方法名；目标节点存在该方法时会被调用。
## [br]
## @api public
var loading_screen_fade_in_method: StringName = &"fade_in"

## loading scene 可选淡出方法名；目标节点存在该方法时会被调用。
## [br]
## @api public
var loading_screen_fade_out_method: StringName = &"fade_out"

## loading scene 可选进度更新方法名；不存在时会回退到 update_progress。
## [br]
## @api public
var loading_screen_progress_method: StringName = &"set_progress"

## loading scene 进度更新回退方法名。
## [br]
## @api public
var loading_screen_progress_fallback_method: StringName = &"update_progress"

## loading scene 可选错误显示方法名；目标节点存在该方法时会被调用并传入错误文本。
## [br]
## @api public
var loading_screen_error_method: StringName = &"show_error"

## 默认 loading scene 最短保留秒数；单次切换可覆盖。
## [br]
## @api public
var default_transition_minimum_seconds: float = 0.0

## 最多保留的场景历史数量；设为 0 表示不记录历史。
## [br]
## @api public
var max_scene_history: int:
	get:
		return _max_scene_history
	set(value):
		_max_scene_history = maxi(value, 0)
		_trim_scene_history()


# --- 私有变量 ---

var _max_preloaded_scene_resources: int = 8
var _max_scene_history: int = 16
var _scene_preload_map: GFScenePreloadMap = null
var _auto_preload_map_neighbors_on_switch: bool = true
var _scene_preload_map_radius: int = -1
var _target_path: String = ""
var _is_loading: bool = false
var _loading_scene_path: String = ""
var _transient_scripts: Array[Script] = []
var _previous_pause_state: bool = false
var _previous_scene_path: String = ""
var _is_showing_loading_scene: bool = false
var _loading_scene_exit_notified: bool = false
var _active_load_uses_preload_request: bool = false
var _active_load_cache_loaded_scene: bool = true
var _active_loading_progress: float = 0.0
var _active_transition_started_msec: int = 0
var _active_transition_minimum_seconds: float = 0.0
var _active_transition_params: Dictionary = {}
var _current_scene_params: Dictionary = {}
var _pending_loaded_path: String = ""
var _pending_loaded_scene: PackedScene = null
var _scene_history: Array[Dictionary] = []
var _preload_requests: Dictionary = {}
var _fixed_preloaded_scenes: Dictionary = {}
var _preloaded_scenes: Dictionary = {}
var _preloaded_scene_access_order: Dictionary = {}
var _preloaded_scene_access_serial: int = 0
var _background_scene_params: Dictionary = {}
var _scene_change_serial: int = 0
var _pending_scene_change_kind: int = _SCENE_CHANGE_NONE
var _pending_scene_change_path: String = ""
var _pending_scene_change_scene: PackedScene = null
var _pending_scene_change_previous_pause_state: bool = false
var _pending_previous_history_path: String = ""
var _active_load_operation: _RESOURCE_LEASE_SCRIPT = null
var _resource_broker: GFResourceBroker = null
var _owns_resource_broker: bool = false
var _disposed: bool = false
var _auto_neighbor_generation: int = 0
var _auto_neighbor_scene_tree: SceneTree = null
var _auto_neighbor_scene_changed_callback: Callable = Callable()
var _auto_neighbor_process_frame_scene_tree: SceneTree = null
var _auto_neighbor_process_frame_callback: Callable = Callable()
var _auto_neighbor_render_callback: Callable = Callable()
var _auto_neighbor_settle_timer: SceneTreeTimer = null
var _auto_neighbor_timer_callback: Callable = Callable()


# --- GF 生命周期方法 ---

## 初始化场景工具的暂停策略。
## [br]
## @api public
func init() -> void:
	_disposed = false
	ignore_pause = true


## 从所属架构解析显式注册的共享 GFResourceBroker。
## [br]
## @api public
## [br]
## @since unreleased
func ready() -> void:
	if _disposed or _resource_broker != null:
		return
	var utility: Object = get_utility(_RESOURCE_BROKER_SCRIPT)
	if utility is GFResourceBroker:
		var broker: GFResourceBroker = utility
		var _bind_error: Error = set_resource_broker(broker)


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func tick(_delta: float) -> void:
	_process_pending_scene_change()
	_poll_preload_requests()
	_poll_active_scene_load()
	_drain_cancelled_threaded_operations()
	_process_pending_scene_change()


## 取消待处理场景切换并释放预加载请求、背景参数和缓存。
## [br]
## @api public
func dispose() -> void:
	_disposed = true
	_cancel_auto_neighbor_plan(&"scene_utility_disposed")
	_cancel_pending_scene_change()
	_cancel_active_scene_load_for_dispose()
	_cancel_preload_requests_for_dispose()
	_reset_loading_state()
	_preload_requests.clear()
	_background_scene_params.clear()
	clear_preloaded_scenes()
	if _owns_resource_broker and _resource_broker != null:
		_resource_broker.dispose()


## 释放共享 Broker 引用和架构依赖作用域。
## [br]
## @api public
## [br]
## @since unreleased
func release_dependencies() -> void:
	_resource_broker = null
	_owns_resource_broker = false
	super.release_dependencies()


# --- 公共方法 ---

## 注入共享 Resource Broker。
##
## 重复绑定当前 Broker 幂等成功；存在活动场景加载或预载请求时拒绝替换，
## 避免跨 Broker 拆分同一切换生命周期。当前 Broker 由本 Utility 私有拥有时，
## 还必须等待它完成 drain 并进入 idle，才能替换为其它 Broker。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param broker: 要共享的 Broker。
## [br]
## @return 绑定结果；请求尚未收敛或私有 Broker 尚未 idle 时返回 `ERR_BUSY`。
func set_resource_broker(broker: GFResourceBroker) -> Error:
	if _disposed:
		return ERR_UNAVAILABLE
	if broker == null:
		return ERR_INVALID_PARAMETER
	if _resource_broker == broker:
		return OK
	if _active_load_operation != null or not _preload_requests.is_empty():
		return ERR_BUSY
	if _owns_resource_broker and _resource_broker != null and _resource_broker != broker:
		if not _resource_broker.is_idle():
			return ERR_BUSY
		_resource_broker.dispose()
	_resource_broker = broker
	_owns_resource_broker = false
	return OK


## 为单个独立 Scene Utility 显式创建私有 Resource Broker。
##
## 需要与 Asset 或 BackgroundWork 协调时，应由项目创建一个共享 Broker 并分别注入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param max_active_requests: Broker 同时活动的底层请求上限。
## [br]
## @param max_pending_requests: Broker 等待 admission 的不同请求上限。
## [br]
## @return 创建的 Broker；存在活动请求时返回 null。
func setup_standalone_resource_broker(
	max_active_requests: int = 4,
	max_pending_requests: int = 256
) -> GFResourceBroker:
	if _disposed:
		return null
	if _active_load_operation != null or not _preload_requests.is_empty():
		return null
	var broker: GFResourceBroker = _RESOURCE_BROKER_SCRIPT.new()
	broker.max_active_requests = max_active_requests
	broker.max_pending_requests = max_pending_requests
	broker.init()
	var bind_error: Error = set_resource_broker(broker)
	if bind_error != OK:
		return null
	_owns_resource_broker = true
	return broker


## 获取当前注入的 Resource Broker。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已绑定的 Broker；未配置时返回 null。
func get_resource_broker() -> GFResourceBroker:
	return _resource_broker

## 异步切换场景。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param path: 目标场景资源路径。
## [br]
## @param loading_scene_path: 可选的过渡场景路径。
## [br]
## @param params: 本次切换参数；完成后可通过 get_current_scene_params() 读取。
## [br]
## @param minimum_duration_seconds: loading scene 最短保留秒数；小于 0 时使用默认值。
## [br]
## @schema params: Dictionary[String, Variant]，切换完成后复制到当前场景参数中的场景切换参数。
## [br]
## @return 发起加载的 Godot Error；异步终态继续通过信号报告。
func load_scene_async(
	path: String,
	loading_scene_path: String = "",
	params: Dictionary = {},
	minimum_duration_seconds: float = -1.0
) -> Error:
	if _disposed:
		return ERR_UNAVAILABLE
	if _is_loading:
		push_warning("[GFSceneUtility] 当前已有场景正在加载中：%s" % _target_path)
		return ERR_BUSY

	var scene_path: String = _normalize_scene_path(path)
	var validation_error: String = _validate_scene_resource_path(scene_path, "load_scene_async")
	if not validation_error.is_empty():
		push_error(validation_error)
		scene_load_failed.emit(scene_path)
		return ERR_INVALID_PARAMETER

	var effective_loading_scene_path: String = _resolve_loading_scene_path(loading_scene_path)
	_begin_loading_state(scene_path, effective_loading_scene_path, cache_loaded_scenes, params, minimum_duration_seconds)
	scene_load_started.emit(scene_path)
	scene_switch_started.emit(scene_path, _previous_scene_path)

	var cached_scene: PackedScene = get_preloaded_scene(scene_path)
	if cached_scene != null:
		_emit_scene_load_progress(scene_path, 1.0)
		_schedule_complete_loading(scene_path, cached_scene)
		return OK

	if is_scene_preloading(scene_path):
		_active_load_uses_preload_request = true
		_show_loading_scene_if_needed()
		return OK

	_active_load_operation = _request_threaded_operation(_target_path, "PackedScene")
	var error: Error = (
		_active_load_operation.get_request_error()
		if _active_load_operation != null
		else ERR_UNCONFIGURED
	)
	if error != OK:
		_fail_loading(scene_path, "[GFSceneUtility] 无法发起场景异步加载：%s (错误码：%d)" % [_target_path, error])
		return error

	_show_loading_scene_if_needed()
	return OK


## 按资源配置切换场景。
## [br]
## @api public
## [br]
## @param config: 场景切换配置。
## [br]
## @return 发起切换的 Godot Error。
func load_scene_with_transition(config: GFSceneTransitionConfig) -> Error:
	if config == null:
		push_error("[GFSceneUtility] load_scene_with_transition 失败：config 为空。")
		scene_load_failed.emit("")
		return ERR_INVALID_PARAMETER

	if config.preload_before_change:
		var preload_error: Error = preload_scene(config.target_scene_path, config.preload_as_fixed_cache)
		if preload_error != OK:
			return preload_error

	var previous_cache_loaded_scenes: bool = cache_loaded_scenes
	cache_loaded_scenes = config.cache_loaded_scene
	var load_error: Error = load_scene_async(
		config.target_scene_path,
		config.loading_scene_path,
		config.params,
		config.minimum_duration_seconds
	)
	cache_loaded_scenes = previous_cache_loaded_scenes
	return load_error


## 预加载一个场景资源并放入缓存。
## [br]
## @api public
## [br]
## @param path: 目标场景资源路径。
## [br]
## @param fixed: 为 true 时写入固定缓存，不受 LRU 容量淘汰影响。
## [br]
## @return 发起请求的 Godot Error。
func preload_scene(path: String, fixed: bool = false) -> Error:
	return _preload_scene_with_admission(path, fixed, {}, 0)


## 后台加载一个场景并记录稍后激活时使用的参数。
## [br]
## @api public
## [br]
## @param path: 目标场景资源路径。
## [br]
## @param params: 激活该场景时传入的参数。
## [br]
## @param fixed: 为 true 时写入固定缓存，不受 LRU 容量淘汰影响。
## [br]
## @return 发起请求的 Godot Error。
## [br]
## @schema params: Dictionary[String, Variant]，后台场景激活时复制并应用的参数。
func begin_background_scene_load(path: String, params: Dictionary = {}, fixed: bool = false) -> Error:
	var scene_path: String = _normalize_scene_path(path)
	var error: Error = preload_scene(scene_path, fixed)
	if error == OK:
		_background_scene_params[scene_path] = params.duplicate(true)
	return error


## 激活已经后台加载或正在后台加载的场景。
## [br]
## @api public
## [br]
## @param path: 目标场景资源路径。
## [br]
## @param loading_scene_path: 可选的过渡场景路径。
## [br]
## @param minimum_duration_seconds: loading scene 最短保留秒数；小于 0 时使用默认值。
## [br]
## @return 发起切换的 Godot Error。
func activate_background_scene(
	path: String,
	loading_scene_path: String = "",
	minimum_duration_seconds: float = -1.0
) -> Error:
	if _is_loading:
		push_warning("[GFSceneUtility] 当前已有场景正在加载中：%s" % _target_path)
		return ERR_BUSY

	var scene_path: String = _normalize_scene_path(path)
	var validation_error: String = _validate_scene_resource_path(scene_path, "activate_background_scene")
	if not validation_error.is_empty():
		push_error(validation_error)
		return ERR_INVALID_PARAMETER

	if not is_scene_preloading(scene_path) and not is_scene_preloaded(scene_path):
		return ERR_DOES_NOT_EXIST

	var params: Dictionary = _get_background_scene_params_reference(scene_path)
	return load_scene_async(
		scene_path,
		loading_scene_path,
		params.duplicate(true),
		minimum_duration_seconds
	)


## 获取后台场景记录的参数副本。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 参数副本；没有记录时返回空字典。
## [br]
## @schema return: Dictionary[String, Variant]，后台场景参数。
func get_background_scene_params(path: String) -> Dictionary:
	var params: Dictionary = _get_background_scene_params_reference(_normalize_scene_path(path))
	return params.duplicate(true)


## 批量预加载场景资源。
## [br]
## @api public
## [br]
## @param paths: 场景路径数组。
## [br]
## @param fixed: 为 true 时全部写入固定缓存。
## [br]
## @return path -> Error 的结果字典。
## [br]
## @schema return: Dictionary[String, Error]，以场景路径为键。
func preload_scenes(paths: PackedStringArray, fixed: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for path: String in paths:
		var scene_path: String = _normalize_scene_path(path)
		result[scene_path] = preload_scene(scene_path, fixed)
	return result


## 配置场景预加载图谱。
## [br]
## @api public
## [br]
## @param preload_map: 场景预加载图谱资源；传 null 可关闭图谱预加载。
## [br]
## @param radius: 自动预加载半径；小于 0 时使用图谱默认值。
## [br]
## @param auto_preload_on_switch: 成功切换场景后是否自动预加载相邻场景。
func configure_scene_preload_map(
	preload_map: GFScenePreloadMap,
	radius: int = -1,
	auto_preload_on_switch: bool = true
) -> void:
	_cancel_auto_neighbor_plan(&"scene_preload_map_reconfigured")
	_scene_preload_map = preload_map
	_scene_preload_map_radius = maxi(radius, -1)
	_auto_preload_map_neighbors_on_switch = auto_preload_on_switch


## 获取指定场景的图谱预加载计划。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 当前场景资源路径。
## [br]
## @param radius: 搜索半径；小于 0 时使用 scene_preload_map_radius，再小于 0 时使用图谱默认值。
## [br]
## @param include_fixed: 是否包含固定预加载路径。
## [br]
## @return 预加载计划字典；未配置图谱时 ok 为 false。
## [br]
## @schema return: Dictionary，包含 ok、source_path、source_cache_key、radius、include_fixed、fixed_paths、temporary_paths、paths、fixed_cache_keys、temporary_cache_keys、cache_keys、resource_identities 和 errors。
func get_scene_preload_map_plan(path: String, radius: int = -1, include_fixed: bool = true) -> Dictionary:
	if scene_preload_map == null:
		return _make_missing_scene_preload_map_result(path, radius, include_fixed)

	var scene_path: String = _normalize_scene_path(path)
	var plan: Dictionary = scene_preload_map.get_preload_plan(scene_path, _resolve_scene_preload_map_radius(radius), include_fixed)
	plan["ok"] = true
	return plan


## 按图谱为指定场景发起预加载。
## [br]
## @api public
## [br]
## @param path: 当前场景资源路径。
## [br]
## @param radius: 搜索半径；小于 0 时使用 scene_preload_map_radius，再小于 0 时使用图谱默认值。
## [br]
## @param include_fixed: 是否包含固定预加载路径。
## [br]
## @return 预加载结果字典。
## [br]
## @schema return: Dictionary，包含 ok、source_path、radius、include_fixed、requested_count、fixed_requested、temporary_requested、results、errors 和 plan。
func preload_scene_map_for(path: String, radius: int = -1, include_fixed: bool = true) -> Dictionary:
	return _preload_scene_map_with_admission(path, radius, include_fixed, {}, 0)


## 按图谱为当前场景发起预加载。
## [br]
## @api public
## [br]
## @param radius: 搜索半径；小于 0 时使用 scene_preload_map_radius，再小于 0 时使用图谱默认值。
## [br]
## @param include_fixed: 是否包含固定预加载路径。
## [br]
## @return 预加载结果字典。
## [br]
## @schema return: Dictionary，包含 ok、source_path、radius、include_fixed、requested_count、fixed_requested、temporary_requested、results、errors 和 plan。
func preload_current_scene_map(radius: int = -1, include_fixed: bool = true) -> Dictionary:
	return preload_scene_map_for(_get_current_scene_path(), radius, include_fixed)


## 取消一个仍在进行中的预加载请求。
## [br]
## @api public
## [br]
## @param path: 场景路径。
func cancel_scene_preload(path: String) -> void:
	var scene_path: String = _normalize_scene_path(path)
	if not _preload_requests.has(scene_path):
		return

	var request: Dictionary = _get_preload_request(scene_path)
	request["cancelled"] = true
	_cancel_secondary_auto_neighbor_leases(
		request,
		&"scene_preload_cancelled"
	)
	_cancel_threaded_operation(_get_preload_request_operation(request), &"scene_preload_cancelled")
	scene_preload_cancelled.emit(scene_path)


## 取消全部正在进行中的预加载请求。
## [br]
## @api public
func cancel_all_scene_preloads() -> void:
	for path: String in _preload_requests.keys():
		cancel_scene_preload(path)


## 检查场景是否正在预加载。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 正在预加载时返回 true。
func is_scene_preloading(path: String) -> bool:
	var scene_path: String = _normalize_scene_path(path)
	if not _preload_requests.has(scene_path):
		return false
	return not _is_preload_request_cancelled(_get_preload_request(scene_path))


## 检查场景是否已经预加载到缓存。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 已缓存时返回 true。
func is_scene_preloaded(path: String) -> bool:
	var scene_path: String = _normalize_scene_path(path)
	return _preloaded_scenes.has(scene_path) or _fixed_preloaded_scenes.has(scene_path)


## 获取已预加载的 PackedScene。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 命中缓存时返回 PackedScene，否则返回 null。
func get_preloaded_scene(path: String) -> PackedScene:
	var scene_path: String = _normalize_scene_path(path)
	var fixed_scene: PackedScene = _get_cached_scene(_fixed_preloaded_scenes, scene_path)
	if fixed_scene != null:
		return fixed_scene

	var scene: PackedScene = _get_cached_scene(_preloaded_scenes, scene_path)
	if scene != null:
		_touch_preloaded_scene(scene_path)
	return scene


## 手动写入预加载缓存。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @param scene: PackedScene 实例。
## [br]
## @param fixed: 为 true 时写入固定缓存。
func put_preloaded_scene(path: String, scene: PackedScene, fixed: bool = false) -> void:
	var scene_path: String = _normalize_scene_path(path)
	if scene_path.is_empty() or scene == null:
		return

	if fixed:
		_erase_dictionary_key(_preloaded_scenes, scene_path)
		_erase_dictionary_key(_preloaded_scene_access_order, scene_path)
		_fixed_preloaded_scenes[scene_path] = scene
		scene_cache_added.emit(scene_path, true)
		return

	if max_preloaded_scene_resources <= 0:
		return

	_erase_dictionary_key(_fixed_preloaded_scenes, scene_path)
	_preloaded_scenes[scene_path] = scene
	_touch_preloaded_scene(scene_path)
	_evict_preloaded_scenes()
	scene_cache_added.emit(scene_path, false)


## 移除一个预加载场景资源。
## [br]
## @api public
## [br]
## @param path: 场景路径。
func remove_preloaded_scene(path: String) -> void:
	var scene_path: String = _normalize_scene_path(path)
	var was_fixed: bool = _fixed_preloaded_scenes.has(scene_path)
	var was_temporary: bool = _preloaded_scenes.has(scene_path)
	_erase_dictionary_key(_fixed_preloaded_scenes, scene_path)
	_erase_dictionary_key(_preloaded_scenes, scene_path)
	_erase_dictionary_key(_preloaded_scene_access_order, scene_path)
	_erase_dictionary_key(_background_scene_params, scene_path)
	if was_fixed:
		scene_cache_removed.emit(scene_path, true)
	if was_temporary:
		scene_cache_removed.emit(scene_path, false)


## 清空所有预加载场景资源。
## [br]
## @api public
## [br]
## @param include_fixed: 为 true 时同时清空固定缓存。
func clear_preloaded_scenes(include_fixed: bool = true) -> void:
	var fixed_paths: PackedStringArray = _get_sorted_string_keys(_fixed_preloaded_scenes)
	var temporary_paths: PackedStringArray = _get_sorted_string_keys(_preloaded_scenes)
	if include_fixed:
		_fixed_preloaded_scenes.clear()
		for path: String in fixed_paths:
			scene_cache_removed.emit(path, true)
	_preloaded_scenes.clear()
	_preloaded_scene_access_order.clear()
	if include_fixed:
		_background_scene_params.clear()
	else:
		for path: String in temporary_paths:
			_erase_dictionary_key(_background_scene_params, path)
	_preloaded_scene_access_serial = 0
	for path: String in temporary_paths:
		scene_cache_removed.emit(path, false)


## 把已缓存场景移动到固定缓存。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 移动成功返回 true。
func move_preloaded_scene_to_fixed(path: String) -> bool:
	var scene_path: String = _normalize_scene_path(path)
	var scene: PackedScene = get_preloaded_scene(scene_path)
	if scene == null:
		return false
	put_preloaded_scene(scene_path, scene, true)
	return true


## 把已缓存场景移动到临时 LRU 缓存。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 移动成功返回 true。
func move_preloaded_scene_to_temporary(path: String) -> bool:
	var scene_path: String = _normalize_scene_path(path)
	var scene: PackedScene = get_preloaded_scene(scene_path)
	if scene == null:
		return false
	put_preloaded_scene(scene_path, scene, false)
	return true


## 检查已缓存场景是否位于固定缓存。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 固定缓存命中时返回 true。
func is_preloaded_scene_fixed(path: String) -> bool:
	return _fixed_preloaded_scenes.has(_normalize_scene_path(path))


## 获取正在预加载的场景路径列表。
## [br]
## @api public
## [br]
## @return 路径列表。
func get_preloading_scene_paths() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for path: String in _preload_requests.keys():
		if is_scene_preloading(path):
			_append_packed_string(result, path)
	result.sort()
	return result


## 获取场景缓存与加载状态快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary，包含 is_loading、target_path、loading_scene_path、current_scene、loading_progress、transition、preload_cache、scene_preload_map、preloading、background 和 resource_broker configured/error/admission。
func get_scene_cache_debug_snapshot() -> Dictionary:
	var preloading_paths: PackedStringArray = get_preloading_scene_paths()
	return {
		"is_loading": _is_loading,
		"target_path": _target_path,
		"loading_progress": _active_loading_progress,
		"loading_scene_path": _loading_scene_path,
		"current_scene": _get_current_scene_path(),
		"previous_scene": _previous_scene_path,
		"transition": {
			"minimum_duration_seconds": _active_transition_minimum_seconds,
			"cache_loaded_scene": _active_load_cache_loaded_scene,
			"params": _active_transition_params.duplicate(true),
			"current_params": _current_scene_params.duplicate(true),
			"history_size": _scene_history.size(),
			"pending_completion": _pending_loaded_scene != null,
		},
		"preload_cache": {
			"size": _fixed_preloaded_scenes.size() + _preloaded_scenes.size(),
			"max_size": max_preloaded_scene_resources,
			"fixed_size": _fixed_preloaded_scenes.size(),
			"temporary_size": _preloaded_scenes.size(),
			"fixed_paths": _get_sorted_string_keys(_fixed_preloaded_scenes),
			"temporary_paths": _get_sorted_string_keys(_preloaded_scenes),
			"paths": _get_all_preloaded_scene_paths(),
		},
		"scene_preload_map": {
			"enabled": scene_preload_map != null,
			"auto_preload_on_switch": auto_preload_map_neighbors_on_switch,
			"radius": scene_preload_map_radius,
		},
		"preloading": {
			"size": preloading_paths.size(),
			"paths": preloading_paths,
		},
		"background": {
			"paths": _get_sorted_string_keys(_background_scene_params),
		},
		"resource_broker": _get_resource_broker_debug_snapshot(),
	}


## 获取场景资源状态。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return SceneResourceState 枚举值。
func get_scene_resource_state(path: String) -> int:
	var scene_path: String = _normalize_scene_path(path)
	if _is_loading and _target_path == scene_path:
		return SceneResourceState.ACTIVE_LOADING
	if is_scene_preloading(scene_path):
		return SceneResourceState.PRELOADING
	if is_scene_preloaded(scene_path):
		return SceneResourceState.PRELOADED
	return SceneResourceState.NOT_LOADED


## 获取当前异步加载进度。
## [br]
## @api public
## [br]
## @return 当前加载进度，未加载时为 0。
func get_loading_progress() -> float:
	return _active_loading_progress


## 获取单个场景资源的缓存与加载信息。
## [br]
## @api public
## [br]
## @param path: 场景路径。
## [br]
## @return 场景资源状态字典。
## [br]
## @schema return: Dictionary，包含 path、state、is_loading、is_preloading、is_preloaded、is_fixed、progress、cached 和 file_size_bytes。
func get_scene_resource_info(path: String) -> Dictionary:
	var scene_path: String = _normalize_scene_path(path)
	var request: Dictionary = _get_preload_request(scene_path)
	var progress: float = 0.0
	if _is_loading and _target_path == scene_path:
		progress = _active_loading_progress
	elif not request.is_empty():
		progress = _get_preload_request_progress(request)
	elif is_scene_preloaded(scene_path):
		progress = 1.0
	return {
		"path": scene_path,
		"exists": ResourceLoader.exists(scene_path),
		"state": get_scene_resource_state(scene_path),
		"is_loading": _is_loading and _target_path == scene_path,
		"is_preloading": is_scene_preloading(scene_path),
		"is_preloaded": is_scene_preloaded(scene_path),
		"is_fixed_cache": is_preloaded_scene_fixed(scene_path),
		"progress": progress,
		"file_size_bytes": _get_resource_file_size(scene_path),
	}


## 获取当前场景参数副本。
## [br]
## @api public
## [br]
## @return 当前场景参数。
## [br]
## @schema return: Dictionary[String, Variant]，当前场景参数。
func get_current_scene_params() -> Dictionary:
	return _current_scene_params.duplicate(true)


## 获取场景历史副本。
## [br]
## @api public
## [br]
## @return 场景历史列表，最新项位于数组末尾。
## [br]
## @schema return: Array[Dictionary]，元素包含 path、params 和 timestamp_unix。
func get_scene_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _scene_history:
		result.append(entry.duplicate(true))
	return result


## 清空场景历史。
## [br]
## @api public
func clear_scene_history() -> void:
	_scene_history.clear()


## 弹出最近一个场景历史项。
## [br]
## @api public
## [br]
## @return 历史项；没有历史时返回空字典。
## [br]
## @schema return: Dictionary，包含 path、params 和 timestamp_unix；没有记录时为空字典。
func pop_scene_history() -> Dictionary:
	if _scene_history.is_empty():
		return {}
	var entry: Dictionary = GFVariantData.as_dictionary(_scene_history.pop_back())
	return entry.duplicate(true)


## 切换到最近一个历史场景。
## [br]
## @api public
## [br]
## @param loading_scene_path: 可选 loading scene 路径。
## [br]
## @param minimum_duration_seconds: loading scene 最短保留秒数；小于 0 时使用默认值。
## [br]
## @return 发起切换的 Godot Error。
func load_previous_scene(loading_scene_path: String = "", minimum_duration_seconds: float = -1.0) -> Error:
	if _is_loading:
		push_warning("[GFSceneUtility] 当前已有场景正在加载中：%s" % _target_path)
		return ERR_BUSY
	if _scene_history.is_empty():
		return ERR_DOES_NOT_EXIST

	var entry: Dictionary = GFVariantData.as_dictionary(_scene_history[_scene_history.size() - 1])
	var path: String = _normalize_scene_path(_get_history_entry_path(entry))
	var params: Dictionary = _get_history_entry_params(entry)
	if path.is_empty():
		return ERR_INVALID_DATA

	var validation_error: String = _validate_scene_resource_path(path, "load_previous_scene")
	if not validation_error.is_empty():
		push_error(validation_error)
		return ERR_INVALID_PARAMETER

	_pending_previous_history_path = path
	var load_error: Error = load_scene_async(
		path,
		loading_scene_path,
		params.duplicate(true) if params != null else {},
		minimum_duration_seconds
	)
	if load_error != OK:
		_pending_previous_history_path = ""
	return load_error


## 标记一个脚本类型为瞬态实例。
## [br]
## @api public
## [br]
## @param script_cls: 需要在下次切场景时清理的脚本类型。
func mark_transient(script_cls: Script) -> void:
	if not _transient_scripts.has(script_cls):
		_transient_scripts.append(script_cls)


## 取消一个脚本类型的瞬态标记。
## [br]
## @api public
## [br]
## @param script_cls: 要取消标记的脚本类型。
func unmark_transient(script_cls: Script) -> void:
	_transient_scripts.erase(script_cls)


## 立即清理所有瞬态实例。
## [br]
## @api public
func cleanup_transients() -> void:
	if _transient_scripts.is_empty():
		return

	var arch: Object = _get_architecture_or_null()
	if arch == null:
		return

	for script_cls: Script in _transient_scripts:
		if arch.has_method("unregister_system"):
			_call_architecture_method(arch, &"unregister_system", script_cls)
		if arch.has_method("unregister_model"):
			_call_architecture_method(arch, &"unregister_model", script_cls)
		if arch.has_method("unregister_utility"):
			_call_architecture_method(arch, &"unregister_utility", script_cls)

	_transient_scripts.clear()


# --- 可重写钩子 / 虚方法 ---

## 获取当前 loading scene 节点。
## [br]
## @api protected
## [br]
## @return 当前 loading scene 节点；不存在时返回 null。
func _get_loading_scene_node() -> Node:
	if not _is_showing_loading_scene:
		return null

	var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if scene_tree == null:
		return null
	return scene_tree.current_scene


## 切换到已加载的 PackedScene。
## [br]
## @api protected
## [br]
## @param scene: 目标 PackedScene。
## [br]
## @return 切换成功返回 true。
func _do_change_scene(scene: PackedScene) -> bool:
	var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if scene_tree == null:
		push_error("[GFSceneUtility] 无法获取 SceneTree，场景切换失败。")
		return false

	var error: Error = scene_tree.change_scene_to_packed(scene)
	if error != OK:
		push_error("[GFSceneUtility] 切换到目标场景失败，错误码：%d" % error)
		return false

	cleanup_transients()
	return true


## 同步切换到场景文件路径。
## [br]
## @api protected
## [br]
## @param path: 场景资源路径。
## [br]
## @return Godot 场景切换结果。
func _do_change_scene_sync(path: String) -> Error:
	var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if scene_tree == null:
		return ERR_UNAVAILABLE

	return scene_tree.change_scene_to_file(_normalize_scene_path(path))


## 获取当前场景资源路径。
## [br]
## @api protected
## [br]
## @return 当前场景资源路径；不可用时返回空字符串。
func _get_current_scene_path() -> String:
	var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if scene_tree == null or scene_tree.current_scene == null:
		return ""

	return scene_tree.current_scene.scene_file_path


# --- 私有/辅助方法 ---

func _get_packed_scene_value(value: Variant) -> PackedScene:
	if value is PackedScene:
		return value
	return null


func _normalize_scene_path(raw_path: String) -> String:
	var path: String = raw_path.replace("\\", "/").strip_edges()
	if not path.begins_with("res://"):
		return path

	var relative_path: String = path.substr("res://".length())
	var normalized_segments: PackedStringArray = PackedStringArray()
	for segment: String in relative_path.split("/", false):
		if segment.is_empty() or segment == ".":
			continue
		if segment == "..":
			if not normalized_segments.is_empty():
				normalized_segments.remove_at(normalized_segments.size() - 1)
			continue
		var _appended: bool = normalized_segments.append(segment)
	return "res://%s" % "/".join(normalized_segments)


func _get_scene_tree_value(value: Variant) -> SceneTree:
	if value is SceneTree:
		return value
	return null


func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var result: PackedStringArray = PackedStringArray()
	if value is Array:
		for item: Variant in value:
			_append_packed_string(result, GFVariantData.to_text(item))
	return result


func _get_dictionary_reference(source: Dictionary, key: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(source, key, {}))


func _get_background_scene_params_reference(path: String) -> Dictionary:
	return _get_dictionary_reference(_background_scene_params, _normalize_scene_path(path))


func _get_preload_request(path: String) -> Dictionary:
	return _get_dictionary_reference(_preload_requests, _normalize_scene_path(path))


func _get_preload_request_operation(request: Dictionary) -> _RESOURCE_LEASE_SCRIPT:
	var value: Variant = GFVariantData.get_option_value(request, "operation")
	if value is _RESOURCE_LEASE_SCRIPT:
		var operation: _RESOURCE_LEASE_SCRIPT = value
		return operation
	return null


func _is_preload_request_cancelled(request: Dictionary) -> bool:
	return GFVariantData.get_option_bool(request, "cancelled", false)


func _is_preload_request_fixed(request: Dictionary) -> bool:
	return GFVariantData.get_option_bool(request, "fixed", false)


func _get_preload_request_progress(request: Dictionary) -> float:
	return GFVariantData.get_option_float(request, "progress", 0.0)


func _get_cached_scene(cache: Dictionary, path: String) -> PackedScene:
	return _get_packed_scene_value(GFVariantData.get_option_value(cache, _normalize_scene_path(path)))


func _get_plan_paths(plan: Dictionary, key: String) -> PackedStringArray:
	return _get_packed_string_array_value(GFVariantData.get_option_value(plan, key, PackedStringArray()))


func _get_history_entry_path(entry: Dictionary) -> String:
	return GFVariantData.get_option_string(entry, "path", "")


func _get_history_entry_params(entry: Dictionary) -> Dictionary:
	return GFVariantData.get_option_dictionary(entry, "params", {})


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _request_threaded_operation(
	path: String,
	type_hint: String,
	admission_options: Dictionary = {}
) -> _RESOURCE_LEASE_SCRIPT:
	if _disposed or _resource_broker == null:
		return null
	var options: Dictionary = admission_options.duplicate(true)
	if not options.has("consumer_id"):
		options["consumer_id"] = &"scene"
	return _resource_broker.request(path, type_hint, options)


func _poll_threaded_operation(operation: _RESOURCE_LEASE_SCRIPT) -> Dictionary:
	if _resource_broker == null:
		return _make_missing_resource_broker_result()
	return _resource_broker.poll_lease(operation)


func _cancel_threaded_operation(operation: _RESOURCE_LEASE_SCRIPT, reason: StringName) -> void:
	if operation != null:
		operation.cancel(reason)


func _forget_threaded_operation(operation: _RESOURCE_LEASE_SCRIPT) -> void:
	if operation != null:
		operation.release()


func _drain_cancelled_threaded_operations() -> void:
	if _resource_broker != null:
		_resource_broker.pump()


func _make_missing_resource_broker_result() -> Dictionary:
	return {
		"status": _RESOURCE_LEASE_SCRIPT.STATUS_FAILED,
		"progress": 0.0,
		"resource": null,
		"has_resource": false,
		"error": "resource_broker_not_configured",
		"request_error": ERR_UNCONFIGURED,
	}


func _get_resource_broker_debug_snapshot() -> Dictionary:
	if _resource_broker == null:
		return {
			"configured": false,
			"error": "resource_broker_not_configured",
			"request_error": ERR_UNCONFIGURED,
			"disposed": _disposed,
		}
	var snapshot: Dictionary = _resource_broker.get_debug_snapshot()
	snapshot["configured"] = true
	snapshot["error"] = ""
	snapshot["request_error"] = OK
	snapshot["disposed"] = _disposed
	return snapshot


func _call_architecture_method(architecture: Object, method_name: StringName, script_cls: Script) -> void:
	if architecture == null or not architecture.has_method(method_name):
		return
	var result: Variant = architecture.call(method_name, script_cls)
	if result != null:
		return


func _get_time_utility(architecture: Object) -> GFTimeUtility:
	if architecture == null or not architecture.has_method(&"get_utility"):
		return null
	var utility_value: Variant = architecture.call(&"get_utility", GFTimeUtility)
	if utility_value is GFTimeUtility:
		return utility_value
	return null


func _resolve_scene_preload_map_radius(radius: int) -> int:
	return scene_preload_map_radius if radius < 0 else radius


func _prepare_scene_map_after_switch(path: String) -> int:
	_cancel_auto_neighbor_plan(&"new_target_scene")
	if not auto_preload_map_neighbors_on_switch or scene_preload_map == null:
		return 0

	var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if scene_tree == null:
		return 0

	var generation: int = _auto_neighbor_generation
	var target_path: String = _normalize_scene_path(path)
	var callback: Callable = Callable(self, "_on_auto_neighbor_scene_changed").bind(
		generation,
		target_path
	)
	var connect_error: Error = scene_tree.scene_changed.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		return 0
	_auto_neighbor_scene_tree = scene_tree
	_auto_neighbor_scene_changed_callback = callback
	return generation


func _on_auto_neighbor_scene_changed(
	generation: int,
	target_path: String
) -> void:
	var scene_tree: SceneTree = _auto_neighbor_scene_tree
	_disconnect_auto_neighbor_scene_changed()
	if generation != _auto_neighbor_generation:
		return
	var scene_root: Node = scene_tree.current_scene if scene_tree != null else null
	if not _scene_root_matches_target(scene_root, target_path):
		_cancel_auto_neighbor_plan(&"unexpected_scene_changed")
		return
	_start_auto_neighbor_settle(generation, target_path)


func _start_auto_neighbor_settle(
	generation: int,
	target_path: String
) -> void:
	var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if scene_tree == null:
		return
	var callback: Callable = Callable(
		self,
		"_on_auto_neighbor_process_frame"
	).bind(generation, target_path)
	var connect_error: Error = scene_tree.process_frame.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		_cancel_auto_neighbor_plan(&"process_frame_settle_connect_failed")
		return
	_auto_neighbor_process_frame_scene_tree = scene_tree
	_auto_neighbor_process_frame_callback = callback


func _on_auto_neighbor_process_frame(
	generation: int,
	target_path: String
) -> void:
	_disconnect_auto_neighbor_process_frame()
	if generation != _auto_neighbor_generation:
		return

	if DisplayServer.get_name().to_lower() == "headless":
		var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
		if scene_tree == null:
			return
		var timer: SceneTreeTimer = scene_tree.create_timer(0.0)
		var timer_callback: Callable = Callable(
			self,
			"_on_auto_neighbor_settle_completed"
		).bind(generation, target_path)
		var timer_connect_error: Error = timer.timeout.connect(
			timer_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
		if timer_connect_error != OK:
			_cancel_auto_neighbor_plan(&"timer_settle_connect_failed")
			return
		_auto_neighbor_settle_timer = timer
		_auto_neighbor_timer_callback = timer_callback
	else:
		var render_callback: Callable = Callable(
			self,
			"_on_auto_neighbor_settle_completed"
		).bind(generation, target_path)
		var render_connect_error: Error = RenderingServer.frame_post_draw.connect(
			render_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
		if render_connect_error != OK:
			_cancel_auto_neighbor_plan(&"render_settle_connect_failed")
			return
		_auto_neighbor_render_callback = render_callback


func _on_auto_neighbor_settle_completed(
	generation: int,
	target_path: String
) -> void:
	_disconnect_auto_neighbor_render_settle()
	_disconnect_auto_neighbor_timer_settle()
	if generation != _auto_neighbor_generation:
		return
	if not auto_preload_map_neighbors_on_switch or scene_preload_map == null:
		return

	var result: Dictionary = _preload_scene_map_with_admission(
		target_path,
		scene_preload_map_radius,
		true,
		{
			"exclusive": true,
			"require_idle": true,
			"consumer_id": &"scene_auto_neighbor",
		},
		generation
	)
	if not result.is_empty():
		return


func _cancel_auto_neighbor_plan(reason: StringName) -> void:
	_disconnect_auto_neighbor_scene_changed()
	_disconnect_auto_neighbor_process_frame()
	_disconnect_auto_neighbor_render_settle()
	_disconnect_auto_neighbor_timer_settle()
	_auto_neighbor_generation += 1
	if _auto_neighbor_generation <= 0:
		_auto_neighbor_generation = 1
	_cancel_auto_neighbor_requests(reason)


func _disconnect_auto_neighbor_scene_changed() -> void:
	if (
		_auto_neighbor_scene_tree != null
		and _auto_neighbor_scene_changed_callback.is_valid()
		and _auto_neighbor_scene_tree.scene_changed.is_connected(
			_auto_neighbor_scene_changed_callback
		)
	):
		_auto_neighbor_scene_tree.scene_changed.disconnect(
			_auto_neighbor_scene_changed_callback
		)
	_auto_neighbor_scene_tree = null
	_auto_neighbor_scene_changed_callback = Callable()


func _disconnect_auto_neighbor_process_frame() -> void:
	if (
		_auto_neighbor_process_frame_scene_tree != null
		and _auto_neighbor_process_frame_callback.is_valid()
		and _auto_neighbor_process_frame_scene_tree.process_frame.is_connected(
			_auto_neighbor_process_frame_callback
		)
	):
		_auto_neighbor_process_frame_scene_tree.process_frame.disconnect(
			_auto_neighbor_process_frame_callback
		)
	_auto_neighbor_process_frame_scene_tree = null
	_auto_neighbor_process_frame_callback = Callable()


func _disconnect_auto_neighbor_render_settle() -> void:
	if (
		_auto_neighbor_render_callback.is_valid()
		and RenderingServer.frame_post_draw.is_connected(
			_auto_neighbor_render_callback
		)
	):
		RenderingServer.frame_post_draw.disconnect(
			_auto_neighbor_render_callback
		)
	_auto_neighbor_render_callback = Callable()


func _disconnect_auto_neighbor_timer_settle() -> void:
	if (
		_auto_neighbor_settle_timer != null
		and _auto_neighbor_timer_callback.is_valid()
		and _auto_neighbor_settle_timer.timeout.is_connected(
			_auto_neighbor_timer_callback
		)
	):
		_auto_neighbor_settle_timer.timeout.disconnect(
			_auto_neighbor_timer_callback
		)
	_auto_neighbor_settle_timer = null
	_auto_neighbor_timer_callback = Callable()


func _cancel_auto_neighbor_requests(reason: StringName) -> void:
	var paths: Array = _preload_requests.keys()
	for path: String in paths:
		if not _preload_requests.has(path):
			continue
		var request: Dictionary = _get_preload_request(path)
		_cancel_secondary_auto_neighbor_leases(request, reason)
		var generation: int = GFVariantData.get_option_int(
			request,
			"auto_neighbor_generation",
			0
		)
		if generation <= 0:
			continue
		request["cancelled"] = true
		_cancel_threaded_operation(
			_get_preload_request_operation(request),
			reason
		)
		_erase_dictionary_key(_preload_requests, path)
		scene_preload_cancelled.emit(path)


func _cancel_secondary_auto_neighbor_leases(
	request: Dictionary,
	reason: StringName
) -> void:
	var leases: Dictionary = GFVariantData.get_option_dictionary(
		request,
		"secondary_auto_neighbor_leases"
	)
	for value: Variant in leases.values():
		if value is _RESOURCE_LEASE_SCRIPT:
			var lease: _RESOURCE_LEASE_SCRIPT = value
			lease.cancel(reason)
	request["secondary_auto_neighbor_leases"] = {}


func _release_secondary_auto_neighbor_leases(request: Dictionary) -> void:
	var leases: Dictionary = GFVariantData.get_option_dictionary(
		request,
		"secondary_auto_neighbor_leases"
	)
	for value: Variant in leases.values():
		if value is _RESOURCE_LEASE_SCRIPT:
			var lease: _RESOURCE_LEASE_SCRIPT = value
			lease.release()
	request["secondary_auto_neighbor_leases"] = {}


func _scene_root_matches_target(scene_root: Node, target_path: String) -> bool:
	if scene_root == null:
		return false
	var current_identity: GFResourceIdentity = GFResourceIdentity.from_path(
		scene_root.scene_file_path,
		&"",
		"PackedScene",
		{ "check_exists": false }
	)
	var target_identity: GFResourceIdentity = GFResourceIdentity.from_path(
		target_path,
		&"",
		"PackedScene",
		{ "check_exists": false }
	)
	return (
		not current_identity.cache_key.is_empty()
		and current_identity.cache_key == target_identity.cache_key
	)


func _preload_scene_map_with_admission(
	path: String,
	radius: int,
	include_fixed: bool,
	admission_options: Dictionary,
	auto_neighbor_generation: int
) -> Dictionary:
	if scene_preload_map == null:
		return _make_missing_scene_preload_map_result(path, radius, include_fixed)

	var scene_path: String = _normalize_scene_path(path)
	var plan: Dictionary = scene_preload_map.get_preload_plan(
		scene_path,
		_resolve_scene_preload_map_radius(radius),
		include_fixed
	)
	var fixed_requested: PackedStringArray = PackedStringArray()
	var temporary_requested: PackedStringArray = PackedStringArray()
	var results: Dictionary = {}
	var errors: Array[Dictionary] = []
	for fixed_path: String in _get_plan_paths(plan, "fixed_paths"):
		if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
			break
		var fixed_error: Error = _preload_scene_with_admission(
			fixed_path,
			true,
			admission_options,
			auto_neighbor_generation
		)
		results[fixed_path] = fixed_error
		_append_packed_string(fixed_requested, fixed_path)
		if fixed_error != OK:
			errors.append(_make_scene_preload_map_error(fixed_path, fixed_error, true))
		if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
			break

	if _is_auto_neighbor_generation_current(auto_neighbor_generation):
		for temporary_path: String in _get_plan_paths(plan, "temporary_paths"):
			if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
				break
			var temporary_error: Error = _preload_scene_with_admission(
				temporary_path,
				false,
				admission_options,
				auto_neighbor_generation
			)
			results[temporary_path] = temporary_error
			_append_packed_string(temporary_requested, temporary_path)
			if temporary_error != OK:
				errors.append(
					_make_scene_preload_map_error(
						temporary_path,
						temporary_error,
						false
					)
				)
			if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
				break

	return {
		"ok": errors.is_empty(),
		"source_path": GFVariantData.get_option_string(
			plan,
			"source_path",
			scene_path
		),
		"radius": GFVariantData.get_option_int(plan, "radius", 0),
		"include_fixed": include_fixed,
		"requested_count": fixed_requested.size() + temporary_requested.size(),
		"fixed_requested": fixed_requested,
		"temporary_requested": temporary_requested,
		"results": results,
		"errors": errors,
		"plan": plan,
	}


func _preload_scene_with_admission(
	path: String,
	fixed: bool,
	admission_options: Dictionary,
	auto_neighbor_generation: int
) -> Error:
	if _disposed:
		return ERR_UNAVAILABLE
	if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
		return ERR_BUSY
	var scene_path: String = _normalize_scene_path(path)
	var validation_error: String = _validate_scene_resource_path(
		scene_path,
		"preload_scene"
	)
	if not validation_error.is_empty():
		push_error(validation_error)
		scene_preload_failed.emit(scene_path)
		return ERR_INVALID_PARAMETER

	if is_scene_preloaded(scene_path):
		_touch_preloaded_scene(scene_path)
		return OK
	if is_scene_preloading(scene_path):
		return _merge_preload_interest(
			scene_path,
			admission_options,
			auto_neighbor_generation
		)

	var operation: _RESOURCE_LEASE_SCRIPT = _request_preload_operation_with_admission(
		scene_path,
		admission_options,
		auto_neighbor_generation
	)
	var error: Error = (
		operation.get_request_error()
		if operation != null
		else ERR_UNCONFIGURED
	)
	if error != OK:
		push_error(
			"[GFSceneUtility] 无法发起场景预加载：%s (错误码：%d)"
			% [scene_path, error]
		)
		scene_preload_failed.emit(scene_path)
		return error
	if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
		operation.cancel(&"auto_neighbor_generation_superseded")
		return ERR_BUSY

	_preload_requests[scene_path] = {
		"progress": 0.0,
		"cancelled": false,
		"fixed": fixed,
		"operation": operation,
		"auto_neighbor_generation": auto_neighbor_generation,
		"secondary_auto_neighbor_leases": {},
	}
	scene_preload_started.emit(scene_path)
	if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
		return ERR_BUSY
	return OK


func _request_preload_operation_with_admission(
	scene_path: String,
	admission_options: Dictionary,
	auto_neighbor_generation: int
) -> _RESOURCE_LEASE_SCRIPT:
	var operation: _RESOURCE_LEASE_SCRIPT = _request_threaded_operation(
		scene_path,
		"PackedScene",
		admission_options
	)
	var failure_reason: String = operation.get_error_message() if operation != null else ""
	if (
		auto_neighbor_generation <= 0
		or operation == null
		or not (
			(
				operation.get_request_error() == ERR_BUSY
				and failure_reason == (
					_RESOURCE_BROKER_SCRIPT.REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED
				)
			)
			or (
				operation.get_request_error() == ERR_ALREADY_IN_USE
				and failure_reason == (
					_RESOURCE_BROKER_SCRIPT.REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED
				)
			)
		)
	):
		return operation

	# Admission 与 type_hint 只约束新底层请求；结果仍在完成边界校验为 PackedScene。
	operation.release()
	var join_options: Dictionary = admission_options.duplicate(true)
	join_options["exclusive"] = false
	join_options["require_idle"] = false
	var join_type_hint: String = (
		""
		if failure_reason == _RESOURCE_BROKER_SCRIPT.REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED
		else "PackedScene"
	)
	return _request_threaded_operation(scene_path, join_type_hint, join_options)


func _merge_preload_interest(
	scene_path: String,
	admission_options: Dictionary,
	auto_neighbor_generation: int
) -> Error:
	if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
		return ERR_BUSY
	var request: Dictionary = _get_preload_request(scene_path)
	if auto_neighbor_generation <= 0:
		request["auto_neighbor_generation"] = 0
		return OK

	var primary_generation: int = GFVariantData.get_option_int(
		request,
		"auto_neighbor_generation",
		0
	)
	if primary_generation > 0:
		return OK

	var leases: Dictionary = GFVariantData.get_option_dictionary(
		request,
		"secondary_auto_neighbor_leases"
	)
	var generation_key: String = str(auto_neighbor_generation)
	if leases.has(generation_key):
		return OK
	var lease: _RESOURCE_LEASE_SCRIPT = _request_preload_operation_with_admission(
		scene_path,
		admission_options,
		auto_neighbor_generation
	)
	var error: Error = lease.get_request_error() if lease != null else ERR_UNCONFIGURED
	if error != OK:
		return error
	if not _is_auto_neighbor_generation_current(auto_neighbor_generation):
		lease.cancel(&"auto_neighbor_generation_superseded")
		return ERR_BUSY
	leases[generation_key] = lease
	request["secondary_auto_neighbor_leases"] = leases
	return OK


func _is_auto_neighbor_generation_current(generation: int) -> bool:
	if generation <= 0:
		return not _disposed
	return (
		not _disposed
		and generation == _auto_neighbor_generation
		and auto_preload_map_neighbors_on_switch
		and scene_preload_map != null
	)


func _make_missing_scene_preload_map_result(path: String, radius: int, include_fixed: bool) -> Dictionary:
	var source_identity: GFResourceIdentity = GFResourceIdentity.from_path(path, &"", "PackedScene", { "check_exists": false })
	var source_path: String = source_identity.canonical_path if not source_identity.canonical_path.is_empty() else source_identity.raw_path
	return {
		"ok": false,
		"source_path": source_path,
		"source_cache_key": source_identity.cache_key,
		"radius": _resolve_scene_preload_map_radius(radius),
		"include_fixed": include_fixed,
		"fixed_paths": PackedStringArray(),
		"temporary_paths": PackedStringArray(),
		"paths": PackedStringArray(),
		"fixed_cache_keys": PackedStringArray(),
		"temporary_cache_keys": PackedStringArray(),
		"cache_keys": PackedStringArray(),
		"resource_identities": {},
		"requested_count": 0,
		"fixed_requested": PackedStringArray(),
		"temporary_requested": PackedStringArray(),
		"results": {},
		"errors": [
			{
				"kind": "missing_preload_map",
				"message": "scene_preload_map is not configured.",
			},
		],
		"plan": {},
	}


func _make_scene_preload_map_error(path: String, error: Error, fixed: bool) -> Dictionary:
	return {
		"kind": "preload_failed",
		"path": path,
		"error": error,
		"fixed": fixed,
	}


func _poll_active_scene_load() -> void:
	if not _is_loading or _target_path.is_empty():
		return

	if _pending_loaded_scene != null:
		var completed: bool = _complete_pending_scene_if_ready()
		if completed:
			return
		return

	if _active_load_uses_preload_request:
		_poll_active_preload_scene()
		return

	var active_load_result: Dictionary = _poll_threaded_operation(_active_load_operation)
	var status: StringName = GFVariantData.get_option_string_name(
		active_load_result,
		"status",
		_RESOURCE_LEASE_SCRIPT.STATUS_FAILED
	)

	match status:
		_RESOURCE_LEASE_SCRIPT.STATUS_QUEUED, _RESOURCE_LEASE_SCRIPT.STATUS_LOADING:
			var ratio: float = GFVariantData.get_option_float(active_load_result, "progress", 0.0)
			_emit_scene_load_progress(_target_path, ratio)

		_RESOURCE_LEASE_SCRIPT.STATUS_COMPLETED:
			var loaded_path: String = _target_path
			var scene: PackedScene = _get_packed_scene_value(GFVariantData.get_option_value(active_load_result, "resource"))
			if scene == null:
				_forget_threaded_operation(_active_load_operation)
				_fail_loading(loaded_path, "[GFSceneUtility] 异步加载完成，但目标资源不是 PackedScene：%s" % loaded_path)
				return

			if _active_load_cache_loaded_scene:
				put_preloaded_scene(loaded_path, scene)
			_forget_threaded_operation(_active_load_operation)
			_schedule_complete_loading(loaded_path, scene)

		_RESOURCE_LEASE_SCRIPT.STATUS_FAILED:
			_forget_threaded_operation(_active_load_operation)
			_fail_loading(_target_path, "[GFSceneUtility] 场景异步加载失败：%s" % _target_path)

		_RESOURCE_LEASE_SCRIPT.STATUS_CANCELLED:
			_forget_threaded_operation(_active_load_operation)
			_reset_loading_state()


func _poll_active_preload_scene() -> void:
	if not _preload_requests.has(_target_path):
		var cached_scene: PackedScene = get_preloaded_scene(_target_path)
		if cached_scene != null:
			_emit_scene_load_progress(_target_path, 1.0)
			_schedule_complete_loading(_target_path, cached_scene)
		else:
			_fail_loading(_target_path, "[GFSceneUtility] 场景预加载未完成：%s" % _target_path)
		return

	var request: Dictionary = _get_preload_request(_target_path)
	if _is_preload_request_cancelled(request):
		_fail_loading(_target_path, "[GFSceneUtility] 场景预加载已取消：%s" % _target_path)
		return

	_emit_scene_load_progress(_target_path, _get_preload_request_progress(request))


func _poll_preload_requests() -> void:
	if _preload_requests.is_empty():
		return

	var paths: Array = _preload_requests.keys()
	for path: String in paths:
		if not _preload_requests.has(path):
			continue

		var request: Dictionary = _get_preload_request(path)
		var operation: _RESOURCE_LEASE_SCRIPT = _get_preload_request_operation(request)
		var preload_result: Dictionary = _poll_threaded_operation(operation)
		var status: StringName = GFVariantData.get_option_string_name(
			preload_result,
			"status",
			_RESOURCE_LEASE_SCRIPT.STATUS_FAILED
		)
		var ratio: float = GFVariantData.get_option_float(preload_result, "progress", _get_preload_request_progress(request))
		request["progress"] = ratio

		if not _is_preload_request_cancelled(request):
			scene_preload_progress.emit(path, ratio)

		match status:
			_RESOURCE_LEASE_SCRIPT.STATUS_QUEUED, _RESOURCE_LEASE_SCRIPT.STATUS_LOADING:
				pass

			_RESOURCE_LEASE_SCRIPT.STATUS_COMPLETED:
				var scene: PackedScene = _get_packed_scene_value(GFVariantData.get_option_value(preload_result, "resource"))
				_erase_dictionary_key(_preload_requests, path)
				_release_secondary_auto_neighbor_leases(request)
				if _is_preload_request_cancelled(request):
					_forget_threaded_operation(operation)
					continue
				if scene == null:
					_forget_threaded_operation(operation)
					scene_preload_failed.emit(path)
					continue
				put_preloaded_scene(path, scene, _is_preload_request_fixed(request))
				_forget_threaded_operation(operation)
				scene_preload_completed.emit(path, scene)

			_RESOURCE_LEASE_SCRIPT.STATUS_FAILED:
				_erase_dictionary_key(_preload_requests, path)
				_release_secondary_auto_neighbor_leases(request)
				if not _is_preload_request_cancelled(request):
					scene_preload_failed.emit(path)
				_forget_threaded_operation(operation)

			_RESOURCE_LEASE_SCRIPT.STATUS_CANCELLED:
				_erase_dictionary_key(_preload_requests, path)
				_release_secondary_auto_neighbor_leases(request)
				_forget_threaded_operation(operation)


func _begin_loading_state(
	path: String,
	loading_scene_path: String,
	should_cache_loaded_scene: bool,
	params: Dictionary,
	minimum_duration_seconds: float
) -> void:
	_cancel_auto_neighbor_plan(&"new_scene_switch")
	_target_path = _normalize_scene_path(path)
	_loading_scene_path = _normalize_scene_path(loading_scene_path)
	_is_loading = true
	_active_load_uses_preload_request = false
	_active_load_cache_loaded_scene = should_cache_loaded_scene
	_active_transition_started_msec = Time.get_ticks_msec()
	_active_transition_minimum_seconds = maxf(
		minimum_duration_seconds if minimum_duration_seconds >= 0.0 else default_transition_minimum_seconds,
		0.0
	)
	_active_transition_params = params.duplicate(true)
	_pending_loaded_path = ""
	_pending_loaded_scene = null
	_previous_pause_state = _get_paused()
	_previous_scene_path = _normalize_scene_path(_get_current_scene_path())
	_is_showing_loading_scene = false
	_loading_scene_exit_notified = false
	_active_loading_progress = 0.0
	_set_paused(true)


func _resolve_loading_scene_path(loading_scene_path: String) -> String:
	var scene_path: String = _normalize_scene_path(loading_scene_path)
	if scene_path.is_empty():
		return ""

	var loading_validation_error: String = _validate_scene_resource_path(scene_path, "loading_scene")
	if not loading_validation_error.is_empty():
		push_warning(loading_validation_error)
		return ""
	return scene_path


func _show_loading_scene_if_needed() -> void:
	if _loading_scene_path.is_empty():
		return

	if _previous_scene_path.is_empty():
		push_warning("[GFSceneUtility] 当前场景缺少 scene_file_path，跳过 loading scene 以避免失败后无法恢复。")
		return

	_queue_scene_change(_SCENE_CHANGE_LOADING, _loading_scene_path)


func _apply_loading_scene_change(path: String) -> void:
	if not _is_loading or _loading_scene_path != path:
		return

	var loading_error: Error = _do_change_scene_sync(path)
	if loading_error == OK:
		_is_showing_loading_scene = true
		loading_scene_shown.emit(path)
		_call_loading_scene_optional_method(loading_screen_fade_in_method)
	else:
		push_error("[GFSceneUtility] 无法切换到 loading scene：%s (错误码：%d)" % [path, loading_error])

	var completed: bool = _complete_pending_scene_if_ready()
	if completed:
		return


func _emit_scene_load_progress(path: String, progress: float) -> void:
	_active_loading_progress = clampf(progress, 0.0, 1.0)
	scene_load_progress.emit(path, _active_loading_progress)
	_call_loading_scene_progress_method(_active_loading_progress)


func _notify_loading_scene_exit_if_needed() -> void:
	if not _is_showing_loading_scene or _loading_scene_exit_notified:
		return

	_loading_scene_exit_notified = true
	_call_loading_scene_optional_method(loading_screen_fade_out_method)
	loading_scene_hidden.emit(_loading_scene_path)


func _call_loading_scene_progress_method(progress: float) -> void:
	if not _is_showing_loading_scene:
		return

	var loading_scene: Node = _get_loading_scene_node()
	if loading_scene == null:
		return
	if loading_screen_progress_method != &"" and loading_scene.has_method(loading_screen_progress_method):
		loading_scene.call(loading_screen_progress_method, progress)
		return
	if loading_screen_progress_fallback_method != &"" and loading_scene.has_method(loading_screen_progress_fallback_method):
		loading_scene.call(loading_screen_progress_fallback_method, progress)


func _call_loading_scene_optional_method(method_name: StringName) -> void:
	if method_name == &"":
		return

	var loading_scene: Node = _get_loading_scene_node()
	if loading_scene != null and loading_scene.has_method(method_name):
		loading_scene.call(method_name)


func _call_loading_scene_error_method(message: String) -> void:
	if loading_screen_error_method == &"":
		return

	var loading_scene: Node = _get_loading_scene_node()
	if loading_scene != null and loading_scene.has_method(loading_screen_error_method):
		loading_scene.call(loading_screen_error_method, message)


func _schedule_complete_loading(path: String, scene: PackedScene) -> void:
	_pending_loaded_path = path
	_pending_loaded_scene = scene
	var completed: bool = _complete_pending_scene_if_ready()
	if completed:
		return


func _complete_pending_scene_if_ready() -> bool:
	if _pending_loaded_scene == null:
		return false
	if _pending_scene_change_kind != _SCENE_CHANGE_NONE:
		return false
	if not _is_transition_minimum_elapsed():
		return false

	var path: String = _pending_loaded_path
	var scene: PackedScene = _pending_loaded_scene
	_pending_loaded_path = ""
	_pending_loaded_scene = null
	_complete_loading(path, scene)
	return true


func _is_transition_minimum_elapsed() -> bool:
	if _active_transition_minimum_seconds <= 0.0:
		return true
	var elapsed_seconds: float = float(Time.get_ticks_msec() - _active_transition_started_msec) / 1000.0
	return elapsed_seconds >= _active_transition_minimum_seconds


func _complete_loading(path: String, scene: PackedScene) -> void:
	_queue_scene_change(_SCENE_CHANGE_TARGET, path, scene)


func _apply_target_scene_change(path: String, scene: PackedScene) -> void:
	if not _is_loading or _target_path != path:
		return
	if scene == null:
		_fail_loading(path, "[GFSceneUtility] 切换到目标场景失败：PackedScene 为空。")
		return

	var previous_path: String = _previous_scene_path
	_notify_loading_scene_exit_if_needed()
	var auto_neighbor_generation: int = _prepare_scene_map_after_switch(path)
	if _do_change_scene(scene):
		_is_showing_loading_scene = false
		_consume_pending_previous_history(path)
		_push_scene_history(previous_path, _current_scene_params)
		_current_scene_params = _active_transition_params.duplicate(true)
		_erase_dictionary_key(_background_scene_params, path)
		scene_load_completed.emit(path, scene)
		scene_switch_completed.emit(path, previous_path)
		_set_paused(_previous_pause_state)
		_reset_loading_state()
	else:
		if auto_neighbor_generation == _auto_neighbor_generation:
			_cancel_auto_neighbor_plan(&"target_scene_change_failed")
		_fail_loading(path, "")


func _set_paused(p_paused: bool) -> void:
	var arch: Object = _get_architecture_or_null()
	if arch == null:
		return

	var time_util: GFTimeUtility = _get_time_utility(arch)
	if time_util != null:
		time_util.is_paused = p_paused


func _get_paused() -> bool:
	var arch: Object = _get_architecture_or_null()
	if arch == null:
		return false

	var time_util: GFTimeUtility = _get_time_utility(arch)
	return time_util.is_paused if time_util != null else false


func _fail_loading(path: String, message: String) -> void:
	_cancel_pending_scene_change()
	if not message.is_empty():
		push_error(message)

	var previous_path: String = _previous_scene_path
	scene_load_failed.emit(path)
	scene_switch_failed.emit(path, previous_path, message)
	_call_loading_scene_error_method(message)
	_notify_loading_scene_exit_if_needed()
	if _restore_previous_scene_if_needed():
		return
	_set_paused(_previous_pause_state)
	_reset_loading_state()


func _restore_previous_scene_if_needed() -> bool:
	if not _is_showing_loading_scene:
		return false

	if _previous_scene_path.is_empty():
		push_warning("[GFSceneUtility] 无法恢复上一场景：缺少 scene_file_path。")
		return false

	_queue_scene_change(_SCENE_CHANGE_RESTORE, _previous_scene_path, null, _previous_pause_state)
	return true


func _apply_restore_previous_scene(path: String, previous_pause_state: bool) -> void:
	var error: Error = _do_change_scene_sync(path)
	if error != OK:
		push_error("[GFSceneUtility] 恢复上一场景失败：%s (错误码：%d)" % [path, error])
	_is_showing_loading_scene = false
	_set_paused(previous_pause_state)
	_reset_loading_state()


func _queue_scene_change(
	kind: int,
	path: String = "",
	scene: PackedScene = null,
	previous_pause_state: bool = false
) -> void:
	_scene_change_serial += 1
	_pending_scene_change_kind = kind
	_pending_scene_change_path = _normalize_scene_path(path)
	_pending_scene_change_scene = scene
	_pending_scene_change_previous_pause_state = previous_pause_state
	call_deferred("_process_pending_scene_change_deferred", _scene_change_serial)


func _process_pending_scene_change_deferred(serial: int) -> void:
	if serial != _scene_change_serial:
		return
	_process_pending_scene_change()


func _process_pending_scene_change() -> void:
	if _pending_scene_change_kind == _SCENE_CHANGE_NONE:
		return

	var kind: int = _pending_scene_change_kind
	var path: String = _pending_scene_change_path
	var scene: PackedScene = _pending_scene_change_scene
	var previous_pause_state: bool = _pending_scene_change_previous_pause_state
	_clear_pending_scene_change(true)

	match kind:
		_SCENE_CHANGE_LOADING:
			_apply_loading_scene_change(path)
		_SCENE_CHANGE_TARGET:
			_apply_target_scene_change(path, scene)
		_SCENE_CHANGE_RESTORE:
			_apply_restore_previous_scene(path, previous_pause_state)


func _cancel_pending_scene_change() -> void:
	_clear_pending_scene_change(true)


func _clear_pending_scene_change(update_serial: bool) -> void:
	if update_serial and _pending_scene_change_kind != _SCENE_CHANGE_NONE:
		_scene_change_serial += 1
	_pending_scene_change_kind = _SCENE_CHANGE_NONE
	_pending_scene_change_path = ""
	_pending_scene_change_scene = null
	_pending_scene_change_previous_pause_state = false


func _validate_scene_resource_path(path: String, label: String) -> String:
	var scene_path: String = _normalize_scene_path(path)
	if scene_path.is_empty():
		return "[GFSceneUtility] %s 失败：path 为空。" % label
	if not ResourceLoader.exists(scene_path):
		return "[GFSceneUtility] %s 失败：资源不存在：%s" % [label, scene_path]

	var extension: String = scene_path.get_extension().to_lower()
	var scene_extensions: PackedStringArray = ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	if scene_extensions.has(extension):
		return ""

	if scene_path.begins_with("uid://"):
		var scene: PackedScene = _get_packed_scene_value(ResourceLoader.load(scene_path, "PackedScene"))
		if scene != null:
			return ""

	return "[GFSceneUtility] %s 失败：资源不是 PackedScene：%s" % [label, scene_path]


func _push_scene_history(path: String, params: Dictionary) -> void:
	var scene_path: String = _normalize_scene_path(path)
	if scene_path.is_empty() or max_scene_history <= 0:
		return

	_scene_history.append({
		"path": scene_path,
		"params": params.duplicate(true),
		"timestamp_unix": Time.get_unix_time_from_system(),
	})
	_trim_scene_history()


func _consume_pending_previous_history(path: String) -> void:
	var scene_path: String = _normalize_scene_path(path)
	if _pending_previous_history_path != scene_path:
		return
	_pending_previous_history_path = ""
	if _scene_history.is_empty():
		return
	var entry: Dictionary = GFVariantData.as_dictionary(_scene_history[_scene_history.size() - 1])
	if _normalize_scene_path(_get_history_entry_path(entry)) == scene_path:
		_scene_history.remove_at(_scene_history.size() - 1)


func _trim_scene_history() -> void:
	while _scene_history.size() > _max_scene_history:
		_scene_history.remove_at(0)


func _reset_loading_state() -> void:
	_is_loading = false
	_target_path = ""
	_loading_scene_path = ""
	_previous_scene_path = ""
	_is_showing_loading_scene = false
	_loading_scene_exit_notified = false
	_active_load_uses_preload_request = false
	_active_load_cache_loaded_scene = true
	_active_loading_progress = 0.0
	_active_transition_started_msec = 0
	_active_transition_minimum_seconds = 0.0
	_active_transition_params.clear()
	_pending_previous_history_path = ""
	_pending_loaded_path = ""
	_pending_loaded_scene = null
	_active_load_operation = null


func _cancel_active_scene_load_for_dispose() -> void:
	if not _is_loading or _target_path.is_empty():
		return
	if _active_load_operation != null:
		_cancel_threaded_operation(_active_load_operation, &"scene_active_load_disposed")
	var path: String = _target_path
	var previous_path: String = _previous_scene_path
	scene_load_failed.emit(path)
	scene_switch_failed.emit(path, previous_path, "[GFSceneUtility] 场景加载因工具释放而取消：%s" % path)


func _cancel_preload_requests_for_dispose() -> void:
	for path: String in _preload_requests.keys():
		var request: Dictionary = _get_preload_request(path)
		if _is_preload_request_cancelled(request):
			continue
		request["cancelled"] = true
		_cancel_secondary_auto_neighbor_leases(
			request,
			&"scene_preload_disposed"
		)
		_cancel_threaded_operation(_get_preload_request_operation(request), &"scene_preload_disposed")
		scene_preload_cancelled.emit(path)


func _touch_preloaded_scene(path: String) -> void:
	var scene_path: String = _normalize_scene_path(path)
	if scene_path.is_empty():
		return
	_preloaded_scene_access_serial += 1
	_preloaded_scene_access_order[scene_path] = _preloaded_scene_access_serial


func _evict_preloaded_scenes() -> void:
	while _preloaded_scenes.size() > max_preloaded_scene_resources and max_preloaded_scene_resources > 0:
		var oldest_path: String = _get_oldest_preloaded_scene_path()
		if oldest_path.is_empty():
			return
		remove_preloaded_scene(oldest_path)


func _get_oldest_preloaded_scene_path() -> String:
	var oldest_path: String = ""
	var oldest_access: int = 0
	var has_oldest: bool = false
	for path: String in _preloaded_scenes:
		var access: int = GFVariantData.get_option_int(_preloaded_scene_access_order, path, 0)
		if not has_oldest or access < oldest_access:
			oldest_path = path
			oldest_access = access
			has_oldest = true
	return oldest_path


func _get_sorted_string_keys(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in data.keys():
		_append_packed_string(result, GFVariantData.to_text(key))
	result.sort()
	return result


func _get_all_preloaded_scene_paths() -> PackedStringArray:
	var result: PackedStringArray = _get_sorted_string_keys(_fixed_preloaded_scenes)
	for path: String in _get_sorted_string_keys(_preloaded_scenes):
		if not result.has(path):
			_append_packed_string(result, path)
	result.sort()
	return result


func _get_resource_file_size(path: String) -> int:
	var scene_path: String = _normalize_scene_path(path)
	if scene_path.is_empty() or scene_path.begins_with("uid://") or not FileAccess.file_exists(scene_path):
		return -1

	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size
