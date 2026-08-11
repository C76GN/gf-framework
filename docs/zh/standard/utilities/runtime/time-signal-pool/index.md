# 时间、信号与对象池

这一组运行时基础服务面向系统层常见的延迟计时、时间缩放、信号桥接和对象复用需求。

## 阅读入口

- [逻辑延迟定时器](timer-utility.md)：`GFTimerUtility` 的一次性延迟、重复任务、owner 清理和调试快照；需要测试、回放或模拟中手动推进整数 tick 时使用 `GFManualTimerQueue`。
- [动态时间缩放](time-utility.md)：`GFTimeUtility` 的全局缩放、分组暂停和物理子步。
- [民用日期与月历网格](civil-date-calendar-grid.md)：纯数学的 Gregorian 日期、ISO 周、显式日期运算结果和 7 列月历数据。
- [异步取消、等待与进度](async-primitives.md)：Kernel 级 `GFCancellationToken`、`GFCancellationSource`、`GFAsyncCompletion`，以及标准层 `GFAsyncWaitUtility`、`GFMainThreadDispatchQueue`、`GFDeferredMutationQueue`、`GFExecutionRequirement`、`GFAsyncKeyedGate`、`GFRequestHandlerRegistry` 与 `GFExecutionLaneDiagnostics`。
- [按 Key 的异步租约门禁](keyed-gate.md)：`GFAsyncKeyedGate` 的等待、fail-fast、公平推进、取消、超时和通知重入边界。
- [原生信号连接工具](signal-utility/index.md)：`GFSignalUtility`、链式信号处理、owner 断开和信号桥接。
- [节点对象池](object-pool.md)：`GFObjectPoolUtility` 的借出、归还、预热、hook 和调试计数。

## 使用边界

本组服务面向通用运行时协调，不表达业务事件语义。业务模块之间的通信使用 Kernel 事件系统；资源加载、下载和后台任务使用 [资源、存储与 IO](../../io/index.md)。
