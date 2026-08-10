# 复合动作与并行执行

`GFVisualActionGroup` 可以将一组 `GFVisualAction` 打包为一个大动作。

## 基本组合

```gdscript
# 将两张卡牌的移动动作并行执行，全部完成后再进入后续动作。
var group: GFVisualActionGroup = GFVisualActionGroup.new([
	GFMoveTweenAction.new(card_a, target_pos_a),
	GFMoveTweenAction.new(card_b, target_pos_b),
], true)

action_queue_sys.enqueue(group)
```

也可以直接使用 `enqueue_parallel([action_a, action_b])`，队列会把它们封装成并行动作组。

## 完成策略

默认并行动作组使用 `WAIT_FOR_ALL` 策略：所有需要等待的子动作都完成后，动作组才会释放后续队列。

当一个表现流程只关心“最先完成的分支”时，可以改用 `FIRST_COMPLETED` 策略，或直接使用 `GFAction.race()`：

```gdscript
q_sys.enqueue(GFAction.race([
	GFAction.wait(0.2, host),
	custom_signal_action,
]))
```

`race()` 默认会在首个子动作完成后取消仍在等待的子动作，避免遗留 Tween、Timer 或外部等待。若调用方需要让剩余动作继续运行，可以传入 `false`：

```gdscript
q_sys.enqueue(GFAction.race([
	background_flash_action,
	user_input_action,
], false))
```

同一个 `GFVisualActionGroup` 或 `GFRepeatAction` 不应被当作可并发复用对象。再次执行时，GF 会先取消上一次尚未结束的分支并发出完成信号，再启动新的运行态，避免旧 Tween、Timer 或 Signal 等待悬挂在队列之外。

动作组在 `execute()` 开始时冻结本轮动作列表；执行期间修改 `actions` 只影响下一轮。并行计划若包含同一个动作实例两次，会在任何子动作产生副作用前整体拒绝；需要两条并行分支时，应创建两个彼此独立的动作实例。

任一子动作、依赖注入或动作协议回调取消/完成/重启当前组后，旧运行代际不会继续启动尚未开始的兄弟动作。

## 使用边界

这个策略只定义动作组的等待边界，不解释“胜利者”或后续业务含义。需要保留结果、选择分支或写入项目状态时，应由具体动作或调用方在自己的层级完成。
