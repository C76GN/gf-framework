# Sensor 与 Receiver

如果项目需要把场景节点之间的交互发送与接收标准化，可使用 `GFInteractionSensor` 和 `GFInteractionReceiver`。Sensor 负责构建上下文并调用接收对象的 `receive_interaction()`；Receiver 提供启用状态、交互 ID 白名单/黑名单、自定义校验回调和统一报告。

```gdscript
var sensor := GFInteractionSensor.new()
sensor.interaction_id = &"use"
sensor.payload = { "source": "keyboard" }

var receiver := GFInteractionReceiver.new()
receiver.accepted_interaction_ids = [&"use"]
receiver.validation_callback = func(context: GFInteractionContext, report: Dictionary) -> Dictionary:
	return {
		"ok": context.sender != null,
		"metadata": {
			"checked": true,
		},
	}

var result := sensor.send_to(receiver)
```

返回报告用于日志和诊断，`receiver` 字段是 `GFReportValueCodec` 生成且只经过一次编码的 JSON-safe Object 摘要，不是 live `Object`；Sensor 会保留框架 Receiver 已完成的受信报告字段，并只编码其余原始字段，避免 marker 被再次包装成 Dictionary marker。需要接收对象实例时，使用发送/接收信号里的 `receiver` 参数，或读取 `GFInteractionContext.target`。

## 业务目标桥接

当碰撞区域只承担检测和过滤，而业务目标在角色、物品或能力节点上时，可以把 `GFInteractionReceiver` 放在碰撞对象自身或其父级，并通过 `receiver_path` 指向真正的业务目标。

Receiver 会先执行自己的 `enabled`、交互 ID 过滤和 `validation_callback`；如果上下文的 `target` 为空或仍指向桥接 Receiver，会在通过后更新为业务目标。业务目标实现了 `receive_interaction(context, interaction_id)` 时会被调用，可以返回 `Dictionary` 覆盖报告、返回 `bool` 决定通过或拒绝，也可以只做副作用不返回值。未实现 `receive_interaction()` 时，业务目标只作为 target 使用，Receiver 仍会沿用自身的接收报告并发出 `interaction_received`。

## 范围与广播

这组节点不会绑定碰撞层、提示 UI、距离规则、冷却、物品消耗或目标效果。需要 2D/3D 范围或射线时，可把项目自己的 `RayCast2D` / `RayCast3D` / `Area2D` / `Area3D` 检测结果交给 `send_to_raycast_2d()`、`send_to_raycast_3d()`、`broadcast_to_area_2d()` 或 `broadcast_to_area_3d()`；Sensor 会从碰撞对象向父节点查找具备 `receive_interaction()` 的接收器。

若 Sensor 配置了 `sender_path`，且业务发送者实现了 `send_to(receiver, payload_override, interaction_id_override)`，分组广播和范围广播会交给业务发送者接管；否则仍使用 Sensor 自身的 `send_to()`。业务 sender 接管时，发送结果信号仍由 Sensor 发出；如果项目还希望 Receiver 发出 `interaction_received`，业务 sender 的 `send_to()` 需要实际调用 `receiver.receive_interaction(context, interaction_id)`。

项目也可以把范围、视线、优先级或编辑器选择结果先写入通用候选 provider，再交给 Sensor。`GFObjectCandidateRegistry` 提供弱引用候选表，按 group、method、priority 和注册顺序筛选排序；`send_to_best_candidate(provider, options)` 会向最高优先级候选发送一次交互，`broadcast_to_candidates(provider, options, max_count)` 会向筛选后的候选列表广播。provider 只负责提供对象候选，不定义距离、冷却、消耗或提示 UI。

需要让交互提示、选择高亮或项目侧候选缓存及时刷新时，可监听注册表的 `candidates_changed(revision)`。注册、更新、清空、按 owner 批量移除和失效对象清理都会在一次确实改变记录的公开操作结束后发出一次通知；幂等注册、空表清理或移除不存在的候选不会制造伪变化。`get_revision()` 与调试快照中的 `revision` 可用于跳过已经处理过的版本。通知只表示候选记录变了，不代表“最佳候选”必然变化；监听方仍应使用自己的 group、method 和项目筛选条件重新查询。

输入触发、碰撞层筛选、UI 焦点和目标合法性仍由项目层决定。
