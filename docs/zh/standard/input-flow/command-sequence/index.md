# 撤销历史与指令序列

本组页面覆盖可撤销命令历史和顺序流程编排。它们适合编辑器、棋盘、流程脚本和可回滚交互；框架只处理执行顺序、历史栈、等待、回滚入口和架构注入，不解释项目业务含义。

## 阅读入口

- [可撤销命令历史](undo-history.md)：`GFUndoableCommand`、快照、`GFCommandHistoryUtility`、撤销和重做。
- [通用指令序列](sequence.md)：`GFCommandSequence`、`GFSequenceStep`、callable 步骤和 Signal 等待。
- [取消、超时与失败策略](failure-cancel.md)：`cancel()`、Signal 超时、失败结果字典、`stop_on_error` 和 `rollback_on_failure`。
- [运行时任务调度](runtime-task-scheduler.md)：`GFRuntimeTaskScheduler`、requirement 仲裁、默认任务和任务组。

## 使用边界

- 快照应保存可恢复的纯数据，不应直接保存运行时对象引用。
- 异步命令或步骤的超时只能停止等待流程，不会自动撤销已经发生的副作用。
- 失败报告只描述流程执行状态；错误语义、用户提示、日志等级和恢复策略由项目层决定。
- 运行时任务的 requirement 应指向需要互斥占用的对象；框架只保证仲裁，不定义业务状态机。
