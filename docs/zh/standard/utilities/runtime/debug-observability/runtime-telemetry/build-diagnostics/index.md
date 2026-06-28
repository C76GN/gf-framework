# 构建信息与诊断快照

本组文档说明构建信息采集、运行时诊断快照、诊断命令、信号图和监控预设。诊断数据只表达运行状态，不负责线上权限、脱敏和远程控制策略。

## 阅读入口

- [构建信息快照](build-info.md)：`GFBuildInfo`、`GFBuildInfoUtility` 和导出前构建元数据写入。
- [诊断快照与命令](diagnostics-commands/index.md)：`GFDiagnosticsUtility`、快照采集、命令 schema 和命令风险等级。
- [操作诊断时间线](operation-diagnostics.md)：`GFOperationDiagnosticsUtility` 的操作、阶段耗时、异常事件和健康快照。
- [信号图、工具快照与监控预设](signals-monitors.md)：场景树快照、信号图、工具快照 provider 和监控导出。

## 使用边界

在编辑器中运行带有 GF 的项目时，标准插件会提供 `GF Runtime Debugger` 调试器页。`GFRuntimeDebuggerPlugin` 为每个 Godot 调试会话创建 `GFRuntimeDebuggerTab`，并通过 Godot 调试器通道请求 `GFDiagnosticsUtility` 的快照、命令目录和受保护命令结果，不要求项目额外搭 UI。运行侧仍需要正常初始化 `GFDiagnosticsUtility`，命令执行也继续遵守 `max_command_tier`、认证 token 和 `allow_danger_commands`。

这些工具只提供版本、队列、缓存、pending 数量、日志、信号连接和运行状态等通用数据。若要暴露给远程调试、玩家可访问控制台或线上 GM 工具，应在项目层做脱敏、白名单过滤和权限控制。
