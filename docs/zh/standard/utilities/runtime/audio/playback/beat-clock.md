# 节拍时钟

`GFAudioBeatClock` 把任意播放时间转换为 beat、measure 和进度快照，并在 `update()` 推进时发出越过的节拍边界。它不持有播放器、不注册到架构容器，也不规定节奏玩法、字幕、演出或 UI 语义。

## 定位

适合在需要“按音乐时间对齐”的地方复用同一套节拍网格，例如 BGM 播放位置、外部音频后端时间、录制回放时间或项目自定义时间源。时钟只处理 BPM、拍号、offset、量化和边界事件；播放、暂停、资源加载和总线控制仍由 `GFAudioUtility` 或项目音频后端负责。

## 常用 API

```gdscript
var clock := GFAudioBeatClock.new()
clock.configure(120.0, 4, 0.0)
clock.set_position_source(func() -> float:
	return audio.get_bgm_playback_position()
)

clock.beat_reached.connect(func(beat_index: int, beat_in_measure: int, position_seconds: float) -> void:
	pass
)

clock.update_from_source()
```

`sample(position_seconds)` 只返回快照，不修改内部状态也不发信号。`update(position_seconds)` 会保存上一帧状态，补发从上一帧到当前时间之间越过的 beat 边界，并发出 `position_updated(snapshot)`。

## 快照字段

快照包含 `position_seconds`、`adjusted_seconds`、`bpm`、`seconds_per_beat`、`beats_per_measure`、`beat_float`、`beat_index`、`beat_in_measure`、`beat_progress`、`measure_index`、`measure_progress` 和 `measure_start_beat`。

`offset_seconds` 会参与节拍计算：采样时使用 `position_seconds + offset_seconds`，反查 beat 边界时间时再减回 offset。这样可以对齐有前奏、空拍或导入偏移的音频，但不改变外部播放器的真实播放时间。

## 边界事件

`beat_reached` 和 `measure_reached` 只由 `update()` 或 `update_from_source()` 触发。首次更新默认不发当前边界，避免一创建时就触发业务动作；需要首帧触发时可设置 `emit_initial_events = true`。

`max_emitted_steps_per_update` 限制单次更新最多补发多少个 beat 边界，避免长时间暂停或大跨度 seek 后一次性发出过多事件。小于等于 0 时不补发边界事件，只更新快照。

## 量化

`quantize_position(position_seconds, subdivisions_per_beat, mode)` 可把时间吸附到 beat 网格或细分网格。它只返回量化后的秒数，不执行 seek、不修改播放器，也不触发事件。

## 使用边界

- `GFAudioBeatClock` 不读取 `AudioServer` 延迟，也不自动校正混音线程时间；如果项目需要平台级校正，应在 `position_source` 中提供已经校正过的秒数。
- 时钟不处理音频播放状态。暂停时是否继续调用 `update()` 由调用方决定。
- 倒退 seek 会重置上一帧边界比较，不会补发倒退区间的历史事件。
