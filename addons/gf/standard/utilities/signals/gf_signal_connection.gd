## GFSignalConnection: 可管理的 Godot Signal 链式连接。
##
## 连接支持默认参数、过滤、映射、延迟、防抖、节流、次数限制、
## 累积转换、一次性触发和 owner 归属清理。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFSignalConnection
extends RefCounted


# --- 枚举 ---

## 链式连接处理步骤类型。
## [br]
## @api public
enum OperationType {
	## 过滤信号参数。
	FILTER,
	## 映射信号参数。
	MAP,
	## 延迟处理。
	DELAY,
	## 防抖处理。
	DEBOUNCE,
	## 节流处理。
	THROTTLE,
	## 跳过前若干次触发。
	SKIP,
	## 只接收前若干次触发。
	TAKE,
	## 累积转换信号参数。
	SCAN,
}


# --- 常量 ---

const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const _MAX_SIGNAL_ARGUMENTS: int = 16


# --- 私有变量 ---

var _source_signal: Signal
var _callback: Callable
var _owner_ref: WeakRef = null
var _utility_ref: WeakRef = null
var _default_args: Array = []
var _connect_flags: int = 0
var _operations: Array[Dictionary] = []
var _is_once: bool = false
var _is_connected: bool = false
var _lifecycle_serial: int = 0


# --- Godot 生命周期方法 ---

func _init(
	source_signal: Signal,
	callback: Callable,
	owner: Object = null,
	default_args: Array = [],
	connect_flags: int = 0,
	utility: Object = null
) -> void:
	_source_signal = source_signal
	_callback = callback
	_owner_ref = weakref(owner) if owner != null else null
	_default_args = default_args.duplicate()
	_connect_flags = connect_flags
	_utility_ref = weakref(utility) if utility != null else null


# --- 公共方法 ---

## 增加过滤步骤。predicate 返回 false 时停止本次回调。
## [br]
## @api public
## [br]
## @param predicate: 用于过滤信号参数的回调。
## [br]
## @return 当前连接对象，便于继续链式配置。
func filter(predicate: Callable) -> GFSignalConnection:
	if predicate.is_valid():
		_operations.append({
			"type": OperationType.FILTER,
			"callable": predicate,
		})
	return self


## 增加映射步骤。mapper 的返回值会替换后续回调参数。
## [br]
## @api public
## [br]
## @param mapper: 用于转换信号参数的回调。
## [br]
## @return 当前连接对象，便于继续链式配置。
func map(mapper: Callable) -> GFSignalConnection:
	if mapper.is_valid():
		_operations.append({
			"type": OperationType.MAP,
			"callable": mapper,
		})
	return self


## 每次触发都延迟指定秒数后再继续处理。
## [br]
## @api public
## [br]
## @param seconds: 延迟时间（秒）。
## [br]
## @return 当前连接对象，便于继续链式配置。
func delay(seconds: float) -> GFSignalConnection:
	_operations.append({
		"type": OperationType.DELAY,
		"seconds": maxf(seconds, 0.0),
	})
	return self


## 防抖处理。连续触发时只保留静默期后的最后一次。
## [br]
## @api public
## [br]
## @param seconds: 防抖静默期（秒）。
## [br]
## @return 当前连接对象，便于继续链式配置。
func debounce(seconds: float) -> GFSignalConnection:
	_operations.append({
		"type": OperationType.DEBOUNCE,
		"seconds": maxf(seconds, 0.0),
		"debounce_serial": 0,
	})
	return self


## 节流处理。指定秒数内只允许首次触发继续传递。
## [br]
## @api public
## [br]
## @param seconds: 节流时间（秒）。
## [br]
## @return 当前连接对象，便于继续链式配置。
func throttle(seconds: float) -> GFSignalConnection:
	_operations.append({
		"type": OperationType.THROTTLE,
		"seconds": maxf(seconds, 0.0),
		"last_msec": -1,
	})
	return self


## 跳过前 count 次成功进入该步骤的触发。
## [br]
## @api public
## [br]
## @param count: 需要跳过的次数。
## [br]
## @return 当前连接对象，便于继续链式配置。
func skip(count: int) -> GFSignalConnection:
	_operations.append({
		"type": OperationType.SKIP,
		"remaining": maxi(count, 0),
	})
	return self


