# 红点计数与树形聚合

`GFUIBadgeUtility` 接收项目计算的叶子计数，沿单父级树向上聚合。它维护可重建的显示数据，不代替未读邮件、可领奖任务等业务事实，也不直接创建显示控件。

```gdscript
var badges: GFUIBadgeUtility = GFUIBadgeUtility.new()
badges.configure({
	"home": "",
	"mail": "home",
	"quests": "home",
	"quest_claimable": "quests",
})
badges.set_leaf_count(&"mail", 3)
badges.set_leaf_count(&"quest_claimable", 2)
# home = 5，quests = 2；聚合节点不能直接写入。

var binding: GFSubscriptionToken = badges.bind_count(
	&"home", update_badge_count, self
)
# 回调立即收到当前 count:int。多个控件可以分别绑定同一个 ID。
# 控件不再使用此绑定时：
binding.cancel()
```

`configure` 先验证完整候选再发布。一个实例只接受一次有效结构；结构变化时创建新实例并重新绑定控件。允许多个根，空父 ID 表示根；未知父级、自环、环、规范化重复 ID、空节点 ID 或首尾空白均被拒绝。第一次配置失败可以修正后重试。

每个叶子计数范围为 `0..1000000000`；最多 4096 个节点，父链最多 64 层。总计使用整数，结构与叶子上限保证不会溢出。`set_leaf_count` 只沿该叶子的祖先链更新，输入与当前值相同不发通知。`get_count` 对未知 ID 返回 `-1`，避免把拼错的配置误判为没有提醒。

`counts_changed` 发出本次改变的节点 ID 与新值。状态在通知前完整提交；回调可以查询聚合值、修改其他叶子或解除绑定。重入更新排队，已绑定控件按提交顺序收到变化，新绑定先收到最新值并跳过更早的排队通知。每次处理最多 256 批，其余由 tick 继续；队列最多 4096 批，超限写入返回 false 且不修改状态。该限制避免业务回调循环更新阻塞一整帧。

`bind_count` 返回既有 `GFSubscriptionToken`，同一 ID 可以有多个独立绑定，取消一个不会影响其他绑定。可绑定最多 4096 个控件。Node owner 必须已经入树，离树立即解绑；普通 Object owner 销毁在 tick 或下一次通知时清理。不要在回调闭包里强持有期望自动销毁的 owner。无 owner 的绑定须显式取消。服务释放后所有 token 失效。

项目在存档恢复、配置切换或账号切换完成后，从已确认的业务状态重新计算叶子计数。UI 不应反向把聚合计数写进业务存档，也不应把红点作为购买、领取或权限判断依据。树不支持任意 DAG、跨父级重复计数或表达式执行；这些聚合规则由项目明确计算为叶子输入。

## 配置诊断

`validate_configuration(parents)` 只读返回 `ok`、`error_kind`、`path`，不发布结构、不触发通知、不占用首次配置机会。`configure()` 共用同一候选验证；两次调用之间修改输入或服务状态后，必须以实际配置结果为准，报告不是准入令牌。

错误码区分 `service_disposed`、`already_configured`、`required`、`invalid_type`、`invalid_id`、`length_limit`、`node_limit`、`duplicate_id`、`missing_parent`、`cycle` 和 `depth_limit`。路径如 `/parents/mail`；ID 中的 `~`、`/` 分别转义为 `~0`、`~1`。缺父级、环或深度错误定位触发检查的起始节点。容量错误附 `limit`、`observed`；深度超限的 `observed_is_lower_bound` 为 true，表示已确认的链长度下界。多个错误只报告当前首先遇到的一项。

诊断不开放运行中更换拓扑；已成功配置的实例仍按原契约拒绝第二次配置。报告内容可用于项目自己的配置提示，不需要匹配错误文本或读取服务内部字段。
