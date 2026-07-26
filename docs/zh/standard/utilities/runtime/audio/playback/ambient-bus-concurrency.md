# 环境音、总线与并发

环境音按 channel 独立播放和停止。每次 replacement 都会先推进该 channel 的 generation；旧的本地异步加载、fade、`finished` 回调或旧 handle 因此不能命中新 session。每个 channel 同时只有一个 local 或 backend owner，切换 owner 时会先停止前一个 owner，避免两条播放路径重叠。项目直接调用原生环境音播放器的 `stop()` 时，下一次 `is_ambient_playing()`、`get_ambient_handle()` 或调试快照读取会在 generation/session identity 仍匹配时把通道收敛为 `stopped/none` 并终结全部旧 handle。backend-owned channel 的查询同样会在 backend、generation、owner 与 session 仍匹配后提交自然结束结果，不会保留陈旧 backend owner。它适合雨声、风声、场景底噪等长期背景层，不替代项目自己的音频状态机或声音优先级规则。

```gdscript
var audio := Gf.get_utility(GFAudioUtility) as GFAudioUtility

audio.play_ambient("res://audio/ambient/rain.ogg", &"rain")
audio.stop_ambient(&"rain", 0.25)
```

`stop_all_ambient()` 会把 backend-owned channel 聚合成一次 `GFAudioBackend.stop_all_ambient()`。批量调用成功后统一收敛全部匹配会话；批量能力未实现或返回 `false` 时，再逐 channel 回退，成功的 channel 提交终态，拒绝停止的 channel 保留真实 backend owner 供调用方后续重试。

## 总线音量

```gdscript
audio.set_bus_volume("SFX", 0.8)
audio.set_bus_volume("BGM", 0.5)
audio.set_bus_volume_db("BGM", -6.0, 0.25)
```

默认播放总线名为 `BGM` / `SFX`。播放请求解析不到总线时会回退到 `Master`；显式总线控制则只操作已存在的总线，找不到时返回失败并发出警告。`set_bus_volume(bus, 0.0)` 会把总线静音并让 `get_bus_volume()` 返回 `0.0`；再次设置大于 `0.0` 的值会解除静音。

`set_bus_volume_db()` 适合需要精确 dB 和平滑过渡的混音控制。`transition_seconds <= 0` 时立即应用；目标音量小于等于 `GFAudioUtility.SILENCE_VOLUME_DB` 时会静音该总线。

## 混音快照与效果属性

```gdscript
var before_menu := audio.capture_mix_snapshot(PackedStringArray(["BGM", "SFX"]))

audio.apply_mix_snapshot({
	"buses": {
		"BGM": { "volume_db": -12.0, "muted": false },
		"SFX": { "volume_linear": 0.7, "muted": true },
	},
	"effects": [
		{
			"bus": "BGM",
			"effect": "lowpass",
			"property": "cutoff_hz",
			"value": 900.0,
		},
	],
}, 0.25)

audio.apply_mix_snapshot(before_menu, 0.25)
```

混音快照描述总线和效果属性，不规定“菜单”“战斗”“对话”等业务状态。`capture_mix_snapshot()` 只枚举 Godot `AudioServer` 总线，并分别保存底层 `volume_db` / `volume_linear` 与 `muted`，即使总线当前静音也不会把真实增益改写成静音阈值。应用快照时会先尝试 backend bulk 接管；backend 拒绝后，每个 gain / mute 字段仍先询问同一个 backend，只有明确未处理的字段才回退到同名 Godot 总线。全部本地字段作为同一个 generation 事务提交，旧 Tween 不能反向覆盖结果；backend 已接管的字段不会改写或取消同名本地状态。`effect` 可以是效果索引，也可以是效果 `resource_name`、类名或类名片段；具体本地效果是否存在仍由项目的 Audio Bus Layout 决定。

需要临时压低某条总线时可使用 `duck_bus()` / `restore_ducked_bus()`：

```gdscript
audio.duck_bus("BGM", 0.5, 0.2, &"dialogue")
audio.restore_ducked_bus("BGM", 0.3, &"dialogue")
```

同一总线只捕获一次稳定 base gain/mute，并保存所有活跃 `duck_id`。配置 backend 时，即使 `AudioServer` 中存在同名总线，也会先成对查询 backend 的 `get_bus_volume()` / `get_bus_mute()`；两项都不可观测才回退本地，只有一项可观测则失败关闭。成功捕获后，local/backend owner 与 backend identity 会固定到整个 duck 生命周期，应用、释放和 dispose 都不会把状态误写到同名的另一 owner。实际衰减取当前作用域中的最强值；任意顺序释放作用域都会根据剩余集合重算，最后一个作用域释放后才恢复原始 base。替换或清除 backend、Utility 重新初始化或 dispose 时，会先按记录 owner 立即恢复仍登记总线的 base gain/mute，再清除作用域和 Tween；恢复失败时可重试的 backend 切换会返回 `false`，生命周期终结则记录 warning 并继续收敛。

## SFX 并发

```gdscript
audio.max_sfx_players = 24
audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.STOP_OLDEST
audio.stop_all_sfx(0.1)
```

`max_sfx_players <= 0` 表示不限制同时播放的 SFX 数量。预算统一统计 GF 创建的普通、2D 和 3D SFX session；正在淡出的 retiring session 在淡出真正结束、播放器停止并归还池之前仍占容量，也会计入调试快照。若 retiring 播放器被项目直接停止，下一次容量、清理或诊断收敛会立即取消旧 Tween、终结 session 并释放容量，不必继续等待原淡出时长。`STOP_OLDEST` 会在 active 与 retiring 的三类 session 中按统一播放顺序选择最旧项；强制终结 retiring session 时同样会先取消旧的 property Tween，避免播放器复用后被迟到淡出改写。溢出策略不处理项目外部音频节点或第三方音频 SDK。
