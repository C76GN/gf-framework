# 回放时间线

`GFReplayTimeline` 用一组按时间排序的纯数据事件串联命令、输入、状态快照或项目自定义记录。它只负责记录、查询、合并和序列化，不负责执行命令、回放输入或恢复状态。

```gdscript
var timeline := GFReplayTimeline.new()
timeline.add_input(0.1, { "action_id": &"jump", "value": true })
timeline.add_command(0.2, { "command_id": &"open_door", "args": { "door": 3 } })
timeline.add_snapshot(0.5, { "tick": 15, "state": { "hp": 10 } })

var early_events := timeline.get_events_in_range(0.0, 0.3)
var snapshots := timeline.get_events_by_kind(GFReplayTimeline.EVENT_SNAPSHOT)
```

常量 `EVENT_COMMAND`、`EVENT_INPUT`、`EVENT_SNAPSHOT` 只是通用分类，payload 的结构由项目决定。需要把多段录制拼起来时，可用 `append_timeline()` 添加时间偏移和类型过滤。

时间戳和 `duration_seconds` 会被规范化为有限且不小于 0 的秒数；`NaN`、`Infinity` 或负数不会进入 `to_dictionary(true)` 的 JSON 兼容输出。payload 与 metadata 中的 Godot 值仍由 `GFVariantJsonCodec` 负责转换。

```gdscript
combined.append_timeline(round_one, 0.0)
combined.append_timeline(round_two, round_one.duration_seconds, PackedStringArray(["input", "snapshot"]))
```

如果后续要真正执行这些事件，项目应把 payload 交给自己的命令构造器、输入回放器或状态恢复流程。时间线本身不解释业务字段，也不保证事件副作用可逆。
