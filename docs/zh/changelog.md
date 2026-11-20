# 更新日志 (Changelog)

## [12.0.2] - 2026-11-20

**版本概述**：对象池允许同一节点同时作为挂载父节点和借用接收方。此补丁修复了这种用法触发的重复信号连接报错。

### 🐛 Bug 修复 (Fixed)

- 调用 `await pool.acquire(scene, self, self)` 时，每个请求只监听一次当前节点的 `tree_exiting`。如果节点在交付前离树，请求以 `CANCELLED / validation / parent_lost` 结束，重新入树也不会恢复已取消的借用。

### 📘 升级指南 (Migration Guide)

- GF 12.0.x 项目可更新整个 `addons/gf/`，继续使用原有借用调用。如果项目已有独立的生命周期接收方，可继续用它管理待交付请求。
- 从 GF 11 或更早版本升级时，请先查阅 [12.0.0 的迁移说明](https://github.com/C76GN/gf-framework/blob/12.0.0/docs/zh/changelog.md#1200---2026-11-18)。
