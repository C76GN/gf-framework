## GFServerTimeEstimator: 服务器样本与单调时钟组合的本地时间估计器。
##
## 请求票据只属于当前实例和进程；响应记录时测量整个往返，不读取系统墙上时钟。
## 估计并非可信服务器权威，网络不对称和服务器误差通过不确定度表达。新样本可以校正
## 时间向前或向后，项目必须自行持久化周期结算身份，不能凭时间变化重复发奖。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFServerTimeEstimator
extends RefCounted


# --- 私有变量 ---

## 创建时固定的单调时钟。
## [br]
## @api private
var _clock: GFClock

## 样本过期上界，边界本身已过期。
## [br]
## @api private
var _max_age_msec: int = 300000

## 允许的最大完整往返时间。
## [br]
## @api private
var _max_rtt_msec: int = 10000

## 不确定度随样本年龄增长的百万分比。
## [br]
## @api private
var _drift_ppm: int = 50

## 未完成票据到请求起点的映射，最多16个。
## [br]
## @api private
var _pending: Dictionary = {}

## 不重用的请求票据序号。
## [br]
## @api private
var _next_ticket: int = 0

## 最近接受的票据，旧请求迟到不能覆盖它。
## [br]
## @api private
var _sample_id: int = 0

## 最近样本的响应接收时间。
## [br]
## @api private
var _received_msec: int = 0

## 接收时估计的服务器 Unix 毫秒。
## [br]
## @api private
var _server_at_receive_msec: int = 0

## 已接受样本的完整往返时间。
## [br]
## @api private
var _rtt_msec: int = 0

## 接收时的不确定度，含向上取整的半往返与服务器误差。
## [br]
## @api private
var _base_uncertainty_msec: int = 0

## 上一次观察的单调时间，用于发现测试或适配器时钟倒退。
## [br]
## @api private
var _last_monotonic_msec: int = -1

## 无样本时的明确原因；有样本时由年龄推导状态。
## [br]
## @api private
var _unavailable_status: String = "unavailable"

## 时钟倒退后须显式标记恢复并重新取样。
## [br]
## @api private
var _clock_failed: bool = false


# --- 公共方法 ---

## 创建估计器并冻结计时政策。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param clock: 单调时钟；null 使用 GFClock，永不读取其墙上时间。
## [br]
## @param options: 样本政策。
## [br]
## @schema options: 封闭 Dictionary，可选 max_age_msec:int[1,86400000]（默认300000）、max_rtt_msec:int[0,300000]（默认10000）、drift_ppm:int[0,1000000]（默认50）。
## [br]
## @return 新估计器；非法政策返回 null。
static func create(clock: GFClock = null, options: Dictionary = {}) -> GFServerTimeEstimator:
	for key: Variant in options:
		if (
			not key is String
			or key not in [
				"max_age_msec",
				"max_rtt_msec",
				"drift_ppm",
			]
			or not options[key] is int
		):
			return null
	var max_age: int = GFVariantData.get_option_int(
		options,
		"max_age_msec",
		300000
	)
	var max_rtt: int = GFVariantData.get_option_int(
		options,
		"max_rtt_msec",
		10000
	)
	var drift: int = GFVariantData.get_option_int(
		options,
		"drift_ppm",
		50
	)
	if (
		max_age < 1
		or max_age > 86400000
		or max_rtt < 0
		or max_rtt > 300000
		or drift < 0
		or drift > 1000000
	):
		return null
	var estimator: GFServerTimeEstimator = GFServerTimeEstimator.new()
	estimator._clock = clock if clock != null else GFClock.new()
	estimator._max_age_msec = max_age
	estimator._max_rtt_msec = max_rtt
	estimator._drift_ppm = drift
	return estimator


## 在发送时间请求前取得一次性票据，并捕获单调起点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数票据；时钟不可用、16个未过期请求占满或实例未初始化时为0。超时票据自动移除。
func begin_sample() -> int:
	var now: int = _observe_clock()
	if now < 0:
		return 0
	for ticket: int in _pending.keys():
		var sent: int = _pending[ticket]
		if now - sent > _max_rtt_msec:
			var _removed_expired: bool = _pending.erase(ticket)
	if _pending.size() >= 16 or _next_ticket == 9223372036854775807:
		return 0
	_next_ticket += 1
	_pending[_next_ticket] = now
	return _next_ticket


