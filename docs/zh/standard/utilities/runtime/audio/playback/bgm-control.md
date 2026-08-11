# BGM 控制

BGM 使用独立播放器，并为每次播放、incoming crossfade 和 outgoing crossfade 分配独立 session。类型化入口用短生命周期的 `GFBgmStartOperation` 表达“是否已提交播放”，成功后再用独立的 `GFBgmSessionHandle` 表达会话控制与结束。异步加载、淡入淡出、暂停、停止和 `finished` 回调都会同时核对 generation 与 session；较旧回调完成得更晚时，不会覆盖或停止新的播放请求。

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

现有 `play_bgm*()` 方法仍是 fire-and-forget 兼容入口。需要区分校验拒绝、准备失败、被新请求取代、取消和真正开始播放时，使用类型化入口：

```gdscript
func start_exploration_bgm(audio: GFAudioUtility, owner: Node) -> void:
	var operation := audio.start_bgm(
		"res://audio/bgm/explore.ogg",
		{
			"crossfade_seconds": 0.5,
			"history_key": "exploration",
		},
		owner
	)
	if operation.is_completed():
		_on_bgm_start_completed(operation.get_result())
	else:
		operation.completed.connect(_on_bgm_start_completed, CONNECT_ONE_SHOT)


func _on_bgm_start_completed(result: GFBgmStartResult) -> void:
	if result.get_status() != GFBgmStartResult.Status.STARTED:
		push_warning("BGM start failed: %s" % result.get_reason())
		return
	var session := result.get_session_handle()
	# session.stop() 只影响这个精确会话；会话被替换后，旧句柄不能停止新 BGM。
	print("BGM session started: ", session.get_session_id())
```

本地 clip、同步 backend 或同步校验可以在 `start_bgm()` / `start_bgm_clip()` 返回前完成，因此调用方必须先查询 `is_completed()`，只在仍 pending 时连接 `completed`。`GFBgmStartResult.Status` 是闭合终态：`STARTED` 表示 local/backend 已接受并提交会话；`REJECTED` 表示请求未被接纳；`FAILED` 表示已接纳候选在准备或提交阶段失败；`SUPERSEDED` 表示较新的有效请求取代等待中的请求；`CANCELLED` 表示 caller、owner、stop、backend topology 或 Utility 生命周期取消等待。`BackendDisposition` 另行区分没有 backend、backend 未认领、明确拒绝、本次接受和请求身份失效；`INVALIDATED` 也用于 backend 已物理接受候选、但框架无法发布规范 Session 身份的失败收敛。backend 拒绝后本地成功会得到 `STARTED`，并可由 `used_backend_fallback()` 识别。

结果只接受下列 `status/reason/error/backend disposition` 配对：