## 只允许前 count 次成功进入该步骤的触发继续传递，耗尽后自动断开。
## [br]
## @api public
## [br]
## @param count: 允许传递的次数。
## [br]
## @return 当前连接对象，便于继续链式配置。
func take(count: int) -> GFSignalConnection:
	_operations.append({
		"type": OperationType.TAKE,
		"remaining": maxi(count, 0),
	})
	return self


## 只允许第一次成功进入该步骤的触发继续传递，之后自动断开。
## [br]
## @api public
## [br]
## @return 当前连接对象，便于继续链式配置。
func first() -> GFSignalConnection:
	return take(1)


## 对信号参数执行累积转换。reducer 第一个参数为当前累积值，后续参数为当前信号参数。
## [br]
## @api public
## [br]
## @param accumulator: 初始累积值。
## [br]
## @param reducer: 累积转换回调。
## [br]
## @schema accumulator: Variant，传给 reducer 的初始累加器。
## [br]
## @return 当前连接对象，便于继续链式配置。
func scan(accumulator: Variant, reducer: Callable) -> GFSignalConnection:
	if reducer.is_valid():
		_operations.append({
			"type": OperationType.SCAN,
			"accumulator": accumulator,
			"callable": reducer,
		})
	return self


## 立即用指定参数主动执行一次链式处理。
## [br]
## @api public
## [br]
## @param value: 初始参数；Array 会按参数列表传入，Callable 会被调用并使用其返回值。
## [br]
## @schema value: Variant，起始值、参数 Array，或返回这两类形态的 Callable。
## [br]
## @return 当前连接对象，便于继续链式配置。
func start_with(value: Variant) -> GFSignalConnection:
	_start_process_async(_normalize_start_args(value), _lifecycle_serial)
	return self


## 设置为一次性连接，首次成功触发后自动断开。
## [br]
## @api public
## [br]
## @return 当前连接对象，便于继续链式配置。
func once() -> GFSignalConnection:
	_is_once = true
	return self


## 启动连接。
## [br]
## @api public
## [br]
## @return 当前连接对象。
func start() -> GFSignalConnection:
	if _is_connected:
		return self
	if _source_signal.is_null():
		push_error("[GFSignalConnection] start 失败：Signal 为空。")
		return self
	if not _callback.is_valid():
		push_error("[GFSignalConnection] start 失败：callback 无效。")
		return self

	var _connected_error: Error = _source_signal.connect(
		_on_signal_emitted,
		_connect_flags as Object.ConnectFlags
	) as Error
	_is_connected = true
	return self


## 主动断开连接。
## [br]
## @api public
func disconnect_signal() -> void:
	_lifecycle_serial += 1
	if not _is_connected:
		return
	if not _source_signal.is_null() and is_instance_valid(_source_signal.get_object()):
		if _source_signal.is_connected(_on_signal_emitted):
			_source_signal.disconnect(_on_signal_emitted)
	_is_connected = false


## 当前连接是否仍有效。
## [br]
## @api public
## [br]
## @return 当前连接仍处于连接状态时返回 true。
func is_active() -> bool:
	return _is_connected


## 当前连接是否属于指定 owner。
## [br]
## @api public
## [br]
## @param owner: 监听或连接的拥有者。
## [br]
## @return owner 匹配时返回 true。
func is_owned_by(owner: Object) -> bool:
	if owner == null or _owner_ref == null:
		return false
	return _owner_ref.get_ref() == owner


## 检查连接是否匹配指定 Signal、回调和可选 owner。
## [br]
## @api public
## [br]
## @param source_signal: 要连接或断开的 Godot 信号。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param owner: 监听或连接的拥有者。
## [br]
## @return Signal、回调和 owner 匹配时返回 true。
func matches(source_signal: Signal, callback: Callable, owner: Object = null) -> bool:
	if _source_signal != source_signal:
		return false
	if _callback != callback:
		return false
	if owner != null and not is_owned_by(owner):
		return false
	return true


