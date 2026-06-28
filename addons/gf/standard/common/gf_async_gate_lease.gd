## GFAsyncGateLease: keyed async gate 的租约句柄。
##
## 租约表示某个 key 当前被允许执行的一个并发槽位。调用方只需要在工作完成、
## 取消或失败时调用 release()；释放是幂等的，不负责执行业务回滚。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFAsyncGateLease
extends RefCounted


# --- 信号 ---

## 租约首次释放时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lease: 当前租约。
## [br]
## @param reason: 稳定释放原因。
signal released(lease: GFAsyncGateLease, reason: StringName)


# --- 私有变量 ---

var _lease_id: int = 0
var _request_id: int = 0
var _key: Variant = null
var _metadata: Dictionary = {}
var _acquired_msec: int = 0
var _released_msec: int = 0
var _release_reason: StringName = &""
var _active: bool = false
var _release_callback: Callable = Callable()


# --- 公共方法 ---

## 释放租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 稳定释放原因。
## [br]
## @return 首次释放成功时返回 true。
func release(reason: StringName = &"manual") -> bool:
	if not _active:
		return false
	var safe_reason: StringName = reason if reason != &"" else &"manual"
	if _release_callback.is_valid():
		var callback_result: Variant = _release_callback.call(self, safe_reason)
		if callback_result is bool:
			var released_by_owner: bool = callback_result
			if released_by_owner and _active:
				var _marked_released: bool = _mark_released_from_gate(safe_reason)
			return released_by_owner
		return false

	return _mark_released_from_gate(safe_reason)


## 当前租约是否仍占用并发槽位。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 活跃时返回 true。
func is_active() -> bool:
	return _active


## 获取租约 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前 gate 内唯一的租约 ID。
func get_lease_id() -> int:
	return _lease_id


## 获取创建该租约的请求 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前 gate 内唯一的请求 ID。
func get_request_id() -> int:
	return _request_id


## 获取租约 key 的副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 租约 key。
## [br]
## @schema return: Variant，调用方传入的 key 副本。
func get_key() -> Variant:
	return GFVariantData.duplicate_variant(_key)


## 获取租约元数据副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 租约元数据。
## [br]
## @schema return: Dictionary，调用方传入的 metadata 副本。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取租约持有时长。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 活跃租约返回当前持有毫秒数；已释放租约返回实际持有毫秒数。
func get_held_msec() -> int:
	if _acquired_msec <= 0:
		return 0
	var end_msec: int = _released_msec if _released_msec > 0 else Time.get_ticks_msec()
	return maxi(end_msec - _acquired_msec, 0)


## 获取释放原因。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 释放原因；未释放时为空 StringName。
func get_release_reason() -> StringName:
	return _release_reason


## 获取租约调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 租约状态快照。
## [br]
## @schema return: Dictionary，包含 lease_id、request_id、key、active、metadata、acquired_msec、released_msec、held_msec 和 release_reason。
func get_debug_snapshot() -> Dictionary:
	return {
		"lease_id": _lease_id,
		"request_id": _request_id,
		"key": GFVariantData.duplicate_variant(_key),
		"active": _active,
		"metadata": _metadata.duplicate(true),
		"acquired_msec": _acquired_msec,
		"released_msec": _released_msec,
		"held_msec": get_held_msec(),
		"release_reason": _release_reason,
	}


# --- 框架内部方法 ---

## 由 GFAsyncKeyedGate 初始化租约。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param lease_id: gate 内唯一租约 ID。
## [br]
## @param request_id: gate 内唯一请求 ID。
## [br]
## @param key: 租约 key。
## [br]
## @param metadata: 调用方元数据。
## [br]
## @param release_callback: 释放回调，签名为 Callable(lease, reason) -> bool。
## [br]
## @return 当前租约。
## [br]
## @schema key: Variant，调用方传入的 key。
## [br]
## @schema metadata: Dictionary，调用方定义的租约上下文。
func configure_from_gate(
	lease_id: int,
	request_id: int,
	key: Variant,
	metadata: Dictionary,
	release_callback: Callable
) -> GFAsyncGateLease:
	_lease_id = lease_id
	_request_id = request_id
	_key = GFVariantData.duplicate_variant(key)
	_metadata = metadata.duplicate(true)
	_acquired_msec = Time.get_ticks_msec()
	_released_msec = 0
	_release_reason = &""
	_active = true
	_release_callback = release_callback
	return self


# 由拥有者 gate 标记租约已释放。
func _mark_released_from_gate(reason: StringName = &"manual") -> bool:
	if not _active:
		return false
	_active = false
	_release_reason = reason if reason != &"" else &"manual"
	_released_msec = Time.get_ticks_msec()
	released.emit(self, _release_reason)
	return true
