# Bank 工具与导入

`GFAudioBankTools` 提供纯配置层的扫描、导入和播放前校验辅助，可用于编辑器按钮、构建脚本或项目自己的音频表生成流程。它不会创建全局音频单例，也不会改变 `GFAudioUtility` 的播放路径。该类和 `GFAudioLibraryTools` 只用于制作期；导出的游戏只需要引用运行时音频能力和已经生成的资源。

## 扫描与生成

```gdscript
var paths := GFAudioBankTools.scan_audio_paths("res://audio", {
	"include_addons": false,
	"max_scan_depth": 32,
	"max_audio_paths": 10000,
	"max_scanned_entries": 100000,
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

`max_id3_bytes` 默认使用 `GFAudioMetadataTools.DEFAULT_MAX_ID3_BYTES`（1 MiB），并始终受 `ABSOLUTE_MAX_ID3_BYTES`（8 MiB）约束。路径入口先读取固定 10-byte header，再只读取文件长度、header 声明长度和有效上限三者中的最小值；报告通过 `requested_max_id3_bytes`、`effective_max_id3_bytes`、`absolute_max_id3_bytes`、`limit_clamped` 和 `read_bytes` 公开实际边界。声明内容不足时 `partial=true` 并返回 `truncated_id3_header` / `truncated_id3_tag`；当前未实现的 ID3v2 unsynchronisation、extended header、experimental/footer 会返回 `unsupported_id3_feature`，不会被当成普通 frame 或完整成功。需要完整封面或其他大型 ID3 feature 时，应使用专门的受控解析器，而不是抬高本工具的文本元数据预算。

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

`GFAudioLibraryTools` 用于编辑器工具或构建脚本从素材库目录收集候选音频，按关键字过滤，再生成可检查的复制计划。它不会直接修改 `GFAudioBank`；复制完成后的目标路径可以继续交给 `GFAudioBankTools` 生成或同步 Bank。发布运行时构建时不需要调用这些制作期工具，保留生成好的 `GFAudioBank` / `GFAudioClip` 资源即可。

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

预检不是执行授权：每个 source 在正式打开后会重新核对长度，完整条目的剩余预算会在创建 temp 和读取前预留，实际读取再计入全计划共享的 `consumed_copy_bytes`，只有成功提交才计入 `committed_copy_bytes`。source 在计划与执行之间改变长度、执行期读写失败或累计预算不足时，temp 不会提交为目标。

覆盖复制使用确定性的 `.gf-copy.tmp` 与 `.gf-copy.backup` 同目录 sidecar。每次新事务会先幂等处理上次中断：backup 存在且 canonical target 缺失时恢复旧 target；target 与 backup 同时存在时把 target 视为已提交结果并清理旧 backup；遗留 temp 会被删除。恢复本身失败时报告会保留 backup path 与 recovery state，供维护者重试或人工恢复，不会吞掉 restore error。调用方必须独占目标目录，并把每个 target 对应的这两个精确名称视为事务保留命名空间；当前无 journal/provenance 可以把外部创建的同名文件与 GF 中断 sidecar 区分开。

## 使用边界

音频扫描同时限制递归深度、返回音频路径数和检查的全部目录项数。默认值分别为 32、10,000 和 100,000；框架绝对上限分别为 64、100,000 和 1,000,000。正数会被 absolute limit 收紧，`0` 表示请求框架绝对上限，负数恢复默认值，不存在关闭全部扫描保护的选项。DirAccess 能识别的 symbolic link 默认跳过；未被平台 API 识别的 junction/reparse 即使形成别名或环，也会被深度与总 entry hard cap 终止。`excluded_paths` 会按 `GFPathTools` 规范化并去重，命中排除目录自身或其子路径都会被跳过。默认扫描与 `GFAudioClip.path` 文件选择器保持同一组常见 Godot 音频扩展名：`wav`、`ogg`、`mp3` 与 `opus`。

`make_import_plan()` / `copy_import_plan()` 当前提供的是词法 `target_root` 约束和可信单写者恢复协议，不是 OS sandbox：它会拒绝绝对 entry、`.` / `..` 和普通 root 逃逸，但 Godot 文件 API 不能固定父目录句柄，也不能在所有平台证明中间 junction/reparse 的物理身份或阻止另一进程在检查与 open/rename 之间交换目录项。只应把它用于调用方控制且不会被并发敌对修改的素材目录，并由同一 writer 独占上述 recovery sidecar 保留命名空间；半可信模板、共享目录或需要抗链接逃逸的导入流程，应先在平台 capability 层隔离/复制 source 与 target。确定性 sidecar 提供应用级 crash 恢复，但不承诺 `fsync` 级掉电持久化。

推荐把 `GFAudioBankTools` 和 `GFAudioLibraryTools` 用作生成、复制和校验配置的工具；声音优先级、混音快照、场景预加载策略和具体事件命名仍由项目层决定。
