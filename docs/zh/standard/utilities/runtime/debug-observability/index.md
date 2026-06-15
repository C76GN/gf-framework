# 调试、日志、诊断与控制台

本组页面覆盖 GF 标准库中的开发期观测、运行时日志、构建信息、诊断快照、支持报告、通知队列和控制台。每个工具只提供通用结构和生命周期入口，不规定项目业务语义、线上权限或玩家 UI。

## 阅读入口

- [调试可视化、运行时检查与信号诊断](debug-visual-inspection/index.md)：`GFDebugDrawUtility`、`GFDebugOverlayUtility`、`GFScreenshotUtility`、`GFRuntimeInspectorUtility`、`GFSceneSignalAudit` 与 `GFSignalRuntimeProbe`。
- [随机种子、日志、构建信息与诊断](runtime-telemetry/index.md)：`GFSeedUtility`、`GFLogUtility`、`GFBuildInfoUtility` 与 `GFDiagnosticsUtility`。
- [支持报告与通知队列](support-notifications/index.md)：`GFSupportReportUtility` 与 `GFNotificationUtility`。
- [运行时开发者控制台](developer-console/index.md)：`GFConsoleUtility` 与资源化控制台命令。

## 使用边界

- 面向开发期和内部工具的能力默认不应暴露给玩家。
- 日志、诊断、支持报告和截图可能包含敏感信息，项目层必须负责脱敏、权限和上传策略。
- Overlay、信号探针和控制台都应限制范围，避免在大型场景或生产构建中默认开启高成本观测。
- 需要查具体类、属性和方法签名时，使用 [API Reference](../../../../reference/api/standard.md)。
