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

持久化设置会保留 `Vector2`、`Vector2i`、`Color`、`StringName` 等常见 Godot 值；其他需要 JSON 类型标记的值会复用 `GFVariantJsonCodec`，因此超出 JSON 安全范围的 64 位整数也能精确往返。

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
