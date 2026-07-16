# Bank 工具与导入

`GFAudioBankTools` 提供纯配置层的扫描、导入和播放前校验辅助，可用于编辑器按钮、构建脚本或项目自己的音频表生成流程。它不会创建全局音频单例，也不会改变 `GFAudioUtility` 的播放路径。该类和 `GFAudioLibraryTools` 属于可选的 `gf.standard.audio.editor` 工具包；导出的运行时包只需要安装 `gf.standard.audio`。

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
	"metadata": {
		"source": "project_audio_import",
	},
	"metadata_by_path": {
		"res://audio/ui/click.ogg": {
			"category": "ui",
		},
	},
})
```

`metadata` 会复制到每个生成的 `GFAudioClip`，`metadata_by_path` 可按资源路径补充或覆盖片段元数据。该字典适合承载导入批次、来源库、标签、预览信息或项目工具需要的附加字段；播放层不会解释这些字段，具体命名和导表约定仍由项目层或独立工具包定义。

需要从已有音频文件或 `AudioStream` 提取常见标题、艺人、专辑、时长和 ID3v2 文本帧时，可先用 `GFAudioMetadataTools` 生成纯字典报告，再把结果写入 `metadata_by_path` 或项目自己的导表数据。该工具只做规范化与摘要，不接管导入器、封面资源生成或播放策略。

```gdscript
var report := GFAudioMetadataTools.read_path_metadata("res://audio/ui/click.mp3")
var metadata := GFVariantData.get_option_dictionary(report, "metadata")

var bank := GFAudioBankTools.create_bank_from_paths(["res://audio/ui/click.mp3"], {
	"metadata_by_path": {
		"res://audio/ui/click.mp3": metadata,
	},
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

## 素材库候选与导入计划

`GFAudioLibraryTools` 用于编辑器工具或构建脚本从素材库目录收集候选音频，按关键字过滤，再生成可检查的复制计划。它不会直接修改 `GFAudioBank`；复制完成后的目标路径可以继续交给 `GFAudioBankTools` 生成或同步 Bank。发布运行时构建时可不安装 `gf.standard.audio.editor`，保留生成好的 `GFAudioBank` / `GFAudioClip` 资源即可。

```gdscript
var entries := GFAudioLibraryTools.scan_library("D:/audio-library", {
	"path_separator": "+",
	"max_audio_paths": 5000,
})

var filtered := GFAudioLibraryTools.filter_entries(entries, "ui click")
var plan := GFAudioLibraryTools.make_import_plan(filtered, "res://audio/imported", {
	"preserve_structure": true,
	"overwrite": false,
})

var copy_report := GFAudioLibraryTools.copy_import_plan(plan)
var copied_paths := GFVariantData.get_option_packed_string_array(copy_report.metadata, "copied_paths")

var import_report := GFAudioBankTools.add_paths_to_bank(bank, copied_paths, {
	"id_mode": "relative_path",
	"base_path": "res://audio/imported",
	"overwrite": false,
})
```

导入计划条目会写入 `source_path`、`target_path`、`relative_path`、`clip_id`、`source_exists`、`target_exists`、`will_copy` 和 `reason`。编辑器 UI 应先展示计划和诊断，再让维护者决定是否复制；项目自己的命名、目录约定和 Bank 分组策略仍由调用方通过 options 和后续导入流程表达。

`copy_import_plan()` 默认会在执行前检查本批次实际可复制条目的数量和总字节数。`max_copy_files` 默认是 `GFAudioLibraryTools.DEFAULT_MAX_COPY_FILES`，`max_copy_bytes` 默认是 `GFAudioLibraryTools.DEFAULT_MAX_COPY_BYTES`；传入 `0` 表示不限制。超限时报告会添加 `copy_file_count_limit_exceeded` 或 `copy_byte_limit_exceeded` 错误，`metadata` 中保留 `planned_copy_count`、`planned_copy_bytes`、`max_copy_files` 和 `max_copy_bytes`，并且不会执行部分复制。

## 使用边界

音频扫描默认限制递归深度和路径数量，项目构建脚本可按音频目录规模调高 `max_scan_depth` / `max_audio_paths`。`excluded_paths` 会按 `GFPathTools` 规范化并去重，命中排除目录自身或其子路径都会被跳过。默认扫描与 `GFAudioClip.path` 文件选择器保持同一组常见 Godot 音频扩展名：`wav`、`ogg`、`mp3` 与 `opus`。

推荐把 `GFAudioBankTools` 和 `GFAudioLibraryTools` 用作生成、复制和校验配置的工具；声音优先级、混音快照、场景预加载策略和具体事件命名仍由项目层决定。
