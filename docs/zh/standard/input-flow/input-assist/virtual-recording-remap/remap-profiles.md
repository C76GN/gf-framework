# 重映射配置与 Profile

运行时改键通过 `GFInputRemapConfig` 保存覆盖项。默认绑定仍留在上下文资源中，配置只记录用户或项目层修改过的部分。

## 单个重映射配置

```gdscript
var remap := GFInputRemapConfig.new()
input_map.set_remap_config(remap)
input_map.set_binding_override(&"gameplay", &"jump", 0, new_input_event)
var saved_remap := remap.to_dict()
var restored_remap := GFInputRemapConfig.from_dict(saved_remap)
```

`GFInputRemapConfig.to_dict()` 会把覆盖的 `InputEvent` 与显式解绑记录转换为可写入配置或存档的字典，`from_dict()` 可恢复，`duplicate_config()` 会用同一套持久化格式做深拷贝；默认绑定仍来自上下文资源，不会被复制进重映射配置。

新的重映射记录使用白名单事件类型和结构化属性，不再为新数据写入 `str_to_var()` 文本；旧格式仍可被读取，便于已有存档渐进迁移。

## Profile 集合

如果项目需要多套可命名的键位配置，可以用 `GFInputProfileBank` 保存多个 `GFInputRemapConfig`。Bank 只管理 profile id 与重映射资源，不规定账号、玩家编号、存档槽位或设置界面结构。

```gdscript
var profiles := GFInputProfileBank.new()
profiles.set_profile(&"keyboard", input_map.get_remap_config(true))
profiles.ensure_profile(&"gamepad")
profiles.set_active_profile(&"gamepad")

input_map.set_remap_config(profiles.get_active_profile())
```

`GFInputProfileBank.to_dict()` / `from_dict()` 保存 profile 集合、当前激活项和 `custom_data`，适合项目把“多套键位方案”作为一个整体写入设置或存档。

## InputMap 预设边界

如果项目需要导入或导出 Godot 当前 `InputMap` 的动作表，可以使用 `GFInputMapPresetTools` 捕获运行时动作、deadzone 和事件列表：

```gdscript
var preset := GFInputMapPresetTools.capture_input_map({
	"action_ids": ["jump", "dash"],
	"metadata": {
		"label": "Keyboard",
	},
})

var report := GFInputMapPresetTools.apply_input_map_preset(preset, {
	"clear_existing_events": true,
})
```

这个预设工具只操作运行时 `InputMap`，不写 `ProjectSettings`，也不决定预设文件放在哪里。需要保存、同步到云端、做平台差异或接入设置界面时，由项目侧把预设字典接到自己的配置、存档或 UI 流程中。