| Status | Reason | Error | 允许的 BackendDisposition |
|---|---|---|---|
| `STARTED` | `REASON_LOCAL_STARTED` | `OK` | `NOT_ATTEMPTED` |
| `STARTED` | `REASON_BACKEND_STARTED` | `OK` | `STARTED` |
| `STARTED` | `REASON_BACKEND_FALLBACK_STARTED` | `OK` | `NOT_CLAIMED`、`REJECTED` |
| `REJECTED` | `REASON_INVALID_PATH`、`REASON_INVALID_OPTIONS`、`REASON_INVALID_CLIP` | `ERR_INVALID_PARAMETER` | `NOT_ATTEMPTED` |
| `REJECTED` | `REASON_INVALID_PLAYBACK_REGION` | `ERR_INVALID_PARAMETER` | `NOT_ATTEMPTED`、`REJECTED` |
| `REJECTED` | `REASON_UTILITY_NOT_INITIALIZED`、`REASON_OWNER_UNAVAILABLE` | `ERR_UNAVAILABLE` | `NOT_ATTEMPTED` |
| `REJECTED` | `REASON_BACKEND_DISPATCH_IN_PROGRESS` | `ERR_BUSY` | `NOT_ATTEMPTED` |
| `FAILED` | `REASON_ASSET_LOAD_FAILED` | `ERR_CANT_OPEN` | `NOT_ATTEMPTED`、`NOT_CLAIMED`、`REJECTED` |
| `FAILED` | `REASON_BACKEND_REJECTED_AND_LOCAL_FAILED` | `ERR_CANT_OPEN` | `REJECTED` |
| `FAILED` | `REASON_STREAM_UNPLAYABLE` | `ERR_INVALID_DATA` | `NOT_ATTEMPTED`、`NOT_CLAIMED`、`REJECTED` |
| `FAILED` | `REASON_BACKEND_OWNER_RELEASE_FAILED` | `ERR_UNAVAILABLE` | `NOT_CLAIMED`、`REJECTED` |
| `FAILED` | `REASON_LOCAL_PLAYER_REJECTED` | `ERR_CANT_CREATE` | `NOT_ATTEMPTED`、`NOT_CLAIMED`、`REJECTED` |
| `FAILED` | `REASON_SESSION_PUBLICATION_FAILED` | `ERR_CANT_CREATE` | `INVALIDATED` |
| `SUPERSEDED` | `REASON_NEWER_REQUEST` | `ERR_BUSY` | `NOT_ATTEMPTED`、`NOT_CLAIMED`、`REJECTED`、`INVALIDATED` |
| `CANCELLED` | `REASON_BACKEND_CHANGED` | `ERR_SKIP` | `INVALIDATED` |
| `CANCELLED` | `REASON_CALLER_CANCELLED`、`REASON_OWNER_RELEASED`、`REASON_STOP_REQUESTED`、`REASON_UTILITY_DISPOSED` | `ERR_SKIP` | `NOT_ATTEMPTED`、`NOT_CLAIMED`、`REJECTED`、`INVALIDATED` |

只有 `STARTED` 可以携带非 `NONE` owner 和规范 `GFBgmSessionHandle`；`REASON_LOCAL_STARTED` 与 `REASON_BACKEND_FALLBACK_STARTED` 固定使用 `OwnerKind.LOCAL`，`REASON_BACKEND_STARTED` 固定使用 `OwnerKind.BACKEND`。其他终态固定使用 `OwnerKind.NONE`、`session_id == 0` 与空句柄。`BackendDisposition.STARTED` 也只允许与 `STARTED/REASON_BACKEND_STARTED/OwnerKind.BACKEND` 同时出现；`FAILED/REASON_SESSION_PUBLICATION_FAILED/INVALIDATED` 同样不得携带 Session 身份。

有效请求只会取代仍 pending 的旧请求，不会在加载、校验或本地 standby 阶段停止当前已提交会话。候选必须先完成资源冻结、播放区间验证和 backend/local 接受，再一次提交新的逻辑 session、history key 与 owner；本地候选或 backend 接受前失败、取消时，原会话、history 和控制句柄保持有效。脚本化 `AudioStream` 的 playback 构造属于同步外部边界：hook 返回后会重新验收候选播放器与备用播放器的精确 parent、生命周期和请求身份；若旧播放器在 hook 中停止而失去 crossfade 资格，备用播放器也必须先准备并验收，之后才能冻结成功发布。现有 backend 协议只有同步 `play_bgm_*() -> bool` 接受点：若 backend 已物理接受候选后请求身份才失效，Utility 会 best-effort 补偿停止候选；旧 backend-owned 会话无法恢复时会以 `PLAYBACK_FAILED` 终结，不能承诺继续播放。提交 replacement 时，新 Operation 结果与旧 Session 终态会先全部冻结，再通知监听器，因此回调中的查询与精确 stop 不会观察到半提交状态。若 typed start 在终态排空、输入校验或请求快照 hook 中同步接纳了新 start，新请求保持最新代，仍在外层调用栈中的旧请求以 `SUPERSEDED/newer_request` 结束。调用方传入的可选 `owner` 必须是仍在场景树中的活动 Node，并且只以弱身份绑定：等待期间退出树会取消 Operation，提交后退出树只停止对应的精确 Session；不传 owner 的 BGM 属于全局会话。

