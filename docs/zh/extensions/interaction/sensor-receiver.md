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

返回报告用于日志和诊断，`receiver` 字段是 `GFReportValueCodec` 生成且只经过一次编码的 JSON-safe Object 摘要，不是 live `Object`。Sensor、Pointer 和 Receiver-to-Receiver 桥接都会先取得 raw outcome，再由各自最外层公开边界完成一次报告编码；同一原始字段不会因入口不同被再次包装成 Dictionary marker。需要接收对象实例时，使用发送/接收信号里的 `receiver` 参数，或读取 `GFInteractionContext.target`。

`validation_callback` 的缺省值 `Callable()` 表示“不配置校验器”。如果曾配置的 Callable 因 owner 释放而变得非空但无效，Receiver 会以 `ok=false, reason=invalid_validator` 失败关闭并发出 `interaction_rejected`；若项目确实要撤销校验器，必须主动把属性重新赋为 `Callable()`，不能依赖 owner 消失恢复默认允许。

## 业务目标桥接

当碰撞区域只承担检测和过滤，而业务目标在角色、物品或能力节点上时，可以把 `GFInteractionReceiver` 放在碰撞对象自身或其父级，并通过 `receiver_path` 指向真正的业务目标。

Receiver 会先执行自己的 `enabled`、交互 ID 过滤和 `validation_callback`；如果上下文的 `target` 为空或仍指向桥接 Receiver，会在通过后更新为业务目标。业务目标实现了 `receive_interaction(context, interaction_id)` 时会被调用，可以返回 `Dictionary` 覆盖报告、返回 `bool` 决定通过或拒绝，也可以只做副作用不返回值。未实现 `receive_interaction()` 时，业务目标只作为 target 使用，Receiver 仍会沿用自身的接收报告并发出 `interaction_received`。

动态协议不是只按方法名识别：框架会在调用前核对必填/默认/可变参数数量、固定参数 Variant 类型，以及 Object 参数的原生类或 GDScript `class_name`。同名但签名不兼容的 `receive_interaction()` 会以 `invalid_receiver` 失败关闭；不兼容的 `send_to()` override 会回退到 Sensor 标准发送；不兼容的候选 provider 会被视为没有可用候选。这样项目方法的名称碰撞不会转化为运行时脚本错误。

## 范围与广播

这组节点不会绑定碰撞层、提示 UI、距离规则、冷却、物品消耗或目标效果。需要 2D/3D 范围或射线时，可把项目自己的 `RayCast2D` / `RayCast3D` / `Area2D` / `Area3D` 检测结果交给 `send_to_raycast_2d()`、`send_to_raycast_3d()`、`broadcast_to_area_2d()` 或 `broadcast_to_area_3d()`；Sensor 会从碰撞对象向父节点查找具备 `receive_interaction()` 的接收器。

若 Sensor 配置了 `sender_path`，且业务发送者实现了 `send_to(receiver, payload_override, interaction_id_override)`，分组广播和范围广播会交给业务发送者接管；否则仍使用 Sensor 自身的 `send_to()`。业务 sender 接管时，每次实际调用都必须产生一个完整结果：空 Dictionary 或非 Dictionary 会转换为 JSON-safe 的 `ok=false, reason=invalid_report`，并由 Sensor 发出对应结果信号；不会返回残缺报告或静默丢弃失败。若项目还希望 Receiver 发出 `interaction_received`，业务 sender 的 `send_to()` 需要实际调用 `receiver.receive_interaction(context, interaction_id)`。

项目也可以把范围、视线、优先级或编辑器选择结果先写入通用候选 provider，再交给 Sensor。`GFObjectCandidateRegistry` 提供弱引用候选表，按 group、method、priority 和注册顺序筛选排序；`send_to_best_candidate(provider, options)` 会向最高优先级候选发送一次交互，`broadcast_to_candidates(provider, options, max_count)` 会向筛选后的候选列表广播。provider 只负责提供对象候选，不定义距离、冷却、消耗或提示 UI。

Sensor 会按实例 ID 保留候选首次出现顺序并去重，再以弱引用跨越“查询到分发”的同步时间边界；前一个回调释放后续 receiver 时，失效项会在实际使用前被跳过，不会访问 previously freed Object。项目不能把 provider 查询时有效视为整个广播期间持续有效。

需要让交互提示、选择高亮或项目侧候选缓存及时刷新时，可监听注册表的 `candidates_changed(revision)`。注册、更新、清空、按 owner 批量移除和失效对象清理都会在一次确实改变记录的公开操作结束后发出一次通知；幂等注册、空表清理或移除不存在的候选不会制造伪变化。`get_revision()` 与调试快照中的 `revision` 可用于跳过已经处理过的版本。通知只表示候选记录变了，不代表“最佳候选”必然变化；监听方仍应使用自己的 group、method 和项目筛选条件重新查询。

输入触发、碰撞层筛选、UI 焦点和目标合法性仍由项目层决定。
