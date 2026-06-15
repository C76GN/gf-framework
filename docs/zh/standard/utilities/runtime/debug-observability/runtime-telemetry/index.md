# 随机种子、日志、构建信息与诊断总览

这一组运行时观测工具覆盖可复现随机流、结构化日志、构建信息和诊断快照。它们用于开发期排查、支持报告和运行状态导出，不替代项目自己的权限、脱敏、线上采集或崩溃分析策略。

## 阅读入口

- [随机种子与可复现随机流](seed-utility.md)：`GFSeedUtility`、全局种子、主 RNG 状态、Godot 分支 RNG 和 deterministic 分支随机源。
- [结构化日志与日志 Sink](log-utility/index.md)：`GFLogUtility`、本地日志、内存缓存、JSONL sink 和批量 sink。
- [构建信息与诊断快照](build-diagnostics/index.md)：`GFBuildInfoUtility`、`GFDiagnosticsUtility`、诊断命令、信号图和监控预设。

## 使用边界

这些工具只提供通用观测数据和导出入口。需要上传日志、远程控制命令、玩家可访问控制台或线上 GM 工具时，应在项目层增加鉴权、脱敏、白名单和速率限制。
