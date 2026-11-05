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

显式传入 `key` 时只按 key 去重；没有 key 时才按消息文本去重，因此不同业务上下文可以显示相同正文。`max_queue_size = 0` 表示只保留当前通知，不保留等待队列；等待队列会按优先级排序，容量不足时优先丢弃低优先级通知。`sticky = true` 的通知不会因时长自动结束，适合需要玩家确认或等待外部事件的提示。

`pause_active()` / `resume_active()` 可暂停当前通知的时长推进，`invoke_active_action(action_id)` 会广播 `notification_action_invoked`，并在 action 配置 `dismiss = true` 时关闭当前通知。

通知系统只维护数据、优先级、暂停和动作意图；按钮样式、焦点、快捷键、Toast 动画和多端适配仍由项目 UI 层决定。

`clear_notifications()` 和 `dispose()` 都会在通知完成回调前撤下当前通知；回调再次调用 `dismiss_active()` 不会为同一个通知 ID 重复发布 `notification_finished`。
