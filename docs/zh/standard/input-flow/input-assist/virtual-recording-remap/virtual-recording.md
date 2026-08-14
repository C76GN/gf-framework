# 虚拟输入与录制回放

自动化测试、回放、AI 控制或项目自己的输入桥接可以使用 `GFVirtualInputSource` 写入抽象动作值，而不是伪造具体按键。虚拟源仍要求动作已经通过上下文注册，并会复用 `GFInputMappingUtility` 的动作值、触发器、全局/玩家级状态和一次性 started/completed 语义。

```gdscript
var input_map := Gf.get_utility(GFInputMappingUtility) as GFInputMappingUtility
var ai_input := input_map.create_virtual_source(&"ai_agent", 0)

ai_input.press(&"confirm")
ai_input.set_axis_2d(&"move", Vector2.RIGHT)
ai_input.release(&"confirm")
```

虚拟源只表达“某个抽象动作现在有什么值”，不代表真实设备、不参与重绑定冲突分析，也不决定玩家加入、角色控制权或回放文件格式。需要清理一整段注入时，可调用 `clear_all()` 或 `GFInputMappingUtility.clear_virtual_source(source_id)`。

`GFVirtualInputSource` 会追踪自己成功写入的 action。调用 `configure()` 改变 mapping、`source_id` 或 `player_index`，以及直接给后两个属性赋新值时，会先释放旧身份下由该 handle 写入的贡献；完全相同的重复配置保持当前状态。`get_snapshot()` 始终返回 `source_id`、`player_index` 和当前玩家作用域的 `actions`，mapping 已释放时字段集不变、`actions` 为空。当前 `clear_all()` / `clear_virtual_source()` 是 source-wide 清理，会清除同一 `source_id` 的所有玩家贡献；需要只清一个玩家时应逐项调用 `clear_action()` / `clear_action_for_player()`。

## 有界动作脉冲

按钮、触摸手势或自动化驱动需要“立即写入、短暂保持、恰好释放一次”时，可在创建 `GFVirtualInputSource` 时注入 `GFTimerUtility`，再调用 `pulse_action()`。计时由框架 `tick()` 驱动，因此测试可以显式推进时间，不依赖场景树 `Timer` 或真实等待。

```gdscript
var input_map := Gf.get_utility(GFInputMappingUtility) as GFInputMappingUtility
var timers := Gf.get_utility(GFTimerUtility) as GFTimerUtility
var touch_input := input_map.create_virtual_source(&"touch_ui", 0, timers)

var pulse := touch_input.pulse_action(
	&"confirm",
	true,
	0.12,
	confirm_button,
	cancel_source.get_token()
)
```

`pulse_action()` 返回 `GFVirtualInputPulseOperation`。句柄冻结创建时的 Mapping、`source_id`、`player_index`、`action_id` 和 generation；之后修改 Source 配置不会让旧定时回调释放错误的输入键。`get_status()`、`get_terminal_reason()` 与 `get_release_count()` 可用于诊断完成、取消、替换、拒绝或启动失败。`release_count` 只证明当前句柄的匹配 lease 是否实际清除过自己的动作贡献，不证明聚合动作一定变为 inactive：到时、取消、clear、生命周期清理，以及 `RETRIGGER` 释放的旧 lease 为 `1`；未取得 lease、原子 `REPLACE`，以及手动写入直接接管的旧句柄为 `0`。

权威并发键是 `source_id + player_index + action_id`，而不是 `GFVirtualInputSource` 对象身份。因此两个同 ID Source 也不会让旧定时器清除新脉冲。同键已有脉冲时显式选择以下策略；默认仍为 `REPLACE`，既有调用行为不变：

- `REPLACE`：通过比较并交换移除旧 lease、提交新 generation 并覆盖同一动作贡献，不产生中间 inactive；适合连续 hold。旧句柄进入 `REPLACED`，`release_count` 为 `0`。
- `RETRIGGER`：实际清除旧 lease 的匹配贡献，再由受事务保护的新 generation 重新写入；适合需要重复离散激活的 UI。旧句柄进入 `REPLACED`，`release_count` 为 `1`。只有清除匹配贡献后全局或玩家聚合状态确实变为 inactive，重新写入才会形成对应的 completed-to-started 边沿与新的 `just_started`；其他 source、设备或绑定仍保持同一动作活跃时，框架不会伪造聚合边沿。
- `REJECT_NEW`：保留旧 lease，让新句柄立即进入 `REJECTED`，且不改写动作值。

`owner` 与 `cancellation_token` 都是可选锚点，同时提供时采用 OR 语义。二者都不提供也可以：脉冲仍受有界 duration、Source 生命周期和 Mapping 弱 lease 清理约束。树外 Node、已经释放的 owner、已完成的 `GFAsyncScope` 或无法建立的 token 连接会在写入前 fail closed；已取消 token 则让句柄立即进入 `CANCELLED`。手动 `set_action_value()`、`press()` 等写入会原子接管匹配 lease，不制造 inactive 间隙；`release()`、`clear_action()`，以及 Source/Mapping 的 clear、重建或 dispose 会终止并实际释放匹配 lease。已经失效的旧定时器不能回头清除后写入的值；若注入的 `GFTimerUtility` 在脉冲期间 dispose/reinit，下一次 Mapping tick 会把丢失的排程收敛为 `FAILED / timer_schedule_lost` 并释放匹配贡献。`GFVirtualInputSource.dispose()` 是不可逆终态，释放后不能通过 `configure()` 复活。

## 录制回放

需要把抽象动作序列保存下来再回放时，可用 `GFInputRecording` 记录 action id、时间、值、玩家索引和元数据，再交给 `GFInputPlayback` 按时间写入 `GFVirtualInputSource`。

```gdscript
var recording := GFInputRecording.new()
recording.add_event(&"jump", true, 0.0)
recording.add_event(&"jump", false, 0.12)

var playback := GFInputPlayback.new()
playback.start(recording, input_map.create_virtual_source(&"replay", 0))
playback.tick(delta)
```

`add_event()` 会按 `time_seconds` 保持事件顺序，同一时间点保留插入顺序；工具或导入器可以追加乱序事件而不必每次手动调用 `sort_events()`。如果项目直接改写公开 `events` 数组，应在回放或序列化前显式调用 `sort_events()`。

录制回放只处理 GF 抽象动作值，不模拟真实按键、鼠标或手柄事件；因此它适合自动化测试、教程演示、复现 bug、AI 接管或项目自定义输入桥接。`respect_recorded_player_index` 可让事件自带的玩家索引生效；是否保存到文件、如何压缩、是否作为回放录像公开给玩家，仍由项目层决定。

恢复暂停的回放时，`start(recording, source, false)` 会按当前 `elapsed_time` 重建虚拟源状态：已经发生但尚未释放的动作会保持按下或轴值状态，避免 resume 后出现“录制中仍按住、运行时却已释放”的短暂漂移。需要从头重播时使用默认的重新开始语义。

`event_applied` 是同步通知，但事件索引会在通知前提交。handler 可以调用 `stop()`、`start()`、`reset()` 或 `seek()`；这些操作会切换回放代际，当前旧 tick 返回后不会继续应用同时间事件、推进新录制的索引或把新会话误报为完成。handler 直接替换当前 `recording` / `source` 也会让本次 tick 停止；切换目标时仍应优先调用 `start()`，让事件快照和 source 状态在一个入口重建。`stop(true)` 清理 source 后，旧调用栈不会再次写回。
