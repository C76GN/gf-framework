# SFX 与音频片段

`GFAudioUtility` 会优先借助 `GFAssetUtility` 异步加载音频资源；未注册时退回同步 `load()`。SFX 播放会在存在 `GFObjectPoolUtility` 时复用池化 `AudioStreamPlayer`，未注册对象池时则创建普通播放器并在播放结束后释放。

```gdscript
var audio := Gf.get_utility(GFAudioUtility) as GFAudioUtility

audio.play_sfx("res://audio/sfx/hit.wav")

var clip := GFAudioClip.new()
clip.stream = preload("res://audio/sfx/confirm.wav")
clip.bus_name = "SFX"
clip.volume_db = -3.0
audio.play_sfx_clip(clip)
```

`GFAudioClip.metadata` 是留给导入器、编辑器工具或项目层的通用字典。GF 不解释其中的键，也不会把它变成播放策略；需要时可以用 `set_metadata_value()`、`get_metadata_value()` 和 `duplicate_metadata()` 做安全写入和复制。

`GFAudioClip.spatial_settings` 可引用 `GFAudioSpatialSettings`，但只会在 `play_sfx_clip_2d()` / `play_sfx_clip_3d()` 等空间 SFX 路径中应用。普通 SFX、BGM 和环境音仍只读取 stream/path、bus、音量、pitch 和 pitch 随机范围。

空间设置为空时，GF 仍会把空间播放器的 `area_mask` 设为 layer 1；项目需要关闭 Area 音频总线覆盖时，应显式提供 `GFAudioSpatialSettings` 并把对应掩码设为 0。

`GFAudioEmitterHandle.stop()` 即使在异步资源返回前调用，也会记录停止请求；迟到的 SFX 资源不会再创建播放器。`stop_all_sfx()` 会递增 SFX 生命周期序号，停止普通 SFX 和 2D/3D 空间 SFX，并阻止尚未返回的异步 SFX 继续落地。

池化播放器归还前会重置 stream、bus、音量和 pitch，避免上一次播放设置污染下一次请求。