## 生命周期与传输边界

BGM transport 接口面向暂停菜单、剧情演出、音量淡入淡出和进度恢复。`pause_bgm()` / `resume_bgm()` 使用 Godot `AudioStreamPlayer.stream_paused` 保留当前位置，`seek_bgm()` 和 `get_bgm_playback_position()` 用于显式跳转和记录。backend-owned BGM 的 `is_bgm_playing()` 与 `is_bgm_paused()` 会在同步非重入边界内查询当前后端，并在 backend/request generation/owner/session identity 仍匹配时刷新内部状态；后端回调中的重入查询只返回已有缓存，不会再次调用后端。暂停中的 session 仍由 `is_bgm_playing()` 返回 `true`，`is_bgm_paused()` 只补充 transport 状态。状态转换会失败关闭：重复暂停不会覆盖原始增益，停止、自然结束或 replacement 后的旧 resume 不会复活已经终结的 session。

`play_bgm_with_options()` 只接受 `crossfade_seconds`、`history_key`、`bus_name`、`volume_db` 和 `pitch_scale`。播放区间与循环点统一由 `GFAudioClip.playback_region` 表达；继续传入 `loop` 或 `playback_region` 通用字段会在加载或后端派发前失败关闭。具体字段、原生流能力和后端协商见[类型化播放区间与循环点](playback-regions.md)。

crossfade 的逻辑提交点是 incoming 播放器接受候选之时，不等待物理淡出完成。该时刻旧 Session 以 `REPLACED` 终结并成为仅供物理淡出的 retiring voice；incoming 随后提前自然结束也不会复活已被替换的旧 Session。候选在接受前失败则保留 outgoing Session。只有当前逻辑 Session 自然结束才会按其 `history_key` 发出一次 `bgm_finished(history_key)`；retiring voice 的 `finished` 回调不会重复发出。第三方后端必须实现 `GFAudioBackend.is_bgm_playing()`；当 Utility 查询到稳定的 backend-owned Session 已结束时，也会先提交 `NATURAL_FINISH`，再按同一 history key 发出一次 `bgm_finished`。调试快照会执行这次收敛查询。

`GFBgmSessionHandle.stop(fade_seconds)` 只停止句柄代表的精确逻辑 Session；返回 `true` 表示该 stop 终态 intent 已按 first-wins 接受，句柄会在当前安全收敛边界进入 `STOPPED`，物理淡出可在之后完成。过期、已终结或被替换的句柄返回 `false`，不会影响当前 replacement。`stop_bgm()` 仍用于全局停止入场时的 pending 请求和当前精确 Session；legacy `play_bgm("", crossfade_seconds)` 保留相同兼容语义，而 typed `start_bgm("")` 会以 `REJECTED/invalid_path` 结束。带时长的本地 stop 使用一个由 `GFAudioUtility` 自己持有、停止和复用的 fallback `Timer` 保障 Tween 丢失时仍能收敛；replacement、session clear 和 dispose 会主动取消它，不会为每次旧请求遗留不可取消的 `SceneTreeTimer`。若流在 stop 淡出完成前已到 EOF，Utility 会保留既有 `STOPPED` 终态并立即收敛播放器、owner、session 与 fallback，不会补发自然结束。

同一实例重复调用 `init()` 是幂等 no-op，不会清空当前 session 或创建第二代播放器；`dispose()` 后可再次 `init()` 开始新生命周期。调用方仍应让 architecture 管理正常 init/dispose 顺序，不应把重复 init 当作 reset API。

场景树关闭时，root 可能先于 Utility 释放本地 BGM 播放器。`dispose()` 会把已经失效或仍存活的两个播放器都收敛为空引用，并保持重复调用幂等；项目不应缓存或直接拥有 Utility 的内部播放器。
