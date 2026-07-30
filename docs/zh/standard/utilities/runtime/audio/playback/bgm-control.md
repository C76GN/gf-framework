# BGM 控制

BGM 使用独立播放器，并为每次播放、incoming crossfade 和 outgoing crossfade 分配独立 session。异步加载、淡入淡出、暂停、停止和 `finished` 回调都会同时核对 generation 与 session；较旧回调完成得更晚时，不会覆盖或停止新的播放请求。

## 基本用法

```gdscript
var audio := Gf.get_utility(GFAudioUtility) as GFAudioUtility

audio.play_bgm("res://audio/bgm/explore.ogg", 0.5)

var boss_region := GFAudioPlaybackRegion.new()
boss_region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
boss_region.loop_start_seconds = 8.0
var boss_clip := GFAudioClip.new()
boss_clip.stream = preload("res://audio/bgm/boss.ogg")
boss_clip.playback_region = boss_region
audio.play_bgm_clip(boss_clip, 0.5)

audio.pause_bgm(0.2)
var bgm_position := audio.get_bgm_playback_position()
audio.resume_bgm(bgm_position, 0.2)
audio.seek_bgm(12.0)
print(audio.get_bgm_history())

audio.bgm_finished.connect(func(history_key: String) -> void:
	print("BGM finished: ", history_key)
)
```

## 生命周期与传输边界

BGM transport 接口面向暂停菜单、剧情演出、音量淡入淡出和进度恢复。`pause_bgm()` / `resume_bgm()` 使用 Godot `AudioStreamPlayer.stream_paused` 保留当前位置，`seek_bgm()` 和 `get_bgm_playback_position()` 用于显式跳转和记录。backend-owned BGM 的 `is_bgm_playing()` 与 `is_bgm_paused()` 会在同步非重入边界内查询当前后端，并在 backend/request generation/owner/session identity 仍匹配时刷新内部状态；后端回调中的重入查询只返回已有缓存，不会再次调用后端。暂停中的 session 仍由 `is_bgm_playing()` 返回 `true`，`is_bgm_paused()` 只补充 transport 状态。状态转换会失败关闭：重复暂停不会覆盖原始增益，停止、自然结束或 replacement 后的旧 resume 不会复活已经终结的 session。

`play_bgm_with_options()` 只接受 `crossfade_seconds`、`history_key`、`bus_name`、`volume_db` 和 `pitch_scale`。播放区间与循环点统一由 `GFAudioClip.playback_region` 表达；继续传入 `loop` 或 `playback_region` 通用字段会在加载或后端派发前失败关闭。具体字段、原生流能力和后端协商见[类型化播放区间与循环点](playback-regions.md)。

crossfade 完成时会原子提交 incoming 的 key 与规范化播放区间；incoming 提前结束或请求失败时，会恢复 outgoing session 自己的 key、播放区间和目标增益。本地 BGM 自然结束时会按该 session 的 `history_key` 发出 `bgm_finished(history_key)`。第三方后端必须实现 `GFAudioBackend.is_bgm_playing()`；当 Utility 查询到稳定的 backend-owned session 已结束时，也会先提交 `stopped/none`，再按同一 history key 发出且只发出一次 `bgm_finished`。调试快照会执行这次收敛查询。

`play_bgm("", crossfade_seconds)` 可按同一淡出参数停止当前 BGM。交叉淡化期间停止会终结 incoming 与 outgoing，完成后的 key、播放区间、owner 和状态统一回到空闲终态。

场景树关闭时，root 可能先于 Utility 释放本地 BGM 播放器。`dispose()` 会把已经失效或仍存活的两个播放器都收敛为空引用，并保持重复调用幂等；项目不应缓存或直接拥有 Utility 的内部播放器。
