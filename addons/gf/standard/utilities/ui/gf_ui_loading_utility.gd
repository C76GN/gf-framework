## GFUILoadingUtility: 并发等待请求的显示状态聚合器。
##
## 主线程服务；不创建界面，不阻塞业务完成。延迟与最短可见时间使用注入的单调时钟，
## tick 同时检查弱 owner/scope 与当前进度。最多持有 4096 个活动 lease。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFUILoadingUtility
extends GFUtility


# --- 信号 ---

## 展示状态或活动请求聚合发生变化时发出，监听方不获得内部可写状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param state: 当前聚合状态副本。
## [br]
## @schema state: Dictionary with visible:bool, pending_count:int, determinate_count:int, indeterminate_count:int, progress:float。progress 为已知进度的等权平均；无已知进度时为 0。
signal state_changed(state: Dictionary)


# --- 私有变量 ---

## 单调时间来源，默认不受游戏暂停或时间缩放影响。
## [br]
## @api private
var _clock: GFClock = GFClock.new()

## 活动请求 ID 到句柄的唯一所有权表。
## [br]
## @api private
var _leases: Dictionary[int, GFUILoadingLease] = {}

## 永不复用的服务内身份。
## [br]
## @api private
var _next_id: int = 1

## 首次出现等待后延迟显示的毫秒数。
## [br]
## @api private
var _delay_msec: int = 150

## 反馈实际显示后的最短可见毫秒数。
## [br]
## @api private
var _minimum_msec: int = 250

## 本批连续等待的开始时间；无等待为 -1。
## [br]
## @api private
var _pending_since: int = -1

## 本次连续显示的开始时间；隐藏为 -1。
## [br]
## @api private
var _visible_since: int = -1

## 最近已发布状态，用于去重与回调重入前提交。
## [br]
## @api private
var _state: Dictionary = {
	"visible": false,
	"pending_count": 0,
	"determinate_count": 0,
	"indeterminate_count": 0,
	"progress": 0.0,
}

## 配置只能在使用前完成一次，避免活动请求改变时基。
## [br]
## @api private
var _configured: bool = false

## 释放后永久关闭准入。
## [br]
## @api private
var _disposed: bool = false

## 串行发出状态通知；重入变化合并为下一轮最新状态。
## [br]
## @api private
var _notifying: bool = false

## 是否还有已提交但尚未通知的聚合状态。
## [br]
## @api private
var _notification_pending: bool = false


# --- GF 生命周期方法 ---

## 清理过期请求并刷新显示与进度，不依赖 delta 计时。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 架构帧间隔；本服务读取单调时钟。
func tick(_delta: float) -> void:
	if _disposed:
		return
	for lease: GFUILoadingLease in _leases.values():
		if lease.is_expired_for_framework():
			var _released: bool = lease.release()
	_refresh()


## 立即撤销全部 lease 并隐藏反馈，不等待显示政策。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for lease: GFUILoadingLease in _leases.values():
		lease.deactivate_for_framework()
	_leases.clear()
	_visible_since = -1
	_pending_since = -1
	_refresh()
	super.dispose()


# --- 公共方法 ---

## 在第一次 acquire 前冻结显示政策和时钟。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param display_delay_msec: 0 到 60000 毫秒。
## [br]
## @param minimum_visible_msec: 0 到 60000 毫秒；不延长业务等待。
## [br]
## @param clock: 可选单调时钟。
## [br]
## @return 首次有效配置时为 true。
func configure(
	display_delay_msec: int = 150,
	minimum_visible_msec: int = 250,
	clock: GFClock = null
) -> bool:
	if (
		_disposed
		or _configured
		or _next_id != 1
		or display_delay_msec < 0
		or display_delay_msec > 60000
		or minimum_visible_msec < 0
		or minimum_visible_msec > 60000
	):
		return false
	_configured = true
	_delay_msec = display_delay_msec
	_minimum_msec = minimum_visible_msec
	_clock = clock if clock != null else GFClock.new()
	return true


## 为一次业务等待取得独立句柄。
##
## 无 owner/scope 时必须显式释放；Node owner 必须在树中，离树立即释放。
## 普通 Object 销毁、scope.complete 或 scope 销毁在下一次 tick 释放。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 可选生命周期拥有者，服务不持有强引用。
## [br]
## @param scope: 可选活动请求作用域。
## [br]
## @param progress: 可选既有进度句柄；达到 1 不自动释放。
## [br]
## @return 新 lease；参数失效、超限或服务释放时为 null。
func acquire(
	owner: Object = null,
	scope: GFAsyncScope = null,
	progress: GFAsyncProgress = null
) -> GFUILoadingLease:
	var report: Dictionary = _validate_acquire(owner, scope)
	if not GFVariantData.get_option_bool(report, "ok"):
		return null
	var lease: GFUILoadingLease = GFUILoadingLease.new()
	var identity: int = _next_id
	_next_id += 1
	if _leases.is_empty():
		_pending_since = _clock.get_monotonic_msec()
	_leases[identity] = lease
	lease.configure_for_framework(
		self,
		identity,
		owner,
		scope,
		progress
	)
	_refresh()
	return lease


