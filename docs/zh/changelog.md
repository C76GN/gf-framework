# 更新日志 (Changelog)

## [未发布]

**版本概述**：GF Framework 13.0.0 正在开发。新增可选并发通知，并降低了稳定画布和战术地图反复进行空间查询的固定开销。

### 🚀 新增特性 (Added)

- 通知队列可配置多个活动名额。每条通知独立计时，结束后按等待优先级补位。项目负责通知的布局和动画。

### 🐛 Bug 修复 (Fixed)

- 2D 空间索引在记录和配置稳定时复用四叉树及建树失败后的线性回退，只检查可能失效的弱对象身份。使用值 ID 的项目在连续点查、半径查询和框选时省去预处理阶段的全表扫描。

### 🔧 API 变动说明 (API Changes)

- `GFNotificationUtility` 新增 `max_active_notifications`、`get_active_notifications()`、`dismiss_notification()` 和 `invoke_notification_action()`。

### 📘 升级指南 (Migration Guide)

通知队列默认继续串行展示，现有调用方式可直接使用。需要堆叠多条通知时，按[通知队列指南](standard/utilities/runtime/debug-observability/support-notifications/notifications.md#并发通知)设置活动上限，并用通知 ID 管理展示实例。

已安装 GF Framework 12.0.x 的项目可以继续使用当前版本。下一正式版发布后，请按对应的升级说明迁移。

需要从更早版本迁移到 12.0.0 时，请查阅该版本的[更新日志与升级指南](https://github.com/C76GN/gf-framework/blob/12.0.0/docs/zh/changelog.md)。

通用包、Windows x64 完整包和同版本原生补充包可从 [12.0.1 发布页](https://github.com/C76GN/gf-framework/releases/tag/12.0.1)下载。
