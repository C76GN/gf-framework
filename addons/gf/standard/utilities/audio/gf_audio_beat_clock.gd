## GFAudioBeatClock: 通用音频节拍时钟。
##
## 将任意播放时间映射为 beat、measure 和进度快照，并在手动 update() 时发出越过的节拍边界。
## 它不持有播放器、不创建节点，也不规定节奏玩法、字幕或演出语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 4.2.0
class_name GFAudioBeatClock
extends RefCounted


# --- 信号 ---

## update() 采样时间并刷新快照后发出。
## [br]
## @api public
## [br]
## @param snapshot: 当前节拍快照。
## [br]
## @schema snapshot: Dictionary，包含 position_seconds、adjusted_seconds、beat_index、measure_index、beat_progress 和 measure_progress 等字段。
signal position_updated(snapshot: Dictionary)

## update() 检测到新的 beat 边界后发出。
## [br]
## @api public
## [br]
## @param beat_index: 从 0 开始的全局 beat 索引。
## [br]
## @param beat_in_measure: 当前小节内的 beat 索引。
## [br]
## @param position_seconds: 该 beat 边界对应的播放时间。
signal beat_reached(beat_index: int, beat_in_measure: int, position_seconds: float)

## update() 检测到新的 measure 边界后发出。
## [br]
## @api public
## [br]
## @param measure_index: 从 0 开始的小节索引。
## [br]
## @param beat_index: 该小节起点对应的全局 beat 索引。
## [br]
## @param position_seconds: 该小节边界对应的播放时间。
signal measure_reached(measure_index: int, beat_index: int, position_seconds: float)


# --- 枚举 ---

## 量化时间时使用的舍入方式。
## [br]
## @api public
enum QuantizeMode {
	## 量化到最近的网格点。
	NEAREST,
	## 量化到不大于当前时间的网格点。
	FLOOR,
	## 量化到不小于当前时间的网格点。
	CEIL,
}


# --- 常量 ---

## 默认 BPM。
## [br]
## @api public
const DEFAULT_BPM: float = 120.0

## 默认每小节 beat 数。
## [br]
## @api public
const DEFAULT_BEATS_PER_MEASURE: int = 4

## 每次 update() 默认最多补发的 beat 边界数量。
## [br]
## @api public
const DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE: int = 64

const _MIN_BPM: float = 0.001


# --- 公共变量 ---

## 当前 BPM。小于等于 0 时会按极小正数处理，避免除零。
## [br]
## @api public
var bpm: float = DEFAULT_BPM

## 每小节 beat 数。小于 1 时按 1 处理。
## [br]
## @api public
var beats_per_measure: int = DEFAULT_BEATS_PER_MEASURE

## 时间偏移，单位秒。采样时使用 position_seconds + offset_seconds 计算节拍。
## [br]
## @api public
var offset_seconds: float = 0.0

## 首次 update() 是否立刻发出当前 beat 和 measure 边界事件。
## [br]
## @api public
var emit_initial_events: bool = false

## 每次 update() 最多补发的 beat 边界数量。小于等于 0 时不补发边界事件。
## [br]
## @api public
var max_emitted_steps_per_update: int = DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE

## 可选播放位置来源。update_from_source() 会调用它并期望得到秒数。
## [br]
## @api public
var position_source: Callable = Callable()

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary metadata for tooling or project-specific routing.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _has_last_position: bool = false
var _last_position_seconds: float = 0.0
var _last_beat_index: int = -1
var _last_snapshot: Dictionary = {}


# --- 公共方法 ---

## 配置节拍参数。
## [br]
## @api public
## [br]
## @param next_bpm: BPM。
## [br]
## @param next_beats_per_measure: 每小节 beat 数。
## [br]
## @param next_offset_seconds: 时间偏移，单位秒。
## [br]
## @param should_reset: 为 true 时清除上一帧边界状态。
func configure(
	next_bpm: float,
	next_beats_per_measure: int = DEFAULT_BEATS_PER_MEASURE,
	next_offset_seconds: float = 0.0,
	should_reset: bool = true
) -> void:
	bpm = maxf(next_bpm, _MIN_BPM)
	beats_per_measure = maxi(next_beats_per_measure, 1)
	offset_seconds = next_offset_seconds
	if should_reset:
		clear()


## 设置播放位置来源。
## [br]
## @api public
## [br]
## @param source: 返回播放秒数的回调。
func set_position_source(source: Callable) -> void:
	position_source = source


## 清除上一帧状态。
## [br]
## @api public
func clear() -> void:
	_has_last_position = false
	_last_position_seconds = 0.0
	_last_beat_index = -1
	_last_snapshot = {}


## 将时钟状态重置到指定播放时间，不发出边界事件。
## [br]
## @api public
## [br]
## @param position_seconds: 播放时间，单位秒。
## [br]
## @return 重置后的快照。
## [br]
## @schema return: Dictionary，结构同 sample()。
func reset(position_seconds: float = 0.0) -> Dictionary:
	var snapshot: Dictionary = sample(position_seconds)
	_store_snapshot(snapshot)
	return snapshot


