## GFFrameIntervalSeries: 按采样顺序保存定长的正整数微秒帧间隔，按需统计分位数和连续慢帧窗口。
## 调用方选定时钟、采样边界和预算，并在同一线程串行记录与读取。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFFrameIntervalSeries
extends RefCounted


# --- 常量 ---

## 可配置的最大保留间隔数，限制环形缓冲和摘要临时数组的大小。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_CAPACITY: int = 65536

## 累计计数饱和值与微秒总和的表示上限。
## [br]
## @api private
const _MAX_I64: int = 9223372036854775807


# --- 私有变量 ---

## 固定容量的间隔缓冲，只有从 _head 开始的 _count 个槽有效。
## [br]
## @api private
var _intervals: PackedInt64Array = PackedInt64Array()

## 对应间隔开始新连续段时为 1，窗口不能向它之前延伸。
## [br]
## @api private
var _segment_starts: PackedByteArray = PackedByteArray()

## 最旧保留间隔的物理下标。
## [br]
## @api private
var _head: int = 0

## 当前保留的有效间隔数。
## [br]
## @api private
var _count: int = 0

## 下一次成功写入是否开启新连续段。
## [br]
## @api private
var _starts_next: bool = true

## 累计被新间隔覆盖的有效样本数。
## [br]
## @api private
var _evicted_count: int = 0

## 调用方在断点处明确报告的累计缺失间隔数。
## [br]
## @api private
var _missing_count: int = 0

## 累计拒绝的非正间隔数。
## [br]
## @api private
var _rejected_count: int = 0


# --- 公共方法 ---

## 创建固定容量序列并一次分配记录空间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param capacity: 保留的间隔数，取值 1 至 MAX_CAPACITY。
## [br]
## @return: 可记录的空序列。容量无效或分配失败时返回 null。
static func create(capacity: int) -> GFFrameIntervalSeries:
	if capacity < 1 or capacity > MAX_CAPACITY:
		return null
	var series: GFFrameIntervalSeries = GFFrameIntervalSeries.new()
	if series._intervals.resize(capacity) != OK or series._segment_starts.resize(capacity) != OK:
		return null
	return series


## 记录一段相邻采样边界之间的耗时。写满后覆盖最旧项。非正间隔会计入拒绝数并切断连续性。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param interval_us: 同一单调时钟测得的正整数微秒差值。
## [br]
## @return: 记录成功返回 true。未创建缓冲或间隔无效返回 false。
func record_interval_us(interval_us: int) -> bool:
	var capacity: int = _intervals.size()
	if capacity == 0:
		return false
	if interval_us <= 0:
		_rejected_count = _saturating_add(_rejected_count, 1)
		_starts_next = true
		return false
	var slot: int = (_head + _count) % capacity
	if _count == capacity:
		_head = (_head + 1) % capacity
		_evicted_count = _saturating_add(_evicted_count, 1)
	else:
		_count += 1
	_intervals[slot] = interval_us
	_segment_starts[slot] = int(_starts_next)
	_starts_next = false
	return true


## 在暂停、采样源切换或漏采时开始新的连续段。旧样本继续参与分位数统计。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param known_missing: 已知漏采的间隔数。未知数量或主动暂停传 0，负数无效。
## [br]
## @return: 接受断点返回 true。未创建缓冲或参数无效返回 false 并保留原状态。
func break_continuity(known_missing: int = 0) -> bool:
	if _intervals.is_empty() or known_missing < 0:
		return false
	_missing_count = _saturating_add(_missing_count, known_missing)
	_starts_next = true
	return true


## 按最近秩统计保留样本的 P95 与 P99，并扫描各连续段中耗时最大的完整窗口。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param window_frames: 一个完整窗口所需的相邻间隔数，必须为正数。
## [br]
## @param budget_us: 非负微秒预算，仅严格超过预算的间隔计入 over_budget_count。
## [br]
## @return: 以微秒为单位的独立摘要。空序列的分位数和均值、没有完整窗口时的窗口耗时均为 null。
## [br]
## @schema return: Dictionary。成功含 ok=true、capacity、sample_count、total_us、mean_us、p95_us、p99_us、over_budget_count、max_window_us，以及饱和于 int64 最大值的累计 evicted_count、missing_count、rejected_count。失败仅含 ok=false 和 error，值为 unprepared、invalid_query、allocation_failed 或 duration_overflow。
func summarize(window_frames: int, budget_us: int) -> Dictionary:
	var capacity: int = _intervals.size()
	if capacity == 0:
		return { "ok": false, "error": &"unprepared" }
	if window_frames <= 0 or budget_us < 0:
		return { "ok": false, "error": &"invalid_query" }
	var sorted: PackedInt64Array = PackedInt64Array()
	if sorted.resize(_count) != OK:
		return { "ok": false, "error": &"allocation_failed" }
	var total_us: int = 0
	var over_budget_count: int = 0
	var window_us: int = 0
	var window_count: int = 0
	var max_window_us: int = 0
	for index: int in range(_count):
		var slot: int = (_head + index) % capacity
		var interval: int = _intervals[slot]
		if total_us > _MAX_I64 - interval:
			return { "ok": false, "error": &"duration_overflow" }
		total_us += interval
		over_budget_count += int(interval > budget_us)
		sorted[index] = interval
		if _segment_starts[slot] != 0:
			window_count = 0
			window_us = 0
		if window_count == window_frames:
			window_us -= _intervals[(_head + index - window_frames) % capacity]
		else:
			window_count += 1
		window_us += interval
		if window_count == window_frames:
			max_window_us = maxi(max_window_us, window_us)
	sorted.sort()
	var mean_us: Variant = null
	var complete_window_us: Variant = null
	if _count > 0:
		mean_us = float(total_us) / _count
	if max_window_us > 0:
		complete_window_us = max_window_us
	return {
		"ok": true,
		"capacity": capacity,
		"sample_count": _count,
		"total_us": total_us,
		"mean_us": mean_us,
		"p95_us": _nearest_rank(sorted, 95),
		"p99_us": _nearest_rank(sorted, 99),
		"over_budget_count": over_budget_count,
		"max_window_us": complete_window_us,
		"evicted_count": _evicted_count,
		"missing_count": _missing_count,
		"rejected_count": _rejected_count,
	}


# --- 私有/辅助方法 ---

## 从已排序的副本取 ceil(p*n/100) 的一基秩。容量上限保证索引乘法可表示。
## [br]
## @api private
static func _nearest_rank(sorted: PackedInt64Array, percentile: int) -> Variant:
	if sorted.is_empty():
		return null
	@warning_ignore("integer_division")
	var index: int = (percentile * sorted.size() + 99) / 100 - 1
	return sorted[index]


## 诊断计数饱和后仍可继续记录样本和划分连续段。
## [br]
## @api private
static func _saturating_add(current: int, increment: int) -> int:
	return current + mini(
		increment,
		_MAX_I64 - current
	)
