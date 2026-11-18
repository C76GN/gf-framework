## GFDataSnapshotCapture: 从固定版本记录源按共享帧预算构造完整快照。
##
## 一个 step 是一条有界记录，不是一个任意大小的对象图。帧额度耗尽仅暂停，
## 累计数据、工作时间和生命期超限失败。失败输出逐条清理，完成前不交付快照。
## 创建时接管 source；调用方不得再读取或释放它。会话只在调用线程串行推进。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 12.0.0
class_name GFDataSnapshotCapture
extends RefCounted


# --- 常量 ---

## 限制为单次捕获独立累计，等待下一帧不会消耗 active work 时间。
## [br]
## @api private
const _DEFAULTS: Dictionary[String, int] = {
	"max_records": 1_000_000,
	"max_items": 1_000_000,
	"max_payload_bytes": 67_108_864,
	"max_depth": 64,
	"max_record_items": 4096,
	"max_record_payload_bytes": 65_536,
	"max_work_msec": 30_000,
	"max_age_msec": 120_000,
}


# --- 私有变量 ---

## 源租约在失败清理结束或成功移交之前一直保持有效。
## [br]
## @api private
var _source: GFDataSnapshotSource = null

## 注入的单调时钟只用于测量，不参与业务数据。
## [br]
## @api private
var _clock: GFClock = null

## 经创建入口校验的限制副本。
## [br]
## @api private
var _limits: Dictionary[String, int] = {}

## 等待发布或清理的记录引用，不向外暴露。
## [br]
## @api private
var _records: Array = []

## 保留适配器返回记录的所有者，使嵌套租约直到输出释放后才结算。
## [br]
## @api private
var _record_owners: Array[GFDataSnapshot] = []

## 单次成功结果；失败和未完成时为 null。
## [br]
## @api private
var _snapshot: GFDataSnapshot = null

## pending、ready、failed、cancelled 四个明确状态。
## [br]
## @api private
var _state: String = "pending"

## 稳定失败分类，无需解析日志文本。
## [br]
## @api private
var _error_kind: String = ""

## 创建时取得的记录数和版本标识，后续读取不能改变。
## [br]
## @api private
var _count: int = 0

## 固定版本的身份，仅在同一个源租约中解释。
## [br]
## @api private
var _revision: int = 0

## 已处理前缀长度，暂停不重新扫描。
## [br]
## @api private
var _position: int = 0

## 根数组自身也占一个逻辑项。
## [br]
## @api private
var _items: int = 1

## 已接纳记录的 PackedArray 元素数。
## [br]
## @api private
var _packed_items: int = 0

## 已接纳记录的逻辑 payload 字节数。
## [br]
## @api private
var _payload_bytes: int = 0

## 根数组深度为零，记录深度在原统计上增加一。
## [br]
## @api private
var _maximum_depth: int = 0

## 生命周期起点与累计实际推进耗时分别计量。
## [br]
## @api private
var _started_usec: int = 0

## 所有 advance 调用实际工作时间之和，不包括帧间等待。
## [br]
## @api private
var _work_usec: int = 0

## 外部适配器回调期间拒绝嵌套推进，取消延迟到回调返回后结算。
## [br]
## @api private
var _busy: bool = false

## 回调重入取消时只记录请求，避免释放正在读取的源。
## [br]
## @api private
var _cancel_requested: bool = false


# --- Godot 生命周期方法 ---

## 自动销毁是泄漏兜底；需要帧预算时应显式取消并推进到 settled。
## [br]
## @api private
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _source != null:
		_records.clear()
		_record_owners.clear()
		_source.release()
		_source = null


# --- 公共方法 ---

