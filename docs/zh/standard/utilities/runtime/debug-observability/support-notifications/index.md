# 支持报告与通知队列

本组页面覆盖支持报告聚合和通用通知数据队列。GF 只提供结构化数据和生命周期信号，上传、工单、Toast/HUD 样式和玩家可见策略由项目层负责。

## 阅读入口

- [支持报告](support-report.md)：`GFSupportReportUtility` 的分区聚合、诊断快照、JSON / Markdown 导出，以及 `GFSupportReportWorkflow` 的离线提交编排。
- [附件与提交](attachments-submit.md)：附件收集、截图、大小限制和 `submit_report()`。
- [通知队列](notifications.md)：`GFNotificationUtility` 的队列、去重、优先级、sticky 和 action。

## 使用边界

支持报告和通知队列只提供通用数据结构、附件收集、离线请求描述和队列生命周期。上传目标、工单系统、玩家 UI、Toast 样式、权限和隐私策略应由项目层控制。
