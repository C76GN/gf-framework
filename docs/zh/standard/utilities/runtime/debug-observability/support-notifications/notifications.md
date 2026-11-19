# 通知队列

`GFNotificationUtility` 提供通知数据队列、去重、时长推进和生命周期信号，不内置 Toast/HUD 样式。项目可以监听 `notification_started` 渲染自己的 UI，也可以把它接到日志、编辑器面板或测试流程。

```gdscript
var notifications := Gf.get_utility(GFNotificationUtility) as GFNotificationUtility
notifications.notification_started.connect(func(notification: Dictionary) -> void:
	show_toast(notification["title"], notification["message"])
)

notifications.push_notification("配置已保存", "设置", GFNotificationUtility.Level.SUCCESS)
```

`push_notification()` 可通过 `options` 设置 `duration_seconds`、去重 `key`、项目自定义 `metadata`、`priority`、`sticky` 和 `actions`；返回值是通知 ID，被重复抑制时会返回已有通知 ID。通知 action 只要求稳定 `id`，`label` 不会由框架自动生成，项目 UI 可按本地化、图标或上下文自行映射。

显式传入 `key` 时只按 key 去重。省略 key 时，去重范围是同样省略 key 且正文相同的记录。活动通知和等待队列都参与去重。等待队列按优先级降序排列，同优先级按入队顺序处理。等待容量不足时从队尾丢弃，结束原因为 `dropped`。`max_queue_size = 0` 时，活动名额填满后到达的通知直接丢弃。

`sticky = true` 的通知展示到显式关闭，适合需要玩家确认或等待外部事件的提示。`pause_active()` 和 `resume_active()` 控制当前通知的倒计时。`invoke_active_action(action_id)` 会广播 `notification_action_invoked`，动作配置 `dismiss = true` 时会关闭该通知。

## 并发通知

默认每次展示一条通知。把 `max_active_notifications` 设为大于 1 的整数即可启用并发，取值会限制在 1 至 32。提高上限会立即用等待队列补位。降低上限时，已有通知按各自生命周期继续展示，腾出名额后再补位。

```gdscript
notifications.max_active_notifications = 3
var saved_id: int = notifications.push_notification("配置已保存")
var exported_id: int = notifications.push_notification("导出已完成")
var active_notifications: Array[Dictionary] = notifications.get_active_notifications()
```

每条通知从开始展示时单独计时。`get_active_notifications()` 按开始展示的顺序返回记录副本。按 ID 关闭用 `dismiss_notification(id)`，触发动作则用 `invoke_notification_action(id, action_id)`。两者都只接受活动 ID。旧的单条入口以最早开始展示且仍在活动的通知为目标。

展示器可用 `notification_started` 和 `notification_finished` 按 ID 建立和移除 UI。项目决定分组、位置、堆叠顺序、焦点、样式和动画。

同一帧到期的活动通知会先一并撤下，然后发出结束信号并从等待队列补位。补入的通知从下一次 tick 开始消耗时长。`clear_notifications()` 和 `dispose()` 会先撤下全部活动通知并清空等待队列，再为每条原先活动的通知发出一次结束信号。在清空或释放的回调期间，`push_notification()` 返回 `0`。
