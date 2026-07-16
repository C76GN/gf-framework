## GFSignalUtility: Godot 原生 Signal 的安全连接与链式处理工具。
##
## 用于连接不适合进入 GF 业务事件总线的节点信号，支持 owner 归属清理、
## 默认参数、过滤、映射、延迟、防抖和一次性触发。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSignalUtility
extends GFUtility


# --- 私有变量 ---

var _connections: Array[GFSignalConnection] = []


# --- GF 生命周期方法 ---

## 释放工具持有的所有 Signal 连接。
## [br]
## @api public
func dispose() -> void:
	disconnect_all()


# --- 公共方法 ---

## 安全连接一个 Signal，并返回可继续链式配置的连接对象。
## [br]
## @param source_signal: 要连接或断开的 Godot 信号。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param owner: 监听或连接的拥有者。
## [br]
## @param default_args: 回调调用时追加的默认参数。
## [br]
## @param connect_flags: Godot 信号连接标记。
## [br]
## @api public
## [br]
## @schema default_args: Array，调用回调时前置于信号参数之前的参数。
## [br]
## @return 创建或复用的连接对象。
func connect_signal(
	source_signal: Signal,
	callback: Callable,
	owner: Object = null,
	default_args: Array = [],
	connect_flags: int = 0
) -> GFSignalConnection:
	return _connect_signal(source_signal, callback, owner, default_args, connect_flags, false)


## 创建一次性 Signal 连接。
## [br]
## @param source_signal: 要连接或断开的 Godot 信号。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param owner: 监听或连接的拥有者。
## [br]
## @param default_args: 回调调用时追加的默认参数。
## [br]
## @param connect_flags: Godot 信号连接标记。
## [br]
## @api public
## [br]
## @schema default_args: Array，调用回调时前置于信号参数之前的参数。
## [br]
## @return 创建或复用的一次性连接对象。
func connect_once(
	source_signal: Signal,
	callback: Callable,
	owner: Object = null,
	default_args: Array = [],
	connect_flags: int = 0
) -> GFSignalConnection:
	return _connect_signal(source_signal, callback, owner, default_args, connect_flags, true)


## 批量连接多个 Signal 到同一个回调。
## [br]
## @param source_signals: 要连接的一组 Godot 信号。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param owner: 监听或连接的拥有者。
## [br]
## @param default_args: 回调调用时追加的默认参数。
## [br]
## @param connect_flags: Godot 信号连接标记。
## [br]
## @return 成功创建或复用的连接列表。
## [br]
## @api public
## [br]
## @schema source_signals: Array，要连接到回调的 Signal 值。
## [br]
## @schema default_args: Array，调用回调时前置于信号参数之前的参数。
func connect_any(
	source_signals: Array,
	callback: Callable,
	owner: Object = null,
	default_args: Array = [],
	connect_flags: int = 0
) -> Array[GFSignalConnection]:
	var result: Array[GFSignalConnection] = []
	for source_signal_variant: Variant in source_signals:
		var typed_signal: Signal = _variant_to_signal(source_signal_variant)
		if typed_signal.is_null():
			continue
		var connection: GFSignalConnection = connect_signal(
			typed_signal,
			callback,
			owner,
			default_args,
			connect_flags
		)
		if connection != null and connection.is_active():
			result.append(connection)
	return result


## 断开指定 Signal 与回调的连接。
## [br]
## @api public
## [br]
## @param source_signal: 要连接或断开的 Godot 信号。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param owner: 监听或连接的拥有者。
func disconnect_signal(source_signal: Signal, callback: Callable, owner: Object = null) -> void:
	for i: int in range(_connections.size() - 1, -1, -1):
		var connection: GFSignalConnection = _connections[i]
		if connection == null:
			_connections.remove_at(i)
			continue
		if _connection_matches(connection, source_signal, callback, owner):
			_connections.erase(connection)
			connection.disconnect_signal()


## 断开某个 owner 拥有的全部连接。
## [br]
## @api public
## [br]
## @param owner: 监听或连接的拥有者。
func disconnect_owner(owner: Object) -> void:
	if owner == null:
		return

	for i: int in range(_connections.size() - 1, -1, -1):
		var connection: GFSignalConnection = _connections[i]
		if connection == null or connection.is_owned_by(owner):
			if connection != null:
				_connections.erase(connection)
				connection.disconnect_signal()
			else:
				_connections.remove_at(i)


## 断开一组由 connect_signal/connect_any 返回的连接。
## [br]
## @api public
## [br]
## @param connections: 连接对象列表。
## [br]
## @schema connections: Array，由 connect_signal()、connect_once() 或 connect_any() 返回的 GFSignalConnection 句柄。
func disconnect_connections(connections: Array) -> void:
	for connection_variant: Variant in connections:
		var connection: GFSignalConnection = _variant_to_connection(connection_variant)
		if connection == null:
			continue
		connection.disconnect_signal()
		_connections.erase(connection)


## 断开所有连接。
## [br]
## @api public
func disconnect_all() -> void:
	var connections: Array[GFSignalConnection] = _connections.duplicate()
	_connections.clear()
	for connection: GFSignalConnection in connections:
		if connection != null:
			connection.disconnect_signal()


## 清理已经失效的连接。
## [br]
## @api public
func prune_invalid_connections() -> void:
	for i: int in range(_connections.size() - 1, -1, -1):
		var connection: GFSignalConnection = _connections[i]
		if connection == null:
			_connections.remove_at(i)
			continue
		if connection.prune_if_invalid():
			_connections.erase(connection)


## 获取当前仍被工具追踪的连接数量。
## [br]
## @api public
## [br]
## @return 仍被工具追踪的有效连接数量。
func get_connection_count() -> int:
	prune_invalid_connections()
	return _connections.size()


# --- 私有/辅助方法 ---

func _connect_signal(
	source_signal: Signal,
	callback: Callable,
	owner: Object,
	default_args: Array,
	connect_flags: int,
	once: bool
) -> GFSignalConnection:
	var existing: GFSignalConnection = _find_connection(source_signal, callback, owner, default_args, connect_flags, once)
	if existing != null:
		return existing

	var connection: GFSignalConnection = GFSignalConnection.new(
		source_signal,
		callback,
		owner,
		default_args,
		connect_flags,
		self
	)
	if once:
		var _once_result_234: Variant = connection.once()
	_connections.append(connection)
	var _start_result_236: Variant = connection.start()
	if not connection.is_active():
		_connections.erase(connection)
	return connection


func _find_connection(
	source_signal: Signal,
	callback: Callable,
	owner: Object,
	default_args: Array,
	connect_flags: int,
	once: bool
) -> GFSignalConnection:
	prune_invalid_connections()
	for connection: GFSignalConnection in _connections:
		if connection._matches_configuration(source_signal, callback, owner, default_args, connect_flags, once):
			return connection
	return null


func _connection_matches(
	connection: GFSignalConnection,
	source_signal: Signal,
	callback: Callable,
	owner: Object
) -> bool:
	if connection == null:
		return false
	return connection.matches(source_signal, callback, owner)


func _variant_to_signal(value: Variant) -> Signal:
	if value is Signal:
		var source_signal: Signal = value
		return source_signal
	return Signal()


func _variant_to_connection(value: Variant) -> GFSignalConnection:
	if value is GFSignalConnection:
		var connection: GFSignalConnection = value
		return connection
	return null


func _untrack_connection(connection: GFSignalConnection) -> void:
	_connections.erase(connection)