## 从 position_source 采样并更新时钟。
## [br]
## @api public
## [br]
## @return 当前节拍快照；来源无效或返回非数字时返回空字典。
## [br]
## @schema return: Dictionary，结构同 sample()。
func update_from_source() -> Dictionary:
	if not position_source.is_valid():
		return {}

	var value: Variant = position_source.call()
	if not _is_number(value):
		return {}
	return update(GFVariantData.to_float(value))


## 采样指定播放时间、刷新状态并发出越过的边界事件。
## [br]
## @api public
## [br]
## @param position_seconds: 播放时间，单位秒。
## [br]
## @return 当前节拍快照。
## [br]
## @schema return: Dictionary，包含 position_seconds、adjusted_seconds、bpm、seconds_per_beat、beats_per_measure、beat_float、beat_index、beat_in_measure、beat_progress、measure_index、measure_progress 和 measure_start_beat。
func update(position_seconds: float) -> Dictionary:
	var snapshot: Dictionary = sample(position_seconds)
	var beat_index: int = GFVariantData.get_option_int(snapshot, "beat_index")
	var had_last_position: bool = _has_last_position
	var previous_beat_index: int = _last_beat_index
	var safe_beats_per_measure: int = GFVariantData.get_option_int(snapshot, "beats_per_measure", get_beats_per_measure())
	var seconds_per_beat: float = GFVariantData.get_option_float(snapshot, "seconds_per_beat", get_seconds_per_beat())
	var snapshot_offset_seconds: float = offset_seconds
	var max_emitted_steps: int = max_emitted_steps_per_update

	_store_snapshot(snapshot)

	if had_last_position:
		_emit_crossed_boundaries(
			previous_beat_index + 1,
			beat_index,
			safe_beats_per_measure,
			seconds_per_beat,
			snapshot_offset_seconds,
			max_emitted_steps
		)
	elif emit_initial_events:
		_emit_crossed_boundaries(
			beat_index,
			beat_index,
			safe_beats_per_measure,
			seconds_per_beat,
			snapshot_offset_seconds,
			max_emitted_steps
		)

	position_updated.emit(snapshot.duplicate(true))
	return snapshot


## 采样指定播放时间但不修改时钟状态。
## [br]
## @api public
## [br]
## @param position_seconds: 播放时间，单位秒。
## [br]
## @return 节拍快照。
## [br]
## @schema return: Dictionary，包含 position_seconds、adjusted_seconds、bpm、seconds_per_beat、beats_per_measure、beat_float、beat_index、beat_in_measure、beat_progress、measure_index、measure_progress 和 measure_start_beat。
func sample(position_seconds: float) -> Dictionary:
	var safe_position: float = maxf(position_seconds, 0.0)
	var adjusted_seconds: float = maxf(safe_position + offset_seconds, 0.0)
	var seconds_per_beat: float = get_seconds_per_beat()
	var safe_beats_per_measure: int = get_beats_per_measure()
	var beat_float: float = adjusted_seconds / seconds_per_beat
	var beat_index: int = floori(beat_float)
	var measure_index: int = floori(float(beat_index) / float(safe_beats_per_measure))
	var beat_in_measure: int = beat_index % safe_beats_per_measure
	var beat_progress: float = beat_float - floor(beat_float)
	var measure_beat_float: float = beat_float - float(measure_index * safe_beats_per_measure)
	var measure_progress: float = measure_beat_float / float(safe_beats_per_measure)
	return {
		"position_seconds": safe_position,
		"adjusted_seconds": adjusted_seconds,
		"bpm": get_bpm(),
		"seconds_per_beat": seconds_per_beat,
		"beats_per_measure": safe_beats_per_measure,
		"beat_float": beat_float,
		"beat_index": beat_index,
		"beat_in_measure": beat_in_measure,
		"beat_progress": beat_progress,
		"measure_index": measure_index,
		"measure_progress": measure_progress,
		"measure_start_beat": measure_index * safe_beats_per_measure,
	}


## 获取经过安全收窄的 BPM。
## [br]
## @api public
## [br]
## @return BPM。
func get_bpm() -> float:
	return maxf(bpm, _MIN_BPM)


## 获取经过安全收窄的每小节 beat 数。
## [br]
## @api public
## [br]
## @return 每小节 beat 数。
func get_beats_per_measure() -> int:
	return maxi(beats_per_measure, 1)


## 获取每个 beat 的秒数。
## [br]
## @api public
## [br]
## @return 秒数。
func get_seconds_per_beat() -> float:
	return 60.0 / get_bpm()


## 获取每小节的秒数。
## [br]
## @api public
## [br]
## @return 秒数。
func get_seconds_per_measure() -> float:
	return get_seconds_per_beat() * float(get_beats_per_measure())