## owner、signal 发射源或 callback 目标失效时清理连接。
## [br]
## @api public
## [br]
## @return 连接已被判定无效并清理时返回 true。
func prune_if_invalid() -> bool:
	if not _callback.is_valid():
		disconnect_signal()
		return true
	if _source_signal.is_null():
		disconnect_signal()
		return true
	var source_obj: Object = _source_signal.get_object()
	if not is_instance_valid(source_obj):
		disconnect_signal()
		return true
	if _owner_ref != null and _owner_ref.get_ref() == null:
		disconnect_signal()
		return true
	return false


# --- 私有/辅助方法 ---

func _matches_configuration(
	source_signal: Signal,
	callback: Callable,
	owner: Object,
	default_args: Array,
	connect_flags: int,
	once_requested: bool
) -> bool:
	if _source_signal != source_signal:
		return false
	if _callback != callback:
		return false
	if not _owner_matches_exact(owner):
		return false
	if _default_args != default_args:
		return false
	if _connect_flags != connect_flags:
		return false
	return _is_once == once_requested


func _on_signal_emitted(
	arg1: Variant = null,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null,
	arg6: Variant = null,
	arg7: Variant = null,
	arg8: Variant = null,
	arg9: Variant = null,
	arg10: Variant = null,
	arg11: Variant = null,
	arg12: Variant = null,
	arg13: Variant = null,
	arg14: Variant = null,
	arg15: Variant = null,
	arg16: Variant = null
) -> void:
	var args: Array = _collect_args([
		arg1,
		arg2,
		arg3,
		arg4,
		arg5,
		arg6,
		arg7,
		arg8,
		arg9,
		arg10,
		arg11,
		arg12,
		arg13,
		arg14,
		arg15,
		arg16,
	])
	_start_process_async(args, _lifecycle_serial)


func _start_process_async(args: Array, lifecycle_serial: int) -> void:
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_process_async"), [args, lifecycle_serial])


func _owner_matches_exact(owner: Object) -> bool:
	if owner == null:
		return _owner_ref == null
	return is_owned_by(owner)


func _process_async(args: Array, lifecycle_serial: int) -> void:
	var current_args: Array = args.duplicate()
	var should_disconnect_after_callback: bool = false
	for operation: Dictionary in _operations:
		if lifecycle_serial != _lifecycle_serial or prune_if_invalid():
			return

		match _get_operation_type(operation):
			OperationType.FILTER:
				var predicate: Callable = _get_operation_callable(operation)
				if not GFVariantData.to_bool(predicate.callv(current_args)):
					return

			OperationType.MAP:
				var mapper: Callable = _get_operation_callable(operation)
				var mapped: Variant = mapper.callv(current_args)
				if mapped is Array:
					current_args = mapped
				else:
					current_args = [mapped]

			OperationType.DELAY:
				await _wait_seconds(_get_operation_seconds(operation), lifecycle_serial)

			OperationType.DEBOUNCE:
				var debounce_serial: int = _next_operation_debounce_serial(operation)
				await _wait_seconds(_get_operation_seconds(operation), lifecycle_serial)
				if lifecycle_serial != _lifecycle_serial:
					return
				if debounce_serial != _get_operation_debounce_serial(operation):
					return

			OperationType.THROTTLE:
				var now_msec: int = Time.get_ticks_msec()
				var last_msec: int = _get_operation_last_msec(operation)
				var wait_msec: int = int(_get_operation_seconds(operation) * 1000.0)
				if last_msec >= 0 and wait_msec > 0 and now_msec - last_msec < wait_msec:
					return
				operation["last_msec"] = now_msec

			OperationType.SKIP:
				var skip_remaining: int = _get_operation_remaining(operation)
				if skip_remaining > 0:
					operation["remaining"] = skip_remaining - 1
					return

			OperationType.TAKE:
				var take_remaining: int = _get_operation_remaining(operation)
				if take_remaining <= 0:
					disconnect_signal()
					_unregister_from_utility()
					return
				operation["remaining"] = take_remaining - 1
				should_disconnect_after_callback = _get_operation_remaining(operation) <= 0

			OperationType.SCAN:
				var reducer: Callable = _get_operation_callable(operation)
				var reducer_args: Array = [_get_operation_accumulator(operation)]
				reducer_args.append_array(current_args)
				var accumulator: Variant = reducer.callv(reducer_args)
				operation["accumulator"] = accumulator
				current_args = [accumulator]

	if lifecycle_serial != _lifecycle_serial or prune_if_invalid():
		return

	var final_args: Array = _default_args.duplicate()
	final_args.append_array(current_args)
	var _callback_result: Variant = _callback.callv(final_args)

	if _is_once or should_disconnect_after_callback:
		disconnect_signal()
		_unregister_from_utility()


