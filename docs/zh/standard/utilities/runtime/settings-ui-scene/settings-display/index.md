# 设置与显示应用

本组页面覆盖通用设置存储、显示设置应用和表单控件绑定。它们负责稳定键、类型转换、持久化和 Godot 显示/audio API 应用，不规定具体设置页 UI 或项目业务含义。

## 阅读入口

- [通用设置存储](settings-utility.md)：`GFSettingsUtility`、`GFSettingDefinition`、持久化、暂存应用、批处理和预设应用。
- [显示、语言与音频总线](display-application.md)：`GFDisplaySettingsUtility` 对窗口、VSync、语言和 Audio Bus 的应用。
- [表单控件绑定](form-binding.md)：`GFControlValueAdapter`、`GFFormBinder` 和控件值变化连接生命周期。

## 使用边界

这组工具只提供设置定义、读写、持久化和应用边界。具体设置项命名、分组、显示文案、平台差异和业务含义仍由项目层决定。
