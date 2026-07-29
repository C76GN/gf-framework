# 类型化播放区间与循环点

`GFAudioPlaybackRegion` 把播放起点、自然或显式终点、循环模式和循环起点放进一份资源化契约，`GFAudioPlaybackRegionResult` 则明确报告 `NONE`、`VALID`、`APPLIED`、`INVALID` 或 `UNSUPPORTED`。`NONE` 只表示尚未执行；`VALID` 表示结构已验证；只有 `APPLIED` 才表示执行者精确接受。区间只挂在 `GFAudioClip.playback_region` 上；路径播放选项以及事件 metadata/options 中的 `loop`、`playback_region` 都是保留键，不能形成平行事实来源，因此本地播放器、异步加载和第三方后端看到的是同一份请求快照。

```gdscript
var region := GFAudioPlaybackRegion.new()
region.start_seconds = 4.0
region.end_seconds = 18.0
region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
region.loop_start_seconds = 8.0

var clip := GFAudioClip.new()
clip.stream = preload("res://audio/music/explore.wav")
clip.playback_region = region

var audio := Gf.get_utility(GFAudioUtility) as GFAudioUtility
audio.play_bgm_clip(clip, 0.25)
```

`end_seconds = -1` 表示使用自然结尾；`loop_start_seconds = -1` 表示从 `start_seconds` 开始循环。这两个哨兵必须精确等于 `-1`，接近值不会被近似接受。启用循环后，循环起点必须位于播放起点和有效终点之间。不循环时不得填写循环起点，并且本地路径只接受自然终点；显式有限终点需要能原生精确执行它的后端。字段含 `NaN` / `Inf`、负边界、空区间或越过已知流长度时，请求会在加载或后端副作用前以 `INVALID` 失败。

## 原生表达能力

本地实现只接受 Godot 音频流能够原生且精确表达的组合，不通过 `_process()`、Timer 或每帧 seek 模拟有限终点。

| 音频流 | 起点 | 循环模式 | 终点约束 |
| --- | --- | --- | --- |
| PCM / QOA WAV | 支持 | forward、ping-pong | 循环终点可按帧设置；非循环只能使用自然结尾 |
| IMA ADPCM WAV | 只能为 0 | 只能 forward | 循环终点可按帧设置；非循环只能使用自然结尾 |
| Ogg Vorbis / MP3 | 支持 | 只能 forward | 只能循环到自然结尾 |
| `AudioStreamPlaylist` | 只能为 0 | 只支持全流 forward | 只能使用自然结尾 |
| 其他 `AudioStream` | 本地不接管 | 本地不接管 | 需要显式后端区间协议 |

Godot WAV 的原生 `loop_end` 是最后一个有效帧索引；GF 会把秒数终点先量化为排他边界，再写入 `boundary - 1`，保证末点始终小于样本数。原生 backward 会在调用方指定的播放起点立即反向，无法保持“先从区间终点反向”的类型化语义，因此本地明确拒绝，支持该语义的后端仍可逐请求返回 `APPLIED`。Ogg Vorbis / MP3 的私有 forward 副本会清除 `beat_count`，避免 BPM 元数据把自然结尾循环缩短为节拍终点，源资源不受影响。

有效但不能由当前流精确表达的组合返回 `UNSUPPORTED`。`INVALID` 表示请求本身有误，不能换后端重试；`UNSUPPORTED` 表示当前执行者不能完成，Utility 可以在后端拒绝后尝试本地实现。若本地仍不支持，则本次播放不落地。

每次本地播放都会先复制 `AudioStream`，只在 session 私有副本上写循环属性，导入资源、Bank 中的共享流和调用方持有的流不会被修改。BGM、环境音、普通 SFX 与 2D/3D 空间 SFX 共用这条准备路径。异步加载开始时也会复制 `GFAudioClip` 和播放区间，调用方随后修改原资源不会改变在途请求。

## 后端协商与诊断

第三方后端若要接管任何带 `playback_region` 的片段，必须同时：

1. 在 `GFAudioBackendCapability.supports_playback_region_contract` 中声明实现了协商协议。
2. 让 `can_handle_clip()` 接受当前片段和通道。
3. 通过无副作用的 `evaluate_playback_region()` 对该次请求返回 `APPLIED`。

粗粒度能力标记只用于发现协议实现，不能替代逐片段、逐通道判断。后端只有返回 `APPLIED` 才算接受；`NONE` 或 `VALID` 都会按未应用处理。`UNSUPPORTED` 仍允许本地回退；`INVALID` 会立即终止请求。Utility 会用验证结果重建规范化区间，并写入不向后端暴露的权威 clip/context；probe、评估和执行回调分别收到内容一致的一次性副本。后端改写回调参数不会改变后续协商或本地回退，也不得保存参数并在稍后重新读取。

`playback_region_rejected(channel, reason)` 提供不含音频载荷的拒绝通知，并保留本次调用的原始 channel，便于项目内即时处理。持久诊断边界更严格：`get_last_playback_region_rejection()` 和 `get_debug_snapshot()` 中的 `last_playback_region_rejection.channel` 只保留 `bgm`、`ambient`、`sfx`、`spatial_sfx`，其余项目通道统一记为 `custom`。当前 BGM 与环境音 session 的规范化区间分别位于 `current_bgm_region` 和 `ambient_sessions.*.playback_region`；环境音只有在确认进入 `stopped` 后才清空区间，停止拒绝或淡出中的非终态会继续保留区间和目标增益。若淡出被替换打断而替换失败，Utility 会一起恢复两者。所有报告只描述稳定状态、原因和边界，不包含流数据、资源内容或项目自定义通道值。