func _wait_seconds(seconds: float, lifecycle_serial: int) -> void:
	if seconds <= 0.0:
		return

	var main_loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = main_loop if main_loop is SceneTree else null
	if tree != null:
		await tree.create_timer(seconds, true, false, true).timeout
		return

	var start_msec: int = Time.get_ticks_msec()
	var wait_msec: int = int(seconds * 1000.0)
	while lifecycle_serial == _lifecycle_serial and Time.get_ticks_msec() - start_msec < wait_msec:
		var fallback_loop: MainLoop = Engine.get_main_loop()
		var scene_tree: SceneTree = fallback_loop if fallback_loop is SceneTree else null
		if scene_tree == null:
			return
		await scene_tree.process_frame


func _collect_args(raw_args: Array) -> Array:
	var declared_count: int = _get_source_signal_argument_count()
	if declared_count >= 0:
		if declared_count > _MAX_SIGNAL_ARGUMENTS:
			push_warning("[GFSignalConnection] 信号连接当前最多捕获 %d 个参数。" % _MAX_SIGNAL_ARGUMENTS)
		return raw_args.slice(0, mini(declared_count, raw_args.size()))

	var args: Array = raw_args.duplicate()
	while not args.is_empty() and args.back() == null:
		var _removed_placeholder: Variant = args.pop_back()
	return args


func _normalize_start_args(value: Variant) -> Array:
	if value is Callable:
		var callable: Callable = value
		if not callable.is_valid():
			return []
		var returned: Variant = callable.call()
		if returned is Array:
			var returned_args: Array = returned
			return returned_args
		return [returned]
	if value is Array:
		var args: Array = value
		return args
	return [value]


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


func _get_operation_type(operation: Dictionary) -> int:
	return GFVariantData.get_option_int(operation, "type", -1)


func _get_operation_callable(operation: Dictionary) -> Callable:
	return _get_callable_value(GFVariantData.get_option_value(operation, "callable", Callable()))


func _get_operation_seconds(operation: Dictionary) -> float:
	return GFVariantData.get_option_float(operation, "seconds")


func _get_operation_last_msec(operation: Dictionary) -> int:
	return GFVariantData.get_option_int(operation, "last_msec", -1)


func _next_operation_debounce_serial(operation: Dictionary) -> int:
	var debounce_serial: int = _get_operation_debounce_serial(operation) + 1
	operation["debounce_serial"] = debounce_serial
	return debounce_serial


func _get_operation_debounce_serial(operation: Dictionary) -> int:
	return GFVariantData.get_option_int(operation, "debounce_serial")


func _get_operation_remaining(operation: Dictionary) -> int:
	return GFVariantData.get_option_int(operation, "remaining")


func _get_operation_accumulator(operation: Dictionary) -> Variant:
	return GFVariantData.get_option_value(operation, "accumulator")


func _get_signal_info_name(signal_info: Dictionary) -> String:
	return GFVariantData.get_option_string(signal_info, "name")


func _get_signal_info_args(signal_info: Dictionary) -> Array:
	return GFVariantData.get_option_array(signal_info, "args")


func _get_source_signal_argument_count() -> int:
	if _source_signal.is_null():
		return -1

	var source_obj: Object = _source_signal.get_object()
	if not is_instance_valid(source_obj):
		return -1

	var signal_name: String = String(_source_signal.get_name())
	for signal_info: Dictionary in source_obj.get_signal_list():
		if _get_signal_info_name(signal_info) != signal_name:
			continue

		var args: Array = _get_signal_info_args(signal_info)
		return args.size()

	return -1


func _unregister_from_utility() -> void:
	if _utility_ref == null:
		return
	var utility: Object = _utility_ref.get_ref()
	if utility != null and utility.has_method("_untrack_connection"):
		var _untrack_result: Variant = utility.call("_untrack_connection", self)
