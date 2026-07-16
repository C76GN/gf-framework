# 运行时任务调度

`GFRuntimeTaskScheduler` 用来表达运行中的互斥任务：任务声明自己占用哪些对象 requirement，调度器负责冲突判断、可中断替换、按帧推进、默认任务恢复和诊断快照。

这个能力适合角色默认行为、临时工具模式、交互流程、编辑器状态或项目自定义运行时编排。框架不绑定输入事件、动画节点、角色控制器或具体 UI；项目层只把这些业务含义映射为任务。

## 核心类型

- `GFRuntimeTask`：任务协议，通过 `set_requirements()`、`add_requirement()`、`remove_requirement()` 和 `get_requirements()` 管理占用对象，并声明 `interruptible`、`initialize()`、`tick()`、`physics_tick()`、`is_finished()` 和 `end()`。
- `GFCallableRuntimeTask`：用 `Callable` 快速声明轻量任务。
- `GFRuntimeTaskGroup`：把多个任务组合为顺序、等待全部或竞速完成。
- `GFRuntimeTaskScheduler`：负责调度、冲突仲裁、默认任务恢复和活动任务查询。

## Requirement 仲裁

同一个 requirement 同一时间只会归一个任务所有。新任务请求已占用的 requirement 时：

- 占用任务不可中断：新任务被拒绝，调度器发出 `task_rejected`。
- 占用任务可中断：旧任务收到 `end(true)`，新任务进入调度器。

Requirement 可以是项目认为需要互斥占用的任意 `Object`，例如角色节点、工具上下文、运行时控制域或一个专门的 `RefCounted` token。不要把 requirement 用作业务状态枚举；它只表示“这段资源当前只能有一个任务控制”。

任务进入调度器后不能再修改 requirement；需要变更占用对象时，应取消任务并重新调度。任务组在调度前会按子任务当前 requirement 重建聚合占用；并行任务组会拒绝包含重复 requirement 的子任务，避免组内绕过同一对象的互斥规则。

## 默认任务

`register_default_task(requirement, task)` 可为 requirement 注册默认任务。调度器发现 requirement 空闲时会自动调度默认任务；前台任务可以中断可中断默认任务，结束后默认任务会在后续推进中恢复。

## 使用示例

```gdscript
var actor_token: RefCounted = RefCounted.new()
var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()

var idle_task: GFCallableRuntimeTask = GFCallableRuntimeTask.new(
	func(_task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> void:
		pass,
	func(delta: float, _task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> void:
		pass
)
idle_task.finish_after_initialize = false
scheduler.register_default_task(actor_token, idle_task)

var interact_task: GFCallableRuntimeTask = GFCallableRuntimeTask.new(
	func(_task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> void:
		pass
)
interact_task.add_requirement(actor_token)
scheduler.schedule(interact_task)
```

## 使用边界

- 需要撤销、重做和历史栈时，优先使用 `GFCommandHistoryUtility` 与 `GFUndoableCommand`。
- 需要一次性顺序流程、Signal 等待和失败报告时，优先使用 `GFCommandSequence`。
- 需要动画、Tween 或视觉动作编排时，优先使用 ActionQueue 相关类型。
- 运行时任务调度器关注“谁现在占用什么并如何被推进”；业务解释、日志等级、用户提示和具体恢复策略留给项目层。
