# 输入检测、格式化与图标

## 检测与文本

`GFInputDetector` 可放进改键界面中检测下一次输入。它通过 `DetectionState` 区分空闲、倒计时、预清理、正式检测和检测后清理阶段，`wait_for_clear_before_detection` 可避免“打开改键界面的确认键”立刻被记录，`wait_for_clear_after_detection` 可让项目等候检测到的按键或轴释放后再提交结果。

`GFInputFormatter` 提供轻量文本格式化，便于设置界面展示当前绑定。Joypad 默认会通过 `GFInputDeviceTextProvider` 输出抽象方位文本，例如 Button South、Left Stick X，也可通过 options 或注册自定义 `GFInputTextProvider` 替换为平台图标、图标字体或本地化文本。

## 图标 Provider

需要 RichTextLabel 图标输出时，可继承 `GFInputIconProvider` 把输入事件映射为项目自己的 `Texture2D` 或 BBCode，`input_event_as_rich_text()` 会优先使用图标 provider，再回退到文本。`GFInputIconAtlasProvider` 是内置的可配置图标 provider：它把按键、鼠标、手柄按钮和手柄轴归一化成 `key:k`、`mouse:left`、`joy_button:south`、`joy_axis:left_x_positive` 这类通用键，再通过显式路径、纹理映射或 `{root}/{style}/{platform}/{icon}.png` 模板解析图标。

```gdscript
var icons := GFInputIconAtlasProvider.new()
icons.root_path = "res://ui/input_icons"
icons.style = &"line"
icons.platform = &"generic"
icons.set_icon_path(&"key:space", "res://ui/input_icons/line/generic/key_space.png")

GFInputFormatter.add_icon_provider(icons)
var rich_text := GFInputFormatter.input_event_as_rich_text(jump_binding.input_event)
```

图标 provider 不附带任何图片资源，也不规定平台品牌、按钮文案或美术风格。项目可以用 `icon_paths` 精确映射少量按钮，也可以用路径模板批量组织素材；`split_key_modifiers` 会把 Ctrl/Shift/Alt/Meta 组合键拆成多个图标，便于设置界面显示。

## Action 显示

当界面只知道 Godot `InputMap` 动作名时，可以直接使用 `GFInputFormatter.action_as_text()`、`action_as_rich_text()` 或 `action_icon()`。这些入口会先读取 runtime `InputMap`，没有注册运行时 action 时再读取 `ProjectSettings` 中的 `input/<action>`，适合普通运行时 UI、编辑器预览和设置界面共用同一套显示逻辑。

```gdscript
var prompt := GFInputFormatter.action_as_rich_text(&"jump", {
	"preferred_device_type": &"joypad",
	"root_path": "res://ui/input_icons",
	"style": &"line",
})
```

`preferred_device_type` 可传 `keyboard_mouse`、`keyboard`、`mouse`、`joypad` 或 `touch`，用于按最近活跃设备选择同一动作下的不同绑定；没有匹配事件时会回退到动作的第一条事件。项目若想为某个动作提供组合图标或语义图标，可以在 icon provider 中映射 `action:jump`，并在调用时传入 `{ "prefer_action_icon": true }`；默认仍优先展示真实物理绑定，避免把业务动作名写成框架固定图标。

## 冲突诊断

`GFInputConflictAnalyzer` 可在保存重绑定前检查同一上下文或跨上下文的有效输入冲突，也可以通过 `build_rebind_report()` 一次性获取有效绑定条目和冲突列表。它只读取资源和重映射配置，不接管运行时输入逻辑。`GFInputContextDiagnostics` 在冲突报告之上补充输入上下文结构诊断，例如空上下文标识、空映射、缺失动作、重复 `action_id`、空绑定、无效死区、空修饰器/触发器槽位，以及 `InputEventAction` 是否缺少 ProjectSettings/Input Map action。编辑器中的 `GFInputMappingDock` 渲染 `GF Workspace > Input` 页面，并复用该诊断工具输出标准校验报告字段；页面只读查看资源，不保存项目按键配置，也不规定输入设置界面布局。
