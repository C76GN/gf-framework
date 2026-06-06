# Bank 工具与导入

`GFAudioBankTools` 提供纯配置层的扫描、导入和播放前校验辅助，可用于编辑器按钮、构建脚本或项目自己的音频表生成流程。它不会创建全局音频单例，也不会改变 `GFAudioUtility` 的播放路径。

## 扫描与生成

```gdscript
var paths := GFAudioBankTools.scan_audio_paths("res://audio", {
	"include_addons": false,
	"max_scan_depth": 32,
	"max_audio_paths": 10000,
})

var bank := GFAudioBankTools.create_bank_from_paths(paths, {
	"id_mode": "relative_path",
	"base_path": "res://audio",
	"path_separator": "+",
	"bus_name": "SFX",
})
```

## 校验与同步

```gdscript
var report := GFAudioBankTools.validate_bank_playback(bank, {
	"check_resource_exists": true,
	"check_bus_exists": true,
})
print(report.make_summary("Audio bank"))

var import_report := GFAudioBankTools.sync_bank_from_scan(bank, "res://audio", {
	"id_mode": "relative_path",
	"base_path": "res://audio",
	"overwrite": false,
	"bus_name": "SFX",
})
```

选中 `GFAudioBank` 资源时，Inspector 的验证入口也会使用同一套工具检查音频路径、候选片段和 bus 名；同一面板还提供扫描目录、选择 ID 生成方式、是否覆盖和默认 bus 的轻量导入入口。

## 使用边界

音频扫描默认限制递归深度和路径数量，项目构建脚本可按音频目录规模调高 `max_scan_depth` / `max_audio_paths`。`excluded_paths` 会按 `GFPathTools` 规范化并去重，命中排除目录自身或其子路径都会被跳过。默认扫描与 `GFAudioClip.path` 文件选择器保持同一组常见 Godot 音频扩展名：`wav`、`ogg`、`mp3` 与 `opus`。

推荐把 `GFAudioBankTools` 用作生成和校验配置的工具；声音优先级、混音快照、场景预加载策略和具体事件命名仍由项目层决定。
