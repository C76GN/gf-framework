# Network 固定 tick、快照与历史

这一页说明面向同步、重放或插值的轻量原语。它们自身只保存 tick、状态字典和历史窗口，不执行预测、回滚、实体复制或服务器权威规则。需要全量权威快照、输入 ack 和可选预测纠偏时，使用单独的 [Network 同步协调器](network-sync-coordinator.md)。

## 核心模型

- `GFFixedTickClock`：把真实时间转换为固定 tick 步数。
- `GFNetworkSnapshot`：保存某个 tick 的状态字典，并能生成浅层 delta 或路径级 patch。
- `GFNetworkHistoryBuffer`：按 tick 保存有限历史。
- `GFNetworkFieldSerializer` / `GFNetworkSnapshotSchema`：按字段编码和解码状态字典。

## Tick 与快照

```gdscript
var clock := GFFixedTickClock.new(30.0)
var steps := clock.advance(delta)
for i in range(steps):
	simulate_one_tick(clock.current_tick - steps + i + 1)

var history := GFNetworkHistoryBuffer.new(120)
history.add_state(clock.current_tick, {
	"position": player_position,
	"velocity": player_velocity,
})

var previous := history.get_closest_snapshot(clock.current_tick - 2)
var latest := history.get_latest_snapshot()
var delta_payload := previous.make_delta_to(latest)
var patch_payload := previous.make_patch_to(latest)
```

`GFFixedTickClock` 除了批量 `ticks_advanced`，也会在每个固定步发出 `tick_started` / `tick_finished`，并在单帧预算不足时发出 `tick_budget_exhausted`。时钟只负责说明本帧该处理哪些 tick；具体输入采样、实体更新、状态广播和视觉插值仍由项目系统决定。

## 字段编码

```gdscript
var position_serializer := GFNetworkFieldSerializer.new()
position_serializer.value_type = GFNetworkFieldSerializer.ValueType.VECTOR2
position_serializer.quantize_decimals = 2

var rotation_serializer := GFNetworkFieldSerializer.new()
rotation_serializer.value_type = GFNetworkFieldSerializer.ValueType.QUATERNION
rotation_serializer.quantize_decimals = 3

var schema := GFNetworkSnapshotSchema.new()
schema.set_field_serializer(&"position", position_serializer)
schema.set_field_serializer(&"rotation", rotation_serializer)

var encoded := schema.encode_snapshot(latest)
var decoded := schema.decode_snapshot(encoded)
```

Quaternion 字段适合玩家朝向、炮塔、载具或摄像机姿态等旋转状态，固定编码为 `[x, y, z, w]`。序列化前后都会恢复单位长度；零长度、`NaN` 或无穷分量会回退为 `Quaternion.IDENTITY`，避免非法旋转继续进入快照和插值。`quantize_decimals` 仍是分量精度策略，量化后会再次归一化，因此它不是位级压缩格式，也不保证最终分量仍精确停在十进制网格上。

Schema 只改变状态字段的表示形式，不决定哪些字段应该同步、发给谁、是否可靠、如何预测或如何解决冲突。发送端和接收端必须为同一字段使用相同 serializer；要进一步减少旋转载荷，应在项目协议层另行选择并版本化压缩格式，而不是把四元数压缩策略写死在通用字段编码器里。

## 脏字段跟踪

`GFNetworkDirtyStateTracker` 用于比较当前状态字典和基线，输出脏字段、优先级分组和调试快照。字段优先级可用于项目侧决定发送频率、可靠通道、压缩策略或只在生成时同步，但 tracker 本身不发送消息，也不读取节点树。

```gdscript
var tracker := GFNetworkDirtyStateTracker.new()
tracker.set_field_priority(&"position", GFNetworkDirtyStateTracker.Priority.REALTIME)
tracker.set_field_priority(&"health", GFNetworkDirtyStateTracker.Priority.HIGH)
tracker.set_baseline({
	"position": Vector2.ZERO,
	"health": 100,
})

var report := tracker.get_dirty_report({
	"position": Vector2(2, 0),
	"health": 100,
}, {
	"priorities": [
		GFNetworkDirtyStateTracker.Priority.REALTIME,
		GFNetworkDirtyStateTracker.Priority.HIGH,
	],
})
```

浮点、`Vector2`、`Vector3` 和 `Color` 会按 `epsilon` 做近似比较；其他值按普通相等比较。调用 `update_baseline(state, field_ids)` 可以在项目确认发送或应用后只更新部分字段。

路径级 patch 用 `set` / `erase` 操作描述嵌套字典变化。它适合项目自定义同步流程中包含实体表、组件表或多层配置片段的状态字典；数组、向量和其他非字典值仍作为整体字段比较。需要压缩或量化 patch 时，`GFNetworkSnapshotSchema.encode_patch()` / `decode_patch()` 会复用已注册的顶层字段编码器。`GFNetworkSyncCoordinator` v1 只接收全量快照，不把这些 patch 当作入站同步协议。

```gdscript
var patch := previous.make_patch_to(latest, {
	"max_depth": 8,
})

var encoded_patch := schema.encode_patch(patch)
var decoded_patch := schema.decode_patch(encoded_patch)
var next_snapshot := previous.apply_patch(decoded_patch)
```

## 使用边界

`GFNetworkHistoryBuffer` 可查询 tick 范围或某个 tick 前后的快照，方便项目做插值、对账或回放定位。`GFNetworkSnapshot.make_message()` 可以把快照打包成 `GFNetworkMessage`，方便复用已有 serializer、channel 和 backend。

浅层 delta 和脏字段 report 只比较字典第一层字段，适合简单状态或需要保持载荷结构极直观的项目流程；路径级 patch 只负责表达嵌套字典的字段变化，不决定实体复制、冲突解决或安全过滤。接收端处理入站消息时，`GFNetworkUtility` 会以底层 backend 报告的 `peer_id` 覆盖 `message.sender_id`，项目不要信任客户端 payload 中自带的 sender 身份。
