# 音频后端与事件资源

需要接入外部音频中间件、平台事件音频或项目自定义混音系统时，可以继承 `GFAudioBackend` 并通过 `set_audio_backend()` 注入。

## 后端接入

后端只有在 `can_handle_path()` 或 `can_handle_clip()` 明确返回 `true` 时才接管请求；播放失败或不支持的请求会继续走默认 Godot 播放路径。带 `GFAudioPlaybackRegion` 的片段还必须先通过逐请求区间协商。

```gdscript
class_name ProjectAudioBackend
extends GFAudioBackend

func can_handle_path(path: String, channel: StringName, _context: Dictionary = {}) -> bool:
	return channel == &"sfx" and path.begins_with("event://")

func play_sfx_path(path: String, options: Dictionary = {}) -> GFAudioEmitterHandle:
	# 项目层把 path 映射到自己的音频事件。
	return GFAudioEmitterHandle.new(null, Callable(), &"external", options)

if not audio.set_audio_backend(ProjectAudioBackend.new()):
	push_error("当前后端拒绝释放已拥有的音频通道。")
audio.play_sfx("event://ui/confirm")
```

`GFAudioBackend` 是协议层，不内置任何第三方 SDK、事件命名或业务状态。后端可选择只处理部分 BGM、BGM transport、SFX、stop-all SFX、环境音、空间音效、总线音量、总线静音、总线效果属性或混音快照，其余请求保持默认行为。mix snapshot 的 bulk 接口返回 `false` 后，Utility 仍会按 gain / mute 字段逐项询问同一个 backend，只有明确拒绝的字段才进入本地原子回退；同名 `Master` / `BGM` 不会让 `AudioServer` 抢先接管。任何 backend 总线若要支持 `duck_bus()`，无论是否存在同名 Godot 总线，都必须同时实现 `get_bus_volume()`、`set_bus_volume_db()`、`set_bus_mute()` 和 `get_bus_mute()`；两项查询都表示未处理时才会回退本地，部分可观测会失败关闭。BGM、每个环境音 channel 和每个 duck 总线都显式记录 local/backend owner；后端接管、后端替换、回退本地或 Utility dispose 时会先收敛旧 owner，迟到的本地加载与淡出回调不会形成双重播放。

后端需要接管类型化区间时，应把 `supports_playback_region_contract` 设为 `true`，并实现无副作用的 `evaluate_playback_region(clip, channel, region, context)`。只有该次请求返回 `APPLIED` 后 Utility 才调用对应 `play_*_clip()`，或在资源化事件路径调用 `post_event()`；`NONE` / `VALID` 不代表已应用，`UNSUPPORTED` 允许转入本地原生能力判断，`INVALID` 会终止请求。能力标记不能代替逐次评估，也不能把近似 seek、Timer 停止或后台轮询伪装成精确支持。完整边界见[类型化播放区间与循环点](playback/playback-regions.md)。

`set_audio_backend()` 与 `clear_audio_backend()` 都返回 `bool`，调用方必须检查结果。替换或显式清除前，Utility 会按确定顺序停止当前后端拥有的 BGM 与环境音 channel，再按记录的 owner/backend identity 恢复并清除全部活跃 duck 作用域。某个 `stop_*()` 返回 `true` 且通过 backend/request/owner identity 复核后，该通道会立即提交为 `stopped`；若后续通道或 duck 基准拒绝恢复，本次 detach/replace 返回 `false`，原 backend 保持绑定且不会被 dispose，但已经确认停止的通道不会被伪装成仍在播放或回滚 owner。修正后端状态后重试时，只会处理仍未收敛的状态。

`dispose()` 属于不可重试的生命周期终态，不沿用 detach/replace 的保留语义。即使后端拒绝停止 owned channel 或 dispose 发生在后端回调边界内，Utility 也会记录 warning，强制解除内部 owner，恢复仍登记的 duck 总线基准，终结全部本地 playback handle，释放根播放器，并 dispose 或至少解除当前后端引用。架构释放因此不会被第三方后端的返回值卡住。

`stop_all_ambient()` 会先对 backend-owned channel 调用一次后端 `stop_all_ambient()`。批量停止返回 `true` 且所有 channel identity 仍匹配时，Utility 一次性把这些会话提交为 `stopped/none`；后端未实现或拒绝批量停止时，再按稳定 channel 顺序逐个调用 `stop_ambient()`，只提交后端确认成功的通道。`is_ambient_playing()` 查询到后端通道已自然结束时，也只会在 backend、request generation、owner 与 session 仍匹配后收敛内部状态。

