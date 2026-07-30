# Bank 播放

`GFAudioClip` 可描述 stream/path、bus、音量、基础 pitch、候选权重、本次播放 pitch 随机范围和可选空间播放设置。`GFAudioBank` 的同一 ID 可保存单个片段或多个候选，并支持用 `fallback_separator` 做分层事件 ID 回退。

```gdscript
var clip := GFAudioClip.new()
clip.stream = preload("res://audio/sfx/confirm.wav")
clip.bus_name = "SFX"
clip.volume_db = -3.0

var alternate := GFAudioClip.new()
alternate.stream = preload("res://audio/sfx/confirm_alt.wav")
alternate.weight = 2.0

var bank := GFAudioBank.new()
bank.set_clip(&"confirm", clip)
bank.set_clips(&"ui+confirm", [clip, alternate])

audio.register_audio_bank(&"ui", bank)
audio.play_sfx_from_bank(bank, &"confirm")
audio.play_sfx_event(&"ui+confirm+primary", &"ui")
```

需要编辑器校验、构建前检查或调试 fallback 时，可用 `resolve_clip()` 获取请求 ID、最终命中 ID、是否使用 fallback、尝试过的 ID 和命中的 clip。`validate_bank()` 可检查空 ID、无效候选、缺失音频源和可选资源路径存在性。

多字符 `fallback_separator` 按从左到右的非重叠分隔语义解析，忽略空片段，并逐次移除最后一个片段后重新连接；`GFAudioUtility` 的运行时 Bank 入口保持同一语义，但最多执行 16 次回退。不要依赖“从最右侧字符位置直接截断”的重叠匹配结果。
