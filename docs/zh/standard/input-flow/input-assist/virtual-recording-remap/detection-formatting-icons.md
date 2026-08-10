# 输入检测、格式化与图标

## 检测与文本

`GFInputDetector` 可放进改键界面中检测下一次输入。它通过 `DetectionState` 区分空闲、倒计时、预清理、正式检测和检测后清理阶段，`wait_for_clear_before_detection` 可避免“打开改键界面的确认键”立刻被记录，`wait_for_clear_after_detection` 可让项目等候检测到的按键或轴释放后再提交结果。

新项目应优先监听 `detection_finished(result)`，通过 `GFInputDetectionResult.reason` 区分 `SUCCESS`、`CANCELLED`、`TIMEOUT` 和 `REPLACED`。旧版 `input_detected(input_event)` 仍保留为兼容投影：成功时传回输入事件，非成功结束时传回 `null`。需要日志、诊断或跨 JSON 边界输出时，可调用 `GFInputDetectionResult.to_dictionary()`，其中输入事件会通过 `GFInputEventIdentity` 转成稳定身份字典。

`elapsed_seconds` 从调用 begin 起一直累计到最终 finish，包含 countdown、clear 和正式等待输入阶段；`timeout_seconds <= 0` 只关闭超时，不会关闭计时。非有限 delta 不会推进会话，`GFInputDetectionResult.create()` 与 `to_dictionary()` 都会把非有限 elapsed 规范为 0，因而 JSON-safe 结果不会依赖 `JSON.stringify()` 把 NaN/Infinity 退化为 `null`。

detector signal 使用同步派发，但允许 handler 调用 begin/cancel。重复 begin 会先让旧会话以 `REPLACED` 完成；如果旧会话的 finish handler 又开始一轮检测，handler 创建的最新会话优先，仍在返回中的旧 begin 调用栈不会再覆盖它。这样每个已发出 `detection_started` 的会话都会获得一次明确 finish。

默认检测只接受适合作为绑定的离散输入，例如按键、鼠标按钮、手柄按钮和手柄轴阈值，不把鼠标移动、触摸拖动或普通指针位移当作可绑定动作。项目确实要记录连续值输入时，应显式配置 value type 过滤，并在 UI 中说明该绑定的运行时语义。

`GFInputFormatter` 提供轻量文本格式化，便于设置界面展示当前绑定。Joypad 默认会通过 `GFInputDeviceTextProvider` 输出抽象方位文本，例如 Button South、Left Stick X，也可通过 options 或注册自定义 `GFInputTextProvider` 替换为平台图标、图标字体或本地化文本。默认静态入口使用 `GFInputFormatterRegistry` 的全局默认实例；设置页、测试或编辑器工具需要临时 provider 时，应优先创建局部 registry，并在调用 options 中传入 `formatter_registry`，避免污染其它场景。

provider 的 `priority` 是实时优先级，不是注册时快照；每次查询或格式化都会在裁剪失效 owner 后按当前值稳定重排，同优先级继续按注册顺序裁决。运行时改变平台专用 provider 的优先级会立即影响文本和图标选择。

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

需要局部作用域时，`register_text_provider()` / `register_icon_provider()` 会返回 `GFInputProviderRegistration` 句柄，用于在面板关闭、插件卸载或测试清理时显式释放注册：

```gdscript
var registry := GFInputFormatterRegistry.new()
var registration := registry.register_icon_provider(icons, settings_panel)
var rich_text := GFInputFormatter.input_event_as_rich_text(jump_binding.input_event, {
	"formatter_registry": registry,
})
registration.release()
```

图标 provider 不附带任何图片资源，也不规定平台品牌、按钮文案或美术风格。项目可以用 `icon_paths` 精确映射少量按钮，也可以用路径模板批量组织素材；`split_key_modifiers` 会把 Ctrl/Shift/Alt/Meta 组合键拆成多个图标，便于设置界面显示。`GFInputIconAtlasProvider` 会缓存成功加载的纹理，也会按 `cache_missing_paths` 和 `max_cached_missing_paths` 缓存缺失路径，避免设置 UI 重复探测同一个不存在的资源；项目热更新图标资源后可调用 `clear_cache()`。

`GFInputEventIdentity` 是输入事件语义身份的公共值对象。需要自己写 provider、冲突 UI 或调试报告时，可以通过 `from_event()` 读取 `kind`、`conflict_key`、`icon_key` 和 `device_id`，或通过 `get_icon_candidates()` 复用框架的图标候选键规则。它只描述物理/语义输入身份，不读取项目 `InputMap`，也不把业务动作写死进框架。

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

`GFInputConflictAnalyzer` 可在保存重绑定前检查同一上下文或跨上下文的有效输入冲突，也可以通过 `build_rebind_report()` 一次性获取有效绑定条目和冲突列表。它只读取资源和重映射配置，不接管运行时输入逻辑。`GFInputContextDiagnostics` 在冲突报告之上补充输入上下文结构诊断，例如空上下文标识、空映射、缺失动作、重复 `action_id`、空绑定、无效死区、空修饰器/触发器槽位，以及 `InputEventAction` 是否缺少 ProjectSettings/Input Map action；`activation_threshold` 与 binding `deadzone` 的 `NaN` / Infinity 也会作为无效数值报告。

编辑器中的 `GFInputMappingDock` 渲染 `GF Workspace > Input` 页面，并复用该诊断工具输出标准校验报告字段。默认只诊断 `GFInputContext` 的资源绑定；项目编辑器工具需要检查玩家或 profile 的有效重绑定时，可调用 `set_remap_config()` 注入 `GFInputRemapConfig`。预算预扫、正式冲突报告、动作行、绑定行和详情会共同使用该配置；`remap_configured` 说明本次报告是否包含覆盖。通过 `GFInputRemapConfig.set_binding()`、`unbind()`、`clear_binding()`、`set_custom_data()` 或成功的 `apply_dict()` 修改当前配置后，Dock 会观察 `Resource.changed`，并把同帧重复变化合并为一次刷新；显式 `refresh()` 仍同步执行。

路径加载只接受 `res://` / `user://` 下可在实例化前检查主类型的 `.tres`，并在缓存身份比较前折叠斜杠、`.` 与 `..` 别名。加载失败会保留并继续显示上次已提交上下文；复制内容同时包含当前失败和 `last_successful_report`，不会把不可见旧报告冒充为本次成功结果。页面仍然只读，不保存项目按键配置，也不规定输入设置界面布局。