所有项目后端方法都在同步非重入边界内执行。`can_handle_*()`、`play_*()`、`stop_*()`、transport、bus、event、query、setup 或 dispose 回调中，不得再次调用同一个 `GFAudioUtility` 修改播放通道、混音或 backend；这类重入会 fail closed。公开播放路径、参数/状态/开关、mix snapshot、effect value 和总线文本会先进入有界请求快照，backend 与本地回退只消费彼此隔离的值；即使 backend 改写参数后明确拒绝请求，本地回退仍只提交未暴露的权威副本。clip/event 的 probe、区间评估与执行回调各自收到一次性请求副本，Utility 保留不暴露的权威请求用于后续协商或本地回退。回调改写参数不会跳过类型化区间评估，也不会污染下一阶段。请求图统一受 16 层、1024 个遍历/属性工作项、64 MiB `String` / `StringName` / Packed Array 载荷字节上界和 16 Mi 个 Packed Array 元素的快照预算约束；向量 Packed Array 按双精度构建的最大元素宽度保守计费。`Resource`、`Array`、`Dictionary` 与 Packed Array 都会隔离，单个快照图内的重复引用在 setter 语义允许时复用同一副本；明确来自 ClassDB 的原生 Packed 属性允许引擎按值复制，但仍复核类型与内容，脚本或动态复制型引用 setter 则失败关闭。循环、超限、`PROPERTY_USAGE_NEVER_DUPLICATE`、只读/联动 setter、storage schema 漂移，以及无法安全实例化或写入的资源图都会在首次后端回调前失败关闭。脚本化 Resource 的 `_init()`、getter、setter 与 `_get_property_list()` 属于项目可信代码边界，本身不能由数据遍历预算中断，因此这些 hook 必须保持确定、无副作用且不得处理不受信输入。回调返回后，Utility 还会复核 backend identity、request generation、owner 与 session，避免间接生命周期变化让外层请求提交陈旧结果。后端回调应保持短小同步，把后续业务调度到回调边界之外。

Utility 的 Bank 播放入口使用自身的有界 resolver，不调用开放式候选复制：最多保留 1024 个活动 Bank ID，并在全部 ID 间最多保留 1024 条临时挂载记录；容量拒绝不会消费令牌、创建栈或改写当前/基础 Bank。每个候选数组最多检查 1024 项，有限权重的求和溢出会失败关闭，零权重候选不会参与存在正权重时的抽样；clip/bank ID 最多 1024 个字符，fallback 分隔符最多 16 个字符且最多回退 16 层。任一上限、候选 clip 快照或 fallback 解析失败都会在播放、资源加载和 backend 回调前终止；这些限制只约束 Utility 的运行时解析，不改变 `GFAudioBank` 作为项目数据资源的独立编辑能力。

接管 BGM 的后端必须覆写 `is_bgm_playing()`：播放中和暂停中的现存 session 都返回 `true`，自然结束或已停止后返回 `false`。基类默认返回 `false`，因此漏实现会 fail closed，并在 `GFAudioUtility.is_bgm_playing()` 或调试快照查询时把该 backend-owned session 收敛为 `stopped/none`。提交前同样会复核 backend、owner、request generation、状态和 history key；确认自然结束后，Utility 清空会话并只发出一次 `bgm_finished(history_key)`。`is_bgm_paused()` 只描述 transport 暂停状态，不能替代 session 存在性查询。

`GFAudioUtility.get_debug_snapshot()` 会先通过 `is_bgm_playing()` 收敛 BGM 生命周期，再把后端的 `get_debug_snapshot()` 放进 `backend_snapshot`，并提供 `bgm_playing`、`bgm_paused`、`bgm_position`、`current_bgm_region`、`last_playback_region_rejection`、`active_sfx_count` 和 `active_spatial_sfx_count` 等字段，便于诊断面板统一展示。

## 能力声明

后端可以通过 `GFAudioBackendCapability` 声明支持 BGM、SFX、环境音、空间音效、资源化事件、参数、状态、开关、监听器、异步加载或播放区间协商协议等能力。快照中的 `backend_capabilities` 可供调试面板或项目工具展示；具体片段是否支持仍以逐请求评估为准。

## 事件资源

需要把音频请求资源化时，可使用 `GFAudioEvent`、`GFAudioParameter`、`GFAudioState` 和 `GFAudioSwitch`，再通过 `post_audio_event()`、`set_audio_parameter()`、`set_audio_state()` 或 `set_audio_switch()` 交给当前后端。事件 metadata/options 中的 `loop` 与 `playback_region` 是保留键；类型化区间只能来自 `event.clip.playback_region`，并走与直接 clip 播放相同的验证和逐请求协商。`can_handle_event()` 返回 `true` 只表示后端愿意尝试；`post_event()` 返回非 `null` 的 `GFAudioEmitterHandle` 才表示请求已被后端接管，返回 `null` 表示未处理，Utility 会继续按事件的 BGM、环境音、普通或空间 SFX channel 走本地回退。外部系统已处理事件但没有 Godot 播放器时，也应返回一个非 `null` 句柄作为接管结果；需要支持停止时可在句柄上绑定项目自己的 release callback。

默认 Godot 播放路径只处理通用 BGM/SFX/环境音，不解释外部后端的项目含义。编辑器选择器或构建工具需要列出外部音频 ID 时，可实现或填充 `GFAudioCatalogProvider`。

```gdscript
var event := GFAudioEvent.new()
event.event_id = &"ui_confirm"
event.channel = &"sfx"
audio.post_audio_event(event)

var parameter := GFAudioParameter.new()
parameter.parameter_id = &"intensity"
parameter.value = 0.75
audio.set_audio_parameter(parameter)
```
