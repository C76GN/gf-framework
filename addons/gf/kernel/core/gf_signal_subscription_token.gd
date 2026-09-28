## GFSignalSubscriptionToken: 管理 Godot Signal 连接的订阅句柄。
##
## 该句柄把 Signal 连接视为需要显式释放的资源；调用 cancel() 会幂等断开连接。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFSignalSubscriptionToken
extends GFSubscriptionToken


# --- 私有变量 ---

## 待连接的 Signal；取消时重置为空 Signal。
## [br]
## @api private
var _source_signal: Signal = Signal()

## 用于连接和断开来源 Signal 的回调。
## [br]
## @api private
var _callback: Callable = Callable()

## 最近一次有效 Signal 连接尝试的来源 ID；重复连接、连接失败或取消均不清除此缓存。
## [br]
## @api private
var _source_id: int = 0

## 与来源 ID 一同记录的信号名称，用于描述连接尝试，不表示当前连接仍活动。
## [br]
## @api private
var _signal_name: StringName = &""


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_signal: 要连接的 Godot Signal。
## [br]
## @param callback: Signal 触发时调用的回调。
## [br]
## @param flags: Godot Signal 连接标记。
## [br]
## @param debug_label: 可选诊断标签。
func _init(
	source_signal: Signal = Signal(),
	callback: Callable = Callable(),
	flags: int = 0,
	debug_label: String = ""
) -> void:
	_source_signal = source_signal
	_callback = callback
	if _connect_source_signal(flags):
		super._init(Callable(self, "_disconnect_source_signal"), debug_label)
	else:
		super._init(Callable(), debug_label)


# --- 公共方法 ---

## 创建绑定 owner 生命周期的 Signal 订阅。
##
## owner 为 Node 时，节点退出场景树会自动取消订阅；其他 Object owner 仍可通过返回的句柄手动取消。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_signal: 要连接的 Godot Signal。
## [br]
## @param owner: 订阅生命周期 owner。
## [br]
## @param callback: Signal 触发时调用的回调。
## [br]
## @param flags: Godot Signal 连接标记。
## [br]
## @param debug_label: 可选诊断标签。
## [br]
## @return 绑定 owner 生命周期的订阅句柄；参数无效或连接失败时返回非活动句柄。
static func connect_owned(
	source_signal: Signal,
	owner: Object,
	callback: Callable,
	flags: int = 0,
	debug_label: String = ""
) -> GFLifetimeSubscription:
	if owner == null or not is_instance_valid(owner):
		return GFLifetimeSubscription.new()

	var signal_subscription: GFSignalSubscriptionToken = GFSignalSubscriptionToken.new(
		source_signal,
		callback,
		flags,
		debug_label
	)
	if not signal_subscription.is_active():
		return GFLifetimeSubscription.new()

	var cancel_callback: Callable = func() -> void:
		var _cancelled: bool = signal_subscription.cancel()
	var lifetime_subscription: GFLifetimeSubscription = GFLifetimeSubscription.new(
		owner,
		cancel_callback,
		debug_label
	)
	if not lifetime_subscription.is_active():
		var _cancelled_inactive: bool = signal_subscription.cancel()
	return lifetime_subscription


## 返回 Signal 来源对象实例 ID；无有效来源时为 0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Signal 来源对象实例 ID。
func get_source_id() -> int:
	return _source_id


## 返回 Signal 名称；无有效来源时为空。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Signal 名称。
func get_signal_name() -> StringName:
	return _signal_name


# --- 私有/辅助方法 ---

## 先记录有效来源身份，再拒绝重复连接或尝试连接；false 不代表来源缓存已清空。
## [br]
## @api private
func _connect_source_signal(flags: int) -> bool:
	if _source_signal.is_null() or not _callback.is_valid():
		return false

	_source_id = _source_signal.get_object_id()
	_signal_name = _source_signal.get_name()
	if _source_signal.is_connected(_callback):
		return false

	var connect_error: Error = _source_signal.connect(_callback, flags as Object.ConnectFlags) as Error
	return connect_error == OK


## 断开仍存在的连接并释放 Signal/Callable 引用，保留最近一次来源 ID 和名称供查询。
## [br]
## @api private
func _disconnect_source_signal() -> void:
	if not _source_signal.is_null() and _callback.is_valid() and _source_signal.is_connected(_callback):
		_source_signal.disconnect(_callback)
	_source_signal = Signal()
	_callback = Callable()
