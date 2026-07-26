# Bank 挂载、空间音效与句柄

注册 `GFAudioBank` 后，可以按稳定事件 ID 播放 BGM、环境音和 SFX。场景或 UI 也可以临时挂载一组音频事件，并在退出时恢复或卸载。

## Bank 挂载

`register_audio_bank()` 后可用 `play_bgm_event()`、`play_ambient_event()`、`play_sfx_event()` 按稳定事件 ID 播放。

场景或 UI 想临时拥有一组音频事件时，可使用 `GFAudioBankMounter` 在 ready/exit 时自动注册、恢复或卸载 bank。同一 `bank_id` 的多个挂载由 `GFAudioUtility` 按栈管理，场景或 UI 交错退出时，较早退出的下层挂载不会覆盖仍处于顶层的 bank。

需要手动控制同类逻辑时，可使用 `mount_audio_bank()` / `unmount_audio_bank()`。

## 播放句柄

需要主动停止、淡出或读取本次 SFX/空间音效状态时，使用 `play_sfx_handle()`、`play_sfx_clip_handle()`、`play_sfx_event_handle()` 或 2D/3D 对应 handle 方法取得 `GFAudioEmitterHandle`。

```gdscript
var clip := GFAudioClip.new()
clip.stream = preload("res://audio/sfx/confirm.wav")

var handle := audio.play_sfx_clip_handle(clip)
if handle != null:
	handle.bind_to_owner(self)
	handle.fade_to(-10.0, 0.2)
	handle.stop(0.1)
```

环境音通道可用 `get_ambient_handle(channel)` 获取当前播放 session 的句柄。句柄会同时绑定 channel generation 与 playback session ID；同一 session 可签发多个句柄，Utility 会跟踪并在停止、自然结束、replacement、重新初始化或 dispose 时一起终结全部句柄。该通道被 replacement 后，所有旧句柄的停止或淡出都会变成 no-op，不能控制复用后的播放器。项目若绕过 handle 直接停止环境音原生播放器，`is_ambient_playing()`、`get_ambient_handle()` 或 `get_debug_snapshot()` 会按当前 generation 收敛 owner/state/session 并终结全部旧句柄，不会继续公开陈旧的 local/playing 状态。

普通与空间 SFX 也使用独立 playback session；如果项目绕过 handle 直接对原生播放器调用 `stop()`，Utility 会在下一次容量、清理或诊断收敛点终结 active 或 retiring session、取消仍在运行的淡出 Tween、完成旧 handle 并立即释放容量。普通池播放器进入终态时还会显式断开当前 session 的 `finished` 回调，播放器复用后旧 callback 或旧 handle 都不能命中新 session。句柄只管理当前 session 的停止、淡出、音量、音高和可选 owner 生命周期绑定，不替项目决定混音快照、声音优先级或业务生命周期。

## 空间音效

```gdscript
var source_2d := $AudioAnchor as Node2D
audio.play_sfx_clip_2d(clip, source_2d, true) # 需要跟随声源时启用 follow_source
```

`play_sfx_clip_2d()` / `play_sfx_clip_3d()` 和对应 event 方法默认只在当前位置创建空间播放器；传入 `follow_source = true` 时，播放器会挂到声源节点下并随声源移动。

需要调节距离衰减、区域掩码、复音、播放类型、3D 发射角、滤波或多普勒时，可在 `GFAudioClip.spatial_settings` 上挂 `GFAudioSpatialSettings`。该资源只在空间 SFX 播放路径应用，不改变普通 SFX、BGM 或环境音的行为。

未挂空间设置时，GF 会把 2D/3D 空间播放器的 `area_mask` 保持在 layer 1，避免 Godot 4.7 的空默认掩码导致 Area 音频总线覆盖失效。需要禁用 Area 覆盖时，在 `GFAudioSpatialSettings` 中把对应 `area_mask_*` 设为 0。

```gdscript
var spatial := GFAudioSpatialSettings.new()
spatial.max_distance_3d = 24.0
spatial.unit_size_3d = 4.0
spatial.doppler_tracking_3d = 2

clip.spatial_settings = spatial
audio.play_sfx_clip_3d(clip, $AudioAnchor3D)
```

复杂混音、音频快照、距离规则、碰撞触发和平台音频权限仍属于项目层。
