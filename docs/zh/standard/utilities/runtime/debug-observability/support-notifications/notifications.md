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

## 更新同一条通知

保存 `push_notification()` 返回的 ID，即可在任务推进时调用 `update_notification(id, changes)`。等待和活动记录都能更新。通知保留 ID、去重 key、优先级、队列位置、剩余时间和暂停状态。显式 key 继续匹配原 key，按正文去重的记录则匹配更新后的正文。

```gdscript
var export_id: int = notifications.push_notification("准备导出", "导出", GFNotificationUtility.Level.INFO, {
	"key": "export",
	"sticky": true,
	"actions": [{"id": "cancel", "label": "取消"}],
})
notifications.update_notification(export_id, {"message": "正在写入文件"})
# 进入终态后撤下取消按钮。项目可以在用户确认后按 ID 关闭这条常驻通知。
notifications.update_notification(export_id, {
	"message": "导出完成",
	"level": GFNotificationUtility.Level.SUCCESS,
	"actions": [],
})
```

`changes` 可包含 `title`、`message`、`level` 和 `actions`。省略的字段保留原值，传入 `actions` 会替换整组动作。标题和正文至少有一项非空。无效字段或值返回 `ERR_INVALID_PARAMETER`，整次更新作废。已经结束或被丢弃的 ID 返回 `ERR_DOES_NOT_EXIST`。

成功返回 `OK`。内容发生变化时，`notification_updated(id)` 发出通知 ID。展示器可用 `get_notification(id)` 取得当前记录的副本，刷新已创建的视图。如果较早执行的监听器又更新了内容，这次读取会拿到最新值。如果它已关闭通知，读取会返回空字典。等待记录在之后的 `notification_started` 中直接带上最新内容。重复写入相同内容不会再次发出信号。

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
