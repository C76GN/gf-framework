# 显示、语言与音频总线

`GFDisplaySettingsUtility` 把通用设置应用到 Godot 的窗口、VSync、语言和音频总线层。它只处理常见引擎 API 边界，不定义项目设置页 UI、文案或业务分组。

```gdscript
var display := Gf.get_utility(GFDisplaySettingsUtility) as GFDisplaySettingsUtility

display.set_fullscreen(true)
display.set_vsync_mode(DisplayServer.VSYNC_ENABLED)
display.set_locale("zh_CN")
display.register_audio_bus_volume("Master", 1.0)
display.set_audio_bus_volume("Master", 0.75)
```

当 `GFSettingsUtility` 中的窗口模式被外部 UI 或配置流程改回窗口模式时，`GFDisplaySettingsUtility` 会同步应用已记录的窗口尺寸。离开窗口模式前会捕获最后一个有效窗口尺寸；如果应用在全屏模式启动且还没有持久化尺寸，则使用 `default_windowed_size`，未显式配置时再从项目 window override 或 viewport 尺寸推导，不会把当前全屏分辨率误记为窗口尺寸。

Architecture 模式会先让全部 Utility 完成 `ready()`，再在 activation 中由 Settings Store 恢复持久化状态。`apply_on_ready=true` 时，Display 会先应用 ready 阶段的当前值，并在 `settings_load_completed` 报告 `was_applied()` 后对完整恢复状态重新执行一次 `apply_all()`；因此 `Architecture.init()` 成功返回时，引擎窗口、VSync、语言和音频总线已经与加载后的 Settings 一致。失败、缺失或仅保留当前值的加载不会触发这次重复应用；`apply_on_ready=false` 会同时关闭 ready 阶段和延迟加载完成后的自动应用。

`default_windowed_size` 只解决“尚无 last-known-windowed 值”的初始化边界。全屏、无边框窗口、显示器切换和平台特定分辨率策略仍应由项目层决定。

音频总线的线性音量只接受有限数值：有限但超出 `0..1` 的输入会被钳制，`NaN` / `Inf` 会在写入设置和调用音频后端前被拒绝，并保留最后一个有效值。注册默认值、读取 fallback 或持久化数据遭到非有限值污染时，也会恢复到有限的 `0..1` 范围。

显示设置是否允许某个分辨率、是否需要平台白名单、是否要同步到项目配置档，仍由项目层决定。
