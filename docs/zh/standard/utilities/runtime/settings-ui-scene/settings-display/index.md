# 设置与显示应用

本组页面覆盖通用设置内存核心、可替换持久化 Store、显示设置应用和表单控件绑定。它们负责稳定键、类型转换、持久化生命周期和 Godot 显示/audio API 应用，不规定具体设置页 UI 或项目业务含义。

## 阅读入口

- [通用设置存储](settings-utility.md)：`GFSettingsUtility`、`GFSettingsStoreUtility`、File/Null/Storage adapter、Architecture 激活、静默取消边界、显式重试、暂存应用和批处理。
- [显示、语言与音频总线](display-application.md)：`GFDisplaySettingsUtility` 对窗口、VSync、语言和 Audio Bus 的应用。
- [表单控件绑定](form-binding.md)：`GFControlValueAdapter`、`GFFormBinder` 和控件值变化连接生命周期。
- [列表与模板绑定](list-repeat-binding.md)：`GFItemListBinder` 和 `GFRepeaterBinder` 的数组条目、store path 与模板副本同步。
- [控件焦点顺序](control-focus-order.md)：`GFControlFocusUtility` 收集可聚焦控件，按显式顺序写入 Tab 和方向导航路径。

## 使用边界

这组工具只提供设置定义、读写、Store capability、持久化生命周期和应用边界。具体设置项命名、分组、显示文案、平台差异、后端服务选择和业务含义仍由项目层决定。
