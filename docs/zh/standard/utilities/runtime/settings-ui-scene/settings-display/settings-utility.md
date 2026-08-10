# 通用设置存储

游戏设置页通常会混合窗口模式、分辨率、语言、音量、难度、辅助功能等数据。如果这些逻辑直接写进 UI 节点，后续存档、重置默认值、平台差异和测试都会变得困难。

`GFSettingsUtility` 只管理抽象设置定义和值，不知道它们会被哪个 UI 或引擎 API 使用。

```gdscript
var settings := Gf.get_utility(GFSettingsUtility) as GFSettingsUtility

settings.register_setting(
	&"gameplay/difficulty",
	"normal",
	GFSettingDefinition.ValueType.STRING
)
settings.set_value(&"gameplay/difficulty", "hard")
settings.save_settings()
```

`GFSettingDefinition` 可以资源化描述稳定键、默认值、值类型、是否持久化和 UI 元数据。`set_value()` 会按定义做类型转换，`to_dict(true)` 只导出持久化设置；未注册定义的临时值也能读写，但不会获得默认值、类型钳制或元数据。

持久化设置会保留 `Vector2`、`Vector2i`、`Color`、`StringName` 等常见 Godot 值；其他需要 JSON 类型标记的值会复用 `GFVariantJsonCodec`，因此超出 JSON 安全范围的 64 位整数也能精确往返。字典 key 也会使用稳定编码，避免 `1` 与 `"1"` 等跨类型 key 在 JSON 对象中互相覆盖；循环引用会让保存返回 `ERR_INVALID_DATA`，调用方应先清理设置值。

未接入存储后端时，fallback 文件名必须是简单 basename，不能包含路径分隔符、`..`、盘符或绝对路径。需要把设置写到项目自定义目录时，应实现明确的存储后端，而不是把外部路径塞进 fallback 文件名。

fallback 保存的 `OK` 与 `settings_saved` 只在 payload 实际写入且 `FileAccess` 没有报告错误时产生；文件可以打开但写入失败时会返回真实 `Error`，不会发出成功信号。显式 `save_settings()` / `flush_pending_save()` 的调用方应处理该错误。自动保存失败后的重试和失败可观察策略尚未由框架替调用方猜测，不能仅凭启用 `auto_save_on_change` 假定永久落盘成功。

从合法持久化数据恢复时使用 `replace_from_dict()`：输入中缺失的已定义键恢复默认值，缺失的未定义旧键被移除；`load_settings()` 固定采用这一语义。只有明确把输入当作覆盖层时才使用 `merge_from_dict()`，它会保留输入中未出现的当前值。两种入口分离后，切换 profile 或读取合法空对象不会静默继承上一份 profile 的残留字段。

## 结构化加载与恢复

`load_settings()` 返回 `GFSettingsLoadResult`，调用方应先检查终态，再读取当前设置。合法空对象 `{}` 是一次成功加载；文件缺失、空文件、格式损坏、完整性失败、未来 schema、迁移失败和 IO 失败则保留各自的稳定分类，不再被折叠为空字典。

```gdscript
var result: GFSettingsLoadResult = settings.load_settings()
if result.is_successful():
	print("设置终态：", result.get_status())
else:
	push_warning("设置加载失败：%s" % result.get_error())
```

默认的 null 恢复策略是严格模式：失败不会修改当前有效值或暂存值，也不会创建、修复或覆盖源文件。项目确实接受缺失或损坏数据时，必须显式提供 `GFSettingsRecoveryPolicy`。恢复只支持保留当前内存状态或重置为已注册默认值；未来 schema、迁移失败和存储 IO 失败始终不可恢复。

```gdscript
var policy := GFSettingsRecoveryPolicy.new()
policy.missing_file_action = GFSettingsRecoveryPolicy.ACTION_USE_CURRENT_STATE
policy.corrupt_file_action = GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS

var result: GFSettingsLoadResult = settings.load_settings("", policy)
if result.was_recovered():
	print("恢复动作：", result.get_recovery_action())
```

加载与恢复本身都不会保存。确认恢复结果符合项目决策后，如需持久化默认值，调用方应在独立步骤中显式调用 `save_settings()`。这样损坏证据不会在读取阶段被静默覆盖。

非空策略会在存储读取前完整校验；未知动作返回 `STATUS_INVALID_REQUEST`，不会访问存储或取消既有保存队列。合法加载请求一旦开始，则会作为全局顺序屏障取消此前尚未执行的延迟保存和批处理保存请求，而不只取消同名文件，避免加载 B 后把新内存状态写回旧来源 A。

`auto_load_on_init` 使用严格 null 策略。启动阶段需要自定义恢复时，应把它设为 `false`，先完成设置定义注册，再显式调用带策略的 `load_settings()`；不要依赖初始化时自动猜测恢复动作。每次终态都会通过 `settings_load_completed` 发出隔离结果，也可用 `get_last_load_result()` 获取最近结果的副本。

自动保存默认会按 `save_debounce_seconds` 做防抖，避免设置页拖动滑块时每次变化都落盘。需要一次性应用多个字段时，可用 `begin_batch()` / `end_batch()` 包裹，或手动 `queue_save()` 后在合适时机 `flush_pending_save()`。

## 暂存设置

设置页如果需要“应用 / 取消”按钮，不应让滑块、选项框直接写入真实设置。可以先把用户选择写入暂存层，用 `get_staged_or_value()` 渲染预览值，确认后再提交。

```gdscript
settings.stage_value(&"audio/master", 0.6)

var preview_value: Variant = settings.get_staged_or_value(&"audio/master")

if settings.has_staged_values():
	var report: Dictionary = settings.apply_staged_values()
	if not report["ok"]:
		print(report["issues"])
```

暂存值会沿用 `GFSettingDefinition` 做类型转换，但不会触发 `setting_changed`、不会保存，也不会出现在 `to_dict()` 中。`apply_staged_values()` 会复用 `apply_values()` 的真实设置应用流程，因此会按现有批处理和自动保存规则合并落盘。需要放弃用户未确认的选择时，调用 `discard_staged_value(key)` 或 `discard_staged_values()`。

如果一个设置页只想提交当前页负责的键，可以通过 `scope` 限制提交范围；未在 scope 中的暂存值会继续保留，供其他页面或后续流程处理。

```gdscript
var report: Dictionary = settings.apply_staged_values({
	"scope": PackedStringArray([
		"video/window_mode",
		"video/window_size",
	]),
})
```

## 预设应用

需要把“低画质”“无障碍”“手柄方案”这类项目预设一次性应用到设置中时，可以使用 `apply_values()`。它会沿用已注册定义做类型转换，并把自动保存合并成一次。

如果预设希望把缺失的键重置为默认值，必须显式传入 `scope`，避免误重置不属于该预设的其他设置。

```gdscript
var report := settings.apply_values({
	"audio/master": 0.75,
	"video/fullscreen": true,
}, {
	"reset_missing": true,
	"scope": PackedStringArray([
		"audio/master",
		"video/fullscreen",
		"video/vsync",
	]),
})

if not report["ok"]:
	print(report["issues"])
```