## 接收服务器时间样本，消耗对应票据并验证往返和响应顺序。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param ticket: begin_sample 返回的当前实例票据。
## [br]
## @param server_unix_msec: 服务器在该请求处理期间采样的 Unix 毫秒，范围 ±4×10^15。
## [br]
## @param server_uncertainty_msec: 项目声明的服务器时间样本误差界，范围0..86400000。
## [br]
## @return 接受并替换当前样本时为 true；失败保留先前样本。票据只可提交一次，较早请求不能覆盖较新请求的已接受样本。
func accept_sample(
	ticket: int,
	server_unix_msec: int,
	server_uncertainty_msec: int = 0
) -> bool:
	var now: int = _observe_clock()
	if now < 0 or not _pending.has(ticket):
		return false
	var sent: int = _pending[ticket]
	var _removed: bool = _pending.erase(ticket)
	var rtt: int = now - sent
	if (
		ticket <= _sample_id
		or rtt > _max_rtt_msec
		or server_unix_msec < -4000000000000000
		or server_unix_msec > 4000000000000000
	):
		return false
	if server_uncertainty_msec < 0 or server_uncertainty_msec > 86400000:
		return false
	_sample_id = ticket
	_received_msec = now
	_rtt_msec = rtt
	_server_at_receive_msec = server_unix_msec + (rtt >> 1)
	_base_uncertainty_msec = server_uncertainty_msec + (rtt >> 1) + (rtt % 2)
	_unavailable_status = "unavailable"
	return true


## 取消本地采样票据，不影响已接受样本或远端请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param ticket: 本地请求票据。
## [br]
## @return 移除了仍在等待的票据时为 true。
func cancel_sample(ticket: int) -> bool:
	return _pending.erase(ticket)


## 应用恢复或计时环境切换后立即调用；旧样本和旧请求全部失效。
## [br]
## @api public
## [br]
## @since unreleased
func mark_resumed() -> void:
	_pending.clear()
	_sample_id = 0
	_unavailable_status = "resumed"
	_last_monotonic_msec = _clock.get_monotonic_msec() if _clock != null else -1
	_clock_failed = _last_monotonic_msec < 0
	if _clock_failed:
		_unavailable_status = "clock_regressed"


## 读取估计和完整可用状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前估计记录；只有 available=true 时才能使用 Unix 值及上下界。
## [br]
## @schema return: 封闭九字段 Dictionary：status:String（available/unavailable/expired/resumed/clock_regressed）、available:bool、unix_time_msec:int、lower_bound_msec:int、upper_bound_msec:int、sample_age_msec:int、round_trip_msec:int、uncertainty_msec:int、sample_id:int。不可用时三个Unix值为0；无样本时年龄、RTT和不确定度为-1；过期样本保留年龄和RTT但不提供不确定度。区间只覆盖给定误差与漂移政策，不保证服务器真实性。
func get_estimate() -> Dictionary:
	var now: int = _observe_clock()
	var status: String = _unavailable_status
	var age: int = -1
	var uncertainty: int = -1
	var estimate: int = 0
	if now >= 0 and _sample_id > 0:
		age = now - _received_msec
		status = "expired" if age >= _max_age_msec else "available"
		if status == "available":
			estimate = _server_at_receive_msec + age
			uncertainty = _base_uncertainty_msec + ceili(float(age) * float(_drift_ppm) / 1000000.0)
	var available: bool = status == "available"
	return {
		"status": status,
		"available": available,
		"unix_time_msec": estimate,
		"lower_bound_msec": estimate - uncertainty if available else 0,
		"upper_bound_msec": estimate + uncertainty if available else 0,
		"sample_age_msec": age,
		"round_trip_msec": _rtt_msec if _sample_id > 0 else -1,
		"uncertainty_msec": uncertainty,
		"sample_id": _sample_id,
	}


# --- 私有/辅助方法 ---

## 只读单调时钟，发现倒退后保持不可用直到显式恢复。
## [br]
## @api private
func _observe_clock() -> int:
	if _clock == null or _clock_failed:
		return -1
	var now: int = _clock.get_monotonic_msec()
	if now < 0 or now < _last_monotonic_msec:
		_clock_failed = true
		_unavailable_status = "clock_regressed"
		_pending.clear()
		_sample_id = 0
		return -1
	_last_monotonic_msec = now
	return now
