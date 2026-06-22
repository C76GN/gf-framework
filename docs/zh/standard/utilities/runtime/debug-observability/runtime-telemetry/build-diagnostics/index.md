# 构建信息与诊断快照

本组文档说明构建信息采集、运行时诊断快照、诊断命令、信号图和监控预设。诊断数据只表达运行状态，不负责线上权限、脱敏和远程控制策略。

## 阅读入口

- [构建信息快照](build-info.md)：`GFBuildInfo`、`GFBuildInfoUtility` 和导出前构建元数据写入。
- [诊断快照与命令](diagnostics-commands/index.md)：`GFDiagnosticsUtility`、快照采集、命令 schema 和命令风险等级。
- [信号图、工具快照与监控预设](signals-monitors.md)：场景树快照、信号图、工具快照 provider 和监控导出。

## 使用边界

这些工具只提供版本、队列、缓存、pending 数量、日志、信号连接和运行状态等通用数据。若要暴露给远程调试、玩家可访问控制台或线上 GM 工具，应在项目层做脱敏、白名单过滤和权限控制。
