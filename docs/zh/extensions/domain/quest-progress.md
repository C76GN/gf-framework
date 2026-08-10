# 任务与进度

Domain 扩展中的 `GFQuestUtility` 用于构建成就、任务及进度累加系统。它基于解耦的数据事件工作，例如每一次击杀发送一条轻量级事件。

## 基础流程

```gdscript
var quest := Gf.get_utility(GFQuestUtility) as GFQuestUtility

# 开始一个任务，监听自定义进度事件，目标为 10 次
quest.start_quest(&"sample_progress", &"progress_event", 10)

# 在项目自己的规则逻辑中推进进度
Gf.send_simple_event(&"progress_event", 1)

# 获取进度或判断完成
var progress := quest.get_quest_progress(&"sample_progress")
var done := quest.is_quest_completed(&"sample_progress")

quest.define_quest(&"gated_progress", &"progress_event", 3, { "category": "optional" })
quest.accept_quest(&"gated_progress")
quest.add_completion_blocker(&"gated_progress", func(quest_id: StringName, report: Dictionary) -> Dictionary:
	return { "ok": _can_finish_quest(quest_id), "reason": "blocked" }
)
```

事件 payload 可以直接是数字，也可以是包含 `amount` 的字典；浮点数会四舍五入，无法解析时默认增加 `1`。默认情况下负数 amount 会被钳制为 `0`，避免异常事件让任务进度倒退；确实需要扣减进度时，可显式设置 `allow_negative_progress = true`。

`quest_id` 和 `target_event` 不能为空。`get_quest_progress()` 返回 `0.0` 到 `1.0` 的比例，即使内部计数因负数事件暂时低于 0，也会按公开百分比范围钳制；`quest_progressed` 信号会额外给出当前值和目标值。`target_count <= 0` 的任务会在开始后立即完成。

## 定义、接取与状态

`start_quest()` 仍是“一步开始监听”的兼容入口；需要先声明再接取时，可用 `define_quest()` / `accept_quest()`，并通过 `get_quest_status()`、`get_quests_by_status()`、`get_quest_report()` 和 `get_debug_snapshot()` 查询运行时状态。

`quest_started` 是提交后信号：监听器收到它时，正目标任务已经进入 active 并完成目标事件订阅，所以回调中同步发送目标事件不会丢失。回调中同步取消或失败同一任务时，已经提交的终态优先，外层开始/接取流程不会重新附着监听器或覆盖终态。

`add_acceptance_condition()` 可在接取前执行通用条件检查，返回 `false` 或 `{ "ok": false, "reason": "..." }` 时会发出 `quest_acceptance_blocked` 并保持 available。

`add_completion_blocker()` 只决定能否从 active 进入 completed，不发奖励、不解锁关卡、不解释原因含义。条件或阻塞器是同步项目回调；如果它在执行期间先取消、失败或清空任务，GF 会在继续转换前重新核对任务身份与状态，避免同一任务提交两个互斥终态。`fail_quest()` 会把任务置为 `STATUS_FAILED` 并注销事件监听，`cancel_quest()` 也只更新任务状态。完成、失败或取消某事件上的最后一个 active 任务时，工具会注销对应 simple event 监听器，避免空任务列表继续接收事件。

## 任务树

复杂任务链可以用 `set_quest_parent()` 建立父子关系，再通过 `get_child_quests()` 和 `get_quest_tree_report()` 获取树形报告与聚合进度。

父子关系只用于组织和调试，不自动完成父任务、不自动接取子任务，也不定义奖励、失败传播或章节解锁：

```gdscript
quest.define_quest(&"chapter_1", &"chapter_event", 1)
quest.define_quest(&"find_key", &"key_found", 1)
quest.set_quest_parent(&"find_key", &"chapter_1")

var tree_report := quest.get_quest_tree_report(&"chapter_1")
print(tree_report["aggregate_progress"])
```

需要保存任务状态时，项目层应把任务定义、父子关系、条件来源和进度数据放进自己的 Model 或存档结构。
