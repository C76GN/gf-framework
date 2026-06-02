## GFReactiveEffect: GFBindableProperty 的轻量响应式副作用。
##
## 监听一组 GFBindableProperty，在任意来源变化时执行回调。可绑定 Node 生命周期，
## 适合 Controller 层组合多个 Model 属性，不要求项目引入新的状态模型。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFReactiveEffect
extends RefCounted


# --- 信号 ---

## effect 执行后发出。
## [br]
## @api public
## [br]
## @param value: 回调返回值。
## [br]
## @schema value {
##   "type": "Variant",
##   "description": "回调返回值。"
## }
signal effect_ran(value: Variant)


# --- 常量 ---

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 单次 run 中最多补跑的次数，避免回调持续写入来源属性造成死循环。
## [br]
## @api public
var max_reruns_per_run: int = 8


# --- 私有变量 ---

var _sources: Array[GFBindableProperty] = []
var _callback: Callable = Callable()
var _owner_ref: WeakRef = null
var _connections: Array[Dictionary] = []
var _active: bool = false
var _running: bool = false
var _rerun_requested: bool = false


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @param sources: 要监听的 GFBindableProperty 列表。
## [br]
## @param callback: 变化后执行的回调。
## [br]
## @param owner: 可选 Node 生命周期宿主。
## [br]
## @param run_immediately: 是否立即执行一次。
func _init(
	sources: Array[GFBindableProperty] = [],
	callback: Callable = Callable(),
	owner: Node = null,
	run_immediately: bool = true
) -> void:
	if not sources.is_empty() or callback.is_valid():
		configure(sources, callback, owner, run_immediately)


# --- 公共方法 ---

## 配置并启动 effect。重复调用会先停止旧绑定。
## [br]
## @api public
## [br]
## @param sources: 要监听的 GFBindableProperty 列表。
## [br]
## @param callback: 变化后执行的回调。
## [br]
## @param owner: 可选 Node 生命周期宿主。
## [br]
## @param run_immediately: 是否立即执行一次。
func configure(
	sources: Array[GFBindableProperty],
	callback: Callable,
	owner: Node = null,
	run_immediately: bool = true
) -> void:
	stop()
	_sources = _filter_sources(sources)
	_callback = callback
	_owner_ref = weakref(owner) if owner != null else null
	_active = _callback.is_valid()
	if not _active:
		return

	for source: GFBindableProperty in _sources:
		_bind_source(source, owner)

	var stop_callback: Callable = Callable(self, "stop")
	if owner != null and not owner.tree_exited.is_connected(stop_callback):
		var _connect_result_110: Variant = owner.tree_exited.connect(
			stop_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)

	if run_immediately:
		run()


## 手动执行 effect。
## [br]
## @api public
## [br]
## @return 回调返回值；回调无效时返回 null。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "回调返回值；回调无效时返回 null。"
## }
func run() -> Variant:
	if not _active or not _callback.is_valid():
		return null
	if _running:
		_rerun_requested = true
		return null

	var value: Variant = null
	var rerun_count: int = 0
	while _active and _callback.is_valid():
		_running = true
		_rerun_requested = false
		value = _callback.call()
		_running = false
		effect_ran.emit(value)

		if not _rerun_requested:
			break
		rerun_count += 1
		if rerun_count >= maxi(max_reruns_per_run, 1):
			push_warning("[GFReactiveEffect] run 停止补跑：达到 max_reruns_per_run。")
			break
	return value


## 停止 effect 并断开全部监听。
## [br]
## @api public
func stop() -> void:
	for connection: Dictionary in _connections:
		var source: GFBindableProperty = _get_connection_source(connection)
		var callback: Callable = _get_connection_callable(connection)
		var connection_owner: Node = _get_owner()
		if source == null or not callback.is_valid():
			continue
		if connection_owner != null:
			source.unbind(connection_owner, callback)
		elif source.value_changed.is_connected(callback):
			source.value_changed.disconnect(callback)

	var effect_owner: Node = _get_owner()
	var stop_callback: Callable = Callable(self, "stop")
	if effect_owner != null and effect_owner.tree_exited.is_connected(stop_callback):
		effect_owner.tree_exited.disconnect(stop_callback)

	_connections.clear()
	_sources.clear()
	_callback = Callable()
	_owner_ref = null
	_active = false
	_running = false
	_rerun_requested = false


## 释放 effect 持有的监听。
## [br]
## @api public
func dispose() -> void:
	stop()


## 检查 effect 是否处于激活状态。
## [br]
## @api public
## [br]
## @return 激活时返回 true。
func is_active() -> bool:
	return _active


## 获取当前监听的属性列表。
## [br]
## @api public
## [br]
## @return GFBindableProperty 数组。
func get_sources() -> Array[GFBindableProperty]:
	return _sources.duplicate()


# --- 私有/辅助方法 ---

func _bind_source(source: GFBindableProperty, owner: Node) -> void:
	var callback: Callable = Callable(self, "_on_source_changed")
	_connections.append({
		"source": source,
		"callable": callback,
	})
	if owner != null:
		source.bind_to(owner, callback)
	elif not source.value_changed.is_connected(callback):
		var _connect_result_216: Variant = source.value_changed.connect(callback)


func _filter_sources(sources: Array[GFBindableProperty]) -> Array[GFBindableProperty]:
	var result: Array[GFBindableProperty] = []
	for source: GFBindableProperty in sources:
		if source != null and not result.has(source):
			result.append(source)
	return result


func _get_owner() -> Node:
	if _owner_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(_owner_ref)


func _on_source_changed(_old_value: Variant, _new_value: Variant) -> void:
	run()


func _get_connection_source(connection: Dictionary) -> GFBindableProperty:
	var raw_source: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(connection, "source")
	if raw_source is GFBindableProperty:
		var source: GFBindableProperty = raw_source
		return source
	return null


func _get_connection_callable(connection: Dictionary) -> Callable:
	var raw_callable: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(connection, "callable", Callable())
	if raw_callable is Callable:
		var callback: Callable = raw_callable
		return callback
	return Callable()