## 只读检查 acquire 的生命周期和剩余容量，不取得 lease、消耗 ID 或刷新显示。
##
## 进度未知或暂时无效仍是合法等待，故此入口不采样进度。报告不预留容量；
## acquire 在执行时重新检查。检查不会连接信号、保留 owner/scope 或触发业务回调。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 与 acquire 相同的可选生命周期 owner。
## [br]
## @param scope: 与 acquire 相同的可选活动作用域。
## [br]
## @return 当前服务与参数的独立校验报告；不输出错误日志。
## [br]
## @schema return: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。 lease_limit 的 observed 是申请本次 lease 后所需总数。
func validate_acquire(owner: Object = null, scope: GFAsyncScope = null) -> Dictionary:
	return _validate_acquire(owner, scope)


## 获取最近发布的显示状态；进度与过期生命周期在 tick 时采样。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 隔离状态副本。
## [br]
## @schema return: Dictionary with visible:bool, pending_count:int, determinate_count:int, indeterminate_count:int, progress:float，与 state_changed 一致。
func get_state() -> Dictionary:
	return _state.duplicate()


# --- 框架内部方法 ---

## 仅释放属于当前服务的精确句柄，旧 ID 或外来句柄不影响活动请求。
## [br]
## @api framework_internal
## [br]
## @param lease: 请求释放的原句柄。
## [br]
## @return 首次移除活动请求时为 true。
func release_for_framework(lease: GFUILoadingLease) -> bool:
	if lease == null or _leases.get(lease.get_id()) != lease:
		return false
	var _removed: bool = _leases.erase(lease.get_id())
	lease.deactivate_for_framework()
	if _leases.is_empty():
		_pending_since = -1
	_refresh()
	return true


# --- 私有/辅助方法 ---

## acquire 与诊断共享即时准入检查；不读取时钟、不清理旧 lease。
## [br]
## @api private
func _validate_acquire(owner: Object, scope: GFAsyncScope) -> Dictionary:
	if _disposed:
		return _validation_report("service_disposed")
	if _leases.size() >= 4096:
		return _validation_report(
			"lease_limit",
			"/leases",
			4096,
			_leases.size() + 1
		)
	if _next_id == 9223372036854775807:
		return _validation_report(
			"identity_exhausted",
			"/lease_id",
			9223372036854775806,
			_next_id
		)
	if owner != null:
		if not is_instance_valid(owner):
			return _validation_report("owner_invalid", "/owner")
		if owner is Node:
			var node: Node = owner
			if not node.is_inside_tree():
				return _validation_report("owner_outside_tree", "/owner")
	if scope != null and not scope.is_active():
		return _validation_report("scope_inactive", "/scope")
	return _validation_report()


## 每次创建独立纯数据报告，不保存全局错误或可复用的准入资格。
## [br]
## @api private
static func _validation_report(
	error_kind: String = "",
	path: String = "",
	limit: int = -1,
	observed: int = -1
) -> Dictionary:
	var report: Dictionary = {
		"ok": error_kind.is_empty(),
		"error_kind": error_kind,
		"path": path,
	}
	if limit >= 0:
		report["limit"] = limit
		report["observed"] = observed
	return report


## 先提交聚合状态再发信号，使监听方可安全 acquire/release 重入。
## [br]
## @api private
func _refresh() -> void:
	var now: int = _clock.get_monotonic_msec()
	if (
		not _disposed
		and not _leases.is_empty()
		and _visible_since < 0
		and now - _pending_since >= _delay_msec
	):
		_visible_since = now
	if (
		_leases.is_empty()
		and _visible_since >= 0
		and now - _visible_since >= _minimum_msec
	):
		_visible_since = -1
	var sum: float = 0.0
	var known: int = 0
	for lease: GFUILoadingLease in _leases.values():
		var progress: GFAsyncProgress = lease.get_progress()
		if progress != null and is_finite(progress.get_value()):
			sum += clampf(
				progress.get_value(),
				0.0,
				1.0
			)
			known += 1
	var next: Dictionary = {
		"visible": _visible_since >= 0,
		"pending_count": _leases.size(),
		"determinate_count": known,
		"indeterminate_count": _leases.size() - known,
		"progress": sum / known if known > 0 else 0.0,
	}
	if next != _state:
		_state = next
		_notification_pending = true
	_drain_notifications()


## 每次最多发布256轮重入变化，剩余状态在下一次 tick 合并发布。
## [br]
## @api private
func _drain_notifications() -> void:
	if _notifying:
		return
	_notifying = true
	var sent: int = 0
	while (
		_notification_pending
		and (
			sent < 256
			or _disposed
		)
	):
		sent += 1
		_notification_pending = false
		state_changed.emit(_state.duplicate())
	_notifying = false