## 接管一个已经固定版本的源；不读取全部记录，不隐藏初始化复制。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param source: 本次调用独占的租约，成功与失败都会接管其释放责任。
## [br]
## @param limits: 有限捕获限制，未知字段被拒绝。
## [br]
## @schema limits: Dictionary with optional positive max_records (1000000), max_items (1000000), max_payload_bytes (67108864), max_depth (64, at most 256), max_record_items (4096), max_record_payload_bytes (65536), max_work_msec (30000), max_age_msec (120000). Per-record limits bound the admitted unit; adapter callbacks must themselves be bounded.
## [br]
## @param clock: 可选单调时钟，用于确定性预算测试；为空时使用系统时钟。
## [br]
## @return: 会话；非法输入产生已失败会话，报告说明原因。
static func begin(
	source: GFDataSnapshotSource,
	limits: Dictionary = {},
	clock: GFClock = null
) -> GFDataSnapshotCapture:
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.new()
	capture._source = source
	capture._clock = GFClock.new() if clock == null else clock
	capture._started_usec = capture._clock.get_monotonic_usec()
	capture._limits = _DEFAULTS.duplicate()
	for key: Variant in limits:
		if not capture._limits.has(key) or not limits[key] is int:
			capture._fail("invalid_limits")
			return capture
		var number: int = limits[key]
		if number <= 0 or number > 2_147_483_647:
			capture._fail("invalid_limits")
			return capture
		capture._limits[key] = number
	if capture._limits["max_depth"] > 256:
		capture._fail("invalid_limits")
		return capture
	if source == null or not source.is_available():
		capture._fail("source_unavailable")
		return capture
	capture._count = source.get_record_count()
	capture._revision = source.get_revision()
	if capture._count < 0 or capture._revision < 0:
		capture._fail("invalid_source")
		return capture
	if capture._count > int(capture._limits["max_records"]):
		capture._fail("record_limit")
		return capture
	if capture._count > int(capture._limits["max_items"]) - 1:
		capture._fail("item_limit")
		return capture
	if source is GFDataVersion:
		var version: GFDataVersion = source
		if not version.reserve_output_for_framework(capture._count * 32 + 128):
			capture._fail("memory_limit")
	return capture


## 消费调用方共享的本帧预算，或分步清理失败输出。不会重置预算。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @param budget: 本帧共享额度，一个 step 对应一条记录或一次清理；调用方每帧重置一次。
## [br]
## @return: pending、ready、failed 或 cancelled；失败不一定已物理 settled。
func advance(budget: GFExecutionBudget) -> String:
	if _busy:
		_fail("reentrant_advance")
		return _state
	if budget == null:
		_fail("invalid_frame_budget")
		return _state
	if _state != "pending":
		_cleanup(budget)
		return _state
	_busy = true
	var started: int = _clock.get_monotonic_usec()
	if not _source_matches():
		_fail("source_changed")
	_check_budget_cancellation(budget)
	if not budget.check():
		var reason: StringName = budget.get_violation_reason()
		if reason == &"cancelled":
			_cancel_requested = true
		elif reason not in [&"step_limit_exceeded", &"time_limit_exceeded"]:
			_fail("invalid_frame_budget")
	while _position < _count and _state == "pending":
		if not _check_lifetime(started):
			break
		if budget.max_elapsed_msec > 0 and budget.get_elapsed_msec() >= budget.max_elapsed_msec:
			break
		if not budget.consume_steps():
			if budget.get_violation_reason() == &"cancelled":
				_cancel_requested = true
				_fail("cancelled")
			elif budget.get_violation_reason() not in [&"step_limit_exceeded", &"time_limit_exceeded"]:
				_fail("invalid_frame_budget")
			break
		var record: GFDataSnapshot = null
		if _source is GFDataVersion:
			var version: GFDataVersion = _source
			record = version.borrow_record_for_framework(_position)
		else:
			record = _source.read_record(_position)
		_check_budget_cancellation(budget)
		if _state != "pending" or not _check_lifetime(started):
			break
		if not _source_matches():
			_fail("source_changed")
			break
		if record == null or not record.is_ready():
			_fail("record_unavailable")
			break
		if not _accept_record(record):
			break
		_position += 1
	_work_usec += maxi(
		_clock.get_monotonic_usec() - started,
		0
	)
	_busy = false
	_check_budget_cancellation(budget)
	if (
		_state == "pending"
		and _check_lifetime(_clock.get_monotonic_usec())
		and _position == _count
	):
		var report: Dictionary = _capture_statistics()
		_snapshot = GFDataSnapshot.from_records_for_framework(
			_records,
			report,
			_source,
			_record_owners,
			{
				"max_items": _limits["max_items"],
				"max_payload_bytes": _limits["max_payload_bytes"],
				"max_depth": _limits["max_depth"],
				"max_string_length": _limits["max_record_payload_bytes"],
				"max_elapsed_msec": _limits["max_work_msec"],
			}
		)
		_records = []
		_record_owners = []
		_source = null
		_state = "ready"
	if _state != "pending":
		_cleanup(budget)
	return _state


## 请求取消；若适配器正在读取，只在它返回后停止并释放。
## [br]
## @api public
## [br]
## @since 12.0.0
func cancel() -> void:
	if _state != "pending":
		return
	_cancel_requested = true
	if not _busy:
		_fail("cancelled")


## 取得完整成功快照，不允许获取部分输出。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @return: ready 时的唯一快照；否则为 null。
func get_snapshot() -> GFDataSnapshot:
	return _snapshot