## 将持续时间秒数转换为 beat 数，不应用 offset_seconds。
## [br]
## @api public
## [br]
## @param duration_seconds: 持续时间，单位秒。
## [br]
## @return beat 数。
func seconds_to_beats(duration_seconds: float) -> float:
	return maxf(duration_seconds, 0.0) / get_seconds_per_beat()


## 将 beat 数转换为持续时间秒数，不应用 offset_seconds。
## [br]
## @api public
## [br]
## @param beat_count: beat 数。
## [br]
## @return 持续时间秒数。
func beats_to_seconds(beat_count: float) -> float:
	return maxf(beat_count, 0.0) * get_seconds_per_beat()


## 将播放时间转换为 beat 数，会应用 offset_seconds。
## [br]
## @api public
## [br]
## @param position_seconds: 播放时间，单位秒。
## [br]
## @return beat 数。
func position_to_beats(position_seconds: float) -> float:
	return seconds_to_beats(maxf(position_seconds + offset_seconds, 0.0))


## 获取指定 beat 边界对应的播放时间，会反向应用 offset_seconds。
## [br]
## @api public
## [br]
## @param beat_index: beat 索引。
## [br]
## @return 播放时间，单位秒。
func beat_to_position_seconds(beat_index: int) -> float:
	return maxf(beats_to_seconds(float(maxi(beat_index, 0))) - offset_seconds, 0.0)


## 量化播放时间到 beat 网格。
## [br]
## @api public
## [br]
## @param position_seconds: 播放时间，单位秒。
## [br]
## @param subdivisions_per_beat: 每个 beat 的细分数量。
## [br]
## @param mode: 量化方式。
## [br]
## @return 量化后的播放时间，单位秒。
func quantize_position(
	position_seconds: float,
	subdivisions_per_beat: int = 1,
	mode: QuantizeMode = QuantizeMode.NEAREST
) -> float:
	var safe_subdivisions: int = maxi(subdivisions_per_beat, 1)
	var step_beats: float = 1.0 / float(safe_subdivisions)
	var beat_value: float = position_to_beats(position_seconds)
	var quantized_steps: float = 0.0
	match mode:
		QuantizeMode.FLOOR:
			quantized_steps = floor(beat_value / step_beats)
		QuantizeMode.CEIL:
			quantized_steps = ceil(beat_value / step_beats)
		_:
			quantized_steps = round(beat_value / step_beats)
	return maxf(beats_to_seconds(quantized_steps * step_beats) - offset_seconds, 0.0)


## 获取上一帧快照副本。
## [br]
## @api public
## [br]
## @return 快照副本。
## [br]
## @schema return: Dictionary，结构同 sample()；尚未 update/reset 时为空。
func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


## 获取上一帧播放位置。
## [br]
## @api public
## [br]
## @return 播放时间，单位秒。
func get_last_position_seconds() -> float:
	return _last_position_seconds


## 检查时钟是否已经有上一帧状态。
## [br]
## @api public
## [br]
## @return 已有状态时返回 true。
func has_last_position() -> bool:
	return _has_last_position


# --- 私有/辅助方法 ---

func _store_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot.duplicate(true)
	_last_position_seconds = GFVariantData.get_option_float(snapshot, "position_seconds")
	_last_beat_index = GFVariantData.get_option_int(snapshot, "beat_index", -1)
	_has_last_position = true


func _emit_crossed_boundaries(
	first_beat_index: int,
	last_beat_index: int,
	safe_beats_per_measure: int,
	seconds_per_beat: float,
	snapshot_offset_seconds: float,
	max_emitted_steps: int
) -> void:
	if max_emitted_steps <= 0:
		return
	if last_beat_index < first_beat_index:
		return

	var emitted_count: int = 0
	var safe_first_beat_index: int = maxi(first_beat_index, 0)
	for beat_index: int in range(safe_first_beat_index, last_beat_index + 1):
		if emitted_count >= max_emitted_steps:
			return

		var beat_in_measure: int = beat_index % safe_beats_per_measure
		var position_seconds: float = _beat_to_position_seconds_for_timing(
			beat_index,
			seconds_per_beat,
			snapshot_offset_seconds
		)
		beat_reached.emit(beat_index, beat_in_measure, position_seconds)
		if beat_in_measure == 0:
			var measure_index: int = floori(float(beat_index) / float(safe_beats_per_measure))
			measure_reached.emit(measure_index, beat_index, position_seconds)
		emitted_count += 1


func _beat_to_position_seconds_for_timing(
	beat_index: int,
	seconds_per_beat: float,
	snapshot_offset_seconds: float
) -> float:
	return maxf(float(maxi(beat_index, 0)) * maxf(seconds_per_beat, 0.0) - snapshot_offset_seconds, 0.0)


func _is_number(value: Variant) -> bool:
	return value is int or value is float