## 报告逻辑结果与物理结算状态，调用不会推进操作。
## [br]
## @api public
## [br]
## @since 12.0.0
## [br]
## @return: 标量状态和累计计量副本。
## [br]
## @schema return: Dictionary with state, error_kind: String, settled: bool, processed_records, total_records, source_revision, items, payload_bytes, work_msec: int. Ready transfers the lease to the result; failed settlement requires advance with a fresh budget.
func get_report() -> Dictionary:
	return {
		"state": _state,
		"error_kind": _error_kind,
		"settled": _source == null and not _busy,
		"processed_records": _position,
		"total_records": _count,
		"source_revision": _revision,
		"items": _items,
		"payload_bytes": _payload_bytes,
		"work_msec": floori(float(_work_usec) / 1000.0),
	}


# --- 私有/辅助方法 ---

## 记录预算和累计预算独立检查，成功后才增加输出前缀。
## [br]
## @api private
func _accept_record(record: GFDataSnapshot) -> bool:
	var stats: Dictionary = record.get_statistics()
	var items: int = stats["items"]
	var payload: int = stats["payload_bytes"]
	var depth: int = stats["maximum_depth"] + 1
	if items > int(_limits["max_record_items"]) or payload > int(_limits["max_record_payload_bytes"]):
		_fail("record_budget")
		return false
	if items > int(_limits["max_items"]) - _items:
		_fail("item_limit")
		return false
	if payload > int(_limits["max_payload_bytes"]) - _payload_bytes:
		_fail("payload_limit")
		return false
	if depth > int(_limits["max_depth"]):
		_fail("depth_limit")
		return false
	_items += items
	_payload_bytes += payload
	var packed: int = stats["packed_items"]
	_packed_items += packed
	_maximum_depth = maxi(_maximum_depth, depth)
	_records.append(record.get_value_for_framework())
	if not _source is GFDataVersion:
		_record_owners.append(record)
	return true


## 帧间等待计入 age，只有实际推进计入 work；两者均为有限限制。
## [br]
## @api private
func _check_lifetime(active_start: int) -> bool:
	if _cancel_requested:
		_fail("cancelled")
		return false
	var now: int = _clock.get_monotonic_usec()
	if now - _started_usec > int(_limits["max_age_msec"]) * 1000:
		_fail("age_limit")
		return false
	if _work_usec + maxi(
		now - active_start,
		0
	) > int(_limits["max_work_msec"]) * 1000:
		_fail("work_limit")
		return false
	return true


## 共享预算保留首次违规原因；取消令牌必须独立检查，不能被此前额度耗尽遮蔽。
## [br]
## @api private
func _check_budget_cancellation(budget: GFExecutionBudget) -> void:
	if budget.cancel_token != null and budget.cancel_token.is_cancel_requested():
		_cancel_requested = true


## 元信息核对能发现协议矛盾，不能证明外部适配器底层没有原地修改。
## [br]
## @api private
func _source_matches() -> bool:
	return (
		_source != null
		and _source.is_available()
		and _source.get_revision() == _revision
		and _source.get_record_count() == _count
	)


## 只记录第一次终态，正在回调时不提前释放源。
## [br]
## @api private
func _fail(error_kind: String) -> void:
	if _state != "pending":
		return
	_error_kind = error_kind
	_state = "cancelled" if error_kind == "cancelled" else "failed"
	if (
		not _busy
		and _records.is_empty()
		and _source != null
	):
		_busy = true
		_source.release()
		_source = null
		_busy = false


## 失败输出逐条解除引用，最后才结算固定源租约。
## [br]
## @api private
func _cleanup(budget: GFExecutionBudget) -> void:
	if _state == "ready" or _busy:
		return
	_busy = true
	while not _records.is_empty() and budget.consume_steps():
		var _removed: Variant = _records.pop_back()
		_removed = null
		if not _record_owners.is_empty():
			var _removed_owner: GFDataSnapshot = _record_owners.pop_back()
			_removed_owner = null
	if _records.is_empty() and _source != null:
		_source.release()
		_source = null
	_busy = false


## 完整快照沿用同步 capture 的计量字段，避免消费者出现两套统计语义。
## [br]
## @api private
func _capture_statistics() -> Dictionary:
	return {
		"ok": true,
		"counts_complete": true,
		"items": _items,
		"packed_items": _packed_items,
		"payload_bytes": _payload_bytes,
		"maximum_depth": _maximum_depth,
		"error_kind": "",
		"error_path": "",
		"limit_kind": "",
		"limit": 0,
		"observed": 0,
	}
